// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGameLogic {
    error PlayerAlreadyExists();
    error AmountAtLeast1e18();
    error AmountAtLeast1e9();
    error InsufficientCoin();
    error InsufficientERC20();
    error EnemyNotFound();
    error PlayerNotFound();
    error ReachedTheTopFloor();
    error WrongFloorIndex();
    error NotAt100Floor();

    function born() external;
    function deposit(uint256 amount) external;
    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function withdraw(uint256 amount) external;

    function battle(uint256 enemyIdx) external;
}
