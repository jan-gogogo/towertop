// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Seed} from "./libraries/Seed.sol";
import {Aoka} from "./libraries/Enemy.sol";
import {Battle} from "./libraries/Battle.sol";
import {Randao} from "./libraries/Randao.sol";
import {Rarity} from "./libraries/Attribute.sol";
import {Floor} from "./libraries/Environment.sol";
import {IGameLogic} from "./interfaces/IGameLogic.sol";
import {IHeroLogic} from "./interfaces/IHeroLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {IProtocol} from "./interfaces/IProtocol.sol";
import {IInventoryLogic} from "./interfaces/IInventoryLogic.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Player, AbilitiesExtra, Character, RewardWinner} from "./libraries/Character.sol";
import {VRFV2PlusClient} from "@chainlink/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Property, Equipment, EquipmentType, EquipmentMaterials} from "./libraries/Property.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Upgradeable} from "@chainlink/src/v0.8/vrf/dev/VRFConsumerBaseV2Upgradeable.sol";

/**
 * @title GameLogic
 * @author Jan
 * @notice Single entry point for the tower-climb game. Holds no game state; delegates to HeroLogic (player/floor/combat)
 *         and InventoryLogic (bag, warehouse, equipment, shop). Manages token/asset mint and burn for deposits,
 *         withdrawals, born, battle rewards, and in-game purchases.
 * @dev Used behind a proxy (e.g. GameV1). Dependencies are set in initialize(): _heroLogic, _inventoryLogic,
 *      _gameToken, _gameAssets. Only the permitted Game proxy should call Hero/Inventory; users call this contract.
 */
abstract contract GameLogic is VRFConsumerBaseV2Upgradeable, IGameLogic {
    using Seed for bytes32;

    //word floor
    bytes32 private constant SEED_MIX_FLOOR = 0x666C6F6F72000000000000000000000000000000000000000000000000000000;
    //word circle
    bytes32 private constant SEED_MIX_CIRCLE = 0x636972636c650000000000000000000000000000000000000000000000000000;

    // chainlink
    bytes32 public _keyHash;
    uint256 public _subscription;

    IProtocol public _protocol;
    IHeroLogic public _heroLogic;
    IGameToken public _gameToken;
    IGameAssets public _gameAssets;
    IInventoryLogic public _inventoryLogic;

    IVRFCoordinatorV2Plus public _vrfCoordinator;

    mapping(uint256 requestId => RewardWinner) private _rewards;

    modifier onlyRegistered() {
        _onlyRegistered();
        _;
    }

    modifier onlyOwnerAndValid(uint256 equipmentId) {
        _onlyOwnerAndValid(equipmentId);
        _;
    }

    /// @notice create a player
    function born() external {
        if (_heroLogic.getPlayer(msg.sender).createAt > 0) revert PlayerAlreadyExists();
        _heroLogic.addPlayer(msg.sender, Character.initPlayer());

        uint256 swordId = _inventoryLogic.addEquipment(msg.sender, _newHandSword());
        _gameAssets.mint(msg.sender, swordId, 1, "");

        bytes32 seed = Randao.getSeed().change(5, SEED_MIX_FLOOR);
        _heroLogic.initFloor(msg.sender, seed);

        emit Born(msg.sender);
    }

    // function deposit(uint256 amount) external {
    //     if (amount < 1 ether) revert AmountAtLeast1e18();
    //     // forge-lint: disable-next-line(erc20-unchecked-transfer)
    //     _gameToken.transferFrom(msg.sender, address(this), amount);
    //     _gameAssets.mint(msg.sender, Property.COIN_ID, amount * 10, "");
    // }

    // function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    //     if (amount < 1 ether) revert AmountAtLeast1e18();
    //     _gameToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
    //     // forge-lint: disable-next-line(erc20-unchecked-transfer)
    //     _gameToken.transferFrom(msg.sender, address(this), amount);
    //     _gameAssets.mint(msg.sender, Property.COIN_ID, amount * 10, "");
    // }

    // function withdraw(uint256 amount) external {
    //     if (amount < 1 gwei) revert AmountAtLeast1e9();
    //     if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < amount) revert InsufficientCoin();
    //     _gameAssets.burn(msg.sender, Property.COIN_ID, amount);
    //     uint256 token = amount / 10;
    //     if (_gameToken.balanceOf(address(this)) < token) revert InsufficientERC20();
    //     uint256 burnAmount = token / 20;
    //     // forge-lint: disable-next-line(erc20-unchecked-transfer)
    //     _gameToken.transfer(msg.sender, token - burnAmount);
    //     _gameToken.burn(address(this), burnAmount);
    // }

    function battle(uint256 enemySlot) external onlyRegistered {
        bytes32 seed = Randao.getSeed();
        uint256[3] memory equippedIds = _heroLogic.getEquippedIds(msg.sender);
        (Equipment memory sword, Equipment memory armor, Equipment memory shield) = _getEquipped(equippedIds);

        AbilitiesExtra memory ae = AbilitiesExtra({
            attack: sword.attack,
            defense: armor.defense + shield.defense,
            crit: sword.crit,
            critChance: sword.critChance,
            stunChance: shield.stunChance,
            blockChance: armor.blockChance,
            weaponMaterialsIdx: uint8(sword.materials),
            armorEquipped: armor.level == 0,
            armorMaterialsIdx: uint8(armor.materials)
        });

        (bool playerWin, uint8 curFloorIndex, uint8 enemyLevel) = _heroLogic.combat(msg.sender, seed, enemySlot, ae);
        if (playerWin) {
            // Request Chainlink VRF random words for generating battle reward loot
            // _requestRandomWordsForReward(msg.sender, curFloorIndex);

            // ============================template============================
            (uint256[] memory assetIds, uint256[] memory values) =
                _inventoryLogic.rewardWinner(msg.sender, seed, curFloorIndex);

            if (assetIds.length > 0 && values.length > 0) {
                _gameAssets.mintBatch(msg.sender, assetIds, values, "");
            }
            // ================================================================

            _heroLogic.playerLevelUp(msg.sender, Battle.calRewardExperience(enemyLevel, curFloorIndex));
        }
    }

    function nextFloor() external onlyRegistered {
        _heroLogic.nextFloor(msg.sender, Randao.getSeed());
    }

    /// @notice currently, only Book and Potion can be used
    function useItems(uint256[] calldata slots) external onlyRegistered {
        uint256 len = slots.length;
        if (len == 0 || len > 5) revert LengthOutOfRange1To5();
        for (uint256 i = 1; i < len; i++) {
            if (slots[i] <= slots[i - 1]) revert WrongSequence();
        }
        (uint32 totalExpGain, uint16 totalHealthGain) = _inventoryLogic.useItems(msg.sender, slots);
        if (totalExpGain > 0) _heroLogic.playerLevelUp(msg.sender, totalExpGain);
        if (totalHealthGain > 0) {
            Player memory p = _heroLogic.getPlayer(msg.sender);
            uint16 newHealth = p.health + totalHealthGain;
            if (newHealth > p.healthMax) newHealth = p.healthMax;
            _heroLogic.setPlayerHealth(msg.sender, newHealth);
        }
    }

    function fullHeal(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external onlyRegistered {
        Player memory player = _heroLogic.getPlayer(msg.sender);
        uint16 healthMax = player.healthMax;
        if (player.health >= healthMax) revert AlreadyFullHealth();

        Floor memory floor = _heroLogic.getFloor(msg.sender);
        uint256 cost = _healCost(healthMax - player.health, floor.index);
        if (cost != amount) revert WrongPaymentAmount(cost, amount);

        _heroLogic.setPlayerHealth(msg.sender, healthMax);
        _deductTokens(amount, deadline, v, r, s);
    }

    function equip(uint256 equipmentId) external onlyRegistered onlyOwnerAndValid(equipmentId) {
        _inventoryLogic.removeFromWarehouse(msg.sender, equipmentId);
        uint256 slot = equipmentId >= 4e9 ? 3 : uint256(_inventoryLogic.getEquipment(equipmentId).etype);
        _heroLogic.equip(msg.sender, equipmentId, slot);
    }

    function unequip(uint256 equipmentId) external onlyRegistered onlyOwnerAndValid(equipmentId) {
        _heroLogic.unequip(msg.sender, equipmentId);
        _inventoryLogic.addToWarehouse(msg.sender, equipmentId);
    }

    function buy(uint256 typeIndex, uint256 slot, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        onlyRegistered
    {
        if (typeIndex > 1) revert InvalidTypeIndex(typeIndex);
        Floor memory floor = _heroLogic.getFloor(msg.sender);
        uint256 cost;
        uint256 assetId;

        if (typeIndex == 0) {
            if (slot >= floor.shop.items.length) revert InvalidIndex(slot);
            assetId = floor.shop.items[slot];
            if (assetId == 0) revert InvalidIndex(slot);
            cost = _inventoryLogic.buyFromShopItem(msg.sender, assetId);
        } else {
            if (slot >= floor.shop.equipments.length) revert InvalidIndex(slot);
            Equipment memory eq = floor.shop.equipments[slot];
            if (eq.level == 0) revert InvalidIndex(slot);
            (cost, assetId) = _inventoryLogic.buyFromShopEquipment(msg.sender, eq);
        }

        _deductTokens(amount, deadline, v, r, s);
        if (cost != amount) revert WrongPaymentAmount(cost, amount);

        _heroLogic.removeShopSlot(msg.sender, typeIndex, slot);
        _gameAssets.mint(msg.sender, assetId, 1, "");
    }

    function upgrade(uint256 equipmentId, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        onlyRegistered
        onlyOwnerAndValid(equipmentId)
    {
        (uint256 cost, uint256 ingredients) = _inventoryLogic.upgrade(msg.sender, equipmentId, Randao.getSeed());

        if (_gameAssets.balanceOf(msg.sender, Property.REFINING_STONE_ID) < ingredients) {
            revert InsufficientRefiningStones();
        }
        if (amount != cost) revert WrongPaymentAmount(cost, amount);

        _gameAssets.burn(msg.sender, Property.REFINING_STONE_ID, ingredients);
        _deductTokens(amount, deadline, v, r, s);
    }

    function mergeSword(
        uint256 mainEquipmentId,
        uint256 subEquipmentId,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyRegistered onlyOwnerAndValid(mainEquipmentId) onlyOwnerAndValid(subEquipmentId) {
        _mergeEquipment(0, mainEquipmentId, subEquipmentId, amount, deadline, v, r, s);
    }

    function mergeArmor(
        uint256 mainEquipmentId,
        uint256 subEquipmentId,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyRegistered onlyOwnerAndValid(mainEquipmentId) onlyOwnerAndValid(subEquipmentId) {
        _mergeEquipment(1, mainEquipmentId, subEquipmentId, amount, deadline, v, r, s);
    }

    function mergeShield(
        uint256 mainEquipmentId,
        uint256 subEquipmentId,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyRegistered onlyOwnerAndValid(mainEquipmentId) onlyOwnerAndValid(subEquipmentId) {
        _mergeEquipment(2, mainEquipmentId, subEquipmentId, amount, deadline, v, r, s);
    }

    function dismantle(uint256 equipmentId) external onlyRegistered onlyOwnerAndValid(equipmentId) {
        Equipment memory e = _inventoryLogic.getEquipment(equipmentId);
        uint256 stones = Property.getRefiningStoneFromDismantle(e.attack, e.defense, e.rarity);

        if (_heroLogic.isEquiped(msg.sender, equipmentId)) {
            _heroLogic.unequip(msg.sender, equipmentId);
        } else {
            _inventoryLogic.removeFromWarehouse(msg.sender, equipmentId);
        }

        _gameAssets.burn(msg.sender, equipmentId, 1);
        _gameAssets.mint(msg.sender, Property.REFINING_STONE_ID, stones, "");
    }

    function _mergeEquipment(
        uint256 slot,
        uint256 mainEquipmentId,
        uint256 subEquipmentId,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private {
        uint256[3] memory ids = _heroLogic.getEquippedIds(msg.sender);
        if (ids[slot] != mainEquipmentId) revert InvalidEquipmentId(mainEquipmentId);
        uint256 cost = _inventoryLogic.mergeEquipment(msg.sender, mainEquipmentId, subEquipmentId, Randao.getSeed());

        if (amount != cost) revert WrongPaymentAmount(cost, amount);
        _deductTokens(amount, deadline, v, r, s);

        _gameAssets.burn(msg.sender, subEquipmentId, 1);
    }

    function circle(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external onlyRegistered {
        bytes32 seed = Randao.getSeed().change(6, SEED_MIX_CIRCLE);
        uint256 cost = _heroLogic.circle(msg.sender, seed);
        if (cost == 0) return;
        if (cost != amount) revert WrongPaymentAmount(cost, amount);
        _deductTokens(amount, deadline, v, r, s);
    }

    function getFloor(address addr) external view returns (Floor memory) {
        return _heroLogic.getFloor(addr);
    }

    function getEnemies(address addr) external view returns (Aoka[] memory) {
        return _heroLogic.getEnemies(addr);
    }

    function getPlayer(address addr) external view returns (Player memory) {
        return _heroLogic.getPlayer(addr);
    }

    function getBag(address addr) external view returns (uint256[] memory) {
        return _inventoryLogic.getBag(addr);
    }

    function getWarehouse(address addr) external view returns (uint256[] memory) {
        return _inventoryLogic.getWarehouse(addr);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        RewardWinner storage rw = _rewards[requestId];
        if (rw.player == address(0)) return;
        // Prevent reentrancy
        // floorIndex == uint256.max means we have already processed this request
        if (rw.floorIndex == type(uint256).max) return;

        // Ideally, we should only store requestId and random here
        // and then use a backend service to fetch data and execute rewardWinner()
        // However, we do not want to start a backend service, so we let Chainlink's VRF coordinator
        // directly execute the rewardWinner() logic here
        uint256 random = randomWords[0];
        (uint256[] memory assetIds, uint256[] memory values) =
            _inventoryLogic.rewardWinner(rw.player, bytes32(random), rw.floorIndex);

        if (assetIds.length > 0 && values.length > 0) {
            _gameAssets.mintBatch(rw.player, assetIds, values, "");
        }
        delete _rewards[requestId];
        // Mark as processed
        rw.floorIndex = type(uint256).max;
        emit FulfillRandom(rw.player, requestId, random);
    }

    function _getEquipped(uint256[3] memory ids)
        internal
        view
        returns (Equipment memory e0, Equipment memory e1, Equipment memory e2)
    {
        if (ids[0] > 0) e0 = _inventoryLogic.getEquipment(ids[0]);
        if (ids[1] > 0) e1 = _inventoryLogic.getEquipment(ids[1]);
        if (ids[2] > 0) e2 = _inventoryLogic.getEquipment(ids[2]);
    }

    function _healCost(uint256 healAmount, uint256 floorIndex) internal pure returns (uint256) {
        // F1: each 1 HP healed ≈ 0.0025 token
        // F50: each 1 HP healed ≈ 0.125 token
        // F100: each 1 HP healed ≈ 0.25 token
        return Math.mulDiv(healAmount, floorIndex * 1 ether, 400, Math.Rounding.Ceil);
    }

    function _newHandSword() private pure returns (Equipment memory) {
        return Equipment({
            etype: EquipmentType.Sword,
            materials: EquipmentMaterials.Iron,
            rarity: Rarity.C,
            level: 1,
            attack: 7,
            defense: 0,
            crit: 0,
            critChance: 0,
            blockChance: 0,
            stunChance: 0,
            growth: 140
        });
    }

    function _requestRandomWordsForReward(address addr, uint256 floorIndex) private {
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: _keyHash,
                subId: _subscription,
                requestConfirmations: 5,
                callbackGasLimit: 250000,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        _rewards[requestId] = RewardWinner({player: addr, floorIndex: floorIndex});
        emit RequestRandom(addr, requestId, floorIndex);
    }

    function _spendToken(address account, uint256 amount) private {
        _gameToken.burnFromApprove(account, amount);
        _protocol.syncFloorPriceAfterBurn();
    }

    function _deductTokens(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) private {
        _gameToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        _gameToken.burnFromApprove(msg.sender, amount);
        _protocol.syncFloorPriceAfterBurn();
    }

    function _onlyOwnerAndValid(uint256 equipmentId) private view {
        if (_gameAssets.balanceOf(msg.sender, equipmentId) == 0) {
            revert NotYourAsset(equipmentId);
        }
        if (!_inventoryLogic.isValidEquipment(equipmentId)) {
            revert InvalidEquipment(equipmentId);
        }
    }

    function _onlyRegistered() private view {
        if (_heroLogic.getPlayer(msg.sender).createAt == 0) {
            revert PlayerNotFound(msg.sender);
        }
    }
}

