// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GameV1} from "../src/GameV1.sol";
import {HeroV1} from "../src/HeroV1.sol";
import {InventoryV1} from "../src/InventoryV1.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @notice Upgrades logic contracts for Game, Hero, and Inventory proxies.
 * @dev    Run with: forge script script/UpgradeContracts.s.sol:UpgradeContracts --rpc-url <RPC> --broadcast -vvvv
 */
contract UpgradeContracts is Script {
    function run() external {
        address gameProxy = vm.envAddress("GAME_PROXY");
        address heroProxy = vm.envAddress("HERO_PROXY");
        address inventoryProxy = vm.envAddress("INVENTORY_PROXY");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        GameV1 newGameImpl = new GameV1();
        HeroV1 newHeroImpl = new HeroV1();
        InventoryV1 newInventoryImpl = new InventoryV1();

        UUPSUpgradeable(gameProxy).upgradeToAndCall(address(newGameImpl), "");

        UUPSUpgradeable(heroProxy).upgradeToAndCall(address(newHeroImpl), "");

        UUPSUpgradeable(inventoryProxy).upgradeToAndCall(address(newInventoryImpl), "");

        vm.stopBroadcast();

        console.log("Upgraded Game proxy to:       ", address(newGameImpl));
        console.log("Upgraded Hero proxy to:        ", address(newHeroImpl));
        console.log("Upgraded Inventory proxy to:   ", address(newInventoryImpl));
    }
}
