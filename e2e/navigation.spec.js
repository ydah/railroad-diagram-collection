import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { readFile } from "node:fs/promises";

test("native rule links preserve browser history", async ({ page }) => {
  await page.goto("/php/8.5/#r-start");
  const link = page.locator("#r-start a.rr-nt").first();
  const target = await link.getAttribute("href");
  await link.click();
  expect(new URL(page.url()).hash).toBe(target);
  await page.goBack();
  expect(new URL(page.url()).hash).toBe("#r-start");
});

test("375px diagrams stay full size inside their scroll region", async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 800 });
  await page.goto("/php/8.5/");
  await page.evaluate(() => window.dispatchEvent(new Event("beforeprint")));
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(375);
  const widest = await page.locator(".diagram-scroll > svg").evaluateAll((elements) => Math.max(...elements.map((svg) => svg.getBoundingClientRect().width)));
  expect(widest).toBeGreaterThan(1000);
  await page.selectOption("#width", "fit");
  const widths = await page.locator(".diagram-scroll > svg").evaluateAll((elements) => elements.map((svg) => svg.getBoundingClientRect().width));
  expect(Math.max(...widths)).toBeLessThan(375);
});

test("filter, lazy token search, locale and version switches", async ({ page }) => {
  await page.goto("/php/8.5/");
  await page.locator(".toc-filter").fill("attributedtop");
  await expect(page.locator(".toc-rules li:visible")).toHaveCount(1);
  await page.locator("#search").fill("abstract");
  await expect(page.locator("#search-results")).toBeVisible();
  await page.locator("#search").press("ArrowDown");
  await page.locator("#search").press("Enter");
  await expect(page).toHaveURL(/\/php\/8\.5\//);
  await page.goto("/php/8.5/#r-start");
  await page.locator('.version-nav a').filter({ hasText: /^8\.4$/ }).click();
  await expect(page).toHaveURL(/\/php\/8\.4\/#r-start$/);
  await page.locator('a[lang="ja"]').click();
  await expect(page).toHaveURL(/\/ja\/php\/8\.4\/#r-start$/);
});

test("theme persists and raw-mode hash is preserved", async ({ page }) => {
  await page.goto("/ruby/4.0/#r-program");
  await page.selectOption("#theme", "dark");
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.locator('.view-options a').filter({ hasText: "Original grammar" }).click();
  await expect(page).toHaveURL(/\/raw\/#r-program$/);
});

test("legacy URL redirects keep fragments", async ({ page }) => {
  await page.goto("/ruby.html#r-program");
  await expect(page).toHaveURL(/\/ruby\/#r-program$/);
});

test("no scripts required for rule navigation and internal deep links", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:4173/ruby/4.0/#r-~24accept");
  expect(await page.locator("section.rule noscript svg:not([data-placeholder])").count()).toBe(await page.locator("section.rule").count());
  await expect(page.locator("svg[data-placeholder]:visible")).toHaveCount(0);
  await expect(page.locator('#r-\\~24accept')).toBeVisible();
  await page.locator('#r-program a.rr-nt').first().click();
  expect(new URL(page.url()).hash).not.toBe("#r-~24accept");
  await context.close();
});

test("large grammars render nearby diagrams, deep links and all diagrams for printing", async ({ page }) => {
  await page.goto("/postgresql/18/");
  await expect(page.locator("section.rule > noscript").first()).toBeHidden();
  await expect(page.locator(".diagram-scroll > svg:not([data-placeholder])").first()).toBeVisible();
  expect(await page.locator(".diagram-scroll > svg:not([data-placeholder])").count()).toBeLessThan(20);
  const link = page.locator('.toc-rules li[data-kind="normal"] a').last();
  const target = await link.getAttribute("href");
  await link.click();
  await expect(page.locator(`${target} .diagram-scroll > svg`)).not.toHaveAttribute("data-placeholder");
  await page.evaluate(() => window.dispatchEvent(new Event("beforeprint")));
  await expect(page.locator("svg[data-placeholder]")).toHaveCount(0);
  expect(await page.locator("section.rule .diagram-scroll > svg").count()).toBe(await page.locator("section.rule").count());
});

test("diagram pixels match stored visual baselines in light and dark themes", async ({ page, context }) => {
  await page.goto("/");
  const cssPath = await page.locator('link[rel="stylesheet"]').getAttribute("href");
  const css = await (await page.request.get(cssPath)).text();
  const diagrams = await page.locator(".legend svg").evaluateAll((elements) => elements.map((element) => element.outerHTML));
  await page.goto("/ruby/4.0/");
  await page.evaluate(() => window.dispatchEvent(new Event("beforeprint")));
  for (const name of ["program", "defn_head"]) diagrams.push(await page.locator(`#r-${name} svg`).evaluate((element) => element.outerHTML));
  const actual = await context.newPage();
  const baseline = await context.newPage();
  await actual.setContent(`<!DOCTYPE html><html><head><style>${css}</style></head><body>${diagrams.join("")}</body></html>`);
  await baseline.setContent(await readFile("test/fixtures/visual/diagrams.html", "utf8"));
  for (const theme of ["light", "dark"]) {
    for (const target of [actual, baseline]) await target.locator("html").evaluate((element, value) => { element.dataset.theme = value; }, theme);
    for (let index = 0; index < diagrams.length; index++) {
      const expected = await baseline.locator("svg").nth(index).screenshot();
      expect(await actual.locator("svg").nth(index).screenshot()).toEqual(expected);
    }
  }
  await actual.close();
  await baseline.close();
});

test("preview, shortcuts and standalone image exports work under the content policy", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto("/ruby/4.0/#r-program");
  const link = page.locator("#r-program a.rr-nt").first();
  await link.focus();
  await expect(page.locator(".rule-preview")).toBeVisible();
  await link.press("ArrowRight");
  await page.keyboard.press("Escape");
  await expect(link).toBeFocused();
  await page.keyboard.press("?");
  await expect(page.locator("#shortcut-help")).toBeVisible();
  await page.keyboard.press("Escape");
  for (const format of ["svg", "png"]) {
    const download = page.waitForEvent("download");
    await page.locator(`#r-program [data-action="${format}"]`).click();
    expect((await download).suggestedFilename()).toMatch(new RegExp(`\\.${format}$`));
  }
  expect(errors).toEqual([]);
});

test("preview server honors gzip negotiation", async ({ request }) => {
  expect((await request.get("/", { headers: { "Accept-Encoding": "gzip" } })).headers()["content-encoding"]).toBe("gzip");
  expect((await request.get("/", { headers: { "Accept-Encoding": "gzip;q=0" } })).headers()["content-encoding"]).toBeUndefined();
});

for (const path of ["/", "/ruby/4.0/", "/php/8.5/", "/perl/5.44/", "/java/2026-09/", "/go/2026-06/", "/jq/1.8.2/", "/postgresql/18/", "/mruby/4.0/", "/php/diff/8.4...8.5/"]) {
  test(`axe and local-only requests: ${path}`, async ({ page }) => {
    test.setTimeout(600_000);
    const external = [];
    page.on("request", (request) => { if (new URL(request.url()).origin !== "http://127.0.0.1:4173") external.push(request.url()); });
    await page.goto(path);
    const results = await new AxeBuilder({ page }).analyze();
    expect(results.violations.map(({ id, nodes }) => ({ id, nodes: nodes.map((node) => node.target) }))).toEqual([]);
    // Keep every rule, but audit bounded DOM groups to avoid axe's quadratic full-grammar scans.
    const rules = await page.evaluate(() => {
      window.dispatchEvent(new Event("beforeprint"));
      document.documentElement.dataset.internal = "show";
      window.auditRules = [...document.querySelectorAll("section.rule")];
      for (const rule of window.auditRules) rule.remove();
      return window.auditRules.map((rule) => rule.id);
    });
    for (let start = 0; start < rules.length; start += 50) {
      await page.evaluate((start) => {
        for (const rule of document.querySelectorAll("section.rule")) rule.remove();
        for (const rule of window.auditRules.slice(start, start + 50)) {
          rule.style.contentVisibility = "visible";
          document.querySelector("main").append(rule);
        }
      }, start);
      const audit = new AxeBuilder({ page });
      for (const id of rules.slice(start, start + 50)) audit.include(`[id="${id}"]`);
      const diagrams = await audit.analyze();
      expect(diagrams.violations.map(({ id, nodes }) => ({ id, nodes: nodes.map((node) => node.target) }))).toEqual([]);
    }
    expect(external).toEqual([]);
  });
}
