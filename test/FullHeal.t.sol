// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Player} from "../src/libraries/Character.sol";

/**
 * Unit tests for Game.fullHeal (spend Coin to restore health to healthMax).
 */
contract FullHealTest is RouterTestBase {
    address user;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
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
