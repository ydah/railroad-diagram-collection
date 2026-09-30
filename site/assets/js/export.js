const STYLE_PROPERTIES = ["fill", "fill-opacity", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-dasharray", "stroke-opacity", "opacity", "font-family", "font-size", "font-weight", "font-style", "text-anchor", "dominant-baseline"];

export function serializedSvg(svg) {
  const clone = svg.cloneNode(true);
  const originalNodes = [svg, ...svg.querySelectorAll("*")];
  const clonedNodes = [clone, ...clone.querySelectorAll("*")];
  originalNodes.forEach((element, index) => {
    const style = getComputedStyle(element);
    STYLE_PROPERTIES.forEach((property) => clonedNodes[index].style.setProperty(property, style.getPropertyValue(property)));
  });
  clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  clone.setAttribute("width", String(svg.viewBox.baseVal.width || svg.width.baseVal.value));
  clone.setAttribute("height", String(svg.viewBox.baseVal.height || svg.height.baseVal.value));
  clone.style.width = "";
  clone.style.height = "";
  clone.style.backgroundColor = getComputedStyle(svg).backgroundColor;
  const heading = document.getElementById(svg.getAttribute("aria-labelledby"));
  if (heading) { clone.removeAttribute("aria-labelledby"); clone.setAttribute("aria-label", heading.textContent.trim()); }
  clone.querySelectorAll('a[href^="#"]').forEach((link) => link.setAttribute("href", new URL(link.getAttribute("href"), location.href).href));
  return new XMLSerializer().serializeToString(clone);
}

function download(blob, name) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export async function exportDiagram(svg, name, format) {
  const blob = new Blob([serializedSvg(svg)], { type: "image/svg+xml;charset=utf-8" });
  if (format === "svg") { download(blob, `${name}.svg`); return; }
  const url = URL.createObjectURL(blob);
  try {
    const picture = new Image();
    picture.src = url;
    await picture.decode();
    const canvas = document.createElement("canvas");
    canvas.width = Math.ceil((svg.viewBox.baseVal.width || svg.width.baseVal.value) * 2);
    canvas.height = Math.ceil((svg.viewBox.baseVal.height || svg.height.baseVal.value) * 2);
    const context = canvas.getContext("2d");
    if (!context) throw new Error("Canvas unavailable");
    context.fillStyle = getComputedStyle(document.body).backgroundColor;
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(picture, 0, 0, canvas.width, canvas.height);
    const png = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
    if (!png) throw new Error("PNG unavailable");
    download(png, `${name}.png`);
  } finally { URL.revokeObjectURL(url); }
}
