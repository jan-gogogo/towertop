/**
 * Centralized copy: zh / en. Use t(key) or t(key, params) for replacements.
 * Language: init from localStorage or navigator.language; switcher in header.
 */

const TEXTS = {
  appTitle: { zh: "Tower Top · Aoka 塔", en: "Tower Top · Aoka Tower" },
  battleReplay: { zh: "战斗重放", en: "Battle Replay" },
  battle: { zh: "战斗", en: "Battle" },
  battlePageTitle: { zh: "战斗 - Tower Top", en: "Battle - Tower Top" },
  connectWallet: { zh: "连接钱包", en: "Connect Wallet" },
  connecting: { zh: "连接中…", en: "Connecting…" },
  disconnect: { zh: "退出", en: "Disconnect" },
  pleaseConnect: { zh: "请连接钱包以开始", en: "Please connect wallet to start" },
  connectHint: { zh: "点击右上角「连接钱包」，选择 MetaMask 或 Ronin", en: "Click \"Connect Wallet\" at top right, choose MetaMask or Ronin" },
  welcomeTitle: { zh: "欢迎来到 Aoka 塔", en: "Welcome to Aoka Tower" },
  welcomeDesc: {
    zh: "你的冒险即将开始。召唤你的英雄，从第一层开始，击败魔物、收集宝物，一路登顶。",
    en: "Your adventure begins. Summon your hero, start from floor one, defeat monsters, collect treasures, and reach the top."
  },
  startAdventure: { zh: "开始冒险", en: "Start Adventure" },
  floorN: { zh: "第 {n} 层", en: "Floor {n}" },
  floorBossSuffix: { zh: "BOSS", en: "BOSS" },
  nextFloorBtn: { zh: "进入下一层", en: "Enter Next Floor" },
  shop: { zh: "商店", en: "Shop" },
  shopTitle: { zh: "商店", en: "Shop" },
  shopClose: { zh: "关闭", en: "Close" },
  bagTitle: { zh: "背包与装备", en: "Bag & Equipment" },
  bagSectionBag: { zh: "背包道具", en: "Bag Items" },
  bagSectionEquip: { zh: "装备仓库", en: "Equipment" },
  bagTabBag: { zh: "背包", en: "Bag" },
  bagTabWarehouse: { zh: "仓库", en: "Warehouse" },
  bagEmpty: { zh: "背包为空", en: "Bag is empty" },
  equipEmpty: { zh: "暂无装备", en: "No equipment yet" },
  itemBook: { zh: "经验书", en: "Exp Book" },
  itemPotion: { zh: "血瓶", en: "Potion" },
  itemBookDesc: { zh: "+5 经验", en: "+5 EXP" },
  itemPotionDesc: { zh: "+10 血量", en: "+10 HP" },
  rarityLabel: { zh: "稀有度", en: "Rarity" },
  rarityC: { zh: "C", en: "C" },
  rarityB: { zh: "B", en: "B" },
  rarityA: { zh: "A", en: "A" },
  rarityS: { zh: "S", en: "S" },
  equipSword: { zh: "剑", en: "Sword" },
  equipArmor: { zh: "盔甲", en: "Armor" },
  equipShield: { zh: "盾", en: "Shield" },
  equipPuppet: { zh: "木偶", en: "Puppet" },
  equipPanelTitle: { zh: "装备/属性", en: "Equipment/Attribute" },
  materialWooden: { zh: "木", en: "Wooden" },
  materialIron: { zh: "铁", en: "Iron" },
  materialObsidian: { zh: "黑曜石", en: "Obsidian" },
  buyBtn: { zh: "购买", en: "Buy" },
  buySuccess: { zh: "购买成功", en: "Purchase successful" },
  buyFailed: { zh: "购买失败", en: "Purchase failed" },
  useItemBtn: { zh: "使用", en: "Use" },
  equipBtn: { zh: "装备", en: "Equip" },
  unequipBtn: { zh: "卸下", en: "Unequip" },
  useItemSuccess: { zh: "使用道具成功", en: "Items used successfully" },
  useItemFailed: { zh: "使用道具失败", en: "Use items failed" },
  useItemNotUsable: { zh: "此物品不能直接使用", en: "This item cannot be used directly" },
  equipSuccess: { zh: "装备更新成功", en: "Equipment updated successfully" },
  equipFailed: { zh: "装备失败", en: "Equip failed" },
  unequipSuccess: { zh: "卸下装备成功", en: "Unequip successful" },
  unequipFailed: { zh: "卸下失败", en: "Unequip failed" },
  coinUnit: { zh: "金币", en: " coins" },
  foundry: { zh: "锻造房", en: "Foundry" },
  loading: { zh: "加载中…", en: "Loading…" },
  loadingReplay: { zh: "正在加载重放…", en: "Loading replay…" },
  confirmingTx: { zh: "交易确认中…", en: "Confirming transaction…" },
  victory: { zh: "胜利", en: "Victory" },
  defeat: { zh: "失败", en: "Defeat" },
  confirm: { zh: "确定", en: "OK" },
  connectFailed: { zh: "连接失败", en: "Connection failed" },
  noRonin: { zh: "未检测到 Ronin 钱包", en: "Ronin wallet not detected" },
  noMetaMask: { zh: "未检测到 MetaMask 钱包", en: "MetaMask wallet not detected" },
  callFailed: { zh: "调用失败", en: "Call failed" },
  statsFormat: { zh: "HP {hp} | 攻 {atk} 防 {def}", en: "HP {hp} | ATK {atk} DEF {def}" },
  traitElectric: { zh: "雷", en: "Electric" },
  traitEarth: { zh: "地", en: "Earth" },
  traitFire: { zh: "火", en: "Fire" },
  networkName: { zh: "Ronin Saigon Testnet", en: "Ronin Saigon Testnet" },

  // Player tooltip (address hover)
  playerAttack: { zh: "攻击力", en: "Attack" },
  playerDefense: { zh: "防御力", en: "Defense" },
  playerCrit: { zh: "暴击倍数", en: "Crit" },
  playerCritChance: { zh: "暴击率", en: "Crit Rate" },
  playerBlockChance: { zh: "格挡率", en: "Block" },
  playerStunChance: { zh: "眩晕率", en: "Stun" },
  playerHp: { zh: "HP", en: "HP" },
  playerExp: { zh: "Exp", en: "Exp" },
  playerLevel: { zh: "Lv", en: "Lv" },
  playerAttackDesc: {
    zh: "影响对敌人造成的伤害，基础伤害 = 攻击力 - 敌人防御",
    en: "Affects damage dealt. Base damage = Attack − Enemy Defense."
  },
  playerDefenseDesc: {
    zh: "影响受到敌人攻击时的伤害减免，敌人攻击小于此值时，受到 1 点伤害",
    en: "Affects damage reduction. If enemy attack is below this value, you take 1 damage."
  },
  playerCritDesc: {
    zh: "暴击时额外伤害倍数，额外伤害 = 暴击倍数 × 基础伤害",
    en: "Extra damage on crit. Extra damage = Crit Multiplier × Base Damage."
  },
  playerCritChanceDesc: {
    zh: "0–100，有一定概率出现暴击，数值越大机率越高",
    en: "0–100, chance for a critical hit; higher value means higher chance."
  },
  playerBlockChanceDesc: {
    zh: "0–100，有一定概率伤害减半，数值越大概率越高",
    en: "0–100, chance to halve incoming damage; higher value means higher chance."
  },
  playerStunChanceDesc: {
    zh: "0–100，有一定概率使敌人一回合无法行动，数值越大概率越高",
    en: "0–100, chance to stun the enemy for one turn; higher value means higher chance."
  },

  // Replay page
  replayPageTitle: { zh: "战斗重放 - Tower Top", en: "Battle Replay - Tower Top" },
  backToGame: { zh: "← 返回游戏", en: "← Back to Game" },
  backToFloor: { zh: "← 返回楼层", en: "← Back to Floor" },
  txHashLabel: { zh: "交易哈希 (txHash)：", en: "Transaction hash (txHash):" },
  txHashPlaceholder: { zh: "0x...", en: "0x..." },
  replayBtn: { zh: "战斗回放", en: "Battle Replay" },
  replayErrNoInput: { zh: "请输入交易哈希", en: "Please enter transaction hash" },
  replayErrNoLogs: {
    zh: "未找到该交易或交易无日志，请确认 txHash 为 Ronin Saigon 上的 battle 交易",
    en: "Transaction not found or no logs. Ensure txHash is a battle tx on Ronin Saigon."
  },
  replayErrInvalid: {
    zh: "该交易不是有效的战斗交易，或无法解析 Combat 事件",
    en: "Not a valid battle transaction or Combat event could not be parsed."
  },
  replayErrFailed: { zh: "重放失败", en: "Replay failed" },
  replayErrNetworkHint: {
    zh: "（若为网络/RPC 限制，请先连接钱包后重试）",
    en: " (If due to network/RPC, try connecting wallet and retry.)"
  },

  // Modal
  modalConfirm: { zh: "确定", en: "OK" },

  // Aoka names: same order as AOKA_SHEETS indices 0..28+
  aokaNames: {
    zh: [
      "锡人", "史莱姆", "哥布林", "石头人", "蝙蝠怪", "巨人", "地狱犬", "雪人", "骷髅", "僵尸",
      "吸血鬼", "狼人", "女巫", "兽人", "黄蜂", "蜥蜴人", "小恶魔", "蜘蛛", "幽灵", "小妖精",
      "史莱姆王", "黑暗领主", "冰霜女王", "火元素", "雷霆泰坦", "暗影收割者", "水晶守卫",
      "钢铁巨像", "术士", "蛇帝", "幻影骑士", "血魂", "幽灵王", "碎骨者", "熔岩兽", "风暴使者",
      "月神祭司", "太阳守卫者", "深渊领主", "泰坦之王"
    ],
    en: [
      "Tin", "Slime", "Goblin", "Golem", "Bat", "Giant", "Hellhound", "Yeti", "Skeleton", "Zombie",
      "Vampire", "Werewolf", "Witch", "Orc", "Hornet", "Lizardman", "Imp", "Spider", "Wisp", "Gremlin",
      "SlimeKing", "DarkLord", "FrostQueen", "FireElemental", "ThunderTitan", "ShadowReaper", "CrystalGuardian",
      "IronColossus", "Warlock", "SerpentEmperor", "PhantomKnight", "BloodWraith", "SpecterKing", "BoneCrusher",
      "MagmaBeast", "StormBringer", "MoonPriest", "SunWarden", "AbyssWatcher", "TitanLord"
    ]
  }
};

const STORAGE_KEY = "tower-lang";

function detectLang() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "zh" || stored === "en") return stored;
  } catch (_) {}
  const nav = typeof navigator !== "undefined" && navigator.language ? navigator.language.toLowerCase() : "";
  if (nav.startsWith("zh")) return "zh";
  return "en";
}

let currentLang = detectLang();

export function getLang() {
  return currentLang;
}

export function setLang(lang) {
  if (lang !== "zh" && lang !== "en") return;
  currentLang = lang;
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch (_) {}
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent("languageChange", { detail: { lang } }));
  }
}

export function initLang() {
  currentLang = detectLang();
  return currentLang;
}

/**
 * @param {string} key - key in TEXTS
 * @param {Record<string, string|number>} [params] - e.g. { n: 5 } for "第 5 层"
 * @returns {string}
 */
export function t(key, params) {
  const entry = TEXTS[key];
  if (!entry) return key;
  let s = entry[currentLang] ?? entry.en ?? entry.zh ?? key;
  if (params && typeof s === "string") {
    Object.keys(params).forEach((k) => {
      s = s.replace(new RegExp("\\{" + k + "\\}", "g"), String(params[k]));
    });
  }
  return s;
}

/**
 * Get Aoka display name by type index.
 * @param {number} typ - aoka type index
 * @returns {string}
 */
export function aokaName(typ) {
  const list = TEXTS.aokaNames[currentLang] || TEXTS.aokaNames.en;
  return list[Number(typ)] || TEXTS.aokaNames.en[Number(typ)] || "Aoka";
}
