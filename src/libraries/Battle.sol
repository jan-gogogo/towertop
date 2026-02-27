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
        uint256 damage = 0;
        uint256 attack = 0;
        uint256 crit = 0;
        uint256 critChance = 0;
        uint256 stunChance = 0;
        uint256 defense = 0;
        uint256 blockChance = 0;
        bool hasElementalAdvantage = false;

        bool playerAdvantage = _elementalAdvantageForPlayerAttack(ae.weaponMaterialsIdx, uint256(aoka.trait));
        bool aokaAdvantage = _elementalAdvantageForAokaAttack(uint256(aoka.trait), ae.armorMaterialsIdx);

        (bytes32 roll1, bytes32 roll2, bytes32 roll3) = _generateRandomNums(seed);

        for (uint256 i = 0; i < 32; i++) {
            if (stunned) {
                stunned = false;
                continue;
            }

            uint256 parity = i & 1;

            if (parity == 0) {
                // player's round

                // attacker
                attack = pAttack;
                crit = ae.crit;
                critChance = ae.critChance;
                stunChance = ae.stunChance;

                // defender
                defense = aoka.defense;
                blockChance = aoka.blockChance;
                hasElementalAdvantage = playerAdvantage;
            } else {
                // Aoka's round
                // attacker
                attack = aoka.attack;
                crit = aoka.crit;
                critChance = aoka.critChance;
                stunChance = aoka.stunChance;

                // defender
                defense = pDefense;
                blockChance = ae.blockChance;
                hasElementalAdvantage = aokaAdvantage && ae.armorEquipped;
            }

            damage = _calculateDamage(
                attack, defense, crit, critChance, blockChance, uint8(roll1[i]), uint8(roll2[i]), hasElementalAdvantage
            );

            if (stunChance > 0) {
                unchecked {
                    if (uint8(roll3[i]) < (stunChance * 256) / 100) {
                        // skip the next attacker's action
                        stunned = true;
                    }
                }
            }

            unchecked {
                if (parity == 0) {
                    if (aHealth > damage) aHealth -= damage;
                    else aHealth = 0;
                } else {
                    if (pHealth > damage) pHealth -= damage;
                    else pHealth = 0;
                }
            }

            if (pHealth == 0 || aHealth == 0) break;
        }

        pHealthFinal = pHealth;
        aHealthFinal = aHealth;
    }

    function rewardItemsAppendEquipmentAndCoins(bytes32 seed, uint256 floorIndex, uint256 eqiupmentId)
        internal
        pure
        returns (uint256[] memory assetIds, uint256[] memory values)
    {
        unchecked {
            bool isBoss = floorIndex.isBossFloor();
            // 1 or 2
            uint256 count = (uint8(seed[4]) % 2) + 1;
            // around 5% or 0
            uint8 s = (isBoss && floorIndex > 69) ? 13 : 0;
            // items + equipment and coin
            assetIds = new uint256[](count + 2);
            values = new uint256[](count + 2);

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
                values[i] = 1;
            }
            // append equipmentId
            assetIds[count] = eqiupmentId;
            values[count] = 1;

            // append coin
            uint256 coinCount = 0;
            if (isBoss) {
                coinCount = (floorIndex + 1) * 2 + 5;
            } else {
                coinCount = floorIndex / 5 + 1;
            }
            assetIds[count + 1] = Property.COIN_ID;
            values[count + 1] = coinCount * 1 ether;
        }
    }

    function calRewardExperience(uint8 enemyLevel, uint256 floorIndex) internal pure returns (uint32) {
        bool isBoss = floorIndex.isBossFloor();
        uint256 exp = 0;
        unchecked {
            if (isBoss) {
                exp = 10 * uint256(enemyLevel) + 5 * (floorIndex + 1);
            } else {
                exp = 2 * uint256(enemyLevel) + floorIndex + 1;
            }
        }
        // casting to 'uint32' is safe because enemyLevel <=100, floorIndex <=99
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint32(exp);
    }

    function equipmentDetermine(uint8 random, uint256 floorIndex) internal pure returns (bool) {
        uint256 segment = floorIndex / 10;
        uint256 init = floorIndex.isBossFloor() ? segment * 2 + 25 : segment + 5;
        // `random` will be implicitly converted to uint256
        return random < (init * 256) / 100;
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
            unchecked {
                damage = attack - defense;
            }
        }

        if (isElementalAdvantage && damage > 1) {
            damage = (damage * 110) / 100;
        }

        if ((roll1 < (critChance * 256) / 100) && crit > 0) {
            damage += damage * crit;
        }

        if ((roll2 < (blockChance * 256) / 100) && damage > 1) {
            unchecked {
                damage /= 2;
            }
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
