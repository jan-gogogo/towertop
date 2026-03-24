// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {AbilitiesExtra} from "./Character.sol";
import {Aoka} from "./Enemy.sol";
import {Property, EquipmentType, EquipmentMaterials} from "./Property.sol";
import {FloorIndex} from "./FloorIndex.sol";
import {Rarity} from "./Attribute.sol";
import {Seed} from "./Seed.sol";

library Battle {
    using Seed for bytes32;
    using FloorIndex for uint256;

    // word "critchance"
    bytes32 private constant SEED_MIX_CRITCHANCE = 0x637269746368616e636500000000000000000000000000000000000000000000;
    // word "blockchance"
    bytes32 private constant SEED_MIX_BLOCKCHANCE = 0x626c6f636b6368616e6365000000000000000000000000000000000000000000;
    // word "stunchance"
    bytes32 private constant SEED_MIX_STUNCHANCE = 0x7374756e6368616e636500000000000000000000000000000000000000000000;

    struct RoundVars {
        uint256 attack;
        uint256 damage;
        uint256 defense;
        uint256 crit;
        uint256 critChance;
        uint256 blockChance;
        uint256 stunChance;
        bool hasElementalAdvantage;
    }

    function combat(
        bytes32 seed,
        uint256 playerHealth,
        uint256 playerAttack,
        uint256 playerDefense,
        Aoka memory aoka,
        AbilitiesExtra memory ae
    ) internal pure returns (uint256 pHealthFinal, uint256 aHealthFinal) {
        uint256 pHealth = playerHealth;
        uint256 aHealth = aoka.health;
        uint256 pAttack = playerAttack + ae.attack;
        uint256 pDefense = playerDefense + ae.defense;
        bool stunned = false;

        bool playerAdvantage = _elementalAdvantageForPlayerAttack(ae.weaponMaterialsIdx, uint256(aoka.trait));
        bool aokaAdvantage = _elementalAdvantageForAokaAttack(uint256(aoka.trait), ae.armorMaterialsIdx);
        (bytes32 roll1, bytes32 roll2, bytes32 roll3) = _generateRandomNums(seed);
        RoundVars memory rv;
        for (uint256 i = 0; i < 32; i++) {
            if (stunned) {
                stunned = false;
                continue;
            }

            uint256 parity = i & 1;

            if (parity == 0) {
                rv.attack = pAttack;
                rv.crit = ae.crit;
                rv.critChance = ae.critChance;
                rv.stunChance = ae.stunChance;
                rv.defense = aoka.defense;
                rv.blockChance = aoka.blockChance;
                rv.hasElementalAdvantage = playerAdvantage;
            } else {
                rv.attack = aoka.attack;
                rv.crit = aoka.crit;
                rv.critChance = aoka.critChance;
                rv.stunChance = aoka.stunChance;
                rv.defense = pDefense;
                rv.blockChance = ae.blockChance;
                rv.hasElementalAdvantage = aokaAdvantage && ae.armorEquipped;
            }

            uint256 damage = _calculateDamage(
                rv.attack,
                rv.defense,
                rv.crit,
                rv.critChance,
                rv.blockChance,
                uint8(roll1[i]),
                uint8(roll2[i]),
                rv.hasElementalAdvantage
            );

            if (rv.stunChance > 0) {
                if (uint8(roll3[i]) < (rv.stunChance * 256) / 100) stunned = true;
            }

            if (parity == 0) {
                aHealth = damage < aHealth ? aHealth - damage : 0;
            } else {
                pHealth = damage < pHealth ? pHealth - damage : 0;
            }

            if (pHealth == 0 || aHealth == 0) break;
        }

        pHealthFinal = pHealth;
        aHealthFinal = aHealth;
    }

    function rewardCoins(uint256 floorIndex) internal pure returns (uint256 coinCount) {
        unchecked {
            coinCount = floorIndex.isBossFloor() ? (floorIndex + 1) + 5 : floorIndex / 5 + 1;
            coinCount *= 1 ether;
        }
    }

    function rewardItems(bytes32 seed, uint256 floorIndex) internal pure returns (uint256[] memory assetIds) {
        unchecked {
            bool isBoss = floorIndex.isBossFloor();
            // 1 or 2
            uint256 count = (uint8(seed[4]) % 2) + 1;
            // around 5% or 0
            uint8 s = (isBoss && floorIndex > 69) ? 13 : 0;

            assetIds = new uint256[](count);

            for (uint256 i = 0; i < count; i++) {
                // 204 is around 80% of 256
                bool isPotion = uint8(seed[i * 2 + 5]) < 204;
                uint8 rarityRoll = uint8(seed[i * 2 + 6]);
                uint256 id = 1;
                if (rarityRoll < s) {
                    id = 4;
                } else if (rarityRoll < 26) {
                    // around 10%
                    id = 3;
                } else if (rarityRoll < 78) {
                    // around 30%
                    id = 2;
                }
                if (isPotion) id += 100;
                assetIds[i] = id;
            }
        }
    }

    function calRewardExperience(uint8 enemyLevel, uint256 floorIndex) internal pure returns (uint32) {
        bool isBoss = floorIndex.isBossFloor();
        uint256 exp = 0;
        unchecked {
            if (isBoss) {
                exp = 2 * uint256(enemyLevel) + (floorIndex + 1);
            } else {
                exp = uint256(enemyLevel) / 2 + floorIndex + 1;
            }
        }
        // casting to 'uint32' is safe because enemyLevel <=100, floorIndex <=99
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint32(exp);
    }

    function equipmentDetermine(uint8 random, uint256 floorIndex) internal pure returns (bool) {
        uint256 segment = floorIndex / 10;
        uint256 init = floorIndex.isBossFloor() ? segment + 12 : (segment / 2) + 3;
        return uint256(random) < (init * 256) / 100;
    }

    function rewardEquipment(bytes32 seed, uint256 floorIndex)
        internal
        pure
        returns (uint8 level, Rarity rarity, EquipmentMaterials materials, EquipmentType typ)
    {
        level = Property.calEquipmentLevel(floorIndex);
        rarity = Property.calRarity(uint8(seed[1]), floorIndex);
        materials = Property.calEquipmentMaterials(uint8(seed[2]));
        typ = EquipmentType(uint8(seed[3]) % 3);
    }

    function _calculateDamage(
        uint256 attack,
        uint256 defense,
        uint256 crit,
        uint256 critChance,
        uint256 blockChance,
        uint256 roll1,
        uint256 roll2,
        bool isElementalAdvantage
    ) internal pure returns (uint256) {
        uint256 damage = 1;

        if (attack > defense) {
            damage = attack - defense;
        }

        if (isElementalAdvantage && damage > 1) {
            damage = (damage * 110) / 100;
        }

        if ((crit > 0 && roll1 < (critChance * 256) / 100)) {
            damage += damage * crit;
        }

        if ((damage > 1 && roll2 < (blockChance * 256) / 100)) {
            damage /= 2;
        }
        return damage;
    }

    function _generateRandomNums(bytes32 seed) private pure returns (bytes32 roll1, bytes32 roll2, bytes32 roll3) {
        roll1 = seed.change(10, SEED_MIX_CRITCHANCE);
        roll2 = seed.change(11, SEED_MIX_BLOCKCHANCE);
        roll3 = seed.change(10, SEED_MIX_STUNCHANCE);
    }

    function _elementalAdvantageForPlayerAttack(uint256 attackEle, uint256 defenseEle) private pure returns (bool) {
        // [0]EquipmentMaterials.Wooden -> [0]AokaTrait.Electric
        // [1]EquipmentMaterials.Iron -> [1]AokaTrait.Earth
        // [2]EquipmentMaterials.Obsidian -> [2]AokaTrait.Fire
        // so if the indexs are the same
        // it means the attributes are mutually restrained (elemental advantage)
        return attackEle == defenseEle;
    }

    function _elementalAdvantageForAokaAttack(uint256 attackEle, uint256 defenseEle) private pure returns (bool) {
        // [0]AokaTrait.Electric -> [1]EquipmentMaterials.Iron
        // [1]AokaTrait.Earth -> [2]EquipmentMaterials.Obsidian
        // [2]AokaTrait.Fire -> [0]EquipmentMaterials.Wooden
        unchecked {
            return (attackEle + 1) % 3 == defenseEle;
        }
    }
}
