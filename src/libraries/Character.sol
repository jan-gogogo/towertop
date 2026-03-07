// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Player {
    // 1-100
    uint8 level;
    uint32 experience;
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
    function isLevelUp(uint8 curLevel, uint32 gainedExp, uint32 curExp) internal pure returns (bool, uint32) {
        unchecked {
            // overflow not possible
            // (gainedExp + curExp) is at most 1100
            uint32 needExp = 5 * (uint32(curLevel) + 1);
            uint32 totalExp = gainedExp + curExp;
            uint32 remainExp = 0;
            bool levelUp = totalExp >= needExp;

            if (levelUp) {
                remainExp = totalExp - needExp;
            }
            return (levelUp, remainExp);
        }
    }

    function levelUpAttributesIncrement()
        internal
        pure
        returns (uint16 healthMaxIncrement, uint16 attackIncrement, uint16 defenseIncrement)
    {
        healthMaxIncrement = 20;
        attackIncrement = 3;
        defenseIncrement = 2;
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
