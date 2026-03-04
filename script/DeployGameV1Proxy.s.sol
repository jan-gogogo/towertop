// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameV1} from "../src/GameV1.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployGameV1Proxy
 * @author Jan
 * @notice Deploys game with UUPS proxy: GameToken, GameAssets, GameV1 (logic), then ERC1967Proxy.
 *         Proxy is initialized with GameV1.initialize(token, assets, owner). Token and assets
 *         must set their proxy to the proxy contract address after deploy.
 *
 * Env:
 *   OWNER_ADDRESS       - passed to GameV1.initialize as contract owner (e.g. for upgrades)
 *   TOKEN_PRIVATE_KEY   - used to deploy GameToken and call token.setProxy(proxy)
 *   ASSET_PRIVATE_KEY   - used to deploy GameAssets and call assets.setProxy(proxy)
 *   GAME_V1_PRIVATE_KEY - used to deploy GameV1 logic contract
 *   PROXY_PRIVATE_KEY   - used to deploy ERC1967Proxy
 */
contract DeployGameV1Proxy is Script {
    function run() external {
        /*================================================================================
                                        env keys
        =================================================================================*/
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        uint256 tokenPrivKey = vm.envUint("TOKEN_PRIVATE_KEY");
        uint256 assetPrivKey = vm.envUint("ASSET_PRIVATE_KEY");
        uint256 gameV1PrivKey = vm.envUint("GAME_V1_PRIVATE_KEY");
        uint256 proxyPrivKey = vm.envUint("PROXY_PRIVATE_KEY");

        /*================================================================================
                                        deploy
        =================================================================================*/

        vm.startBroadcast(tokenPrivKey);
        GameToken token = new GameToken("Tower Top Token", "TOP");
        console.log("GameToken deployed at:", address(token));
        vm.stopBroadcast();

        vm.startBroadcast(assetPrivKey);
        GameAssets assets = new GameAssets("");
        console.log("GameAssets deployed at:", address(assets));
        vm.stopBroadcast();

        vm.startBroadcast(gameV1PrivKey);
        GameV1 gameV1 = new GameV1();
        console.log("GameV1 deployed at:", address(gameV1));
        vm.stopBroadcast();

        bytes memory data = abi.encodeCall(GameV1.initialize, (address(token), address(assets), ownerAddress));
        vm.startBroadcast(proxyPrivKey);
        ERC1967Proxy proxy = new ERC1967Proxy(address(gameV1), data);
        console.log("ERC1967Proxy deployed at:", address(proxy));
        vm.stopBroadcast();

        /*================================================================================
                        set proxy address on token and assets
        =================================================================================*/

        vm.startBroadcast(tokenPrivKey);
        token.setProxy(address(proxy));
        console.log("GameToken.setProxy(proxy) done");
        vm.stopBroadcast();

        vm.startBroadcast(assetPrivKey);
        assets.setProxy(address(proxy));
        console.log("GameAssets.setProxy(proxy) done");
        vm.stopBroadcast();
    }
}
