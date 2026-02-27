// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Player {
    // 1-100
    uint8 level;
    uint16 experience;
    uint16 healthMax;
    uint16 health;
    uint16 attack;
    uint16 defense;
    uint8 courage;
    uint40 createAt;
}

struct AbilitiesExtra {
    uint16 attack;
    uint16 defense;
    uint16 crit;
    uint16 critChance;
    uint16 stunChance;
    uint16 blockChance;
    uint8 weaponMaterialsIdx;
    bool armorEquipped;
    uint8 armorMaterialsIdx;
}

struct Equipment {
    uint256 sword;
    uint256 armor;
    uint256 shield;
    uint256 specialItem;
}

library Character {
    function isLevelUp(uint8 curLevel, uint16 gainedExp, uint16 curExp) internal pure returns (bool) {
        unchecked {
            // overflow not possible
            // (gainedExp + curExp) is at most 25750 (design: total exp 1→100), so sum < 30000
            // curLevel is at most 100, so 5 * (curLevel + 1) <= 505
            return gainedExp + curExp >= 5 * (uint16(curLevel) + 1);
        }
    }

    function levelUpAttributesIncrement(uint8 curLevel)
        internal
        pure
        returns (uint16 healthMaxIncrement, uint16 attackIncrement, uint16 defenseIncrement)
    {
        unchecked {
            // overflow not possible
            // curLevel is at most 100
            // (4 * 100 + 20) < 65535
            healthMaxIncrement = 20 + (uint16(curLevel) - 1) * 4;
            attackIncrement = 3 + (curLevel - 1);
            defenseIncrement = 2 + (curLevel - 1);
        }
    }

    function initPlayer() internal view returns (Player memory) {
        unchecked {
            return Player({
                level: 1,
                experience: 0,
                healthMax: 100,
                health: 100,
                attack: 10,
                defense: 5,
                courage: 0,
                createAt: uint40(block.timestamp)
            });
        }
    }

    function circle(Player storage player) internal {
        Player memory ip = initPlayer();
        player.level = ip.level;
        player.experience = ip.experience;
        player.healthMax = ip.healthMax;
        player.health = ip.health;
        player.attack = ip.attack;
        player.defense = ip.defense;
        player.courage++;
    }
}
