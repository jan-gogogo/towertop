// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {HeroLogic} from "./HeroLogic.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

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
contract HeroV1 is HeroLogic, Initializable {
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
    function initialize(address _permit_) external initializer {
        _permit = _permit_;
    }
}
