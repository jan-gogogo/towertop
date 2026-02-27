// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {GameLogic} from "./GameLogic.sol";
import {IGameToken} from "./interfaces/IGameToken.sol";
import {IGameAssets} from "./interfaces/IGameAssets.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @title  GameV1 contract
 * @author Jan
 * @notice The deployable logic contract, mainly responsible for initialization, version upgrading, and permissions; does not involve game logic.
 */
contract GameV1 is GameLogic, UUPSUpgradeable, Ownable2StepUpgradeable {
    /**
     * @notice constructor function
     *  @dev Disable initializers on the logic contract so initialize() never runs in its context.
     *       The code in initialize() below is what would go in a constructor—but a constructor
     *       would store _gameToken, _gameStorage, _gameAssets, _owner in GameV1, not in the proxy.
     *       We need the logic contract to hold no storage, so we run the real setup in the proxy's context
     *       when it's deployed; then all that state lives in the proxy.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice initialization function (called during proxy deployment)
     *  @dev This function is disabled on the logic contract; the proxy runs it in its own context when deployed.
     *       Because it runs in the proxy's context, msg.sender is the deployer,
     *       not the proxy—so we pass _owner_ explicitly instead of relying on auth.
     */
    function initialize(address _gameToken_, address _gameAssets_, address _owner_) external initializer {
        _gameToken = IGameToken(_gameToken_);
        _gameAssets = IGameAssets(_gameAssets_);

        // storage next-IDs (constructor runs on impl only; proxy must init here).
        _initNextIds();

        // set contract owner (checked when upgrading or transferring permissions).
        __Ownable_init(_owner_);

        // two-step ownership transfer so a typo in the new address doesn't lock out ownership:
        // 1. current owner calls transferOwnership(addr) → sets pendingOwner.
        // 2. new owner calls acceptOwnership() → becomes owner.
        __Ownable2Step_init();
    }

    /**
     * @notice authorizes an upgrade (only owner can upgrade).
     *  @dev must use onlyOwner—otherwise anyone could point the proxy at a different implementation and hijack the logic.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
