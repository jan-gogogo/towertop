// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IHeroLogic} from "../src/interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "../src/interfaces/IInventoryLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {IProtocol} from "../src/interfaces/IProtocol.sol";
import {IFeePool} from "../src/interfaces/IFeePool.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {Protocol} from "../src/Protocol.sol";
import {FeePool} from "../src/FeePool.sol";
import {GameV1} from "../src/GameV1.sol";
import {HeroV1} from "../src/HeroV1.sol";
import {InventoryV1} from "../src/InventoryV1.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";

/**
 * @notice Deploys GameV1 + HeroV1 + InventoryV1 (each behind ERC1967Proxy with UUPS)
 *         and wires GameToken/GameAssets so the Game proxy can mint/burn.
 *         Tests that need hero/inventory access (e.g. setPlayerHealth, setFloorIndex) use heroLogic/inventoryLogic.
 */
abstract contract RouterTestBase is Test {
    IGameLogic public gameLogic;
    IHeroLogic public heroLogic;
    IInventoryLogic public inventoryLogic;
    IGameToken public gameToken;
    IGameAssets public gameAssets;
    IProtocol public protocol;
    IFeePool public feePool;
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;
    uint256 public vrfSubId;

    uint256 constant SLOPE = 0.000000005 ether; // 5e-9
    uint256 constant INIT_PRICE = 0.1 ether; // value is 0.01 USDT

    /// @notice Deploy full stack with VRF Mock; call from setUp(). Uses msg.sender as owner (e.g. address(this) in tests).
    function deployRouterStack() internal {
        address owner = address(this);

        // 1. Deploy VRF Mock
        vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(1e17, 1e9, 4e15);

        // 2. Create subscription and fund it
        vrfSubId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(vrfSubId, 1000 ether);

        GameToken token = new GameToken("Aoka Tower Token", "ATT");
        GameAssets assets = new GameAssets("");
        FeePool feePoolImpl = new FeePool(owner);
        Protocol protocolImpl = new Protocol(address(token), address(feePoolImpl), SLOPE, INIT_PRICE);

        GameV1 gameImpl = new GameV1();
        HeroV1 heroImpl = new HeroV1();
        InventoryV1 inventoryImpl = new InventoryV1();

        // Deploy Hero proxy (UUPS)
        bytes memory heroInit = abi.encodeCall(HeroV1.initialize, (address(0), owner));
        ERC1967Proxy heroProxy = new ERC1967Proxy(address(heroImpl), heroInit);
        heroLogic = IHeroLogic(address(heroProxy));

        // Deploy Inventory proxy (UUPS)
        bytes memory inventoryInit = abi.encodeCall(InventoryV1.initialize, (address(0), owner));
        ERC1967Proxy inventoryProxy = new ERC1967Proxy(address(inventoryImpl), inventoryInit);
        inventoryLogic = IInventoryLogic(address(inventoryProxy));

        // Deploy Game proxy (UUPS)
        bytes memory gameInit = abi.encodeCall(
            GameV1.initialize,
            (
                address(heroProxy),
                address(inventoryProxy),
                address(token),
                address(assets),
                address(protocolImpl),
                address(vrfCoordinatorMock),
                bytes32(0),
                vrfSubId,
                owner
            )
        );
        ERC1967Proxy gameProxy = new ERC1967Proxy(address(gameImpl), gameInit);
        gameLogic = IGameLogic(address(gameProxy));

        // 3. Add game as consumer
        vrfCoordinatorMock.addConsumer(vrfSubId, address(gameProxy));

        heroLogic.setPermit(address(gameProxy));
        inventoryLogic.setPermit(address(gameProxy));

        token.authorize(address(gameProxy), address(gameProxy));
        assets.authorize(address(gameProxy));

        protocol = IProtocol(address(protocolImpl));
        protocol.setGameProxy(address(gameProxy));

        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
    }
}
