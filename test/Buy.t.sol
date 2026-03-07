// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Property, Equipment} from "../src/libraries/Property.sol";
import {Floor} from "../src/libraries/Environment.sol";

/**
 * Unit tests for Game.buy(uint256 typeIndex, uint256 slot).
 */
contract BuyTest is RouterTestBase {
    address game;
    address user;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
        game = address(gameLogic);
    }

    function _clearCurrentFloor(uint256 battleSeed) internal {
        Floor memory floor = gameLogic.getFloor(user);
        for (uint256 i = 0; i < floor.enemies.length; i++) {
            vm.prevrandao(battleSeed + i);
            gameLogic.battle(i);
        }
    }

    function _advanceToFloor(uint8 targetIndex, uint256 seedBase) internal {
        while (gameLogic.getFloor(user).index < targetIndex) {
            uint8 idx = gameLogic.getFloor(user).index;
            _clearCurrentFloor(seedBase + uint256(idx) * 100);
            gameLogic.nextFloor();
        }
    }

    function _advanceToFloorWithShop() internal {
        vm.startPrank(user);
        vm.prevrandao(0x1234);
        gameLogic.born();
        _advanceToFloor(2, 0x1234);
        _clearCurrentFloor(0x1234 + 200);
        vm.prevrandao(uint256(0x2000000000000000000000000000000000000000000000000000000000000000));
        gameLogic.nextFloor();
        vm.stopPrank();
    }

    function _itemCost(uint256 itemId) internal pure returns (uint256) {
        if (itemId >= 1 && itemId <= 4) return (3 + 5 * (itemId - 1)) * 1 ether;
        if (itemId >= 101 && itemId <= 104) return (2 + 4 * (itemId - 101)) * 1 ether;
        revert("invalid itemId");
    }

    function _giveUserCoin(uint256 coinAmount) internal {
        uint256 tokenAmount = coinAmount / 10;
        if (tokenAmount < 1 ether) tokenAmount = 1 ether;
        vm.prank(game);
        gameToken.mint(user, tokenAmount);
        vm.startPrank(user);
        gameToken.approve(address(gameLogic), tokenAmount);
        gameLogic.deposit(tokenAmount);
        vm.stopPrank();
    }

    function test_buy_item_success() public {
        _advanceToFloorWithShop();
        Floor memory floor = gameLogic.getFloor(user);
        if (floor.shop.items.length == 0) return;

        uint256 itemId = floor.shop.items[0];
        uint256 cost = _itemCost(itemId);
        _giveUserCoin(cost + 1 ether);

        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        uint256 assetBefore = gameAssets.balanceOf(user, itemId);

        vm.prank(user);
        gameLogic.buy(0, 0);

        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore - cost, "Coin spent");
        assertEq(gameAssets.balanceOf(user, itemId), assetBefore + 1, "item minted");
        floor = gameLogic.getFloor(user);
        assertEq(floor.shop.items[0], 0, "slot cleared");
    }

    function test_buy_equipment_success() public {
        _advanceToFloorWithShop();
        Floor memory floor = gameLogic.getFloor(user);
        if (floor.shop.equipments.length == 0) return;

        Equipment memory eq = floor.shop.equipments[0];
        uint256 cost = (3 * uint256(eq.level) + 8 * uint256(eq.rarity) + 2) * 1 ether;
        _giveUserCoin(cost + 1 ether);

        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);

        vm.prank(user);
        gameLogic.buy(1, 0);

        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore - cost, "Coin spent");
        floor = gameLogic.getFloor(user);
        assertEq(floor.shop.equipments[0].level, 0, "equipment slot cleared");
    }

    function test_buy_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.buy(0, 0);
    }

    function test_buy_revertWhenInvalidTypeIndex() public {
        vm.startPrank(user);
        vm.prevrandao(0x1234);
        gameLogic.born();
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidTypeIndex.selector, uint256(4)));
        gameLogic.buy(4, 0);
        vm.stopPrank();
    }

    function test_buy_revertWhenIndexOutOfRange() public {
        _advanceToFloorWithShop();
        uint256 outOfRange = 1000;

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidIndex.selector, outOfRange));
        gameLogic.buy(0, outOfRange);
    }

    function test_buy_revertWhenItemAlreadySold() public {
        _advanceToFloorWithShop();
        Floor memory floor = gameLogic.getFloor(user);
        if (floor.shop.items.length == 0) return;

        uint256 itemId = floor.shop.items[0];
        _giveUserCoin(_itemCost(itemId) + 1 ether);

        vm.startPrank(user);
        gameLogic.buy(0, 0);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidIndex.selector, uint256(0)));
        gameLogic.buy(0, 0);
        vm.stopPrank();
    }

    function test_buy_revertWhenInsufficientCoin() public {
        _advanceToFloorWithShop();
        _giveUserCoin(1 ether);
        Floor memory floor = gameLogic.getFloor(user);
        if (floor.shop.items.length >= 2) {
            uint256 cost0 = _itemCost(floor.shop.items[0]);
            uint256 cost1 = _itemCost(floor.shop.items[1]);
            if (cost0 < 10 ether && cost1 > 10 ether - cost0) {
                vm.startPrank(user);
                gameLogic.buy(0, 0);
                vm.expectRevert(IGameLogic.InsufficientCoin.selector);
                gameLogic.buy(0, 1);
                vm.stopPrank();
            }
        }
    }
}
