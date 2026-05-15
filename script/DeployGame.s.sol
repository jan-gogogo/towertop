// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV1} from "../src/GameV1.sol";
import {HeroV1} from "../src/HeroV1.sol";
import {InventoryV1} from "../src/InventoryV1.sol";
import {Protocol} from "../src/Protocol.sol";
import {FeePool} from "../src/FeePool.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";
import {IHeroLogic} from "../src/interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "../src/interfaces/IInventoryLogic.sol";

/**
 * @notice Deploys the full Tower Top stack:
 *         GameToken, GameAssets (no proxy),
 *         GameV1, HeroV1, InventoryV1 (logic) + ERC1967Proxy each (UUPS pattern).
 *         Wires setPermit(gameProxy) on Hero/Inventory and authorize(gameProxy) on Token/Assets.
 * @dev    Run with: forge script script/DeployGame.s.sol:DeployGame --rpc-url <RPC> --broadcast
 *         Optional env: OWNER_ADDRESS (proxy admin; default = broadcast sender).
 */
contract DeployGame is Script {
    uint256 constant SLOPE = 0.000000005 ether; // 5e-9
    uint256 constant INIT_PRICE = 0.1 ether; // value is 0.01 USDT

    function run()
        external
        returns (
            address gameProxy,
            address heroProxy,
            address inventoryProxy,
            address token,
            address assets,
            address protocol,
            address feePool
        )
    {
        address owner = vm.envAddress("OWNER_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        GameToken _token = new GameToken("Aoka Tower Token", "ATT");
        GameAssets _assets = new GameAssets("");
        FeePool _feePool = new FeePool(owner);
        Protocol _protocol = new Protocol(address(_token), address(_feePool), SLOPE, INIT_PRICE);

        token = address(_token);
        assets = address(_assets);
        protocol = address(_protocol);
        feePool = address(_feePool);

        GameV1 gameImpl = new GameV1();
        HeroV1 heroImpl = new HeroV1();
        InventoryV1 inventoryImpl = new InventoryV1();

        // Deploy Hero proxy (UUPS)
        bytes memory heroInit = abi.encodeCall(HeroV1.initialize, (address(0), owner));
        ERC1967Proxy _heroProxy = new ERC1967Proxy(address(heroImpl), heroInit);
        heroProxy = address(_heroProxy);

        // Deploy Inventory proxy (UUPS)
        bytes memory inventoryInit = abi.encodeCall(InventoryV1.initialize, (address(0), owner));
        ERC1967Proxy _inventoryProxy = new ERC1967Proxy(address(inventoryImpl), inventoryInit);
        inventoryProxy = address(_inventoryProxy);

        // Deploy Game proxy (UUPS)
        bytes memory gameInit = abi.encodeCall(
            GameV1.initialize,
            (
                heroProxy,
                inventoryProxy,
                token,
                assets,
                protocol,
                vm.envAddress("VRF_COORDINATOR"),
                vm.envBytes32("VRF_KEY_HASH"),
                vm.envUint("VRF_SUBSCRIPTION"),
                owner
            )
        );
        ERC1967Proxy _gameProxy = new ERC1967Proxy(address(gameImpl), gameInit);
        gameProxy = address(_gameProxy);

        IHeroLogic(heroProxy).setPermit(gameProxy);
        IInventoryLogic(inventoryProxy).setPermit(gameProxy);

        _token.authorize(protocol, gameProxy);
        _assets.authorize(gameProxy);

        _protocol.setGameProxy(gameProxy);

        vm.stopBroadcast();

        console.log("Game proxy (user entry):", gameProxy);
        console.log("Game Impl:              ", address(gameImpl));
        console.log("Hero proxy:             ", heroProxy);
        console.log("Hero Impl:              ", address(heroImpl));
        console.log("Inventory proxy:        ", inventoryProxy);
        console.log("Inventory Impl:         ", address(inventoryImpl));
        console.log("GameToken:              ", token);
        console.log("GameAssets:             ", assets);
        console.log("Proxy admin (owner):    ", owner);
        console.log("Protocol                ", protocol);
        console.log("Fee Pool                ", feePool);
    }
}
