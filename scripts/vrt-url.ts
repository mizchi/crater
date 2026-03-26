/**
 * One-command URL → VRT comparison.
 *
 * Usage:
 *   npx tsx scripts/vrt-url.ts https://example.com
 *   npx tsx scripts/vrt-url.ts https://example.com --name example-com --width 800 --height 600
 *   npx tsx scripts/vrt-url.ts https://example.com --backend native
 *
 * Captures a URL with Chromium, renders with Crater, compares with pixelmatch.
 * Outputs diff images to output/playwright/vrt/url/<name>/
 */

import { chromium } from "playwright";
import path from "node:path";
import fs from "node:fs";
import { execFileSync } from "node:child_process";
import pixelmatchFn from "pixelmatch";

// --- Args ---
const args = process.argv.slice(2);
const url = args.find((a) => a.startsWith("http"));
if (!url) {
  console.error("Usage: npx tsx scripts/vrt-url.ts <url> [--name slug] [--width N] [--height N] [--backend native|sixel]");
  process.exit(1);
}

function getArg(flag: string, fallback: string): string {
  const idx = args.indexOf(flag);
  return idx >= 0 && idx + 1 < args.length ? args[idx + 1] : fallback;
}

const name = getArg("--name", new URL(url).hostname.replace(/\./g, "-"));
const width = parseInt(getArg("--width", "800"));
const height = parseInt(getArg("--height", "600"));
const backend = getArg("--backend", "sixel");
const threshold = parseFloat(getArg("--threshold", "0.3"));
const outputDir = path.join(process.cwd(), "output", "playwright", "vrt", "url", name);

console.log(`\nVRT: ${url}`);
console.log(`  viewport: ${width}x${height}`);
console.log(`  backend: ${backend}`);
console.log(`  output: ${outputDir}\n`);

// --- Step 1: Capture with Chromium ---
console.log("1. Capturing with Chromium...");
const browser = await chromium.launch({ args: ["--no-sandbox"] });
const context = await browser.newContext({
  viewport: { width, height },
  deviceScaleFactor: 1,
  colorScheme: "light",
});
const page = await context.newPage();
await page.emulateMedia({ colorScheme: "light", reducedMotion: "reduce" });

await page.goto(url, { waitUntil: "load", timeout: 30000 });
await page.waitForTimeout(1000); // Wait for rendering

// Get page HTML (inlined)
const html = await page.evaluate(() => {
  // Inline all stylesheets
  const styles: string[] = [];
  for (const sheet of document.styleSheets) {
    try {
      const rules = Array.from(sheet.cssRules).map((r) => r.cssText).join("\n");
      styles.push(rules);
    } catch {
      // Cross-origin stylesheet, skip
    }
  }
  // Remove scripts, add inline styles
  const clone = document.documentElement.cloneNode(true) as HTMLElement;
  clone.querySelectorAll("script").forEach((s) => s.remove());
  clone.querySelectorAll('link[rel="stylesheet"]').forEach((l) => l.remove());
  // Remove preload/prefetch hints
  clone.querySelectorAll('link[rel="preload"], link[rel="prefetch"], link[rel="dns-prefetch"], link[rel="preconnect"]').forEach((l) => l.remove());
  // Add base href
  const base = document.createElement("base");
  base.href = document.location.href;
  const head = clone.querySelector("head");
  if (head) {
    head.insertBefore(base, head.firstChild);
    for (const css of styles) {
      const style = document.createElement("style");
      style.textContent = css;
      head.appendChild(style);
    }
  }
  return "<!DOCTYPE html>" + clone.outerHTML;
});

const chromiumPng = await page.screenshot({ type: "png" });
await browser.close();

console.log(`   HTML: ${html.length} chars`);
console.log(`   Screenshot: ${chromiumPng.length} bytes`);

// --- Step 2: Render with Crater ---
console.log(`2. Rendering with Crater (${backend})...`);

let craterRgba: Uint8Array;
let craterWidth = width;
let craterHeight = height;

if (backend === "native") {
  // Native: write HTML to file, run crater_paint binary
  fs.writeFileSync("/tmp/crater_paint_input.html", html);
  fs.writeFileSync("/tmp/crater_paint_config.txt", `${width} ${height}`);

  const binCandidates = [
    process.env.CRATER_PAINT_BIN,
    `${process.env.HOME}/ghq/github.com/mizchi/kagura/examples/crater_paint/_build/native/debug/build/crater_paint.exe`,
  ].filter(Boolean) as string[];

  let bin: string | null = null;
  for (const candidate of binCandidates) {
    if (fs.existsSync(candidate)) { bin = candidate; break; }
  }
  if (!bin) {
    console.error("Error: crater_paint binary not found");
    process.exit(1);
  }

  const cwd = `${process.env.HOME}/ghq/github.com/mizchi/kagura/examples/crater_paint`;
  const result = execFileSync(bin, [], { cwd, timeout: 120000, maxBuffer: 10 * 1024 * 1024 });
  if (!result.toString().includes("OK")) {
    console.error("Error: crater_paint failed:", result.toString());
    process.exit(1);
  }

  // Read BMP
  const bmpData = fs.readFileSync("/tmp/crater_paint_output.bmp");
  const bmpOffset = bmpData.readUInt32LE(10);
  const bmpW = bmpData.readInt32LE(18);
  const bmpH = Math.abs(bmpData.readInt32LE(22));
  const bpp = bmpData.readUInt16LE(28) / 8;
  const rowStride = Math.ceil(bmpW * bpp / 4) * 4;
  craterRgba = new Uint8Array(bmpW * bmpH * 4);
  craterWidth = bmpW;
  craterHeight = bmpH;
  for (let y = 0; y < bmpH; y++) {
    const srcRow = bmpH - 1 - y;
    const srcOffset = bmpOffset + srcRow * rowStride;
    for (let x = 0; x < bmpW; x++) {
      const si = srcOffset + x * bpp;
      const di = (y * bmpW + x) * 4;
      craterRgba[di] = bmpData[si + 2];     // R
      craterRgba[di + 1] = bmpData[si + 1]; // G
      craterRgba[di + 2] = bmpData[si];     // B
      craterRgba[di + 3] = 255;
    }
  }
} else {
  // Sixel: use BiDi server (must be running)
  const WebSocket = (await import("ws")).default;
  const ws = new WebSocket("ws://127.0.0.1:9222");
  let cmdId = 0;
  const pending = new Map<number, { resolve: (v: any) => void }>();

  await new Promise<void>((resolve, reject) => {
    ws.on("open", resolve);
    ws.on("error", reject);
  });
  ws.on("message", (data: Buffer) => {
    const msg = JSON.parse(data.toString());
    const p = pending.get(msg.id);
    if (p) { pending.delete(msg.id); p.resolve(msg); }
  });

  const send = (method: string, params: any) => new Promise<any>((resolve) => {
    const id = ++cmdId;
    pending.set(id, { resolve });
    ws.send(JSON.stringify({ id, method, params }));
  });

  const createResp = await send("browsingContext.create", { type: "tab" });
  const contextId = createResp.result.context;
  await send("browsingContext.setViewport", { context: contextId, viewport: { width, height } });

  const dataUrl = `data:text/html;base64,${Buffer.from(html).toString("base64")}`;
  await send("browsingContext.navigate", { context: contextId, url: dataUrl, wait: "complete" });
  await send("script.evaluate", {
    expression: `__loadHTML(${JSON.stringify(html)})`,
    target: { context: contextId },
    awaitPromise: false,
  });

  const paintResp = await send("browsingContext.capturePaintData", { context: contextId, origin: "viewport" });
  const paintResult = paintResp.result;
  craterWidth = paintResult.width;
  craterHeight = paintResult.height;
  craterRgba = Uint8Array.from(Buffer.from(paintResult.data, "base64"));

  await send("browsingContext.close", { context: contextId });
  ws.close();
}

console.log(`   Crater: ${craterWidth}x${craterHeight}`);

// --- Step 3: Compare ---
console.log("3. Comparing...");

// Decode Chromium PNG to RGBA
const chromiumBrowser = await chromium.launch({ args: ["--no-sandbox"] });
const decodePage = await chromiumBrowser.newPage();
const decoded = await decodePage.evaluate(async (base64Png: string) => {
  const bytes = Uint8Array.from(atob(base64Png), (c) => c.charCodeAt(0));
  const blob = new Blob([bytes], { type: "image/png" });
  const bitmap = await createImageBitmap(blob);
  const canvas = document.createElement("canvas");
  canvas.width = bitmap.width;
  canvas.height = bitmap.height;
  const ctx = canvas.getContext("2d")!;
  ctx.drawImage(bitmap, 0, 0);
  const imageData = ctx.getImageData(0, 0, bitmap.width, bitmap.height);
  return { width: bitmap.width, height: bitmap.height, data: Array.from(imageData.data) };
}, chromiumPng.toString("base64"));
await chromiumBrowser.close();

const chromiumRgba = Uint8Array.from(decoded.data);

if (decoded.width !== craterWidth || decoded.height !== craterHeight) {
  console.error(`Size mismatch: Chromium ${decoded.width}x${decoded.height} vs Crater ${craterWidth}x${craterHeight}`);
  process.exit(1);
}

const w = decoded.width;
const h = decoded.height;
const diffOutput = new Uint8Array(w * h * 4);
const diffPixels = pixelmatchFn(chromiumRgba, craterRgba, diffOutput, w, h, { threshold });
const totalPixels = w * h;
const diffRatio = diffPixels / totalPixels;

// --- Step 4: Save outputs ---
fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(path.join(outputDir, "chromium.png"), chromiumPng);

// Encode crater + diff as PNG via canvas (reuse chromium for encoding)
const encodeBrowser = await chromium.launch({ args: ["--no-sandbox"] });
const encodePage = await encodeBrowser.newPage();

async function encodePng(rgba: Uint8Array, w: number, h: number): Promise<Buffer> {
  const base64 = await encodePage.evaluate(async (payload: { data: number[]; width: number; height: number }) => {
    const canvas = document.createElement("canvas");
    canvas.width = payload.width;
    canvas.height = payload.height;
    const ctx = canvas.getContext("2d")!;
    const imageData = new ImageData(Uint8ClampedArray.from(payload.data), payload.width, payload.height);
    ctx.putImageData(imageData, 0, 0);
    return canvas.toDataURL("image/png").replace(/^data:image\/png;base64,/, "");
  }, { data: Array.from(rgba), width: w, height: h });
  return Buffer.from(base64, "base64");
}

fs.writeFileSync(path.join(outputDir, "crater.png"), await encodePng(craterRgba, w, h));
fs.writeFileSync(path.join(outputDir, "diff.png"), await encodePng(diffOutput, w, h));
await encodeBrowser.close();

fs.writeFileSync(path.join(outputDir, "report.json"), JSON.stringify({
  url, name, width: w, height: h,
  backend, threshold,
  diffPixels, totalPixels, diffRatio,
  timestamp: new Date().toISOString(),
}, null, 2));

// --- Report ---
const pct = (diffRatio * 100).toFixed(2);
const status = diffRatio <= 0.05 ? "PASS" : diffRatio <= 0.15 ? "WARN" : "FAIL";
console.log(`\n${status}: ${pct}% diff (${diffPixels}/${totalPixels} pixels)`);
console.log(`  Output: ${outputDir}/`);
