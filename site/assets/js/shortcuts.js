import { stored, remember } from "./view-options.js";

export function initShortcuts() {
  const control = document.getElementById("shortcuts-enabled");
  let enabled = stored("shortcuts", "on") !== "off";
  if (control) {
    control.checked = enabled;
    control.addEventListener("change", () => { enabled = control.checked; remember("shortcuts", enabled ? "on" : "off"); });
  }
  const help = document.getElementById("shortcut-help");
  document.querySelector('[data-action="help"]')?.addEventListener("click", () => help?.showModal());
  help?.querySelector('[data-action="close-help"]')?.addEventListener("click", () => help.close());
  document.addEventListener("keydown", (event) => {
    if (!enabled || event.altKey || event.ctrlKey || event.metaKey || event.isComposing || event.target.isContentEditable || event.target.closest('input, textarea, select, [role="textbox"], dialog[open]')) return;
    if (event.key === "/") {
      const search = document.getElementById("search") ?? document.querySelector(".toc-filter");
      if (search) { event.preventDefault(); search.focus(); }
    } else if (event.key === "?" && help) {
      event.preventDefault(); help.showModal();
    } else if (event.key === "j" || event.key === "k") {
      const sections = [...document.querySelectorAll("section.rule")].filter((section) => section.getClientRects().length > 0 && getComputedStyle(section).display !== "none");
      if (!sections.length) return;
      const current = sections.findIndex((section) => `#${section.id}` === location.hash);
      const start = current < 0 ? sections.findIndex((section) => section.getBoundingClientRect().bottom > 100) : current;
      const next = Math.max(0, Math.min(sections.length - 1, Math.max(0, start) + (event.key === "j" ? 1 : -1)));
      event.preventDefault();
      location.hash = sections[next].id;
      const title = sections[next].querySelector(".rule-title a");
      title?.focus({ preventScroll: true });
    }
  });
}
