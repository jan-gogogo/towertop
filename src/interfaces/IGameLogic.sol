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
    error InvalidTypeIndex(uint256 typeIndex);
    error InvalidIndex(uint256 index);

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
     * @param typeIndex 0: item (book/potion), 1: sword, 2: shield, 3: armor
     * @param slot index of the item or equipment in the shop list
     */
    function buy(uint256 typeIndex, uint256 slot) external;

    /**
     * @notice get floor state for an address
     * @param addr player address
     */
    function getFloor(address addr) external view returns (Floor memory);

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
