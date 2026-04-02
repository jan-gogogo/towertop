// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IInventoryLogic} from "./interfaces/IInventoryLogic.sol";
import {Rarity} from "./libraries/Attribute.sol";
import {Property, Equipment, Puppet, EquipmentType, ItemType, EquipmentMaterials} from "./libraries/Property.sol";
import {Seed} from "./libraries/Seed.sol";
import {Battle} from "./libraries/Battle.sol";
import {Rarity} from "./libraries/Attribute.sol";

/**
 * @title InventoryLogic
 * @author Jan
 * @notice Holds bag, warehouse, equipment and puppet data. Handles add/remove items, use consumables (book/potion),
 *         shop buy, equipment upgrade/merge, and battle rewards. Callable only by the permitted Game proxy.
 * @dev Used behind a proxy (e.g. InventoryV1). setPermit(gameProxy) must be called once after deployment.
 *      Equipment IDs: 1e9..4e9-1 for gear, 4e9..5e9-1 for puppets.
 */
abstract contract InventoryLogic is IInventoryLogic {
    using Seed for bytes32;

    // word "upgrade"
    bytes32 private constant SEED_MIX_UPGRADE = 0x7570677261646500000000000000000000000000000000000000000000000000;
    // word "merge"
    bytes32 private constant SEED_MIX_MERGE = 0x6d65726765000000000000000000000000000000000000000000000000000000;
    // word "reward"
    bytes32 private constant SEED_MIX_REWARD = 0x7265776172640000000000000000000000000000000000000000000000000000;
    uint256 private constant EMPTY_SLOT = 0;
    uint256 private constant BAG_CAP = 100;
    uint256 private constant WAREHOUSE_CAP = 100;
    uint256 private constant EQUIPMENT_ID_START = 1e9;
    uint256 private constant EQUIPMENT_ID_CAP = 4e9;
    uint256 private constant PUPPET_ID_START = 4e9;
    uint256 private constant PUPPET_ID_CAP = 5e9;

    address public _permit;

    mapping(address => uint256[]) private _bag;
    mapping(address => uint256[]) private _warehouse;
    mapping(uint256 id => Equipment) private _equipments;
    mapping(uint256 id => Puppet) private _puppets;

    uint256 private _nextEquipmentId;
    uint256 private _nextPuppetId;

    modifier onlyPermit() {
        _onlyPermit();
        _;
    }

    function setPermit(address permit_) external {
        if (_permit != address(0)) revert Unauthorized();
        _permit = permit_;
    }

    function addItem(address addr, uint256 itemId) external onlyPermit {
        _addItemBatch(addr, Property.asSingletonArrays(itemId));
    }

    function addItems(address addr, uint256[] calldata itemIds) external onlyPermit {
        _addItemBatch(addr, itemIds);
    }

    function addEquipment(address addr, Equipment calldata equipment)
        external
        onlyPermit
        returns (uint256 equipmentId)
    {
        return _addEquipmentInternal(addr, equipment);
    }

    function addPuppet(address addr, uint8 rarity, uint40 lastClaimAt) external onlyPermit returns (uint256 puppetId) {
        uint256 latest = _nextPuppetId;
        if (latest >= PUPPET_ID_CAP) revert CapacityExceeded();
        _puppets[latest] = Puppet({rarity: Rarity(rarity), lastClaimAt: lastClaimAt});
        _nextPuppetId++;
        _addToWarehouse(addr, latest);
        return latest;
    }

    function removeFromWarehouse(address addr, uint256 equipmentId) external onlyPermit {
        uint256[] storage wh = _warehouse[addr];
        uint256 len = wh.length;
        bool found = false;
        for (uint256 i = 0; i < len; i++) {
            if (wh[i] == equipmentId) {
                delete wh[i];
                found = true;
                break;
            }
        }
        if (!found) revert EquipmentNotFound(equipmentId);
    }

    function addToWarehouse(address addr, uint256 equipmentId) external onlyPermit {
        _addToWarehouse(addr, equipmentId);
    }

    function useItems(address addr, uint256[] calldata slots)
        external
        onlyPermit
        returns (uint32 totalExpGain, uint16 totalHealthGain)
    {
        uint256 len = slots.length;
        if (len == 0 || len > 5) revert LengthOutOfRange1To5();
        for (uint256 i = 1; i < len; i++) {
            if (slots[i] <= slots[i - 1]) revert WrongSequence();
        }
        uint256[] storage items = _bag[addr];
        uint256 bagLen = items.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 slot = slots[i];
            if (slot >= bagLen) revert ItemNotFound(slot);
            uint256 itemId = items[slot];
            if (itemId == 0) revert ItemNotFound(slot);
            ItemType typ = Property.typeFromItemId(itemId);
            if (typ == ItemType.Book) {
                totalExpGain += Property.calBookValue(itemId);
            } else if (typ == ItemType.Potion) {
                totalHealthGain += Property.calPotionValue(itemId);
            } else {
                revert WrongItemType();
            }
        }
        _delItems(addr, slots);
    }

    function buyFromShopItem(address addr, uint256 itemId) external onlyPermit returns (uint256 cost) {
        cost = Property.itemCost(itemId);
        _addItemBatch(addr, Property.asSingletonArrays(itemId));
    }

    function buyFromShopEquipment(address addr, Equipment calldata equipment)
        external
        onlyPermit
        returns (uint256 cost, uint256 assetId)
    {
        cost = Property.equipmentCost(equipment.level, equipment.rarity);
        assetId = _addEquipmentInternal(addr, equipment);
    }

    function upgrade(address, uint256 equipmentId, bytes32 seed) external onlyPermit returns (uint256 cost) {
        if (equipmentId == 0) revert InvalidEquipmentId(equipmentId);
        Equipment storage e = _equipments[equipmentId];
        if (equipmentId >= PUPPET_ID_START) revert InvalidEquipmentId(equipmentId);
        uint8 curLevel = e.level;
        if (curLevel >= Property.MAX_EQUIPMENT_LEVEL) revert ReachedMaxLevel();
        cost = Property.upgradeEquipmentCost(curLevel);
        bytes32 upgradeSeed = seed.change(7, SEED_MIX_UPGRADE);
        if (Property.determineUpgrade(uint8(upgradeSeed[0]), curLevel)) {
            _upgradeEquipment(equipmentId);
        }
    }

    function mergeEquipment(address addr, uint256 mainId, uint256 subId, bytes32 seed)
        external
        onlyPermit
        returns (uint256 cost)
    {
        if (mainId == 0 || subId == 0) revert InvalidEquipmentId(0);
        Equipment storage mainRef = _equipments[mainId];
        if (mainId >= PUPPET_ID_START) revert InvalidEquipmentId(mainId);
        return _mergeEquipment(addr, mainRef.etype, mainId, subId, seed);
    }

    function rewardWinner(address winner, bytes32 seed, uint256 floorIndex)
        external
        onlyPermit
        returns (uint256[] memory assetIds, uint256[] memory values)
    {
        bytes32 rewardSeed = seed.change(6, SEED_MIX_REWARD);
        uint256 equipmentId = 0;
        if (Battle.equipmentDetermine(uint8(rewardSeed[0]), floorIndex)) {
            equipmentId = _rollEquipmentReward(winner, rewardSeed, floorIndex);
        }
        uint256[] memory itemIds = Battle.rewardItems(rewardSeed, floorIndex);
        uint256 coinCount = Battle.rewardCoins(floorIndex);

        uint256 itemLen = itemIds.length;
        if (itemLen > 0) {
            _addItemBatch(winner, itemIds);
        }

        uint256 assetCount = itemLen;
        if (equipmentId > 0) assetCount++;
        if (coinCount > 0) assetCount++;

        if (assetCount == 0) return (new uint256[](0), new uint256[](0));

        assetIds = new uint256[](assetCount);
        values = new uint256[](assetCount);

        for (uint256 i = 0; i < itemLen; i++) {
            assetIds[i] = itemIds[i];
            values[i] = 1;
        }
        uint256 pos = itemLen;
        if (equipmentId > 0) {
            assetIds[pos] = equipmentId;
            values[pos] = 1;
            pos++;
        }
        if (coinCount > 0) {
            assetIds[pos] = Property.COIN_ID;
            values[pos] = coinCount;
        }
    }

    function getBag(address addr) external view returns (uint256[] memory) {
        return _copyUint256Array(_bag[addr]);
    }

    function getWarehouse(address addr) external view returns (uint256[] memory) {
        return _copyUint256Array(_warehouse[addr]);
    }

    function getEquipment(uint256 id) external view returns (Equipment memory) {
        return _equipments[id];
    }

    function getPuppet(uint256 id) external view returns (Puppet memory) {
        return _puppets[id];
    }

    function isValidEquipment(uint256 id) external pure returns (bool) {
        return (id >= EQUIPMENT_ID_START && id < EQUIPMENT_ID_CAP) || (id >= PUPPET_ID_START && id < PUPPET_ID_CAP);
    }

    /// @notice Initialize next-IDs (for proxy: call from implementation's initialize(); constructor only runs on impl, not on proxy).
    function _initNextIds() internal {
        if (_nextEquipmentId != 0) return;
        _nextEquipmentId = EQUIPMENT_ID_START;
        _nextPuppetId = PUPPET_ID_START;
    }

    /// @notice add a new weaponId to player's warehouse
    function _addToWarehouse(address addr, uint256 id) private {
        uint256[] storage wh = _warehouse[addr];
        uint256 len = wh.length;
        if (len >= WAREHOUSE_CAP) revert NeedMoreSpace();
        for (uint256 i = 0; i < len; i++) {
            if (wh[i] == EMPTY_SLOT) {
                wh[i] = id;
                return;
            }
        }
        wh.push(id);
    }

    function _addItemBatch(address addr, uint256[] memory itemIds) private {
        uint256 itemsLen = itemIds.length;
        if (itemsLen == 0) revert EmptyItems();
        uint256 op = 0;
        uint256[] storage mb = _bag[addr];
        uint256 len = mb.length;
        for (uint256 i = 0; i < len; i++) {
            if (mb[i] == EMPTY_SLOT) {
                mb[i] = itemIds[op];
                op++;
            }
            if (op == itemsLen) return;
        }
        uint256 remains = itemsLen - op;
        if (remains + len > BAG_CAP) revert NeedMoreSpace();
        for (uint256 i = 0; i < remains; i++) {
            mb.push(itemIds[op + i]);
        }
    }

    function _delItems(address addr, uint256[] calldata slots) private {
        uint256 count = slots.length;
        if (count == 0) return;
        uint256[] storage mb = _bag[addr];
        uint256 len = mb.length;
        for (uint256 i = 0; i < count; i++) {
            uint256 slot = slots[i];
            if (slot >= len) revert ArrayOutOfBounds();
            if (mb[slot] != EMPTY_SLOT) delete mb[slot];
        }
    }

    function _addEquipmentInternal(address addr, Equipment memory equipment) private returns (uint256) {
        uint256 latest = _nextEquipmentId;
        if (latest >= EQUIPMENT_ID_CAP) revert CapacityExceeded();
        _equipments[latest] = equipment;
        _nextEquipmentId++;
        _addToWarehouse(addr, latest);
        return latest;
    }

    function _upgradeEquipment(uint256 equipmentId) private {
        Equipment storage e = _equipments[equipmentId];
        e.level++;
        if (e.etype == EquipmentType.Sword) {
            e.attack = Property.calAttackForSword(e.rarity, e.level);
        } else if (e.etype == EquipmentType.Armor) {
            e.defense = Property.calDefenseForArmor(e.rarity, e.level);
        } else {
            e.defense = Property.calDefenseForShield(e.rarity, e.level);
        }
    }

    function _mergeEquipment(address addr, EquipmentType typ, uint256 mainId, uint256 subId, bytes32 seed)
        private
        returns (uint256 cost)
    {
        if (mainId == subId) revert SameEquipmentIds();
        Equipment storage subRef = _equipments[subId];
        if (subId >= PUPPET_ID_START || subRef.etype != typ) revert InvalidEquipmentId(subId);
        uint256[] storage warehouse = _warehouse[addr];
        uint256 len = warehouse.length;
        uint256 subIdx = len;
        for (uint256 i = 0; i < len; i++) {
            if (warehouse[i] == subId) {
                subIdx = i;
                break;
            }
        }
        if (subIdx >= len) revert InvalidEquipmentId(subId);
        bytes32 mergeSeed = seed.change(5, SEED_MIX_MERGE);
        Equipment storage mainRef = _equipments[mainId];
        if (typ == EquipmentType.Sword || typ == EquipmentType.Armor) {
            if (mainRef.materials != subRef.materials || mainRef.rarity != subRef.rarity) revert CannotMerge();
        } else {
            if (mainRef.rarity != subRef.rarity) revert CannotMerge();
        }
        if (mainRef.rarity == Rarity.S) revert ReachedMaxLevel();
        cost = Property.mergeEquipmentCost(mainRef.rarity);
        if (Property.determineMerge(uint8(mergeSeed[0]), mainRef.rarity)) _equipmentEvolve(mainRef);
        delete warehouse[subIdx];
        delete _equipments[subId];
    }

    function _equipmentEvolve(Equipment storage e) private {
        Rarity newRarity = Rarity(uint8(e.rarity) + 1);
        e.rarity = newRarity;
        if (e.etype == EquipmentType.Sword) {
            (uint16 crit, uint16 critChance,, uint16 stunChance) = Property.calSecondAttributes(newRarity);
            e.attack = Property.calAttackForSword(newRarity, e.level);
            e.crit = crit;
            e.critChance = critChance;
            e.stunChance = stunChance;
        } else if (e.etype == EquipmentType.Armor) {
            e.defense = Property.calDefenseForArmor(newRarity, e.level);
        } else {
            (,, uint16 blockChance, uint16 stunChance) = Property.calSecondAttributes(newRarity);
            e.blockChance = blockChance;
            e.stunChance = stunChance;
            e.defense = Property.calDefenseForShield(newRarity, e.level);
        }
    }

    function _copyUint256Array(uint256[] storage source) private view returns (uint256[] memory result) {
        uint256 len = source.length;
        result = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = source[i];
        }
    }

    function _rollEquipmentReward(address winner, bytes32 rewardSeed, uint256 floorIndex)
        private
        returns (uint256 equipmentId)
    {
        (uint8 level, Rarity rarity, EquipmentMaterials materials, EquipmentType typ) =
            Battle.rewardEquipment(rewardSeed, floorIndex);
        (uint16 crit, uint16 critChance, uint16 blockChance, uint16 stunChance) =
            Property.calSecondAttributesDirectly(rarity);

        Equipment memory eq;
        eq.etype = typ;
        eq.materials = materials;
        eq.rarity = rarity;
        eq.level = level;
        if (typ == EquipmentType.Sword) {
            eq.attack = Property.calAttackForSword(rarity, level);
            eq.crit = crit;
            eq.critChance = critChance;
            eq.stunChance = stunChance;
        } else if (typ == EquipmentType.Armor) {
            eq.defense = Property.calDefenseForArmor(rarity, level);
        } else {
            eq.defense = Property.calDefenseForShield(rarity, level);
            eq.blockChance = blockChance;
            eq.stunChance = stunChance;
        }
        equipmentId = _addEquipmentInternal(winner, eq);
    }

    function _onlyPermit() private view {
        if (msg.sender != _permit) revert Unauthorized();
    }
}
