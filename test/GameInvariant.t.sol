// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {GameV0} from "../src/GameV0.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {Player} from "../src/libraries/Character.sol";
import {Floor} from "../src/libraries/Environment.sol";

/// @dev Test-only HARNESS that exposes internal getters for invariants.
contract GameV0Harness is GameV0 {
    constructor(address _gameToken_, address _gameAssets_) GameV0(_gameToken_, _gameAssets_) {}

    function exposedGetPlayerLevel(address player) external view returns (uint8) {
        Player storage p = findPlayer(player);
        return p.level;
    }

    function exposedGetFloorIndex(address player) external view returns (uint8) {
        Floor storage f = findFloor(player);
        return f.index;
    }

    function exposedGetEnemiesCount(address player) external view returns (uint256) {
        Floor storage f = findFloor(player);
        return f.enemies.length;
    }
}

/// @dev Handler that Foundry's invariant engine will fuzz-call.
///      It represents "a single player" interacting with the game.
contract GameHandler {
    IGameLogic public immutable GAME;
    GameV0Harness public immutable HARNESS;

    constructor(IGameLogic _game, GameV0Harness _harness) {
        GAME = _game;
        HARNESS = _harness;
    }

    /// @dev Try to create a player. If it already exists, the call will revert and be counted.
    function doBorn() external {
        GAME.born();
    }

    /// @dev Try to battle a random enemy index. We first read the current enemy
    ///      count for this player and modulo the fuzzed index, so that almost
    ///      every call results in an actual battle instead of EnemyNotFound.
    function doBattle(uint256 enemyIdx) external {
        uint256 count = HARNESS.exposedGetEnemiesCount(address(this));
        if (count == 0) {
            revert();
        }

        uint256 idx = enemyIdx % count;
        GAME.battle(idx);
    }

    /// @dev Try to advance to the next floor. This will revert unless all enemies
    ///      on the current floor have been defeated or the player is already at
    ///      the top floor; such reverts are counted by the invariant engine.
    function doNextFloor() external {
        GAME.nextFloor();
    }
}

contract GameInvariantTest is Test {
    GameV0Harness internal game;
    IGameLogic internal gameLogic;
    GameHandler internal handler;

    function setUp() public {
        // Deploy token and assets
        GameToken token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");

        // Deploy game directly (no proxy)
        GameV0Harness gameContract = new GameV0Harness(address(token), address(assets));

        token.setProxy(address(gameContract));
        assets.setProxy(address(gameContract));

        game = GameV0Harness(address(gameContract));
        gameLogic = IGameLogic(address(gameContract));

        handler = new GameHandler(gameLogic, game);
        targetContract(address(handler));
    }

    /// @notice Invariant: player level must never exceed 100,
    ///          and floor index must never exceed 99, regardless of handler calls.
    function invariant_playerLevelAndFloorIndexBounded() public view {
        address actor = address(handler);

        uint8 level = game.exposedGetPlayerLevel(actor);
        uint8 floorIndex = game.exposedGetFloorIndex(actor);

        assertLe(level, 10, "player level should never exceed 100");
        assertLe(floorIndex, 99, "floor index should never exceed 99");
    }
}

