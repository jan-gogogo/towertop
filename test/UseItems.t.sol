// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Property} from "../src/libraries/Property.sol";

/**
 * Unit tests for Game.useItems.
 */
contract UseItemsTest is RouterTestBase {
    address user;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
    }

    function test_useItems_revertWhenEmptySlots() public {
        vm.startPrank(user);
        gameLogic.born();
        uint256[] memory empty;
        vm.expectRevert(IGameLogic.LengthOutOfRange1To5.selector);
        gameLogic.useItems(empty);
        vm.stopPrank();
    }

    function test_useItems_revertWhenMoreThan5Slots() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(IGameLogic.LengthOutOfRange1To5.selector);
        gameLogic.useItems(_slots(0, 1, 2, 3, 4, 5));
        vm.stopPrank();
    }

    function test_useItems_revertWhenDuplicateSlots() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.stopPrank();
        vm.prank(address(gameLogic));
        inventoryLogic.addItem(user, Property.BOOK_C_ID);
        vm.prank(user);
        vm.expectRevert(IGameLogic.WrongSequence.selector);
        gameLogic.useItems(_slots(0, 0));
    }

    function test_useItems_revertWhenSlotOutOfRange() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.ItemNotFound.selector, uint256(10)));
        gameLogic.useItems(_slots(10));
        vm.stopPrank();
    }

    function test_useItems_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.useItems(_slots(0));
    }

    function _slots(uint256 a) internal pure returns (uint256[] memory) {
        uint256[] memory s = new uint256[](1);
        s[0] = a;
        return s;
    }

    function _slots(uint256 a, uint256 b) internal pure returns (uint256[] memory) {
        uint256[] memory s = new uint256[](2);
        s[0] = a;
        s[1] = b;
        return s;
    }

    function _slots(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory) {
        uint256[] memory s = new uint256[](3);
        s[0] = a;
        s[1] = b;
        s[2] = c;
        return s;
    }

    function _slots(uint256 a, uint256 b, uint256 c, uint256 d, uint256 e, uint256 f)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory s = new uint256[](6);
        s[0] = a;
        s[1] = b;
        s[2] = c;
        s[3] = d;
        s[4] = e;
        s[5] = f;
        return s;
    }
}
