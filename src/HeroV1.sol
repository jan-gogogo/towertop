// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {HeroLogic} from "./HeroLogic.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @title HeroV1
 * @author Jan
 * @notice First implementation of hero (player) and floor logic, intended to be used behind an upgradeable proxy.
 *         Inherits all hero/floor entry points from HeroLogic (players, equipped slots, floor, combat, nextFloor).
 *         State lives in the proxy; this contract holds no storage. The constructor disables initializers on the
 *         logic contract. initialize(_permit_) is invoked once on the proxy to set the permitted caller (the Game
 *         proxy address); only that address may call HeroLogic functions.
 * @dev Deploy as the implementation; point a proxy at it and call initialize(gameProxyAddress) on the proxy.
 */
contract HeroV1 is HeroLogic, UUPSUpgradeable, Ownable2StepUpgradeable {
    /**
     * @notice Constructor for the logic contract.
     * @dev Disables initializers on this contract so initialize() cannot be run in the logic contract's context.
     *      Only the proxy should run initialize() in its own context; all state (_permit, _players, _floor, etc.)
     *      then lives in the proxy storage.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialization function (called once on the proxy at deployment).
     * @param _permit_ Address of the permitted caller (typically the Game proxy). Only this address may call
     *                 HeroLogic functions such as addPlayer, combat, nextFloor, etc.
     * @dev Runs in the proxy's context. Call from the proxy deploy script after deploying the proxy; do not
     *      call on the logic contract.
     */
    function initialize(address _permit_, address _owner_) external initializer {
        _permit = _permit_;

        // Prevent accidental transfer to wrong address when changing owner.
        // Uses Ownable2Step: two-step ownership transfer for safety.
        // 1. Original owner calls transferOwnership(address) to set pendingOwner
        // 2. New owner calls acceptOwnership() to finalize ownership
        __Ownable_init(_owner_);
        __Ownable2Step_init();
    }

    /// @notice Authorizes upgrade (only owner can upgrade)
    /// @dev Must use onlyOwner check here, otherwise anyone could change the implementation address
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
