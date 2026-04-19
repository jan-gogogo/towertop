// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Aoka} from "./Enemy.sol";
import {Rarity} from "./Attribute.sol";
import {FloorIndex} from "./FloorIndex.sol";
import {Equipment, EquipmentMaterials, EquipmentType, Property} from "./Property.sol";

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
    // uint256[] price;
    uint256[] items;
    Equipment[] equipments;
    // uint256[] equipmentPrices;
}

library Environment {
    /// @notice calculate the shop count on next floor
    function shopCountNextFloor(uint8 random, uint256 floorIndex) internal pure returns (uint256) {
        if (floorIndex < 5) return 0;

        unchecked {
            // overflow not possible
            // because floorIndex ≤ 99
            uint256 f = floorIndex + 51;
            if (f > 128) f = 128;
            return uint256(random) < f ? 1 : 0;
        }
    }

    /// @notice calculate the foundry count on next floor
    function foundryCountNextFloor(uint8 random, uint256 floorIndex) internal pure returns (uint256) {
        if (floorIndex < 10) return 0;

        unchecked {
            // overflow not possible
            // because floorIndex ≤ 99
            uint256 f = floorIndex + 38;
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
    ///         book = 20, potion = 60. Uses seed[i] for rarity/materials,
    ///         seed[16+i] for type roll.
    function fillShop(Shop storage shop, bytes32 seed, uint256 floorIndex) internal {
        // overflow not possible because floorIndex <= 99
        unchecked {
            uint256 slotCount = 2 + (uint256(seed) % 3);

            uint256 equipWeight = 40 + floorIndex / 5;
            uint256 bookWeight = 20;
            uint256 potionWeight = 60;
            uint256 totalWeight = equipWeight + bookWeight + potionWeight;

            uint256 swordBorder = equipWeight / 3;
            uint256 shieldBorder = equipWeight - swordBorder;
            uint256 bookBorder = equipWeight + bookWeight;

            uint256 useCountOneRound = 5;

            for (uint256 i = 0; i < slotCount; i++) {
                Rarity rarity = Property.calRarity(uint8(seed[i * useCountOneRound + 0]), floorIndex);
                uint256 r = uint256(uint8(seed[i * useCountOneRound + 1])) % totalWeight;

                if (r < equipWeight) {
                    uint8 level = Property.calEquipmentLevel(floorIndex);
                    EquipmentMaterials materials = Property.calEquipmentMaterials(uint8(seed[i * useCountOneRound + 2]));
                    uint8 seedForGroth = uint8(seed[i * useCountOneRound + 3]);
                    uint8 seedForScope = uint8(seed[i * useCountOneRound + 4]);
                    if (r < swordBorder) {
                        Property.pushEquipment(
                            shop.equipments, EquipmentType.Sword, materials, rarity, level, seedForGroth, seedForScope
                        );
                    } else if (r < shieldBorder) {
                        Property.pushEquipment(
                            shop.equipments, EquipmentType.Shield, materials, rarity, level, seedForGroth, seedForScope
                        );
                    } else {
                        Property.pushEquipment(
                            shop.equipments, EquipmentType.Armor, materials, rarity, level, seedForGroth, seedForScope
                        );
                    }
                } else {
                    if (r < bookBorder) {
                        shop.items.push(Property.getBookId(rarity));
                    } else {
                        shop.items.push(Property.getPotionId(rarity));
                    }
                }
            }
        }
    }

    function calEntryCost(uint256 entryFloor) internal pure returns (uint256) {
        if (entryFloor < 21) return 0;

        return (entryFloor - 20) * 15e17; //1.5 ether
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
