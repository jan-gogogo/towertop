/**
 * Battle replay UI: stage DOM, animations, and replay from combat data.
 * Depends on gameApi.battleReplay. Use createBattleReplayUI(container) to mount.
 */

import { battleReplay } from "./gameApi.js";
import { t } from "./i18n.js";

const AOKA_SHEETS = {
  0: "aoka_goblin", 1: "aoka_slime", 2: "aoka_goblin", 3: "aoka_golem", 4: "aoka_bat", 5: "aoka_giant",
  6: "aoka_hellhound", 7: "aoka_yeti", 8: "aoka_skeleton", 9: "aoka_zombie", 10: "aoka_vampire",
  11: "aoka_werewolf", 12: "aoka_witch", 13: "aoka_orc", 14: "aoka_hornet", 15: "aoka_lizardman",
  16: "aoka_imp", 17: "aoka_spider", 18: "aoka_wisp", 19: "aoka_gremlin", 20: "aoka_slimeking",
  21: "aoka_darklord", 22: "aoka_frostqueen", 23: "aoka_fireelemental", 24: "aoka_thundertitan",
  25: "aoka_shadowreaper", 26: "aoka_crystalguardian", 27: "aoka_ironcolossus", 28: "aoka_warlock"
};

export function getAokaImageUrl(typ, basePath = "./") {
  const name = AOKA_SHEETS[Number(typ)] || "aoka_goblin";
  const dir = basePath.replace(/\/?$/, "/");
  return `${dir}assets/aoka/${name}.png`;
}

const PLAYER_IMAGE_PATH = "./assets/player/hero.png";

/**
 * Create battle stage + result UI inside container. Returns API for replay and controls.
 * @param {HTMLElement} container
 * @param {{ assetBasePath?: string }} options
 * @returns {{ replay(combatData): Promise<void>, showWaiting(show: boolean, text?: string), showResult(playerWin: boolean), onConfirm(cb: () => void), setEnemyImage(url: string), setPlayerImage(url: string) }}
 */
export function createBattleReplayUI(container, options = {}) {
  const assetBasePath = options.assetBasePath ?? "./";
  const base = assetBasePath.replace(/\/?$/, "/");

  const root = document.createElement("div");
  root.className = "battle-replay-root";
  root.innerHTML = `
    <div class="battle-stage">
      <div class="battle-bg"></div>
      <div class="sprite enemy" id="battleEnemySprite"></div>
      <div class="sprite player" id="battlePlayerSprite"></div>
      <div class="battle-wait" id="battleWait" style="display:none;">${t("loading")}</div>
      <div class="battle-overlay"></div>
    </div>
    <div class="battle-result-overlay" id="battleResultOverlay" style="display:none;">
      <p class="result-text" id="battleResultText"></p>
      <button type="button" class="btn-confirm" id="battleResultConfirm">${t("confirm")}</button>
    </div>
  `;
  container.appendChild(root);

  const stage = root.querySelector(".battle-stage");
  const enemySprite = root.querySelector("#battleEnemySprite");
  const playerSprite = root.querySelector("#battlePlayerSprite");
  const battleWait = root.querySelector("#battleWait");
  const resultOverlay = root.querySelector("#battleResultOverlay");
  const resultText = root.querySelector("#battleResultText");
  const resultConfirm = root.querySelector("#battleResultConfirm");

  let confirmCallback = null;

  function setEnemyImage(url) {
    if (enemySprite) enemySprite.style.backgroundImage = url ? `url("${url}")` : "";
  }
  function setPlayerImage(url) {
    if (playerSprite) playerSprite.style.backgroundImage = url ? `url("${url}")` : "";
  }

  function showWaiting(show, text) {
    if (!battleWait) return;
    battleWait.style.display = show ? "flex" : "none";
    battleWait.textContent = text != null ? text : t("loading");
  }

  function showResult(playerWin) {
    if (!resultOverlay || !resultText) return;
    resultText.textContent = playerWin ? t("victory") : t("defeat");
    resultText.className = "result-text " + (playerWin ? "victory" : "defeat");
    resultOverlay.style.display = "flex";
  }

  function hideResult() {
    if (resultOverlay) resultOverlay.style.display = "none";
  }

  resultConfirm?.addEventListener("click", () => {
    hideResult();
    if (confirmCallback) confirmCallback();
  });

  function onConfirm(cb) {
    confirmCallback = cb;
  }

  function addDamagePop(value, isEnemy) {
    if (!stage) return;
    const pop = document.createElement("div");
    pop.className = "damage-pop " + (isEnemy ? "enemy" : "player");
    pop.textContent = "-" + value;
    stage.appendChild(pop);
    setTimeout(() => pop.remove(), 900);
  }

  function runHurt(sprite) {
    if (!sprite) return;
    sprite.classList.remove("hurt");
    sprite.offsetHeight;
    sprite.classList.add("hurt");
    setTimeout(() => sprite.classList.remove("hurt"), 400);
  }

  function runAttack(sprite, isEnemy) {
    if (!sprite) return;
    sprite.classList.remove("attack-player", "attack-enemy");
    sprite.offsetHeight;
    sprite.classList.add(isEnemy ? "attack-enemy" : "attack-player");
    setTimeout(() => sprite.classList.remove("attack-player", "attack-enemy"), 350);
  }

  function animateRound(round) {
    return new Promise((resolve) => {
      if (round.stunned) {
        setTimeout(resolve, 400);
        return;
      }
      if (round.attacker === "player") {
        runAttack(playerSprite, false);
        setTimeout(() => {
          runHurt(enemySprite);
          addDamagePop(round.damage, true);
        }, 180);
      } else if (round.attacker === "enemy") {
        runAttack(enemySprite, true);
        setTimeout(() => {
          runHurt(playerSprite);
          addDamagePop(round.damage, false);
        }, 180);
      }
      setTimeout(resolve, 700);
    });
  }

  async function animateBattle(rounds, playerWin) {
    for (const round of rounds) {
      await animateRound(round);
    }
    setTimeout(() => showResult(playerWin), 500);
  }

  /**
   * Run battle replay from combat data (seed, playerHealth, playerAttack, playerDefense, aoka, ae).
   * @param {Object} combatData - from parseCombatFromReceipt
   */
  async function replay(combatData) {
    if (!combatData || !combatData.aoka) return;
    setEnemyImage(getAokaImageUrl(combatData.aoka.typ, assetBasePath));
    setPlayerImage(base + "assets/player/hero.png");
    enemySprite?.classList.remove("hurt", "attack-enemy");
    playerSprite?.classList.remove("hurt", "attack-player");
    hideResult();

    const pHealth = Number(combatData.playerHealth);
    const pAttack = Number(combatData.playerAttack);
    const pDefense = Number(combatData.playerDefense);
    const seedHex = typeof combatData.seed === "string" ? combatData.seed : (combatData.seed?.hash ? "0x" + combatData.seed.hash : null);
    if (!seedHex) {
      showResult(false);
      return;
    }
    const { rounds, playerWin } = battleReplay(seedHex, pHealth, pAttack, pDefense, combatData.aoka, combatData.ae);
    await animateBattle(rounds, playerWin);
  }

  return {
    replay,
    showWaiting,
    showResult,
    hideResult,
    onConfirm,
    setEnemyImage,
    setPlayerImage,
    getAokaImageUrl: (typ) => getAokaImageUrl(typ, assetBasePath)
  };
}
