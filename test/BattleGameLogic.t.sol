// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV1} from "../src/GameV1.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";
import {Property} from "../src/libraries/Property.sol";
import {Player} from "../src/libraries/Character.sol";
import {Floor} from "../src/libraries/Environment.sol";
import {Character} from "../src/libraries/Character.sol";

contract GameV1BattleHarness is GameV1 {
    function exposedSetPlayerHealth(address addr, uint16 h) external {
        findPlayer(addr).health = h;
    }
}

/**
 * Unit tests for GameLogic.battle(uint256 enemySlot).
 */
contract BattleGameLogicTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;
    GameV1BattleHarness harness;

    address proxy;
    address owner;
    address user;

    GameToken token;

    function setUp() public {
        owner = address(0x1222223332);
        user = address(0x1234);

        token = new GameToken("T3", "TowerTop");
        GameAssets assets = new GameAssets("");
        GameV1BattleHarness impl = new GameV1BattleHarness();

        bytes memory data = abi.encodeCall(GameV1.initialize, (address(token), address(assets), owner));
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(impl), data);
        proxy = address(proxyContract);

        token.setProxy(proxy);
        assets.setProxy(proxy);

        gameLogic = IGameLogic(proxy);
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
        harness = GameV1BattleHarness(proxy);

        vm.startPrank(user);
        vm.prevrandao(0x1234);
        gameLogic.born();
        vm.stopPrank();
    }

    /// Clear all enemies on current floor; each battle uses baseSeed + slotIndex so outcomes are deterministic.
    function _clearCurrentFloorWithSeed(uint256 baseSeed) internal {
        Floor memory floor = gameLogic.getFloor(user);
        for (uint256 i = 0; i < floor.enemies.length; i++) {
            vm.prevrandao(baseSeed + i);
            gameLogic.battle(i);
        }
    }

    /// Advance to target floor index by clearing each floor (with per-battle seeds) and calling nextFloor.
    function _advanceToFloor(uint8 targetIndex, uint256 seedBase) internal {
        while (gameLogic.getFloor(user).index < targetIndex) {
            uint8 idx = gameLogic.getFloor(user).index;
            _clearCurrentFloorWithSeed(seedBase + uint256(idx) * 100);
            gameLogic.nextFloor();
        }
    }

    function test_battle_for_snapshot() public {
        vm.pauseGasMetering();
        vm.startPrank(user);
        vm.resetGasMetering();
        gameLogic.battle(0);
    }

    // --- Happy path ---

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

    // --- Player takes damage ---

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

    // --- BOSS floor: drops and experience ---

    function test_battle_bossFloor_dropsAndExperience() public {
        vm.startPrank(user);
        _advanceToFloor(4, 0x1234);
        assertEq(gameLogic.getFloor(user).index, 4, "floor 4 is BOSS floor (5th floor)");
        assertTrue(gameLogic.getFloor(user).enemies[0].isBoss, "first enemy is BOSS");

        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        Player memory playerBefore = gameLogic.getPlayer(user);

        vm.prevrandao(0xBEEF);
        gameLogic.battle(0);

        Floor memory floor = gameLogic.getFloor(user);
        assertEq(floor.enemies[0].health, 0, "BOSS defeated");
        assertGt(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore, "coin reward dropped");
        assertGt(gameLogic.getPlayer(user).experience, playerBefore.experience, "experience gained");
        // Reward items/equipment are minted via ERC1155; at least coins and exp are granted
        assertGt(gameAssets.balanceOf(user, Property.COIN_ID), 0, "player has coin reward");
        vm.stopPrank();
    }

    // --- Level up: attribute increments ---

    function test_battle_playerLevelUp_attributesIncrement() public {
        vm.startPrank(user);
        _clearCurrentFloorWithSeed(0x1234);
        if (gameLogic.getPlayer(user).level < 2) {
            gameLogic.nextFloor();
            vm.prevrandao(0x1234);
            gameLogic.battle(0);
        }
        Player memory p = gameLogic.getPlayer(user);
        assertEq(p.level, 2, "level should be 2");
        (uint16 healthInc, uint16 attackInc, uint16 defenseInc) = Character.levelUpAttributesIncrement(1);
        assertEq(p.healthMax, 100 + healthInc, "healthMax = 100 + increment");
        assertEq(p.attack, 10 + attackInc, "attack = 10 + increment");
        assertEq(p.defense, 5 + defenseInc, "defense = 5 + increment");
        assertTrue(p.experience <= 3, "remainExp after one level up");
        vm.stopPrank();
    }

    // --- Player death: no reward ---

    function test_battle_playerDeath_noDropsNoCoinNoExp() public {
        vm.startPrank(user);
        _advanceToFloor(4, 0x1234);
        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        Player memory playerBefore = gameLogic.getPlayer(user);
        harness.exposedSetPlayerHealth(user, 1);
        vm.prevrandao(uint256(1));
        gameLogic.battle(0);

        Player memory playerAfter = gameLogic.getPlayer(user);
        assertEq(playerAfter.health, 0, "player should be dead");
        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore, "no coin gain on death");
        assertEq(playerAfter.experience, playerBefore.experience, "no experience gain on death");
        assertEq(playerAfter.level, playerBefore.level, "no level up on death");
        vm.stopPrank();
    }

    // --- Reverts: enemy slot ---

    function test_battle_revertWhenEnemyNotFound_slotOutOfRange() public {
        vm.startPrank(user);
        Floor memory floor = gameLogic.getFloor(user);
        uint256 outOfRangeSlot = floor.enemies.length; // first invalid index

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
}

/**
 * Revert tests that require user not to be registered (no born in setUp).
 */
contract BattleGameLogicNotRegisteredTest is Test {
    IGameLogic gameLogic;
    address proxy;
    address user;

    function setUp() public {
        user = address(0x1234);
        GameToken token = new GameToken("T3", "TowerTop");
        GameAssets assets = new GameAssets("");
        GameV1BattleHarness impl = new GameV1BattleHarness();
        bytes memory data = abi.encodeCall(GameV1.initialize, (address(token), address(assets), address(0x1222223332)));
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(impl), data);
        proxy = address(proxyContract);
        token.setProxy(proxy);
        assets.setProxy(proxy);
        gameLogic = IGameLogic(proxy);
    }

    function test_battle_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.battle(0);
    }
}
