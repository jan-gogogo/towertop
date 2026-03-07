// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Property} from "../src/libraries/Property.sol";
import {Player} from "../src/libraries/Character.sol";
import {Floor} from "../src/libraries/Environment.sol";
import {Character} from "../src/libraries/Character.sol";

/**
 * Unit tests for Game.battle(uint256 enemySlot).
 */
contract BattleTest is RouterTestBase {
    address public user = address(0x1234);

    function setUp() public {
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

    function test_battle_afterBorn_playerCanFight() public {
        // user already born in setUp
        Player memory pBefore = heroLogic.getPlayer(user);
        Floor memory floor = heroLogic.getFloor(user);
        assertGt(floor.enemies.length, 0, "floor has enemies");
        assertEq(pBefore.createAt, block.timestamp, "player registered");

        vm.prank(user);
        gameLogic.battle(0);

        Player memory pAfter = heroLogic.getPlayer(user);
        Floor memory floorAfter = heroLogic.getFloor(user);
        assertTrue(pAfter.health > 0 || floorAfter.enemies[0].health == 0, "either player alive or enemy dead");
    }

    function test_battle_revertWhenEnemySlotOutOfRange() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EnemyNotFound.selector, 100));
        gameLogic.battle(100);
    }

    function test_battle_winGrantsRewards() public {
        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        uint256 bagLenBefore = inventoryLogic.getBag(user).length;

        vm.prank(user);
        gameLogic.battle(0);

        Player memory p = heroLogic.getPlayer(user);
        Floor memory floor = heroLogic.getFloor(user);
        bool playerWon = floor.enemies.length > 0 && floor.enemies[0].health == 0;

        if (playerWon) {
            assertGt(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore, "coin increased on win");
            assertGe(
                inventoryLogic.getBag(user).length + inventoryLogic.getWarehouse(user).length,
                bagLenBefore,
                "items or equipment may increase on win"
            );
            assertTrue(p.level >= 1, "player has level");
        }
    }

    function test_battle_for_snapshot() public {
        vm.pauseGasMetering();
        vm.startPrank(user);
        vm.resetGasMetering();
        gameLogic.battle(0);
    }

    function test_battle_playerWins_enemySlot0() public {
        vm.startPrank(user);
        Floor memory floorBefore = gameLogic.getFloor(user);
        assertTrue(floorBefore.enemies.length >= 1, "floor 0 has at least one enemy");

        gameLogic.battle(0);

        Floor memory floorAfter = gameLogic.getFloor(user);
        assertEq(floorAfter.enemies[0].health, 0, "enemy at slot 0 should be defeated");
        vm.stopPrank();
    }

    function test_battle_playerHealthAndEnemyUpdated() public {
        vm.startPrank(user);
        Player memory playerBefore = gameLogic.getPlayer(user);
        gameLogic.battle(0);
        Player memory playerAfter = gameLogic.getPlayer(user);

        Floor memory floor = gameLogic.getFloor(user);
        assertEq(floor.enemies[0].health, 0, "enemy defeated");
        assertTrue(
            playerAfter.health <= playerBefore.health || playerAfter.experience > playerBefore.experience,
            "player either took damage or gained exp"
        );
        vm.stopPrank();
    }

    function test_battle_validSlotWithinEnemyCount() public {
        vm.startPrank(user);
        Floor memory floor = gameLogic.getFloor(user);
        uint256 count = floor.enemies.length;
        assertTrue(count >= 1 && count <= 4, "floor 0 has 1-4 enemies");

        gameLogic.battle(count - 1);
        floor = gameLogic.getFloor(user);
        assertEq(floor.enemies[count - 1].health, 0, "last enemy defeated");
        vm.stopPrank();
    }

    function test_battle_playerTakesDamage_whenEnemyHits() public {
        vm.startPrank(user);
        _advanceToFloor(4, 0x1234);
        vm.prevrandao(uint256(0));
        Player memory playerBefore = gameLogic.getPlayer(user);
        gameLogic.battle(0);
        Player memory playerAfter = gameLogic.getPlayer(user);
        assertLt(playerAfter.health, playerBefore.health, "player should take damage when enemy hits");
        vm.stopPrank();
    }

    function test_battle_bossFloor_dropsAndExperience() public {
        vm.startPrank(user);
        _advanceToFloor(4, 0x1234);
        assertEq(gameLogic.getFloor(user).index, 4, "floor 4 is BOSS floor");
        assertTrue(gameLogic.getFloor(user).enemies[0].isBoss, "first enemy is BOSS");

        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        Player memory playerBefore = gameLogic.getPlayer(user);

        vm.prevrandao(0xBEEF);
        gameLogic.battle(0);

        Floor memory floor = gameLogic.getFloor(user);
        assertEq(floor.enemies[0].health, 0, "BOSS defeated");
        assertGt(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore, "coin reward dropped");
        Player memory playerAfter = gameLogic.getPlayer(user);
        assertTrue(
            playerAfter.experience > playerBefore.experience || playerAfter.level > playerBefore.level,
            "experience gained or level up after BOSS"
        );
        assertGt(gameAssets.balanceOf(user, Property.COIN_ID), 0, "player has coin reward");
        vm.stopPrank();
    }

    function test_battle_playerLevelUp_attributesIncrement() public {
        vm.startPrank(user);
        _clearCurrentFloorWithSeed(0x1234);
        if (gameLogic.getPlayer(user).level < 2) {
            gameLogic.nextFloor();
            vm.prevrandao(0x1234);
            gameLogic.battle(0);
        }
        Player memory p = gameLogic.getPlayer(user);
        assertGe(p.level, 1, "level at least 1");
        if (p.level >= 2) {
            (uint16 healthInc, uint16 attackInc, uint16 defenseInc) = Character.levelUpAttributesIncrement();
            assertEq(p.healthMax, 100 + healthInc, "healthMax = 100 + increment");
            assertEq(p.attack, 10 + attackInc, "attack = 10 + increment");
            assertEq(p.defense, 5 + defenseInc, "defense = 5 + increment");
            assertTrue(p.experience <= 3, "remainExp after one level up");
        }
        vm.stopPrank();
    }

    function test_battle_playerDeath_noDropsNoCoinNoExp() public {
        vm.startPrank(user);
        _advanceToFloor(4, 0x1234);
        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        Player memory playerBefore = gameLogic.getPlayer(user);
        vm.stopPrank();
        vm.prank(address(gameLogic));
        heroLogic.setPlayerHealth(user, 1);
        vm.prank(user);
        vm.prevrandao(uint256(1));
        gameLogic.battle(0);

        Player memory playerAfter = gameLogic.getPlayer(user);
        assertEq(playerAfter.health, 0, "player should be dead");
        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore, "no coin gain on death");
        assertEq(playerAfter.experience, playerBefore.experience, "no experience gain on death");
        assertEq(playerAfter.level, playerBefore.level, "no level up on death");
    }

    function test_battle_revertWhenEnemyNotFound_slotOutOfRange() public {
        vm.startPrank(user);
        Floor memory floor = gameLogic.getFloor(user);
        uint256 outOfRangeSlot = floor.enemies.length;

        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EnemyNotFound.selector, outOfRangeSlot));
        gameLogic.battle(outOfRangeSlot);
        vm.stopPrank();
    }

    function test_battle_revertWhenEnemyNotFound_largeSlot() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EnemyNotFound.selector, 10));
        gameLogic.battle(10);
        vm.stopPrank();
    }

    function test_battle_revertWhenEnemyAlreadyDead() public {
        vm.startPrank(user);
        gameLogic.battle(0);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.EnemyNotFound.selector, uint256(0)));
        gameLogic.battle(0);
        vm.stopPrank();
    }
}

contract BattleNotRegisteredTest is RouterTestBase {
    address user = address(0x1234);

    function setUp() public {
        deployRouterStack();
    }

    function test_battle_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.battle(0);
    }
}
