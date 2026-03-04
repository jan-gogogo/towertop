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
import {Floor} from "../src/libraries/Environment.sol";
import {Rarity} from "../src/libraries/Attribute.sol";

/**
 * Unit tests for GameLogic.buy(uint256 typeIndex, uint256 index).
 */
contract BuyTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;

    address game;
    address user;

    function setUp() public {
        user = address(0x1234);

        GameToken token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");
        GameV0 gameV0 = new GameV0(address(token), address(assets));
        game = address(gameV0);

        token.setProxy(game);
        assets.setProxy(game);

        gameLogic = IGameLogic(game);
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _clearCurrentFloor(uint256 battleSeed) internal {
        Floor memory floor = gameLogic.getFloor(user);
        for (uint256 i = 0; i < floor.enemies.length; i++) {
            vm.prevrandao(battleSeed + i);
            gameLogic.battle(i);
        }
    }

    /// Advance to target floor index by clearing each floor and calling nextFloor.
    function _advanceToFloor(uint8 targetIndex, uint256 seedBase) internal {
        while (gameLogic.getFloor(user).index < targetIndex) {
            uint8 idx = gameLogic.getFloor(user).index;
            _clearCurrentFloor(seedBase + uint256(idx) * 100);
            gameLogic.nextFloor();
        }
    }

    /// Advance to a floor that has a shop (floor index 3 with seed that spawns shop).
    function _advanceToFloorWithShop() internal {
        vm.startPrank(user);
        vm.prevrandao(0x1234);
        gameLogic.born();
        _advanceToFloor(2, 0x1234);
        // Clear floor 2 enemies so nextFloor() can advance to floor 3
        _clearCurrentFloor(0x1234 + 200);
        // Seed for floor 3: first byte < 54 => shop appears. 0x20 works.
        vm.prevrandao(uint256(0x2000000000000000000000000000000000000000000000000000000000000000));
        gameLogic.nextFloor();
        vm.stopPrank();
    }

    /// Inline of Property.itemCost (internal): book 3+5*rarityIndex, potion 2+4*rarityIndex, in 1e18.
    function _itemCost(uint256 itemId) internal pure returns (uint256) {
        if (itemId >= 1 && itemId <= 4) {
            return (3 + 5 * (itemId - 1)) * 1 ether;
        }
        if (itemId >= 101 && itemId <= 104) {
            return (2 + 4 * (itemId - 101)) * 1 ether;
        }
        revert("invalid itemId");
    }

    /// Inline of Property.equipmentCost (internal): (3*level + 8*rarity + 2) * 1e18.
    function _equipmentCost(uint8 level, Rarity rarity) internal pure returns (uint256) {
        return (3 * uint256(level) + 8 * uint256(rarity) + 2) * 1 ether;
    }

    function _giveUserCoin(uint256 coinAmount) internal {
        // Coin is ERC1155 with 1e18 units; deposit gives amount*10 Coin per token. Min deposit 1 ether.
        uint256 tokenAmount = coinAmount / 10;
        if (tokenAmount < 1 ether) tokenAmount = 1 ether;
        vm.prank(game);
        gameToken.mint(user, tokenAmount);
        vm.startPrank(user);
        gameToken.approve(game, tokenAmount);
        gameLogic.deposit(tokenAmount);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Happy path
    // -------------------------------------------------------------------------

    function test_buy_item_success() public {
        _advanceToFloorWithShop();
        Floor memory floor = gameLogic.getFloor(user);
        if (floor.shop.items.length == 0) return; // skip if no item slot this seed

        uint256 itemId = floor.shop.items[0];
        uint256 cost = _itemCost(itemId);
        _giveUserCoin(cost + 1 ether); // extra to ensure enough

        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);
        uint256 assetBefore = gameAssets.balanceOf(user, itemId);

        vm.prank(user);
        gameLogic.buy(0, 0);

        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore - cost, "Coin spent");
        assertEq(gameAssets.balanceOf(user, itemId), assetBefore + 1, "item minted");
        floor = gameLogic.getFloor(user);
        assertEq(floor.shop.items[0], 0, "slot cleared (sold)");
    }

    function test_buy_sword_success() public {
        _advanceToFloorWithShop();
        Floor memory floor = gameLogic.getFloor(user);
        if (floor.shop.swords.length == 0) return;

        uint256 cost = _equipmentCost(floor.shop.swords[0].level, floor.shop.swords[0].rarity);
        _giveUserCoin(cost + 1 ether);

        uint256 coinBefore = gameAssets.balanceOf(user, Property.COIN_ID);

        vm.prank(user);
        gameLogic.buy(1, 0);

        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBefore - cost, "Coin spent");
        floor = gameLogic.getFloor(user);
        assertEq(floor.shop.swords[0].level, 0, "sword slot cleared");
    }

    // -------------------------------------------------------------------------
    // Reverts: onlyRegistered
    // -------------------------------------------------------------------------

    function test_buy_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.buy(0, 0);
    }

    // -------------------------------------------------------------------------
    // Reverts: typeIndex
    // -------------------------------------------------------------------------

    function test_buy_revertWhenInvalidTypeIndex() public {
        vm.startPrank(user);
        vm.prevrandao(0x1234);
        gameLogic.born();
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.InvalidTypeIndex.selector, uint256(4)));
        gameLogic.buy(4, 0);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Reverts: index / sold
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // Reverts: insufficient Coin
    // -------------------------------------------------------------------------

    function test_buy_revertWhenInsufficientCoin() public {
        _advanceToFloorWithShop();
        // Give 1 ether -> 10e18 Coin; buy first item then try second with insufficient balance.
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
