// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IHeroLogic} from "../src/interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "../src/interfaces/IInventoryLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV1} from "../src/GameV1.sol";
import {HeroV1} from "../src/HeroV1.sol";
import {InventoryV1} from "../src/InventoryV1.sol";
import {TransparentUpgradeableProxy} from "../src/TransparentUpgradeableProxy.sol";

/**
 * @notice Deploys GameV1 + HeroV1 + InventoryV1 (each behind TransparentUpgradeableProxy)
 *         and wires GameToken/GameAssets so the Game proxy can mint/burn.
 *         Tests that need hero/inventory access (e.g. setPlayerHealth, setFloorIndex) use heroLogic/inventoryLogic.
 */
abstract contract RouterTestBase is Test {
    IGameLogic public gameLogic;
    IHeroLogic public heroLogic;
    IInventoryLogic public inventoryLogic;
    IGameToken public gameToken;
    IGameAssets public gameAssets;
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;
    uint256 public vrfSubId;

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

        GameV1 gameImpl = new GameV1();
        HeroV1 heroImpl = new HeroV1();
        InventoryV1 inventoryImpl = new InventoryV1();

        bytes memory heroInit = abi.encodeCall(HeroV1.initialize, (address(0)));
        TransparentUpgradeableProxy heroProxy = new TransparentUpgradeableProxy(address(heroImpl), owner, heroInit);
        heroLogic = IHeroLogic(address(heroProxy));

        bytes memory inventoryInit = abi.encodeCall(InventoryV1.initialize, (address(0)));
        TransparentUpgradeableProxy inventoryProxy =
            new TransparentUpgradeableProxy(address(inventoryImpl), owner, inventoryInit);
        inventoryLogic = IInventoryLogic(address(inventoryProxy));

        bytes memory gameInit = abi.encodeCall(
            GameV1.initialize,
            (
                address(heroProxy),
                address(inventoryProxy),
                address(token),
                address(assets),
                address(vrfCoordinatorMock),
                bytes32(0),
                vrfSubId
            )
        );
        TransparentUpgradeableProxy gameProxy = new TransparentUpgradeableProxy(address(gameImpl), owner, gameInit);
        gameLogic = IGameLogic(address(gameProxy));

        // 3. Add game as consumer
        vrfCoordinatorMock.addConsumer(vrfSubId, address(gameProxy));

        heroLogic.setPermit(address(gameProxy));
        inventoryLogic.setPermit(address(gameProxy));

        token.setProxy(address(gameProxy));
        assets.setProxy(address(gameProxy));

        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
    }
}
