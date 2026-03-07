// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Rarity} from "./Attribute.sol";

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
//  Sword uses attack/crit/critChance/stunChance;
//  Armor uses defense;
//  Shield uses defense/blockChance/stunChance.
//  Unused fields are 0.
struct Equipment {
    EquipmentType etype;
    EquipmentMaterials materials;
    Rarity rarity; // 1-4
    uint8 level; // 1-25
    uint16 attack;
    uint16 defense;
    uint16 crit; // 0 - 5
    uint16 critChance; // 0-100
    uint16 blockChance; // 0-100
    uint16 stunChance; // 0-100
}

struct Puppet {
    Rarity rarity;
    uint40 lastClaimAt;
}

library Property {
    error WrongPotionId();
    error WrongBookId();
    error WrongItemId();
    error WrongEquipmentId();

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

    uint256 constant COIN_ID = 301;

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

    function calSecondAttributesDirectly(Rarity rarity)
        internal
        pure
        returns (uint16 crit, uint16 critChance, uint16 blockChance, uint16 stunChance)
    {
        if (rarity == Rarity.C) {
            return (0, 0, 0, 0);
        }

        // if not through foundry, degrade(rarity - 1) the second attributes
        unchecked {
            (crit, critChance, blockChance, stunChance) = calSecondAttributes(Rarity(uint8(rarity) - 1));
        }
    }

    function calSecondAttributes(Rarity rarity)
        internal
        pure
        returns (uint16 crit, uint16 critChance, uint16 blockChance, uint16 stunChance)
    {
        if (rarity == Rarity.C) {
            return (0, 0, 0, 0);
        }

        // here rarity is 1 to 3 (B/A/S)
        uint8 mul = uint8(rarity);
        crit = mul;
        unchecked {
            critChance = 7 * mul;
            blockChance = 7 * mul;
            stunChance = 5 * mul;
        }
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
        // C=10, B=20, A=40, S=80  ->  10 * 2^rarity
        unchecked {
            return uint32(10 * (2 ** uint256(rarity)));
        }
    }

    function calPotionValue(uint256 itemId) internal pure returns (uint16) {
        if (itemId < 101 || itemId > 104) {
            revert WrongPotionId();
        }
        unchecked {
            Rarity rarity = Rarity(itemId - 101);
            return calPotionValue(rarity);
        }
    }

    function calPotionValue(Rarity rarity) internal pure returns (uint16) {
        // C=15，B=30，A=60，S=120 -> 15 * 2^rarity
        unchecked {
            return uint16(15 * (2 ** uint256(rarity)));
        }
    }

    function pushEquipmentSword(Equipment[] storage arr, EquipmentMaterials materials, Rarity rarity, uint8 level)
        internal
    {
        (uint16 crit, uint16 critChance,, uint16 stunChance) = calSecondAttributesDirectly(rarity);
        arr.push(
            Equipment({
                etype: EquipmentType.Sword,
                materials: materials,
                rarity: rarity,
                level: level,
                attack: calAttackForSword(rarity, level),
                defense: 0,
                crit: crit,
                critChance: critChance,
                blockChance: 0,
                stunChance: stunChance
            })
        );
    }

    function pushEquipmentArmor(Equipment[] storage arr, EquipmentMaterials materials, Rarity rarity, uint8 level)
        internal
    {
        arr.push(
            Equipment({
                etype: EquipmentType.Armor,
                materials: materials,
                rarity: rarity,
                level: level,
                attack: 0,
                defense: calDefenseForArmor(rarity, level),
                crit: 0,
                critChance: 0,
                blockChance: 0,
                stunChance: 0
            })
        );
    }

    function pushEquipmentShield(Equipment[] storage arr, Rarity rarity, uint8 level) internal {
        (,, uint16 blockChance, uint16 stunChance) = calSecondAttributesDirectly(rarity);
        arr.push(
            Equipment({
                etype: EquipmentType.Shield,
                materials: EquipmentMaterials.Wooden,
                rarity: rarity,
                level: level,
                attack: 0,
                defense: calDefenseForShield(rarity, level),
                crit: 0,
                critChance: 0,
                blockChance: blockChance,
                stunChance: stunChance
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
        if (floorIndex < 20) return Rarity.C;
        unchecked {
            uint256 mod = floorIndex >= 80 ? 3 : 2;
            // casting to 'uint8' is safe because mod is at most 3
            // forge-lint: disable-next-line(unsafe-typecast)
            return Rarity(uint8(uint256(random) % mod));
        }
    }

    function calEquipmentMaterials(uint8 random) internal pure returns (EquipmentMaterials) {
        unchecked {
            return EquipmentMaterials(uint8(random % 3));
        }
    }

    function calAttackForSword(Rarity rarity, uint8 level) internal pure returns (uint16) {
        unchecked {
            uint8 rarityBonus = uint8(rarity) * 2;
            return uint16(level + rarityBonus);
        }
    }

    function calDefenseForArmor(Rarity rarity, uint8 level) internal pure returns (uint16) {
        unchecked {
            uint8 rarityBonus = uint8(rarity) * 2;
            return uint16(level + rarityBonus);
        }
    }

    function calDefenseForShield(Rarity rarity, uint8 level) internal pure returns (uint16) {
        unchecked {
            uint8 rarityBonus = uint8(rarity) * 2;
            return uint16((level + 1) / 2 + rarityBonus);
        }
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

    function equipmentCost(uint8 level, Rarity rarity) internal pure returns (uint256) {
        unchecked {
            return (3 * uint256(level) + 8 * uint256(rarity) + 2) * 1 ether;
        }
    }

    function itemCost(uint256 itemId) internal pure returns (uint256) {
        if (!isValidBookOrPotion(itemId)) revert WrongItemId();

        uint256 id = itemId;
        uint256 add = 3;
        uint256 mul = 5;
        unchecked {
            if (id > 100) {
                // potion
                add = 2;
                mul = 4;
                id -= 100;
            }
            id--;
            return (mul * id + add) * 1 ether;
        }
    }

    function upgradeEquipmentCost(uint8 curLevel) internal pure returns (uint256) {
        unchecked {
            return (uint256(curLevel) * 2 + 3) * 1 ether;
        }
    }

    function determineUpgrade(uint8 random, uint8 curLevel) internal pure returns (bool) {
        // P_upgrade = max(40%, 95% - 2% * L)
        // overflow not possible because curLevel <=25
        unchecked {
            uint8 p = 243 - 5 * curLevel;
            if (p > 102) p = 102;
            return random < p;
        }
    }

    function determineMerge(uint8 random, Rarity rarity) internal pure returns (bool) {
        unchecked {
            uint8 p = 0;
            if (Rarity.C == rarity) {
                p = 157; // 60%
            } else if (Rarity.B == rarity) {
                p = 79; // 30%
            } else {
                p = 13; // 5%
            }
            return random < p;
        }
    }

    function mergeEquipmentCost(uint8 curLevel, Rarity curRarity) internal pure returns (uint256) {
        //cost_merge = 5 + 3 * mainLevel + 5 * rarity_oldIndex
        // overflow not possible because curLevel <=25, curRarity <=3
        unchecked {
            return (uint256(curLevel) * 3 + uint256(curRarity) * 5 + 5) * 1 ether;
        }
    }

    function isValidBookOrPotion(uint256 itemId) private pure returns (bool) {
        if (itemId > 0 && itemId < 5) return true;
        if (itemId > 100 && itemId < 105) return true;
        return false;
    }
}
