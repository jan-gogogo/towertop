// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {HeroLogic} from "./HeroLogic.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract HeroV1 is HeroLogic, Initializable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _permit_) external initializer {
        _permit = _permit_;
    }
}
