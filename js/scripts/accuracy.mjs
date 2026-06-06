#!/usr/bin/env node
// Accuracy gate: render fixtures with crater (software backend) and with
// real Chromium (Playwright screenshot), and assert crater is close enough
// to the browser to be useful as an E2E / VRT oracle. Axis-aligned content
// is expected to match pixel-for-pixel; rounded corners differ only by
// anti-aliasing. Skips gracefully when no browser is available.
import zlib from "node:zlib";
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

async function loadChromium() {
  try { return (await import("playwright")).chromium; }
  catch {
    const { createRequire } = await import("node:module");
    const require = createRequire(import.meta.url);
    for (const c of [resolve(__dirname, "../node_modules/playwright"), resolve(__dirname, "../../node_modules/playwright"), "/opt/node22/lib/node_modules/playwright"]) {
      try { return require(c).chromium; } catch {}
    }
    return null;
  }
}

function paeth(a, b, c) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); return pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
function decodePng(buf) {
  let pos = 8, w = 0, h = 0, ct = 6; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos); const type = buf.toString("ascii", pos + 4, pos + 8); const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === "IHDR") { w = data.readUInt32BE(0); h = data.readUInt32BE(4); ct = data[9]; }
    else if (type === "IDAT") idat.push(data); else if (type === "IEND") break;
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const ch = ct === 6 ? 4 : ct === 2 ? 3 : 1, stride = w * ch, out = Buffer.alloc(h * stride);
  let rp = 0;
  for (let y = 0; y < h; y++) {
    const f = raw[rp++];
    for (let x = 0; x < stride; x++) {
      const v = raw[rp++];
      const a = x >= ch ? out[y * stride + x - ch] : 0, b = y > 0 ? out[(y - 1) * stride + x] : 0, c = x >= ch && y > 0 ? out[(y - 1) * stride + x - ch] : 0;
      let val; switch (f) { case 1: val = v + a; break; case 2: val = v + b; break; case 3: val = v + ((a + b) >> 1); break; case 4: val = v + paeth(a, b, c); break; default: val = v; }
      out[y * stride + x] = val & 0xff;
    }
  }
  const rgba = new Array(w * h * 4);
  for (let i = 0; i < w * h; i++) { rgba[i * 4] = out[i * ch]; rgba[i * 4 + 1] = out[i * ch + (ch > 1 ? 1 : 0)]; rgba[i * 4 + 2] = out[i * ch + (ch > 2 ? 2 : 0)]; rgba[i * 4 + 3] = ch === 4 ? out[i * ch + 3] : 255; }
  return { w, h, rgba };
}
function compare(a, b) {
  let max = 0, diff = 0; const n = a.length / 4;
  for (let i = 0; i < a.length; i += 4) {
    let d = 0; for (let k = 0; k < 3; k++) d = Math.max(d, Math.abs(a[i + k] - b[i + k]));
    if (d > max) max = d; if (d > 16) diff++;
  }
  return { max, diffPx: diff, total: n, diffPct: (100 * diff / n) };
}

const wrap = (inner) => `<!doctype html><html><head><style>html,body{margin:0;padding:0}</style></head><body>${inner}</body></html>`;
const FIXTURES = [
  { name: "solid", w: 80, h: 60, maxDiffPct: 0.5, html: wrap(`<div style="width:60px;height:40px;background:rgb(51,102,204)"></div>`) },
  { name: "two-boxes", w: 80, h: 60, maxDiffPct: 0.5, html: wrap(`<div style="width:40px;height:20px;background:#c33"></div><div style="width:40px;height:20px;background:#3a5"></div>`) },
  { name: "border", w: 60, h: 50, maxDiffPct: 0.5, html: wrap(`<div style="width:40px;height:30px;border:4px solid #2244cc;background:#ffee88;box-sizing:border-box"></div>`) },
  { name: "nested", w: 60, h: 60, maxDiffPct: 0.5, html: wrap(`<div style="width:50px;height:50px;background:#222"><div style="width:20px;height:20px;background:#dd4"></div></div>`) },
  { name: "flex-row", w: 90, h: 30, maxDiffPct: 0.5, html: wrap(`<div style="display:flex"><div style="width:30px;height:30px;background:#c33"></div><div style="width:30px;height:30px;background:#3a5"></div><div style="width:30px;height:30px;background:#35c"></div></div>`) },
  // A first child's top margin collapses through the body and shifts the box
  // down; the renderer must translate nodes by their accumulated ancestor
  // offset (paint coords are parent-relative), not paint them at the origin.
  { name: "margin-top", w: 60, h: 50, maxDiffPct: 0.5, html: wrap(`<div style="width:30px;height:20px;background:#39c;margin:10px"></div>`) },
  // box-shadow is a hard offset rect; its only Chromium delta was the same
  // dropped-margin offset, so this pins both at once.
  { name: "box-shadow", w: 60, h: 50, maxDiffPct: 0.5, html: wrap(`<div style="width:24px;height:24px;background:#000;box-shadow:4px 4px 0 #888;margin:6px"></div>`) },
  // Axis-aligned linear gradients lower to 1px solid strips along the axis and
  // match the browser pixel-for-pixel (the few-LSB delta is gradient colour
  // interpolation rounding, well under the per-channel threshold).
  { name: "grad-horiz", w: 60, h: 40, maxDiffPct: 0.5, html: wrap(`<div style="width:40px;height:24px;background:linear-gradient(90deg,#f00,#00f)"></div>`) },
  { name: "grad-vert", w: 40, h: 60, maxDiffPct: 0.5, html: wrap(`<div style="width:24px;height:40px;background:linear-gradient(to bottom,#000,#0a0,#fff)"></div>`) },
  // A diagonal gradient is tiled with rotated bands clipped to the box; the
  // residual is the hard band-seam AA vs the browser's smooth interpolation.
  { name: "grad-diag", w: 60, h: 60, maxDiffPct: 4, html: wrap(`<div style="width:40px;height:40px;background:linear-gradient(45deg,#000,#fff)"></div>`) },
  // rounded corners differ only by anti-aliasing
  { name: "rounded", w: 60, h: 60, maxDiffPct: 2, html: wrap(`<div style="width:40px;height:40px;background:#000;border-radius:12px"></div>`) },
  // transform: rotate fills the box's actual rotated quad (a diamond); the
  // residual is the hard-edged polygon vs the browser's edge anti-aliasing.
  { name: "rotate-45", w: 60, h: 60, maxDiffPct: 4, html: wrap(`<div style="width:24px;height:24px;background:#000;transform:rotate(45deg);margin:12px"></div>`) },
  // Text: same font in both. Positioning/shape match; the residual is the
  // sub-pixel AA difference between crater's glyph rasterizer and the
  // browser's (FreeType) -- an inherent rasterizer floor, not a layout gap.
  // The tolerance still catches positioning / font-loading regressions
  // (those spike well past it).
  { name: "text-av", w: 40, h: 28, maxDiffPct: 18, font: "test/fonts/minimal-kern.ttf", text: "AV", size: 24 },
];

// Build the HTML for a text fixture; the same markup renders in crater (via
// the globally-installed font provider) and Chromium (via @font-face).
function textHtml(fontB64, text, size) {
  return `<!doctype html><html><head><style>` +
    `@font-face{font-family:tf;src:url(data:font/ttf;base64,${fontB64})}` +
    `html,body{margin:0;padding:0}div{font-family:tf;font-size:${size}px;color:#000}` +
    `</style></head><body><div>${text}</div></body></html>`;
}

async function main() {
  const chromium = await loadChromium();
  if (!chromium) { console.error("skip: playwright unavailable"); return; }
  const m = await import("../dist/index.js");
  let browser;
  try { browser = await chromium.launch({ args: ["--no-sandbox", "--force-device-scale-factor=1", "--hide-scrollbars"] }); }
  catch (e) { console.error("skip: could not launch chromium —", e.message); return; }
  let failures = 0;
  try {
    const page = await browser.newPage({ deviceScaleFactor: 1 });
    for (const fx of FIXTURES) {
      let html = fx.html;
      if (fx.font) {
        // Install the same font in crater and embed it via @font-face for
        // Chromium so both rasterize identical glyph outlines.
        const bytes = readFileSync(resolve(__dirname, "..", fx.font));
        m.setFontProviderFromBytes(Array.from(bytes));
        html = textHtml(bytes.toString("base64"), fx.text, fx.size);
      }
      const crater = m.renderHtmlToImageRgba(html, fx.w, fx.h);
      await page.setViewportSize({ width: fx.w, height: fx.h });
      await page.setContent(html, { waitUntil: "load" });
      if (fx.font) await page.evaluate(() => document.fonts.ready);
      const png = await page.screenshot({ clip: { x: 0, y: 0, width: fx.w, height: fx.h } });
      const chrome = decodePng(png);
      const c = compare(crater, chrome.rgba);
      const ok = c.diffPct <= fx.maxDiffPct;
      console.error(`${ok ? "ok  " : "FAIL"} ${fx.name.padEnd(10)} diffPct=${c.diffPct.toFixed(2)}% (<= ${fx.maxDiffPct}%) maxCh=${c.max}`);
      if (!ok) failures++;
    }
  } finally {
    await browser.close();
  }
  if (failures > 0) { console.error(`\n${failures} fixture(s) exceeded the Chromium accuracy tolerance.`); process.exit(1); }
  console.error("crater matches Chromium within tolerance.");
}

main().catch((e) => { console.error(e); process.exit(1); });
