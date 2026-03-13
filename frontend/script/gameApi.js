/**
 * Frontend API for IGameLogic (Tower Top game contract).
 * All methods correspond to src/interfaces/IGameLogic.sol.
 * Uses ethers v6; CONTRACTS.gameProxy is the main entry.
 */

import { CONTRACTS } from "./contracts.js";

let _abi = null;

/** @returns {Promise<Array>} ABI for GameV1 (IGameLogic). */
export async function getAbi() {
  if (_abi) return _abi;
  const res = await fetch("./abi/GameV1.json");
  if (!res.ok) throw new Error("Failed to load Game ABI");
  _abi = await res.json();
  return _abi;
}

/**
 * @param {import("ethers").ContractRunner} runner - ethers v6 signer or provider (use provider for view-only)
 * @param {{ address?: string, abi?: Array } } [opts] - optional override address/abi
 * @returns {Promise<import("ethers").Contract>}
 */
export async function getGameContract(runner, opts = {}) {
  const ethers = globalThis.ethers;
  if (!ethers) throw new Error("ethers not loaded; include ethers v6 script before gameApi");
  const abi = opts.abi ?? (await getAbi());
  const address = opts.address ?? CONTRACTS.gameProxy;
  return new ethers.Contract(address, abi, runner);
}

// --------------- Write (state-changing) methods ---------------
// Each returns the transaction (ethers TransactionResponse). Caller can .wait() for receipt.

/**
 * Create a player (register + initial assets). Reverts if player already exists.
 * @param {import("ethers").Contract} game
 * @returns {Promise<import("ethers").TransactionResponse>}
 */
export async function born(game) {
  return game.born();
}

/**
 * Deposit ERC20 token for game coin; caller must approve game proxy first. amount >= 1e18.
 * @param {import("ethers").Contract} game
 * @param {bigint} amount - token amount in wei
 */
export async function deposit(game, amount) {
  return game.deposit(amount);
}

/**
 * Deposit with EIP-2612 permit (no prior approve). amount >= 1e18.
 * @param {import("ethers").Contract} game
 * @param {bigint} amount
 * @param {number} deadline - unix timestamp
 * @param {number} v
 * @param {string} r
 * @param {string} s
 */
export async function depositWithPermit(game, amount, deadline, v, r, s) {
  return game.depositWithPermit(amount, deadline, v, r, s);
}

/**
 * Withdraw game coin to ERC20 (5% burn). amount >= 1e9.
 * @param {import("ethers").Contract} game
 * @param {bigint} amount
 */
export async function withdraw(game, amount) {
  return game.withdraw(amount);
}

/** Cached recommended gas limit from frontend/gasLimit.json (from battle gas benchmark). */
let _battleGasLimit = null;

/**
 * Recommended gas limit for battle(): from gasLimit.json (benchmark + 20%) or fallback.
 * @returns {Promise<number>}
 */
export async function getBattleGasLimit() {
  if (_battleGasLimit != null) return _battleGasLimit;
  try {
    const res = await fetch("./gasLimit.json");
    if (res.ok) {
      const j = await res.json();
      if (typeof j.battleGasLimit === "number" && j.battleGasLimit > 0) {
        _battleGasLimit = j.battleGasLimit;
        return _battleGasLimit;
      }
    }
  } catch (_) {}
  _battleGasLimit = 1_200_000;
  return _battleGasLimit;
}

/**
 * Fight enemy at slot on current floor.
 * Uses gasLimit from frontend/gasLimit.json (see test_battle_gasBenchmark) or fallback.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} enemySlot
 * @param {{ gasLimit?: number | bigint }} [opts] - optional overrides
 */
export async function battle(game, enemySlot, opts = {}) {
  const gasLimit = opts.gasLimit ?? (await getBattleGasLimit());
  return game.battle(enemySlot, { gasLimit });
}

/**
 * Advance to next floor after all enemies defeated.
 * @param {import("ethers").Contract} game
 */
export async function nextFloor(game) {
  return game.nextFloor();
}

/**
 * Use items at bag slots (book/potion). slots ascending, unique, length 1–5.
 * @param {import("ethers").Contract} game
 * @param {number[]|bigint[]} slots
 */
export async function useItems(game, slots) {
  return game.useItems(slots);
}

/**
 * Spend coin to restore health to healthMax. Only when health < healthMax.
 * @param {import("ethers").Contract} game
 */
export async function fullHeal(game) {
  return game.fullHeal();
}

/**
 * Equip equipment from warehouse by token id.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} equipmentId
 */
export async function equip(game, equipmentId) {
  return game.equip(equipmentId);
}

/**
 * Unequip and put back to warehouse.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} equipmentId
 */
export async function unequip(game, equipmentId) {
  return game.unequip(equipmentId);
}

/**
 * Buy from current floor shop. typeIndex 0: item, 1: equipment.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} typeIndex
 * @param {number|bigint} slot
 */
export async function buy(game, typeIndex, slot) {
  return game.buy(typeIndex, slot);
}

/**
 * Upgrade equipment by spending coin.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} equipmentId
 */
export async function upgrade(game, equipmentId) {
  return game.upgrade(equipmentId);
}

/**
 * Merge two swords; sub is consumed.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} mainEquipmentId
 * @param {number|bigint} subEquipmentId
 */
export async function mergeSword(game, mainEquipmentId, subEquipmentId) {
  return game.mergeSword(mainEquipmentId, subEquipmentId);
}

/**
 * Merge two armors; sub is consumed.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} mainEquipmentId
 * @param {number|bigint} subEquipmentId
 */
export async function mergeArmor(game, mainEquipmentId, subEquipmentId) {
  return game.mergeArmor(mainEquipmentId, subEquipmentId);
}

/**
 * Merge two shields; sub is consumed.
 * @param {import("ethers").Contract} game
 * @param {number|bigint} mainEquipmentId
 * @param {number|bigint} subEquipmentId
 */
export async function mergeShield(game, mainEquipmentId, subEquipmentId) {
  return game.mergeShield(mainEquipmentId, subEquipmentId);
}

/**
 * Rebirth at floor 100: reset level/stats, keep equipment/items/coins, courage+1, floor to 1.
 * @param {import("ethers").Contract} game
 */
export async function circle(game) {
  return game.circle();
}

// --------------- View methods ---------------
// Can use provider (no signer). Return values match Solidity structs decoded by ethers.

/**
 * @param {import("ethers").Contract} game
 * @param {string} addr - player address
 * @returns {Promise<{ index: number, enemies: Array, foundry: { rarity: number }, shop: Object }>}
 */
export async function getFloor(game, addr) {
  return game.getFloor(addr);
}

/**
 * @param {import("ethers").Contract} game
 * @param {string} addr
 * @returns {Promise<Array<{ typ: number, trait: number, level: number, health: number, attack: number, defense: number, crit: number, critChance: number, blockChance: number, stunChance: number, isBoss: boolean }>>}
 */
export async function getEnemies(game, addr) {
  return game.getEnemies(addr);
}

/**
 * @param {import("ethers").Contract} game
 * @param {string} addr
 * @returns {Promise<{ level: number, experience: number, healthMax: number, health: number, attack: number, defense: number, courage: number, createAt: number }>}
 */
export async function getPlayer(game, addr) {
  return game.getPlayer(addr);
}

/**
 * @param {import("ethers").Contract} game
 * @param {string} addr
 * @returns {Promise<bigint[]>}
 */
export async function getBag(game, addr) {
  return game.getBag(addr);
}

/**
 * @param {import("ethers").Contract} game
 * @param {string} addr
 * @returns {Promise<bigint[]>}
 */
export async function getWarehouse(game, addr) {
  return game.getWarehouse(addr);
}

// Minimal ABIs for HeroLogic (getEquippedIds) and InventoryLogic (getEquipment / getPuppet).
const HERO_ABI = [
  {
    type: "function",
    name: "getEquippedIds",
    inputs: [{ name: "addr", type: "address", internalType: "address" }],
    outputs: [{ name: "", type: "uint256[4]", internalType: "uint256[4]" }],
    stateMutability: "view"
  }
];

const INVENTORY_ABI = [
  {
    type: "function",
    name: "getEquipment",
    inputs: [{ name: "id", type: "uint256", internalType: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct Property.Equipment",
        components: [
          { name: "etype", type: "uint8", internalType: "enum Property.EquipmentType" },
          { name: "materials", type: "uint8", internalType: "enum Property.EquipmentMaterials" },
          { name: "rarity", type: "uint8", internalType: "enum Attribute.Rarity" },
          { name: "level", type: "uint8", internalType: "uint8" },
          { name: "attack", type: "uint16", internalType: "uint16" },
          { name: "defense", type: "uint16", internalType: "uint16" },
          { name: "crit", type: "uint16", internalType: "uint16" },
          { name: "critChance", type: "uint16", internalType: "uint16" },
          { name: "blockChance", type: "uint16", internalType: "uint16" },
          { name: "stunChance", type: "uint16", internalType: "uint16" }
        ]
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "getPuppet",
    inputs: [{ name: "id", type: "uint256", internalType: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct Property.Puppet",
        components: [
          { name: "rarity", type: "uint8", internalType: "enum Attribute.Rarity" },
          { name: "lastClaimAt", type: "uint40", internalType: "uint40" }
        ]
      }
    ],
    stateMutability: "view"
  }
];

/**
 * Get equipment bonuses (same as used in battle). Uses HeroLogic.getEquippedIds and InventoryLogic.getEquipment.
 * @param {import("ethers").Contract} game - game contract (must have .runner for provider/signer)
 * @param {string} addr - player address
 * @returns {Promise<{ attack: number, defense: number, crit: number, critChance: number, blockChance: number, stunChance: number }>}
 */
export async function getAbilitiesExtra(game, addr) {
  const ethers = globalThis.ethers;
  if (!ethers) throw new Error("ethers not loaded");
  const runner = game.runner;
  if (!runner) throw new Error("game contract needs a runner (provider or signer)");
  const hero = new ethers.Contract(CONTRACTS.heroProxy, HERO_ABI, runner);
  const inv = new ethers.Contract(CONTRACTS.inventoryProxy, INVENTORY_ABI, runner);
  const ids = await hero.getEquippedIds(addr);
  const e0 = { attack: 0, defense: 0, crit: 0, critChance: 0, stunChance: 0, blockChance: 0 };
  const e1 = { defense: 0 };
  const e2 = { defense: 0, stunChance: 0, blockChance: 0 };
  let eq0 = e0, eq1 = e1, eq2 = e2;
  if (ids[0] && Number(ids[0]) > 0) eq0 = await inv.getEquipment(ids[0]);
  if (ids[1] && Number(ids[1]) > 0) eq1 = await inv.getEquipment(ids[1]);
  if (ids[2] && Number(ids[2]) > 0) eq2 = await inv.getEquipment(ids[2]);
  return {
    attack: Number(eq0.attack ?? 0),
    defense: Number(eq1.defense ?? 0) + Number(eq2.defense ?? 0),
    crit: Number(eq0.crit ?? 0),
    critChance: Number(eq0.critChance ?? 0),
    stunChance: Number(eq0.stunChance ?? 0) + Number(eq2.stunChance ?? 0),
    blockChance: Number(eq2.blockChance ?? 0)
  };
}

/**
 * Get equipped ids for a player (HeroLogic.getEquippedIds).
 * @param {import("ethers").Contract} game
 * @param {string} addr
 * @returns {Promise<bigint[]>}
 */
export async function getEquippedIds(game, addr) {
  const ethers = globalThis.ethers;
  if (!ethers) throw new Error("ethers not loaded");
  const runner = game.runner;
  if (!runner) throw new Error("game contract needs a runner (provider or signer)");
  const hero = new ethers.Contract(CONTRACTS.heroProxy, HERO_ABI, runner);
  return hero.getEquippedIds(addr);
}

/**
 * Batch fetch equipments by ids from InventoryLogic.getEquipment.
 * Returns a map id(string) -> Equipment struct.
 * @param {import("ethers").Contract} game
 * @param {Array<number|bigint>} ids
 * @returns {Promise<Record<string, any>>}
 */
export async function getEquipments(game, ids) {
  const ethers = globalThis.ethers;
  if (!ethers) throw new Error("ethers not loaded");
  const runner = game.runner;
  if (!runner) throw new Error("game contract needs a runner (provider or signer)");
  const inv = new ethers.Contract(CONTRACTS.inventoryProxy, INVENTORY_ABI, runner);
  const out = {};
  const tasks = [];
  ids.forEach((rawId) => {
    const id = typeof rawId === "bigint" ? Number(rawId) : Number(rawId);
    if (!id || out[id]) return;
    tasks.push(
      inv.getEquipment(id).then((eq) => {
        out[String(id)] = eq;
      }).catch(() => {})
    );
  });
  if (tasks.length > 0) {
    await Promise.all(tasks);
  }
  return out;
}

/**
 * Batch fetch puppets by ids from InventoryLogic.getPuppet.
 * Returns a map id(string) -> Puppet struct.
 * @param {import("ethers").Contract} game
 * @param {Array<number|bigint>} ids
 * @returns {Promise<Record<string, any>>}
 */
export async function getPuppets(game, ids) {
  const ethers = globalThis.ethers;
  if (!ethers) throw new Error("ethers not loaded");
  const runner = game.runner;
  if (!runner) throw new Error("game contract needs a runner (provider or signer)");
  const inv = new ethers.Contract(CONTRACTS.inventoryProxy, INVENTORY_ABI, runner);
  const out = {};
  const tasks = [];
  ids.forEach((rawId) => {
    const id = typeof rawId === "bigint" ? Number(rawId) : Number(rawId);
    if (!id || out[id]) return;
    tasks.push(
      inv.getPuppet(id).then((p) => {
        out[String(id)] = p;
      }).catch(() => {})
    );
  });
  if (tasks.length > 0) {
    await Promise.all(tasks);
  }
  return out;
}

// --------------- Helpers for UI ---------------

/**
 * Fetch transaction receipt by hash via JSON-RPC (e.g. for battle replay from txHash).
 * @param {string} txHash - transaction hash (0x...)
 * @param {string} [rpcUrl] - default CONTRACTS.rpcUrl
 * @returns {Promise<{ logs: Array<{ address: string, topics: string[], data: string }>, ... } | null>}
 */
/**
 * @param {string} txHash
 * @param {string} [rpcUrl]
 * @param {import("ethers").Provider} [provider] - if provided (e.g. from wallet), use it to avoid CORS
 */
export async function getReceiptByHash(txHash, rpcUrl, provider) {
  const h = txHash.startsWith("0x") ? txHash : "0x" + txHash;
  if (!txHash) return null;

  let raw = null;
  if (provider && typeof provider.getTransactionReceipt === "function") {
    raw = await provider.getTransactionReceipt(h);
  }
  if (!raw) {
    const url = rpcUrl ?? CONTRACTS.rpcUrl;
    if (!url) return null;
    const body = JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getTransactionReceipt",
      params: [h]
    });
    const res = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body });
    if (!res.ok) throw new Error("RPC request failed: " + res.status);
    const data = await res.json();
    if (data.error) throw new Error(data.error.message || "RPC error");
    raw = data?.result ?? null;
  }
  if (!raw) return null;
  const logs = Array.isArray(raw.logs) ? raw.logs : (raw.logs && typeof raw.logs === "object" ? Object.values(raw.logs) : []);
  return { ...raw, logs };
}

/**
 * Whether the player has called born (createAt > 0).
 * If getPlayer reverts or returns bad data (e.g. unregistered player), returns false.
 * @param {import("ethers").Contract} game
 * @param {string} addr
 * @returns {Promise<boolean>}
 */
export async function isBorn(game, addr) {
  try {
    const p = await game.getPlayer(addr);
    return !!p && (p.createAt > 0n || Number(p.createAt) > 0);
  } catch (_) {
    return false;
  }
}

/**
 * IHeroLogic.Combat: Combat(addr, seed, playerHealth, playerAttack, playerDefense, aoka, ae).
 * Find a log with this event in receipt and decode; returns combat data or null.
 * Matches by event topic0 only (any emitter address) so replay works across deployments.
 * @param {import("ethers").Contract} game - unused, kept for API compatibility
 * @param {import("ethers").TransactionReceipt} receipt
 * @returns {{ seed: string, playerHealth: bigint, playerAttack: bigint, playerDefense: bigint, aoka: Object, ae: Object } | null}
 */
export function parseCombatFromReceipt(game, receipt) {
  const ethers = globalThis.ethers;
  if (!ethers || !receipt) return null;
  const rawLogs = receipt.logs;
  const logs = Array.isArray(rawLogs) ? rawLogs : (rawLogs && typeof rawLogs === "object" ? Object.values(rawLogs) : []);
  if (logs.length === 0) return null;
  const combatIface = new ethers.Interface([
    "event Combat(address addr, bytes32 seed, uint256 playerHealth, uint256 playerAttack, uint256 playerDefense, tuple(uint8 typ, uint8 trait, uint8 level, uint16 health, uint16 attack, uint16 defense, uint8 crit, uint8 critChance, uint8 blockChance, uint8 stunChance, bool isBoss) aoka, tuple(uint16 attack, uint16 defense, uint16 crit, uint16 critChance, uint16 stunChance, uint16 blockChance, uint8 weaponMaterialsIdx, bool armorEquipped, uint8 armorMaterialsIdx) ae)"
  ]);
  const combatTopic0 = (combatIface.getEvent("Combat").topicHash || "").toLowerCase();
  for (const log of logs) {
    const topics = Array.isArray(log.topics) ? log.topics : (log.topics ? Object.values(log.topics) : []);
    if (topics.length === 0) continue;
    if ((topics[0] || "").toLowerCase() !== combatTopic0) continue;
    let data = log.data;
    if (data == null) continue;
    if (typeof data !== "string") data = String(data);
    if (!data.startsWith("0x")) data = "0x" + data;
    if (data.length < 130) continue;
    try {
      const decoded = combatIface.parseLog({ topics, data });
      if (!decoded || !decoded.args) continue;
      const args = decoded.args;
      return {
        seed: args.seed,
        playerHealth: args.playerHealth,
        playerAttack: args.playerAttack,
        playerDefense: args.playerDefense,
        aoka: normalizeAoka(args.aoka),
        ae: normalizeAbilitiesExtra(args.ae)
      };
    } catch (_) {
      continue;
    }
  }
  return null;
}

function normalizeAoka(a) {
  if (!a) return a;
  return {
    typ: Number(a.typ ?? 0),
    trait: Number(a.trait ?? 0),
    level: Number(a.level ?? 0),
    health: Number(a.health ?? 0),
    attack: Number(a.attack ?? 0),
    defense: Number(a.defense ?? 0),
    crit: Number(a.crit ?? 0),
    critChance: Number(a.critChance ?? 0),
    blockChance: Number(a.blockChance ?? 0),
    stunChance: Number(a.stunChance ?? 0),
    isBoss: Boolean(a.isBoss)
  };
}

function normalizeAbilitiesExtra(ae) {
  if (!ae) return ae;
  return {
    attack: Number(ae.attack ?? 0),
    defense: Number(ae.defense ?? 0),
    crit: Number(ae.crit ?? 0),
    critChance: Number(ae.critChance ?? 0),
    stunChance: Number(ae.stunChance ?? 0),
    blockChance: Number(ae.blockChance ?? 0),
    weaponMaterialsIdx: Number(ae.weaponMaterialsIdx ?? 0),
    armorEquipped: Boolean(ae.armorEquipped),
    armorMaterialsIdx: Number(ae.armorMaterialsIdx ?? 0)
  };
}

// Seed.change(oriSeed, len, word) = keccak256(abi.encode(oriSeed, len, word))
function seedChange(ethers, oriSeed, len, word) {
  const hex = oriSeed.startsWith("0x") ? oriSeed : "0x" + oriSeed;
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes32", "uint256", "bytes32"],
    [hex, BigInt(len), word]
  );
  return ethers.keccak256(encoded);
}

const SEED_MIX_CRITCHANCE = "0x637269746368616e636500000000000000000000000000000000000000000000";
const SEED_MIX_BLOCKCHANCE = "0x626c6f636b6368616e6365000000000000000000000000000000000000000000";
const SEED_MIX_STUNCHANCE = "0x7374756e6368616e636500000000000000000000000000000000000000000000";

/**
 * Replay Battle.combat in JS; returns rounds for animation.
 * Each round: { attacker: 'player'|'enemy', damage, playerHealth, aokaHealth, stunned }.
 * @param {string} seedHex - bytes32 hex
 * @param {number} playerHealth
 * @param {number} playerAttack
 * @param {number} playerDefense
 * @param {Object} aoka - normalized aoka
 * @param {Object} ae - normalized AbilitiesExtra
 * @returns {{ rounds: Array<{ attacker: string, damage: number, playerHealth: number, aokaHealth: number, stunned?: boolean }>, playerWin: boolean }}
 */
export function battleReplay(seedHex, playerHealth, playerAttack, playerDefense, aoka, ae) {
  const ethers = globalThis.ethers;
  if (!ethers) throw new Error("ethers required for battleReplay");
  const seed = seedHex.startsWith("0x") ? seedHex : "0x" + seedHex;
  const roll1 = seedChange(ethers, seed, 10, SEED_MIX_CRITCHANCE);
  const roll2 = seedChange(ethers, seed, 11, SEED_MIX_BLOCKCHANCE);
  const roll3 = seedChange(ethers, seed, 10, SEED_MIX_STUNCHANCE);
  const roll1Bytes = ethers.getBytes(roll1);
  const roll2Bytes = ethers.getBytes(roll2);
  const roll3Bytes = ethers.getBytes(roll3);

  let pHealth = Number(playerHealth);
  let aHealth = aoka.health;
  const pAttack = Number(playerAttack) + (ae?.attack ?? 0);
  const pDefense = Number(playerDefense) + (ae?.defense ?? 0);
  const playerAdvantage = (ae?.weaponMaterialsIdx ?? 0) === (aoka.trait ?? 0);
  const aokaAdvantage = ((aoka.trait ?? 0) + 1) % 3 === (ae?.armorMaterialsIdx ?? 0) && (ae?.armorEquipped ?? false);

  const rounds = [];
  let stunned = false;

  for (let i = 0; i < 32; i++) {
    if (stunned) {
      stunned = false;
      rounds.push({ attacker: null, damage: 0, playerHealth: pHealth, aokaHealth: aHealth, stunned: true });
      continue;
    }
    const parity = i & 1;
    let attack, defense, crit, critChance, blockChance, stunChance, hasElementalAdvantage;
    if (parity === 0) {
      attack = pAttack;
      crit = ae?.crit ?? 0;
      critChance = ae?.critChance ?? 0;
      stunChance = ae?.stunChance ?? 0;
      defense = aoka.defense;
      blockChance = aoka.blockChance;
      hasElementalAdvantage = playerAdvantage;
    } else {
      attack = aoka.attack;
      crit = aoka.crit;
      critChance = aoka.critChance;
      stunChance = aoka.stunChance;
      defense = pDefense;
      blockChance = ae?.blockChance ?? 0;
      hasElementalAdvantage = aokaAdvantage;
    }
    const r1 = roll1Bytes[i] ?? 0;
    const r2 = roll2Bytes[i] ?? 0;
    const r3 = roll3Bytes[i] ?? 0;
    const damage = calcDamage(attack, defense, crit, critChance, blockChance, r1, r2, hasElementalAdvantage);
    if (stunChance > 0 && r3 < (stunChance * 256) / 100) stunned = true;
    if (parity === 0) {
      aHealth = Math.max(0, aHealth - damage);
      rounds.push({ attacker: "player", damage, playerHealth: pHealth, aokaHealth: aHealth });
    } else {
      pHealth = Math.max(0, pHealth - damage);
      rounds.push({ attacker: "enemy", damage, playerHealth: pHealth, aokaHealth: aHealth });
    }
    if (pHealth === 0 || aHealth === 0) break;
  }

  return { rounds, playerWin: aHealth === 0 };
}

function calcDamage(attack, defense, crit, critChance, blockChance, roll1, roll2, isElementalAdvantage) {
  let damage = 1;
  if (attack > defense) damage = attack - defense;
  if (isElementalAdvantage && damage > 1) damage = Math.floor((damage * 110) / 100);
  if (crit > 0 && roll1 < (critChance * 256) / 100) damage += damage * crit;
  if (damage > 1 && blockChance > 0 && roll2 < (blockChance * 256) / 100) damage = Math.floor(damage / 2);
  return damage;
}

export { CONTRACTS };
