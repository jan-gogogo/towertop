#!/usr/bin/env python3
"""
Tower Game Numerical Design - v7 (Token-Centric + Corrected Difficulty)
=========================================================================
Key redesign from v6:
- Enemy attack/defense scaled to create REAL difficulty gates
- Token economy redesigned with per-encounter budgets that hit targets

Token Spending Targets (cumulative):
  F1-15:    0 ATT   | F1-20: ~100 ATT
  F1-50: ~1000 ATT  | F1-70: ~2000 ATT
  F1-90: ~3000 ATT  | F1-100: ~4000 ATT

Difficulty Gates (L25 full set, 500 MC runs):
  F1-10:   WIN no gear
  F10-20:  WIN with potions (no gear viable)
  F20-30:  WIN with L5 C set
  F30-40:  WIN with L10 C set
  F40-50:  WIN with L20 C set
  F50-60:  WIN with L25 C set
  F60-70:  WIN with L25 B set
  F70-85:  WIN with L25 A set
  F85-100: WIN with L25 S set
"""

import csv
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

random.seed(42)


# ============================================================
# RARITY & EQUIPMENT  (matches Solidity Property.sol)
# ============================================================
RARITY_NAMES = ['C', 'B', 'A', 'S']


@dataclass
class Equipment:
    rarity: int
    level: int
    attack: int = 0
    defense: int = 0
    crit: int = 0
    critChance: int = 0
    blockChance: int = 0
    stunChance: int = 0


def make_equip(rarity: int, level: int, etype: str = 'sword') -> Equipment:
    """
    Sword:  attack = level + rarity*4, crit=r, critChance=7*r, stunChance=5*r
    Armor:  defense = level + rarity*4
    Shield: defense = (level+1)//2 + rarity*2, blockChance=7*r, stunChance=5*r
    (matches Property.calAttackForSword / calDefenseForArmor / calDefenseForShield)
    """
    if etype == 'sword':
        return Equipment(
            rarity=rarity, level=level,
            attack=level + rarity * 4,
            crit=rarity, critChance=7 * rarity, stunChance=5 * rarity
        )
    elif etype == 'armor':
        return Equipment(
            rarity=rarity, level=level,
            defense=level + rarity * 4
        )
    else:
        return Equipment(
            rarity=rarity, level=level,
            defense=(level + 1) // 2 + rarity * 2,
            blockChance=7 * rarity, stunChance=5 * rarity
        )


def make_set(rarity: int, level: int):
    return (
        make_equip(rarity, level, 'sword'),
        make_equip(rarity, level, 'armor'),
        make_equip(rarity, level, 'shield'),
    )


# ============================================================
# PLAYER  (matches Solidity Character.sol)
# ============================================================
@dataclass
class Player:
    level: int = 1
    healthMax: int = 100
    sword: Optional[Equipment] = None
    armor: Optional[Equipment] = None
    shield: Optional[Equipment] = None

    def total_attack(self) -> int:
        base = 10 + (self.level - 1) * 3
        return base + (self.sword.attack if self.sword else 0)

    def total_defense(self) -> int:
        base = 5 + (self.level - 1) * 2
        d = base
        if self.armor:  d += self.armor.defense
        if self.shield: d += self.shield.defense
        return d

    def total_crit(self) -> int:
        return self.sword.crit if self.sword else 0

    def total_critChance(self) -> int:
        c = 0
        if self.sword:  c += self.sword.critChance
        if self.shield: c += self.shield.stunChance
        return c

    def total_blockChance(self) -> int:
        return self.shield.blockChance if self.shield else 0

    def total_stunChance(self) -> int:
        s = 0
        if self.sword:  s += self.sword.stunChance
        if self.shield: s += self.shield.stunChance
        return s


# ============================================================
# ENEMIES  (REDESIGNED for correct difficulty gates)
# Key insight: boss damage per fight = boss_atk * 4 hits
# Player HP must >= boss_damage to survive
# Player damage per fight = player_atk * 4 hits
# Player wins when: player_dmg >= boss_HP
# ============================================================
@dataclass
class Enemy:
    level: int
    health: int
    attack: int
    defense: int
    crit: int
    critChance: int
    blockChance: int
    stunChance: int


def mob_stats(floor: int) -> Enemy:
    """
    Mob (fi = floor-1):
      HP = 12 + fi * 8
      ATK = 3 + fi  (fi<20),  fi*2  (fi>=20)  [more aggressive scaling]
      DEF = 5 + fi  (fi<20),  fi*1.5 (fi>=20) [scaling defense]
      crit/critChance/blockChance/stunChance as in v5 design doc
    """
    fi = floor - 1
    health = 12 + fi * 8
    if fi < 20:
        attack = 3 + fi
    else:
        attack = fi * 2
    defense = 5 + fi if fi < 20 else int(fi * 1.5)

    if fi < 30:
        crit = 0
    elif fi < 60:
        crit = 1
    else:
        crit = 2

    critChance = 0
    if fi >= 15:
        critChance = min(15, (fi - 15) // 2)

    blockChance = 0
    if fi >= 20:
        blockChance = min(12, (fi - 20) // 3)

    stunChance = 0
    if fi >= 40:
        stunChance = min(8, (fi - 40) // 5)

    return Enemy(floor, health, attack, defense, crit, critChance, blockChance, stunChance)


def boss_stats(floor: int) -> Enemy:
    """
    Boss (REDESIGNED):
      HP = 40 + fi * 30  [scaled up for later floors]
      ATK = 20 + fi * 3  [linear scaling, ~140 at F50, ~320 at F100]
      DEF = 4 + fi  [moderate scaling]
      crit/critChance/blockChance/stunChance per v5 design doc
    """
    fi = floor - 1
    health = 40 + fi * 30
    attack = 20 + fi * 3
    defense = 4 + fi

    if fi < 25:
        crit = 1
    elif fi < 60:
        crit = 2
    else:
        crit = 3

    critChance = min(20, 5 + fi // 5)
    blockChance = min(15, 5 + fi // 6)
    stunChance = 0
    if fi >= 20:
        stunChance = min(10, (fi - 20) // 5)

    return Enemy(floor, health, attack, defense, crit, critChance, blockChance, stunChance)


# ============================================================
# BATTLE  (matches Solidity Battle.sol)
# ============================================================
def calc_damage(attack, defense, crit, critChance, blockChance,
                roll1, roll2, elemental=False):
    # New formula: damage = Math.mulDiv(attack, 100, 100 + defense)
    # Solidity Math.mulDiv = floor(attack * 100 / (100 + defense)), min 1
    damage = (attack * 100) // (100 + defense)
    if damage == 0:
        damage = 1
    if elemental and damage > 1:
        damage = (damage * 110) // 100
    if crit > 0 and roll1 < (critChance * 256) // 100:
        damage += damage * crit
    if damage > 1 and roll2 < (blockChance * 256) // 100:
        damage //= 2
    return damage


def avg_dmg(atk, defense, crit, critChance, blockChance) -> float:
    # New formula: raw = floor(atk * 100 / (100 + defense)), min 1
    raw = (atk * 100) // (100 + defense)
    if raw == 0:
        raw = 1
    crit_hit = (critChance * 256) // 100
    after_crit = raw + raw * crit * crit_hit / 256.0
    block_hit = (blockChance * 256) // 100
    avg = after_crit * (256 - block_hit) / 256.0 + (raw // 2) * block_hit / 256.0
    return max(0.5, avg)


def battle_wr_mc(player: Player, enemy: Enemy, n: int = 500) -> float:
    """Monte Carlo battle with full stun mechanics."""
    wins = 0
    for _ in range(n):
        eh, ph = enemy.health, player.healthMax
        player_turn = True
        for _ in range(300):
            if player_turn:
                roll1 = random.randint(0, 255)
                roll2 = random.randint(0, 255)
                damage = calc_damage(
                    player.total_attack(), enemy.defense,
                    player.total_crit(), player.total_critChance(),
                    enemy.blockChance, roll1, roll2, False
                )
                eh -= damage
                if eh <= 0:
                    wins += 1
                    break
                # enemy stun check (player can stun enemy)
                if player.total_critChance() == 0 or roll1 >= (player.total_critChance() * 256) // 100:
                    roll3 = random.randint(0, 255)
                    if roll3 < (enemy.stunChance * 256) // 100:
                        continue  # enemy stunned, player attacks again
            else:
                roll1 = random.randint(0, 255)
                roll2 = random.randint(0, 255)
                damage = calc_damage(
                    enemy.attack, player.total_defense(),
                    enemy.crit, enemy.critChance,
                    player.total_blockChance(), roll1, roll2, False
                )
                ph -= damage
                if ph <= 0:
                    break
                # player stun check (enemy can stun player)
                if enemy.critChance == 0 or roll1 >= (enemy.critChance * 256) // 100:
                    roll3 = random.randint(0, 255)
                    if roll3 < (player.total_stunChance() * 256) // 100:
                        player_turn = False
                        continue
            player_turn = not player_turn
    return wins / n


# ============================================================
# TOKEN ECONOMY (ATT — redesigned to hit spending targets)
# ============================================================
#
# Per-encounter budget design:
#   F1-15:   0 per encounter
#   F16-20:  ~5 per encounter  (100 / 20 encounters = 5)
#   F21-50:  ~10 per encounter (900 / 90 encounters = 10)
#   F51-70:  ~10 per encounter (1000 / 100 encounters = 10)
#   F71-90:  ~10 per encounter (1000 / 100 encounters = 10)
#   F91-100: ~20 per encounter (1000 / 50 encounters = 20)
#
# Per-encounter breakdown (heals + upgrades + boss_entry):
#   F16-20:  3 heal + 2 upgrade + 0 boss = 5
#   F21-50:  3 heal + 7 upgrade + 0 boss = 10
#   F51-70:  4 heal + 5 upgrade + 1 boss = 10
#   F71-90:  5 heal + 4 upgrade + 1 boss = 10
#   F91-100: 8 heal + 9 upgrade + 3 boss = 20
#
# Upgrade costs (per piece per level):
#   C: ceil(L * 0.5)   → 1,3,5,7,9,... (avg ~6.5 for L6-25)
#   B: ceil(L * 1.5)   → 2,5,8,11,...  (avg ~19.5 for L1-25)
#   A: ceil(L * 2.0)   → 2,4,8,10,...  (avg ~26 for L1-25)
#   S: ceil(L * 3.0)   → 3,6,9,12,...  (avg ~39 for L1-25)
# ============================================================

def upgrade_cost(level: int, rarity: int) -> int:
    """Cost per piece per level, scaled by rarity."""
    multipliers = {0: 0.5, 1: 1.5, 2: 2.0, 3: 3.0}
    m = multipliers[rarity]
    return max(1, int(level * m + 0.5))


def merge_cost(from_rarity: int) -> int:
    """
    Reduced merge costs to balance token economy:
    C->B: 100, B->A: 200, A->S: 300
    (vs original 200/600/1000)
    """
    return {0: 100, 1: 200, 2: 300}[from_rarity]


def heal_cost(floor: int) -> int:
    """Full heal cost. F1-15: 0, F16+: ceil((fi-14) * 0.4)."""
    fi = floor - 1
    if fi < 15:
        return 0
    return max(1, int((fi - 14) * 0.4 + 0.5))


def boss_entry_cost(floor: int) -> int:
    """Boss entry fee. F1-20: 0, F21+: ceil((fi-19) * 1.5)."""
    fi = floor - 1
    if fi < 20:
        return 0
    return max(1, int((fi - 19) * 1.5 + 0.5))


def rebirth_cost() -> int:
    return 500


def mob_reward(floor: int) -> float:
    """ATT per mob kill. F1: 0.5, scales with floor."""
    return 0.5 + (floor - 1) * 0.3


def boss_reward(floor: int) -> float:
    """ATT per boss kill. F5: 16, F20: 38.5, F50: 83.5, F100: 158.5."""
    return 10 + (floor - 1) * 1.5


def floor_bonus(floor: int) -> float:
    """ATT bonus per floor completion."""
    fi = floor - 1
    if fi < 20:    return 1.0
    elif fi < 50: return 2.0
    elif fi < 70: return 3.0
    elif fi < 90: return 4.0
    else:         return 5.0


# ============================================================
# TOKEN SPENDING (analytical, with realistic encounter counts)
# ============================================================
def seg_of(floor: int) -> str:
    if floor <= 15:      return '1-15'
    elif floor <= 20:   return '15-20'
    elif floor <= 50:   return '20-50'
    elif floor <= 70:   return '50-70'
    elif floor <= 90:   return '70-90'
    else:               return '90-100'


def count_encounters(start: int, end: int) -> tuple:
    """Return (floor_count, boss_count) for a floor range."""
    floors = end - start + 1
    bosses = sum(1 for f in range(start, end + 1) if f % 5 == 0)
    return floors, bosses


def analytical_spending():
    """
    Compute token spending analytically.

    Per-range spending targets (the budget for each floor range):
      F1-15:      0 tokens
      F15-20:  100 tokens (spending within floors 16-20)
      F20-50: 1000 tokens
      F50-70: 1000 tokens
      F70-90: 1000 tokens
      F90-100: 1000 tokens
      Total:   4100 tokens (over budget by 2.5%)

    Spending breakdown per range:
      - Heal: per-floor formula
      - Upgrades: spread over the FULL upgrade period (not just the target range)
      - Boss entry: per-boss floor formula (varies by floor)
      - Fixed: merges + rebirth

    Key insight: upgrade costs are spread proportionally across the FULL upgrade range,
    not just the target floor range. For example, B-gear upgrades (3 pieces, L1→L25)
    cost 2925 tokens over floors 51-65 (15 floors), giving ~195 tokens/floor.
    But F51-70 only has 20 floors budgeted for 1000 tokens → upgrades must be
    reduced OR spreads over more floors.
    """
    BOSS_ENTRY = 20  # base fee per boss floor (scales with floor via boss_entry_cost)

    # Heal costs per floor (cumulative sum)
    def heal_budget_range(start: int, end: int) -> float:
        return sum(heal_cost(f) for f in range(start, end + 1))

    # Boss entry costs per range
    def boss_budget_range(start: int, end: int) -> float:
        return sum(boss_entry_cost(f) for f in range(start, end + 1) if f % 5 == 0)

    # Upgrade costs per range (spread proportionally over FULL upgrade period)
    upgrade_schedule = [
        # (start_f, end_f, rarity, total_cost_for_3_pieces)
        (16, 20,  0, sum(upgrade_cost(l, 0) for l in range(1, 6)) * 3),
        (21, 40,  0, sum(upgrade_cost(l, 0) for l in range(6, 21)) * 3),
        (41, 50,  0, sum(upgrade_cost(l, 0) for l in range(21, 26)) * 3),
        (51, 65,  1, sum(upgrade_cost(l, 1) for l in range(1, 26)) * 3),
        (66, 82,  2, sum(upgrade_cost(l, 2) for l in range(1, 26)) * 3),
        (89, 95,  3, sum(upgrade_cost(l, 3) for l in range(1, 26)) * 3),
    ]

    segs = ['1-15', '15-20', '20-50', '50-70', '70-90', '90-100']
    segs_floors = {
        '1-15':    (1, 15),
        '15-20':   (16, 20),
        '20-50':   (21, 50),
        '50-70':   (51, 70),
        '70-90':   (71, 90),
        '90-100':  (91, 100),
    }

    # Upgrade costs SPREAD PROPORTIONALLY over each floor range
    upgrade_per_seg = {s: 0.0 for s in segs}
    for start_f, end_f, rarity, total_cost in upgrade_schedule:
        upg_per_floor = total_cost / (end_f - start_f + 1)
        for f in range(start_f, end_f + 1):
            seg = seg_of(f)
            upgrade_per_seg[seg] += upg_per_floor

    # Compute per-segment heal, boss entry, floors, bosses
    breakdown = {}
    for seg in segs:
        s, e = segs_floors[seg]
        floors, bosses = count_encounters(s, e)
        heal = heal_budget_range(s, e)
        boss_fees = boss_budget_range(s, e)
        fixed = 0
        if seg == '20-50':  fixed += merge_cost(0)   # C->B
        if seg == '50-70':  fixed += merge_cost(1)   # B->A
        if seg == '70-90':  fixed += merge_cost(2)   # A->S
        if seg == '90-100': fixed += rebirth_cost()    # Rebirth
        breakdown[seg] = {
            'floors': floors, 'bosses': bosses,
            'heal': heal, 'boss_entry': boss_fees,
            'fixed': fixed, 'upgrade': upgrade_per_seg[seg],
        }
        breakdown[seg]['total'] = (
            heal + upgrade_per_seg[seg] + boss_fees + fixed
        )

    # Per-range targets
    targets = {
        '1-15':      0,
        '15-20':   100,
        '20-50':  1000,
        '50-70':  1000,
        '70-90':  1000,
        '90-100': 1000,
    }

    # Cumulative targets
    order = ['1-15', '15-20', '20-50', '50-70', '70-90', '90-100']
    cum_targets = {}
    rt = 0
    for s in order:
        rt += targets[s]
        cum_targets[s] = rt

    # Seg spending = actual
    seg_spending = {s: breakdown[s]['total'] for s in segs}

    # Cumulative actual
    cum_actual = {}
    running = 0.0
    for s in order:
        running += seg_spending[s]
        cum_actual[s] = running

    return seg_spending, cum_actual, targets, cum_targets, breakdown


def compute_income():
    """Total ATT income from floors 1-100."""
    total = 0.0
    for f in range(1, 101):
        is_boss = (f % 5 == 0)
        # 3 mobs per floor (regardless of boss floor)
        for _ in range(3):
            total += mob_reward(f)
        if is_boss:
            total += boss_reward(f)
        total += floor_bonus(f)
    return total


# ============================================================
# PRINT FUNCTIONS
# ============================================================
def print_tables():
    print("=" * 70)
    print("DETAILED NUMERICAL TABLES (Token-Centric v7)")
    print("=" * 70)

    print("\n--- Player Level Progression ---")
    print("HP: 100+(level-1)*20  ATK: 10+(level-1)*3  DEF: 5+(level-1)*2")
    print(f"{'Lvl':>4} {'Floor':>6} {'HP':>7} {'ATK':>6} {'DEF':>6}")
    print("-" * 35)
    for floor in [1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
        lvl = min(floor, 100)
        print(f"L{lvl:>3} F{floor:<5} {100+(lvl-1)*20:>7} {10+(lvl-1)*3:>6} {5+(lvl-1)*2:>6}")

    print("\n--- Sword/Armor (attack/defense = level + rarity*4) ---")
    print(f"{'Lvl':>4} {'C':>5} {'B':>5} {'A':>5} {'S':>5}")
    print("-" * 28)
    for l in [1, 5, 10, 15, 20, 25]:
        print(f"{l:>4} {l:>5} {l+4:>5} {l+8:>5} {l+12:>5}")

    print("\n--- Shield (def=(level+1)//2 + rarity*2) ---")
    print(f"{'Lvl':>4} {'C':>5} {'B':>5} {'A':>5} {'S':>5}")
    print("-" * 28)
    for l in [1, 5, 10, 15, 20, 25]:
        print(f"{l:>4} {(l+1)//2:>5} {(l+1)//2+2:>5} {(l+1)//2+4:>5} {(l+1)//2+6:>5}")

    print("\n--- Rarity Secondary Attributes ---")
    print(f"{'Rarity':>7} {'Crit':>6} {'Crit%':>7} {'Block%':>8} {'Stun%':>7}")
    print("-" * 40)
    for r, n in enumerate(RARITY_NAMES):
        print(f"{n:>7} {r:>6} {7*r:>7} {7*r:>8} {5*r:>7}")

    print("\n--- Mob Stats by Floor ---")
    print(f"{'Floor':>6} {'HP':>7} {'ATK':>6} {'DEF':>6} {'CRIT':>6} {'CRIT%':>7} {'BLOCK%':>8} {'STUN%':>7}")
    print("-" * 65)
    for f in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100]:
        m = mob_stats(f)
        print(f"F{f:<5} {m.health:>7} {m.attack:>6} {m.defense:>6} "
              f"{m.crit:>6} {m.critChance:>7} {m.blockChance:>8} {m.stunChance:>7}")

    print("\n--- Boss Stats by Floor ---")
    print(f"{'Floor':>6} {'HP':>7} {'ATK':>6} {'DEF':>6} {'CRIT':>6} {'CRIT%':>7} {'BLOCK%':>8} {'STUN%':>7}")
    print("-" * 65)
    for f in [5, 10, 15, 20, 25, 30, 40, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]:
        b = boss_stats(f)
        print(f"F{f:<5} {b.health:>7} {b.attack:>6} {b.defense:>6} "
              f"{b.crit:>6} {b.critChance:>7} {b.blockChance:>8} {b.stunChance:>7}")

    print("\n--- Token Costs (key floors) ---")
    print(f"{'Floor':>6} {'Heal':>6} {'BossEntry':>11} {'C-Upg':>8} {'B-Upg':>8} {'A-Upg':>8} {'S-Upg':>8}")
    print("-" * 70)
    for f in [15, 20, 25, 30, 40, 50, 55, 60, 65, 70, 80, 85, 88, 90, 95, 100]:
        print(f"F{f:<5} {heal_cost(f):>6} {boss_entry_cost(f):>11} "
              f"{upgrade_cost(f//5+1, 0):>8} {upgrade_cost(f//5+1, 1):>8} "
              f"{upgrade_cost(f//5+1, 2):>8} {upgrade_cost(f//5+1, 3):>8}")

    print("\n--- Token Rewards (key floors) ---")
    print(f"{'Floor':>6} {'Mob':>8} {'Boss':>10} {'Bonus':>8}")
    print("-" * 35)
    for f in [1, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
        print(f"F{f:<5} {mob_reward(f):>8.1f} {boss_reward(f):>10.1f} {floor_bonus(f):>8.1f}")


def verify_difficulty():
    print("\n" + "=" * 70)
    print("BATTLE DIFFICULTY TABLE (Monte Carlo, 500 runs)")
    print("=" * 70)

    configs = [
        ("No gear",    0, 0, 0, 0, 0, 0),
        ("L1 C set",  0, 1, 0, 1, 0, 1),
        ("L5 C set",  0, 5, 0, 5, 0, 5),
        ("L10 C set", 0, 10, 0, 10, 0, 10),
        ("L20 C set", 0, 20, 0, 20, 0, 20),
        ("L25 C set", 0, 25, 0, 25, 0, 25),
        ("L25 B set", 1, 25, 1, 25, 1, 25),
        ("L25 A set", 2, 25, 2, 25, 2, 25),
        ("L25 S set", 3, 25, 3, 25, 3, 25),
    ]

    test_floors = sorted(set(list(range(1, 101, 5)) +
                             [5, 10, 15, 20, 25, 30, 35, 40, 45, 50,
                              55, 60, 65, 70, 75, 80, 85, 90, 95, 100]))

    # matrix[i][j] = win% for configs[i] at test_floors[j]
    matrix: list[list[int]] = []
    for name, sr, sl, ar, al, shr, shl in configs:
        row_pcts: list[int] = []
        for floor in test_floors:
            lvl = min(floor, 100)
            p_hp = 100 + (lvl - 1) * 20
            p = Player(level=lvl, healthMax=p_hp)
            p.sword = make_equip(sr, sl) if sl > 0 else None
            p.armor = make_equip(ar, al) if al > 0 else None
            p.shield = make_equip(shr, shl) if shl > 0 else None
            e = boss_stats(floor) if floor % 5 == 0 else mob_stats(floor)
            wr = battle_wr_mc(p, e, 500)
            row_pcts.append(int(wr * 100))
        matrix.append(row_pcts)

    cfg_names = [c[0] for c in configs]
    pct_w = 5  # "100%"
    col_w = max(pct_w + 1, max(len(n) for n in cfg_names))

    # Transposed: one row per floor (narrow, fits typical terminals)
    sep = " | "
    floor_hdr = f"{'Floor':>5}"
    hdr = floor_hdr + sep + sep.join(f"{n:^{col_w}}" for n in cfg_names)
    print(hdr)
    print("-" * len(hdr))

    for j, floor in enumerate(test_floors):
        cells = [f"{matrix[i][j]:>{pct_w}}%" for i in range(len(configs))]
        print(f"F{floor:>4}" + sep + sep.join(f"{c:^{col_w}}" for c in cells))

    csv_path = Path(__file__).resolve().parent / "numerical_v7_difficulty.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as fp:
        w = csv.writer(fp)
        w.writerow(["Floor", *cfg_names])
        for j, floor in enumerate(test_floors):
            w.writerow([floor] + [matrix[i][j] for i in range(len(configs))])
    print(f"\n(Same data as CSV: {csv_path})")

    print("\nTargets:")
    print("  F1-10:   WIN with no gear")
    print("  F10-20:  WIN with L1 C set or potions")
    print("  F20-30:  WIN with L5 C set")
    print("  F30-40:  WIN with L10 C set")
    print("  F40-50:  WIN with L20 C set")
    print("  F50-60:  WIN with L25 C set")
    print("  F60-70:  WIN with L25 B set")
    print("  F70-85:  WIN with L25 A set")
    print("  F85-100: WIN with L25 S set")


def main():
    print("\n" + "=" * 70)
    print(" TOWER GAME NUMERICAL DESIGN v7 (Token-Centric + Corrected Difficulty)")
    print("=" * 70)
    print("Token (ATT) initial value: $0.01 USDT\n")

    print_tables()
    verify_difficulty()

    seg_spending, cum_actual, targets, cum_targets, breakdown = analytical_spending()

    print("\n" + "=" * 70)
    print("TOKEN SPENDING ANALYSIS")
    print("=" * 70)

    order = ['1-15', '15-20', '20-50', '50-70', '70-90', '90-100']

    print(f"\n{'Range':<10} {'Flr':>4} {'Boss':>5} {'Heal':>7} {'Upgrades':>9} {'BossFee':>8} {'Fixed':>7} {'Actual':>8} {'PerRng':>8} {'Diff':>8} {'OK?':>5}")
    print("-" * 110)
    all_ok = True
    for s in order:
        b = breakdown[s]
        actual = b['heal'] + b['upgrade'] + b['boss_entry'] + b['fixed']
        per_range_diff = actual - targets[s]
        cum_diff = cum_actual[s] - cum_targets[s]
        pct = abs(per_range_diff) / max(targets[s], 1) * 100 if targets[s] > 0 else 0
        ok = pct < 15
        if not ok: all_ok = False
        print(f"{s:<10} {b['floors']:>4} {b['bosses']:>5} {b['heal']:>7.0f} {b['upgrade']:>9.0f} "
              f"{b['boss_entry']:>8.0f} {b['fixed']:>7.0f} {actual:>8.0f} "
              f"{targets[s]:>8.0f} {per_range_diff:>+8.0f} {'OK' if ok else 'ADJ':>5}")

    total_actual = sum(breakdown[s]['heal'] + breakdown[s]['upgrade'] +
                       breakdown[s]['boss_entry'] + breakdown[s]['fixed'] for s in order)
    print(f"\n{'TOTAL':<10} {'':>4} {'':>5} "
          f"{sum(breakdown[s]['heal'] for s in order):>7.0f} "
          f"{sum(breakdown[s]['upgrade'] for s in order):>9.0f} "
          f"{sum(breakdown[s]['boss_entry'] for s in order):>8.0f} "
          f"{sum(breakdown[s]['fixed'] for s in order):>7.0f} "
          f"{total_actual:>8.0f}")

    income = compute_income()
    total_spending = sum(breakdown[s]['heal'] + breakdown[s]['upgrade'] +
                         breakdown[s]['boss_entry'] + breakdown[s]['fixed'] for s in order)
    print(f"\nTotal income (floors 1-100):  {income:.0f} ATT")
    print(f"Total spending:               {total_spending:.0f} ATT")
    print(f"Balance (income - spending): {income - total_spending:.0f} ATT")
    print(f"All segments within 15% of targets: {'YES' if all_ok else 'NO'}")

    print("\n--- Spending Breakdown by Range ---")
    print(f"{'Range':<10} {'Actual':>10} {'Per/floor':>10} {'Upgr/floor':>11} {'Heal/floor':>11} {'BossFee':>9}")
    print("-" * 65)
    for s in order:
        b = breakdown[s]
        floors = max(b['floors'], 1)
        actual = b['heal'] + b['upgrade'] + b['boss_entry'] + b['fixed']
        print(f"{s:<10} {actual:>10.0f} "
              f"{actual/floors:>10.1f} "
              f"{b['upgrade']/floors:>11.1f} "
              f"{b['heal']/floors:>11.1f} "
              f"{b['boss_entry']/floors:>9.1f}")

    print("\n--- Upgrade/Merge/Rebirth Schedule ---")
    schedule = [
        (16, 20,  "C-gear L1->L5 (3 pieces)",     sum(upgrade_cost(l, 0) for l in range(1, 6)) * 3),
        (21, 40,  "C-gear L5->L20 (3 pieces)",    sum(upgrade_cost(l, 0) for l in range(6, 21)) * 3),
        (41, 50,  "C-gear L20->L25 (3 pieces)",   sum(upgrade_cost(l, 0) for l in range(21, 26)) * 3),
        (50, 50,  "C->B merge (200 ATT)",          merge_cost(0)),
        (51, 65,  "B-gear L1->L25 (3 pieces)",    sum(upgrade_cost(l, 1) for l in range(1, 26)) * 3),
        (65, 65,  "B->A merge (600 ATT)",          merge_cost(1)),
        (66, 82,  "A-gear L1->L25 (3 pieces)",    sum(upgrade_cost(l, 2) for l in range(1, 26)) * 3),
        (88, 88,  "A->S forge (1000 ATT)",        merge_cost(2)),
        (89, 95,  "S-gear L1->L25 (3 pieces)",    sum(upgrade_cost(l, 3) for l in range(1, 26)) * 3),
        (100, 100,"Rebirth (500 ATT)",             rebirth_cost()),
    ]
    print(f"{'Floors':<12} {'Description':<40} {'Cost':>10}")
    print("-" * 65)
    for s, e, desc, cost in schedule:
        print(f"F{s:>3}-F{e:<3}   {desc:<40} {cost:>10.0f}")
    print(f"\n{'TOTAL':>55} {sum(c for _, _, _, c in schedule):>10.0f} ATT")

    print("\n" + "=" * 70)
    print("DESIGN SUMMARY")
    print("=" * 70)
    print("""
PLAYER PROGRESSION:
  level        = min(floor, 100)
  healthMax   = 100 + (level-1) * 20
  baseAttack  = 10 + (level-1) * 3
  baseDefense = 5 + (level-1) * 2
  expToNextLevel = 5 * (level + 1)

ENEMY FORMULAS (Mob, fi=floor-1):
  HP     = 12 + fi*8
  ATK    = 3+fi (fi<20), fi*2 (fi>=20)
  DEF    = 5+fi (fi<20), int(fi*1.5) (fi>=20)
  CRIT   = 0 (fi<30), 1 (30<=fi<60), 2 (fi>=60)
  CRIT%  = min(15, 0 if fi<15 else (fi-15)//2)
  BLOCK% = min(12, 0 if fi<20 else (fi-20)//3)
  STUN%  = min(8, 0 if fi<40 else (fi-40)//5)

ENEMY FORMULAS (Boss, fi=floor-1):
  HP     = 40 + fi*30
  ATK    = 20 + fi*3
  DEF    = 4 + fi
  CRIT   = 1 (fi<25), 2 (25<=fi<60), 3 (fi>=60)
  CRIT%  = min(20, 5+fi//5)
  BLOCK% = min(15, 5+fi//6)
  STUN%  = min(10, 0 if fi<20 else (fi-20)//5)

TOKEN SINKS (ATT):
  upgrade_cost(L,r) = ceil(L * {0:0.5, 1:1.5, 2:2.0, 3:3.0}[r])  per piece per level
  merge_cost:  C->B=200, B->A=600, A->S=1000  ATT
  heal_cost(f) = 0 (f<=15), ceil((fi-14)*0.4) (f>15)
  boss_entry(f)= 0 (f<=20), ceil((fi-19)*1.5) (f>20)
  rebirth = 500 ATT at F100

TOKEN SOURCES (ATT per floor, 3 mobs + 1 boss on boss floors):
  mob_reward(f)   = 0.5 + fi*0.3  per mob kill
  boss_reward(f)  = 10 + fi*1.5   per boss kill
  floor_bonus(f)  = 1/2/3/4/5 per floor completion

TOKEN SPENDING TARGETS (cumulative):
  F15:     0 ATT
  F20:  ~100 ATT
  F50:  ~1000 ATT
  F70:  ~2000 ATT
  F90:  ~3000 ATT
  F100: ~4000 ATT

DIFFICULTY GATES (L25 full set):
  F1-50:   C-rarity (WIN, comfortable)
  F60-70:  B-rarity (WIN, tight)
  F70-85:  A-rarity (WIN, tight)
  F85-100: S-rarity (WIN, tight)
""")


if __name__ == "__main__":
    main()
