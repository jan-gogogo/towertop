// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV1} from "../src/GameV1.sol";
import {HeroV1} from "../src/HeroV1.sol";
import {InventoryV1} from "../src/InventoryV1.sol";
import {TransparentUpgradeableProxy} from "../src/TransparentUpgradeableProxy.sol";
import {IHeroLogic} from "../src/interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "../src/interfaces/IInventoryLogic.sol";

/**
 * @notice Deploys the full Tower Top stack:
 *         GameToken, GameAssets (no proxy),
 *         GameV1, HeroV1, InventoryV1 (logic) + TransparentUpgradeableProxy each.
 *         Wires setPermit(gameProxy) on Hero/Inventory and setProxy(gameProxy) on Token/Assets.
 * @dev    Run with: forge script script/DeployGame.s.sol:DeployGame --rpc-url <RPC> --broadcast
 *         Optional env: OWNER_ADDRESS (proxy admin; default = broadcast sender).
 */
contract DeployGame is Script {
    function run()
        external
        returns (address gameProxy, address heroProxy, address inventoryProxy, address token, address assets)
    {
        address owner = vm.envOr("OWNER_ADDRESS", msg.sender);
        uint256 tokenPrivKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(tokenPrivKey);

        GameToken _token = new GameToken("Aoka Tower Token", "ATT");
        GameAssets _assets = new GameAssets("");
        token = address(_token);
        assets = address(_assets);

        GameV1 gameImpl = new GameV1();
        HeroV1 heroImpl = new HeroV1();
        InventoryV1 inventoryImpl = new InventoryV1();

        bytes memory heroInit = abi.encodeCall(HeroV1.initialize, (address(0)));
        TransparentUpgradeableProxy _heroProxy = new TransparentUpgradeableProxy(address(heroImpl), owner, heroInit);
        heroProxy = address(_heroProxy);

        bytes memory inventoryInit = abi.encodeCall(InventoryV1.initialize, (address(0)));
        TransparentUpgradeableProxy _inventoryProxy =
            new TransparentUpgradeableProxy(address(inventoryImpl), owner, inventoryInit);
        inventoryProxy = address(_inventoryProxy);

        bytes memory gameInit = abi.encodeCall(
            GameV1.initialize,
            (
                heroProxy,
                inventoryProxy,
                token,
                assets,
                vm.envAddress("VRF_COORDINATOR"),
                vm.envBytes32("VRF_KEY_HASH"),
                vm.envUint("VRF_SUBSCRIPTION")
            )
        );
        TransparentUpgradeableProxy _gameProxy = new TransparentUpgradeableProxy(address(gameImpl), owner, gameInit);
        gameProxy = address(_gameProxy);

        IHeroLogic(heroProxy).setPermit(gameProxy);
        IInventoryLogic(inventoryProxy).setPermit(gameProxy);

        _token.setProxy(gameProxy);
        _assets.setProxy(gameProxy);

        vm.stopBroadcast();

        console.log("Game proxy (user entry):", gameProxy);
        console.log("Hero proxy:             ", heroProxy);
        console.log("Inventory proxy:        ", inventoryProxy);
        console.log("GameToken:              ", token);
        console.log("GameAssets:             ", assets);
        console.log("Proxy admin (owner):    ", owner);
    }
}
