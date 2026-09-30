let onRender = () => {};

export function renderDiagram(containerOrRule) {
  const container = containerOrRule?.matches(".diagram-scroll") ? containerOrRule : containerOrRule?.querySelector(".diagram-scroll");
  const placeholder = container?.querySelector(":scope > svg");
  if (!placeholder?.hasAttribute("data-placeholder")) return placeholder;
  const source = container.querySelector(":scope > noscript");
  if (!source) return placeholder;
  const parsed = new DOMParser().parseFromString(source.textContent, "image/svg+xml");
  if (parsed.documentElement.localName !== "svg" || parsed.documentElement.namespaceURI !== "http://www.w3.org/2000/svg" || parsed.querySelector("parsererror")) throw new Error("Invalid diagram SVG");
  const svg = document.importNode(parsed.documentElement, true);
  placeholder.replaceWith(svg);
  source.remove();
  onRender();
  return svg;
}

export function initDiagrams(afterRender = () => {}) {
  onRender = afterRender;
  const containers = [...document.querySelectorAll(".diagram-scroll > svg[data-placeholder]")].map((svg) => svg.parentElement);
  const renderAll = () => containers.forEach(renderDiagram);
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
  containers.forEach((container) => observer.observe(container));
}
