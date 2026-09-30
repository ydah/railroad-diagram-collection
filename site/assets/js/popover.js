export function initPopover() {
  const popover = document.createElement("div");
  popover.id = "rule-preview";
  popover.className = "rule-preview";
  popover.role = "dialog";
  popover.setAttribute("aria-label", document.body.dataset.previewLabel ?? "");
  popover.hidden = true;
  document.body.append(popover);
  let trigger;
  let timer;
  let dismissed;
  const hide = () => {
    clearTimeout(timer);
    popover.hidden = true;
    trigger?.removeAttribute("aria-expanded");
    trigger?.removeAttribute("aria-controls");
  };
  const close = (restore = false) => {
    const previous = trigger;
    dismissed = trigger;
    hide();
    if (restore) previous?.focus();
  };
  const position = () => {
    if (!trigger || popover.hidden) return;
    const rect = trigger.getBoundingClientRect();
    const width = popover.offsetWidth;
    const height = popover.offsetHeight;
    const left = Math.min(Math.max(16, rect.left), window.innerWidth - width - 16);
    const top = rect.bottom + height + 12 < window.innerHeight ? rect.bottom + 8 : Math.max(12, rect.top - height - 8);
    popover.style.left = `${left}px`;
    popover.style.top = `${top}px`;
  };
  const show = (link) => {
    const section = document.getElementById(link.getAttribute("href")?.slice(1));
    const svg = section?.querySelector(".diagram-scroll > svg");
    if (!svg) return;
    hide();
    trigger = link;
    const head = document.createElement("div");
    head.className = "preview-head";
    const title = document.createElement("strong");
    title.textContent = section.querySelector(".rule-title")?.textContent.trim() ?? section.id;
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = document.body.dataset.previewClose;
    button.addEventListener("click", () => close(true));
    head.append(title, button);
    const diagram = document.createElement("div");
    diagram.className = "diagram-scroll";
    diagram.tabIndex = 0;
    diagram.role = "region";
    diagram.setAttribute("aria-label", `${document.body.dataset.previewLabel} ${title.textContent}`);
    const clone = svg.cloneNode(true);
    clone.removeAttribute("aria-labelledby");
    clone.setAttribute("aria-label", title.textContent);
    clone.style.width = "";
    clone.querySelectorAll("[id]").forEach((element) => element.removeAttribute("id"));
    clone.querySelectorAll("a").forEach((element) => { element.setAttribute("tabindex", "-1"); element.classList.remove("is-related"); });
    const open = document.createElement("a");
    open.href = link.getAttribute("href");
    open.className = "preview-open";
    open.textContent = document.body.dataset.previewOpen;
    diagram.append(clone);
    popover.replaceChildren(head, diagram, open);
    popover.hidden = false;
    link.setAttribute("aria-expanded", "true");
    link.setAttribute("aria-controls", popover.id);
    position();
  };
  const reference = (link, entered, event) => {
    if (link === dismissed) {
      if (!entered) dismissed = undefined;
      return;
    }
    if (entered) {
      hide();
      timer = setTimeout(() => show(link), 300);
    } else if (document.activeElement !== link && !link.matches(":hover") && !popover.contains(event.relatedTarget)) {
      clearTimeout(timer);
      timer = setTimeout(() => {
      if (!popover.matches(":hover") && !popover.contains(document.activeElement) && document.activeElement !== trigger) hide();
      }, 150);
    }
  };
  popover.addEventListener("pointerenter", () => clearTimeout(timer));
  popover.addEventListener("pointerleave", () => {
    if (!popover.contains(document.activeElement) && !trigger?.matches(":hover")) hide();
  });
  popover.addEventListener("focusout", (event) => {
    if (!popover.contains(event.relatedTarget) && event.relatedTarget !== trigger) hide();
  });
  popover.addEventListener("click", (event) => { if (event.target.closest("a")) hide(); });
  document.addEventListener("keydown", (event) => {
    if (popover.hidden) return;
    if (event.key === "Escape") { event.preventDefault(); close(popover.contains(document.activeElement)); }
    else if ((event.key === "ArrowRight" || (event.key === "Tab" && !event.shiftKey)) && document.activeElement === trigger) {
      event.preventDefault(); popover.querySelector("button")?.focus();
    }
  });
  const onViewportChange = () => { if (!popover.hidden) hide(); };
  window.addEventListener("scroll", onViewportChange, { passive: true });
  window.addEventListener("resize", onViewportChange, { passive: true });
  return { reference };
}
