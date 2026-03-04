// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV0} from "../src/GameV0.sol";
import {Property} from "../src/libraries/Property.sol";
import {Rarity} from "../src/libraries/Attribute.sol";

contract GameV0Harness is GameV0 {
    constructor(address _gameToken_, address _gameAssets_) GameV0(_gameToken_, _gameAssets_) {}

    function exposedGetPlayerLevel(address player) external view returns (uint8) {
        return findPlayer(player).level;
    }

    function exposedGetFloorIndex(address player) external view returns (uint8) {
        return findFloor(player).index;
    }

    function exposedGetEnemiesCount(address player) external view returns (uint256) {
        return findFloor(player).enemies.length;
    }

    function exposedGetFloorShopItemsLength(address player) external view returns (uint256) {
        return findFloor(player).shop.items.length;
    }

    function exposedGetFloorShopSwordsLength(address player) external view returns (uint256) {
        return findFloor(player).shop.swords.length;
    }

    function exposedGetFloorFoundryRarity(address player) external view returns (Rarity) {
        return findFloor(player).foundry.rarity;
    }

    function exposedGetEnemyLevel(address player, uint256 index) external view returns (uint8) {
        return findFloor(player).enemies[index].level;
    }

    function exposedGetEnemyHealth(address player, uint256 index) external view returns (uint16) {
        return findFloor(player).enemies[index].health;
    }

    function exposedGetEnemyIsBoss(address player, uint256 index) external view returns (bool) {
        return findFloor(player).enemies[index].isBoss;
    }
}

/**
 * Unit tests for GameLogic.born.
 */
contract BornTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;
    GameV0Harness harness;

    address user;

    function setUp() public {
        user = address(0x1234);

        GameToken token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");
        GameV0Harness game = new GameV0Harness(address(token), address(assets));

        token.setProxy(address(game));
        assets.setProxy(address(game));

        gameLogic = IGameLogic(address(game));
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
        harness = GameV0Harness(address(game));
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

        assertEq(harness.exposedGetPlayerLevel(user), 1, "player level should be 1");
        assertEq(harness.exposedGetFloorIndex(user), 0, "floor index should be 0");
        assertGt(harness.exposedGetEnemiesCount(user), 0, "floor should have enemies");
    }

    function test_born_revertWhenPlayerAlreadyExists() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(IGameLogic.PlayerAlreadyExists.selector);
        gameLogic.born();
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Floor-related data tests (after born: floor index 0)
    // -------------------------------------------------------------------------

    function test_floor_afterBorn_index0_enemiesInRange() public {
        vm.prank(user);
        gameLogic.born();

        assertEq(harness.exposedGetFloorIndex(user), 0, "floor index should be 0");
        uint256 count = harness.exposedGetEnemiesCount(user);
        assertGe(count, 3, "floor 0 should have at least 3 enemies (aokaCount 3 or 4)");
        assertLe(count, 4, "floor 0 should have at most 4 enemies");
    }

    function test_floor_afterBorn_noShopOnFloor0() public {
        vm.prank(user);
        gameLogic.born();

        assertEq(
            harness.exposedGetFloorShopItemsLength(user),
            0,
            "floor 0 has no shop (shopCountNextFloor returns 0 for index < 3)"
        );
        assertEq(harness.exposedGetFloorShopSwordsLength(user), 0, "floor 0 shop has no swords");
    }

    function test_floor_afterBorn_enemiesHaveValidStats() public {
        vm.prank(user);
        gameLogic.born();

        uint256 count = harness.exposedGetEnemiesCount(user);
        for (uint256 i = 0; i < count; i++) {
            assertGe(harness.exposedGetEnemyLevel(user, i), 1, "enemy level >= 1");
            assertLe(harness.exposedGetEnemyLevel(user, i), 100, "enemy level <= 100");
            assertGt(harness.exposedGetEnemyHealth(user, i), 0, "enemy health > 0");
        }
    }

    function test_floor_afterBorn_floor0NotBossFloor() public {
        vm.prank(user);
        gameLogic.born();

        uint256 count = harness.exposedGetEnemiesCount(user);
        for (uint256 i = 0; i < count; i++) {
            assertFalse(
                harness.exposedGetEnemyIsBoss(user, i), "floor 0 is not a boss floor (index 0), no enemy should be boss"
            );
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
