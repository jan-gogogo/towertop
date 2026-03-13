export function mountHeader(appRootId = "appHeader") {
  const { createApp } = window.Vue || {};
  if (!createApp) {
    console.error("Vue not found");
    return;
  }

  const app = createApp({
    template: `
      <header class="header header-fixed">
        <span class="game-title" id="headerAppTitle" data-i18n="appTitle">Tower Top · Aoka 塔</span>
        <div style="display: flex; align-items: center; gap: 10px;">
          <span class="lang-switcher" style="display: inline-flex; align-items: center; gap: 6px; font-size: 13px;">
            <button type="button" class="lang-btn" data-lang="zh">中文</button>
            <span style="color: var(--text-muted);">|</span>
            <button type="button" class="lang-btn" data-lang="en">English</button>
          </span>
          <a href="replay.html" id="headerBattleReplay" data-i18n="battleReplay" style="color: var(--text-muted); font-size: 13px; text-decoration: none; margin-left: 4px;">战斗重放</a>
          <div class="pill">
            <span class="pill-dot"></span>
            <span id="headerNetwork" data-i18n="networkName">Ronin Saigon Testnet</span>
          </div>
          <div class="wallet-area">
            <div id="walletNotConnected" class="wallet-not-connected">
              <button id="connectBtn" data-i18n="connectWallet">连接钱包</button>
              <div id="walletDropdown" class="wallet-dropdown">
                <button type="button" id="walletOptionRonin">Ronin</button>
                <button type="button" id="walletOptionMetaMask">MetaMask</button>
              </div>
            </div>
            <div id="walletConnected" class="wallet-connected">
              <div class="wallet-addr-wrap" id="walletAddrWrap">
                <span id="walletAddr" class="wallet-addr"></span>
                <div id="playerTooltip" class="player-tooltip" aria-hidden="true">
                  <div class="player-tooltip-header">
                    <img class="player-tooltip-avatar" src="assets/player/avatar.png" alt="" />
                    <span class="player-tooltip-level" id="playerTooltipLevel">Lv 1</span>
                    <img class="player-tooltip-bag" src="assets/player/bag.png" alt="" />
                  </div>
                  <div class="player-tooltip-bar">
                    <label id="playerTooltipHpLabel">HP</label>
                    <div class="bar"><div class="bar-fill hp" id="playerTooltipHpFill" style="width:100%"></div></div>
                    <div class="bar-text" id="playerTooltipHpText">100/100</div>
                  </div>
                  <div class="player-tooltip-bar">
                    <label id="playerTooltipExpLabel">Exp</label>
                    <div class="bar"><div class="bar-fill exp" id="playerTooltipExpFill" style="width:0%"></div></div>
                    <div class="bar-text" id="playerTooltipExpText">0/10</div>
                  </div>
                  <div class="player-tooltip-attrs" id="playerTooltipAttrs"></div>
                </div>
              </div>
              <button id="disconnectBtn" class="btn-disconnect" data-i18n="disconnect">退出</button>
            </div>
          </div>
        </div>
      </header>
    `
  });

  const root = document.getElementById(appRootId);
  if (!root) {
    console.error("Header root element not found:", appRootId);
    return;
  }

  app.mount(root);
}

