// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameStorage} from "../src/GameStorage.sol";
import {Sword, Armor, Shield, EquipmentMaterials} from "../src/libraries/Property.sol";
import {Player} from "../src/libraries/Character.sol";
import {Character} from "../src/libraries/Character.sol";
import {Rarity} from "../src/libraries/Attribute.sol";

/**
 * Harness to expose GameStorage internal functions for unit testing.
 */
contract GameStorageHarness is GameStorage {
    constructor() {
        _initNextIds();
    }

    function exposedInitNextIds() external {
        _initNextIds();
    }

    function exposedAddPlayer(address addr, Player memory player) external {
        addPlayer(addr, player);
    }

    function exposedAddSword(address addr, Sword memory sword) external returns (uint256) {
        return addSword(addr, sword);
    }

    function exposedAddArmor(address addr, Armor memory armor) external returns (uint256) {
        return addArmor(addr, armor);
    }

    function exposedAddShield(address addr, Shield memory shield) external returns (uint256) {
        return addShield(addr, shield);
    }

    function exposedAddPuppet(address addr, Rarity rarity, uint40 lastClaimAt) external returns (uint256) {
        return addPuppet(addr, rarity, lastClaimAt);
    }

    function exposedAddItem(address addr, uint256 itemId) external {
        addItem(addr, itemId);
    }

    function exposedAddItems(address addr, uint256[] memory itemIds) external {
        addItems(addr, itemIds);
    }

    function exposedDelItems(address addr, uint256[] calldata slots) external {
        delItems(addr, slots);
    }

    function exposedFindBagLength(address addr) external view returns (uint256) {
        return findBag(addr).length;
    }

    function exposedFindBagAt(address addr, uint256 i) external view returns (uint256) {
        return findBag(addr)[i];
    }

    function exposedFindWarehouseLength(address addr) external view returns (uint256) {
        return findWarehouse(addr).length;
    }

    function exposedFindWarehouseAt(address addr, uint256 i) external view returns (uint256) {
        return findWarehouse(addr)[i];
    }

    function exposedFindFloorIndex(address addr) external view returns (uint8) {
        return findFloor(addr).index;
    }

    function exposedSetFloorIndex(address addr, uint8 index) external {
        findFloor(addr).index = index;
    }

    function exposedFindPlayerCreateAt(address addr) external view returns (uint40) {
        return findPlayer(addr).createAt;
    }

    function exposedFindPlayerLevel(address addr) external view returns (uint8) {
        return findPlayer(addr).level;
    }

    function exposedGetEquipped(address addr) external view returns (Sword memory s, Armor memory a, Shield memory sh) {
        return getEquipped(addr);
    }
}

/**
 * Unit tests for GameStorage – cover all internal functions.
 */
contract GameStorageTest is Test {
    GameStorageHarness harness;
    address user;

    function setUp() public {
        harness = new GameStorageHarness();
        user = address(0x1234);
    }

    // ---------- _initNextIds ----------
    function test_initNextIds_idempotent() public {
        harness.exposedInitNextIds();
        harness.exposedInitNextIds();
        // First addSword should still get 1e9 (no double init)
        Sword memory s = _defaultSword();
        assertEq(harness.exposedAddSword(user, s), 1e9, "first sword id");
    }

    // ---------- addPlayer / findPlayer ----------
    function test_addPlayer_findPlayer() public {
        Player memory p = Character.initPlayer();
        p.level = 5;
        harness.exposedAddPlayer(user, p);
        assertEq(harness.exposedFindPlayerLevel(user), 5, "player level");
        assertEq(harness.exposedFindPlayerCreateAt(user), block.timestamp, "createAt");
    }

    // ---------- addSword / findWarehouse ----------
    function test_addSword_warehouse() public {
        Sword memory s = _defaultSword();
        uint256 id = harness.exposedAddSword(user, s);
        assertEq(id, 1e9, "first sword id");
        assertEq(harness.exposedFindWarehouseLength(user), 1, "warehouse len");
        assertEq(harness.exposedFindWarehouseAt(user, 0), 1e9, "warehouse[0]");
    }

    function test_addSword_multiple() public {
        Sword memory s = _defaultSword();
        assertEq(harness.exposedAddSword(user, s), 1e9, "id 1");
        assertEq(harness.exposedAddSword(user, s), 1e9 + 1, "id 2");
        assertEq(harness.exposedFindWarehouseLength(user), 2, "warehouse len");
    }

    // ---------- addArmor ----------
    function test_addArmor_warehouse() public {
        Armor memory a = _defaultArmor();
        uint256 id = harness.exposedAddArmor(user, a);
        assertEq(id, 2e9, "first armor id");
        assertEq(harness.exposedFindWarehouseAt(user, 0), 2e9, "warehouse[0]");
    }

    // ---------- addShield ----------
    function test_addShield_warehouse() public {
        Shield memory sh = _defaultShield();
        uint256 id = harness.exposedAddShield(user, sh);
        assertEq(id, 3e9, "first shield id");
        assertEq(harness.exposedFindWarehouseAt(user, 0), 3e9, "warehouse[0]");
    }

    // ---------- addPuppet ----------
    function test_addPuppet_warehouse() public {
        uint256 id = harness.exposedAddPuppet(user, Rarity.C, uint40(block.timestamp));
        assertEq(id, 4e9, "first puppet id");
        assertEq(harness.exposedFindWarehouseAt(user, 0), 4e9, "warehouse[0]");
    }

    // ---------- addItem / addItems / findBag ----------
    function test_addItem_findBag() public {
        harness.exposedAddItem(user, 101);
        assertEq(harness.exposedFindBagLength(user), 1, "bag len");
        assertEq(harness.exposedFindBagAt(user, 0), 101, "bag[0]");
    }

    function test_addItems_findBag() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 102;
        ids[2] = 201;
        harness.exposedAddItems(user, ids);
        assertEq(harness.exposedFindBagLength(user), 3, "bag len");
        assertEq(harness.exposedFindBagAt(user, 0), 1, "bag[0]");
        assertEq(harness.exposedFindBagAt(user, 1), 102, "bag[1]");
        assertEq(harness.exposedFindBagAt(user, 2), 201, "bag[2]");
    }

    function test_addItems_emptyReverts() public {
        uint256[] memory empty;
        vm.expectRevert(GameStorage.EmptyItems.selector);
        harness.exposedAddItems(user, empty);
    }

    function test_addItems_bagCapReverts() public {
        uint256[] memory many = new uint256[](101);
        for (uint256 i = 0; i < 101; i++) {
            many[i] = i + 1;
        }
        vm.expectRevert(GameStorage.NeedMoreSpace.selector);
        harness.exposedAddItems(user, many);
    }

    // ---------- delItems ----------
    function test_delItems() public {
        harness.exposedAddItem(user, 101);
        harness.exposedAddItem(user, 102);
        uint256[] memory slots = new uint256[](1);
        slots[0] = 0;
        harness.exposedDelItems(user, slots);
        assertEq(harness.exposedFindBagAt(user, 0), 0, "slot 0 cleared");
        assertEq(harness.exposedFindBagAt(user, 1), 102, "slot 1 unchanged");
    }

    function test_delItems_multipleSlots() public {
        harness.exposedAddItems(user, _array(1, 2, 3));
        uint256[] memory slots = new uint256[](2);
        slots[0] = 0;
        slots[1] = 2;
        harness.exposedDelItems(user, slots);
        assertEq(harness.exposedFindBagAt(user, 0), 0, "slot 0 cleared");
        assertEq(harness.exposedFindBagAt(user, 1), 2, "slot 1 unchanged");
        assertEq(harness.exposedFindBagAt(user, 2), 0, "slot 2 cleared");
    }

    function test_delItems_emptySlotsNoRevert() public {
        uint256[] memory slots;
        harness.exposedDelItems(user, slots); // should not revert
    }

    function test_delItems_revertWhenSlotOutOfBounds() public {
        harness.exposedAddItem(user, 1);
        uint256[] memory slots = new uint256[](1);
        slots[0] = 5;
        vm.expectRevert(GameStorage.ArrayOutOfBounds.selector);
        harness.exposedDelItems(user, slots);
    }

    // ---------- findFloor ----------
    function test_findFloor() public {
        harness.exposedSetFloorIndex(user, 42);
        assertEq(harness.exposedFindFloorIndex(user), 42, "floor index");
    }

    // ---------- getEquipped (no setter in GameStorage; default empty) ----------
    function test_getEquipped_defaultEmpty() public view {
        (Sword memory s, Armor memory a, Shield memory sh) = harness.exposedGetEquipped(user);
        assertEq(uint16(s.attack), 0, "default sword");
        assertEq(uint16(a.defense), 0, "default armor");
        assertEq(uint16(sh.blockChance), 0, "default shield");
    }

    // ---------- warehouse capacity (NeedMoreSpace via _addToWarehouse) ----------
    function test_warehouse_capacityReverts() public {
        Sword memory s = _defaultSword();
        for (uint256 i = 0; i < 100; i++) {
            harness.exposedAddSword(user, s);
        }
        vm.expectRevert(GameStorage.NeedMoreSpace.selector);
        harness.exposedAddSword(user, s);
    }

    // ---------- fill bag then use empty slots (addItem reuses slots) ----------
    function test_addItem_reusesEmptySlotsAfterDelItems() public {
        harness.exposedAddItems(user, _array(1, 2, 3));
        uint256[] memory slots = new uint256[](1);
        slots[0] = 1;
        harness.exposedDelItems(user, slots);
        harness.exposedAddItem(user, 99);
        assertEq(harness.exposedFindBagAt(user, 1), 99, "reused slot 1");
    }

    // ---------- helpers ----------
    function _defaultSword() internal pure returns (Sword memory) {
        return Sword({
            materials: EquipmentMaterials.Iron,
            rarity: Rarity.C,
            level: 1,
            attack: 10,
            crit: 0,
            critChance: 0,
            stunChance: 0
        });
    }

    function _defaultArmor() internal pure returns (Armor memory) {
        return Armor({materials: EquipmentMaterials.Iron, rarity: Rarity.C, level: 1, defense: 5});
    }

    function _defaultShield() internal pure returns (Shield memory) {
        return Shield({rarity: Rarity.C, level: 1, defense: 3, blockChance: 10, stunChance: 0});
    }

    function _array(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        return arr;
    }
}
