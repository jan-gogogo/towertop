// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Equipment} from "../libraries/Property.sol";

interface IInventoryLogic {
    error Unauthorized();
    error NeedMoreSpace();
    error EmptyItems();
    error CapacityExceeded();
    error ArrayOutOfBounds();
    error EquipmentNotFound(uint256 id);
    error ItemNotFound(uint256 slot);
    error WrongItemType();
    error WrongSequence();
    error InvalidEquipmentId(uint256 id);
    error InvalidTypeIndex(uint256 typeIndex);
    error InvalidIndex(uint256 index);
    error ReachedMaxLevel();
    error CannotMerge();
    error SameEquipmentIds();
    error LengthOutOfRange1To5();

    function setPermit(address permit_) external;
    function addItem(address addr, uint256 itemId) external;
    function addItems(address addr, uint256[] calldata itemIds) external;
    function addEquipment(address addr, Equipment calldata equipment) external returns (uint256 equipmentId);
    function removeFromWarehouse(address addr, uint256 equipmentId) external;
    function addToWarehouse(address addr, uint256 equipmentId) external;
    function useItems(address addr, uint256[] calldata slots)
        external
        returns (uint32 totalExpGain, uint16 totalHealthGain);
    function buyFromShopItem(address addr, uint256 itemId) external returns (uint256 cost);
    function buyFromShopEquipment(address addr, Equipment calldata equipment)
        external
        returns (uint256 cost, uint256 assetId);
    function upgrade(address addr, uint256 equipmentId, bytes32 seed) external returns (uint256 cost);
    function mergeEquipment(address addr, uint256 mainId, uint256 subId, bytes32 seed) external returns (uint256 cost);

    function rewardWinner(address winner, bytes32 seed, uint256 floorIndex)
        external
        returns (uint256[] memory assetIds, uint256[] memory values);

    function getBag(address addr) external view returns (uint256[] memory itemIds);
    function getWarehouse(address addr) external view returns (uint256[] memory equipmentIds);
    function getEquipment(uint256 id) external view returns (Equipment memory);
    function isValidEquipment(uint256 id) external pure returns (bool);
}
