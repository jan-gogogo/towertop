// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Protocol} from "../src/Protocol.sol";
import {FeePool} from "../src/FeePool.sol";
import {GameToken} from "../src/GameToken.sol";
import {IProtocol} from "../src/interfaces/IProtocol.sol";
import {IFeePool} from "../src/interfaces/IFeePool.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {ProtocolHandler} from "./handlers/ProtocolHandler.sol";
import {console} from "forge-std/console.sol";

/**
 * @title ProtocolInvariantTest
 * @notice Invariant tests for Protocol contract with linear bonding curve.
 *
 * Protocol Mechanics
 * ================
 * The Protocol implements a linear bonding curve for token minting/burning:
 *   - buy:  Deposits ETH, mints tokens at price = (slope * supply * amount) + (0.5 * slope * amount^2) + (initPrice * amount)
 *   - sell: Burns tokens, refunds ETH at price = (slope * supply * amount) - (0.5 * slope * amount^2) + (initPrice * amount)
 * Fees are deducted on both buy (1%) and sell (2%), sent to FeePool.
 *
 * Invariants under test
 * =====================
 *   I1 — Solvency: address(protocol).balance >= calculateSellRefund(totalSupply)
 *              The contract's ETH balance must always cover the maximum possible
 *              refund for all outstanding tokens.
 *
 * Handler
 * =======
 * ProtocolHandler exercises two stateful actions: buy, sell.
 * Actor selection is limited to 10 fixed addresses (100-109) to improve
 * sell success rate, as the full address space would leave most actors with
 * zero token balance.
 * All calls are wrapped in try/catch to prevent the handler from reverting —
 * an invariant handler must never revert. Reverts from individual calls are
 * expected (e.g. sell when supply is 0, or sell when actor has no tokens)
 * and are skipped silently.
 *
 * Fuzzing
 * =======
 * - run            : forge test --match-contract ProtocolInvariantTest
 * - with verbosity : forge test -vvv --match-contract ProtocolInvariantTest
 * - specific invariant : forge test --match-path test/ProtocolInvariant.t.sol -f <func>
 */
contract ProtocolInvariantTest is Test {
    IProtocol public protocol;
    IGameToken public token;
    IFeePool public feePool;
    address public game;
    ProtocolHandler public handler;

    uint256 constant SLOPE = 0.000000005 ether; // 5e-9
    uint256 constant INIT_PRICE = 0.1 ether; // value is 0.01 USDT

    function setUp() public {
        token = new GameToken("Aoka Tower Token", "ATT");
        feePool = new FeePool(address(this));
        game = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
        protocol = new Protocol(address(token), address(feePool), SLOPE, INIT_PRICE);
        protocol.setGameProxy(game);
        token.authorize(address(protocol), game);

        handler = new ProtocolHandler(payable(address(protocol)), address(token), game);

        // Target the protocol contract for invariant testing
        targetContract(address(handler));

        // Seed handler with enough ether so buy() calls succeed
        vm.deal(address(handler), 10_000_000 ether);
    }

    // -------------------------------------------------------------------------
    // I1 — Solvency: The protocol contract's balance must always be sufficient
    // to refund all outstanding tokens (totalSupply) when users sell.
    // balance >= calculateSellRefund(totalSupply)
    // -------------------------------------------------------------------------

    function invariant_solvency() external view {
        uint256 balance = address(protocol).balance;
        uint256 totalSupply = token.totalSupply();
        uint256 refundAll = protocol.calculateSellRefund(totalSupply);
        uint256 sumBought = handler.ghostSumBought();
        uint256 sumSold = handler.ghostSumSold();
        uint256 sumFee = handler.ghostSumFeesAllocated();
        console.log("Protocol balance: ", balance);
        console.log("Refund all: ", refundAll);
        console.log("Sum bought token: ", sumBought);
        console.log("Sum Sold token: ", sumSold);
        console.log("Sum fee: ", sumFee);

        uint256 actor0 = token.balanceOf(address(100));
        uint256 actor1 = token.balanceOf(address(101));
        uint256 actor2 = token.balanceOf(address(102));
        uint256 actor3 = token.balanceOf(address(103));
        uint256 actor4 = token.balanceOf(address(104));
        uint256 actor5 = token.balanceOf(address(105));
        uint256 actor6 = token.balanceOf(address(106));
        uint256 actor7 = token.balanceOf(address(107));
        uint256 actor8 = token.balanceOf(address(108));
        uint256 actor9 = token.balanceOf(address(109));

        console.log("actor0 balance: ", actor0);
        console.log("actor1 balance: ", actor1);
        console.log("actor2 balance: ", actor2);
        console.log("actor3 balance: ", actor3);
        console.log("actor4 balance: ", actor4);
        console.log("actor5 balance: ", actor5);
        console.log("actor6 balance: ", actor6);
        console.log("actor7 balance: ", actor7);
        console.log("actor8 balance: ", actor8);
        console.log("actor9 balance: ", actor9);

        assertGe(balance, refundAll, "I1: Protocol's balance < refund all token supply");
    }

    // -------------------------------------------------------------------------
    // I2 — The protocol's token price must never decrease below the initial
    // price after any tokens have been burned.
    // Ensures the price is monotonically non-decreasing with respect to token burns.
    // -------------------------------------------------------------------------

    function invariant_price_monotonicity() external view {
        uint256 sumBurn = handler.ghostSumBurn();
        if (sumBurn == 0) return;
        uint256 newPrice = protocol.getPrice();
        console.log("Sum Burn: ", sumBurn);
        console.log("init Price: ", INIT_PRICE);
        console.log("new Price: ", newPrice);
        assertGt(newPrice, INIT_PRICE, "I2: Protocol's new price <= init price");
    }

    // -------------------------------------------------------------------------
    // I3 — Solvency: The protocol's fee pool must always be able to withdraw
    // at least the total accumulated fees.
    // Fee pool balance >= sum allocated fee
    // -------------------------------------------------------------------------
    function invariant_fee_pool_solvency() external view {
        // Fee pool balance
        uint256 feePoolBal = address(feePool).balance;
        // Tracked sum of protocol-allocated fees (ghost value)
        uint256 sumFee = handler.ghostSumFeesAllocated();
        console.log("FeePool balance: ", feePoolBal);
        console.log("Sum fee allocated: ", sumFee);

        // Fee pool should at least cover all the allocated fees (not less)
        assertGe(feePoolBal, sumFee, "I3: Fee pool balance < sum allocated fee");
    }
}
