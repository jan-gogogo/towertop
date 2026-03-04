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
import {Player} from "../src/libraries/Character.sol";

/**
 * Harness to expose addItem for useItems tests (put books/potions in bag).
 */
contract GameV0UseItemsHarness is GameV0 {
    constructor(address _gameToken_, address _gameAssets_) GameV0(_gameToken_, _gameAssets_) {}

    function exposedAddItemToBag(uint256 itemId) external {
        addItem(msg.sender, itemId);
    }
}

/**
 * Unit tests for GameLogic.useItems.
 */
contract UseItemsTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;
    GameV0UseItemsHarness harness;

    address user;

    function setUp() public {
        user = address(0x1234);

        GameToken token = new GameToken("Tower Top Token", "TOP");
        GameAssets assets = new GameAssets("");
        GameV0UseItemsHarness game = new GameV0UseItemsHarness(address(token), address(assets));

        token.setProxy(address(game));
        assets.setProxy(address(game));

        gameLogic = IGameLogic(address(game));
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
        harness = GameV0UseItemsHarness(address(game));
    }

    // -------------------------------------------------------------------------
    // Happy path
    // -------------------------------------------------------------------------

    function test_useItems_singlePotion_slot0() public {
        vm.startPrank(user);
        gameLogic.born();
        // born gives 1 potion at slot 0; use it
        gameLogic.useItems(_slots(0));
        vm.stopPrank();

        uint256[] memory bag = gameLogic.getBag(user);
        assertEq(bag.length, 1, "bag length unchanged (slot still exists)");
        assertEq(bag[0], 0, "slot 0 consumed");
        Player memory p = gameLogic.getPlayer(user);
        assertEq(p.health, 100, "health capped at healthMax (was full)");
    }

    function test_useItems_singleBook_levelUp() public {
        vm.startPrank(user);
        gameLogic.born();
        harness.exposedAddItemToBag(Property.BOOK_C_ID); // slot 1
        gameLogic.useItems(_slots(1));
        vm.stopPrank();

        Player memory p = gameLogic.getPlayer(user);
        assertEq(p.level, 2, "BOOK_C gives 10 exp, level 1 needs 10 to level up");
        uint256[] memory bag = gameLogic.getBag(user);
        assertEq(bag[1], 0, "slot 1 consumed");
    }

    function test_useItems_twoSlots_ascendingOrder() public {
        vm.startPrank(user);
        gameLogic.born();
        harness.exposedAddItemToBag(Property.BOOK_C_ID); // slot 1
        harness.exposedAddItemToBag(Property.POTION_B_ID); // slot 2
        gameLogic.useItems(_slots(0, 1, 2)); // use potion at 0, book at 1, potion at 2
        vm.stopPrank();

        Player memory p = gameLogic.getPlayer(user);
        assertEq(p.level, 2, "one book used");
        uint256[] memory bag = gameLogic.getBag(user);
        assertEq(bag[0], 0, "slot 0 consumed");
        assertEq(bag[1], 0, "slot 1 consumed");
        assertEq(bag[2], 0, "slot 2 consumed");
    }

    function test_useItems_singleSlot_len1Allowed() public {
        vm.startPrank(user);
        gameLogic.born();
        gameLogic.useItems(_slots(0));
        vm.stopPrank();
        assertEq(gameLogic.getBag(user)[0], 0, "single slot use works");
    }

    // -------------------------------------------------------------------------
    // Reverts: length
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // Reverts: sequence
    // -------------------------------------------------------------------------

    function test_useItems_revertWhenWrongSequence() public {
        vm.startPrank(user);
        gameLogic.born();
        harness.exposedAddItemToBag(Property.BOOK_C_ID);
        vm.expectRevert(IGameLogic.WrongSequence.selector);
        gameLogic.useItems(_slots(1, 0)); // descending
        vm.stopPrank();
    }

    function test_useItems_revertWhenDuplicateSlots() public {
        vm.startPrank(user);
        gameLogic.born();
        harness.exposedAddItemToBag(Property.BOOK_C_ID);
        vm.expectRevert(IGameLogic.WrongSequence.selector);
        gameLogic.useItems(_slots(0, 0));
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Reverts: slot / item
    // -------------------------------------------------------------------------

    function test_useItems_revertWhenSlotOutOfRange() public {
        vm.startPrank(user);
        gameLogic.born();
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.ItemNotFound.selector, uint256(10)));
        gameLogic.useItems(_slots(10));
        vm.stopPrank();
    }

    function test_useItems_revertWhenSlotEmpty() public {
        vm.startPrank(user);
        gameLogic.born();
        gameLogic.useItems(_slots(0)); // consume slot 0
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.ItemNotFound.selector, uint256(0)));
        gameLogic.useItems(_slots(0)); // use again
        vm.stopPrank();
    }

    function test_useItems_revertWhenWrongItemType() public {
        vm.startPrank(user);
        gameLogic.born();
        harness.exposedAddItemToBag(Property.REFERSH_STONE_ID); // Stone, not usable
        vm.expectRevert(IGameLogic.WrongItemType.selector);
        gameLogic.useItems(_slots(1));
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Reverts: onlyRegistered
    // -------------------------------------------------------------------------

    function test_useItems_revertWhenNotRegistered() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IGameLogic.PlayerNotFound.selector, user));
        gameLogic.useItems(_slots(0));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

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
