// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Property} from "../src/libraries/Property.sol";

/**
 * Unit tests for Router.born (via IGameLogic).
 */
contract BornTest is RouterTestBase {
    address user;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
    }

    function test_born_for_snapshot() public {
        vm.pauseGasMetering();
        vm.prank(user);
        vm.resetGasMetering();
        gameLogic.born();
    }

    function test_born_success_mintsTokenAndAssets() public {
        vm.prank(user);
        gameLogic.born();

        assertEq(gameToken.balanceOf(user), 1 ether, "player should receive 1 ether");
        assertEq(gameAssets.balanceOf(user, Property.POTION_C_ID), 1, "player should have 1 potion");
        assertEq(gameAssets.balanceOf(user, 1e9), 1, "player should have 1 sword (first id 1e9)");
        assertEq(gameAssets.balanceOf(user, 4e9), 1, "player should have 1 puppet (first id 4e9)");
    }

    function test_born_success_initialPlayerAndFloorState() public {
        vm.prank(user);
        gameLogic.born();

        assertEq(gameLogic.getPlayer(user).level, 1, "player level should be 1");
        assertEq(gameLogic.getFloor(user).index, 0, "floor index should be 0");
        assertGt(gameLogic.getEnemies(user).length, 0, "floor should have enemies");
    }

    function test_born_revertWhenPlayerAlreadyExists() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(IGameLogic.PlayerAlreadyExists.selector);
        gameLogic.born();
        vm.stopPrank();
    }

    function test_floor_afterBorn_index0_enemiesInRange() public {
        vm.prank(user);
        gameLogic.born();

        assertEq(gameLogic.getFloor(user).index, 0, "floor 0");
        uint256 count = gameLogic.getEnemies(user).length;
        assertGe(count, 3, "floor 0 should have at least 3 enemies");
        assertLe(count, 4, "floor 0 should have at most 4 enemies");
    }

    function test_floor_afterBorn_noShopOnFloor0() public {
        vm.prank(user);
        gameLogic.born();

        assertEq(gameLogic.getFloor(user).shop.items.length, 0, "floor 0 has no shop");
        assertEq(gameLogic.getFloor(user).shop.equipments.length, 0, "floor 0 shop has no equipments");
    }

    function test_floor_afterBorn_enemiesHaveValidStats() public {
        vm.prank(user);
        gameLogic.born();

        uint256 count = gameLogic.getEnemies(user).length;
        for (uint256 i = 0; i < count; i++) {
            assertGe(gameLogic.getEnemies(user)[i].level, 1, "enemy level >= 1");
            assertLe(gameLogic.getEnemies(user)[i].level, 100, "enemy level <= 100");
            assertGt(gameLogic.getEnemies(user)[i].health, 0, "enemy health > 0");
        }
    }

    function test_floor_afterBorn_floor0NotBossFloor() public {
        vm.prank(user);
        gameLogic.born();

        uint256 count = gameLogic.getEnemies(user).length;
        for (uint256 i = 0; i < count; i++) {
            assertFalse(gameLogic.getEnemies(user)[i].isBoss, "floor 0 is not a boss floor, no enemy should be boss");
        }
    }

    function test_floor_nextFloor_revertWhenNotAllEnemiesDefeated() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(IGameLogic.MustDefeatAllEenemies.selector);
        gameLogic.nextFloor();
        vm.stopPrank();
    }
}
