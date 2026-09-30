let onRender = () => {};

export function renderDiagram(containerOrRule) {
  const rule = containerOrRule?.closest("section.rule");
  const placeholder = rule?.querySelector(":scope > figure[data-placeholder]");
  if (!placeholder) return rule?.querySelector(".diagram-scroll > svg");
  const source = rule.querySelector(":scope > noscript");
  if (!source) return placeholder.querySelector("svg");
  const template = document.createElement("template");
  template.innerHTML = source.textContent;
  const svg = template.content.querySelector(".diagram-scroll > svg");
  if (!svg || svg.namespaceURI !== "http://www.w3.org/2000/svg") throw new Error("Invalid diagram SVG");
  const menu = template.content.querySelector(".rule-tools-menu");
  if (menu) {
    menu.open = !matchMedia("(max-width: 767px)").matches;
    rule.querySelector(":scope > .rule-head").append(menu);
  }
  const focused = placeholder.contains(document.activeElement);
  placeholder.replaceWith(template.content);
  source.remove();
  onRender();
  if (focused) svg.parentElement.focus({ preventScroll: true });
  return svg;
}

export function initDiagrams(afterRender = () => {}) {
  onRender = afterRender;
  const rules = [...document.querySelectorAll("section.rule > figure[data-placeholder]")].map((figure) => figure.parentElement);
  const renderAll = () => rules.forEach(renderDiagram);
  const renderHash = () => {
    let id;
    try { id = decodeURIComponent(location.hash.slice(1)); } catch { return; }
    const target = document.getElementById(id);
    renderDiagram(target?.closest("section.rule") ?? target);
  };
  renderHash();
  window.addEventListener("hashchange", renderHash);
  window.addEventListener("beforeprint", renderAll);
  if (typeof window.IntersectionObserver !== "function") { renderAll(); return; }
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      renderDiagram(entry.target);
      observer.unobserve(entry.target);
    }
  }, { rootMargin: "200px" });
  rules.forEach((rule) => observer.observe(rule));
}
