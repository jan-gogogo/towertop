// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Randao} from "./Randao.sol";

abstract contract Oracle is Randao {
    function getSeed() internal view override returns (bytes32) {
        // currently using blockchain random number
        return super.getSeed();
    }

    function getSeedUint() internal view override returns (uint256) {
        // currently using blockchain random number
        return super.getSeedUint();
    }
}
