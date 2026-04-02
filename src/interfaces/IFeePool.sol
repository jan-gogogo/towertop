// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFeePool {
    function feein() external payable;
    function withdraw() external;
    function send(address receiver, uint256 amount, string calldata memo) external;
}
