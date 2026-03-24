// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {GameLogic} from "./GameLogic.sol";
import {IHeroLogic} from "./interfaces/IHeroLogic.sol";
import {IInventoryLogic} from "./interfaces/IInventoryLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

/**
 * @title GameV1
 * @author Jan
 * @notice First implementation of the game logic, intended to be used behind an upgradeable proxy.
 *         Inherits all game entry points from GameLogic (born, deposit, battle, shop, etc.) and holds no
 *         storage; state lives in the proxy. The constructor disables initializers on this logic contract.
 *         initialize() is invoked once on the proxy at deployment to set HeroLogic, InventoryLogic,
 *         GameToken, and GameAssets dependencies.
 * @dev Deploy this contract as the implementation; point a proxy (e.g. TransparentUpgradeableProxy) at it
 *      and call initialize(...) on the proxy with the dependency addresses.
 */
contract GameV1 is GameLogic {
    /**
     * @notice constructor function
     *  @dev Disable initializers on the logic contract so initialize() never runs in its context.
     *       The code in initialize() below is what would go in a constructor—but a constructor
     *       would store _heroLogic, _inventoryLogic, _gameToken, _gameAssets in GameV1, not in the proxy.
     *       We need the logic contract to hold no storage, so we run the real setup in the proxy's context
     *       when it's deployed; then all that state lives in the proxy.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice initialization function (called during proxy deployment)
     * @dev This function is disabled on the logic contract; the proxy runs it in its own context when deployed.
     *      Because it runs in the proxy's context, msg.sender is the deployer, not the proxy—so we pass _owner_
     *      explicitly instead of relying on auth.
     *      Additionally initializes Chainlink VRF consumer for random number generation:
     *      - _vrfCoordinator_: Chainlink VRF Coordinator V2 Plus address
     *      - _keyHash_: Key hash for VRF subscription
     *      - _subscription_: Subscription ID for VRF funding
     */
    function initialize(
        address _heroLogic_,
        address _inventoryLogic_,
        address _gameToken_,
        address _gameAssets_,
        address _vrfCoordinator_,
        bytes32 _keyHash_,
        uint256 _subscription_
    ) external initializer {
        _heroLogic = IHeroLogic(_heroLogic_);
        _inventoryLogic = IInventoryLogic(_inventoryLogic_);
        _gameToken = IGameToken(_gameToken_);
        _gameAssets = IGameAssets(_gameAssets_);

        __VRFConsumerBaseV2_init(_vrfCoordinator_);
        _vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator_);
        _keyHash = _keyHash_;
        _subscription = _subscription_;
    }
}
