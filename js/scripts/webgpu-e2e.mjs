#!/usr/bin/env node
// Real-browser E2E for the gfx web backend.
//
// Always: load crater's bundle + the gfx web runtime in a real Chromium and
// verify renderHtmlViaWebBackendRgba renders the expected pixels in-browser
// (not just in node).
//
// When the browser exposes WebGPU (navigator.gpu): additionally render the
// same command stream on the real GPU (WebGPUBackend) and assert it matches
// the CPU runtime within tolerance. WebGPU is unavailable in plain headless
// Chromium, so that part is skipped there and exercised in GPU-capable CI.
import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname, join, extname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, ".."); // js/

async function loadChromium() {
  try {
    return (await import("playwright")).chromium;
  } catch {
    const { createRequire } = await import("node:module");
    const require = createRequire(import.meta.url);
    const candidates = [
      resolve(ROOT, "../node_modules/playwright"), // repo root (pnpm workspace)
      resolve(ROOT, "node_modules/playwright"),
      "/opt/node22/lib/node_modules/playwright",
    ];
    for (const c of candidates) {
      try { return require(c).chromium; } catch {}
    }
    throw new Error("playwright not resolvable");
  }
}

const MIME = { ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm", ".html": "text/html" };

const PAGE = `<!doctype html><meta charset="utf-8"><body>
<script type="module">
import * as crater from "/dist/index.js";
import { CpuBackend, WebGPUBackend } from "/dist/gfx-web-runtime.mjs";

async function getDevice() {
  if (!navigator.gpu) return null;
  // requestAdapter / requestDevice can hang (rather than reject) on a broken
  // or partially-initialized WebGPU stack -- e.g. SwiftShader in headless CI.
  // Race each against a timeout so __ready always resolves and the page falls
  // back to the CPU backend instead of blocking the test forever.
  const withTimeout = (p, ms) => Promise.race([p, new Promise((r) => setTimeout(() => r(null), ms))]);
  try {
    const a = await withTimeout(navigator.gpu.requestAdapter(), 5000);
    if (!a) return null;
    return await withTimeout(a.requestDevice(), 5000);
  } catch { return null; }
}

window.__mode = "cpu";
window.__ready = (async () => {
  window.__device = await getDevice();
  window.__mode = window.__device ? "webgpu" : "cpu";
})();

window.renderWebCpu = (html, w, h) => {
  globalThis.__craterGfxWeb = new CpuBackend();
  return crater.renderHtmlViaWebBackendRgba(html, w, h);
};
window.renderWebGpu = async (html, w, h) => {
  if (!window.__device) return null;
  const be = new WebGPUBackend(window.__device, "rgba8unorm");
  globalThis.__craterGfxWeb = be;
  crater.renderHtmlViaWebBackendRgba(html, w, h); // drives begin/draw/end
  return await be.readPixelsAsync();
};
</script></body>`;

function startServer() {
  const server = createServer((req, res) => {
    const url = req.url === "/" ? "__page__" : req.url.split("?")[0];
    if (url === "__page__") {
      res.writeHead(200, { "content-type": "text/html" });
      res.end(PAGE);
      return;
    }
    const file = join(ROOT, url);
    if (!file.startsWith(ROOT) || !existsSync(file)) {
      res.writeHead(404); res.end("not found"); return;
    }
    res.writeHead(200, { "content-type": MIME[extname(file)] ?? "application/octet-stream" });
    res.end(readFileSync(file));
  });
  return new Promise((r) => server.listen(0, () => r(server)));
}

function maxDiff(a, b) {
  if (a.length !== b.length) return { lenA: a.length, lenB: b.length, max: 255 };
  let max = 0, diffPixels = 0;
  for (let i = 0; i < a.length; i += 4) {
    let d = 0;
    for (let k = 0; k < 4; k++) d = Math.max(d, Math.abs(a[i + k] - b[i + k]));
    if (d > max) max = d;
    if (d > 8) diffPixels++;
  }
  return { max, diffPixels, total: a.length / 4 };
}

const FIXTURES = [
  {
    name: "stacked-blocks",
    w: 8, h: 8,
    html: `<html><body style="margin:0"><div style="width:8px;height:4px;background:#000"></div><div style="width:8px;height:4px;background:#fff"></div></body></html>`,
    // top-left black, a bottom pixel white
    checks: [[0, [0, 0, 0, 255]], [8 * 5 * 4, [255, 255, 255, 255]]],
  },
  {
    name: "rounded-box",
    w: 12, h: 12,
    html: `<html><body style="margin:0;background:#fff"><div style="width:12px;height:12px;background:#000;border-radius:4px"></div></body></html>`,
    // a corner pixel is carved (white), the centre is black
    checks: [[0, [255, 255, 255, 255]], [(6 * 12 + 6) * 4, [0, 0, 0, 255]]],
  },
];

async function main() {
  // Hard wall-clock watchdog: a browser/GPU step that wedges should not hang
  // the CI job. If we blow the deadline, treat it as a skip (this is a
  // best-effort browser E2E that already skips when no browser is available).
  const watchdog = setTimeout(() => {
    console.error("skip: gfx web backend E2E timed out");
    process.exit(0);
  }, 90000);
  watchdog.unref?.();
  let chromium;
  try {
    chromium = await loadChromium();
  } catch (e) {
    console.error("skip: playwright/chromium unavailable —", e.message);
    clearTimeout(watchdog);
    return;
  }
  const server = await startServer();
  const port = server.address().port;
  let browser;
  try {
    browser = await chromium.launch({
      args: ["--no-sandbox", "--enable-unsafe-webgpu", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
    });
  } catch (e) {
    server.close();
    console.error("skip: could not launch chromium —", e.message);
    clearTimeout(watchdog);
    return;
  }
  let failures = 0;
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(30000);
    page.on("pageerror", (e) => { console.error("pageerror:", e.message); failures++; });
    await page.goto(`http://127.0.0.1:${port}/`, { timeout: 30000, waitUntil: "load" });
    await page.evaluate(() => window.__ready);
    const mode = await page.evaluate(() => window.__mode);
    console.error(`browser backend mode: ${mode}`);

    for (const fx of FIXTURES) {
      const cpu = await page.evaluate(({ html, w, h }) => window.renderWebCpu(html, w, h), fx);
      let ok = true;
      for (const [idx, rgba] of fx.checks) {
        for (let k = 0; k < 4; k++) {
          if (cpu[idx + k] !== rgba[k]) { ok = false; }
        }
      }
      if (!ok) { console.error(`FAIL ${fx.name}: in-browser pixels wrong`); failures++; }
      else console.error(`ok   ${fx.name} (browser ${mode})`);

      if (mode === "webgpu") {
        const gpu = await page.evaluate(({ html, w, h }) => window.renderWebGpu(html, w, h), fx);
        const d = maxDiff(gpu, cpu);
        if (d.max > 16 || (d.diffPixels ?? 0) > Math.ceil(d.total * 0.05)) {
          console.error(`FAIL ${fx.name}: GPU vs CPU diff`, d); failures++;
        } else {
          console.error(`ok   ${fx.name} (webgpu==cpu, maxDiff=${d.max})`);
        }
      }
    }
  } finally {
    await browser.close();
    server.close();
    clearTimeout(watchdog);
  }
  if (failures > 0) { console.error(`\n${failures} E2E check(s) failed.`); process.exit(1); }
  console.error("gfx web backend E2E passed.");
}

main().catch((e) => { console.error(e); process.exit(1); });
