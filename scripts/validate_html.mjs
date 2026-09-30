import { glob } from "node:fs/promises";
import { spawn } from "node:child_process";

// Validate one page per process so the complete multilingual site fits CI memory.
let count = 0;
for await (const path of glob("dist/**/*.html")) {
  await new Promise((resolve, reject) => {
    const child = spawn("node_modules/.bin/html-validate", [path], { stdio: "inherit" });
    child.on("error", reject);
    child.on("exit", (code) => code === 0 ? resolve() : reject(new Error(`Invalid HTML: ${path}`)));
  });
  count++;
}
if (!count) throw new Error("Build dist first");
console.log(`Validated ${count} HTML pages.`);
