// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IProtocol} from "../../src/interfaces/IProtocol.sol";
import {IFeePool} from "../../src/interfaces/IFeePool.sol";
import {IGameToken} from "../../src/interfaces/IGameToken.sol";

/**
 * @title ProtocolHandler
 * @notice Fuzzing handler that exercises all state-changing paths of Protocol.
 *         Used by ProtocolInvariantTest to drive invariant testing.
 *
 * Actor Selection
 * ===============
 * Trading is limited to 10 fixed addresses (100-109) to improve test efficiency.
 * A full uint160 address space would result in most addresses holding zero tokens,
 * causing sell() calls to frequently fail due to insufficient balance.
 *
 * Handler actions (each is a leaf / terminal action in the call graph):
 *   - buy(actorNum, amount) — mints tokens at bonding curve price + 1% fee
 *   - sell(actorNum, amount) — burns tokens for bonding curve refund - 2% fee
 *
 * Failure handling:
 *   - buy: vm.deals ether if actor balance is insufficient
 *   - sell: skips if supply is 0 or actor has no tokens
 * Reverts are expected and caught by the invariant runner.
 */
contract ProtocolHandler is Test {
    IProtocol public _protocol;
    IGameToken public _token;
    IFeePool public _feePool;

    address public _game;

    uint256 public lastestPrice;
    uint256 public ghostSumBought;
    uint256 public ghostSumSold;
    uint256 public ghostSumFeesAllocated;
    uint256 public ghostSumBurn;

    uint256 constant FEE_BUY_PART_RATE = 100; // 1%
    uint256 constant FEE_SELL_PART_RATE = 200; // 2%
    uint256 constant MAX_BPS = 10000;
    uint256 constant MIN_AMOUNT_FOR_BUY = 0.001 ether;
    uint256 constant MIN_AMOUNT_FOR_SELL = 0.000000001 ether;
    uint256 constant MAX_AMOUNT_FOR_TRADE = 100_000_000 ether;
    uint256 constant MIN_SYNC_THRESHOLD = 0.0001 ether;

    constructor(address payable _protocol_, address _token_, address _game_) {
        _protocol = IProtocol(_protocol_);
        _token = IGameToken(_token_);
        _game = _game_;
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    function buy(uint8 actorNum, uint256 amount) external payable {
        // The range from address 0 to uint160 is too broad, resulting in many addresses holding zero tokens.
        // By restricting trading to just 10 addresses, we greatly improve the success rate of each test,
        // since sell() tests would otherwise frequently return early due to lack of _token ownership.
        uint160 a = actorNum % 10 + 100;
        address actor = address(a);

        amount = bound(amount, MIN_AMOUNT_FOR_BUY, MAX_AMOUNT_FOR_TRADE);
        uint256 cost = _protocol.calculateBuyCost(amount);
        uint256 fee = (cost * FEE_BUY_PART_RATE) / MAX_BPS;
        uint256 totalCost = cost + fee;

        uint256 bal = actor.balance;
        if (bal < totalCost) {
            vm.deal(actor, totalCost);
        }

        vm.prank(actor);
        _protocol.buy{value: totalCost}(amount, type(uint256).max);
        ghostSumBought += amount;
        ghostSumFeesAllocated += fee;
    }

    function sell(uint8 actorNum, uint256 amount) external {
        // The range from address 0 to uint160 is too broad, resulting in many addresses holding zero tokens.
        // By restricting trading to just 10 addresses, we greatly improve the success rate of each test,
        // since sell() tests would otherwise frequently return early due to lack of _token ownership.
        uint160 a = actorNum % 10 + 100;
        address actor = address(a);

        uint256 supply = _token.totalSupply();
        if (supply < MIN_AMOUNT_FOR_SELL) return;
        uint256 actorBal = _token.balanceOf(actor);
        if (actorBal < MIN_AMOUNT_FOR_SELL) return;

        amount = Math.min(actorBal, MAX_AMOUNT_FOR_TRADE);

        uint256 refund = _protocol.calculateSellRefund(amount);
        uint256 fee = Math.mulDiv(refund, FEE_SELL_PART_RATE, MAX_BPS);

        vm.prank(actor);
        _protocol.sell(amount, 0);
        ghostSumSold += amount;
        ghostSumFeesAllocated += fee;
    }

    function burnAndSyncFloorPrice(uint8 actorNum, uint256 amount) external {
        // The range from address 0 to uint160 is too broad, resulting in many addresses holding zero tokens.
        // By restricting trading to just 10 addresses, we greatly improve the success rate of each test,
        // since sell() tests would otherwise frequently return early due to lack of _token ownership.
        uint160 a = actorNum % 10 + 100;
        address actor = address(a);

        uint256 actorBalance = _token.balanceOf(actor);
        if (actorBalance < MIN_SYNC_THRESHOLD) return;

        if (actorBalance > 10 ether) actorBalance = 10 ether;

        amount = bound(amount, MIN_SYNC_THRESHOLD, actorBalance);

        vm.prank(actor);
        _token.approve(_game, amount);
        vm.prank(_game);
        _token.burnFromApprove(actor, amount);

        ghostSumBurn += amount;

        vm.prank(_game);
        _protocol.syncFloorPriceAfterBurn();
    }

    // -------------------------------------------------------------------------
    // Trackers (optional — useful for debugging)
    // -------------------------------------------------------------------------

    function currentSupply() external view returns (uint256) {
        return _token.totalSupply();
    }
}
