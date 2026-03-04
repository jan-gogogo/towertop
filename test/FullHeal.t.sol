// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV0} from "../src/GameV0.sol";
import {Player} from "../src/libraries/Character.sol";

/**
 * Unit tests for GameLogic.fullHeal (spend Coin to restore health to healthMax).
 */
contract FullHealTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;

    address user;

    GameToken token;

    function setUp() public {
        user = address(0x1234);

        token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");
        GameV0 gameV0 = new GameV0(address(token), address(assets));

        token.setProxy(address(gameV0));
        assets.setProxy(address(gameV0));

        gameLogic = IGameLogic(address(gameV0));
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
    }

    function test_fullHeal_revertWhenAlreadyFullHealth() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(IGameLogic.AlreadyFullHealth.selector);
        gameLogic.fullHeal();
        vm.stopPrank();
    }

    function test_fullHeal_revertWhenInsufficientCoin() public {
        vm.prevrandao(0x1234);
        vm.startPrank(user);
        gameLogic.born();

        gameLogic.battle(0);
        gameLogic.battle(1);
        gameLogic.battle(2);
        gameLogic.battle(3);
        Player memory player = gameLogic.getPlayer(user);
        assertGt(player.healthMax, player.health);
        // Level 1 cost = (5 + 2) * 1e18 = 7e18. User has 0 Coin (only got token from born, no deposit).
        vm.expectRevert(IGameLogic.InsufficientCoin.selector);
        gameLogic.fullHeal();
        vm.stopPrank();
    }

    function test_fullHeal_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.fullHeal();
    }
}
