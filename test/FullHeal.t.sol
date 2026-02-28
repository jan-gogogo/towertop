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
import {Player} from "../src/libraries/Character.sol";

/**
 * Unit tests for GameLogic.fullHeal (spend Coin to restore health to healthMax).
 */
contract FullHealTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;

    address proxy;
    address owner;
    address user;

    GameToken token;

    function setUp() public {
        owner = address(0x1222223332);
        user = address(0x1234);

        token = new GameToken("T3", "TowerTop");
        GameAssets assets = new GameAssets("");
        GameV1 impl = new GameV1();

        bytes memory data = abi.encodeCall(GameV1.initialize, (address(token), address(assets), owner));
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(impl), data);
        proxy = address(proxyContract);

        token.setProxy(proxy);
        assets.setProxy(proxy);

        gameLogic = IGameLogic(proxy);
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
