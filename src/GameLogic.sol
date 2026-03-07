// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IGameLogic} from "./interfaces/IGameLogic.sol";
import {IHeroLogic} from "./interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "./interfaces/IInventoryLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {Player, AbilitiesExtra, Character} from "./libraries/Character.sol";
import {Rarity} from "./libraries/Attribute.sol";
import {Aoka} from "./libraries/Enemy.sol";
import {Battle} from "./libraries/Battle.sol";
import {Property, Equipment, EquipmentType, EquipmentMaterials} from "./libraries/Property.sol";
import {Floor} from "./libraries/Environment.sol";
import {Seed} from "./libraries/Seed.sol";
import {Randao} from "./random/Randao.sol";

/**
 * @title GameLogic
 * @author Jan
 * @notice Single entry point for the tower-climb game. Holds no game state; delegates to HeroLogic (player/floor/combat)
 *         and InventoryLogic (bag, warehouse, equipment, shop). Manages token/asset mint and burn for deposits,
 *         withdrawals, born, battle rewards, and in-game purchases.
 * @dev Used behind a proxy (e.g. GameV1). Dependencies are set in initialize(): _heroLogic, _inventoryLogic,
 *      _gameToken, _gameAssets. Only the permitted Game proxy should call Hero/Inventory; users call this contract.
 */
abstract contract GameLogic is IGameLogic, Randao {
    using Seed for bytes32;

    IHeroLogic public _heroLogic;
    IInventoryLogic public _inventoryLogic;
    IGameToken public _gameToken;
    IGameAssets public _gameAssets;

    //word floor
    bytes32 private constant SEED_MIX_FLOOR = 0x666C6F6F72000000000000000000000000000000000000000000000000000000;
    //word circle
    bytes32 private constant SEED_MIX_CIRCLE = 0x636972636c650000000000000000000000000000000000000000000000000000;

    modifier onlyRegistered() {
        _onlyRegistered();
        _;
    }

    /// @notice create a player
    function born() external {
        if (_heroLogic.getPlayer(msg.sender).createAt > 0) revert PlayerAlreadyExists();
        _heroLogic.addPlayer(msg.sender, Character.initPlayer());

        uint256 itemId = Property.POTION_C_ID;
        _inventoryLogic.addItem(msg.sender, itemId);

        uint256 swordId = _inventoryLogic.addEquipment(msg.sender, _newHandSword());
        uint256 puppetId = _inventoryLogic.addPuppet(msg.sender, uint8(Rarity.C), uint40(block.timestamp));

        uint256[] memory ids = new uint256[](3);
        uint256[] memory values = new uint256[](3);
        ids[0] = itemId;
        ids[1] = swordId;
        ids[2] = puppetId;
        values[0] = 1;
        values[1] = 1;
        values[2] = 1;
        _gameAssets.mintBatch(msg.sender, ids, values, "");
        _gameToken.mint(msg.sender, 1 ether);

        bytes32 seed = getSeed().change(5, SEED_MIX_FLOOR);
        _heroLogic.initFloor(msg.sender, seed);

        emit Born(msg.sender);
    }

    function deposit(uint256 amount) external {
        if (amount < 1 ether) revert AmountAtLeast1e18();
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        _gameToken.transferFrom(msg.sender, address(this), amount);
        _gameAssets.mint(msg.sender, Property.COIN_ID, amount * 10, "");
    }

    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (amount < 1 ether) revert AmountAtLeast1e18();
        _gameToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        _gameToken.transferFrom(msg.sender, address(this), amount);
        _gameAssets.mint(msg.sender, Property.COIN_ID, amount * 10, "");
    }

    function withdraw(uint256 amount) external {
        if (amount < 1 gwei) revert AmountAtLeast1e9();
        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < amount) revert InsufficientCoin();
        _gameAssets.burn(msg.sender, Property.COIN_ID, amount);
        uint256 token = amount / 10;
        if (_gameToken.balanceOf(address(this)) < token) revert InsufficientERC20();
        uint256 burnAmount = token / 20;
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        _gameToken.transfer(msg.sender, token - burnAmount);
        _gameToken.burn(address(this), burnAmount);
    }

    function battle(uint256 enemySlot) external onlyRegistered {
        bytes32 seed = getSeed();
        uint256[4] memory equippedIds = _heroLogic.getEquippedIds(msg.sender);
        (Equipment memory e0, Equipment memory e1, Equipment memory e2) = _getEquipped(equippedIds);

        AbilitiesExtra memory ae = AbilitiesExtra({
            attack: e0.attack,
            defense: e1.defense + e2.defense,
            crit: e0.crit,
            critChance: e0.critChance,
            stunChance: e0.stunChance + e2.stunChance,
            blockChance: e2.blockChance,
            weaponMaterialsIdx: uint8(e0.materials),
            armorEquipped: e1.level == 0,
            armorMaterialsIdx: uint8(e1.materials)
        });

        (bool playerWin, uint8 curFloorIndex, uint8 enemyLevel) = _heroLogic.combat(msg.sender, seed, enemySlot, ae);

        if (playerWin) {
            (uint256[] memory assetIds, uint256[] memory values) =
                _inventoryLogic.rewardWinner(msg.sender, seed, curFloorIndex);
            _gameAssets.mintBatch(msg.sender, assetIds, values, "");
            _heroLogic.playerLevelUp(msg.sender, Battle.calRewardExperience(enemyLevel, curFloorIndex));
        }
    }

    function nextFloor() external onlyRegistered {
        _heroLogic.nextFloor(msg.sender, getSeed());
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

    function fullHeal() external onlyRegistered {
        Player memory player = _heroLogic.getPlayer(msg.sender);
        uint16 healthMax = player.healthMax;
        if (player.health >= healthMax) revert AlreadyFullHealth();
        uint256 cost = _healToFullCost(player.level);
        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
        _heroLogic.setPlayerHealth(msg.sender, healthMax);
    }

    function equip(uint256 equipmentId) external onlyRegistered {
        if (!_inventoryLogic.isValidEquipment(equipmentId)) revert InvalidEquipmentId(equipmentId);
        _inventoryLogic.removeFromWarehouse(msg.sender, equipmentId);
        uint256 slot = equipmentId >= 4e9 ? 3 : uint256(_inventoryLogic.getEquipment(equipmentId).etype);
        _heroLogic.equip(msg.sender, equipmentId, slot);
    }

    function unequip(uint256 equipmentId) external onlyRegistered {
        if (!_inventoryLogic.isValidEquipment(equipmentId)) revert InvalidEquipmentId(equipmentId);
        _heroLogic.unequip(msg.sender, equipmentId);
        _inventoryLogic.addToWarehouse(msg.sender, equipmentId);
    }

    function buy(uint256 typeIndex, uint256 slot) external onlyRegistered {
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

        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();
        _heroLogic.removeShopSlot(msg.sender, typeIndex, slot);
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
        _gameAssets.mint(msg.sender, assetId, 1, "");
    }

    function upgrade(uint256 equipmentId) external onlyRegistered {
        uint256 cost = _inventoryLogic.upgrade(msg.sender, equipmentId, getSeed());
        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
    }

    function mergeSword(uint256 mainEquipmentId, uint256 subEquipmentId) external onlyRegistered {
        _mergeEquipment(0, mainEquipmentId, subEquipmentId);
    }

    function mergeArmor(uint256 mainEquipmentId, uint256 subEquipmentId) external onlyRegistered {
        _mergeEquipment(1, mainEquipmentId, subEquipmentId);
    }

    function mergeShield(uint256 mainEquipmentId, uint256 subEquipmentId) external onlyRegistered {
        _mergeEquipment(2, mainEquipmentId, subEquipmentId);
    }

    function _mergeEquipment(uint256 slot, uint256 mainEquipmentId, uint256 subEquipmentId) private {
        uint256[4] memory ids = _heroLogic.getEquippedIds(msg.sender);
        if (ids[slot] != mainEquipmentId) revert InvalidEquipmentId(mainEquipmentId);
        uint256 cost = _inventoryLogic.mergeEquipment(msg.sender, mainEquipmentId, subEquipmentId, getSeed());
        if (_gameAssets.balanceOf(msg.sender, Property.COIN_ID) < cost) revert InsufficientCoin();
        _gameAssets.burn(msg.sender, subEquipmentId, 1);
        _gameAssets.burn(msg.sender, Property.COIN_ID, cost);
    }

    function circle() external onlyRegistered {
        bytes32 seed = getSeed().change(6, SEED_MIX_CIRCLE);
        _heroLogic.circle(msg.sender, seed);
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

    function _getEquipped(uint256[4] memory ids)
        internal
        view
        returns (Equipment memory e0, Equipment memory e1, Equipment memory e2)
    {
        if (ids[0] > 0) e0 = _inventoryLogic.getEquipment(ids[0]);
        if (ids[1] > 0) e1 = _inventoryLogic.getEquipment(ids[1]);
        if (ids[2] > 0) e2 = _inventoryLogic.getEquipment(ids[2]);
    }

    function _healToFullCost(uint8 level) internal pure returns (uint256) {
        unchecked {
            return (5 + uint256(level) * 2) * 1 ether;
        }
    }

    function _newHandSword() private pure returns (Equipment memory) {
        return Equipment({
            etype: EquipmentType.Sword,
            materials: EquipmentMaterials.Iron,
            rarity: Rarity.C,
            level: 1,
            attack: 8,
            defense: 0,
            crit: 0,
            critChance: 0,
            blockChance: 0,
            stunChance: 0
        });
    }

    function _onlyRegistered() private view {
        if (_heroLogic.getPlayer(msg.sender).createAt == 0) {
            revert PlayerNotFound(msg.sender);
        }
    }
}

