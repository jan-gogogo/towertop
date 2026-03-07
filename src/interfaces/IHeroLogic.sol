// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Floor} from "../libraries/Environment.sol";
import {Player, AbilitiesExtra} from "../libraries/Character.sol";
import {Aoka} from "../libraries/Enemy.sol";

interface IHeroLogic {
    event Combat(
        address player,
        bytes32 seed,
        uint256 playerHealth,
        uint256 playerAttack,
        uint256 playerDefense,
        Aoka aoka,
        AbilitiesExtra ae
    );

    error Unauthorized();
    error NotEquippedId(uint256 id);
    error EnemyNotFound(uint256 slot);
    error WrongFloorIndex();
    error ReachedTheTopFloor();
    error MustDefeatAllEenemies();
    error NotAt100Floor();
    error InvalidEquipmentId(uint256 equipmentId);
    error ArrayOutOfBounds();

    function setPermit(address permit_) external;
    function addPlayer(address addr, Player calldata player) external;
    function setPlayerHealth(address addr, uint16 health) external;
    function playerLevelUp(address addr, uint32 gainedExp) external;
    function setEnemyHealth(address addr, uint256 enemySlot, uint16 health) external;
    function combat(address addr, bytes32 seed, uint256 enemySlot, AbilitiesExtra calldata ae)
        external
        returns (bool playerWin, uint8 floorIndex, uint8 enemyLevel);
    function equip(address addr, uint256 equipmentId, uint256 slot) external;
    function unequip(address addr, uint256 equipmentId) external;
    function initFloor(address addr, bytes32 seed) external;
    function nextFloor(address addr, bytes32 seed) external;
    function circle(address addr, bytes32 seed) external;
    function removeShopSlot(address addr, uint256 typeIndex, uint256 slot) external;

    function setFloorIndex(address addr, uint8 index) external;

    function getPlayer(address addr) external view returns (Player memory);
    function getFloor(address addr) external view returns (Floor memory);
    function getEnemies(address addr) external view returns (Aoka[] memory);
    function getEquippedIds(address addr) external view returns (uint256[4] memory);
}
