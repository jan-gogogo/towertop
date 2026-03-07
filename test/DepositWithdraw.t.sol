// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RouterTestBase} from "./RouterTestBase.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {Property} from "../src/libraries/Property.sol";

bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

/**
 * Unit tests for Game.deposit, depositWithPermit, withdraw.
 * User approves Game proxy for token; tokens are held by Game proxy.
 */
contract DepositWithdrawTest is RouterTestBase {
    address game; // game proxy address (for mint prank and token holder)
    address user;

    uint256 internal signerPk = 1;
    address internal signer;

    function setUp() public {
        user = address(0x1234);
        signer = vm.addr(signerPk);
        deployRouterStack();
        game = address(gameLogic);
    }

    function test_deposit_revertWhenAmountLessThan1Ether() public {
        _giveUserToken(1 ether);
        vm.startPrank(user);
        gameToken.approve(address(gameLogic), 1 ether);
        vm.expectRevert(IGameLogic.AmountAtLeast1e18.selector);
        gameLogic.deposit(1 ether - 1);
        vm.stopPrank();
    }

    function test_deposit_success() public {
        uint256 amount = 2 ether;
        _giveUserToken(amount);
        vm.startPrank(user);
        gameToken.approve(address(gameLogic), amount);
        gameLogic.deposit(amount);
        vm.stopPrank();

        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), amount * 10, "user Coin balance");
        assertEq(gameToken.balanceOf(address(gameLogic)), amount, "Game proxy token balance");
        assertEq(gameToken.balanceOf(user), 0, "user token spent");
    }

    function test_withdraw_revertWhenAmountLessThan1Gwei() public {
        vm.prank(user);
        vm.expectRevert(IGameLogic.AmountAtLeast1e9.selector);
        gameLogic.withdraw(1 gwei - 1);
    }

    function test_withdraw_revertWhenInsufficientLiquidity() public {
        vm.prank(address(gameLogic));
        gameAssets.mint(user, Property.COIN_ID, 10 ether, "");
        assertEq(gameToken.balanceOf(address(gameLogic)), 0);

        vm.prank(user);
        vm.expectRevert(IGameLogic.InsufficientERC20.selector);
        gameLogic.withdraw(10 ether);
    }

    function test_withdraw_success_and5PercentBurn() public {
        uint256 depositAmount = 10 ether;
        _giveUserToken(depositAmount);
        vm.startPrank(user);
        gameToken.approve(address(gameLogic), depositAmount);
        gameLogic.deposit(depositAmount);
        vm.stopPrank();

        uint256 coinBalance = depositAmount * 10;
        uint256 withdrawCoin = 10 ether;
        vm.prank(user);
        gameLogic.withdraw(withdrawCoin);

        uint256 expectedToken = withdrawCoin / 10;
        uint256 expectedBurn = expectedToken / 20;
        uint256 expectedToUser = expectedToken - expectedBurn;

        assertEq(gameToken.balanceOf(user), expectedToUser, "user receives 95%");
        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBalance - withdrawCoin, "Coin deducted");
        assertEq(
            gameToken.balanceOf(address(gameLogic)),
            depositAmount - expectedToken,
            "Game proxy balance decreased"
        );
        assertEq(gameToken.totalSupply(), depositAmount - expectedBurn, "5% burned");
    }

    function test_depositWithPermit_revertWhenAmountLessThan1Ether() public {
        uint256 amount = 1 ether - 1;
        _giveUserTokenTo(signer, 1 ether);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _signPermit(signer, address(gameLogic), amount);
        vm.prank(signer);
        vm.expectRevert(IGameLogic.AmountAtLeast1e18.selector);
        gameLogic.depositWithPermit(amount, deadline, v, r, s);
    }

    function test_depositWithPermit_success() public {
        uint256 amount = 2 ether;
        _giveUserTokenTo(signer, amount);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _signPermit(signer, address(gameLogic), amount);

        vm.prank(signer);
        gameLogic.depositWithPermit(amount, deadline, v, r, s);

        assertEq(gameAssets.balanceOf(signer, Property.COIN_ID), amount * 10, "signer Coin balance");
        assertEq(gameToken.balanceOf(address(gameLogic)), amount, "Game proxy token balance");
        assertEq(gameToken.balanceOf(signer), 0, "signer token spent");
    }

    function test_depositWithPermit_revertWhenDeadlineExpired() public {
        uint256 amount = 2 ether;
        _giveUserTokenTo(signer, amount);
        uint256 pastDeadline = block.timestamp - 1;
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermitRaw(signer, address(gameLogic), amount, gameToken.nonces(signer), pastDeadline);

        vm.prank(signer);
        vm.expectRevert();
        gameLogic.depositWithPermit(amount, pastDeadline, v, r, s);
    }

    function test_depositWithPermit_revertWhenInvalidSignature() public {
        uint256 amount = 2 ether;
        _giveUserTokenTo(signer, amount);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _signPermit(signer, address(gameLogic), amount);
        vm.prank(signer);
        vm.expectRevert();
        gameLogic.depositWithPermit(amount, deadline, v, r, bytes32(uint256(s) + 1));
    }

    function test_depositThenWithdraw_roundTrip() public {
        uint256 amount = 100 ether;
        _giveUserToken(amount);
        vm.startPrank(user);
        gameToken.approve(address(gameLogic), amount);
        gameLogic.deposit(amount);
        vm.stopPrank();

        uint256 coinBalance = gameAssets.balanceOf(user, Property.COIN_ID);
        vm.prank(user);
        gameLogic.withdraw(coinBalance);

        uint256 tokenBack = coinBalance / 10;
        uint256 burnAmount = tokenBack / 20;
        assertEq(gameToken.balanceOf(user), amount - burnAmount, "user has initial minus 5% of withdrawn");
        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), 0, "no Coin left");
    }

    function _signPermit(address ownerAddr, address spenderAddr, uint256 value)
        internal
        view
        returns (uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    {
        deadline = block.timestamp + 1 hours;
        uint256 nonce = gameToken.nonces(ownerAddr);
        (v, r, s) = _signPermitRaw(ownerAddr, spenderAddr, value, nonce, deadline);
        return (deadline, v, r, s);
    }

    function _signPermitRaw(address ownerAddr, address spenderAddr, uint256 value, uint256 nonce, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, ownerAddr, spenderAddr, value, nonce, deadline));
        bytes32 domainSeparator = gameToken.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        return vm.sign(signerPk, digest);
    }

    function _giveUserToken(uint256 amount) internal {
        vm.prank(game);
        gameToken.mint(user, amount);
    }

    function _giveUserTokenTo(address to, uint256 amount) internal {
        vm.prank(game);
        gameToken.mint(to, amount);
    }
}
