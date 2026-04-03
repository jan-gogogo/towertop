// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IHeroLogic} from "./interfaces/IHeroLogic.sol";
import {Player, Character, AbilitiesExtra} from "./libraries/Character.sol";
import {Floor, Environment} from "./libraries/Environment.sol";
import {Aoka, Enemy} from "./libraries/Enemy.sol";
import {Battle} from "./libraries/Battle.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title HeroLogic
 * @author Jan
 * @notice Holds hero (player) state and floor state: _players, _equipped, _floor. Runs combat, equip/unequip,
 *         floor progression (init, next, circle). Callable only by the permitted Game proxy.
 * @dev Used behind a proxy (e.g. HeroV1). setPermit(gameProxy) must be called once after deployment.
 */
abstract contract HeroLogic is IHeroLogic {
    using SafeCast for uint256;

    address public _permit;

    mapping(address => Player) internal _players;
    mapping(address => uint256[3]) internal _equipped; // 0:Sword 1:Armor 2:Shield
    mapping(address => Floor) internal _floor;

    modifier onlyPermit() {
        _onlyPermit();
        _;
    }

    function addPlayer(address addr, Player calldata player) external onlyPermit {
        _players[addr] = player;
    }

    function setPlayerHealth(address addr, uint16 health) external onlyPermit {
        _players[addr].health = health;
    }

    function playerLevelUp(address addr, uint32 gainedExp) external onlyPermit {
        _playerLevelUp(addr, gainedExp);
    }

    function setEnemyHealth(address addr, uint256 enemySlot, uint16 health) external onlyPermit {
        Floor storage floor = _floor[addr];
        if (enemySlot >= floor.enemies.length) revert ArrayOutOfBounds();
        floor.enemies[enemySlot].health = health;
    }

    function combat(address addr, bytes32 seed, uint256 enemySlot, AbilitiesExtra calldata ae)
        external
        onlyPermit
        returns (bool playerWin, uint8 floorIndex, uint8 enemyLevel)
    {
        Player storage player = _players[addr];
        Floor storage floor = _floor[addr];
        if (enemySlot >= floor.enemies.length) revert IHeroLogic.EnemyNotFound(enemySlot);
        Aoka memory enemy = floor.enemies[enemySlot];
        uint256 enemyHealthOri = enemy.health;
        if (enemyHealthOri == 0) revert IHeroLogic.EnemyNotFound(enemySlot);

        uint256 oriHealth = player.health;
        uint256 oriAttack = player.attack;
        uint256 oriDefense = player.defense;
        (uint256 playerHealFinal, uint256 aokaHealthFinal) =
            Battle.combat(seed, oriHealth, oriAttack, oriDefense, enemy, ae);

        player.health = playerHealFinal.toUint16();
        floorIndex = floor.index;
        enemyLevel = enemy.level;
        playerWin = (aokaHealthFinal == 0);
        if (!playerWin) {
            // If aoka wins, recover 20% health
            aokaHealthFinal = aokaHealthFinal / 10 * 12;
            if (aokaHealthFinal > enemyHealthOri) {
                aokaHealthFinal = enemyHealthOri;
            }
        }
        // casting to 'uint16' is safe because aokaHealthFinal is at most enemyHealthOri (enemy.health was uint16);
        // when player wins it is 0; when player loses we cap it to enemyHealthOri, so always <= 65535.
        // forge-lint: disable-next-line(unsafe-typecast)
        floor.enemies[enemySlot].health = uint16(aokaHealthFinal);

        emit Combat(addr, seed, oriHealth, oriAttack, oriDefense, enemy, ae);
    }

    function equip(address addr, uint256 equipmentId, uint256 slot) external onlyPermit {
        if (slot > 2) revert ArrayOutOfBounds();
        _equipped[addr][slot] = equipmentId;
    }

    function unequip(address addr, uint256 equipmentId) external onlyPermit {
        uint256 slot = _findEquippedSlot(addr, equipmentId);
        delete _equipped[addr][slot];
    }

    function initFloor(address addr, bytes32 seed) external onlyPermit {
        Floor storage floor = _floor[addr];
        if (floor.index != 0) revert WrongFloorIndex();
        _constructFloorData(floor, floor.index, seed);
    }

    function nextFloor(address addr, bytes32 seed) external onlyPermit {
        Floor storage floor = _floor[addr];
        uint8 curIndex = floor.index;
        if (curIndex >= 99) revert ReachedTheTopFloor();
        uint256 enemyCount = floor.enemies.length;
        for (uint256 i = 0; i < enemyCount; i++) {
            if (floor.enemies[i].health > 0) revert MustDefeatAllEenemies();
        }
        Environment.clearFloor(floor);
        floor.index = curIndex + 1;
        _constructFloorData(floor, floor.index, seed);
    }

    function circle(address addr, bytes32 seed) external onlyPermit {
        Floor storage floor = _floor[addr];
        if (floor.index != 99) revert NotAt100Floor();
        Player storage player = _players[addr];
        Character.circle(player);
        Environment.clearFloor(floor);
        _constructFloorData(floor, floor.index, seed);
    }

    function setFloorIndex(address addr, uint8 index) external onlyPermit {
        _floor[addr].index = index;
    }

    function removeShopSlot(address addr, uint256 typeIndex, uint256 slot) external onlyPermit {
        Floor storage floor = _floor[addr];
        if (typeIndex == 0) {
            uint256[] storage items = floor.shop.items;
            if (slot < items.length) delete items[slot];
        } else if (typeIndex == 1) {
            if (slot < floor.shop.equipments.length) {
                delete floor.shop.equipments[slot];
            }
        }
    }

    function getPlayer(address addr) external view returns (Player memory) {
        return _players[addr];
    }

    function getFloor(address addr) external view returns (Floor memory) {
        return _floor[addr];
    }

    function getEnemies(address addr) external view returns (Aoka[] memory) {
        return _floor[addr].enemies;
    }

    function getEquippedIds(address addr) external view returns (uint256[3] memory) {
        return _equipped[addr];
    }

    /// @notice player level up, increase attributes
    function _playerLevelUp(address addr, uint32 gainedExp) private {
        Player storage p = _players[addr];
        uint8 curLevel = p.level;
        if (curLevel >= 100) return;
        (bool levelUp, uint32 remainExp) = Character.isLevelUp(curLevel, gainedExp, p.experience);
        if (!levelUp) {
            p.experience += gainedExp;
            return;
        }
        (uint16 healthMaxIncrement, uint16 attackIncrement, uint16 defenseIncrement) =
            Character.levelUpAttributesIncrement();
        unchecked {
            p.healthMax += healthMaxIncrement;
            p.attack += attackIncrement;
            p.defense += defenseIncrement;
            p.experience = remainExp;
            p.level++;
        }
    }

    function _findEquippedSlot(address addr, uint256 equipmentId) private view returns (uint256) {
        uint256[3] storage slots = _equipped[addr];
        for (uint256 i = 0; i < 3; i++) {
            if (slots[i] == equipmentId) return i;
        }
        revert IHeroLogic.NotEquippedId(equipmentId);
    }

    function _constructFloorData(Floor storage floor, uint256 floorIndex, bytes32 seed) private {
        uint256 shopCount = Environment.shopCountNextFloor(uint8(seed[0]), floorIndex);
        uint256 foundryCount = Environment.foundryCountNextFloor(uint8(seed[1]), floorIndex);
        uint256 aokaCount = Environment.aokaCountNextFloor(uint8(seed[2]), floorIndex, shopCount, foundryCount);
        if (shopCount > 0) Environment.fillShop(floor.shop, seed, floorIndex);
        if (foundryCount > 0) Environment.fillFoundry(floor.foundry, floorIndex);
        if (aokaCount > 0) Enemy.fillAokas(floor.enemies, seed, floorIndex, aokaCount);
    }

    /// @notice Set the permitted caller once (e.g. Game proxy); only when _permit is still address(0).
    function setPermit(address permit_) external {
        if (_permit != address(0)) revert Unauthorized();
        _permit = permit_;
    }

    function _onlyPermit() private view {
        if (msg.sender != _permit) revert Unauthorized();
    }
}
