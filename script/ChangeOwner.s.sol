// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @notice Changes owner for Game, Hero, and Inventory proxies.
 * @dev    Run with: forge script script/ChangeOwner.s.sol:ChangeOwner --rpc-url <RPC> --broadcast -vvvv
 *         Two-step ownership transfer: first this script initiates transfer, then new owner must call acceptOwnership.
 */
contract ChangeOwner is Script {
    function run() external {
        address newOwner = vm.envAddress("NEW_OWNER");
        address gameProxy = vm.envAddress("GAME_PROXY");
        address heroProxy = vm.envAddress("HERO_PROXY");
        address inventoryProxy = vm.envAddress("INVENTORY_PROXY");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Ownable2StepUpgradeable(gameProxy).transferOwnership(newOwner);
        Ownable2StepUpgradeable(heroProxy).transferOwnership(newOwner);
        Ownable2StepUpgradeable(inventoryProxy).transferOwnership(newOwner);

        // then the new owner must call
        // Ownable2StepUpgradeable(gameProxy).acceptOwnership();

        vm.stopBroadcast();

        console.log("New owner address: ", newOwner);
        console.log("Game proxy:        ", gameProxy);
        console.log("Hero proxy:        ", heroProxy);
        console.log("Inventory proxy:   ", inventoryProxy);
        console.log("Two-step transfer initiated. New owner must call acceptOwnership() on each proxy.");
    }
}
