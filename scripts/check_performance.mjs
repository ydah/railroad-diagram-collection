import { spawn } from "node:child_process";
import { mkdir, readFile, stat } from "node:fs/promises";
import { chromium } from "@playwright/test";

const run = (command, args, options = {}) => new Promise((resolve, reject) => {
  const child = spawn(command, args, { stdio: "inherit", ...options });
  child.on("error", reject);
  child.on("exit", (code) => code === 0 ? resolve() : reject(new Error(`${command} exited ${code}`)));
});

const server = spawn("bundle", ["exec", "exe/rdc", "serve", "--port", "4175"], { stdio: "ignore" });
try {
  for (let attempt = 0; attempt < 100; attempt++) {
    try { if ((await fetch("http://127.0.0.1:4175/")).ok) break; } catch { /* Wait for the local server. */ }
    if (attempt === 99) throw new Error("Preview server did not start");
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  await mkdir(".lighthouseci/reports", { recursive: true });
  const index = JSON.parse(await readFile("dist/api/v1/index.json", "utf8"));
  const pages = await Promise.all(index.languages.map(async (language) => {
    const version = language.versions.find((entry) => entry.default);
    if (!version) return null;
    const path = `${language.id}/${version.id}/`;
    return { path, size: (await stat(`dist/${path}index.html`)).size };
  }));
  const largest = pages.filter(Boolean).sort((a, b) => b.size - a.size)[0];
  console.log(`Mobile budget: /${largest.path} (${largest.size} HTML bytes)`);
  const scores = {};
  for (let runIndex = 0; runIndex < 3; runIndex++) {
    const path = `.lighthouseci/reports/page-${runIndex}`;
    await run(process.execPath, ["node_modules/lighthouse/cli/index.js", `http://127.0.0.1:4175/${largest.path}`,
      "--quiet", "--chrome-flags=--headless --no-sandbox --disable-dev-shm-usage", "--output=json", "--output=html", `--output-path=${path}`],
    { env: { ...process.env, CHROME_PATH: chromium.executablePath() } });
    const report = JSON.parse(await readFile(`${path}.report.json`, "utf8"));
    for (const [name, category] of Object.entries(report.categories)) (scores[name] ??= []).push(category.score);
  }
  const budgets = { performance: .9, accessibility: 1, "best-practices": 1, seo: 1 };
  for (const [name, minimum] of Object.entries(budgets)) {
    const median = scores[name].sort((a, b) => a - b)[1];
    console.log(`${name}: ${Math.round(median * 100)} (minimum ${minimum * 100})`);
    if (median < minimum) throw new Error(`${name} exceeds the performance budget`);
  }
} finally {
  server.kill("SIGTERM");
}
