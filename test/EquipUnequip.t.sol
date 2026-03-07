// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IHeroLogic} from "../src/interfaces/IHeroLogic.sol";
import {Equipment, EquipmentType, Puppet} from "../src/libraries/Property.sol";

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

    function test_equip_snapshot() public {
        vm.prank(user);
        vm.resetGasMetering();
        gameLogic.equip(1e9);
    }

    function test_unequip_snapshot() public {
        vm.prank(user);
        gameLogic.equip(1e9);
        vm.prank(user);
        vm.resetGasMetering();
        gameLogic.unequip(1e9);
    }

    function test_equip_sword_success() public {
        vm.startPrank(user);
        uint256 swordId = 1e9;
        gameLogic.equip(swordId);
        vm.stopPrank();

        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertFalse(_arrayContains(wh, swordId), "warehouse must not contain equipped sword");
        (Equipment memory e0,,,) = _getEquipped(user);
        assertEq(uint8(e0.etype), uint8(EquipmentType.Sword), "slot 0 is sword");
        assertEq(e0.attack, 8, "equipped sword attack from born()");
        assertEq(e0.level, 1, "equipped sword level");
    }

    function test_equip_puppet_success() public {
        vm.startPrank(user);
        uint256 puppetId = 4e9;
        gameLogic.equip(puppetId);
        vm.stopPrank();

        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertFalse(_arrayContains(wh, puppetId), "warehouse must not contain equipped puppet");
        (,,, Puppet memory p) = _getEquipped(user);
        assertEq(uint8(p.rarity), uint8(0), "equipped puppet rarity C");
    }

    function test_equip_then_unequip_roundtrip() public {
        vm.startPrank(user);
        uint256 swordId = 1e9;
        gameLogic.equip(swordId);
        (Equipment memory eBefore,,,) = _getEquipped(user);
        assertEq(eBefore.attack, 8, "sword equipped");

        gameLogic.unequip(swordId);
        vm.stopPrank();

        (Equipment memory eAfter,,,) = _getEquipped(user);
        assertEq(eAfter.attack, 0, "slot empty after unequip");
        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertTrue(_arrayContains(wh, swordId), "warehouse must contain sword after unequip");
    }

    function test_equip_revertWhenNotInWarehouse() public {
        vm.startPrank(user);
        gameLogic.equip(1e9);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EquipmentNotFound.selector, uint256(1e9)));
        gameLogic.equip(1e9);
        vm.stopPrank();
    }

    function test_equip_revertWhenInvalidEquipmentId_zero() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidEquipmentId.selector, uint256(0)));
        gameLogic.equip(0);
        vm.stopPrank();
    }

    function test_equip_revertWhenInvalidEquipmentId_tooHigh() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidEquipmentId.selector, uint256(5e9)));
        gameLogic.equip(5e9);
        vm.stopPrank();
    }

    function test_equip_revertWhenNotRegistered() public {
        address notRegistered = address(0x9999);
        vm.prank(notRegistered);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, notRegistered));
        gameLogic.equip(1e9);
    }

    function test_unequip_afterEquip_success() public {
        vm.startPrank(user);
        gameLogic.equip(1e9);
        gameLogic.unequip(1e9);
        vm.stopPrank();

        assertTrue(_arrayContains(gameLogic.getWarehouse(user), 1e9), "warehouse has sword after unequip");
        (Equipment memory e0,,,) = _getEquipped(user);
        assertEq(e0.attack, 0, "sword slot empty");
    }

    function test_unequip_revertWhenNotEquipped() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IHeroLogic.NotEquippedId.selector, uint256(1e9)));
        gameLogic.unequip(1e9);
        vm.stopPrank();
    }

    function test_unequip_revertWhenInvalidEquipmentId_zero() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidEquipmentId.selector, uint256(0)));
        gameLogic.unequip(0);
        vm.stopPrank();
    }

    function test_unequip_revertWhenNotRegistered() public {
        address notRegistered = address(0x9999);
        vm.prank(notRegistered);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, notRegistered));
        gameLogic.unequip(1e9);
    }

    function _arrayContains(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }
}
