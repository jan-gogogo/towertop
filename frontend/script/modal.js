/**
 * Unified Modal dialog. Use showModal({ title?, message, buttonText? }) instead of alert().
 * Styled to match app (dark theme, accent button). Resolves when user clicks the button.
 */

let modalRoot = null;

function getRoot() {
  if (modalRoot) return modalRoot;
  modalRoot = document.createElement("div");
  modalRoot.id = "tower-modal-root";
  modalRoot.setAttribute("aria-hidden", "true");
  document.body.appendChild(modalRoot);
  return modalRoot;
}

const STYLES = `
  #tower-modal-root {
    position: fixed;
    inset: 0;
    z-index: 10000;
    display: none;
    align-items: center;
    justify-content: center;
    padding: 24px;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(4px);
  }
  #tower-modal-root.visible {
    display: flex;
  }
  #tower-modal-root .modal-backdrop {
    position: absolute;
    inset: 0;
    cursor: default;
  }
  #tower-modal-root .modal-box {
    position: relative;
    width: 100%;
    max-width: 400px;
    padding: 24px;
    border-radius: 16px;
    background: linear-gradient(145deg, rgba(15, 23, 42, 0.98), rgba(15, 23, 42, 0.95));
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(148, 163, 184, 0.2);
    color: #e5e7eb;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  #tower-modal-root .modal-title {
    font-size: 18px;
    font-weight: 600;
    margin-bottom: 12px;
    color: #e5e7eb;
  }
  #tower-modal-root .modal-message {
    font-size: 14px;
    line-height: 1.5;
    color: #9ca3af;
    margin-bottom: 20px;
    white-space: pre-wrap;
    word-break: break-word;
  }
  #tower-modal-root .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
  }
  #tower-modal-root .modal-btn {
    padding: 10px 20px;
    border-radius: 999px;
    border: none;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    background: #38bdf8;
    color: #0b1120;
    box-shadow: 0 10px 30px rgba(56, 189, 248, 0.4);
    transition: transform 0.12s ease, box-shadow 0.12s ease;
  }
  #tower-modal-root .modal-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 14px 35px rgba(56, 189, 248, 0.6);
  }
`;

function injectStyles() {
  if (document.getElementById("tower-modal-styles")) return;
  const el = document.createElement("style");
  el.id = "tower-modal-styles";
  el.textContent = STYLES;
  document.head.appendChild(el);
}

/**
 * Show modal; returns a Promise that resolves when the user clicks the confirm button.
 * @param {{ title?: string, message: string, buttonText?: string }} opts
 * @returns {Promise<void>}
 */
export function showModal(opts) {
  const { title = "", message, buttonText = "OK" } = opts || {};
  injectStyles();
  const root = getRoot();
  root.innerHTML = `
    <div class="modal-backdrop" id="tower-modal-backdrop"></div>
    <div class="modal-box" role="dialog" aria-modal="true" aria-labelledby="tower-modal-title">
      ${title ? `<div class="modal-title" id="tower-modal-title">${escapeHtml(title)}</div>` : ""}
      <div class="modal-message">${escapeHtml(message)}</div>
      <div class="modal-actions">
        <button type="button" class="modal-btn" id="tower-modal-confirm">${escapeHtml(buttonText)}</button>
      </div>
    </div>
  `;
  root.classList.add("visible");
  root.setAttribute("aria-hidden", "false");

  return new Promise((resolve) => {
    const close = () => {
      root.classList.remove("visible");
      root.setAttribute("aria-hidden", "true");
      root.innerHTML = "";
      resolve();
    };
    const backdrop = root.querySelector("#tower-modal-backdrop");
    const btn = root.querySelector("#tower-modal-confirm");
    const onBtn = () => { btn?.removeEventListener("click", onBtn); backdrop?.removeEventListener("click", onBackdrop); close(); };
    const onBackdrop = () => {}; // click backdrop does not close (consistent with modal behavior)
    btn?.addEventListener("click", onBtn);
    backdrop?.addEventListener("click", onBackdrop);
  });
}

function escapeHtml(s) {
  if (s == null) return "";
  const div = document.createElement("div");
  div.textContent = s;
  return div.innerHTML;
}
