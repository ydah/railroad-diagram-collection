const TARGET = "a.rr-nt, .rule-title";

export function initHighlight(root = document.querySelector("main"), onReference = () => {}) {
  if (!root) return;
  let index;
  let active = [];
  const clear = () => {
    active.forEach((element) => element.classList.remove("is-related"));
    active = [];
  };
  const enter = (event) => {
    const target = event.target.closest?.(TARGET);
    if (!target || target === event.relatedTarget?.closest?.(TARGET)) return;
    if (!index) {
      index = new Map();
      for (const link of root.querySelectorAll("a.rr-nt")) {
        const slug = link.getAttribute("href");
        if (!slug?.startsWith("#")) continue;
        if (!index.has(slug)) index.set(slug, []);
        index.get(slug).push(link);
      }
    }
    clear();
    const slug = target.matches("a.rr-nt") ? target.getAttribute("href") : `#${target.closest("section.rule")?.id}`;
    const title = document.getElementById(slug?.slice(1))?.querySelector(".rule-title");
    active = [...(index.get(slug) ?? []), ...(title ? [title] : [])];
    active.forEach((element) => element.classList.add("is-related"));
    if (target.matches("a.rr-nt")) onReference(target, true, event);
  };
  const leave = (event) => {
    const target = event.target.closest?.(TARGET);
    if (target && target !== event.relatedTarget?.closest?.(TARGET)) {
      clear();
      if (target.matches("a.rr-nt")) onReference(target, false, event);
    }
  };
  root.addEventListener("pointerover", enter);
  root.addEventListener("pointerout", leave);
  root.addEventListener("focusin", enter);
  root.addEventListener("focusout", leave);
}
