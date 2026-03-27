import { chromium } from "playwright";
import * as fs from "node:fs";

const url = process.argv[2] || "https://example.com";
const outPath = process.argv[3] || "/tmp/captured_clean.html";

const browser = await chromium.launch({ args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 1024, height: 768 } });
await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
await page.waitForTimeout(2000);

const html = await page.evaluate(() => {
  // Inline stylesheets
  const styles = [];
  for (const sheet of document.styleSheets) {
    try {
      const rules = Array.from(sheet.cssRules).map(r => r.cssText).join("\n");
      styles.push(rules);
    } catch {}
  }
  const clone = document.documentElement.cloneNode(true);

  // Remove non-visual elements
  clone.querySelectorAll("script, noscript, template, link[rel='preload'], link[rel='prefetch'], link[rel='dns-prefetch'], link[rel='preconnect']").forEach(el => el.remove());
  clone.querySelectorAll('link[rel="stylesheet"]').forEach(l => l.remove());

  // Remove hidden elements
  clone.querySelectorAll("[hidden]").forEach(el => el.remove());
  
  // Remove closed dialogs
  clone.querySelectorAll("dialog:not([open])").forEach(el => el.remove());

  // Remove elements with display:none computed style
  // (checks actual computed style, not just CSS classes)
  const removeHidden = (root) => {
    const toRemove = [];
    root.querySelectorAll("*").forEach(el => {
      const cs = window.getComputedStyle(el);
      if (cs.display === "none" || cs.visibility === "hidden") {
        toRemove.push(el);
      }
    });
    // Remove from leaf to root to avoid parent removal issues
    toRemove.reverse().forEach(el => {
      if (el.parentNode) el.parentNode.removeChild(el);
    });
  };
  removeHidden(clone);

  // Remove overlay elements: modals, search, dialogs, fixed/sticky positioned
  clone.querySelectorAll("modal-dialog, dialog-helper, qbsearch-input, [role='dialog'], [aria-modal='true']").forEach(el => el.remove());

  // Resolve computed styles for key layout properties on remaining elements
  // This bakes CSS variable resolution and cascade into inline styles
  const layoutProps = ['display', 'position', 'width', 'height', 'max-width', 'margin', 'padding', 'flex-direction', 'flex-wrap', 'gap', 'overflow'];

  // Map original DOM elements to clone elements for computed style extraction
  const origElements = document.querySelectorAll("*");
  const cloneElements = clone.querySelectorAll("*");
  // They may not match due to removals, so skip this approach
  // Instead, just add the inlined styles

  // Add inlined styles
  const head = clone.querySelector("head");
  if (head) {
    for (const css of styles) {
      const style = document.createElement("style");
      style.textContent = css;
      head.appendChild(style);
    }
  }

  // Option: extract main content only (skip header/footer overlays)
  const mainEl = clone.querySelector("main, [role='main'], .application-main, #__next, #app, #root");
  if (mainEl) {
    // Wrap main content with basic HTML + captured styles
    const wrapper = clone.ownerDocument.createElement("html");
    const wrapHead = clone.ownerDocument.createElement("head");
    const wrapBody = clone.ownerDocument.createElement("body");
    // Copy styles
    const origHead = clone.querySelector("head");
    if (origHead) {
      for (const child of Array.from(origHead.children)) {
        if (child.tagName === "STYLE" || child.tagName === "META") {
          wrapHead.appendChild(child.cloneNode(true));
        }
      }
    }
    wrapBody.appendChild(mainEl);
    wrapper.appendChild(wrapHead);
    wrapper.appendChild(wrapBody);
    return "<!DOCTYPE html>" + wrapper.outerHTML;
  }
  return "<!DOCTYPE html>" + clone.outerHTML;
});

fs.writeFileSync(outPath, html);
const origSize = await page.evaluate(() => document.documentElement.outerHTML.length);
console.log(`Captured: ${url}`);
console.log(`  Original: ${origSize.toLocaleString()} chars`);
console.log(`  Cleaned: ${html.length.toLocaleString()} chars (${Math.round(html.length/origSize*100)}%)`);
console.log(`  → ${outPath}`);

await browser.close();
