// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IHeroLogic} from "../src/interfaces/IHeroLogic.sol";
import {Equipment, EquipmentType, EquipmentMaterials, Puppet, Rarity} from "../src/libraries/Property.sol";

/**
 * Unit tests for Game.equip and Game.unequip.
 */
contract EquipUnequipTest is RouterTestBase {
    address user;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
        vm.prank(user);
        gameLogic.born();
    }

    function _getEquipped(address addr)
        internal
        view
        returns (Equipment memory e0, Equipment memory e1, Equipment memory e2, Puppet memory p)
    {
        uint256[4] memory ids = heroLogic.getEquippedIds(addr);
        if (ids[0] > 0) e0 = inventoryLogic.getEquipment(ids[0]);
        if (ids[1] > 0) e1 = inventoryLogic.getEquipment(ids[1]);
        if (ids[2] > 0) e2 = inventoryLogic.getEquipment(ids[2]);
        if (ids[3] > 0) p = inventoryLogic.getPuppet(ids[3]);
    }

    function _addSwordToWarehouse(address addr) internal returns (uint256 swordId) {
        Equipment memory sword = Equipment({
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
        vm.prank(address(gameLogic));
        swordId = inventoryLogic.addEquipment(addr, sword);
        vm.prank(address(gameLogic));
        gameAssets.mint(addr, swordId, 1, "");
    }

    function test_equip_snapshot() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        vm.resetGasMetering();
        gameLogic.equip(swordId);
    }

    function test_unequip_snapshot() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        gameLogic.equip(swordId);
        vm.prank(user);
        vm.resetGasMetering();
        gameLogic.unequip(swordId);
    }

    function test_equip_sword_success() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        gameLogic.equip(swordId);

        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertFalse(_arrayContains(wh, swordId), "warehouse must not contain equipped sword");
        (Equipment memory e0,,,) = _getEquipped(user);
        assertEq(uint8(e0.etype), uint8(EquipmentType.Sword), "slot 0 is sword");
        assertEq(e0.attack, 8, "equipped sword attack");
        assertEq(e0.level, 1, "equipped sword level");
    }

    function test_equip_puppet_success() public {
        vm.prank(user);
        uint256 puppetId = 4e9;
        gameLogic.equip(puppetId);

        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertFalse(_arrayContains(wh, puppetId), "warehouse must not contain equipped puppet");
        (,,, Puppet memory p) = _getEquipped(user);
        assertEq(uint8(p.rarity), uint8(0), "equipped puppet rarity C");
    }

    function test_equip_then_unequip_roundtrip() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        gameLogic.equip(swordId);
        (Equipment memory eBefore,,,) = _getEquipped(user);
        assertEq(eBefore.attack, 8, "sword equipped");

        vm.prank(user);
        gameLogic.unequip(swordId);

        (Equipment memory eAfter,,,) = _getEquipped(user);
        assertEq(eAfter.attack, 0, "slot empty after unequip");
        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertTrue(_arrayContains(wh, swordId), "warehouse must contain sword after unequip");
    }

    function test_equip_revertWhenNotInWarehouse() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        gameLogic.equip(swordId);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EquipmentNotFound.selector, swordId));
        vm.prank(user);
        gameLogic.equip(swordId);
    }

    function test_equip_revertWhenInvalidEquipmentId_zero() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidEquipmentId.selector, uint256(0)));
        gameLogic.equip(0);
    }

    function test_equip_revertWhenInvalidEquipmentId_tooHigh() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidEquipmentId.selector, uint256(5e9)));
        gameLogic.equip(5e9);
    }

    function test_equip_revertWhenNotRegistered() public {
        uint256 swordId = _addSwordToWarehouse(user);
        address notRegistered = address(0x9999);
        vm.prank(notRegistered);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, notRegistered));
        gameLogic.equip(swordId);
    }

    function test_unequip_afterEquip_success() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        gameLogic.equip(swordId);
        vm.prank(user);
        gameLogic.unequip(swordId);

        assertTrue(_arrayContains(gameLogic.getWarehouse(user), swordId), "warehouse has sword after unequip");
        (Equipment memory e0,,,) = _getEquipped(user);
        assertEq(e0.attack, 0, "sword slot empty");
    }

    function test_unequip_revertWhenNotEquipped() public {
        uint256 swordId = _addSwordToWarehouse(user);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IHeroLogic.NotEquippedId.selector, swordId));
        gameLogic.unequip(swordId);
    }

    function test_unequip_revertWhenInvalidEquipmentId_zero() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidEquipmentId.selector, uint256(0)));
        gameLogic.unequip(0);
    }

    function test_unequip_revertWhenNotRegistered() public {
        uint256 swordId = _addSwordToWarehouse(user);
        address notRegistered = address(0x9999);
        vm.prank(notRegistered);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, notRegistered));
        gameLogic.unequip(swordId);
    }

    function _arrayContains(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }
}
