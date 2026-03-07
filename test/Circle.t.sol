// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Player} from "../src/libraries/Character.sol";
import {Floor} from "../src/libraries/Environment.sol";

/**
 * Unit tests for Game.circle() (reset at 100th floor: player stats reset, courage+1, floor rebuilt).
 */
contract CircleTest is RouterTestBase {
    address user;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
        vm.startPrank(user);
        vm.prevrandao(0x1234);
        gameLogic.born();
        vm.stopPrank();
    }

    function _clearCurrentFloorWithSeed(uint256 baseSeed) internal {
        Floor memory floor = gameLogic.getFloor(user);
        for (uint256 i = 0; i < floor.enemies.length; i++) {
            vm.prevrandao(baseSeed + i);
            gameLogic.battle(i);
        }
    }

    function _advanceToFloor(uint8 targetIndex, uint256 seedBase) internal {
        while (gameLogic.getFloor(user).index < targetIndex) {
            uint8 idx = gameLogic.getFloor(user).index;
            _clearCurrentFloorWithSeed(seedBase + uint256(idx) * 100);
            gameLogic.nextFloor();
        }
    }

    function test_circle_revertWhenNotRegistered() public {
        address unregistered = address(0x9999);
        vm.prank(unregistered);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, unregistered));
        gameLogic.circle();
    }

    function test_circle_revertWhenNotAt100Floor() public {
        vm.startPrank(user);
        assertEq(gameLogic.getFloor(user).index, 0, "starts at floor 0");
        vm.expectRevert(IGameLogic.NotAt100Floor.selector);
        gameLogic.circle();
        vm.stopPrank();
    }

    function test_circle_success_resetsPlayerAndIncrementsCourage() public {
        vm.startPrank(user);
        _clearCurrentFloorWithSeed(0x1234);
        gameLogic.nextFloor();
        _clearCurrentFloorWithSeed(0x1234 + 100);
        assertGe(gameLogic.getPlayer(user).level, 2, "player should be at least level 2");
        vm.stopPrank();

        // setFloorIndex only callable by game proxy
        vm.prank(address(gameLogic));
        heroLogic.setFloorIndex(user, 99);

        vm.startPrank(user);
        Player memory before = gameLogic.getPlayer(user);
        assertEq(gameLogic.getFloor(user).index, 99, "at 100th floor");

        gameLogic.circle();

        Player memory playerAfter = gameLogic.getPlayer(user);
        assertEq(playerAfter.level, 1, "level reset to 1");
        assertEq(playerAfter.experience, 0, "experience reset to 0");
        assertEq(playerAfter.healthMax, 100, "healthMax reset to 100");
        assertEq(playerAfter.health, 100, "health reset to 100");
        assertEq(playerAfter.attack, 10, "attack reset to 10");
        assertEq(playerAfter.defense, 5, "defense reset to 5");
        assertEq(playerAfter.courage, before.courage + 1, "courage incremented by 1");
        assertEq(playerAfter.createAt, before.createAt, "createAt unchanged");
        vm.stopPrank();
    }

    function test_circle_success_floorReconstructed() public {
        vm.prank(address(gameLogic));
        heroLogic.setFloorIndex(user, 99);

        vm.prank(user);
        gameLogic.circle();

        Floor memory floor = gameLogic.getFloor(user);
        assertEq(floor.index, 0, "floor reset to 0 after circle");
        vm.stopPrank();
    }
}
