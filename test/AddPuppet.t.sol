// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IInventoryLogic} from "../src/interfaces/IInventoryLogic.sol";
import {Rarity} from "../src/libraries/Attribute.sol";
import {Puppet} from "../src/libraries/Property.sol";

/**
 * Unit tests for InventoryLogic.addPuppet.
 */
contract AddPuppetTest is RouterTestBase {
    address user;
    uint256 constant PUPPET_ID_START = 4e9;

    function setUp() public {
        user = address(0x1234);
        deployRouterStack();
    }

    function test_addPuppet_returnsIdAndStoresInWarehouse() public {
        uint40 lastClaimAt = uint40(block.timestamp);

        vm.prank(address(gameLogic));
        uint256 puppetId = inventoryLogic.addPuppet(user, uint8(Rarity.C), lastClaimAt);

        assertEq(puppetId, PUPPET_ID_START, "first puppet id should be 4e9");

        Puppet memory p = inventoryLogic.getPuppet(puppetId);
        assertEq(uint8(p.rarity), uint8(Rarity.C), "rarity should be C");
        assertEq(p.lastClaimAt, lastClaimAt, "lastClaimAt should match");

        uint256[] memory wh = inventoryLogic.getWarehouse(user);
        assertEq(wh.length, 1, "warehouse should have one slot");
        assertEq(wh[0], puppetId, "warehouse slot 0 should be puppet id");
    }

    function test_addPuppet_secondPuppet_returnsNextId() public {
        vm.prank(address(gameLogic));
        uint256 id0 = inventoryLogic.addPuppet(user, uint8(Rarity.C), uint40(block.timestamp));

        vm.prank(address(gameLogic));
        uint256 id1 = inventoryLogic.addPuppet(user, uint8(Rarity.B), uint40(block.timestamp + 1));

        assertEq(id0, PUPPET_ID_START, "first id 4e9");
        assertEq(id1, PUPPET_ID_START + 1, "second id 4e9+1");

        assertEq(uint8(inventoryLogic.getPuppet(id1).rarity), uint8(Rarity.B), "second puppet rarity B");
        uint256[] memory wh = inventoryLogic.getWarehouse(user);
        assertEq(wh.length, 2, "warehouse should have two entries");
        assertEq(wh[0], id0, "slot 0 first puppet");
        assertEq(wh[1], id1, "slot 1 second puppet");
    }

    function test_addPuppet_revertWhenNotPermitted() public {
        vm.prank(user);
        vm.expectRevert(IInventoryLogic.Unauthorized.selector);
        inventoryLogic.addPuppet(user, uint8(Rarity.C), uint40(block.timestamp));
    }
}
