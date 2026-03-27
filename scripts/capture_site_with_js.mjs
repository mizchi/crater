import { chromium } from "playwright";
import * as fs from "node:fs";

const url = process.argv[2] || "https://example.com";
const outPath = process.argv[3] || "/tmp/captured_with_js.html";

const browser = await chromium.launch({ args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 800, height: 600 } });

// Intercept scripts to capture their content
const scriptContents = new Map();
page.on("response", async (response) => {
  const reqUrl = response.url();
  if (reqUrl.endsWith(".js") || response.headers()["content-type"]?.includes("javascript")) {
    try {
      const body = await response.text();
      scriptContents.set(reqUrl, body);
    } catch {}
  }
});

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
await page.waitForTimeout(1000);

const html = await page.evaluate((scripts) => {
  const styles = [];
  for (const sheet of document.styleSheets) {
    try {
      const rules = Array.from(sheet.cssRules).map(r => r.cssText).join("\n");
      styles.push(rules);
    } catch {}
  }
  const clone = document.documentElement.cloneNode(true);
  // Remove external link stylesheets
  clone.querySelectorAll('link[rel="stylesheet"]').forEach(l => l.remove());
  clone.querySelectorAll('link[rel="preload"], link[rel="prefetch"]').forEach(l => l.remove());
  
  // Inline external scripts
  clone.querySelectorAll("script[src]").forEach(s => {
    const src = s.getAttribute("src");
    const fullUrl = new URL(src, location.href).href;
    const content = scripts[fullUrl];
    if (content) {
      s.removeAttribute("src");
      s.textContent = content;
    } else {
      s.remove(); // Can't inline, remove
    }
  });
  
  // Add inlined styles
  const head = clone.querySelector("head");
  if (head) {
    for (const css of styles) {
      const style = document.createElement("style");
      style.textContent = css;
      head.appendChild(style);
    }
  }
  return "<!DOCTYPE html>" + clone.outerHTML;
}, Object.fromEntries(scriptContents));

fs.writeFileSync(outPath, html);
console.log(`Captured: ${url} (${html.length} chars, ${scriptContents.size} scripts inlined) → ${outPath}`);
await browser.close();
