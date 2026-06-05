#!/usr/bin/env node
// Browser-free image VRT: render HTML fixtures to PNG via crater's gfx
// software backend and pixel-diff them against committed baseline PNGs.
// Deterministic and CI-friendly (no browser / GPU). `--update` rewrites
// the baselines.
//
// Usage:
//   node image-vrt.mjs            # check against baselines (exit 1 on diff)
//   node image-vrt.mjs --update   # (re)write baselines
import zlib from "node:zlib";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const BASELINE_DIR = resolve(__dirname, "../test/image-vrt/baselines");
const TOLERANCE = 0; // max per-channel diff allowed before a pixel counts

// Representative, deterministic fixtures (margin:0, fixed px sizes).
const FIXTURES = [
  {
    name: "stacked-blocks",
    width: 16,
    height: 12,
    html: `<html><body style="margin:0">
<div style="width:16px;height:4px;background:#000000"></div>
<div style="width:16px;height:4px;background:#ffffff"></div>
<div style="width:16px;height:4px;background:#808080"></div>
</body></html>`,
  },
  {
    name: "bordered-box",
    width: 16,
    height: 12,
    html: `<html><body style="margin:0">
<div style="width:16px;height:12px;border:2px solid #2244cc;box-sizing:border-box;background:#ffee88"></div>
</body></html>`,
  },
  {
    name: "flex-rgb",
    width: 24,
    height: 8,
    html: `<html><body style="margin:0">
<div style="display:flex;width:24px;height:8px">
<div style="width:8px;height:8px;background:#cc3333"></div>
<div style="width:8px;height:8px;background:#33aa55"></div>
<div style="width:8px;height:8px;background:#3355cc"></div>
</div>
</body></html>`,
  },
  {
    name: "grid-2x2",
    width: 16,
    height: 12,
    html: `<html><body style="margin:0">
<div style="display:grid;grid-template-columns:8px 8px;grid-template-rows:6px 6px;width:16px;height:12px">
<div style="background:#000000"></div>
<div style="background:#555555"></div>
<div style="background:#aaaaaa"></div>
<div style="background:#ffffff"></div>
</div>
</body></html>`,
  },
  {
    name: "abspos-overlap",
    width: 16,
    height: 12,
    html: `<html><body style="margin:0">
<div style="position:relative;width:16px;height:12px;background:#eeeeee">
<div style="position:absolute;left:2px;top:2px;width:8px;height:6px;background:#000000"></div>
<div style="position:absolute;left:6px;top:4px;width:8px;height:6px;background:#888888"></div>
</div>
</body></html>`,
  },
  {
    name: "alpha-blend",
    width: 16,
    height: 8,
    html: `<html><body style="margin:0;background:#ffffff">
<div style="width:16px;height:8px;background:#ffffff"></div>
<div style="position:absolute;left:0;top:0;width:16px;height:8px;background:rgba(0,0,0,0.5)"></div>
</body></html>`,
  },
  {
    name: "overflow-clip",
    width: 16,
    height: 16,
    html: `<html><body style="margin:0">
<div style="overflow:hidden;width:8px;height:8px;background:#cccccc">
<div style="width:16px;height:16px;background:#000000"></div>
</div>
</body></html>`,
  },
];

async function loadCrater() {
  const candidates = [
    "../dist/crater.js",
    "../../target/js/release/build/js/js.js",
    "../../_build/js/release/build/mizchi/crater-js/crater-js.js",
  ];
  let lastErr;
  for (const rel of candidates) {
    try {
      return await import(resolve(__dirname, rel));
    } catch (e) {
      lastErr = e;
    }
  }
  console.error("Could not load crater bundle. Build it with `npm run build` (in js/).");
  throw lastErr;
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

// Minimal PNG decoder for 8-bit colorType-6 (RGBA), non-interlaced.
function decodePng(buf) {
  let pos = 8;
  let width = 0;
  let height = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString("ascii", pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * 4;
  const out = Buffer.alloc(height * stride);
  let rp = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[rp++];
    for (let x = 0; x < stride; x++) {
      const v = raw[rp++];
      const a = x >= 4 ? out[y * stride + x - 4] : 0;
      const b = y > 0 ? out[(y - 1) * stride + x] : 0;
      const c = x >= 4 && y > 0 ? out[(y - 1) * stride + x - 4] : 0;
      let val;
      switch (filter) {
        case 1: val = v + a; break;
        case 2: val = v + b; break;
        case 3: val = v + ((a + b) >> 1); break;
        case 4: val = v + paeth(a, b, c); break;
        default: val = v;
      }
      out[y * stride + x] = val & 0xff;
    }
  }
  return { width, height, data: out };
}

function diffRgba(current, baseline) {
  if (current.length !== baseline.length) {
    return { sizeMismatch: true, diffPixels: -1, maxChannelDiff: 255 };
  }
  let diffPixels = 0;
  let maxChannelDiff = 0;
  for (let i = 0; i < current.length; i += 4) {
    let d = 0;
    for (let k = 0; k < 4; k++) {
      const cd = Math.abs((current[i + k] & 0xff) - (baseline[i + k] & 0xff));
      if (cd > d) d = cd;
    }
    if (d > maxChannelDiff) maxChannelDiff = d;
    if (d > TOLERANCE) diffPixels++;
  }
  return { sizeMismatch: false, diffPixels, maxChannelDiff };
}

const update = process.argv.includes("--update");
const crater = await loadCrater();
mkdirSync(BASELINE_DIR, { recursive: true });

let failures = 0;
for (const fx of FIXTURES) {
  const b64 = crater.renderHtmlToImagePngBase64(fx.html, fx.width, fx.height);
  const png = Buffer.from(b64, "base64");
  const baselinePath = join(BASELINE_DIR, `${fx.name}.png`);
  if (update) {
    writeFileSync(baselinePath, png);
    console.error(`updated ${fx.name} (${png.length} bytes)`);
    continue;
  }
  if (!existsSync(baselinePath)) {
    console.error(`MISSING baseline for ${fx.name} (run with --update)`);
    failures++;
    continue;
  }
  const current = decodePng(png).data;
  const baseline = decodePng(readFileSync(baselinePath)).data;
  const { sizeMismatch, diffPixels, maxChannelDiff } = diffRgba(current, baseline);
  if (sizeMismatch || diffPixels > 0) {
    console.error(
      `FAIL ${fx.name}: diffPixels=${diffPixels} maxChannelDiff=${maxChannelDiff}` +
        (sizeMismatch ? " (size mismatch)" : ""),
    );
    failures++;
  } else {
    console.error(`ok   ${fx.name}`);
  }
}

if (!update && failures > 0) {
  console.error(`\n${failures} image-VRT fixture(s) regressed.`);
  process.exit(1);
}
console.error(update ? "baselines updated." : "all image-VRT fixtures match.");
