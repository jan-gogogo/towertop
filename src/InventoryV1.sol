// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {InventoryLogic} from "./InventoryLogic.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

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
contract InventoryV1 is InventoryLogic, Initializable {
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
    function initialize(address _permit_) external initializer {
        _initNextIds();
        _permit = _permit_;
    }
}
