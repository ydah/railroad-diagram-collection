import { rankSearch } from "./match.js";

export function initSearch(input, announce) {
  const list = document.getElementById(input.getAttribute("aria-controls"));
  if (!list) return;
  let loading;
  let entries = [];
  let results = [];
  let selected = -1;
  let dismissed = false;
  const hide = () => {
    list.hidden = true;
    input.setAttribute("aria-expanded", "false");
    input.removeAttribute("aria-activedescendant");
    selected = -1;
  };
  const href = (entry) => {
    try {
      const url = entry.u ? new URL(entry.u, new URL(input.dataset.base || "./", location.href)) : new URL(`#${entry.s}`, location.href);
      return url.origin === location.origin && url.protocol === location.protocol ? url.href : null;
    } catch { return null; }
  };
  const navigate = (index) => {
    const url = results[index] && href(results[index]);
    if (!url) return;
    hide();
    location.assign(url);
  };
  const activate = (index) => {
    selected = index;
    for (const option of list.children) option.setAttribute("aria-selected", String(Number(option.dataset.index) === index));
    const option = list.children[index];
    if (option) {
      input.setAttribute("aria-activedescendant", option.id);
      option.scrollIntoView({ block: "nearest" });
    }
  };
  const render = () => {
    if (dismissed || document.activeElement !== input) return;
    results = rankSearch(entries, input.value).filter((entry) => href(entry));
    list.replaceChildren();
    selected = -1;
    input.removeAttribute("aria-activedescendant");
    if (!results.length) {
      hide();
      if (input.value.trim() && entries.length) announce(document.body.dataset.searchEmpty);
      return;
    }
    results.forEach((entry, index) => {
      const option = document.createElement("li");
      option.id = `search-option-${index}`;
      option.role = "option";
      option.dataset.index = String(index);
      option.setAttribute("aria-selected", "false");
      const name = document.createElement("span");
      name.className = "search-name";
      name.textContent = entry.n;
      const meta = document.createElement("span");
      meta.className = "search-meta";
      meta.textContent = [entry.l, entry.a].filter(Boolean).join(" / ");
      option.append(name, meta);
      list.append(option);
    });
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    if (document.body.dataset.searchCount) announce(document.body.dataset.searchCount.replace("{count}", results.length));
  };
  const load = () => {
    if (loading) return loading;
    let url;
    try { url = new URL(input.dataset.index, location.href); } catch { return Promise.resolve(); }
    if (url.origin !== location.origin) return Promise.resolve();
    loading = fetch(url, { credentials: "same-origin" }).then((response) => {
      if (!response.ok) throw new Error(`Search index: ${response.status}`);
      return response.json();
    }).then((data) => {
      if (!Array.isArray(data)) throw new Error("Invalid search index");
      entries = data.filter((entry) => entry && typeof entry.n === "string" && typeof entry.s === "string" && (!entry.t || Array.isArray(entry.t)));
      render();
    }).catch(() => { loading = undefined; announce(document.body.dataset.searchFailed); });
    return loading;
  };
  input.addEventListener("focus", () => { dismissed = false; load(); render(); });
  input.addEventListener("input", () => { dismissed = false; load(); render(); });
  input.addEventListener("keydown", (event) => {
    if (event.key === "Escape") { event.preventDefault(); dismissed = true; hide(); }
    else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (!results.length) return;
      event.preventDefault();
      dismissed = false;
      list.hidden = false;
      input.setAttribute("aria-expanded", "true");
      activate(selected < 0 ? (event.key === "ArrowDown" ? 0 : results.length - 1) : (selected + (event.key === "ArrowDown" ? 1 : -1) + results.length) % results.length);
    } else if (event.key === "Enter" && selected >= 0 && !list.hidden) {
      event.preventDefault(); navigate(selected);
    } else if (event.key === "Tab") hide();
  });
  input.addEventListener("blur", hide);
  list.addEventListener("pointerdown", (event) => event.preventDefault());
  list.addEventListener("pointermove", (event) => {
    const option = event.target.closest('[role="option"]');
    if (option && Number(option.dataset.index) !== selected) activate(Number(option.dataset.index));
  });
  list.addEventListener("click", (event) => {
    const option = event.target.closest('[role="option"]');
    if (option) navigate(Number(option.dataset.index));
  });
  load();
}
