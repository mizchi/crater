#!/usr/bin/env node
// Render an HTML file (or inline string) to a PNG via crater's gfx software
// backend. Intended for image-VRT tooling: produces a true-color PNG that
// can be pixel-diffed against a browser reference.
//
// Usage:
//   node html-to-png.mjs <input.html> <out.png> [width] [height]
//   node html-to-png.mjs --html '<div ...>' <out.png> [width] [height]
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Resolve the crater bundle: published dist first, then known dev build
// layouts (plain `target/` and the feature-flag `_build/` layout).
const candidates = [
  "../dist/crater.js",
  "../../target/js/release/build/js/js.js",
  "../../_build/js/release/build/mizchi/crater-js/crater-js.js",
];
let crater;
let lastErr;
for (const rel of candidates) {
  try {
    crater = await import(resolve(__dirname, rel));
    break;
  } catch (e) {
    lastErr = e;
  }
}
if (!crater) {
  console.error("Could not load crater bundle. Build it with `npm run build` (in js/).");
  console.error(lastErr);
  process.exit(1);
}

const args = process.argv.slice(2);
let html;
let rest;
if (args[0] === "--html") {
  html = args[1];
  rest = args.slice(2);
} else {
  html = readFileSync(args[0], "utf8");
  rest = args.slice(1);
}
const out = rest[0] ?? "out.png";
const width = Number(rest[1] ?? 800);
const height = Number(rest[2] ?? 600);

const b64 = crater.renderHtmlToImagePngBase64(html, width, height);
writeFileSync(out, Buffer.from(b64, "base64"));
console.error(`wrote ${out} (${width}x${height})`);
