#!/usr/bin/env node
/**
 * Luna Component VRT - Compare crater CLI vs Chrome rendering
 *
 * Usage:
 *   node tests/luna-vrt/run-vrt.mjs                    # Run all fixtures
 *   node tests/luna-vrt/run-vrt.mjs alert               # Run specific fixture
 *   node tests/luna-vrt/run-vrt.mjs --update-baseline   # Update Chrome baselines
 */

import { execSync } from "node:child_process";
import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import pixelmatch from "pixelmatch";
import { PNG } from "pngjs";

const FIXTURES_DIR = join(import.meta.dirname, "fixtures");
const OUTPUT_DIR = join(import.meta.dirname, "output");
const REPORT_FILE = join(import.meta.dirname, "report.json");
const VIEWPORT_WIDTH = 432;
const TARGET_ID = "target";
const DIFF_THRESHOLD = 0.1; // pixelmatch threshold

const args = process.argv.slice(2);
const updateBaseline = args.includes("--update-baseline");
const filterName = args.find(a => !a.startsWith("--"));

mkdirSync(OUTPUT_DIR, { recursive: true });

const fixtures = readdirSync(FIXTURES_DIR)
  .filter(f => f.endsWith(".html"))
  .filter(f => !filterName || f.replace(".html", "") === filterName)
  .map(f => ({ name: f.replace(".html", ""), path: join(FIXTURES_DIR, f) }));

if (fixtures.length === 0) {
  console.error("No fixtures found" + (filterName ? ` matching "${filterName}"` : ""));
  process.exit(1);
}

console.log(`Running VRT for ${fixtures.length} fixture(s)...\n`);

function renderWithCrater(fixturePath, outputPath) {
  try {
    const json = execSync(
      `node dist/crater.js --artifact image --target-id ${TARGET_ID} --html-file ${fixturePath} --viewport-width ${VIEWPORT_WIDTH}`,
      { encoding: "utf8", timeout: 30000 }
    );
    const data = JSON.parse(json);
    const png = Buffer.from(data.data, "base64");
    writeFileSync(outputPath, png);
    return { width: data.width, height: data.height };
  } catch (e) {
    console.error(`  crater failed: ${e.message.split("\n")[0]}`);
    return null;
  }
}

async function renderWithChrome(fixturePath, outputPath) {
  let browser;
  try {
    const puppeteer = await import("puppeteer-core");
    const chromePaths = [
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
    ];
    const chromePath = chromePaths.find(p => existsSync(p));
    if (!chromePath) throw new Error("Chrome not found");

    browser = await puppeteer.default.launch({
      executablePath: chromePath,
      headless: true,
      args: ["--no-sandbox"],
    });
    const page = await browser.newPage();
    await page.setViewport({ width: VIEWPORT_WIDTH, height: 800 });
    await page.setContent(readFileSync(fixturePath, "utf8"), { waitUntil: "networkidle0" });

    const bounds = await page.evaluate((id) => {
      const el = document.getElementById(id);
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: r.x, y: r.y, width: r.width, height: r.height };
    }, TARGET_ID);

    if (!bounds) throw new Error("Target not found");

    await page.screenshot({
      path: outputPath,
      clip: {
        x: Math.floor(bounds.x),
        y: Math.floor(bounds.y),
        width: Math.ceil(bounds.width),
        height: Math.ceil(bounds.height),
      },
    });
    return { width: Math.ceil(bounds.width), height: Math.ceil(bounds.height) };
  } catch (e) {
    console.error(`  chrome failed: ${e.message}`);
    return null;
  } finally {
    if (browser) await browser.close();
  }
}

function diffPngs(craterPath, chromePath, diffPath) {
  const craterPng = PNG.sync.read(readFileSync(craterPath));
  const chromePng = PNG.sync.read(readFileSync(chromePath));

  // Use the larger dimensions (pad smaller image with white)
  const w = Math.max(craterPng.width, chromePng.width);
  const h = Math.max(craterPng.height, chromePng.height);

  function padToSize(img, targetW, targetH) {
    if (img.width === targetW && img.height === targetH) return img.data;
    const buf = Buffer.alloc(targetW * targetH * 4, 255); // white fill
    for (let y = 0; y < img.height && y < targetH; y++) {
      for (let x = 0; x < img.width && x < targetW; x++) {
        const si = (y * img.width + x) * 4;
        const di = (y * targetW + x) * 4;
        buf[di] = img.data[si];
        buf[di + 1] = img.data[si + 1];
        buf[di + 2] = img.data[si + 2];
        buf[di + 3] = img.data[si + 3];
      }
    }
    return buf;
  }

  const craterData = padToSize(craterPng, w, h);
  const chromeData = padToSize(chromePng, w, h);
  const diffImg = new PNG({ width: w, height: h });

  const diffPixels = pixelmatch(craterData, chromeData, diffImg.data, w, h, {
    threshold: DIFF_THRESHOLD,
  });

  writeFileSync(diffPath, PNG.sync.write(diffImg));

  const totalPixels = w * h;
  const diffRatio = diffPixels / totalPixels;

  return {
    width: w,
    height: h,
    diffPixels,
    totalPixels,
    diffRatio,
    diffPercent: (diffRatio * 100).toFixed(2) + "%",
    craterSize: `${craterPng.width}x${craterPng.height}`,
    chromeSize: `${chromePng.width}x${chromePng.height}`,
  };
}

// Main
const report = [];
for (const fixture of fixtures) {
  console.log(`[${fixture.name}]`);
  const outDir = join(OUTPUT_DIR, fixture.name);
  mkdirSync(outDir, { recursive: true });

  const craterPng = join(outDir, "crater.png");
  const chromePng = join(outDir, "chrome.png");
  const diffPng = join(outDir, "diff.png");

  const craterResult = renderWithCrater(fixture.path, craterPng);
  if (craterResult) console.log(`  crater: ${craterResult.width}x${craterResult.height}`);

  if (updateBaseline || !existsSync(chromePng)) {
    const chromeResult = await renderWithChrome(fixture.path, chromePng);
    if (chromeResult) console.log(`  chrome: ${chromeResult.width}x${chromeResult.height}`);
  } else {
    console.log(`  chrome: baseline`);
  }

  if (existsSync(craterPng) && existsSync(chromePng)) {
    const diff = diffPngs(craterPng, chromePng, diffPng);
    console.log(`  diff:   ${diff.diffPercent} (${diff.diffPixels}/${diff.totalPixels}px)`);
    report.push({ name: fixture.name, ...diff });
  } else {
    report.push({ name: fixture.name, error: "render failed" });
  }
  console.log();
}

// Save report
writeFileSync(REPORT_FILE, JSON.stringify(report, null, 2) + "\n");

// Summary table
console.log("=== Summary ===");
console.log("Component    | Crater     | Chrome     | Diff%");
console.log("-------------|------------|------------|-------");
for (const r of report) {
  if (r.error) {
    console.log(`${r.name.padEnd(13)}| FAILED`);
  } else {
    const pass = parseFloat(r.diffPercent) < 20 ? "  " : "⚠ ";
    console.log(`${pass}${r.name.padEnd(11)}| ${r.craterSize.padEnd(11)}| ${r.chromeSize.padEnd(11)}| ${r.diffPercent}`);
  }
}
