// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Seed {
    /// @dev calculate a new hash value based on the original seed
    /// @param oriSeed seed to mix
    /// @param len length of the suffix (e.g. 6 for "reward")
    /// @param word suffix left-padded to 32 bytes (e.g. 0x72657761726400... for "reward")
    function change(bytes32 oriSeed, uint256 len, bytes32 word) internal pure returns (bytes32) {
        bytes32 result;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x40)
            mstore(add(ptr, 0x20), oriSeed)
            mstore(add(ptr, 0x40), len)
            mstore(add(ptr, 0x60), word)
            result := keccak256(ptr, 128)

            // update the next-available slot pointer
            // because we marked "memory-safe"
            mstore(0x40, add(ptr, 128)) // or 0x80
        }
        return result;
    }
}
