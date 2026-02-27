// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGameLogic} from "../src/interfaces/IGameLogic.sol";
import {IGameToken} from "../src/interfaces/IGameToken.sol";
import {IGameAssets} from "../src/interfaces/IGameAssets.sol";
import {GameToken} from "../src/GameToken.sol";
import {GameAssets} from "../src/GameAssets.sol";
import {GameV1} from "../src/GameV1.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";
import {Property} from "../src/libraries/Property.sol";

bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

/**
 * Unit tests for GameLogic.deposit, GameLogic.depositWithPermit, and GameLogic.withdraw.
 */
contract DepositWithdrawTest is Test {
    IGameLogic gameLogic;
    IGameToken gameToken;
    IGameAssets gameAssets;

    address proxy;
    address owner;
    address user;

    /// Signer for depositWithPermit tests (must have known private key to sign EIP-712)
    uint256 internal signerPk = 1;
    address internal signer;

    function setUp() public {
        owner = address(0x1222223332);
        user = address(0x1234);
        signer = vm.addr(signerPk);

        GameToken token = new GameToken("T3", "TowerTop");
        GameAssets assets = new GameAssets("");
        GameV1 gameV1 = new GameV1();

        bytes memory data = abi.encodeCall(GameV1.initialize, (address(token), address(assets), owner));
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(gameV1), data);
        proxy = address(proxyContract);

        token.setProxy(proxy);
        assets.setProxy(proxy);

        gameLogic = IGameLogic(proxy);
        gameToken = IGameToken(address(token));
        gameAssets = IGameAssets(address(assets));
    }

    function test_deposit_revertWhenAmountLessThan1Ether() public {
        _giveUserToken(1 ether);
        vm.startPrank(user);
        gameToken.approve(proxy, 1 ether);
        vm.expectRevert(IGameLogic.AmountAtLeast1e18.selector);
        gameLogic.deposit(1 ether - 1);
        vm.stopPrank();
    }

    function test_deposit_success() public {
        uint256 amount = 2 ether;
        _giveUserToken(amount);
        vm.startPrank(user);
        gameToken.approve(proxy, amount);
        gameLogic.deposit(amount);
        vm.stopPrank();

        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), amount * 10, "user Coin balance");
        assertEq(gameToken.balanceOf(proxy), amount, "contract token balance");
        assertEq(gameToken.balanceOf(user), 0, "user token spent");
    }

    function test_withdraw_revertWhenAmountLessThan1Gwei() public {
        vm.prank(user);
        vm.expectRevert(IGameLogic.AmountAtLeast1e9.selector);
        gameLogic.withdraw(1 gwei - 1);
    }

    function test_withdraw_revertWhenInsufficientLiquidity() public {
        // User has Coin (e.g. from born + some mint) but contract has no token to pay out.
        // Give user Coin by minting directly from assets (as proxy).
        vm.prank(proxy);
        gameAssets.mint(user, Property.COIN_ID, 10 ether, "");
        // Contract has 0 token.
        assertEq(gameToken.balanceOf(proxy), 0);

        vm.prank(user);
        vm.expectRevert(IGameLogic.InsufficientERC20.selector);
        gameLogic.withdraw(10 ether);
    }

    function test_withdraw_success_and5PercentBurn() public {
        uint256 depositAmount = 10 ether;
        _giveUserToken(depositAmount);
        vm.startPrank(user);
        gameToken.approve(proxy, depositAmount);
        gameLogic.deposit(depositAmount);
        vm.stopPrank();

        uint256 coinBalance = depositAmount * 10;
        uint256 withdrawCoin = 10 ether; // 10 ether Coin -> 1 ether token
        vm.prank(user);
        gameLogic.withdraw(withdrawCoin);

        uint256 expectedToken = withdrawCoin / 10; // 1 ether
        uint256 expectedBurn = expectedToken / 20; // 5% = 0.05 ether
        uint256 expectedToUser = expectedToken - expectedBurn; // 0.95 ether

        assertEq(gameToken.balanceOf(user), expectedToUser, "user receives 95%");
        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), coinBalance - withdrawCoin, "Coin deducted");
        assertEq(gameToken.balanceOf(proxy), depositAmount - expectedToken, "contract balance decreased by 1 ether");
        assertEq(gameToken.totalSupply(), depositAmount - expectedBurn, "5% burned");
    }

    // ---------- depositWithPermit ----------

    function test_depositWithPermit_revertWhenAmountLessThan1Ether() public {
        uint256 amount = 1 ether - 1;
        _giveUserTokenTo(signer, 1 ether);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _signPermit(signer, proxy, amount);
        vm.prank(signer);
        vm.expectRevert(IGameLogic.AmountAtLeast1e18.selector);
        gameLogic.depositWithPermit(amount, deadline, v, r, s);
    }

    function test_depositWithPermit_success() public {
        uint256 amount = 2 ether;
        _giveUserTokenTo(signer, amount);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _signPermit(signer, proxy, amount);

        vm.prank(signer);
        gameLogic.depositWithPermit(amount, deadline, v, r, s);

        assertEq(gameAssets.balanceOf(signer, Property.COIN_ID), amount * 10, "signer Coin balance");
        assertEq(gameToken.balanceOf(proxy), amount, "contract token balance");
        assertEq(gameToken.balanceOf(signer), 0, "signer token spent");
    }

    function test_depositWithPermit_revertWhenDeadlineExpired() public {
        uint256 amount = 2 ether;
        _giveUserTokenTo(signer, amount);
        uint256 pastDeadline = block.timestamp - 1;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitRaw(signer, proxy, amount, gameToken.nonces(signer), pastDeadline);

        vm.prank(signer);
        vm.expectRevert(); // ERC2612ExpiredSignature from token
        gameLogic.depositWithPermit(amount, pastDeadline, v, r, s);
    }

    function test_depositWithPermit_revertWhenInvalidSignature() public {
        uint256 amount = 2 ether;
        _giveUserTokenTo(signer, amount);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _signPermit(signer, proxy, amount);
        // Tamper signature
        vm.prank(signer);
        vm.expectRevert(); // ERC2612InvalidSigner or wrong recovery
        gameLogic.depositWithPermit(amount, deadline, v, r, bytes32(uint256(s) + 1));
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

    function test_depositThenWithdraw_roundTrip() public {
        uint256 amount = 100 ether;
        _giveUserToken(amount);
        vm.startPrank(user);
        gameToken.approve(proxy, amount);
        gameLogic.deposit(amount);
        vm.stopPrank();

        uint256 coinBalance = gameAssets.balanceOf(user, Property.COIN_ID);
        uint256 withdrawCoin = coinBalance; // withdraw all Coin
        vm.prank(user);
        gameLogic.withdraw(withdrawCoin);

        uint256 tokenBack = withdrawCoin / 10;
        uint256 burnAmount = tokenBack / 20;
        assertEq(gameToken.balanceOf(user), amount - burnAmount, "user has initial minus 5% of withdrawn");
        assertEq(gameAssets.balanceOf(user, Property.COIN_ID), 0, "no Coin left");
    }

    function _giveUserToken(uint256 amount) internal {
        vm.prank(proxy);
        gameToken.mint(user, amount);
    }

    function _giveUserTokenTo(address to, uint256 amount) internal {
        vm.prank(proxy);
        gameToken.mint(to, amount);
    }
}
