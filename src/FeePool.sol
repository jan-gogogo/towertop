// SPDX-License-Identifier: MIt
pragma solidity ^0.8.24;
import {IFeePool} from "./interfaces/IFeePool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract FeePool is ReentrancyGuardTransient, IFeePool {
    error NoFeeIn();
    error NotManager();
    error PayoutFailed();
    error BalanceTooLow();
    error NotGameContract();
    error SendFromPoolFailed();
    error InvalidReceiverAddress();

    event Withdraw(address indexed manager, uint256 amount);
    event SendFromPool(address indexed receiver, uint256 amount, string memo);

    address public _game;
    address public _manager;
    uint256 public _feePool; // Fee pool for player incentives
    uint256 public _feeTeam; // Team revenue

    uint256 private constant MAX_BPS = 10000; // Max Basis Points
    uint256 private constant INCOME_TEAM_PART_RATE = 2000; // 20%

    modifier onlyManager() {
        _onlyManager();
        _;
    }

    constructor(address _manager_) {
        _manager = _manager_;
    }

    function feein() external payable {
        if (msg.value == 0) revert NoFeeIn();
        _feeAllocation(msg.value);
    }

    function withdraw() external onlyManager nonReentrant {
        uint256 amount = _feeTeam;
        if (amount == 0) revert BalanceTooLow();
        _feeTeam = 0;
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert PayoutFailed();
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice To incentivize players, the game will send a portion of the fee pool to players
     *         through activities such as rankings, PVP, achievements, etc.
     * @param receiver Address of the fund recipient
     * @param amount Amount of funds to send
     */
    function send(address receiver, uint256 amount, string calldata memo) external nonReentrant {
        if (msg.sender != _game) revert NotGameContract();
        if (receiver == address(0)) revert InvalidReceiverAddress();
        if (_feePool < amount) revert BalanceTooLow();

        _feePool -= amount;
        (bool success,) = receiver.call{value: amount}("");
        if (!success) revert SendFromPoolFailed();

        emit SendFromPool(receiver, amount, memo);
    }

    function _feeAllocation(uint256 fee) private {
        // Split fee: 20% to team, 80% to pool (for player incentives)
        uint256 team = Math.mulDiv(fee, INCOME_TEAM_PART_RATE, MAX_BPS, Math.Rounding.Floor);
        uint256 pool = fee - team;
        _feePool += pool;
        _feeTeam += team;
    }

    function _onlyManager() private view {
        if (msg.sender != _manager) revert NotManager();
    }
}
