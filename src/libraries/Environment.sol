// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Aoka} from "./Enemy.sol";
import {Equipment, EquipmentMaterials, Property} from "./Property.sol";
import {Rarity} from "./Attribute.sol";
import {FloorIndex} from "./FloorIndex.sol";

struct Floor {
    // 0–99
    uint8 index;
    Aoka[] enemies;
    Foundry foundry;
    Shop shop;
}

struct Foundry {
    // max rarity tier for this foundry;
    // only equipment of this rarity or lower can be forged (e.g. A allows A and below).
    Rarity rarity;
}

struct Shop {
    uint256[] price;
    uint256[] items;
    Equipment[] equipments;
    uint256[] equipmentPrices;
}

library Environment {
    /// @notice calculate the shop count on next floor
    function shopCountNextFloor(uint8 random, uint256 floorIndex) internal pure returns (uint256) {
        if (floorIndex < 3) return 0;

        // f = min(128, 51 + (floor_index * 256) / 200)
        // random < f ? 1 : 0
        unchecked {
            // overflow not possible
            // because floorIndex ≤ 99
            uint256 f = (floorIndex * 256) / 200 + 51;
            if (f > 128) f = 128;
            return uint256(random) < f ? 1 : 0;
        }
    }

    /// @notice calculate the foundry count on next floor
    function foundryCountNextFloor(uint8 random, uint256 floorIndex) internal pure returns (uint256) {
        if (floorIndex < 5) return 0;

        // f = min(115, 38 + (floor_index * 256) / 250)
        // random < f ? 1 : 0
        unchecked {
            // overflow not possible
            // because floorIndex ≤ 99
            uint256 f = (floorIndex * 256) / 250 + 38;
            if (f > 115) f = 115;
            return uint256(random) < f ? 1 : 0;
        }
    }

    /// @notice calculate Aoka count on next floor (BOSS floor always 1)
    function aokaCountNextFloor(uint8 random, uint256 floorIndex, uint256 shopCount, uint256 foundryCount)
        internal
        pure
        returns (uint256)
    {
        if (FloorIndex.isBossFloor(floorIndex)) return 1;
        unchecked {
            // overflow not possible; shopCount ≤ 1, foundryCount ≤ 1
            return uint256(random < 128 ? 3 : 4) - shopCount - foundryCount;
        }
    }

    function fillFoundry(Foundry storage foundry, uint256 floorIndex) internal {
        unchecked {
            // S only at 90+.
            uint256 d = floorIndex / 25;
            uint256 idx = floorIndex >= 90 ? 3 : (d > 2 ? 2 : d);
            // casting to 'uint8' is safe because ids is at most 3
            // forge-lint: disable-next-line(unsafe-typecast)
            foundry.rarity = Rarity(uint8(idx));
        }
    }

    /// @notice Fills shop with 2–4 slots of equipment (sword/shield/armor)
    ///         or consumables (book/potion) by floorIndex and seed.
    /// @dev    Slot count: 2 + (floorIndex % 3). Type by weight:
    ///         equip = 40 + floorIndex/5 (split sword/shield/armor 1/3 each),
    ///         book = 30, potion = 50. Uses seed[i] for rarity/materials,
    ///         seed[16+i] for type roll.
    function fillShop(Shop storage shop, bytes32 seed, uint256 floorIndex) internal {
        // overflow not possible because floorIndex <= 99
        unchecked {
            uint256 slotCount = 2 + (floorIndex % 3);

            uint256 equipWeight = 40 + floorIndex / 5;
            uint256 bookWeight = 30;
            uint256 potionWeight = 50;
            uint256 totalWeight = equipWeight + bookWeight + potionWeight;

            uint256 swordBorder = equipWeight / 3;
            uint256 shieldBorder = equipWeight - swordBorder;
            uint256 bookBorder = equipWeight + bookWeight;

            for (uint256 i = 0; i < slotCount; i++) {
                Rarity rarity = Property.calRarity(uint8(seed[i]), floorIndex);
                uint256 r = uint256(uint8(seed[16 + i])) % totalWeight;

                if (r < equipWeight) {
                    uint8 level = Property.calEquipmentLevel(floorIndex);
                    EquipmentMaterials materials = Property.calEquipmentMaterials(uint8(seed[i + slotCount]));
                    if (r < swordBorder) {
                        Property.pushEquipmentSword(shop.equipments, materials, rarity, level);
                    } else if (r < shieldBorder) {
                        Property.pushEquipmentShield(shop.equipments, rarity, level);
                    } else {
                        Property.pushEquipmentArmor(shop.equipments, materials, rarity, level);
                    }
                    shop.equipmentPrices.push(Property.equipPrice(level, rarity));
                } else {
                    if (r < bookBorder) {
                        shop.items.push(Property.getBookId(rarity));
                        shop.price.push(Property.calBookValue(rarity));
                    } else {
                        shop.items.push(Property.getPotionId(rarity));
                        shop.price.push(Property.calPotionValue(rarity));
                    }
                }
            }
        }
    }

    function clearFloor(Floor storage floor) internal {
        // according to EIP-2200, clearing the entire floor can provide some gas refunds
        // this can partially offset the gas cost of regenerating the floor afterwards
        delete floor.index;
        delete floor.enemies;
        delete floor.foundry;
        delete floor.shop;
    }
}
