// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Rarity} from "./Attribute.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

enum ItemType {
    Empty,
    Book,
    Potion,
    Stone
}

enum EquipmentMaterials {
    Wooden,
    Iron,
    Obsidian
}

enum EquipmentType {
    Sword,
    Armor,
    Shield
}

/*================================================================================
                                        equipment (unified union)
=================================================================================*/

//  Unified equipment:
//  Sword uses attack/crit/critChance;
//  Armor uses defense/blockChance;
//  Shield uses defense/stunChance.
//  Unused fields are 0.
struct Equipment {
    EquipmentType etype;
    EquipmentMaterials materials;
    Rarity rarity; // 1-4
    uint8 level; // 1-25
    uint16 attack;
    uint16 defense;
    uint16 crit; // 0 - 5
    uint16 critChance; // 0-100, 15 means 15%
    uint16 blockChance; // 0-100
    uint16 stunChance; // 0-100
    uint16 growth; // 100-400, it means grouth * (attack or defense) / 100 when level up
}

library Property {
    error WrongPotionId();
    error WrongBookId();
    error WrongItemId();
    error WrongEquipmentId();
    error WrongRarity();
    error WrongGrowth();
    error CannotCalEquipmentCost();

    uint256 constant MAX_EQUIPMENT_LEVEL = 25;

    uint256 constant BOOK_C_ID = 1;
    uint256 constant BOOK_B_ID = 2;
    uint256 constant BOOK_A_ID = 3;
    uint256 constant BOOK_S_ID = 4;

    uint256 constant POTION_C_ID = 101;
    uint256 constant POTION_B_ID = 102;
    uint256 constant POTION_A_ID = 103;
    uint256 constant POTION_S_ID = 104;

    uint256 constant REFERSH_STONE_ID = 201;

    uint256 constant REFINING_STONE_ID = 301;

    function asSingletonArrays(uint256 element1) internal pure returns (uint256[] memory array1) {
        assembly ("memory-safe") {
            array1 := mload(0x40)
            mstore(array1, 1)
            mstore(add(array1, 0x20), element1)

            // update the next-available slot pointer
            // because we marked "memory-safe"
            mstore(0x40, add(array1, 64))
        }
    }

    function getBookId(Rarity rarity) internal pure returns (uint256) {
        return uint256(rarity) + 1;
    }

    function getPotionId(Rarity rarity) internal pure returns (uint256) {
        return uint256(rarity) + 101;
    }

    function calSecondAttributeForSword(Rarity rarity, uint16 growth)
        internal
        pure
        returns (uint16 crit, uint16 critChance)
    {
        if (rarity == Rarity.C) {
            return (0, 0);
        }

        //  rarity is 1 to 3 (B/A/S)
        uint8 mul = uint8(rarity);
        crit = mul;
        critChance = calSecondAttributesWithGrowth(5, growth, mul);
    }

    function calSecondAttributeForShield(Rarity rarity, uint16 growth) internal pure returns (uint16 stunChance) {
        if (rarity == Rarity.C) {
            return 0;
        }

        //  rarity is 1 to 3 (B/A/S)
        stunChance = calSecondAttributesWithGrowth(3, growth, uint8(rarity));
    }

    function calSecondAttributeForArmor(Rarity rarity, uint16 growth) internal pure returns (uint16 blockChance) {
        if (rarity == Rarity.C) {
            return 0;
        }

        //  rarity is 1 to 3 (B/A/S)
        blockChance = calSecondAttributesWithGrowth(5, growth, uint8(rarity));
    }

    function calBookValue(uint256 itemId) internal pure returns (uint32) {
        if (itemId < 1 || itemId > 4) {
            revert WrongBookId();
        }
        unchecked {
            Rarity rarity = Rarity(itemId - 1);
            return calBookValue(rarity);
        }
    }

    function calBookValue(Rarity rarity) internal pure returns (uint32) {
        // C=40, B=80, A=160, S=320  ->  40 * 2^rarity
        unchecked {
            return uint32(40 * (2 ** uint256(rarity)));
        }
    }

    function calPotionValue(uint256 itemId) internal pure returns (uint16) {
        if (itemId < 101 || itemId > 104) {
            revert WrongPotionId();
        }
        Rarity rarity = Rarity(itemId - 101);
        return calPotionValue(rarity);
    }

    function calPotionValue(Rarity rarity) internal pure returns (uint16) {
        // C=50，B=100，A=200
        // S=1000
        return rarity == Rarity.S ? 1000 : uint16(50 * (2 ** uint256(rarity)));
    }

    function pushEquipment(
        Equipment[] storage arr,
        EquipmentType typ,
        EquipmentMaterials materials,
        Rarity rarity,
        uint8 level,
        uint8 random1,
        uint8 random2
    ) internal {
        // High growth equipment will not in shops
        uint16 growth = getGrowthForShop(random1, random2);
        uint16 crit = 0;
        uint16 critChance = 0;
        uint16 blockChance = 0;
        uint16 stunChance = 0;

        uint16 mainValue = calMainAttribute(typ, growth, level);
        uint16 attack = 0;
        uint16 defense = 0;
        if (EquipmentType.Sword == typ) {
            attack = mainValue;
            (crit, critChance) = Property.calSecondAttributeForSword(rarity, growth);
        } else if (EquipmentType.Shield == typ) {
            defense = mainValue;
            stunChance = Property.calSecondAttributeForShield(rarity, growth);
        } else if (EquipmentType.Armor == typ) {
            defense = mainValue;
            blockChance = Property.calSecondAttributeForArmor(rarity, growth);
        }
        arr.push(
            Equipment({
                etype: typ,
                materials: materials,
                rarity: rarity,
                level: level,
                attack: attack,
                defense: defense,
                crit: crit,
                critChance: critChance,
                blockChance: blockChance,
                stunChance: stunChance,
                growth: growth
            })
        );
    }

    function equipPrice(uint256 level, Rarity rarity) internal pure returns (uint256) {
        unchecked {
            return 20 * level * (1 + uint256(rarity));
        }
    }

    function calEquipmentLevel(uint256 floorIndex) internal pure returns (uint8) {
        unchecked {
            // casting to 'uint8' is safe because floorIndex is at most 99
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint8(floorIndex / 5 + 1);
        }
    }

    function calRarity(uint8 random, uint256 floorIndex) internal pure returns (Rarity) {
        if (floorIndex < 51) return Rarity.C; // only C
        return Rarity(uint8(uint256(random) % 2)); // C or B
    }

    function calRarityForDefeatedBoss(uint8 random, uint256 floorIndex) internal pure returns (Rarity) {
        if (floorIndex < 31) return Rarity.C; // only C
        if (floorIndex < 61) return Rarity(uint8(uint256(random) % 2)); // C or B
        if (floorIndex < 91) return Rarity(uint8(uint256(random) % 2) + 1); // B or A
        return Rarity.A;
    }

    /**
     * @notice calculate growth value of equipments in shop
     * ≈60% probability [100,199]
     * ≈39% probability [200,299]
     * ≈1% probability [300,400]
     * @param random1 random for growth level
     * @param random2 random for growth scope
     */
    function getGrowthForShop(uint8 random1, uint8 random2) internal pure returns (uint16) {
        return getGrowthDifficulty(253, random1, random2);
    }

    /**
     * @notice calculate growth value of equipments for victory
     * ≈60% probability [100,199]
     * ≈30% probability [200,299]
     * ≈10% probability [300,400]
     * @param random1 random for growth level
     * @param random2 random for growth scope
     */
    function getGrowthForVictory(uint8 random1, uint8 random2) internal pure returns (uint16) {
        return getGrowthDifficulty(230, random1, random2);
    }

    /**
     * @notice map 0-255 to 100-400 based on weighted probabilities
     */
    function getGrowthDifficulty(uint8 midStep, uint8 random1, uint8 random2) private pure returns (uint16) {
        uint256 difficulty = 0;
        if (random1 <= 153) {
            // [100,199]
            difficulty = 100 + (uint256(random2) % 100);
        } else if (random1 <= midStep) {
            // [200,299]
            difficulty = 200 + (uint256(random2) % 100);
        } else {
            // [300,400]
            difficulty = 300 + (uint256(random2) * 101);
        }
        // casting to 'uint16' is safe because difficulty is at most 400
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(difficulty);
    }

    function getRefiningStoneFromDismantle(uint16 attack, uint16 defense, Rarity rarity)
        internal
        pure
        returns (uint256)
    {
        return (attack > 0 ? attack : defense) * (uint256(rarity) + 1);
    }

    function calEquipmentMaterials(uint8 random) internal pure returns (EquipmentMaterials) {
        unchecked {
            return EquipmentMaterials(uint8(random % 3));
        }
    }

    function calMainAttribute(EquipmentType typ, uint256 growth, uint256 level) internal pure returns (uint16) {
        uint256 basis = 5; // 1 for Shield

        if (EquipmentType.Sword == typ) {
            basis = 7;
        } else if (EquipmentType.Armor == typ) {
            basis = 7;
        }

        uint256 attribute = Math.mulDiv(growth, level, 100, Math.Rounding.Floor);

        // casting to 'uint16' is safe because attribute is at most 12
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(attribute + basis);
    }

    function typeFromItemId(uint256 id) internal pure returns (ItemType typ) {
        if (id == 0) {
            return ItemType.Empty;
        }

        if (id < 101) {
            typ = ItemType.Book;
        } else if (id < 201) {
            typ = ItemType.Potion;
        } else if (id < 301) {
            typ = ItemType.Stone;
        } else {
            typ = ItemType.Empty;
        }
    }

    function equipmentCost(uint16 growth, Rarity rarity) internal pure returns (uint256) {
        if (!isValidRarity(rarity)) revert WrongRarity();
        if (!isValidGroth(growth)) revert WrongGrowth();

        uint256 cost = 0;
        uint256 step = growth / 100;
        cost = growth * step * 1 ether;

        if (Rarity.B == rarity) {
            cost += 300 ether;
        } else if (Rarity.A == rarity) {
            cost += 1800 ether;
        } else if (Rarity.S == rarity) {
            cost += 10000 ether;
        }

        return cost;
    }

    function itemCost(uint256 itemId) internal pure returns (uint256) {
        if (!isValidBookOrPotion(itemId)) revert WrongItemId();
        // book   25, 50, 100, 200
        // potion 4, 8, 16, 150

        if (POTION_S_ID == itemId) return 150;

        uint256 id = itemId;
        uint256 initVal = 4;
        if (id > 100) {
            // potion
            id -= 100;
        } else {
            // book
            initVal = 25;
        }
        if (id > 0) id--;
        return (initVal * 2 ** id) * 1 ether;
    }

    function upgradeEquipmentCost(Rarity rarity, uint8 curLevel) internal pure returns (uint256) {
        uint256 mul = 0;
        if (Rarity.C == rarity) {
            mul = 5;
        } else if (Rarity.B == rarity) {
            mul = 15;
        } else if (Rarity.A == rarity) {
            mul = 20;
        } else {
            mul = 30;
        }

        return Math.mulDiv(uint256(curLevel), mul * 1 ether, 10, Math.Rounding.Ceil);
    }

    function upgradeEquipmentIngredients(Rarity rarity, uint16 attack, uint16 defense) internal pure returns (uint256) {
        uint16 mainAttribute = attack > 0 ? attack : defense;

        return mainAttribute * 13 * (uint256(rarity) + 1) / 10;
    }

    function determineUpgrade(uint8 random, Rarity rarity, uint8 curLevel) internal pure returns (bool) {
        // C: [0,255) means rarity C(curLevel 1) has a ≈99.6% success rate, curLevel 24 has a ≈90% success rate
        // B: [0,242) means rarity B(curLevel 1) has a ≈94.5% success rate, curLevel 24 has a ≈85% success rate
        // A: [0,229) means rarity A(curLevel 1) has a ≈89.4% success rate, curLevel 24 has a ≈80% success rate
        // S: [0,216) means rarity S(curLevel 1) has a ≈84.3% success rate, curLevel 24 has a ≈75% success rate
        uint256 step = 13;

        return random < 256 - (uint8(rarity) * step) - curLevel;
    }

    function determineMerge(uint8 random, Rarity rarity) internal pure returns (bool) {
        uint8 step = 0;
        if (Rarity.C == rarity) {
            step = 180; // ≈70%
        } else if (Rarity.B == rarity) {
            step = 90; // ≈35%
        } else {
            step = 26; // ≈10%
        }
        return random < step;
    }

    function mergeEquipmentCost(Rarity curRarity) internal pure returns (uint256) {
        if (Rarity.C == curRarity) {
            // C -> B
            return 200 ether;
        } else if (Rarity.B == curRarity) {
            // B -> A
            return 600 ether;
        } else {
            // A -> S
            return 1000 ether;
        }
    }

    function isValidBookOrPotion(uint256 itemId) private pure returns (bool) {
        if (itemId > 0 && itemId < 5) return true;
        if (itemId > 100 && itemId < 105) return true;
        return false;
    }

    function isValidRarity(Rarity rarity) private pure returns (bool) {
        return uint8(rarity) < 4;
    }

    function isValidGroth(uint16 growth) private pure returns (bool) {
        return growth >= 100 || growth <= 400;
    }

    function calSecondAttributesWithGrowth(uint256 basis, uint256 growth, uint256 mul) private pure returns (uint16) {
        unchecked {
            // casting to 'uint16' is safe because growth is at most 400, basis is at most 5, mul is at most 3
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint16(Math.mulDiv(basis, growth, 100, Math.Rounding.Floor) * mul);
        }
    }
}
