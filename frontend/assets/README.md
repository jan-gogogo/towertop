# Assets

## Equipment icons

Icons in `equipment/` are single-image items for inventory/shop. Style and size match the game: cartoon, EOS Knights–like, transparent background, web-ready (e.g. 128–256px).

| File | Description |
|------|-------------|
| sword_wooden.png | Wooden sword 木剑 (Wooden, 256×256, transparent) |
| sword_iron.png | Iron sword 铁剑 (Iron, same style/size) |
| sword_obsidian.png | Obsidian sword 黑曜石剑 (Obsidian, same style/size) |
| armor_wooden.png | Wooden armor 木甲 (Wooden, 256×256, transparent) |
| armor_iron.png | Iron armor 铁甲 (Iron, same style/size) |
| armor_obsidian.png | Obsidian armor 黑曜石甲 (Obsidian, same style/size) |
| shield_wooden.png | Wooden shield 木盾 (Wooden, 256×256, transparent) |
| shield_iron.png | Iron shield 铁盾 (Iron, same style/size) |
| shield_obsidian.png | Obsidian shield 黑曜石盾 (Obsidian, same style/size) |
| sword_wooden_c.png | C-grade wooden sword (rarity variant) |
| sword_wooden_b.png | B-grade wooden sword (rarity variant) |
| sword_wooden_a.png | A-grade wooden sword (rarity variant) |
| sword_wooden_s.png | S-grade wooden sword (rarity variant) |

Material icons (`sword_wooden.png`, `sword_iron.png`, `sword_obsidian.png`) are same style, same size, transparent background. Naming: `<type>_<material>.png` or `<type>_<material>_<rarity>.png` (e.g. `sword_wooden_c.png`, `shield_iron_b.png`). Materials: wooden, iron, obsidian. Rarity: c, b, a, s.

---

## Player sprites

Sprites in `player/` are the main hero in battle, same chibi style as Aoka. Files named `player_hero_4states.png` are 2×2 grids (256×256 per cell, transparent PNG):

| Grid cell | State   | Use in battle        |
|-----------|---------|----------------------|
| Top-left  | normal  | 待机 / 正常（背对玩家） |
| Top-right | attack  | 攻击动作               |
| Bottom-left | attacked | 受击 / 被攻击      |
| Bottom-right | fallen | 倒下 / 战败         |

- Camera: hero背对玩家，适合放在右下角，对应宝可梦式布局。
- 统一规格：扁平卡通、轮廓清晰、256×256 画布、背景透明。

| File | Description |
|------|-------------|
| player_hero_4states.png | Player hero (back view) hero sprite sheet |

---

## Item icons (consumables)

Icons in `items/` are single-image consumables. Same specs: flat cartoon, clear outline, 256×256, transparent PNG.

| File | Description |
|------|-------------|
| item_book.png | Experience book 经验书 (Book) |
| item_potion.png | Health potion 药水瓶 (Potion) |

---

## Battle backgrounds

Backgrounds in `backgrounds/` are wide, flat-cartoon scenes without characters, used under the battle UI.

| File | Description |
|------|-------------|
| bg_tower_battle.png | Tower interior battle arena (stone floor, banners, torches), landscape ≈1280×720 |
| bg_tower_battle_2.png | Broken pillar arena – same tower interior, collapsed column and debris in the circle |
| bg_tower_battle_3.png | Stained-glass tower chamber with circular floor markings and weapon rack |
| bg_tower_battle_4.png | High-floor hall in the tower, banners and braziers lining the walls |
| bg_tower_battle_5.png | Dark tower boss room with glowing rune circle and blue flames |

---

## Aoka (enemy) sprites

Sprites in `aoka/` correspond to `AokaType` in `src/libraries/Enemy.sol`.

### 4-state sprite sheets (全身像 + 四状态)

Files named `aoka_<type>_4states.png` are **2×2 grids** for JS to switch by state:

| Grid cell | State   | Use in battle        |
|-----------|--------|-----------------------|
| Top-left  | normal | 待机 / 正常            |
| Top-right | attack | 攻击动作               |
| Bottom-left | attacked | 受击（闪/抖）       |
| Bottom-right | fallen | 倒下 / 战败          |

- Full-body character, cartoon style (EOS Knights–like).
- Transparent (or white-to-transparent) background.
- Same size per cell so frontend can crop by index: `0=normal, 1=attack, 2=attacked, 3=fallen`.

### 4-state files (by AokaType enum index)

All 40 types have a sprite sheet. Use filename from `AokaType` as: `aoka_<lowercase_type>_4states.png` (e.g. `SlimeKing` → `aoka_slime_king_4states.png`).

| Index | File | AokaType | Notes |
|-------|------|----------|--------|
| 0 | aoka_tin_4states.png | Tin | Special |
| 1 | aoka_slime_4states.png | Slime | Minion |
| 2 | aoka_goblin_4states.png | Goblin | Minion |
| 3 | aoka_golem_4states.png | Golem | Minion |
| 4 | aoka_bat_4states.png | Bat | Minion |
| 5 | aoka_giant_4states.png | Giant | Minion |
| 6 | aoka_hellhound_4states.png | Hellhound | Minion |
| 7 | aoka_yeti_4states.png | Yeti | Minion |
| 8 | aoka_skeleton_4states.png | Skeleton | Minion |
| 9 | aoka_zombie_4states.png | Zombie | Minion |
| 10 | aoka_vampire_4states.png | Vampire | Minion |
| 11 | aoka_werewolf_4states.png | Werewolf | Minion |
| 12 | aoka_witch_4states.png | Witch | Minion |
| 13 | aoka_orc_4states.png | Orc | Minion |
| 14 | aoka_hornet_4states.png | Hornet | Minion |
| 15 | aoka_lizardman_4states.png | Lizardman | Minion |
| 16 | aoka_imp_4states.png | Imp | Minion |
| 17 | aoka_spider_4states.png | Spider | Minion |
| 18 | aoka_wisp_4states.png | Wisp | Minion |
| 19 | aoka_gremlin_4states.png | Gremlin | Minion |
| 20 | aoka_slime_king_4states.png | SlimeKing | BOSS |
| 21 | aoka_dark_lord_4states.png | DarkLord | BOSS |
| 22 | aoka_frost_queen_4states.png | FrostQueen | BOSS |
| 23 | aoka_fire_elemental_4states.png | FireElemental | BOSS |
| 24 | aoka_thunder_titan_4states.png | ThunderTitan | BOSS |
| 25 | aoka_shadow_reaper_4states.png | ShadowReaper | BOSS |
| 26 | aoka_crystal_guardian_4states.png | CrystalGuardian | BOSS |
| 27 | aoka_iron_colossus_4states.png | IronColossus | BOSS |
| 28 | aoka_warlock_4states.png | Warlock | BOSS |
| 29 | aoka_serpent_emperor_4states.png | SerpentEmperor | BOSS |
| 30 | aoka_phantom_knight_4states.png | PhantomKnight | BOSS |
| 31 | aoka_blood_wraith_4states.png | BloodWraith | BOSS |
| 32 | aoka_specter_king_4states.png | SpecterKing | BOSS |
| 33 | aoka_bone_crusher_4states.png | BoneCrusher | BOSS |
| 34 | aoka_magma_beast_4states.png | MagmaBeast | BOSS |
| 35 | aoka_storm_bringer_4states.png | StormBringer | BOSS |
| 36 | aoka_moon_priest_4states.png | MoonPriest | BOSS |
| 37 | aoka_sun_warden_4states.png | SunWarden | BOSS |
| 38 | aoka_abyss_watcher_4states.png | AbyssWatcher | BOSS |
| 39 | aoka_titan_lord_4states.png | TitanLord | BOSS |
