#!/usr/bin/env python3
"""
Tower Game Numerical Design - v6 (Token-Centric Redesign)
==========================================================
All calculations are analytical (no simulation bugs).

Key changes from v5:
- Gold (ERC1155 Coin) is REPLACED by Token (ERC20 ATT)
- Born: mint 1000 ATT (at $0.01 = $10 initial value)
- All game costs (upgrade/merge/heal/boss entry/rebirth) burn ATT
- Token rewards for combat replace coin rewards
- ATT value: $0.01 USDT per token

Token Spending Targets (cumulative):
  F1-15:    0 ATT
  F1-20: ~100 ATT
  F1-50: ~1000 ATT
  F1-70: ~2000 ATT
  F1-90: ~3000 ATT
  F1-100: ~4000 ATT

Difficulty Gates (L25 full set, WR >= 50%):
  F1-10:   No gear WIN
  F10-20:  L1 C set WIN (or potions)
  F20-30:  L5 C set WIN
  F30-40:  L10 C set WIN
  F40-50:  L20 C set WIN
  F50-60:  L25 C set WIN
  F60-70:  L25 B set WIN
  F70-85:  L25 A set WIN
  F85-100: L25 S set WIN
"""

import random
from dataclasses import dataclass
from typing import Optional

random.seed(42)


# ============================================================
# RARITY & EQUIPMENT
# ============================================================

RARITY_NAMES = ['C', 'B', 'A', 'S']
# Rarity index: C=0, B=1, A=2, S=3


@dataclass
class Equipment:
    rarity: int      # 0-3
    level: int       # 1-25
    attack: int = 0  # sword
    defense: int = 0 # armor + shield
    crit: int = 0    # sword
    critChance: int = 0  # sword
    blockChance: int = 0 # shield
    stunChance: int = 0  # sword + shield


def make_equip(rarity: int, level: int, etype: str = 'sword') -> Equipment:
    """
    Sword:  attack = level + rarity*2, crit=r, critChance=7*r, stunChance=5*r
    Armor:  defense = level + rarity*2
    Shield: defense = (level+1)//2 + rarity*2, blockChance=7*r, stunChance=5*r
    """
    if etype == 'sword':
        return Equipment(
            rarity=rarity, level=level,
            attack=level + rarity * 2,
            crit=rarity, critChance=7 * rarity, stunChance=5 * rarity
        )
    elif etype == 'armor':
        return Equipment(
            rarity=rarity, level=level,
            defense=level + rarity * 2
        )
    else:  # shield
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
# PLAYER (matches Solidity Character.sol)
# ============================================================

@dataclass
class Player:
    level: int = 1
    experience: int = 0
    healthMax: int = 100
    health: int = 100
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
        if self.sword:   c += self.sword.critChance
        if self.shield:  c += self.shield.stunChance
        return c

    def total_blockChance(self) -> int:
        return self.shield.blockChance if self.shield else 0

    def total_stunChance(self) -> int:
        s = 0
        if self.sword:  s += self.sword.stunChance
        if self.shield: s += self.shield.stunChance
        return s


def exp_to_next_level(level: int) -> int:
    """expToNextLevel = 5 * (currentLevel + 1)"""
    return 5 * (level + 1)


def gain_experience(player: Player, exp: int) -> int:
    """Add experience and level up. Returns total levels gained."""
    player.experience += exp
    levels_gained = 0
    while player.experience >= exp_to_next_level(player.level) and player.level < 100:
        player.experience -= exp_to_next_level(player.level)
        player.level += 1
        player.healthMax += 20
        levels_gained += 1
    return levels_gained


# ============================================================
# ENEMIES (matches Solidity Enemy.sol)
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
    floor: 1-indexed
    Mob:
      health = 12 + fi * 8
      attack = 3+fi (fi<20), fi*2 (fi>=20)
      defense = 2 + fi/3
      crit = 0 (fi<30), 1 (30<=fi<60), 2 (fi>=60)
      critChance = min(15, 0 if fi<15 else (fi-15)//2)
      blockChance = min(12, 0 if fi<20 else (fi-20)//3)
      stunChance = min(8, 0 if fi<40 else (fi-40)//5)
    """
    fi = floor - 1
    health = 12 + fi * 8
    if fi < 20:
        attack = 3 + fi
    else:
        attack = fi * 2

    defense = 2 + fi // 3

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
    floor: 1-indexed, must be divisible by 5
    Boss:
      health = 40 + fi * 20
      attack = 7+fi (fi<20), 30+fi*3 (fi>=20)
      defense = 4 + fi/2
      crit = 1 (fi<25), 2 (25<=fi<60), 3 (fi>=60)
      critChance = min(20, 5 + fi//5)
      blockChance = min(15, 5 + fi//6)
      stunChance = min(10, 0 if fi<20 else (fi-20)//5)
    """
    fi = floor - 1
    health = 40 + fi * 20
    if fi < 20:
        attack = 7 + fi
    else:
        attack = 30 + fi * 3

    defense = 4 + fi // 2

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
# BATTLE (matches Solidity Battle.sol)
# ============================================================

def calc_damage(attack, defense, crit, critChance, blockChance,
                roll1, roll2, elemental=False):
    """
    Matches Battle._calculateDamage in Solidity:
    - damage = max(1, attack - defense)
    - elemental: damage *= 110/100
    - crit: damage += damage * crit  (if roll1 < critChance*256/100)
    - block: damage /= 2  (if roll2 < blockChance*256/100)
    Returns damage (int).
    """
    damage = max(1, attack - defense)
    if elemental and damage > 1:
        damage = (damage * 110) // 100
    if crit > 0 and roll1 < (critChance * 256) // 100:
        damage += damage * crit
    if damage > 1 and roll2 < (blockChance * 256) // 100:
        damage //= 2
    return damage


def avg_dmg(atk, defense, crit, critChance, blockChance) -> float:
    """
    Analytical average damage (deterministic, no simulation needed).
    """
    raw = max(1, atk - defense)
    crit_hit = (critChance * 256) // 100
    after_crit = raw + raw * crit * crit_hit / 256.0
    block_hit = (blockChance * 256) // 100
    avg = after_crit * (256 - block_hit) / 256.0 + (raw // 2) * block_hit / 256.0
    return max(0.5, avg)


def battle_wr(player: Player, enemy: Enemy, n: int = 500) -> float:
    """
    Monte Carlo win rate: player attacks first.
    Returns fraction of wins [0, 1].
    """
    p_dmg = avg_dmg(player.total_attack(), enemy.defense,
                    player.total_crit(), player.total_critChance(),
                    enemy.blockChance)
    e_dmg = avg_dmg(enemy.attack, player.total_defense(),
                    enemy.crit, enemy.critChance,
                    player.total_blockChance())

    wins = 0
    for _ in range(n):
        eh, ph = enemy.health, player.healthMax
        stun_active = False
        for _ in range(300):
            if stun_active:
                stun_active = False
            else:
                eh -= p_dmg
                if eh <= 0:
                    wins += 1
                    break
                # enemy turn
                ph -= e_dmg
                if ph <= 0:
                    break
            # Check stun (enemy's stunChance against player)
            # In solidity: stun checked on attacker side
            # Player attacks: enemy may be stunned (enemy.stunChance)
            # Enemy attacks: player may be stunned (player.stunChance)
            # stun only if no crit: crit and stun are checked sequentially
            # stunChance checked after damage is dealt
            # Simplified: stun happens with probability stunChance/100
            # For avg_dmg approach, we approximate stun effect
        # The stun effect: if enemy is stunned, player gets extra attack
        # For WR calculation with avg_dmg: extra attack = p_dmg * (e_stunChance/100)
        # But this makes the formula non-linear. Use Monte Carlo for accuracy.
    return wins / n


def battle_wr_mc(player: Player, enemy: Enemy, n: int = 1000) -> float:
    """
    Full Monte Carlo battle with stun mechanics.
    """
    wins = 0
    for _ in range(n):
        eh, ph = enemy.health, player.healthMax
        player_turn = True  # player goes first
        for _ in range(300):
            if player_turn:
                # Player attacks
                roll1 = random.randint(0, 255)
                roll2 = random.randint(0, 255)
                damage = calc_damage(player.total_attack(), enemy.defense,
                                     player.total_crit(), player.total_critChance(),
                                     enemy.blockChance, roll1, roll2, False)
                eh -= damage
                if eh <= 0:
                    wins += 1
                    break
                # Check stun on enemy (no crit on this turn for stun to apply)
                if player.total_crit() == 0 or roll1 >= (player.total_critChance() * 256) // 100:
                    roll3 = random.randint(0, 255)
                    if roll3 < (enemy.stunChance * 256) // 100:
                        player_turn = True  # enemy stunned, player goes again
                        continue
            else:
                # Enemy attacks
                roll1 = random.randint(0, 255)
                roll2 = random.randint(0, 255)
                damage = calc_damage(enemy.attack, player.total_defense(),
                                     enemy.crit, enemy.critChance,
                                     player.total_blockChance(), roll1, roll2, False)
                ph -= damage
                if ph <= 0:
                    break
                # Check stun on player
                if enemy.crit == 0 or roll1 >= (enemy.critChance * 256) // 100:
                    roll3 = random.randint(0, 255)
                    if roll3 < (player.total_stunChance() * 256) // 100:
                        player_turn = False  # player stunned, enemy goes again
                        continue
            player_turn = not player_turn
    return wins / n


# ============================================================
# TOKEN ECONOMY FORMULAS (NEW - ATT based)
# ============================================================

def upgrade_cost(level: int, rarity: int) -> int:
    """
    Cost per piece per level, scaled by rarity.
    Formula: ceil(level * (0.5 + rarity * 0.4))
    F17: 1*0.9=0.9->1; L10 C: 5; L10 B: 9; L10 A: 13; L10 S: 17
    """
    return max(1, int(level * (0.5 + rarity * 0.4) + 0.5))


def merge_cost(from_rarity: int) -> int:
    """
    C->B: 200, B->A: 600, A->S: 1000
    """
    return [200, 600, 1000][from_rarity]


def heal_cost(floor: int) -> int:
    """
    Full heal cost in ATT.
    F1-15: 0 (free)
    F16+: ceil((fi-14) * 0.4)
    """
    fi = floor - 1
    if fi < 15:
        return 0
    return max(1, int((fi - 14) * 0.4 + 0.5))


def boss_entry_cost(floor: int) -> int:
    """
    Boss entry fee in ATT.
    F1-20: 0 (free)
    F21+: ceil((fi-19) * 1.5)
    """
    fi = floor - 1
    if fi < 20:
        return 0
    return max(1, int((fi - 19) * 1.5 + 0.5))


def rebirth_cost() -> int:
    """Rebirth at F100 costs 500 ATT."""
    return 500


# ============================================================
# TOKEN REWARDS
# ============================================================

def mob_token_reward(floor: int) -> float:
    """
    ATT earned per mob kill.
    Formula: 0.5 + fi * 0.3 + bonus
    F1: 0.8, F10: 3.5, F20: 6.5, F50: 15.5, F100: 30.5
    """
    fi = floor - 1
    return 0.5 + fi * 0.3


def boss_token_reward(floor: int) -> float:
    """
    ATT earned per boss kill (on top of mob reward for that floor).
    Formula: 10 + fi * 1.5
    F5: 16, F20: 38.5, F50: 85, F100: 158.5
    """
    fi = floor - 1
    return 10 + fi * 1.5


def floor_bonus(floor: int) -> float:
    """
    ATT bonus per floor completion (regardless of encounter result).
    F1-20: 1, F21-50: 2, F51-70: 3, F71-90: 4, F91-100: 5
    """
    fi = floor - 1
    if fi < 20:    return 1.0
    elif fi < 50: return 2.0
    elif fi < 70: return 3.0
    elif fi < 90: return 4.0
    else:         return 5.0


# ============================================================
# ANALYTICAL TOKEN SPENDING (upgrade + heal + boss + rebirth)
# ============================================================

def seg_of(floor: int) -> str:
    if floor <= 15:      return '1-15'
    elif floor <= 20:    return '15-20'
    elif floor <= 50:    return '20-50'
    elif floor <= 70:    return '50-70'
    elif floor <= 90:    return '70-90'
    else:                return '90-100'


def analytical_spending():
    """
    Compute analytical token spending with upgrade plan:
    - F16-20: C gear upgrade L1->L5 (3 pieces)
    - F21-40: C gear upgrade L5->L20 (3 pieces)
    - F41-50: C gear upgrade L20->L25 (3 pieces)
    - F50: C->B merge (200)
    - F51-65: B gear upgrade L1->L25 (3 pieces)
    - F65: B->A merge (600)
    - F66-82: A gear upgrade L1->L25 (3 pieces)
    - F88: A->S forge (1000)
    - F89-95: S gear upgrade L1->L25 (3 pieces)
    - F100: rebirth (500)
    """
    upgrade_schedule = [
        # (start, end, rarity, target_level, total_cost_for_3_pieces)
        (16, 20, 0, 5,  sum(upgrade_cost(l, 0) for l in range(1, 6)) * 3),
        (21, 40, 0, 20, sum(upgrade_cost(l, 0) for l in range(6, 21)) * 3),
        (41, 50, 0, 25, sum(upgrade_cost(l, 0) for l in range(21, 26)) * 3),
        # F51-65: B gear starts fresh at L1 (after merge, level resets to L1 or stays?)
        # In this design: merge result is L1 of new rarity (conservative)
        (51, 65, 1, 25, sum(upgrade_cost(l, 1) for l in range(1, 26)) * 3),
        (66, 82, 2, 25, sum(upgrade_cost(l, 2) for l in range(1, 26)) * 3),
        (89, 95, 3, 25, sum(upgrade_cost(l, 3) for l in range(1, 26)) * 3),
    ]

    segs = ['1-15', '15-20', '20-50', '50-70', '70-90', '90-100']
    seg_spending = {s: 0.0 for s in segs}

    # Fixed costs (heal + boss entry) per floor
    for f in range(1, 101):
        seg_spending[seg_of(f)] += heal_cost(f) + boss_entry_cost(f)

    # Upgrade costs spread over floor ranges
    for start_f, end_f, rarity, target_lvl, total_cost in upgrade_schedule:
        num_floors = end_f - start_f + 1
        cost_per_floor = total_cost / num_floors
        for f in range(start_f, end_f + 1):
            seg_spending[seg_of(f)] += cost_per_floor

    # Rebirth at F100
    seg_spending['90-100'] += rebirth_cost()

    # Cumulative
    order = ['1-15', '15-20', '20-50', '50-70', '70-90', '90-100']
    cum = {}
    running = 0.0
    for s in order:
        running += seg_spending[s]
        cum[s] = running

    return seg_spending, cum


def compute_analytical_income():
    """Compute total ATT income from floors 1-100."""
    total = 0.0
    for f in range(1, 101):
        is_boss = (f % 5 == 0)
        # Per floor: 3-4 mob encounters + 1 boss if boss floor
        mob_count = 4 if random.random() < 0.5 else 3
        for _ in range(mob_count):
            total += mob_token_reward(f)
        if is_boss:
            total += boss_token_reward(f)
        total += floor_bonus(f)
    return total


# ============================================================
# PRINT FUNCTIONS
# ============================================================

def print_tables():
    print("=" * 70)
    print("DETAILED NUMERICAL TABLES (Token-Centric v6)")
    print("=" * 70)

    # Player progression
    print("\n--- Player Level Progression ---")
    print("level: each floor +1, capped at 100")
    print("HP: 100 + (level-1)*20  |  ATK: 10 + (level-1)*3  |  DEF: 5 + (level-1)*2")
    print(f"{'Lvl':>4} {'Floor':>6} {'HP':>7} {'ATK':>6} {'DEF':>6}")
    print("-" * 35)
    for floor in [1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
        lvl = min(floor, 100)
        hp = 100 + (lvl - 1) * 20
        atk = 10 + (lvl - 1) * 3
        defense = 5 + (lvl - 1) * 2
        print(f"L{lvl:>3} F{floor:<5} {hp:>7} {atk:>6} {defense:>6}")

    # Equipment stats
    print("\n--- Sword/Armor (attack/defense = level + rarity*2) ---")
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

    # Enemy stats
    print("\n--- Mob Stats by Floor ---")
    print(f"{'Floor':>6} {'Lvl':>4} {'HP':>7} {'ATK':>6} {'DEF':>6} {'CRIT':>6} {'CRIT%':>7} {'BLOCK%':>8} {'STUN%':>7}")
    print("-" * 75)
    for f in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100]:
        m = mob_stats(f)
        print(f"F{f:<5} {m.level:>4} {m.health:>7} {m.attack:>6} {m.defense:>6} "
              f"{m.crit:>6} {m.critChance:>7} {m.blockChance:>8} {m.stunChance:>7}")

    print("\n--- Boss Stats by Floor ---")
    print(f"{'Floor':>6} {'Lvl':>4} {'HP':>7} {'ATK':>6} {'DEF':>6} {'CRIT':>6} {'CRIT%':>7} {'BLOCK%':>8} {'STUN%':>7}")
    print("-" * 75)
    for f in [5, 10, 15, 20, 25, 30, 40, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]:
        b = boss_stats(f)
        print(f"F{f:<5} {b.level:>4} {b.health:>7} {b.attack:>6} {b.defense:>6} "
              f"{b.crit:>6} {b.critChance:>7} {b.blockChance:>8} {b.stunChance:>7}")

    # Token costs
    print("\n--- Token Costs (key floors) ---")
    print(f"{'Floor':>6} {'Heal':>6} {'BossEntry':>11} {'Upg(L5C)':>10} {'Upg(L10B)':>10} {'MergeCtoB':>11} {'MergeAtoS':>11} {'Rebirth':>9}")
    print("-" * 100)
    for f in [15, 20, 25, 30, 40, 50, 55, 60, 65, 70, 80, 85, 88, 90, 95, 100]:
        print(f"F{f:<5} {heal_cost(f):>6} {boss_entry_cost(f):>11} "
              f"{upgrade_cost(5,0):>10} {upgrade_cost(10,1):>10} "
              f"{merge_cost(0):>11} {merge_cost(2):>11} {rebirth_cost():>9}")

    # Token rewards
    print("\n--- Token Rewards (key floors) ---")
    print(f"{'Floor':>6} {'Mob':>8} {'Boss':>10} {'FloorBonus':>13}")
    print("-" * 40)
    for f in [1, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
        print(f"F{f:<5} {mob_token_reward(f):>8.1f} {boss_token_reward(f):>10.1f} {floor_bonus(f):>13.1f}")


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

    # Test floors: boss floors + key floors
    test_floors = sorted(set(
        list(range(1, 101, 5)) +  # boss floors: 5, 10, 15, ...
        [1, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]
    ))

    header = f"{'Config':<12}"
    for f in test_floors:
        col = f"F{f:<5}"
        header += col
    print(header)
    print("-" * (12 + 5 * len(test_floors)))

    for name, sr, sl, ar, al, shr, shl in configs:
        row = f"{name:<12}"
        for floor in test_floors:
            lvl = min(floor, 100)
            p_hp = 100 + (lvl - 1) * 20
            p = Player(level=lvl, healthMax=p_hp)
            p.sword = make_equip(sr, sl) if sl > 0 else None
            p.armor = make_equip(ar, al) if al > 0 else None
            p.shield = make_equip(shr, shl) if shl > 0 else None
            e = boss_stats(floor) if floor % 5 == 0 else mob_stats(floor)
            wr = battle_wr_mc(p, e, 500)
            sym = "WIN" if wr >= 0.9 else ("WIN" if wr >= 0.5 else ("lose" if wr >= 0.1 else "---"))
            row += f"{sym:>5}"
        print(row)

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
    print(" TOWER GAME NUMERICAL DESIGN v6 (Token-Centric Redesign)")
    print("=" * 70)
    print("Token (ATT) initial value: $0.01 USDT\n")

    print_tables()
    verify_difficulty()

    # Token spending analysis
    seg_spending, cum_spending = analytical_spending()

    print("\n" + "=" * 70)
    print("TOKEN SPENDING ANALYSIS")
    print("=" * 70)

    order = ['1-15', '15-20', '20-50', '50-70', '70-90', '90-100']
    targets = {
        '1-15':    0,
        '15-20':  100,
        '20-50': 1000,
        '50-70': 2000,
        '70-90': 3000,
        '90-100': 4000,
    }
    cum_targets = {}
    rt = 0
    for s in order:
        rt += targets[s]
        cum_targets[s] = rt

    print(f"\n{'Range':<10} {'Spending':>10} {'Cum':>10} {'Target':>10} {'Diff':>9} {'%':>7} {'OK?':>5}")
    print("-" * 75)
    running = 0.0
    all_ok = True
    for s in order:
        running += seg_spending[s]
        diff = running - cum_targets[s]
        pct = abs(diff) / max(cum_targets[s], 1) * 100 if cum_targets[s] > 0 else 0
        ok = pct < 15
        if not ok: all_ok = False
        print(f"{s:<10} {seg_spending[s]:>10.0f} {running:>10.0f} "
              f"{cum_targets[s]:>10.0f} {diff:>+9.0f} {pct:>6.1f}% {'OK' if ok else 'ADJ':>5}")

    print(f"\n{'TOTAL':<10} {sum(seg_spending.values()):>10.0f}  (target: 4000)")

    # Token income analysis
    print("\n" + "=" * 70)
    print("TOKEN INCOME ANALYSIS")
    print("=" * 70)

    incomes = []
    for trial in range(5):
        income = compute_analytical_income()
        incomes.append(income)

    avg_income = sum(incomes) / len(incomes)
    total_spending = running

    print(f"\nAvg total income (floors 1-100, 5 trials):  {avg_income:.0f} ATT")
    print(f"Total spending:                            {total_spending:.0f} ATT")
    print(f"Balance (income - spending):               {avg_income - total_spending:.0f} ATT")

    print("\n--- Upgrade/Merge/Rebirth Schedule ---")
    schedule = [
        (16, 20,  "C-gear L1->L5 (3 pieces)",     sum(upgrade_cost(l, 0) for l in range(1, 6)) * 3),
        (21, 40,  "C-gear L5->L20 (3 pieces)",    sum(upgrade_cost(l, 0) for l in range(6, 21)) * 3),
        (41, 50,  "C-gear L20->L25 (3 pieces)",   sum(upgrade_cost(l, 0) for l in range(21, 26)) * 3),
        (50, 50,  "C->B merge (cost 200 ATT)",     merge_cost(0)),
        (51, 65,  "B-gear L1->L25 (3 pieces)",     sum(upgrade_cost(l, 1) for l in range(1, 26)) * 3),
        (65, 65,  "B->A merge (cost 600 ATT)",     merge_cost(1)),
        (66, 82,  "A-gear L1->L25 (3 pieces)",     sum(upgrade_cost(l, 2) for l in range(1, 26)) * 3),
        (88, 88,  "A->S forge (cost 1000 ATT)",    merge_cost(2)),
        (89, 95,  "S-gear L1->L25 (3 pieces)",     sum(upgrade_cost(l, 3) for l in range(1, 26)) * 3),
        (100, 100,"Rebirth (cost 500 ATT)",        rebirth_cost()),
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
  healthMax    = 100 + (level-1) * 20
  baseAttack   = 10 + (level-1) * 3
  baseDefense  = 5 + (level-1) * 2
  expToNextLevel = 5 * (level + 1)

ENEMY FORMULAS (Mob, fi=floor-1):
  HP     = 12 + fi*8
  ATK    = 3+fi (fi<20), fi*2 (fi>=20)
  DEF    = 2 + fi/3
  CRIT   = 0 (fi<30), 1 (30<=fi<60), 2 (fi>=60)
  CRIT%  = min(15, 0 if fi<15 else (fi-15)//2)
  BLOCK% = min(12, 0 if fi<20 else (fi-20)//3)
  STUN%  = min(8, 0 if fi<40 else (fi-40)//5)

ENEMY FORMULAS (Boss, fi=floor-1):
  HP     = 40 + fi*20
  ATK    = 7+fi (fi<20), 30+fi*3 (fi>=20)
  DEF    = 4 + fi/2
  CRIT   = 1 (fi<25), 2 (25<=fi<60), 3 (fi>=60)
  CRIT%  = min(20, 5+fi//5)
  BLOCK% = min(15, 5+fi//6)
  STUN%  = min(10, 0 if fi<20 else (fi-20)//5)

TOKEN SINKS (ATT):
  upgrade_cost(L,r) = ceil(L * (0.5 + r*0.4))  per piece per level
  merge_cost:  C->B=200, B->A=600, A->S=1000  ATT
  heal_cost(f) = 0 (f<=15), ceil((fi-14)*0.4) (f>15)
  boss_entry(f)= 0 (f<=20), ceil((fi-19)*1.5) (f>20)
  rebirth = 500 ATT at F100

TOKEN SOURCES (ATT per floor):
  mob_reward(f)    = 0.5 + fi*0.3  per mob kill (3-4 mobs/floor)
  boss_reward(f)  = 10 + fi*1.5   per boss kill
  floor_bonus(f)   = 1 (f<=20), 2 (f<=50), 3 (f<=70), 4 (f<=90), 5 (f>90)

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
