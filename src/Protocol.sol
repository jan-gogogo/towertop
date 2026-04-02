// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGameToken} from "./interfaces/IGameToken.sol";
import {IFeePool} from "./interfaces/IFeePool.sol";
import {IProtocol} from "./interfaces/IProtocol.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Protocol is ReentrancyGuardTransient, IProtocol {
    event Buy(address indexed buyer, uint256 amount, uint256 cost, uint256 fee);
    event Sell(address indexed seller, uint256 amount, uint256 refund, uint256 fee);
    event FloorLifted(uint256 oldPrice, uint256 initPrice, uint256 surplus);

    IGameToken public _token;
    IFeePool public _feePool;
    uint256 public _lastSyncedSupply;
    address public _gameProxy;
    uint256 public _price; // 0.01 USDT;  $0.01
    mapping(address => uint256) public _lastBuyAt;

    uint256 public immutable SLOPE; // 0.000000005 ether;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_BPS = 10000; // Max Basis Points
    uint256 public constant FEE_BUY_PART_RATE = 100; // 1%
    uint256 public constant FEE_SELL_PART_RATE = 300; // 3%
    uint256 public constant MIN_AMOUNT_FOR_BUY = 0.001 ether;
    uint256 public constant MIN_AMOUNT_FOR_SELL = 0.000000001 ether;
    uint256 public constant MAX_AMOUNT_FOR_TRADE = 100_000_000 ether;
    uint256 public constant MIN_SYNC_THRESHOLD = 0.0001 ether;
    uint256 public constant SECONDS_PER_DAY = 60 * 60 * 24;

    constructor(address _token_, address _feePool_, uint256 _slope_, uint256 _price_) {
        _token = IGameToken(_token_);
        _feePool = IFeePool(_feePool_);
        SLOPE = _slope_;
        _price = _price_;
    }

    function getSellFeePer() external view returns (uint256) {
        return _calculateFeeForSell(1 ether);
    }

    function getPrice() external view returns (uint256) {
        return _price;
    }

    function calculateBuyCost(uint256 amount) external view returns (uint256) {
        return _calculateBuyCost(amount);
    }

    function calculateSellRefund(uint256 amount) external view returns (uint256) {
        return _calculateSellRefund(amount);
    }

    function setGameProxy(address gameProxy) external {
        if (_gameProxy != address(0)) revert ProxyAddressAlreadySet();
        _gameProxy = gameProxy;
    }

    function buy(uint256 amount, uint256 maxCost) external payable nonReentrant {
        if (amount < MIN_AMOUNT_FOR_BUY) revert MinBuyRequired();
        if (amount > MAX_AMOUNT_FOR_TRADE) revert QuantityTooLarge();

        uint256 cost = _calculateBuyCost(amount);
        uint256 fee = _calculateFeeForBuy(cost);
        uint256 totalCost = cost + fee;

        if (totalCost > maxCost) revert PriceTooHigh(totalCost, maxCost);
        if (msg.value < totalCost) revert BalanceTooLow();
        _token.mint(msg.sender, amount);
        _lastSyncedSupply = _token.totalSupply();

        // send fee to pool
        _feePool.feein{value: fee}();

        // refund excess value
        if (msg.value > totalCost) {
            (bool success,) = msg.sender.call{value: msg.value - totalCost}("");
            if (!success) revert SendChangeFailed();
        }
        _lastBuyAt[msg.sender] = block.timestamp;
        emit Buy(msg.sender, amount, totalCost, fee);
    }

    function sell(uint256 amount, uint256 minAmountOut) external nonReentrant {
        if (amount < MIN_AMOUNT_FOR_SELL) revert MinSellRequired();
        if (amount > MAX_AMOUNT_FOR_TRADE) revert QuantityTooLarge();
        if (_token.balanceOf(msg.sender) < amount) revert BalanceTooLow();

        uint256 refund = _calculateSellRefund(amount);
        uint256 fee = _calculateFeeForSell(refund);
        uint256 receiveAmt = refund - fee;

        if (receiveAmt < minAmountOut) revert SlippageExceeded();
        _token.burn(msg.sender, amount);
        _lastSyncedSupply = _token.totalSupply();

        // send fee to pool
        _feePool.feein{value: fee}();

        //refund
        (bool success,) = msg.sender.call{value: receiveAmt}("");
        if (!success) revert PaybackFailed();

        emit Sell(msg.sender, amount, receiveAmt, fee);
    }

    /**
     * @notice This function should be called by the game contract when tokens are burned in the game.
     * @dev Burning tokens reduces the supply, and the originally corresponding reserve remains in the contract as surplus.
     *      We redistribute this surplus to the remaining supply, increasing the initPrice.
     */
    function syncFloorPriceAfterBurn() external nonReentrant {
        if (msg.sender != _gameProxy) revert NotGameContract();
        if (_lastSyncedSupply == 0) return;

        uint256 curTotalSupply = _token.totalSupply();
        if (curTotalSupply == 0) return;

        uint256 burnedAmount = _lastSyncedSupply - curTotalSupply;
        if (burnedAmount < MIN_SYNC_THRESHOLD) return;

        // 1. Calculate the "theoretical value" of the burned portion according to the current bonding curve
        // This value now becomes the surplus
        uint256 surplus = Math.mulDiv(
            SLOPE, (2 * _lastSyncedSupply * burnedAmount - burnedAmount * burnedAmount), (2 * PRECISION * PRECISION)
        ) + Math.mulDiv(_price, burnedAmount, PRECISION);

        // 2. Redistribute the surplus to the remaining Tokens
        // NewInitPrice = OldInitPrice + (Surplus / RemainingSupply)
        uint256 priceIncrease = Math.mulDiv(surplus, PRECISION, curTotalSupply);

        uint256 oldPrice = _price;
        _price += priceIncrease;

        _lastSyncedSupply = curTotalSupply;
        emit FloorLifted(oldPrice, _price, surplus);
    }

    // fee 1%
    function _calculateFeeForBuy(uint256 cost) private pure returns (uint256) {
        return Math.mulDiv(cost, FEE_BUY_PART_RATE, MAX_BPS);
    }

    // fee 3%-10%
    function _calculateFeeForSell(uint256 refund) private view returns (uint256) {
        uint256 gap = block.timestamp - _lastBuyAt[msg.sender];
        uint256 rate;
        if (gap < SECONDS_PER_DAY) {
            rate = 1000; // 10%
        } else if (gap < SECONDS_PER_DAY * 7) {
            rate = 500; // 5%
        } else {
            rate = FEE_SELL_PART_RATE;
        }
        return Math.mulDiv(refund, rate, MAX_BPS);
    }

    // linear bonding curve
    // cost = (slope * supply * amount) + (0.5 * slope * amount^2) + (initPrice * amount)
    function _calculateBuyCost(uint256 amount) private view returns (uint256) {
        uint256 supply = _token.totalSupply();

        uint256 slopePart =
            Math.mulDiv(SLOPE * amount, (2 * supply + amount), 2 * PRECISION * PRECISION, Math.Rounding.Ceil);

        uint256 basePart = Math.mulDiv(_price, amount, PRECISION, Math.Rounding.Ceil);
        return slopePart + basePart;
    }

    // linear bonding curve
    // refund = (slope * supply * amount) - (0.5 * slope * amount^2) + (initPrice * amount)
    function _calculateSellRefund(uint256 amount) private view returns (uint256) {
        uint256 supply = _token.totalSupply();
        if (supply < amount) revert SupplyTooLow();

        uint256 slopePart =
            Math.mulDiv(SLOPE * amount, (2 * supply - amount), 2 * PRECISION * PRECISION, Math.Rounding.Floor);
        uint256 basePart = Math.mulDiv(_price, amount, PRECISION, Math.Rounding.Floor);
        return slopePart + basePart;
    }
}
