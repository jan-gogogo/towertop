// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Floor} from "../libraries/Environment.sol";
import {Player, AbilitiesExtra} from "../libraries/Character.sol";
import {Aoka} from "../libraries/Enemy.sol";

interface IGameLogic {
    event Born(address indexed addr);
    event Combat(address indexed addr, bytes32 seed, Floor floor, Player player, AbilitiesExtra ae, Aoka aoka);
    event RequestRandom(address indexed addr, uint256 requestId, uint256 floorIndex);
    event FulfillRandom(address indexed addr, uint256 requestId, uint256 random);

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
    error ReachedMaxLevel();
    error WrongFloorIndex();
    error NotAt100Floor();
    error MustDefeatAllEenemies();
    error EmptyItemIds();
    error LengthOutOfRange1To5();
    error WrongItemType();
    error WrongSequence();
    error AlreadyFullHealth();
    error InvalidTypeIndex(uint256 typeIndex);
    error InvalidIndex(uint256 index);
    error CannotMerge();
    error SameEquipmentIds();

    /**
     * @notice create a player (register and give initial assets)
     */
    function born() external;

    /**
     * @notice deposit ERC20 token for game coin; caller must approve this contract first
     * @param amount amount in token's smallest unit (e.g. wei), must be >= 1 ether
     */
    function deposit(uint256 amount) external;

    /**
     * @notice deposit ERC20 token for game coin in one tx without prior approve by using EIP-2612 permit
     * @dev calls token.permit(owner, address(this), amount, deadline, v, r, s) then transferFrom; same amount rules as deposit (e.g. amount >= 1 ether).
     * @param amount token amount to deposit (same unit as deposit, e.g. wei; must be >= 1 ether)
     * @param deadline permit signature expiry (unix timestamp; must be >= block.timestamp)
     * @param v EIP-712 signature recovery id (27 or 28)
     * @param r EIP-712 signature r
     * @param s EIP-712 signature s
     */
    function depositWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @notice burn game coin and withdraw ERC20 token to caller (with 5% burn)
     * @param amount coin amount to withdraw, must be >= 1 gwei
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice fight enemy at the given slot on current floor
     * @param enemySlot index of enemy in current floor's enemy list
     */
    function battle(uint256 enemySlot) external;

    /**
     * @notice advance to next floor after all enemies on current floor are defeated
     */
    function nextFloor() external;

    /**
     * @notice use items at the given bag slots (book or potion only); slots must be ascending and unique, length 1–5
     * @param slots bag slot indices in ascending order
     */
    function useItems(uint256[] calldata slots) external;

    /**
     * @notice spend coin to restore health to healthMax; only when health < healthMax
     */
    function fullHeal() external;

    /**
     * @notice equip an equipment from warehouse by id
     * @param equipmentId equipment token id (must exist in caller's warehouse)
     */
    function equip(uint256 equipmentId) external;

    /**
     * @notice unequip an equipment and put it back to warehouse
     * @param equipmentId equipment token id (must be currently equipped)
     */
    function unequip(uint256 equipmentId) external;

    /**
     * @notice buy one item or equipment from current floor's shop
     * @param typeIndex 0: item (book/potion), 1: equipment (sword/shield/armor in shop.equipments)
     * @param slot index in shop.items (typeIndex=0) or shop.equipments (typeIndex=1)
     */
    function buy(uint256 typeIndex, uint256 slot, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /**
     * @notice upgrade a single equipment by spending coin; level increases on success
     * @param equipmentId equipment token id to upgrade
     */
    function upgrade(uint256 equipmentId) external;

    /**
     * @notice merge two swords into a higher-rarity main sword; sub sword is consumed
     * @param mainEquipmentId equipment id of the main sword (must be equipped)
     * @param subEquipmentId equipment id of the sub sword (must be in warehouse)
     */
    function mergeSword(uint256 mainEquipmentId, uint256 subEquipmentId) external;

    /**
     * @notice merge two armors into a higher-rarity main armor; sub armor is consumed
     * @param mainEquipmentId equipment id of the main armor (must be equipped)
     * @param subEquipmentId equipment id of the sub armor (must be in warehouse)
     */
    function mergeArmor(uint256 mainEquipmentId, uint256 subEquipmentId) external;

    /**
     * @notice merge two shields into a higher-rarity main shield; sub shield is consumed
     * @param mainEquipmentId equipment id of the main shield (must be equipped)
     * @param subEquipmentId equipment id of the sub shield (must be in warehouse)
     */
    function mergeShield(uint256 mainEquipmentId, uint256 subEquipmentId) external;

    /**
     * @notice Rebirth at the top floor (100th): reset level/stats to initial,
     *         keep equipment, items and coins; courage +1; floor resets to first layer.
     * @dev    Callable only when at floor index 99 (100th floor).
     *         Player level, experience, health and combat stats are reset;
     *         equipment, bag items and coins are unchanged; courage increments;
     *         floor is cleared and rebuilt for layer 0.
     */
    function circle() external;

    /**
     * @notice get floor state for an address
     * @param addr player address
     */
    function getFloor(address addr) external view returns (Floor memory);

    /**
     * @notice get current floor's enemies for an address
     * @param addr player address
     */
    function getEnemies(address addr) external view returns (Aoka[] memory);

    /**
     * @notice get player state for an address
     * @param addr player address
     */
    function getPlayer(address addr) external view returns (Player memory);

    /**
     * @notice get bag (consumable item slot ids) for an address
     * @param addr player address
     */
    function getBag(address addr) external view returns (uint256[] memory itemIds);

    /**
     * @notice get warehouse (equipment token ids) for an address
     * @param addr player address
     */
    function getWarehouse(address addr) external view returns (uint256[] memory weaponIds);
}
