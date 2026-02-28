// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {GameStorage} from "./GameStorage.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {IGameLogic} from "./interfaces/IGameLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {Player, AbilitiesExtra, Character} from "./libraries/Character.sol";
import {Rarity} from "./libraries/Attribute.sol";
import {Battle} from "./libraries/Battle.sol";
import {Enemy, Aoka} from "./libraries/Enemy.sol";
import {Property, Sword, Armor, Shield, EquipmentMaterials, EquipmentType, ItemType} from "./libraries/Property.sol";
import {Oracle} from "./random/Oracle.sol";
import {Floor, Environment} from "./libraries/Environment.sol";
import {Seed} from "./libraries/Seed.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title Game logic contract
 * @author Jan
 * @notice Main logic for the entire game
 */
abstract contract GameLogic is GameStorage, Oracle, IGameLogic {
    using SafeCast for uint256;
    using Seed for bytes32;

    IGameAssets internal _gameAssets;
    IGameToken internal _gameToken;

    // word "reward"
    bytes32 private constant SEED_MIX_REWORD = 0x7265776172640000000000000000000000000000000000000000000000000000;
    // word "floor"
    bytes32 private constant SEED_MIX_FLOOR = 0x666C6F6F72000000000000000000000000000000000000000000000000000000;

    modifier onlyRegistered() {
        _onlyRegistered();
        _;
    }

    /// @notice create a player
    function born() external {
        if (findPlayer(msg.sender).createAt > 0) {
            revert IGameLogic.PlayerAlreadyExists();
        }

        addPlayer(msg.sender, Character.initPlayer());

        // create some equipments and items
        uint256 itemId = _newHandPotion();
        addItem(msg.sender, itemId);
        uint256 swordId = addSword(msg.sender, _newHandSword());
        uint256 puppetId = addPuppet(msg.sender, Rarity.C, uint40(block.timestamp));

        // mint ERC1155 assets
        uint256[] memory ids = new uint256[](3);
        uint256[] memory values = new uint256[](3);
        ids[0] = itemId;
        ids[1] = swordId;
        ids[2] = puppetId;
        values[0] = 1;
        values[1] = 1;
        values[2] = 1;
        _gameAssets.mintBatch(msg.sender, ids, values, "");

        // mint ERC20 token
        _gameToken.mint(msg.sender, 1 ether);

        _initFloor(msg.sender, Oracle.getSeed().change(5, SEED_MIX_FLOOR));
    }

    /// @notice deposit ERC20 game token into this contract (proxy)
    ///         caller must `_gameToken.approve(address(this), amount)` first
    /// @param amount token amount to deposit (in token's smallest unit, e.g. wei)
    function deposit(uint256 amount) external {
        if (amount < 1 ether) {
            revert IGameLogic.AmountAtLeast1e18();
        }

        _deposit(amount);
    }

    /// @notice deposit in one tx without prior approve: uses EIP-2612 permit (signature) then transferFrom
    /// @param amount token amount to deposit (same rules as deposit)
    /// @param deadline permit signature expiry (block.timestamp)
    /// @param v,r,s EIP-712 signature of permit(owner=signer, spender=this, value=amount, nonce=token.nonces(signer), deadline)
    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (amount < 1 ether) {
            revert IGameLogic.AmountAtLeast1e18();
        }

        _gameToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        _deposit(amount);
    }

    function withdraw(uint256 amount) external {
        if (amount < 1 gwei) {
            revert IGameLogic.AmountAtLeast1e9();
        }

        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < amount) {
            revert IGameLogic.InsufficientCoin();
        }

        _gameAssets.burn(msg.sender, Property.COIN_ID, amount);
        uint256 token = amount / 10;
        if (_gameToken.balanceOf(address(this)) < token) {
            revert IGameLogic.InsufficientERC20();
        }

        // burn 5%
        uint256 burnAmount = token / 20;
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        _gameToken.transfer(msg.sender, token - burnAmount);
        _gameToken.burn(address(this), burnAmount);
    }

    function battle(uint256 enemySlot) external onlyRegistered {
        Floor storage floor = findFloor(msg.sender);
        if (floor.enemies.length <= enemySlot) {
            revert IGameLogic.EnemyNotFound(enemySlot);
        }

        Player storage player = findPlayer(msg.sender);
        (Sword memory sword, Armor memory armor, Shield memory shield) = getEquipped(msg.sender);

        // 0: no equipped armor, don't use `armorMaterialsIdx`
        AbilitiesExtra memory ae = AbilitiesExtra({
            attack: sword.attack,
            defense: armor.defense + shield.defense,
            crit: sword.crit,
            critChance: sword.critChance,
            stunChance: sword.stunChance + shield.stunChance,
            blockChance: shield.blockChance,
            weaponMaterialsIdx: uint8(sword.materials),
            armorEquipped: armor.level == 0,
            armorMaterialsIdx: uint8(armor.materials)
        });

        bytes32 seed = Oracle.getSeed();
        Aoka storage enemy = floor.enemies[enemySlot];
        (uint256 playerHealFinal, uint256 aokaHealthFinal) =
            Battle.combat(seed, player.health, player.attack, player.defense, enemy, ae);

        // don't use `playerHealFinal > 0` alone to determine if the player has won
        // because after 32 rounds, both the player and Aoka might still have health remaining
        bool playerWin = aokaHealthFinal == 0;
        uint256 curFloorIndex = floor.index;
        player.health = playerHealFinal.toUint16();
        if (playerWin) {
            // defeated aoka
            enemy.health = 0;
            _rewardWinner(msg.sender, seed, curFloorIndex);
            uint32 gainedExp = Battle.calRewardExperience(enemy.level, curFloorIndex);
            _playerLevelUp(player, gainedExp);
        }
    }

    function nextFloor() external onlyRegistered {
        _nextFloor(msg.sender, Oracle.getSeed());
    }

    /// @notice currently, only Book and Potion can be used
    function useItems(uint256[] calldata slots) external onlyRegistered {
        uint256 len = slots.length;
        if (len == 0 || len > 5) {
            revert IGameLogic.LengthOutOfRange1To5();
        }

        // item slots must be sorted in ascending order
        // and cannot be repeated
        for (uint256 i = 1; i < len; i++) {
            if (slots[i] <= slots[i - 1]) {
                revert IGameLogic.WrongSequence();
            }
        }

        Player storage player = findPlayer(msg.sender);

        uint256[] storage items = findBag(msg.sender);
        uint256 bagLen = items.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 slot = slots[i];
            if (slot >= bagLen) {
                revert IGameLogic.ItemNotFound(slot);
            }
            uint256 itemId = items[slot];
            if (itemId == 0) {
                revert IGameLogic.ItemNotFound(slot);
            }
            ItemType typ = Property.typeFromItemId(itemId);
            if (typ == ItemType.Book) {
                _playerLevelUp(player, Property.calBookValue(itemId));
            } else if (typ == ItemType.Potion) {
                uint16 addHealth = Property.calPotionValue(itemId);
                uint16 totalHealth = player.health + addHealth;
                player.health = totalHealth > player.healthMax ? player.healthMax : totalHealth;
            } else {
                revert IGameLogic.WrongItemType();
            }
        }

        delItems(msg.sender, slots);
    }

    function getFloor(address addr) external view returns (Floor memory) {
        return findFloor(addr);
    }

    function getPlayer(address addr) external view returns (Player memory) {
        return findPlayer(addr);
    }

    function getBag(address addr) external view returns (uint256[] memory itemIds) {
        uint256[] storage _mb = findBag(addr);
        uint256 len = _mb.length;
        itemIds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            itemIds[i] = _mb[i];
        }
    }

    function getWarehouse(address addr) external view returns (uint256[] memory weaponIds) {
        uint256[] storage _wh = findWarehouse(addr);
        uint256 len = _wh.length;
        weaponIds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            weaponIds[i] = _wh[i];
        }
    }

    function _newHandPotion() private pure returns (uint256) {
        return Property.POTION_C_ID;
    }

    function _newHandSword() private pure returns (Sword memory sword) {
        return Sword({
            materials: EquipmentMaterials.Iron,
            rarity: Rarity.C,
            level: 1,
            attack: 8,
            crit: 0,
            critChance: 0,
            stunChance: 0
        });
    }

    /// @notice player level up, increase attributes
    function _playerLevelUp(Player storage _player, uint32 gainedExp) private {
        // don't level up if already at max level
        // and won't increase the gainedExp
        uint8 curLevel = _player.level;
        if (curLevel >= 100) {
            return;
        }

        (bool levelUp, uint32 remainExp) = Character.isLevelUp(curLevel, gainedExp, _player.experience);
        if (!levelUp) {
            _player.experience += gainedExp;
            return;
        }

        // increment values for the three basic attributes
        (uint16 healthMaxIncrement, uint16 attackIncrement, uint16 defenseIncrement) =
            Character.levelUpAttributesIncrement(curLevel);

        unchecked {
            _player.healthMax += healthMaxIncrement;
            _player.attack += attackIncrement;
            _player.defense += defenseIncrement;
            // reset experience
            _player.experience = remainExp;
            // no matter how much experience is gained, only one level can be increased at a time
            _player.level++;
        }
    }

    function _deposit(uint256 amount) private {
        // address(this) is proxy if use proxy pattern
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        _gameToken.transferFrom(msg.sender, address(this), amount);
        _gameAssets.mint(msg.sender, Property.COIN_ID, amount * 10, "");
    }

    function _rewardWinner(address winner, bytes32 seed, uint256 floorIndex) private {
        bytes32 rewardSeed = seed.change(6, SEED_MIX_REWORD);

        uint256 equipmentId = 0;
        // use rewardSeed array index 0
        if (Battle.equipmentDetermine(uint8(rewardSeed[0]), floorIndex)) {
            // use rewardSeed array indexs [1,2,3]
            equipmentId = _rollEquipment(winner, rewardSeed, floorIndex);
        }
        // combine items and equipment
        (uint256[] memory assetIds, uint256[] memory values) =
            Battle.rewardItemsAppendEquipmentAndCoins(rewardSeed, floorIndex, equipmentId);
        _gameAssets.mintBatch(winner, assetIds, values, "");
    }

    function _rollEquipment(address winner, bytes32 rewardSeed, uint256 floorIndex)
        private
        returns (uint256 equipmentId)
    {
        // use rewardSeed array indexs from [1,2,3]
        (uint8 level, Rarity rarity, EquipmentMaterials materials, EquipmentType typ) =
            Battle.rewardEquipment(rewardSeed, floorIndex);
        (uint16 crit, uint16 critChance, uint16 blockChance, uint16 stunChance) =
            Property.calSecondAttributesDirectly(rarity);

        if (EquipmentType.Sword == typ) {
            equipmentId = addSword(
                winner,
                Sword({
                    materials: materials,
                    rarity: rarity,
                    level: level,
                    attack: Property.calAttackForSword(rarity, level),
                    crit: crit,
                    critChance: critChance,
                    stunChance: stunChance
                })
            );
        } else if (EquipmentType.Armor == typ) {
            equipmentId = addArmor(
                winner,
                Armor({
                    materials: materials,
                    rarity: rarity,
                    level: level,
                    defense: Property.calDefenseForArmor(rarity, level)
                })
            );
        } else {
            equipmentId = addShield(
                winner,
                Shield({
                    rarity: rarity,
                    level: level,
                    defense: Property.calDefenseForShield(rarity, level),
                    blockChance: blockChance,
                    stunChance: stunChance
                })
            );
        }
    }

    function _initFloor(address addr, bytes32 seed) private {
        Floor storage floor = findFloor(addr);
        if (floor.index != 0) revert IGameLogic.WrongFloorIndex();

        _constructFloorData(floor, floor.index, seed);
    }

    function _nextFloor(address addr, bytes32 seed) private {
        Floor storage floor = findFloor(addr);
        uint8 curIndex = floor.index;
        // can't exceed 99
        if (curIndex >= 99) revert IGameLogic.ReachedTheTopFloor();

        uint256 enemyCount = floor.enemies.length;
        for (uint256 i = 0; i < enemyCount; i++) {
            if (floor.enemies[i].health > 0) {
                revert IGameLogic.MustDefeatAllEenemies();
            }
        }

        Environment.clearFloor(floor);
        // next
        floor.index = curIndex + 1;
        _constructFloorData(floor, floor.index, seed);
    }

    function _circle(address addr, bytes32 seed) private {
        Floor storage floor = findFloor(addr);
        if (floor.index != 99) revert IGameLogic.NotAt100Floor();

        Player storage player = findPlayer(addr);
        Character.circle(player);

        //reset floor
        Environment.clearFloor(floor);
        _constructFloorData(floor, floor.index, seed);
    }

    function _constructFloorData(Floor storage floor, uint256 floorIndex, bytes32 seed) private {
        // shop count is 1 or 0
        uint256 shopCount = Environment.shopCountNextFloor(uint8(seed[0]), floorIndex);
        // foundry count is 1 or 0
        uint256 foundryCount = Environment.foundryCountNextFloor(uint8(seed[1]), floorIndex);
        // aoka count is 1 to 4
        uint256 aokaCount = Environment.aokaCountNextFloor(uint8(seed[2]), shopCount, foundryCount);

        if (shopCount > 0) {
            Environment.fillShop(floor.shop, seed, floorIndex);
        }
        if (foundryCount > 0) {
            Environment.fillFoundry(floor.foundry, floorIndex);
        }
        if (aokaCount > 0) {
            Enemy.fillAokas(floor.enemies, seed, floorIndex, aokaCount);
        }
    }

    function _onlyRegistered() private view {
        if (findPlayer(msg.sender).createAt == 0) {
            revert IGameLogic.PlayerNotFound(msg.sender);
        }
    }
}
