import { normalize, matchScore } from "./match.js";

export function initToc() {
  const toc = document.querySelector(".toc");
  if (!toc) return;
  const input = toc.querySelector(".toc-filter");
  const items = [...toc.querySelectorAll("li[data-name]")].map((li) => {
    let aliases;
    try { const value = JSON.parse(li.dataset.alias || "[]"); aliases = Array.isArray(value) ? value : [value]; }
    catch { aliases = (li.dataset.alias || "").split(/\s+/); }
    return { li, keys: [li.dataset.name, ...aliases].filter((value) => typeof value === "string" && value) };
  });
  input?.addEventListener("input", () => {
    const query = normalize(input.value);
    for (const { li, keys } of items) li.hidden = !!query && !keys.some((key) => matchScore(query, key) > 0);
  });
  const links = new Map([...toc.querySelectorAll('a[href^="#"]')].map((link) => [link.getAttribute("href").slice(1), link]));
  let current;
  const setCurrent = (id) => {
    if (current === links.get(id)) return;
    current?.removeAttribute("aria-current");
    current = links.get(id);
    current?.setAttribute("aria-current", "true");
  };
  const fromHash = () => {
    let id;
    try { id = decodeURIComponent(location.hash.slice(1)); } catch { return; }
    setCurrent(id);
  };
  fromHash();
  window.addEventListener("hashchange", fromHash);
  if ("IntersectionObserver" in window) {
    const visible = new Set();
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) entry.isIntersecting ? visible.add(entry.target) : visible.delete(entry.target);
      const first = [...visible].sort((a, b) => a.getBoundingClientRect().top - b.getBoundingClientRect().top)[0];
      if (first) setCurrent(first.id);
    }, { rootMargin: "-80px 0px -55% 0px" });
    document.querySelectorAll("section.rule").forEach((rule) => observer.observe(rule));
  }
  const toggle = document.getElementById("toc-toggle");
  if (!toggle) return;
  const mobile = matchMedia("(max-width: 767px)");
  const backdrop = document.createElement("button");
  backdrop.className = "toc-backdrop";
  backdrop.type = "button";
  backdrop.tabIndex = -1;
  backdrop.setAttribute("aria-label", toggle.dataset.close ?? toggle.getAttribute("aria-label") ?? toggle.textContent);
  backdrop.hidden = true;
  document.body.append(backdrop);
  const setOpen = (open, restore = true) => {
    document.documentElement.dataset.toc = open ? "open" : "closed";
    toggle.setAttribute("aria-expanded", String(open));
    backdrop.hidden = !open;
    if (open) input?.focus();
    else if (restore && mobile.matches) toggle.focus();
  };
  toggle.addEventListener("click", () => setOpen(toggle.getAttribute("aria-expanded") !== "true"));
  backdrop.addEventListener("click", () => setOpen(false));
  toc.addEventListener("click", (event) => {
    if (event.target.closest('a[href^="#"]')) setOpen(false, false);
    if (event.target.closest('[data-action="close-toc"]')) setOpen(false);
  });
  toc.addEventListener("keydown", (event) => {
    if (!mobile.matches || document.documentElement.dataset.toc !== "open") return;
    if (event.key === "Escape") { event.preventDefault(); setOpen(false); }
    if (event.key !== "Tab") return;
    const focusable = [...toc.querySelectorAll('a[href], button, input, select, [tabindex="0"]')].filter((element) => element.getClientRects().length);
    const first = focusable[0];
    const last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
    if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
  });
  mobile.addEventListener("change", () => setOpen(false, false));
}
