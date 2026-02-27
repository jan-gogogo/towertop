// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Rarity} from "./libraries/Attribute.sol";
import {Property, Sword, Armor, Shield, Puppet} from "./libraries/Property.sol";
import {Player} from "./libraries/Character.sol";
import {Floor} from "./libraries/Environment.sol";

/**
 * @title Game storage contract
 * @author Jan
 * @notice Stores all logical data for the game
 * @dev GameFi TowerTop supports logic contract upgrades. All game logic lives in GameLogic;
 *      this contract is single-responsibility storage only. As a result, it necessarily
 *      exposes many "update data" functions (e.g. updateAfterBattle, updateHealth,
 *      updateExperience) that merely persist values computed by the logic contract.
 */
abstract contract GameStorage {
    uint256 private constant EMPTY_SLOT = 0;
    uint256 private constant BAG_CAP = 100;
    uint256 private constant WAREHOUSE_CAP = 100;
    uint256 private constant EQUIPMENT_CAP = 1e9;

    mapping(address => Player) private _players;
    mapping(address palyer => uint256[]) private _bag;
    mapping(address palyer => uint256[]) private _warehouse;
    mapping(address palyer => Floor) _floor;
    // 0:SwordId 1:ArmorId 2:ShieldId
    mapping(address player => uint256[3]) private _equipped;

    mapping(uint256 id => Sword) private _swords;
    mapping(uint256 id => Armor) private _armors;
    mapping(uint256 id => Shield) private _shields;
    mapping(uint256 id => Puppet) private _puppets;

    // start with 1e9
    uint256 private _nextSwordId;
    // start with 2e9
    uint256 private _nextArmorId;
    // start with 3e9
    uint256 private _nextShieldId;
    // start with 4e9
    uint256 private _nextPuppetId;

    error ProxyAddressAlreadySet();
    error NeedMoreSpace();
    error EmptyItems();
    error CapacityExceeded();
    error ArrayOutOfBounds();

    /// @notice Initialize next-IDs (for proxy: call from implementation's initialize(); constructor only runs on impl, not on proxy).
    function _initNextIds() internal {
        // already inited (e.g. re-initialization guard)
        if (_nextSwordId != 0) return;

        _nextSwordId = 1e9;
        _nextArmorId = 2e9;
        _nextShieldId = 3e9;
        _nextPuppetId = 4e9;
    }

    function addPlayer(address addr, Player memory player) internal {
        _players[addr] = player;
    }

    function addSword(address addr, Sword memory sword) internal returns (uint256) {
        uint256 latest = _nextSwordId;
        if (latest >= 2e9) revert CapacityExceeded();

        _swords[latest] = sword;
        // overflow not possible
        // _nextSwordId < 2e9 limitation above
        unchecked {
            _nextSwordId++;
        }

        // add to player's warehouse
        _addToWarehouse(addr, latest);
        return latest;
    }

    function addArmor(address addr, Armor memory armor) internal returns (uint256) {
        uint256 latest = _nextArmorId;
        if (latest >= 3e9) revert CapacityExceeded();

        _armors[latest] = armor;
        // overflow not possible
        // _nextArmorId < 3e9 limitation above
        unchecked {
            _nextArmorId++;
        }
        _addToWarehouse(addr, latest);
        return latest;
    }

    function addShield(address addr, Shield memory shield) internal returns (uint256) {
        uint256 latest = _nextShieldId;
        if (latest >= 4e9) revert CapacityExceeded();

        _shields[latest] = shield;
        // overflow not possible
        // _nextShieldId < 4e9 limitation above
        unchecked {
            _nextShieldId++;
        }
        _addToWarehouse(addr, latest);
        return latest;
    }

    function addPuppet(address addr, Rarity rarity, uint40 lastClaimAt) internal returns (uint256) {
        uint256 latest = _nextPuppetId;
        if (latest >= 5e9) revert CapacityExceeded();

        _puppets[latest] = Puppet({rarity: rarity, lastClaimAt: lastClaimAt});
        unchecked {
            _nextPuppetId++;
        }
        _addToWarehouse(addr, latest);
        return latest;
    }

    function addItem(address addr, uint256 itemId) internal {
        _addItemBatch(addr, Property.asSingletonArrays(itemId));
    }

    function addItems(address addr, uint256[] memory itemIds) internal {
        _addItemBatch(addr, itemIds);
    }

    /**
     * @notice Delete multiple items from a player's bag.
     * @param slots The indexes of the items in _bag, starting from 0.
     */
    function delItems(address addr, uint256[] memory slots) internal {
        uint256 count = slots.length;
        if (count == 0) return;

        uint256[] storage _mb = _bag[addr];
        uint256 len = _mb.length;

        // use `delete` to remove elements
        // after deleting, _bag.length does not change
        for (uint256 i = 0; i < count; i++) {
            uint256 slot = slots[i];
            if (slot >= len) revert ArrayOutOfBounds();
            if (_mb[slot] != EMPTY_SLOT) {
                delete _mb[slot];
            }
        }
    }

    function updateAfterBattle(address addr, uint8 level, uint16 experience, uint16 healthMax, uint16 health) external {
        Player storage player = _players[addr];
        player.level = level;
        player.experience = experience;
        player.healthMax = healthMax;
        player.health = health;
    }

    function updateHealth(address addr, uint16 health) external {
        _players[addr].health = health;
    }

    function updateExperience(address addr, uint16 experience) external {
        _players[addr].experience = experience;
    }

    function getBag(address addr) internal view returns (uint256[] memory itemIds) {
        uint256[] storage _mb = _bag[addr];
        uint256 len = _mb.length;
        itemIds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            itemIds[i] = _mb[i];
        }
    }

    function getWarehouse(address addr) internal view returns (uint256[] memory weaponIds) {
        uint256[] storage _wh = _warehouse[addr];
        uint256 len = _wh.length;
        weaponIds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            weaponIds[i] = _wh[i];
        }
    }

    function getFloor(address addr) internal view returns (Floor storage) {
        return _floor[addr];
    }

    function getPlayer(address addr) internal view returns (Player storage) {
        return _players[addr];
    }

    function getEquipped(address addr)
        internal
        view
        returns (Sword memory sword, Armor memory armor, Shield memory shield)
    {
        // 0:SwordId 1:ArmorId 2:ShieldId
        uint256[3] storage ids = _equipped[addr];
        uint256 swordId = ids[0];
        uint256 armorId = ids[1];
        uint256 shieldId = ids[2];
        if (swordId > 0) {
            sword = _swords[swordId];
        }
        if (armorId > 0) {
            armor = _armors[armorId];
        }
        if (shieldId > 0) {
            shield = _shields[shieldId];
        }
    }

    /// @notice add a new weaponId to player's warehouse
    function _addToWarehouse(address addr, uint256 id) private {
        uint256[] storage _wh = _warehouse[addr];
        uint256 len = _wh.length;

        if (len >= WAREHOUSE_CAP) revert NeedMoreSpace();

        // first, add id to a empty slot(_wh[i]==0) if possible
        for (uint256 i = 0; i < len; i++) {
            if (_wh[i] == EMPTY_SLOT) {
                _wh[i] = id;
                return;
            }
        }

        // no any empty slot, push id to the `_warehouse`
        _wh.push(id);
    }

    function _addItemBatch(address addr, uint256[] memory itemIds) private {
        uint256 itemsLen = itemIds.length;
        if (itemsLen == 0) revert EmptyItems();

        uint256 op = 0;
        uint256[] storage _mb = _bag[addr];
        uint256 len = _mb.length;

        // first, add items to empty slots (_mb[i]==0) if possible
        for (uint256 i = 0; i < len; i++) {
            if (_mb[i] == EMPTY_SLOT) {
                _mb[i] = itemIds[op];
                unchecked {
                    op++;
                }
            }

            if (op == itemsLen) {
                // all added
                return;
            }
        }

        // if there is still remaining, append the rest of the items to the _bag
        uint256 remains = itemsLen - op;
        if (remains + len > BAG_CAP) revert NeedMoreSpace();

        for (uint256 i = 0; i < remains; i++) {
            _mb.push(itemIds[op + i]);
        }
    }
}
