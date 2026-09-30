import { initHighlight } from "./highlight.js";
import { initToc } from "./toc.js";
import { initViewOptions } from "./view-options.js";
import { initShortcuts } from "./shortcuts.js";
import { initDiagrams, renderDiagram } from "./diagrams.js";

document.documentElement.dataset.js = "true";
initViewOptions();
initToc();
initShortcuts();

let statusTimer;
function announce(message) {
  const status = document.getElementById("status");
  if (!status || !message) return;
  clearTimeout(statusTimer);
  status.textContent = message;
  statusTimer = setTimeout(() => { status.textContent = ""; }, 5000);
}

let popover;
const loadPopover = () => popover ??= import("./popover.js").then(({ initPopover }) => initPopover());
const invalidateHighlight = initHighlight(document.querySelector("main"), (target, entered, event) => {
  loadPopover().then((view) => view.reference(target, entered, event)).catch(() => {});
});
initDiagrams(invalidateHighlight);
if (document.querySelector("a.rr-nt, svg[data-placeholder]")) {
  if ("requestIdleCallback" in window) requestIdleCallback(loadPopover, { timeout: 2000 });
  else setTimeout(loadPopover, 1000);
}

const search = document.getElementById("search");
search?.addEventListener("focus", () => {
  import("./search.js").then(({ initSearch }) => initSearch(search, announce)).catch(() => announce(document.body.dataset.searchFailed));
}, { once: true });

async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    announce(document.body.dataset.copied);
  } catch {
    const input = document.createElement("textarea");
    input.value = text;
    input.className = "sr-only";
    document.body.append(input);
    const active = document.activeElement;
    input.select();
    let succeeded = false;
    try { succeeded = document.execCommand("copy"); } catch { /* Report the unavailable clipboard. */ }
    input.remove();
    active?.focus({ preventScroll: true });
    announce(succeeded ? document.body.dataset.copied : document.body.dataset.copyFailed);
  }
}

document.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-action]");
  const rule = button?.closest("section.rule");
  if (!rule) return;
  const action = button.dataset.action;
  const svg = renderDiagram(rule);
  if (action === "copy-link") {
    const url = new URL(location.href);
    url.hash = rule.id;
    await copy(url.href);
  } else if (action === "copy-bnf") {
    await copy(rule.querySelector(".rule-bnf code")?.textContent ?? "");
  } else if (action === "bnf") {
    const bnf = rule.querySelector(".rule-bnf");
    if (bnf) { bnf.open = !bnf.open; bnf.querySelector("summary")?.focus(); }
  } else if (svg && ["svg", "png"].includes(action)) {
    button.disabled = true;
    try {
      const { exportDiagram } = await import("./export.js");
      await exportDiagram(svg, rule.id, action);
    } catch { announce(document.body.dataset.exportFailed); }
    finally { button.disabled = false; }
  } else if (svg && action.startsWith("zoom-")) {
    const original = svg.viewBox.baseVal.width || svg.width.baseVal.value;
    const zoom = action === "zoom-reset" ? 1 : Math.max(.25, Math.min(4, Number(svg.dataset.zoom ?? 1) + (action === "zoom-in" ? .25 : -.25)));
    svg.dataset.zoom = String(zoom);
    svg.style.width = `${original * zoom}px`;
    svg.style.height = "auto";
  } else if (action === "fullscreen") {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await rule.requestFullscreen();
    } catch { announce(document.body.dataset.fullscreenFailed); }
  }
});
