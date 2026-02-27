// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameV1} from "../src/GameV1.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";
import {console} from "forge-std/console.sol";

contract DeployProxyGame is Script {
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
        GameToken token = new GameToken("T3", "TowerTop");
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

        // deploy the proxy contract
        bytes memory data = abi.encodeCall(GameV1.initialize, (address(token), address(assets), ownerAddress));
        vm.startBroadcast(proxyPrivKey);
        // arg1: the impl contract
        // arg2: constructor params of the impl contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(gameV1), data);
        console.log("encoded data:", vm.toString(data));
        console.log("ERC1967Proxy deployed at:", address(proxy));
        vm.stopBroadcast();

        /*================================================================================
                                set proxy address to other contracts
        =================================================================================*/

        // tx sender must be the deployer
        vm.startBroadcast(tokenPrivKey);
        token.setProxy(address(proxy));
        vm.stopBroadcast();

        vm.startBroadcast(assetPrivKey);
        assets.setProxy(address(proxy));
        vm.stopBroadcast();
    }
}
