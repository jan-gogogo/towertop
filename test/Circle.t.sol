// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV0} from "../src/GameV0.sol";
import {Player, Character} from "../src/libraries/Character.sol";
import {Floor} from "../src/libraries/Environment.sol";

contract GameV0CircleHarness is GameV0 {
    constructor(address _gameToken_, address _gameAssets_) GameV0(_gameToken_, _gameAssets_) {}

    function exposedSetFloorIndex(address addr, uint8 index) external {
        findFloor(addr).index = index;
    }
}

/**
 * Unit tests for GameLogic.circle() (reset at 100th floor: player stats reset, courage+1, floor rebuilt).
 */
contract CircleTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;
    GameV0CircleHarness harness;

    address user;

    function setUp() public {
        user = address(0x1234);

        GameToken token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");
        GameV0CircleHarness game = new GameV0CircleHarness(address(token), address(assets));

        token.setProxy(address(game));
        assets.setProxy(address(game));

        gameLogic = IGameLogic(address(game));
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
        harness = GameV0CircleHarness(address(game));

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
        // Advance and fight so player levels up at least once (meaningful reset after circle)
        _clearCurrentFloorWithSeed(0x1234);
        gameLogic.nextFloor();
        _clearCurrentFloorWithSeed(0x1234 + 100);
        assertGe(gameLogic.getPlayer(user).level, 2, "player should be at least level 2");

        // Simulate being at 100th floor (index 99)
        harness.exposedSetFloorIndex(user, 99);

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
        vm.startPrank(user);
        harness.exposedSetFloorIndex(user, 99);

        gameLogic.circle();

        Floor memory floor = gameLogic.getFloor(user);
        // clearFloor() deletes floor.index so it becomes 0; new cycle starts at floor 0
        assertEq(floor.index, 0, "floor reset to 0 after circle (new cycle)");
        // Floor was cleared and rebuilt with new content for floor 0
        vm.stopPrank();
    }
}
