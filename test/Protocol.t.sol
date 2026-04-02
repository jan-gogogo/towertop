// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {Protocol} from "../src/Protocol.sol";
import {FeePool} from "../src/FeePool.sol";
import {GameToken} from "../src/GameToken.sol";
import {IProtocol} from "../src/interfaces/IProtocol.sol";
import {IFeePool} from "../src/interfaces/IFeePool.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {console} from "forge-std/console.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ProtocolTest is Test {
    IProtocol public _protocol;
    IGameToken public _token;
    IFeePool public _feePool;

    address public user1;
    address public user2;
    address public user3;

    address constant GAME_ADDR = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
    // INIT_PRICE / SLOPE =
    uint256 constant SLOPE = 0.000000005 ether; // 5e-9
    uint256 constant INIT_PRICE = 0.1 ether; // value is 0.01 USDT

    uint256 constant INIT_BALANCE = 100_000_000_000 ether;

    function setUp() public {
        _token = new GameToken("Aoka Tower Token", "ATT");
        _feePool = new FeePool(address(this));
        user1 = address(0x000001);
        user2 = address(0x000002);
        user3 = address(0x000003);
        _protocol = new Protocol(address(_token), address(_feePool), SLOPE, INIT_PRICE);
        _token.authorize(address(_protocol), GAME_ADDR);
        _protocol.setGameProxy(GAME_ADDR);

        vm.deal(user1, INIT_BALANCE);
        vm.deal(user2, INIT_BALANCE);
        vm.deal(user3, INIT_BALANCE);
    }

    function test_calculate_buy_cost() public view {
        uint256 buyCost = _protocol.calculateBuyCost(1 ether);
        console.log("buy cost: ", buyCost);
    }

    function test_calculate_sell_refund() public {
        vm.prank(user1);
        _protocol.buy{value: 100_000_000 ether}(100 ether, 100_000_000 ether);
        uint256 sellRefund = _protocol.calculateSellRefund(100);
        console.log("sell refund: ", sellRefund);
    }

    // Ensure that when whales buy or sell, the price does not have a catastrophic spike.
    // Given the current supply, buying 1% of the total supply should result in a price change within the expected range.
    function test_liquidity_depth() public {
        // set supply to 100,000,000 tokens
        vm.startPrank(user1);
        _protocol.buy{value: 100_000_000 ether}(50_000_000 ether, 100_000_000 ether);
        _protocol.buy{value: 100_000_000 ether}(50_000_000 ether, 100_000_000 ether);
        vm.stopPrank();
        uint256 oldPrice = _protocol.calculateBuyCost(1 ether);

        // buy 1% of total supply
        uint256 buyAmount = _token.totalSupply() * 100 / 10000;
        vm.prank(user2);
        _protocol.buy{value: 100_000_000 ether}(buyAmount, 100_000_000 ether);

        uint256 newPrice = _protocol.calculateBuyCost(1 ether);

        console.log("old price: ", oldPrice);
        console.log("new price: ", newPrice);

        // Assert: Price impact should not exceed 5%
        uint256 priceImpact = (newPrice - oldPrice) * 100 / oldPrice * 10000;
        console.log("priceImpact: ", priceImpact);
        assertLe(priceImpact, 5, "Price impact too high for 1% buy");
    }

    // Verify that in extreme sell-off scenarios, the protocol can retain enough ETH (reserve)
    // and that fees can cover potential risks.
    // When 20% of holders collectively exit, the remaining holders' "net asset value" should not drop to zero.
    function test_sell_off_resilience() public {
        // set supply to 100,000,000 tokens
        vm.startPrank(user1);
        _protocol.buy{value: 100_000_000 ether}(50_000_000 ether, 100_000_000 ether);
        _protocol.buy{value: 100_000_000 ether}(50_000_000 ether, 100_000_000 ether);

        // sell 20%
        uint256 balance = _token.balanceOf(user1);
        console.log("user balance: ", balance);
        _protocol.sell(balance * 2000 / 10000, 0);

        uint256 actualReserve = address(_protocol).balance;
        console.log("actual reserve: ", actualReserve);

        uint256 currentSupply = _token.totalSupply();
        console.log("current supply: ", currentSupply);
        // if swap all
        uint256 theoreticalReserve = _protocol.calculateSellRefund(currentSupply);
        console.log("theoretical reserve: ", theoreticalReserve);
        // Assert: Actual reserve after sell fees should be greater than the theoretical curve support
        assertGe(actualReserve, theoreticalReserve, "Reserve leaked!");
    }

    function test_reasonable_slippage_for_buy() public {
        /*================================================================================
                              Buy 100k tokens, slippage does not exceed 3%
        =================================================================================*/
        uint256 instantPrice1 = _protocol.calculateBuyCost(1 ether);
        console.log("buy 100k instant price: ", formatEth(instantPrice1));
        // user1 buy 100k
        vm.prank(user1);
        _protocol.buy{value: 100_000_000 ether}(100_000 ether, 100_000_000 ether);

        uint256 user1TotalCost = INIT_BALANCE - user1.balance;
        uint256 user1HoldedTokenCount = _token.balanceOf(user1);

        uint256 avgUser1Price = user1TotalCost * 1 ether / user1HoldedTokenCount;
        console.log("buy 100k cost per token: ", formatEth(avgUser1Price));

        uint256 user1SlippagePrice = instantPrice1 * 103 / 100;
        console.log("3% slippage price: ", formatEth(user1SlippagePrice));

        assertLe(avgUser1Price, user1SlippagePrice, "Buy 100k slippage too high: > 3%");

        console.log(" ");

        /*================================================================================
                          Buy 1M tokens, slippage does not exceed 7%
        =================================================================================*/
        uint256 instantPrice2 = _protocol.calculateBuyCost(1 ether);
        console.log("buy 1M instant price: ", formatEth(instantPrice2));
        // user2 buy 1M
        vm.prank(user2);
        _protocol.buy{value: 100_000_000 ether}(1_000_000 ether, 100_000_000 ether);

        uint256 user2TotalCost = INIT_BALANCE - user2.balance;
        uint256 user2HoldedTokenCount = _token.balanceOf(user2);

        uint256 avgUser2Price = user2TotalCost * 1 ether / user2HoldedTokenCount;
        console.log("buy 1M cost per token: ", formatEth(avgUser2Price));

        uint256 user2SlippagePrice = instantPrice2 * 107 / 100;
        console.log("7% slippage price: ", formatEth(user2SlippagePrice));

        assertLe(avgUser2Price, user2SlippagePrice, "Buy 1M slippage too high: > 7%");

        console.log(" ");

        /*================================================================================
                          Buy 5M tokens, slippage does not exceed 15%
        =================================================================================*/
        uint256 instantPrice3 = _protocol.calculateBuyCost(1 ether);
        console.log("buy 5M instant price: ", formatEth(instantPrice3));
        // user3 buy 5M
        vm.prank(user3);
        _protocol.buy{value: 100_000_000 ether}(5_000_000 ether, 100_000_000 ether);

        uint256 user3TotalCost = INIT_BALANCE - user3.balance;
        uint256 user3HoldedTokenCount = _token.balanceOf(user3);

        uint256 avgUser3Price = user3TotalCost * 1 ether / user3HoldedTokenCount;
        console.log("buy 5M cost per token: ", formatEth(avgUser3Price));

        uint256 user3SlippagePrice = instantPrice3 * 115 / 100;
        console.log("15% slippage price: ", formatEth(user3SlippagePrice));

        assertLe(avgUser3Price, user3SlippagePrice, "Buy 5M slippage too high: > 15%");

        console.log(" ");
    }

    /// @dev Test user can profit by buying tokens early at a low price and selling after the price rises.
    function test_user_can_profit_from_early_buy_and_sell() public {
        uint256 currentTime = block.timestamp;
        console.log("price per token: ", _protocol.calculateBuyCost(1 ether));
        // user buy 5,000,000
        vm.prank(user1);
        _protocol.buy{value: 100_000_000 ether}(5_000_000 ether, 100_000_000 ether);

        uint256 holdedTokenCount = _token.balanceOf(user1);
        uint256 totalCost = INIT_BALANCE - user1.balance;
        uint256 avgBuyPrice = totalCost * 1 ether / holdedTokenCount;
        uint256 balanceAfterBuy = user1.balance;
        console.log("avg buy price: ", avgBuyPrice);
        // price up
        vm.startPrank(user2);
        _protocol.buy{value: 100_000_000 ether}(10_000_000 ether, 100_000_000 ether);
        vm.stopPrank();

        // sell all
        vm.warp(currentTime + 8 days);
        vm.prank(user1);
        _protocol.sell(holdedTokenCount, 0);

        uint256 balanceAfterSell = user1.balance;
        assertGt(balanceAfterSell, INIT_BALANCE, "user lost money");

        uint256 earnForSell = balanceAfterSell - balanceAfterBuy;
        uint256 avgSellPrice = earnForSell * 1 ether / holdedTokenCount;
        console.log("avg sell price: ", avgSellPrice);
        assertGe(avgSellPrice, avgBuyPrice, "User sells each token at a loss");
    }

    // Health check for protocol price after buy and burn
    function test_price_health() public {
        // User1 buys 10,000,000 tokens
        vm.prank(user1);
        _protocol.buy{value: 100_000_000 ether}(10_000_000 ether, 100_000_000 ether);

        // Record current supply and prices
        uint256 supply = _token.totalSupply();
        uint256 buyCost = _protocol.calculateBuyCost(1 ether);
        uint256 sellRefund = _protocol.calculateSellRefund(1 ether);
        uint256 price = _protocol.getPrice();

        // Print protocol balance, supply and pricing info before burn
        console.log("balance: ", address(_protocol).balance);
        console.log("supply: ", supply);
        console.log("buy cost: ", buyCost);
        console.log("sell refund: ", sellRefund);
        console.log("price: ", price);
        console.log(" ");

        // Burn 1/5 of the supply from user1, simulating a large burn event
        vm.prank(address(_protocol));
        _token.burn(user1, supply / 5);

        // Synchronize protocol floor price after token burn
        vm.prank(GAME_ADDR);
        _protocol.syncFloorPriceAfterBurn();

        // Query new prices/costs after the burn event
        uint256 buyCostAfterBurn = _protocol.calculateBuyCost(1 ether);
        uint256 sellRefundAfterBurn = _protocol.calculateSellRefund(1 ether);
        uint256 supplyAfterBurn = _token.totalSupply();
        uint256 priceAfterBurn = _protocol.getPrice();
        console.log("After burn supply: ", supplyAfterBurn);
        console.log("After burn buy cost: ", buyCostAfterBurn);
        console.log("After burn sell refund: ", sellRefundAfterBurn);
        console.log("After burn price: ", priceAfterBurn);

        assertGt(
            priceAfterBurn,
            price,
            "After a significant token burn event, the price should increase to reflect the reduced supply"
        );

        // Calculate amount needed to refund all remaining tokens after burn
        uint256 refundAll = _protocol.calculateSellRefund(supplyAfterBurn);
        console.log("protocol balance: ", address(_protocol).balance);
        console.log("refund all need: ", refundAll);

        assertGe(address(_protocol).balance, refundAll, "Reserve leaked!");

        // Print protocol fee pool balance (accumulated fees)
        console.log("fee: ", address(_feePool).balance);

        console.log(" ");

        // Burn a fixed amount (75,000 tokens) from user1, testing another floor lift
        vm.prank(address(_protocol));
        _token.burn(user1, 75000 ether);

        // Sync protocol price after the back buy token burn
        vm.prank(GAME_ADDR);
        _protocol.syncFloorPriceAfterBurn();

        // Query new prices/costs after the 2nd burn event (BackBuy)
        uint256 buyCostAfterBackBuy = _protocol.calculateBuyCost(1 ether);
        uint256 sellRefundAfterBackBuy = _protocol.calculateSellRefund(1 ether);
        uint256 supplyAfterBackBuy = _token.totalSupply();
        console.log("After BackBuy supply: ", supplyAfterBackBuy);
        console.log("After BackBuy buy cost: ", buyCostAfterBackBuy);
        console.log("After BackBuy sell refund: ", sellRefundAfterBackBuy);
        console.log("After BackBuy price: ", _protocol.getPrice());

        // Calculate new refund required for all tokens after BackBuy event
        uint256 refundAllAfterBackBuy = _protocol.calculateSellRefund(supplyAfterBackBuy);
        console.log("protocol balance: ", address(_protocol).balance);
        console.log("refund all need: ", refundAllAfterBackBuy);

        assertGe(address(_protocol).balance, refundAllAfterBackBuy, "Reserve leaked after backBuy");
    }

    function formatEth(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0.000000000000000000";

        uint256 eth = value / 1e18;
        uint256 frac = value % 1e18;

        string memory fracStr = Strings.toString(frac);

        uint256 fracLen = bytes(fracStr).length;
        while (fracLen < 18) {
            fracStr = string(abi.encodePacked("0", fracStr));
            fracLen++;
        }

        return string(abi.encodePacked(Strings.toString(eth), ".", fracStr));
    }
}
