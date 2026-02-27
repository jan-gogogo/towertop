// SPDX-License-Identifier:  MIT
pragma solidity ^0.8.24;

library FloorIndex {
    function isBossFloor(uint256 idx) internal pure returns (bool) {
        return (idx + 1) % 5 == 0;
    }
}
