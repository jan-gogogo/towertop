// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Floor} from "../libraries/Environment.sol";
import {Player} from "../libraries/Character.sol";

interface IGameLogic {
    error PlayerAlreadyExists();
    error AmountAtLeast1e18();
    error AmountAtLeast1e9();
    error InsufficientCoin();
    error InsufficientERC20();
    error EnemyNotFound(uint256 slot);
    error PlayerNotFound(address addr);
    error EquipmentNotFound(uint256 id);
    error ItemNotFound(uint256 slot);
    error InvalidEquipmentId(uint256 equipmentId);
    error ReachedTheTopFloor();
    error WrongFloorIndex();
    error NotAt100Floor();
    error MustDefeatAllEenemies();
    error EmptyItemIds();
    error LengthOutOfRange1To5();
    error WrongItemType();
    error WrongSequence();
    error AlreadyFullHealth();

    function born() external;
    function deposit(uint256 amount) external;
    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function withdraw(uint256 amount) external;

    function battle(uint256 enemySlot) external;
    function nextFloor() external;
    function useItems(uint256[] calldata slots) external;
    function fullHeal() external;
    function equip(uint256 equipmentId) external;
    function unequip(uint256 equipmentId) external;

    function getFloor(address addr) external view returns (Floor memory);
    function getPlayer(address addr) external view returns (Player memory);
    function getBag(address addr) external view returns (uint256[] memory itemIds);
    function getWarehouse(address addr) external view returns (uint256[] memory weaponIds);
}
