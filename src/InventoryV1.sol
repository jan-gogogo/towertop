// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {InventoryLogic} from "./InventoryLogic.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @title InventoryV1
 * @author Jan
 * @notice First implementation of inventory logic (bag, warehouse, equipment), intended to be used behind
 *         an upgradeable proxy. Inherits all inventory entry points from InventoryLogic (addItem, addEquipment,
 *         useItems, equip, unequip, shop buy, upgrade/merge, battle rewards). State lives in the proxy;
 *         this contract holds no storage. The constructor disables initializers on the logic contract.
 *         initialize(_permit_) is invoked once on the proxy to set the permitted caller (the Game proxy) and to
 *         initialize next-ID counters for equipment.
 * @dev Deploy as the implementation; point a proxy at it and call initialize(gameProxyAddress) on the proxy.
 */
contract InventoryV1 is InventoryLogic, UUPSUpgradeable, Ownable2StepUpgradeable {
    /**
     * @notice Constructor for the logic contract.
     * @dev Disables initializers on this contract so initialize() cannot be run in the logic contract's context.
     *      Only the proxy should run initialize() in its own context; all state (_permit, _bag, _warehouse,
     *      _equipments, _nextEquipmentId) then lives in the proxy storage.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialization function (called once on the proxy at deployment).
     * @param _permit_ Address of the permitted caller (typically the Game proxy). Only this address may call
     *                 InventoryLogic functions such as addItem, addEquipment, useItems, equip, buy, etc.
     * @dev Runs in the proxy's context. Calls _initNextIds() to set _nextEquipmentId, then sets
     *      _permit. Call from the proxy deploy script after deploying the proxy; do not call on the logic contract.
     */
    function initialize(address _permit_, address _owner_) external initializer {
        _initNextIds();
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
