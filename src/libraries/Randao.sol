// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Randao {
    function getSeed() internal view returns (bytes32) {
        return bytes32(block.prevrandao);
    }

    function getSeedUint() internal view returns (uint256) {
        return block.prevrandao;
    }
}
