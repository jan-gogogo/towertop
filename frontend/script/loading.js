export function createLoading(options = {}) {
  const { text = "LOADING" } = options || {};
  const wrap = document.createElement("div");
  wrap.className = "aoka-loading aoka-loading-shake";

  const label = document.createElement("span");
  label.textContent = text.toUpperCase();
  wrap.appendChild(label);

  for (let i = 0; i < 3; i++) {
    const dot = document.createElement("div");
    dot.className = "aoka-loading-dot";
    wrap.appendChild(dot);
  }

  return wrap;
}

