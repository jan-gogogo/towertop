// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV0} from "../src/GameV0.sol";
import {GameStorage} from "../src/GameStorage.sol";
import {Sword, Armor, Shield, Puppet} from "../src/libraries/Property.sol";

/**
 * Harness to expose getEquipped for equip/unequip tests.
 */
contract GameV0EquipHarness is GameV0 {
    constructor(address _gameToken_, address _gameAssets_) GameV0(_gameToken_, _gameAssets_) {}

    function exposedGetEquipped(address addr)
        external
        view
        returns (Sword memory s, Armor memory a, Shield memory sh, Puppet memory p)
    {
        return getEquipped(addr);
    }
}

/**
 * Unit tests for GameLogic.equip and GameLogic.unequip.
 */
contract EquipUnequipTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;
    GameV0EquipHarness harness;

    address user;

    function setUp() public {
        user = address(0x1234);

        GameToken token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");
        GameV0EquipHarness game = new GameV0EquipHarness(address(token), address(assets));

        token.setProxy(address(game));
        assets.setProxy(address(game));

        gameLogic = IGameLogic(address(game));
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
        harness = GameV0EquipHarness(address(game));

        vm.prank(user);
        gameLogic.born();
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

    // -------------------------------------------------------------------------
    // equip — happy path
    // -------------------------------------------------------------------------

    function test_equip_sword_success() public {
        vm.startPrank(user);
        uint256 swordId = 1e9;
        gameLogic.equip(swordId);
        vm.stopPrank();

        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertFalse(_arrayContains(wh, swordId), "warehouse must not contain equipped sword");
        (Sword memory s,,,) = harness.exposedGetEquipped(user);
        assertEq(s.attack, 8, "equipped sword attack from born()");
        assertEq(s.level, 1, "equipped sword level");
    }

    function test_equip_puppet_success() public {
        vm.startPrank(user);
        uint256 puppetId = 4e9;
        gameLogic.equip(puppetId);
        vm.stopPrank();

        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertFalse(_arrayContains(wh, puppetId), "warehouse must not contain equipped puppet");
        (,,, Puppet memory p) = harness.exposedGetEquipped(user);
        assertEq(uint8(p.rarity), uint8(0), "equipped puppet rarity C"); // Rarity.C = 0
    }

    function test_equip_then_unequip_roundtrip() public {
        vm.startPrank(user);
        uint256 swordId = 1e9;
        gameLogic.equip(swordId);
        (Sword memory sBefore,,,) = harness.exposedGetEquipped(user);
        assertEq(sBefore.attack, 8, "sword equipped");

        gameLogic.unequip(swordId);
        vm.stopPrank();

        (Sword memory sAfter,,,) = harness.exposedGetEquipped(user);
        assertEq(sAfter.attack, 0, "slot empty after unequip");
        uint256[] memory wh = gameLogic.getWarehouse(user);
        assertTrue(_arrayContains(wh, swordId), "warehouse must contain sword after unequip");
    }

    // -------------------------------------------------------------------------
    // equip — reverts
    // -------------------------------------------------------------------------

    function test_equip_revertWhenNotInWarehouse() public {
        vm.startPrank(user);
        gameLogic.equip(1e9); // first equip succeeds
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EquipmentNotFound.selector, uint256(1e9)));
        gameLogic.equip(1e9); // same id no longer in warehouse
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

    // -------------------------------------------------------------------------
    // unequip — happy path
    // -------------------------------------------------------------------------

    function test_unequip_afterEquip_success() public {
        vm.startPrank(user);
        gameLogic.equip(1e9);
        gameLogic.unequip(1e9);
        vm.stopPrank();

        assertTrue(_arrayContains(gameLogic.getWarehouse(user), 1e9), "warehouse has sword after unequip");
        (Sword memory s,,,) = harness.exposedGetEquipped(user);
        assertEq(s.attack, 0, "sword slot empty");
    }

    // -------------------------------------------------------------------------
    // unequip — reverts
    // -------------------------------------------------------------------------

    function test_unequip_revertWhenNotEquipped() public {
        vm.startPrank(user);
        // sword 1e9 is in warehouse but not equipped
        vm.expectRevert(abi.encodeWithSelector(GameStorage.NotEquippedId.selector, uint256(1e9)));
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

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _arrayContains(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }
}
