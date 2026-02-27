// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Randao {
    function getSeed() internal view virtual returns (bytes32) {
        return bytes32(block.prevrandao);
    }

    function getSeedUint() internal view virtual returns (uint256) {
        return block.prevrandao;
    }
}
