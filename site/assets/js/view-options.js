export function stored(key, fallback) {
  try { return localStorage.getItem(`rdc:${key}`) ?? fallback; } catch { return fallback; }
}

export function remember(key, value) {
  try { localStorage.setItem(`rdc:${key}`, value); } catch { /* Preferences remain usable without storage. */ }
}

export function initViewOptions() {
  const root = document.documentElement;
  for (const section of document.querySelectorAll("section.rule")) {
    const height = Number(section.querySelector(".diagram-scroll > svg")?.getAttribute("height"));
    if (height > 0) section.style.containIntrinsicSize = `auto ${height + 300}px`;
  }
  for (const [key, allowed, fallback] of [["theme", ["system", "light", "dark"], "system"], ["width", ["raw", "fit"], "raw"]]) {
    const saved = stored(key, fallback);
    root.dataset[key] = allowed.includes(saved) ? saved : fallback;
    const control = document.getElementById(key);
    if (!control) continue;
    control.value = root.dataset[key];
    control.addEventListener("change", () => {
      if (!allowed.includes(control.value)) return;
      root.dataset[key] = control.value;
      remember(key, control.value);
      if (key === "width") document.querySelectorAll(".diagram-scroll > svg").forEach((svg) => { svg.style.width = ""; delete svg.dataset.zoom; });
    });
  }
  root.dataset.internal = stored("internal", "hide") === "show" ? "show" : "hide";
  const internal = document.getElementById("internal");
  if (internal) {
    internal.checked = root.dataset.internal === "show";
    internal.addEventListener("change", () => {
      root.dataset.internal = internal.checked ? "show" : "hide";
      remember("internal", root.dataset.internal);
    });
  }
  const reveal = (fragment) => {
    let id;
    try { id = decodeURIComponent(fragment.slice(1)); } catch { return; }
    const section = document.getElementById(id);
    if (section?.matches('section.rule[data-kind="accept"], section.rule[data-kind="midrule"]') && root.dataset.internal !== "show") {
      root.dataset.internal = "show";
      if (internal) internal.checked = true;
      requestAnimationFrame(() => section.scrollIntoView());
    }
  };
  const revealHash = () => reveal(location.hash);
  revealHash();
  window.addEventListener("hashchange", revealHash);
  document.addEventListener("click", (event) => {
    const link = event.target.closest('a[href^="#"]');
    if (link) reveal(link.getAttribute("href"));
  }, true);
  const updateLinks = () => {
    for (const link of document.querySelectorAll("a[data-preserve-hash]")) {
      const url = new URL(link.getAttribute("href"), location.href);
      if (url.origin !== location.origin) continue;
      url.hash = location.hash;
      link.href = url.href;
    }
  };
  updateLinks();
  window.addEventListener("hashchange", updateLinks);
  document.querySelectorAll("select[data-navigate]").forEach((select) => select.addEventListener("change", () => {
    const url = new URL(select.value, location.href);
    if (url.origin !== location.origin) return;
    url.hash = location.hash;
    location.assign(url.href);
  }));
  const diffFilter = document.getElementById("diff-filter");
  diffFilter?.addEventListener("change", () => {
    document.querySelectorAll("[data-change]").forEach((section) => { section.hidden = diffFilter.value !== "all" && section.dataset.change !== diffFilter.value; });
  });
  const mobile = matchMedia("(max-width: 767px)");
  const updateMenus = () => document.querySelectorAll(".rule-tools-menu").forEach((menu) => { menu.open = !mobile.matches; });
  updateMenus();
  mobile.addEventListener("change", updateMenus);
}
