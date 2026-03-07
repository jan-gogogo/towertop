// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {RouterTestBase} from "./RouterTestBase.sol";
import {Property, Equipment, EquipmentType} from "../src/libraries/Property.sol";
import {Player} from "../src/libraries/Character.sol";
import {Floor} from "../src/libraries/Environment.sol";
import {Aoka} from "../src/libraries/Enemy.sol";

/**
 * Simulates a real user playing Tower Top until cannot nextFloor or level 100.
 * Uses books for exp, potions when low HP, fullHeal with coins, buys/upgrades when possible.
 * Outputs final Player, coin consumed, bag, warehouse, floor, and equipment details.
 */
contract TowerTopSimulationTest is RouterTestBase {
    address user;
    uint256 totalCoinConsumed;
    uint256 bookUseCount;
    uint256 potionUseCount;
    uint256 battleCount;
    uint256 fullHealCount;
    uint256 upgradeCount;
    uint256 mergeCount;
    uint256 seedBase;
    uint256 _txNonce;

    function setUp() public {
        user = address(0x1234);
        seedBase = 0x1234567a;
        totalCoinConsumed = 0;
        bookUseCount = 0;
        potionUseCount = 0;
        battleCount = 0;
        fullHealCount = 0;
        upgradeCount = 0;
        mergeCount = 0;
        _txNonce = 0;

        deployRouterStack();

        vm.startPrank(user);
        _nextSeed();
        gameLogic.born();
        _nextSeed();
        gameToken.approve(address(gameLogic), 1 ether);
        gameLogic.deposit(1 ether);
        _equipBestGear();
        vm.stopPrank();
    }

    function test_simulateRealUserPlayUntilEnd() public {
        vm.startPrank(user);

        while (true) {
            // Player memory p = gameLogic.getPlayer(user);

            Floor memory floor = gameLogic.getFloor(user);

            if (floor.index >= 28) {
                break;
            }

            // 1. Use books (exp) and potions (when HP low) — like a real user
            _useBooksAndPotions();

            // 2. fullHeal when HP is low and we have coins
            _maybeFullHeal();

            // 3. Always equip best gear (sword / armor / shield)
            _equipBestGear();

            // 4. Buy from shop when we have coins
            _maybeBuyFromShop();
            _equipBestGear();

            // 5. Merge equipment when we have a pair (same type, same materials/rarity) and coins
            _maybeMergeEquipment();
            _equipBestGear();

            // 6. Upgrade equipped equipment when we have coins and level < 25
            _maybeUpgradeEquipment();

            // 7. Fight all enemies on current floor
            floor = gameLogic.getFloor(user);
            bool allDead = true;
            for (uint256 i = 0; i < floor.enemies.length; i++) {
                if (floor.enemies[i].health > 0) {
                    allDead = false;
                    _nextSeed();
                    gameLogic.battle(i);
                    battleCount++;
                    _useBooksAndPotions();
                    _maybeFullHeal();
                    floor = gameLogic.getFloor(user);
                }
            }

            if (!allDead) continue;

            // 8. Try next floor
            _nextSeed();
            try gameLogic.nextFloor() {}
            catch {
                break; // ReachedTheTopFloor or other
            }
        }

        vm.stopPrank();

        // ----- Final report -----
        _reportFinalState();
    }

    function _useBooksAndPotions() internal {
        uint256[] memory bag = gameLogic.getBag(user);
        if (bag.length == 0) return;

        Player memory p = gameLogic.getPlayer(user);
        uint256[] memory bookSlots = new uint256[](bag.length);
        uint256[] memory potionSlots = new uint256[](bag.length);
        uint256 nBook = 0;
        uint256 nPotion = 0;

        for (uint256 i = 0; i < bag.length; i++) {
            if (bag[i] == 0) continue;
            if (bag[i] >= 1 && bag[i] <= 4) {
                bookSlots[nBook++] = i;
            } else if (bag[i] >= 101 && bag[i] <= 104) {
                if (p.health < p.healthMax) potionSlots[nPotion++] = i;
            }
        }

        for (uint256 from = 0; from < nBook;) {
            uint256 to = from + 5;
            if (to > nBook) to = nBook;
            uint256 cnt = to - from;
            uint256[] memory slots = new uint256[](cnt);
            for (uint256 j = from; j < to; j++) {
                slots[j - from] = bookSlots[j];
            }
            _nextSeed();
            gameLogic.useItems(slots);
            bookUseCount += cnt;
            from = to;
        }

        for (uint256 from = 0; from < nPotion;) {
            uint256 to = from + 5;
            if (to > nPotion) to = nPotion;
            uint256 cnt = to - from;
            uint256[] memory slots = new uint256[](cnt);
            for (uint256 j = from; j < to; j++) {
                slots[j - from] = potionSlots[j];
            }
            _nextSeed();
            gameLogic.useItems(slots);
            potionUseCount += cnt;
            from = to;
        }
    }

    function _maybeFullHeal() internal {
        Player memory p = gameLogic.getPlayer(user);
        if (p.health >= p.healthMax) return;
        uint256 cost = (5 + uint256(p.level) * 2) * 1 ether;
        if (gameAssets.balanceOf(user, Property.COIN_ID) < cost) return;
        _nextSeed();
        gameLogic.fullHeal();
        totalCoinConsumed += cost;
        fullHealCount++;
    }

    function _maybeBuyFromShop() internal {
        Floor memory floor = gameLogic.getFloor(user);
        uint256 coins = gameAssets.balanceOf(user, Property.COIN_ID);
        if (coins == 0) return;

        // Items (typeIndex 0)
        for (uint256 s = 0; s < floor.shop.items.length; s++) {
            if (floor.shop.items[s] == 0) continue;
            uint256 price = floor.shop.price[s];
            if (price > 0 && coins >= price) {
                uint256 balBefore = gameAssets.balanceOf(user, Property.COIN_ID);
                _nextSeed();
                try gameLogic.buy(0, s) {
                    totalCoinConsumed += (balBefore - gameAssets.balanceOf(user, Property.COIN_ID));
                    return;
                } catch {}
            }
        }
        // Equipment (typeIndex 1): unified shop.equipments / shop.equipmentPrices
        for (uint256 s = 0; s < floor.shop.equipments.length; s++) {
            if (floor.shop.equipments[s].level == 0) continue;
            uint256 price = floor.shop.equipmentPrices[s];
            if (price > 0 && coins >= price) {
                uint256 balBefore = gameAssets.balanceOf(user, Property.COIN_ID);
                _nextSeed();
                try gameLogic.buy(1, s) {
                    totalCoinConsumed += (balBefore - gameAssets.balanceOf(user, Property.COIN_ID));
                    return;
                } catch {}
            }
        }
    }

    function _maybeUpgradeEquipment() internal {
        (uint256 swordId, uint256 armorId, uint256 shieldId,) = _getEquippedIds();

        if (swordId != 0) _tryUpgrade(swordId);
        if (armorId != 0) _tryUpgrade(armorId);
        if (shieldId != 0) _tryUpgrade(shieldId);
    }

    /// @notice Use a fresh random for the next game tx (each battle/buy/upgrade/merge/etc gets different prevrandao).
    function _nextSeed() internal {
        _txNonce++;
        vm.prevrandao(keccak256(abi.encodePacked(seedBase, _txNonce)));
    }

    function _getEquippedIds()
        internal
        view
        returns (uint256 swordId, uint256 armorId, uint256 shieldId, uint256 puppetId)
    {
        uint256[4] memory ids = heroLogic.getEquippedIds(user);
        return (ids[0], ids[1], ids[2], ids[3]);
    }

    function _tryUpgrade(uint256 equipmentId) internal {
        if (equipmentId >= 4e9) return; // puppet
        uint256 coins = gameAssets.balanceOf(user, Property.COIN_ID);
        Equipment memory eq = inventoryLogic.getEquipment(equipmentId);
        if (eq.level >= Property.MAX_EQUIPMENT_LEVEL) return;
        uint256 cost = (uint256(eq.level) * 2 + 3) * 1 ether;
        if (coins < cost) return;
        _nextSeed();
        try gameLogic.upgrade(equipmentId) {
            totalCoinConsumed += cost;
            upgradeCount++;
        } catch {}
    }

    /// @notice Equip the best sword, armor, and shield (by attack/defense, then rarity, then level).
    function _equipBestGear() internal {
        (uint256 curSword, uint256 curArmor, uint256 curShield,) = _getEquippedIds();
        uint256[] memory wh = gameLogic.getWarehouse(user);

        uint256 bestSwordId = _bestSwordId(curSword, wh);
        if (bestSwordId != curSword) {
            if (curSword != 0) {
                _nextSeed();
                try gameLogic.unequip(curSword) {} catch {}
            }
            if (bestSwordId != 0) {
                _nextSeed();
                try gameLogic.equip(bestSwordId) {} catch {}
            }
        }

        uint256 bestArmorId = _bestArmorId(curArmor, wh);
        if (bestArmorId != curArmor) {
            if (curArmor != 0) {
                _nextSeed();
                try gameLogic.unequip(curArmor) {} catch {}
            }
            if (bestArmorId != 0) {
                _nextSeed();
                try gameLogic.equip(bestArmorId) {} catch {}
            }
        }

        uint256 bestShieldId = _bestShieldId(curShield, wh);
        if (bestShieldId != curShield) {
            if (curShield != 0) {
                _nextSeed();
                try gameLogic.unequip(curShield) {} catch {}
            }
            if (bestShieldId != 0) {
                _nextSeed();
                try gameLogic.equip(bestShieldId) {} catch {}
            }
        }
    }

    function _bestSwordId(uint256 equippedId, uint256[] memory wh) internal view returns (uint256 bestId) {
        uint256 bestAttack = 0;
        uint8 bestRarity = 0;
        uint8 bestLevel = 0;
        if (equippedId != 0) {
            Equipment memory e = inventoryLogic.getEquipment(equippedId);
            if (e.etype == EquipmentType.Sword) {
                bestId = equippedId;
                bestAttack = e.attack;
                bestRarity = uint8(e.rarity);
                bestLevel = e.level;
            }
        }
        for (uint256 i = 0; i < wh.length; i++) {
            if (wh[i] < 1e9 || wh[i] >= 2e9) continue;
            Equipment memory e = inventoryLogic.getEquipment(wh[i]);
            if (e.etype != EquipmentType.Sword) continue;
            bool better = e.attack > bestAttack || (e.attack == bestAttack && uint8(e.rarity) > bestRarity)
                || (e.attack == bestAttack && uint8(e.rarity) == bestRarity && e.level > bestLevel);
            if (better) {
                bestId = wh[i];
                bestAttack = e.attack;
                bestRarity = uint8(e.rarity);
                bestLevel = e.level;
            }
        }
        return bestId;
    }

    function _bestArmorId(uint256 equippedId, uint256[] memory wh) internal view returns (uint256 bestId) {
        uint16 bestDef = 0;
        uint8 bestRarity = 0;
        uint8 bestLevel = 0;
        if (equippedId != 0) {
            Equipment memory e = inventoryLogic.getEquipment(equippedId);
            if (e.etype == EquipmentType.Armor) {
                bestId = equippedId;
                bestDef = e.defense;
                bestRarity = uint8(e.rarity);
                bestLevel = e.level;
            }
        }
        for (uint256 i = 0; i < wh.length; i++) {
            if (wh[i] < 2e9 || wh[i] >= 3e9) continue;
            Equipment memory e = inventoryLogic.getEquipment(wh[i]);
            if (e.etype != EquipmentType.Armor) continue;
            bool better = e.defense > bestDef || (e.defense == bestDef && uint8(e.rarity) > bestRarity)
                || (e.defense == bestDef && uint8(e.rarity) == bestRarity && e.level > bestLevel);
            if (better) {
                bestId = wh[i];
                bestDef = e.defense;
                bestRarity = uint8(e.rarity);
                bestLevel = e.level;
            }
        }
        return bestId;
    }

    function _bestShieldId(uint256 equippedId, uint256[] memory wh) internal view returns (uint256 bestId) {
        uint16 bestDef = 0;
        uint16 bestBlock = 0;
        uint8 bestRarity = 0;
        uint8 bestLevel = 0;
        if (equippedId != 0) {
            Equipment memory e = inventoryLogic.getEquipment(equippedId);
            if (e.etype == EquipmentType.Shield) {
                bestId = equippedId;
                bestDef = e.defense;
                bestBlock = e.blockChance;
                bestRarity = uint8(e.rarity);
                bestLevel = e.level;
            }
        }
        for (uint256 i = 0; i < wh.length; i++) {
            if (wh[i] < 3e9 || wh[i] >= 4e9) continue;
            Equipment memory e = inventoryLogic.getEquipment(wh[i]);
            if (e.etype != EquipmentType.Shield) continue;
            bool better = e.defense > bestDef || (e.defense == bestDef && e.blockChance > bestBlock)
                || (e.defense == bestDef && e.blockChance == bestBlock && uint8(e.rarity) > bestRarity)
                || (e.defense == bestDef
                    && e.blockChance == bestBlock
                    && uint8(e.rarity) == bestRarity
                    && e.level > bestLevel);
            if (better) {
                bestId = wh[i];
                bestDef = e.defense;
                bestBlock = e.blockChance;
                bestRarity = uint8(e.rarity);
                bestLevel = e.level;
            }
        }
        return bestId;
    }

    /// @notice Try to merge equipped + warehouse pair (same type, same materials/rarity, rarity < S).
    function _maybeMergeEquipment() internal {
        (uint256 mainSword, uint256 mainArmor, uint256 mainShield,) = _getEquippedIds();
        uint256[] memory wh = gameLogic.getWarehouse(user);
        uint256 coins = gameAssets.balanceOf(user, Property.COIN_ID);

        if (mainSword != 0) {
            Equipment memory mainRef = inventoryLogic.getEquipment(mainSword);
            if (mainRef.etype == EquipmentType.Sword && uint8(mainRef.rarity) < 3) {
                uint256 cost = (uint256(mainRef.level) * 3 + uint256(mainRef.rarity) * 5 + 5) * 1 ether;
                if (coins >= cost) {
                    for (uint256 i = 0; i < wh.length; i++) {
                        if (wh[i] < 1e9 || wh[i] >= 2e9 || wh[i] == mainSword) continue;
                        Equipment memory subRef = inventoryLogic.getEquipment(wh[i]);
                        if (
                            subRef.etype == EquipmentType.Sword && mainRef.materials == subRef.materials
                                && mainRef.rarity == subRef.rarity
                        ) {
                            _nextSeed();
                            try gameLogic.mergeSword(mainSword, wh[i]) {
                                mergeCount++;
                                totalCoinConsumed += cost;
                                return;
                            } catch {}
                        }
                    }
                }
            }
        }

        if (mainArmor != 0) {
            Equipment memory mainRef = inventoryLogic.getEquipment(mainArmor);
            if (mainRef.etype == EquipmentType.Armor && uint8(mainRef.rarity) < 3) {
                uint256 cost = (uint256(mainRef.level) * 3 + uint256(mainRef.rarity) * 5 + 5) * 1 ether;
                if (coins >= cost) {
                    for (uint256 i = 0; i < wh.length; i++) {
                        if (wh[i] < 2e9 || wh[i] >= 3e9 || wh[i] == mainArmor) continue;
                        Equipment memory subRef = inventoryLogic.getEquipment(wh[i]);
                        if (
                            subRef.etype == EquipmentType.Armor && mainRef.materials == subRef.materials
                                && mainRef.rarity == subRef.rarity
                        ) {
                            _nextSeed();
                            try gameLogic.mergeArmor(mainArmor, wh[i]) {
                                mergeCount++;
                                totalCoinConsumed += cost;
                                return;
                            } catch {}
                        }
                    }
                }
            }
        }

        if (mainShield != 0) {
            Equipment memory mainRef = inventoryLogic.getEquipment(mainShield);
            if (mainRef.etype == EquipmentType.Shield && uint8(mainRef.rarity) < 3) {
                uint256 cost = (uint256(mainRef.level) * 3 + uint256(mainRef.rarity) * 5 + 5) * 1 ether;
                if (coins >= cost) {
                    for (uint256 i = 0; i < wh.length; i++) {
                        if (wh[i] < 3e9 || wh[i] >= 4e9 || wh[i] == mainShield) continue;
                        Equipment memory subRef = inventoryLogic.getEquipment(wh[i]);
                        if (subRef.etype == EquipmentType.Shield && mainRef.rarity == subRef.rarity) {
                            _nextSeed();
                            try gameLogic.mergeShield(mainShield, wh[i]) {
                                mergeCount++;
                                totalCoinConsumed += cost;
                                return;
                            } catch {}
                        }
                    }
                }
            }
        }
    }

    function _reportFinalState() internal view {
        Player memory p = gameLogic.getPlayer(user);
        uint256 coinBalance = gameAssets.balanceOf(user, Property.COIN_ID);
        Floor memory floor = gameLogic.getFloor(user);
        uint256[] memory bag = gameLogic.getBag(user);
        uint256[] memory warehouse = gameLogic.getWarehouse(user);
        uint256[4] memory equippedIds = heroLogic.getEquippedIds(user);

        console.log("========== Tower Top Simulation Final Report ==========");
        console.log("--- Player ---");
        console.log("  level", p.level);
        console.log("  experience", p.experience);
        console.log("  healthMax", p.healthMax);
        console.log("  health", p.health);
        console.log("  attack", p.attack);
        console.log("  defense", p.defense);
        console.log("  courage", p.courage);
        console.log("  createAt", p.createAt);

        console.log("--- Coins ---");
        console.log("  total coin consumed (fullHeal + buy + upgrade + merge)", totalCoinConsumed);
        console.log("  player coin balance", coinBalance);

        console.log("--- Actions ---");
        console.log("  book use count", bookUseCount);
        console.log("  potion use count", potionUseCount);
        console.log("  battle count", battleCount);
        console.log("  fullHeal count", fullHealCount);
        console.log("  upgrade count", upgradeCount);
        console.log("  merge count", mergeCount);

        console.log("--- Current Floor ---");
        console.log("  floor index:", floor.index);
        console.log("  enemies count:", floor.enemies.length);
        for (uint256 i = 0; i < floor.enemies.length; i++) {
            Aoka memory e = floor.enemies[i];
            console.log("  enemy", i);
            console.log("    typ", uint8(e.typ), "level", e.level);
            console.log("    health", e.health, "attack", e.attack);
            console.log("    defense", e.defense);
            console.log("    isBoss", e.isBoss ? 1 : 0);
        }
        console.log("  foundry.rarity", uint8(floor.foundry.rarity));
        console.log("  shop.items length", floor.shop.items.length);
        console.log("  shop.equipments length", floor.shop.equipments.length);

        console.log("--- Bag (itemIds) ---");
        console.log("  bag length:", bag.length);
        for (uint256 i = 0; i < bag.length; i++) {
            if (bag[i] != 0) console.log("  slot", i, "itemId", bag[i]);
        }

        console.log("--- Warehouse (equipment ids) ---");
        console.log("  warehouse length:", warehouse.length);
        for (uint256 i = 0; i < warehouse.length; i++) {
            if (warehouse[i] != 0) console.log("  slot", i, "id", warehouse[i]);
        }

        console.log("--- _equipped (ids) ---");
        console.log("  swordId", equippedIds[0], "armorId", equippedIds[1]);
        console.log("  shieldId", equippedIds[2], "puppetId", equippedIds[3]);

        console.log("--- Equipped Sword ---");
        if (equippedIds[0] != 0) _logSword(equippedIds[0]);
        else console.log("  (none)");

        console.log("--- Equipped Armor ---");
        if (equippedIds[1] != 0) _logArmor(equippedIds[1]);
        else console.log("  (none)");

        console.log("--- Equipped Shield ---");
        if (equippedIds[2] != 0) _logShield(equippedIds[2]);
        else console.log("  (none)");

        console.log("--- All Swords (equipped + warehouse) ---");
        _logSword(equippedIds[0]);
        for (uint256 i = 0; i < warehouse.length; i++) {
            uint256 id = warehouse[i];
            if (id >= 1e9 && id < 2e9) _logSword(id);
        }

        console.log("--- All Armors ---");
        _logArmor(equippedIds[1]);
        for (uint256 i = 0; i < warehouse.length; i++) {
            uint256 id = warehouse[i];
            if (id >= 2e9 && id < 3e9) _logArmor(id);
        }

        console.log("--- All Shields ---");
        _logShield(equippedIds[2]);
        for (uint256 i = 0; i < warehouse.length; i++) {
            uint256 id = warehouse[i];
            if (id >= 3e9 && id < 4e9) _logShield(id);
        }

        console.log("========== End Report ==========");
    }

    function _logSword(uint256 id) internal view {
        if (id == 0) return;
        Equipment memory e = inventoryLogic.getEquipment(id);
        if (e.etype != EquipmentType.Sword) return;
        console.log("  sword id", id);
        console.log("    materials", uint8(e.materials), "rarity", uint8(e.rarity));
        console.log("    level", e.level, "attack", e.attack);
        console.log("    crit", e.crit, "critChance", e.critChance);
        console.log("    stunChance", e.stunChance);
    }

    function _logArmor(uint256 id) internal view {
        if (id == 0) return;
        Equipment memory e = inventoryLogic.getEquipment(id);
        if (e.etype != EquipmentType.Armor) return;
        console.log("  armor id", id);
        console.log("    materials", uint8(e.materials), "rarity", uint8(e.rarity));
        console.log("    level", e.level);
        console.log("    defense", e.defense);
    }

    function _logShield(uint256 id) internal view {
        if (id == 0) return;
        Equipment memory e = inventoryLogic.getEquipment(id);
        if (e.etype != EquipmentType.Shield) return;
        console.log("  shield id", id);
        console.log("    rarity", uint8(e.rarity), "level", e.level);
        console.log("    defense", e.defense);
        console.log("    blockChance", e.blockChance, "stunChance", e.stunChance);
    }
}
