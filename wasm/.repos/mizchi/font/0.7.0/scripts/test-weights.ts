import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

interface FontModule {
  loadFont(data: Uint8Array): string;
  glyphToSvgPath(codepoint: number, fontSize: number): string;
  glyphAdvance(codepoint: number, fontSize: number): number;
  getFontInfo(): string;
}

interface FontInfo {
  units_per_em: number;
  num_glyphs: number;
  ascent: number;
  descent: number;
}

interface WeightResult {
  name: string;
  info: FontInfo;
  glyphs: Map<string, { path: string; advance: number }>;
}

const FONT_WEIGHTS = [
  { name: "Light", file: "NotoSansMono-Light.ttf" },
  { name: "Regular", file: "NotoSansMono-Regular.ttf" },
  { name: "Bold", file: "NotoSansMono-Bold.ttf" },
];

// Test characters covering various glyph types
const TEST_CHARS = ["A", "H", "O", "a", "e", "o", "1", "0"];
const FONT_SIZE = 64;

async function main() {
  const mod = (await import(
    resolve(__dirname, "../target/js/release/build/js/js.js")
  )) as FontModule;

  const results: WeightResult[] = [];
  let hasError = false;

  // Load each weight and render test glyphs
  for (const weight of FONT_WEIGHTS) {
    const fontPath = resolve(__dirname, `../fixtures/${weight.file}`);
    const fontData = new Uint8Array(readFileSync(fontPath));
    const infoStr = mod.loadFont(fontData);
    if (!infoStr) {
      console.error(`FAIL: Could not parse ${weight.file}`);
      hasError = true;
      continue;
    }
    const info = JSON.parse(infoStr) as FontInfo;
    const glyphs = new Map<string, { path: string; advance: number }>();

    for (const ch of TEST_CHARS) {
      const codepoint = ch.codePointAt(0)!;
      const path = mod.glyphToSvgPath(codepoint, FONT_SIZE);
      const advance = mod.glyphAdvance(codepoint, FONT_SIZE);
      glyphs.set(ch, { path, advance });
    }

    results.push({ name: weight.name, info, glyphs });
    console.log(`OK: Loaded ${weight.name} (${info.num_glyphs} glyphs, ascent=${info.ascent}, descent=${info.descent})`);
  }

  // Verify that different weights produce different path data
  console.log("\n--- Weight Differentiation Test ---");
  for (let i = 0; i < results.length; i++) {
    for (let j = i + 1; j < results.length; j++) {
      const a = results[i];
      const b = results[j];
      let diffCount = 0;
      let sameCount = 0;

      for (const ch of TEST_CHARS) {
        const pathA = a.glyphs.get(ch)!.path;
        const pathB = b.glyphs.get(ch)!.path;
        if (pathA !== pathB) {
          diffCount++;
        } else {
          sameCount++;
          console.log(`  WARN: '${ch}' has identical path for ${a.name} vs ${b.name}`);
        }
      }

      if (diffCount === 0) {
        console.error(`FAIL: ${a.name} vs ${b.name} — all glyphs identical!`);
        hasError = true;
      } else {
        console.log(`OK: ${a.name} vs ${b.name} — ${diffCount}/${TEST_CHARS.length} glyphs differ`);
      }
    }
  }

  // Generate comparison SVG for visual inspection
  const comparisonSvg = generateComparisonSvg(results);
  const outputPath = resolve(__dirname, "../debug-weight-comparison.svg");
  writeFileSync(outputPath, comparisonSvg);
  console.log(`\nComparison SVG written to: ${outputPath}`);

  // Generate per-weight snapshot data (path hashes) for regression detection
  console.log("\n--- Snapshot Data ---");
  for (const result of results) {
    const snapshot: Record<string, string> = {};
    for (const ch of TEST_CHARS) {
      snapshot[ch] = result.glyphs.get(ch)!.path;
    }
    const snapshotPath = resolve(
      __dirname,
      `../fixtures/snapshot-${result.name.toLowerCase()}.json`
    );
    const existing = tryReadJson(snapshotPath);
    if (existing) {
      // Compare with existing snapshot
      let changed = 0;
      for (const ch of TEST_CHARS) {
        if (existing[ch] !== snapshot[ch]) {
          changed++;
          console.log(`  CHANGED: ${result.name} '${ch}' path differs from snapshot`);
        }
      }
      if (changed === 0) {
        console.log(`OK: ${result.name} snapshot matches (${TEST_CHARS.length} glyphs)`);
      } else {
        console.log(`WARN: ${result.name} — ${changed}/${TEST_CHARS.length} glyphs changed from snapshot`);
        writeFileSync(snapshotPath, JSON.stringify(snapshot, null, 2) + "\n");
        console.log(`  Updated: ${snapshotPath}`);
      }
    } else {
      // First run — write initial snapshot
      writeFileSync(snapshotPath, JSON.stringify(snapshot, null, 2) + "\n");
      console.log(`NEW: ${result.name} snapshot created at ${snapshotPath}`);
    }
  }

  if (hasError) {
    process.exit(1);
  }
}

function tryReadJson(path: string): Record<string, string> | null {
  try {
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch {
    return null;
  }
}

function generateComparisonSvg(results: WeightResult[]): string {
  const colWidth = 80;
  const rowHeight = 80;
  const labelWidth = 100;
  const marginTop = 50;
  const marginLeft = 10;

  const totalWidth = labelWidth + TEST_CHARS.length * colWidth + marginLeft * 2;
  const totalHeight = marginTop + results.length * rowHeight + 20;

  let svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="${totalHeight}" viewBox="0 0 ${totalWidth} ${totalHeight}">
  <rect width="100%" height="100%" fill="white"/>
  <style>text { font-family: sans-serif; font-size: 14px; }</style>
`;

  // Column headers
  for (let c = 0; c < TEST_CHARS.length; c++) {
    const x = marginLeft + labelWidth + c * colWidth + colWidth / 2;
    svg += `  <text x="${x}" y="30" text-anchor="middle" fill="#666">${TEST_CHARS[c]}</text>\n`;
  }

  // Rows per weight
  for (let r = 0; r < results.length; r++) {
    const result = results[r];
    const baseY = marginTop + r * rowHeight + rowHeight * 0.7;

    // Weight label
    svg += `  <text x="${marginLeft + 5}" y="${baseY}" fill="#333">${result.name}</text>\n`;

    // Separator line
    svg += `  <line x1="${marginLeft}" y1="${marginTop + r * rowHeight}" x2="${totalWidth - marginLeft}" y2="${marginTop + r * rowHeight}" stroke="#eee" stroke-width="1"/>\n`;

    // Glyphs
    for (let c = 0; c < TEST_CHARS.length; c++) {
      const ch = TEST_CHARS[c];
      const glyph = result.glyphs.get(ch)!;
      if (glyph.path) {
        const x = marginLeft + labelWidth + c * colWidth + colWidth / 2 - glyph.advance / 2;
        svg += `  <path d="${glyph.path}" fill="black" transform="translate(${x}, ${baseY})"/>\n`;
      }
    }
  }

  svg += `</svg>\n`;
  return svg;
}

main();
