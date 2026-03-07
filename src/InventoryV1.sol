// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {InventoryLogic} from "./InventoryLogic.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract InventoryV1 is InventoryLogic, Initializable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _permit_) external initializer {
        _initNextIds();
        _permit = _permit_;
    }
}
