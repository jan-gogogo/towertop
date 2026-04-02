// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IProtocol {
    error SupplyTooLow();
    error PaybackFailed();
    error BalanceTooLow();
    error MinBuyRequired();
    error MinSellRequired();
    error NotGameContract();
    error SendChangeFailed();
    error QuantityTooLarge();
    error SlippageExceeded();
    error ProxyAddressAlreadySet();
    error PriceTooHigh(uint256 cost, uint256 maxCost);

    function getSellFeePer() external view returns (uint256);
    function getPrice() external view returns (uint256);
    function calculateBuyCost(uint256 amount) external view returns (uint256);
    function calculateSellRefund(uint256 amount) external view returns (uint256);
    function setGameProxy(address gameProxy) external;
    function buy(uint256 amount, uint256 maxCost) external payable;
    function sell(uint256 amount, uint256 minAmountOut) external;
    function syncFloorPriceAfterBurn() external;
}
