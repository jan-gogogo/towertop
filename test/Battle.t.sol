// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Battle} from "../src/libraries/Battle.sol";
import {AbilitiesExtra} from "../src/libraries/Character.sol";
import {Aoka, AokaType, AokaTrait} from "../src/libraries/Enemy.sol";
import {EquipmentMaterials, EquipmentType, Property} from "../src/libraries/Property.sol";
import {Rarity} from "../src/libraries/Attribute.sol";

contract BattleTest is Test {
    using Battle for bytes32;

    function _basicAoka(uint16 health, uint16 attack, uint16 defense) internal pure returns (Aoka memory) {
        return Aoka({
            typ: AokaType.Slime,
            trait: AokaTrait.Electric,
            level: 1,
            health: health,
            attack: attack,
            defense: defense,
            crit: 0,
            critChance: 0,
            blockChance: 0,
            stunChance: 0,
            isBoss: false
        });
    }

    function _basicAbilities() internal pure returns (AbilitiesExtra memory) {
        return AbilitiesExtra({
            attack: 0,
            defense: 0,
            crit: 0,
            critChance: 0,
            stunChance: 0,
            blockChance: 0,
            weaponMaterialsIdx: 0,
            armorEquipped: false,
            armorMaterialsIdx: 0
        });
    }

    function test_combat_playerWins_whenHigherAttackNoRng() public pure {
        bytes32 seed = bytes32(uint256(0x1234));
        AbilitiesExtra memory ae = _basicAbilities();

        // Player is stronger than enemy, no crit/block/stun
        uint256 playerHealth = 100;
        uint256 playerAttack = 20;
        uint256 playerDefense = 5;

        Aoka memory enemy = _basicAoka(50, 10, 3);

        (uint256 pHealthFinal, uint256 aHealthFinal) =
            Battle.combat(seed, playerHealth, playerAttack, playerDefense, enemy, ae);

        assertGt(pHealthFinal, 0, "player should survive");
        assertEq(aHealthFinal, 0, "enemy should die");
    }

    function test_combat_enemyWins_whenHigherAttackNoRng() public pure {
        bytes32 seed = bytes32(uint256(0x5678));
        AbilitiesExtra memory ae = _basicAbilities();

        // Enemy is much stronger than player
        uint256 playerHealth = 50;
        uint256 playerAttack = 5;
        uint256 playerDefense = 2;

        Aoka memory enemy = _basicAoka(200, 30, 5);

        (uint256 pHealthFinal, uint256 aHealthFinal) =
            Battle.combat(seed, playerHealth, playerAttack, playerDefense, enemy, ae);

        assertEq(pHealthFinal, 0, "player should die");
        assertGt(aHealthFinal, 0, "enemy should survive");
    }

    function test_combat_playerStunsEnemy_whenStunChanceAlways() public pure {
        // roll3 is compared with (stunChance * 256) / 100; when stunChance = 100,
        // every successful attack will stun and skip the next attacker action.
        bytes32 seed = bytes32(uint256(0x9999));

        AbilitiesExtra memory ae = _basicAbilities();
        ae.stunChance = 100;

        uint256 playerHealth = 100;
        uint256 playerAttack = 10;
        uint256 playerDefense = 5;

        // Enemy could kill the player in a few hits if allowed to act,
        // but permanent stuns should prevent enemy from acting at all.
        Aoka memory enemy = _basicAoka(30, 50, 0);

        (uint256 pHealthFinal, uint256 aHealthFinal) =
            Battle.combat(seed, playerHealth, playerAttack, playerDefense, enemy, ae);

        assertEq(pHealthFinal, playerHealth, "enemy should never hit due to 100% stun");
        assertEq(aHealthFinal, 0, "enemy should eventually die");
    }

    function test_combat_elementalAdvantage_affectsDamage() public pure {
        bytes32 seed = bytes32(uint256(0xABCD));

        // Player weapon material index == enemy trait index => player has elemental advantage
        AbilitiesExtra memory ae = _basicAbilities();
        ae.weaponMaterialsIdx = 1; // Iron

        // Enemy trait = Earth (1); give it enough HP so that advantage
        // kills within 32 rounds but no-advantage does not.
        Aoka memory enemy = _basicAoka(350, 0, 10);
        enemy.trait = AokaTrait.Earth;

        uint256 playerHealth = 100;
        uint256 playerAttack = 20; // base damage = 20 - 10 = 10, adv damage ≈ 11
        uint256 playerDefense = 0;

        (uint256 pHealthFinalAdv, uint256 aHealthFinalAdv) =
            Battle.combat(seed, playerHealth, playerAttack, playerDefense, enemy, ae);

        // Compare with a run that has no advantage.
        AbilitiesExtra memory aeNoAdv = _basicAbilities();
        aeNoAdv.weaponMaterialsIdx = 0; // does not match Earth trait

        Aoka memory enemyNoAdv = enemy;
        (uint256 pHealthFinalNoAdv, uint256 aHealthFinalNoAdv) =
            Battle.combat(seed, playerHealth, playerAttack, playerDefense, enemyNoAdv, aeNoAdv);

        assertEq(pHealthFinalAdv, pHealthFinalNoAdv, "player should not take damage in either case");
        assertLt(aHealthFinalAdv, aHealthFinalNoAdv, "enemy HP should be lower with elemental advantage");
    }

    function test_rewardItemsAppendEquipmentAndCoins_shapes() public pure {
        bytes32 seed = bytes32(uint256(0xCAFEBABE));
        uint256 floorIndex = 10;
        uint256 equipmentId = 123;

        (uint256[] memory assetIds, uint256[] memory values) =
            Battle.rewardItemsAppendEquipmentAndCoins(seed, floorIndex, equipmentId);

        // 1 or 2 items + 1 equipment + 1 coin
        assertTrue(assetIds.length >= 3 && assetIds.length <= 4, "assetIds length");
        assertEq(assetIds.length, values.length, "values same length");

        uint256 count = assetIds.length - 2;
        // Equipment slot
        assertEq(assetIds[count], equipmentId, "equipment id in expected slot");
        assertEq(values[count], 1, "equipment amount is 1");

        // Coin slot
        assertEq(assetIds[count + 1], Property.COIN_ID, "coin id");
        // Non-zero coin amount
        assertGt(values[count + 1], 0, "coin value > 0");
    }

    function test_calRewardExperience_matchesFormula() public pure {
        // Non-boss floor
        uint8 enemyLevel = 10;
        uint256 floorIndex = 7;
        uint256 exp1 = Battle.calRewardExperience(enemyLevel, floorIndex);
        assertEq(exp1, uint256(2 * enemyLevel + floorIndex + 1));

        // Boss floor: (idx + 1) % 5 == 0 -> floorIndex = 4
        enemyLevel = 5;
        floorIndex = 4;
        uint32 exp2 = Battle.calRewardExperience(enemyLevel, floorIndex);
        assertEq(exp2, uint32(10 * enemyLevel + 5 * (floorIndex + 1)));
    }

    function test_equipmentDetermine_thresholds() public pure {
        // Non-boss, floorIndex = 0 -> init = 5 -> threshold ~= 12
        uint256 floorIndex = 0;
        assertTrue(Battle.equipmentDetermine(0, floorIndex), "0 should be below threshold");
        assertFalse(Battle.equipmentDetermine(100, floorIndex), "100 should be above threshold");

        // Boss floor: floorIndex = 4 (5th floor)
        floorIndex = 4;
        // init = segment * 2 + 25, segment = 0 => 25 -> threshold ~= 64
        assertTrue(Battle.equipmentDetermine(10, floorIndex), "10 should be below boss threshold");
        assertFalse(Battle.equipmentDetermine(200, floorIndex), "200 should be above boss threshold");
    }

    function test_rewardEquipment_usesPropertyHelpers() public pure {
        uint256 floorIndex = 10;
        // forge-fmt: off
        bytes32 seed = bytes32(0x0000000000000000000000000000000000000000000000000000000000302010);
        // forge-fmt: on

        (uint8 level, Rarity rarity, EquipmentMaterials materials, EquipmentType typ) =
            Battle.rewardEquipment(seed, floorIndex);

        // level is derived from floor index via Property.calEquipmentLevel
        assertEq(level, Property.calEquipmentLevel(floorIndex), "level from floor");

        // rarity and materials are derived from specific seed bytes
        Rarity expectedRarity = Property.calRarity(uint8(seed[1]), floorIndex);
        EquipmentMaterials expectedMaterials = Property.calEquipmentMaterials(uint8(seed[2]));

        assertEq(uint8(rarity), uint8(expectedRarity), "rarity from seed");
        assertEq(uint8(materials), uint8(expectedMaterials), "materials from seed");

        // type is in range [0,2] (Sword/Armor/Shield)
        assertTrue(uint8(typ) <= 2, "equipment type range");
    }
}

