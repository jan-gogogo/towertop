#!/usr/bin/env python3
"""
Tower Game Numerical Design - Analytical Simulation v5
=====================================================
All calculations are analytical (no simulation bugs).

Key design:
- Equipment drops are FREE (player gets gear from drops)
- Token spending: healing + boss entry + equipment upgrade + rarity merge
- Player level = 1 + (floor-1) * 0.5 (reaches L51 at F100)

Targets:
  Token consumption (cumulative):
    F1-15:   0 token
    F1-20: ~100 token
    F1-50: ~1000 token
    F1-70: ~2000 token
    F1-91: ~3000 token
    F1-100:~4000 token

  Difficulty gates (L25 full set):
    F1-50:   C-rarity sufficient (WIN)
    F55-75:  B-rarity needed (WIN, tight)
    F75-85:  A-rarity needed (WIN, tight)
    F85+:    S-rarity needed (WIN, tight)
"""

import random
from dataclasses import dataclass
from typing import Optional

random.seed(42)


# ============================================================
# EQUIPMENT
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


def make_equip(rarity: int, level: int, is_shield: bool = False) -> Equipment:
    if is_shield:
        d = (level + 1) // 2 + rarity * 2
        return Equipment(rarity=rarity, level=level, defense=d,
                        blockChance=7*rarity, stunChance=5*rarity)
    else:
        a = level + rarity * 2
        d = level + rarity * 2
        return Equipment(rarity=rarity, level=level, attack=a, defense=d,
                        crit=rarity, critChance=7*rarity, stunChance=5*rarity)


def make_set(rarity: int, level: int):
    return (make_equip(rarity, level, False),
            make_equip(rarity, level, False),
            make_equip(rarity, level, True))


# ============================================================
# PLAYER
# ============================================================

@dataclass
class Player:
    level: int = 1
    healthMax: int = 100
    sword: Optional[Equipment] = None
    armor: Optional[Equipment] = None
    shield: Optional[Equipment] = None

    def total_attack(self) -> int:
        return 5 + self.level * 2 + (self.sword.attack if self.sword else 0)

    def total_defense(self) -> int:
        d = self.level
        if self.armor:  d += self.armor.defense
        if self.shield: d += self.shield.defense
        return d

    def total_crit(self) -> int:
        return self.sword.crit if self.sword else 0

    def total_critChance(self) -> int:
        c = 0
        if self.sword: c += self.sword.critChance
        if self.shield: c += self.shield.stunChance
        return c

    def total_blockChance(self) -> int:
        return self.shield.blockChance if self.shield else 0


# ============================================================
# ENEMY
# ============================================================

@dataclass
class Enemy:
    health: int
    attack: int
    defense: int
    crit: int
    critChance: int
    blockChance: int
    stunChance: int


def mob_stats(floor: int) -> Enemy:
    fi = floor - 1
    hp = 10 + fi * 6
    atk = (2 + fi) if fi < 20 else (fi * 2 - 18)
    defense = 1 + fi
    return Enemy(hp, atk, defense, crit=0,
                 critChance=max(0, (fi-15)//3),
                 blockChance=max(0, (fi-20)//4),
                 stunChance=min(10, max(0, (fi-40)//8)))


def boss_stats(floor: int) -> Enemy:
    fi = floor - 1
    hp = 40 + fi * 10
    atk = (5 + fi) if fi < 20 else (fi * 2 - 15)
    defense = 2 + fi
    crit = 1 if fi < 25 else (2 if fi < 60 else 3)
    return Enemy(hp, atk, defense, crit=crit,
                 critChance=min(20, 3 + fi//4),
                 blockChance=min(15, 2 + fi//5),
                 stunChance=min(12, max(0, (fi-40)//8)))


# ============================================================
# BATTLE
# ============================================================

def avg_dmg(atk: int, defense: int, crit: int, critChance: int,
            defender_block: int) -> float:
    raw = max(1, atk - defense)
    crit_hit = (critChance * 256) // 100
    after_crit = raw + raw * crit * crit_hit / 256.0
    block_hit = (defender_block * 256) // 100
    avg = after_crit * (256 - block_hit) / 256.0 + (raw // 2) * block_hit / 256.0
    return max(0.5, avg)


def battle_wr(player: Player, enemy: Enemy, n: int = 500) -> float:
    p_dmg = avg_dmg(player.total_attack(), enemy.defense,
                     player.total_crit(), player.total_critChance(),
                     enemy.blockChance)
    e_dmg = avg_dmg(enemy.attack, player.total_defense(),
                     enemy.crit, enemy.critChance,
                     player.total_blockChance())
    wins = 0
    for _ in range(n):
        eh, ph = enemy.health, player.healthMax
        for _ in range(300):
            eh -= p_dmg
            if eh <= 0:
                wins += 1
                break
            ph -= e_dmg
            if ph <= 0:
                break
    return wins / n


# ============================================================
# TOKEN ECONOMY FORMULAS
# ============================================================

def heal_cost(floor: int) -> int:
    fi = floor - 1
    return 0 if fi < 15 else int(0.5 * fi)


def boss_entry_cost(floor: int) -> int:
    fi = floor - 1
    return 0 if fi < 20 else int(2.5 * (fi - 20))


def upgrade_cost(level: int) -> int:
    return max(1, level * 2)


def merge_cost(from_r: int) -> int:
    return {0: 200, 1: 600, 2: 800}[from_r]


def mob_reward(floor: int) -> int:
    return 5 + (floor - 1) // 2


def boss_reward(floor: int) -> int:
    return 20 + (floor - 1) * 2


def floor_bonus(floor: int) -> int:
    fi = floor - 1
    if fi < 20:   return 10
    elif fi < 50: return 20
    elif fi < 70: return 30
    else:         return 40


def seg_of(floor: int) -> str:
    if floor <= 15:   return '1-15'
    elif floor <= 20: return '15-20'
    elif floor <= 50: return '20-50'
    elif floor <= 70: return '50-70'
    else:             return '70-100'


# ============================================================
# ANALYTICAL TOKEN SPENDING
# ============================================================

def analytical_spending():
    """
    Compute token spending analytically with a concrete upgrade/merge plan.
    """
    # Fixed costs per floor range
    def fixed_cost(start: int, end: int) -> int:
        return sum(heal_cost(f) + boss_entry_cost(f) for f in range(start, end + 1))

    fixed = {
        '1-15':   fixed_cost(1, 15),
        '15-20':  fixed_cost(16, 20),
        '20-50':  fixed_cost(21, 50),
        '50-70':  fixed_cost(51, 70),
        '70-100': fixed_cost(71, 100),
    }

    # Upgrade/merge plan: each item is (start_f, end_f, rarity, level, cost)
    # cost = total token cost for this upgrade over the period
    upgrade_items = [
        # (start, end, rarity, level, description, total_cost)
        # C-gear upgrades
        (16, 20, 0, 5,  "C-gear L1->L5",   sum(upgrade_cost(l) for l in range(1, 6)) * 3),
        (21, 40, 0, 20, "C-gear L5->L20",  sum(upgrade_cost(l) for l in range(6, 21)) * 3),
        (41, 50, 0, 25, "C-gear L20->L25", sum(upgrade_cost(l) for l in range(21, 26)) * 3),
        # Merge C->B at floor 50
        (50, 50, 1, 25, "C->B merge", merge_cost(0)),
        # B-gear upgrades
        (51, 65, 1, 25, "B-gear L1->L25", sum(upgrade_cost(l) for l in range(1, 26)) * 3),
        # Merge B->A at floor 65
        (65, 65, 2, 25, "B->A merge", merge_cost(1)),
        # A-gear upgrades
        (66, 82, 2, 25, "A-gear L1->L25", sum(upgrade_cost(l) for l in range(1, 26)) * 3),
        # Merge A->S at floor 88
        (88, 88, 3, 25, "A->S merge", merge_cost(2)),
        # S-gear upgrades
        (89, 95, 3, 25, "S-gear L1->L25", sum(upgrade_cost(l) for l in range(1, 26)) * 3),
    ]

    seg_spending = {'1-15': 0, '15-20': 0, '20-50': 0, '50-70': 0, '70-100': 0}

    # Add fixed costs
    for s, c in fixed.items():
        seg_spending[s] += c

    # Add upgrade costs (proportional over the period)
    for start_f, end_f, rarity, target_lvl, desc, total_cost in upgrade_items:
        num_floors = end_f - start_f + 1
        cost_per_floor = total_cost / num_floors
        for f in range(start_f, end_f + 1):
            s = seg_of(f)
            seg_spending[s] += cost_per_floor

    # Cumulative
    order = ['1-15', '15-20', '20-50', '50-70', '70-100']
    cum = {}
    running = 0
    for s in order:
        running += seg_spending[s]
        cum[s] = running

    return seg_spending, cum, fixed


# ============================================================
# TOKEN INCOME
# ============================================================

def compute_income():
    """Compute total token income from floors 1-100."""
    total = 0
    for f in range(1, 101):
        is_boss = (f % 5 == 0)
        ec = 1 if is_boss else (3 if random.random() < 0.5 else 4)
        total += ec * mob_reward(f)
        if is_boss:
            total += boss_reward(f)
        total += floor_bonus(f)
    return total


# ============================================================
# PRINT FUNCTIONS
# ============================================================

def print_tables():
    print("=" * 70)
    print("DETAILED NUMERICAL TABLES")
    print("=" * 70)

    print("\n--- Player Level Progression ---")
    print("level = 1 + (floor-1) * 0.5,  healthMax = 100 + (level-1)*20")
    print(f"{'Lvl':>5} {'Floor':>6} {'HP':>7} {'ATK':>6} {'DEF':>6}")
    print("-" * 35)
    for lvl in [1, 5, 10, 20, 30, 40, 50]:
        f = (lvl - 1) * 2 + 1
        print(f"{lvl:>5} F{f:<5} {100+(lvl-1)*20:>7} {5+lvl*2:>6} {lvl:>6}")

    print("\n--- Sword/Armor (attack = level + rarity*2) ---")
    print(f"{'Lvl':>4} {'C':>5} {'B':>5} {'A':>5} {'S':>5}")
    print("-" * 28)
    for l in [1, 5, 10, 15, 20, 25]:
        print(f"{l:>4} {l:>5} {l+2:>5} {l+4:>5} {l+6:>5}")

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
        print(f"F{f:<5} {m.health:>7} {m.attack:>6} {m.defense:>6} {m.crit:>6} "
              f"{m.critChance:>7} {m.blockChance:>8} {m.stunChance:>7}")

    print("\n--- Boss Stats by Floor ---")
    print(f"{'Floor':>6} {'HP':>7} {'ATK':>6} {'DEF':>6} {'CRIT':>6} {'CRIT%':>7} {'BLOCK%':>8} {'STUN%':>7}")
    print("-" * 65)
    for f in [5, 10, 15, 20, 25, 30, 40, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]:
        b = boss_stats(f)
        print(f"F{f:<5} {b.health:>7} {b.attack:>6} {b.defense:>6} {b.crit:>6} "
              f"{b.critChance:>7} {b.blockChance:>8} {b.stunChance:>7}")

    print("\n--- Token Costs (key floors) ---")
    print(f"{'Floor':>6} {'Heal':>6} {'BossEntry':>11} {'Upg/lvl':>9} {'C->B':>7} {'B->A':>7} {'A->S':>7}")
    print("-" * 65)
    for f in [15, 20, 30, 40, 50, 55, 60, 65, 70, 80, 85, 88, 90, 95, 100]:
        print(f"F{f:<5} {heal_cost(f):>6} {boss_entry_cost(f):>11} "
              f"{upgrade_cost(f//5+1):>9} {merge_cost(0):>7} {merge_cost(1):>7} {merge_cost(2):>7}")

    print("\n--- Token Rewards (key floors) ---")
    print(f"{'Floor':>6} {'Mob':>6} {'Boss':>7} {'FloorBonus':>12}")
    print("-" * 35)
    for f in [1, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
        print(f"F{f:<5} {mob_reward(f):>6} {boss_reward(f):>7} {floor_bonus(f):>12}")

    print("\n--- Win Rate vs Boss (500 runs, L25 gear) ---")
    print(f"{'Floor':>6} {'BossHP':>8} {'BossATK':>9} "
          f"{'C-WR':>7} {'B-WR':>7} {'A-WR':>7} {'S-WR':>7} {'Min':>6}")
    print("-" * 75)
    for f in [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]:
        fi = f - 1
        plvl = 1 + fi // 2
        boss = boss_stats(f)
        p_hp = 100 + (plvl - 1) * 20
        min_r = '?'
        for r in [0, 1, 2, 3]:
            s, a, sh = make_set(r, 25)
            p = Player(level=plvl, healthMax=p_hp, sword=s, armor=a, shield=sh)
            wr = battle_wr(p, boss, 500)
            if wr >= 0.5 and min_r == '?':
                min_r = RARITY_NAMES[r]
        p0 = Player(level=plvl, healthMax=p_hp, sword=make_equip(0,25), armor=make_equip(0,25), shield=make_equip(0,25,True))
        p1 = Player(level=plvl, healthMax=p_hp, sword=make_equip(1,25), armor=make_equip(1,25), shield=make_equip(1,25,True))
        p2 = Player(level=plvl, healthMax=p_hp, sword=make_equip(2,25), armor=make_equip(2,25), shield=make_equip(2,25,True))
        p3 = Player(level=plvl, healthMax=p_hp, sword=make_equip(3,25), armor=make_equip(3,25), shield=make_equip(3,25,True))
        print(f"F{f:<5} {boss.health:>8.0f} {boss.attack:>9.0f} "
              f"{battle_wr(p0,boss,500):>7.0%} {battle_wr(p1,boss,500):>7.0%} "
              f"{battle_wr(p2,boss,500):>7.0%} {battle_wr(p3,boss,500):>7.0%} {min_r:>6}")


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

    test_floors = sorted(set(
        list(range(1, 101, 5)) +
        [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]
    ))

    header = f"{'Config':<12}"
    for f in test_floors:
        header += f"F{f:>3}".rjust(6)
    print(header)
    print("-" * (12 + 6 * len(test_floors)))

    for name, sr, sl, ar, al, shr, shl in configs:
        row = f"{name:<12}"
        for floor in test_floors:
            fi = floor - 1
            plvl = 1 + fi // 2
            p_hp = 100 + (plvl - 1) * 20
            p = Player(level=plvl, healthMax=p_hp)
            p.sword = make_equip(sr, sl) if sl > 0 else None
            p.armor = make_equip(ar, al) if al > 0 else None
            p.shield = make_equip(shr, shl, True) if shl > 0 else None
            e = boss_stats(floor) if floor % 5 == 0 else mob_stats(floor)
            wr = battle_wr(p, e, 500)
            sym = "WIN" if wr >= 0.9 else ("win" if wr >= 0.5 else ("lose" if wr >= 0.1 else "---"))
            row += f"{sym:>6}"
        print(row)

    print("\nTargets:")
    print("  F1-10:   WIN with no gear")
    print("  F10-20:  WIN with potions (no gear also viable)")
    print("  F20-30:  WIN with L1 C sword")
    print("  F30-40:  WIN with L10 C full set")
    print("  F40-50:  WIN with L20 C full set")
    print("  F50-60:  WIN with L25 C full set")
    print("  F60-75:  WIN with L25 B full set")
    print("  F75-85:  WIN with L25 A full set")
    print("  F85+:    WIN with L25 S full set")


def main():
    print("\n" + "=" * 70)
    print(" TOWER GAME NUMERICAL DESIGN v5 (Analytical)")
    print("=" * 70)
    print("Token (ATT) initial value: $0.01 USDT\n")

    print_tables()
    verify_difficulty()

    seg_spending, cum_spending, fixed = analytical_spending()

    print("\n" + "=" * 70)
    print("TOKEN SPENDING ANALYSIS")
    print("=" * 70)

    order = ['1-15', '15-20', '20-50', '50-70', '70-100']
    targets = {'1-15': 0, '15-20': 100, '20-50': 1000, '50-70': 2000, '70-100': 4000}
    cum_targets = {}
    rt = 0
    for s in order:
        rt += targets[s]
        cum_targets[s] = rt

    print(f"\n{'Range':<10} {'Fixed':>8} {'Upgrade':>10} {'Total':>10} {'Cum':>10} {'Target':>10} {'Diff':>9} {'%':>7} {'OK?':>5}")
    print("-" * 90)
    running = 0
    running_target = 0
    all_ok = True
    for s in order:
        upgrade = seg_spending[s] - fixed[s]
        running += seg_spending[s]
        running_target = cum_targets[s]
        diff = running - running_target
        pct = abs(diff) / max(running_target, 1) * 100 if running_target > 0 else 0
        ok = pct < 15
        if not ok: all_ok = False
        print(f"{s:<10} {fixed[s]:>8.0f} {upgrade:>10.0f} {seg_spending[s]:>10.0f} "
              f"{running:>10.0f} {running_target:>10.0f} {diff:>+9.0f} {pct:>6.1f}% {'OK' if ok else 'ADJ':>5}")

    print(f"\n{'Total':<10} {sum(fixed.values()):>8.0f} "
          f"{sum(seg_spending[s]-fixed[s] for s in order):>10.0f} "
          f"{running:>10.0f}  (target: 4000)")

    income = compute_income()
    print(f"\nTotal income (floors 1-100):  {income:.0f} tokens")
    print(f"Total spending:               {running:.0f} tokens")
    print(f"Balance (should be > 0):     {income - running:.0f} tokens")
    print(f"\nAll segments within 15% of targets: {'YES' if all_ok else 'NO'}")

    print("\n--- Upgrade/Merge Schedule ---")
    schedule = [
        (16, 20, "C-gear L1->L5 (3 pieces)"),
        (21, 40, "C-gear L5->L20 (3 pieces)"),
        (41, 50, "C-gear L20->L25 (3 pieces)"),
        (50, 50, "C->B merge (cost 200 tokens)"),
        (51, 65, "B-gear L1->L25 (3 pieces)"),
        (65, 65, "B->A merge (cost 600 tokens)"),
        (66, 82, "A-gear L1->L25 (3 pieces)"),
        (88, 88, "A->S merge (cost 800 tokens)"),
        (89, 95, "S-gear L1->L25 (3 pieces)"),
        (95, 100,"S-gear L25 full set, endgame"),
    ]
    print(f"{'Floors':<12} {'Description':<40}")
    print("-" * 55)
    for s, e, desc in schedule:
        print(f"F{s:>3}-F{e:<3}   {desc:<40}")

    print("\n" + "=" * 70)
    print("DESIGN SUMMARY")
    print("=" * 70)
    print("""
PLAYER PROGRESSION:
  level      = 1 + (floor-1) * 0.5
  healthMax  = 100 + (level-1) * 20
  attack     = 5 + level * 2
  defense    = level

ENEMY FORMULAS (Mob, fi=floor-1):
  HP     = 10 + fi*6
  ATK    = 2+fi (fi<20), fi*2-18 (fi>=20)
  DEF    = 1 + fi
  CRIT%  = max(0, (fi-15)//3)
  BLOCK% = max(0, (fi-20)//4)
  STUN%  = min(10, max(0, (fi-40)//8))

ENEMY FORMULAS (Boss, fi=floor-1):
  HP     = 40 + fi*10
  ATK    = 5+fi (fi<20), fi*2-15 (fi>=20)
  DEF    = 2 + fi
  CRIT   = 1 (fi<25), 2 (25<=fi<60), 3 (fi>=60)
  CRIT%  = min(20, 3+fi//4)
  BLOCK% = min(15, 2+fi//5)
  STUN%  = min(12, max(0, (fi-40)//8))

TOKEN SINKS:
  heal_cost(f)       = 0 (f<=15), int(0.5*(f-1)) (f>15)
  boss_entry_cost(f) = 0 (f<=20), int(2.5*(f-20)) (f>20)
  upgrade_cost(lvl)  = max(1, lvl*2) per piece per level
  merge_cost         = C->B:200, B->A:600, A->S:800

TOKEN SOURCES (per floor):
  mob_reward(f)    = 5 + (f-1)//2
  boss_reward(f)   = 20 + (f-1)*2
  floor_bonus(f)   = 10 (f<20), 20 (f<50), 30 (f<70), 40 (f>=70)

TOKEN SPENDING TARGETS (cumulative):
  F15:   0 token
  F20: ~100 token
  F50: ~1000 token
  F70: ~2000 token
  F91: ~3000 token
  F100: ~4000 token

DIFFICULTY GATES (L25 full set):
  F1-50:   C-rarity (WIN, comfortable margin)
  F55-75:  B-rarity (WIN, tight margin)
  F75-85:  A-rarity (WIN, tight margin)
  F85+:    S-rarity (WIN, tight margin)
""")


if __name__ == "__main__":
    main()
