// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameV0} from "../src/GameV0.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployGameV0
 * @author Jan
 * @notice Deploys game without proxy: GameToken, GameAssets, then GameV0.
 *         Token and assets must set their proxy to the GameV0 address after deploy.
 *
 * Env:
 *   TOKEN_PRIVATE_KEY   - used to deploy GameToken and call token.setProxy(gameV0)
 *   ASSET_PRIVATE_KEY   - used to deploy GameAssets and call assets.setProxy(gameV0)
 *   GAME_V0_PRIVATE_KEY - used to deploy GameV0
 */
contract DeployGameV0 is Script {
    function run() external {
        /*================================================================================
                                        env keys
        =================================================================================*/
        uint256 tokenPrivKey = vm.envUint("TOKEN_PRIVATE_KEY");
        uint256 assetPrivKey = vm.envUint("ASSET_PRIVATE_KEY");
        uint256 gameV0PrivKey = vm.envUint("GAME_V0_PRIVATE_KEY");

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

        vm.startBroadcast(gameV0PrivKey);
        GameV0 gameV0 = new GameV0(address(token), address(assets));
        console.log("GameV0 deployed at:", address(gameV0));
        vm.stopBroadcast();

        /*================================================================================
                        set GameV0 as owner on token and assets
        =================================================================================*/

        vm.startBroadcast(tokenPrivKey);
        token.setProxy(address(gameV0));
        console.log("GameToken.setProxy(GameV0) done");
        vm.stopBroadcast();

        vm.startBroadcast(assetPrivKey);
        assets.setProxy(address(gameV0));
        console.log("GameAssets.setProxy(GameV0) done");
        vm.stopBroadcast();
    }
}
