import { chromium } from "playwright";
import * as fs from "node:fs";

const url = process.argv[2] || "https://preactjs.com";
const outPath = "/tmp/captured_site.html";

const browser = await chromium.launch({ args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
await page.waitForTimeout(2000);

const html = await page.evaluate(() => {
  const styles = [];
  for (const sheet of document.styleSheets) {
    try {
      const rules = Array.from(sheet.cssRules).map(r => r.cssText).join("\n");
      styles.push(rules);
    } catch {}
  }
  const clone = document.documentElement.cloneNode(true);
  clone.querySelectorAll("script").forEach(s => s.remove());
  clone.querySelectorAll('link[rel="stylesheet"]').forEach(l => l.remove());
  clone.querySelectorAll('link[rel="preload"], link[rel="prefetch"], link[rel="dns-prefetch"], link[rel="preconnect"]').forEach(l => l.remove());
  const head = clone.querySelector("head");
  if (head) {
    for (const css of styles) {
      const style = document.createElement("style");
      style.textContent = css;
      head.appendChild(style);
    }
  }
  return "<!DOCTYPE html>" + clone.outerHTML;
});

fs.writeFileSync(outPath, html);
console.log(`Captured: ${url} (${html.length} chars) → ${outPath}`);
await browser.close();
