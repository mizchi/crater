import { readFileSync } from "node:fs";
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

const TEST_CHARS = ["A", "H", "O", "a", "e", "o", "1", "0", "!", "@"];
const FONT_SIZE = 64;

async function main() {
  const mod = (await import(
    resolve(__dirname, "../target/js/release/build/js/js.js")
  )) as FontModule;

  let hasError = false;

  // Load TTF
  const ttfPath = resolve(__dirname, "../fixtures/NotoSansMono-Regular.ttf");
  const ttfData = new Uint8Array(readFileSync(ttfPath));
  const ttfInfoStr = mod.loadFont(ttfData);
  if (!ttfInfoStr) {
    console.error("FAIL: Could not parse TTF");
    process.exit(1);
  }
  const ttfInfo = JSON.parse(ttfInfoStr) as FontInfo;
  console.log(`TTF:   ${ttfInfo.num_glyphs} glyphs, upm=${ttfInfo.units_per_em}, ascent=${ttfInfo.ascent}, descent=${ttfInfo.descent}`);

  // Collect TTF glyph data
  const ttfGlyphs = new Map<string, { path: string; advance: number }>();
  for (const ch of TEST_CHARS) {
    const cp = ch.codePointAt(0)!;
    ttfGlyphs.set(ch, {
      path: mod.glyphToSvgPath(cp, FONT_SIZE),
      advance: mod.glyphAdvance(cp, FONT_SIZE),
    });
  }

  // Load WOFF2
  const woff2Path = resolve(__dirname, "../fixtures/NotoSansMono-Regular.woff2");
  const woff2Data = new Uint8Array(readFileSync(woff2Path));
  const woff2InfoStr = mod.loadFont(woff2Data);
  if (!woff2InfoStr) {
    console.error("FAIL: Could not parse WOFF2");
    hasError = true;
  } else {
    const woff2Info = JSON.parse(woff2InfoStr) as FontInfo;
    console.log(`WOFF2: ${woff2Info.num_glyphs} glyphs, upm=${woff2Info.units_per_em}, ascent=${woff2Info.ascent}, descent=${woff2Info.descent}`);

    // Compare font metadata
    if (ttfInfo.units_per_em !== woff2Info.units_per_em) {
      console.error(`FAIL: units_per_em mismatch: TTF=${ttfInfo.units_per_em} WOFF2=${woff2Info.units_per_em}`);
      hasError = true;
    } else {
      console.log("OK: units_per_em match");
    }

    if (ttfInfo.num_glyphs !== woff2Info.num_glyphs) {
      console.error(`FAIL: num_glyphs mismatch: TTF=${ttfInfo.num_glyphs} WOFF2=${woff2Info.num_glyphs}`);
      hasError = true;
    } else {
      console.log("OK: num_glyphs match");
    }

    if (ttfInfo.ascent !== woff2Info.ascent || ttfInfo.descent !== woff2Info.descent) {
      console.error(`FAIL: metrics mismatch: TTF ascent/descent=${ttfInfo.ascent}/${ttfInfo.descent} WOFF2=${woff2Info.ascent}/${woff2Info.descent}`);
      hasError = true;
    } else {
      console.log("OK: ascent/descent match");
    }

    // Compare glyphs
    const woff2Glyphs = new Map<string, { path: string; advance: number }>();
    for (const ch of TEST_CHARS) {
      const cp = ch.codePointAt(0)!;
      woff2Glyphs.set(ch, {
        path: mod.glyphToSvgPath(cp, FONT_SIZE),
        advance: mod.glyphAdvance(cp, FONT_SIZE),
      });
    }

    console.log("\n--- Glyph Comparison (TTF vs WOFF2) ---");
    let matchCount = 0;
    let mismatchCount = 0;
    for (const ch of TEST_CHARS) {
      const ttfG = ttfGlyphs.get(ch)!;
      const woff2G = woff2Glyphs.get(ch)!;

      const pathMatch = ttfG.path === woff2G.path;
      const advanceMatch = Math.abs(ttfG.advance - woff2G.advance) < 0.01;

      if (pathMatch && advanceMatch) {
        matchCount++;
        console.log(`  OK: '${ch}' path and advance match`);
      } else {
        mismatchCount++;
        if (!pathMatch) {
          console.error(`  FAIL: '${ch}' path mismatch`);
          console.error(`    TTF:   ${ttfG.path.slice(0, 80)}...`);
          console.error(`    WOFF2: ${woff2G.path.slice(0, 80)}...`);
        }
        if (!advanceMatch) {
          console.error(`  FAIL: '${ch}' advance mismatch: TTF=${ttfG.advance} WOFF2=${woff2G.advance}`);
        }
        hasError = true;
      }
    }
    console.log(`\nResult: ${matchCount}/${TEST_CHARS.length} glyphs match`);
    if (mismatchCount > 0) {
      console.log(`WARNING: ${mismatchCount} glyphs differ (may be acceptable if outlines are equivalent)`);
    }
  }

  // Also test WOFF1 for completeness
  const woff1Path = resolve(__dirname, "../fixtures/NotoSansMono-Regular.woff");
  const woff1Data = new Uint8Array(readFileSync(woff1Path));
  const woff1InfoStr = mod.loadFont(woff1Data);
  if (!woff1InfoStr) {
    console.error("FAIL: Could not parse WOFF1");
    hasError = true;
  } else {
    const woff1Info = JSON.parse(woff1InfoStr) as FontInfo;
    console.log(`\nWOFF1: ${woff1Info.num_glyphs} glyphs, upm=${woff1Info.units_per_em}`);
    console.log("OK: WOFF1 parsing still works");
  }

  if (hasError) {
    process.exit(1);
  }
  console.log("\nAll WOFF2 tests passed!");
}

main();
