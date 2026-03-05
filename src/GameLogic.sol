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
    // word "upgrade"
    bytes32 private constant SEED_MIX_UPGRADE = 0x7570677261646500000000000000000000000000000000000000000000000000;
    // word "merge"
    bytes32 private constant SEED_MIX_MERGE = 0x6d65726765000000000000000000000000000000000000000000000000000000;
    // word "circle"
    bytes32 private constant SEED_MIX_CIRCLE = 0x636972636c650000000000000000000000000000000000000000000000000000;
    modifier onlyRegistered() {
        _onlyRegistered();
        _;
    }

    /// @notice create a player
    function born() external {
        if (findPlayer(msg.sender).createAt > 0) {
            revert PlayerAlreadyExists();
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

        emit Born(msg.sender);
    }

    /// @notice deposit ERC20 game token into this contract (proxy)
    ///         caller must `_gameToken.approve(address(this), amount)` first
    /// @param amount token amount to deposit (in token's smallest unit, e.g. wei)
    function deposit(uint256 amount) external {
        if (amount < 1 ether) {
            revert AmountAtLeast1e18();
        }

        _deposit(amount);
    }

    /// @notice deposit in one tx without prior approve: uses EIP-2612 permit (signature) then transferFrom
    /// @param amount token amount to deposit (same rules as deposit)
    /// @param deadline permit signature expiry (block.timestamp)
    /// @param v,r,s EIP-712 signature of permit(owner=signer, spender=this, value=amount, nonce=token.nonces(signer), deadline)
    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (amount < 1 ether) {
            revert AmountAtLeast1e18();
        }

        _gameToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        _deposit(amount);
    }

    function withdraw(uint256 amount) external {
        if (amount < 1 gwei) {
            revert AmountAtLeast1e9();
        }

        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < amount) {
            revert InsufficientCoin();
        }

        _gameAssets.burn(msg.sender, Property.COIN_ID, amount);
        uint256 token = amount / 10;
        if (_gameToken.balanceOf(address(this)) < token) {
            revert InsufficientERC20();
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
            revert EnemyNotFound(enemySlot);
        }

        Player storage player = findPlayer(msg.sender);
        (Sword memory sword, Armor memory armor, Shield memory shield,) = getEquipped(msg.sender);

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
        if (enemy.health == 0) revert EnemyNotFound(enemySlot);

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

        emit Combat(msg.sender, seed, floor, player, ae, enemy);
    }

    function nextFloor() external onlyRegistered {
        _nextFloor(msg.sender, Oracle.getSeed());
    }

    /// @notice currently, only Book and Potion can be used
    function useItems(uint256[] calldata slots) external onlyRegistered {
        uint256 len = slots.length;
        if (len == 0 || len > 5) {
            revert LengthOutOfRange1To5();
        }

        // item slots must be sorted in ascending order
        // and cannot be repeated
        for (uint256 i = 1; i < len; i++) {
            if (slots[i] <= slots[i - 1]) {
                revert WrongSequence();
            }
        }

        Player storage player = findPlayer(msg.sender);

        uint256[] storage items = findBag(msg.sender);
        uint256 bagLen = items.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 slot = slots[i];
            if (slot >= bagLen) {
                revert ItemNotFound(slot);
            }
            uint256 itemId = items[slot];
            if (itemId == 0) {
                revert ItemNotFound(slot);
            }
            ItemType typ = Property.typeFromItemId(itemId);
            if (typ == ItemType.Book) {
                _playerLevelUp(player, Property.calBookValue(itemId));
            } else if (typ == ItemType.Potion) {
                uint16 addHealth = Property.calPotionValue(itemId);
                uint16 totalHealth = player.health + addHealth;
                player.health = totalHealth > player.healthMax ? player.healthMax : totalHealth;
            } else {
                revert WrongItemType();
            }
        }

        delItems(msg.sender, slots);
    }

    function fullHeal() external onlyRegistered {
        Player storage player = findPlayer(msg.sender);
        if (player.health >= player.healthMax) {
            revert AlreadyFullHealth();
        }
        uint256 cost = _healToFullCost(player.level);
        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) {
            revert InsufficientCoin();
        }
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
        player.health = player.healthMax;
    }

    function equip(uint256 equipmentId) external onlyRegistered {
        if (!isValidEquipment(equipmentId)) revert InvalidEquipmentId(equipmentId);

        uint256[] storage equipmentIds = findWarehouse(msg.sender);
        uint256 len = equipmentIds.length;
        bool found = false;
        for (uint256 i = 0; i < len; i++) {
            if (equipmentIds[i] == equipmentId) {
                delete equipmentIds[i];
                found = true;
                break;
            }
        }
        if (!found) revert EquipmentNotFound(equipmentId);
        equipWeapon(msg.sender, equipmentId);
    }

    function unequip(uint256 equipmentId) external onlyRegistered {
        if (!isValidEquipment(equipmentId)) revert InvalidEquipmentId(equipmentId);

        unequipWeapon(msg.sender, equipmentId);
        addToWarehouse(msg.sender, equipmentId);
    }

    function buy(uint256 typeIndex, uint256 slot) external onlyRegistered {
        if (typeIndex > 3) revert InvalidTypeIndex(typeIndex);

        Floor storage floor = findFloor(msg.sender);
        uint256 cost = 0;
        uint256 assetId = 0;

        if (typeIndex == 0) {
            uint256[] storage itemIds = floor.shop.items;
            if (slot >= itemIds.length) revert InvalidIndex(slot);
            assetId = itemIds[slot];
            if (assetId == 0) revert InvalidIndex(slot);
            addItem(msg.sender, assetId);
            delete itemIds[slot];
            cost = Property.itemCost(assetId);
        } else if (typeIndex == 1) {
            Sword[] storage swords = floor.shop.swords;
            if (slot >= swords.length) revert InvalidIndex(slot);
            Sword memory sword = swords[slot];
            if (sword.level == 0) revert InvalidIndex(slot);
            cost = Property.equipmentCost(sword.level, sword.rarity);
            assetId = addSword(msg.sender, sword);
            delete swords[slot];
        } else if (typeIndex == 2) {
            Shield[] storage shields = floor.shop.shields;
            if (slot >= shields.length) revert InvalidIndex(slot);
            Shield memory shield = shields[slot];
            if (shield.level == 0) revert InvalidIndex(slot);
            cost = Property.equipmentCost(shield.level, shield.rarity);
            assetId = addShield(msg.sender, shield);
            delete shields[slot];
        } else {
            Armor[] storage armors = floor.shop.armors;
            if (slot >= armors.length) revert InvalidIndex(slot);
            Armor memory armor = armors[slot];
            if (armor.level == 0) revert InvalidIndex(slot);
            cost = Property.equipmentCost(armor.level, armor.rarity);
            assetId = addArmor(msg.sender, armor);
            delete armors[slot];
        }

        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();
        _gameAssets.mint(msg.sender, assetId, 1, "");
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
    }

    function upgrade(uint256 equipmentId) external onlyRegistered {
        if (equipmentId == 0) revert InvalidEquipmentId(equipmentId);
        // 0:SwordId 1:ArmorId 2:ShieldId 3: Puppet (cann't upgrade)
        uint256[4] storage equippedIds = findEquipped(msg.sender);

        EquipmentType typ;
        bool found = false;
        for (uint256 i = 0; i < 3; i++) {
            if (equippedIds[i] == equipmentId) {
                typ = EquipmentType(i);
                found = true;
                break;
            }
        }

        if (!found) {
            // seek in warehouse
            uint256[] storage weaponIds = findWarehouse(msg.sender);
            uint256 len = weaponIds.length;
            for (uint256 i = 0; i < len; i++) {
                if (weaponIds[i] == equipmentId) {
                    typ = Property.typeFromEquipmentId(equipmentId);
                    found = true;
                    break;
                }
            }
        }

        if (!found) revert InvalidEquipmentId(equipmentId);

        uint8 curLevel = _getEquipmentLevel(equipmentId, typ);

        // level <=25
        if (curLevel >= Property.MAX_EQUIPMENT_LEVEL) revert ReachedMaxLevel();

        // check player's coin balance
        uint256 cost = Property.upgradeEquipmentCost(curLevel);
        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();

        bytes32 upgradeSeed = Oracle.getSeed().change(7, SEED_MIX_UPGRADE);
        if (Property.determineUpgrade(uint8(upgradeSeed[0]), curLevel)) {
            _upgradeEquipment(equipmentId, typ);
        }

        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
    }

    function mergeSword(uint256 mainEquipmentId, uint256 subEquipmentId) external {
        _mergeEquipment(EquipmentType.Sword, mainEquipmentId, subEquipmentId);
    }

    function mergeArmor(uint256 mainEquipmentId, uint256 subEquipmentId) external {
        _mergeEquipment(EquipmentType.Armor, mainEquipmentId, subEquipmentId);
    }

    function mergeShield(uint256 mainEquipmentId, uint256 subEquipmentId) external {
        _mergeEquipment(EquipmentType.Shield, mainEquipmentId, subEquipmentId);
    }

    function circle() external onlyRegistered {
        _circle(msg.sender, Oracle.getSeed().change(6, SEED_MIX_CIRCLE));
    }

    function _mergeEquipment(EquipmentType typ, uint256 mainId, uint256 subId) private {
        if (mainId == 0) revert InvalidEquipmentId(mainId);
        if (subId == 0) revert InvalidEquipmentId(subId);
        if (mainId == subId) revert SameEquipmentIds();

        uint256 equippedSlot = uint256(typ);
        if (findEquipped(msg.sender)[equippedSlot] != mainId) revert InvalidEquipmentId(mainId);

        uint256[] storage warehouse = findWarehouse(msg.sender);
        uint256 len = warehouse.length;
        uint256 subIdx = len;
        for (uint256 i = 0; i < len; i++) {
            if (warehouse[i] == subId) {
                subIdx = i;
                break;
            }
        }
        if (subIdx >= len) revert InvalidEquipmentId(subId);
        if (Property.typeFromEquipmentId(subId) != typ) revert InvalidEquipmentId(subId);

        bytes32 mergeSeed = Oracle.getSeed().change(5, SEED_MIX_MERGE);
        uint256 cost;
        if (typ == EquipmentType.Sword) cost = _mergeSwordImpl(mainId, subId, warehouse, subIdx, mergeSeed);
        else if (typ == EquipmentType.Armor) cost = _mergeArmorImpl(mainId, subId, warehouse, subIdx, mergeSeed);
        else cost = _mergeShieldImpl(mainId, subId, warehouse, subIdx, mergeSeed);

        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();
        _gameAssets.burn(msg.sender, subId, 1);
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
    }

    function _mergeSwordImpl(
        uint256 mainId,
        uint256 subId,
        uint256[] storage warehouse,
        uint256 subIdx,
        bytes32 mergeSeed
    ) private returns (uint256 cost) {
        Sword storage mainRef = findSword(mainId);
        Sword storage subRef = findSword(subId);
        if (mainRef.materials != subRef.materials || mainRef.rarity != subRef.rarity) revert CannotMerge();
        if (mainRef.rarity == Rarity.S) revert ReachedMaxLevel();
        cost = Property.mergeEquipmentCost(mainRef.level, mainRef.rarity);
        if (Property.determineMerge(uint8(mergeSeed[0]), mainRef.rarity)) _swordEvolve(mainRef);
        delete warehouse[subIdx];
        clearSword(subId);
    }

    function _mergeArmorImpl(
        uint256 mainId,
        uint256 subId,
        uint256[] storage warehouse,
        uint256 subIdx,
        bytes32 mergeSeed
    ) private returns (uint256 cost) {
        Armor storage mainRef = findArmor(mainId);
        Armor storage subRef = findArmor(subId);
        if (mainRef.materials != subRef.materials || mainRef.rarity != subRef.rarity) revert CannotMerge();
        if (mainRef.rarity == Rarity.S) revert ReachedMaxLevel();
        cost = Property.mergeEquipmentCost(mainRef.level, mainRef.rarity);
        if (Property.determineMerge(uint8(mergeSeed[0]), mainRef.rarity)) _armorEvolve(mainRef);
        delete warehouse[subIdx];
        clearArmor(subId);
    }

    function _mergeShieldImpl(
        uint256 mainId,
        uint256 subId,
        uint256[] storage warehouse,
        uint256 subIdx,
        bytes32 mergeSeed
    ) private returns (uint256 cost) {
        Shield storage mainRef = findShield(mainId);
        Shield storage subRef = findShield(subId);
        if (mainRef.rarity != subRef.rarity) revert CannotMerge();
        if (mainRef.rarity == Rarity.S) revert ReachedMaxLevel();
        cost = Property.mergeEquipmentCost(mainRef.level, mainRef.rarity);
        if (Property.determineMerge(uint8(mergeSeed[0]), mainRef.rarity)) _shieldEvolve(mainRef);
        delete warehouse[subIdx];
        clearShield(subId);
    }

    function _swordEvolve(Sword storage sword) private {
        Rarity newRarity = Rarity(uint8(sword.rarity) + 1);
        sword.rarity = newRarity;
        (uint16 crit, uint16 critChance,, uint16 stunChance) = Property.calSecondAttributes(newRarity);
        sword.attack = Property.calAttackForSword(newRarity, sword.level);
        sword.crit = crit;
        sword.critChance = critChance;
        sword.stunChance = stunChance;
    }

    function _armorEvolve(Armor storage armor) private {
        Rarity newRarity = Rarity(uint8(armor.rarity) + 1);
        armor.rarity = newRarity;
        armor.defense = Property.calDefenseForArmor(newRarity, armor.level);
    }

    function _shieldEvolve(Shield storage shield) private {
        Rarity newRarity = Rarity(uint8(shield.rarity) + 1);
        shield.rarity = newRarity;
        (,, uint16 blockChance, uint16 stunChance) = Property.calSecondAttributes(newRarity);
        shield.blockChance = blockChance;
        shield.stunChance = stunChance;
        shield.defense = Property.calDefenseForShield(newRarity, shield.level);
    }

    function getFloor(address addr) external view returns (Floor memory) {
        return findFloor(addr);
    }

    function getEnemies(address addr) external view returns (Aoka[] memory) {
        return findFloor(addr).enemies;
    }

    function getPlayer(address addr) external view returns (Player memory) {
        return findPlayer(addr);
    }

    function getBag(address addr) external view returns (uint256[] memory itemIds) {
        return _copyUint256Array(findBag(addr));
    }

    function getWarehouse(address addr) external view returns (uint256[] memory weaponIds) {
        return _copyUint256Array(findWarehouse(addr));
    }

    function _copyUint256Array(uint256[] storage source) private view returns (uint256[] memory result) {
        uint256 len = source.length;
        result = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = source[i];
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

    function _healToFullCost(uint8 level) private pure returns (uint256) {
        // lv.1 costs 7
        // lv.100 costs 205
        unchecked {
            return (5 + uint256(level) * 2) * 1 ether;
        }
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

        // add consumable rewards (book/potion) to bag
        if (assetIds.length > 2) {
            uint256 itemCount = assetIds.length - 2;
            uint256[] memory itemIds = new uint256[](itemCount);
            for (uint256 i = 0; i < itemCount; i++) {
                itemIds[i] = assetIds[i];
            }
            addItems(winner, itemIds);
        }
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
        if (floor.index != 0) revert WrongFloorIndex();

        _constructFloorData(floor, floor.index, seed);
    }

    function _nextFloor(address addr, bytes32 seed) private {
        Floor storage floor = findFloor(addr);
        uint8 curIndex = floor.index;
        // can't exceed 99
        if (curIndex >= 99) revert ReachedTheTopFloor();

        uint256 enemyCount = floor.enemies.length;
        for (uint256 i = 0; i < enemyCount; i++) {
            if (floor.enemies[i].health > 0) {
                revert MustDefeatAllEenemies();
            }
        }

        Environment.clearFloor(floor);
        // next
        floor.index = curIndex + 1;
        _constructFloorData(floor, floor.index, seed);
    }

    function _circle(address addr, bytes32 seed) private {
        Floor storage floor = findFloor(addr);
        if (floor.index != 99) revert NotAt100Floor();

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
        uint256 aokaCount = Environment.aokaCountNextFloor(uint8(seed[2]), floorIndex, shopCount, foundryCount);

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

    function _getEquipmentLevel(uint256 equipmentId, EquipmentType typ) private view returns (uint8) {
        if (typ == EquipmentType.Sword) return findSword(equipmentId).level;
        if (typ == EquipmentType.Armor) return findArmor(equipmentId).level;
        return findShield(equipmentId).level;
    }

    function _upgradeEquipment(uint256 equipmentId, EquipmentType typ) private {
        if (typ == EquipmentType.Sword) {
            Sword storage s = findSword(equipmentId);
            s.level++;
            s.attack = Property.calAttackForSword(s.rarity, s.level);
        } else if (typ == EquipmentType.Armor) {
            Armor storage a = findArmor(equipmentId);
            a.level++;
            a.defense = Property.calDefenseForArmor(a.rarity, a.level);
        } else {
            Shield storage s = findShield(equipmentId);
            s.level++;
            s.defense = Property.calDefenseForShield(s.rarity, s.level);
        }
    }

    function _onlyRegistered() private view {
        if (findPlayer(msg.sender).createAt == 0) {
            revert PlayerNotFound(msg.sender);
        }
    }
}
