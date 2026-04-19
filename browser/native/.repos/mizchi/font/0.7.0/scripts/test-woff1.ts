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

const TEST_CHARS = ["A", "H", "O", "a", "e", "o", "1", "0"];
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
  console.log(
    `OK: TTF loaded (${ttfInfo.num_glyphs} glyphs, ascent=${ttfInfo.ascent}, descent=${ttfInfo.descent})`
  );

  // Collect TTF glyph data
  const ttfGlyphs = new Map<string, { path: string; advance: number }>();
  for (const ch of TEST_CHARS) {
    const cp = ch.codePointAt(0)!;
    ttfGlyphs.set(ch, {
      path: mod.glyphToSvgPath(cp, FONT_SIZE),
      advance: mod.glyphAdvance(cp, FONT_SIZE),
    });
  }

  // Load WOFF1
  const woffPath = resolve(__dirname, "../fixtures/NotoSansMono-Regular.woff");
  const woffData = new Uint8Array(readFileSync(woffPath));
  const woffInfoStr = mod.loadFont(woffData);
  if (!woffInfoStr) {
    console.error("FAIL: Could not parse WOFF1");
    process.exit(1);
  }
  const woffInfo = JSON.parse(woffInfoStr) as FontInfo;
  console.log(
    `OK: WOFF1 loaded (${woffInfo.num_glyphs} glyphs, ascent=${woffInfo.ascent}, descent=${woffInfo.descent})`
  );

  // Verify font info matches
  if (ttfInfo.units_per_em !== woffInfo.units_per_em) {
    console.error(
      `FAIL: units_per_em mismatch: TTF=${ttfInfo.units_per_em}, WOFF=${woffInfo.units_per_em}`
    );
    hasError = true;
  }
  if (ttfInfo.num_glyphs !== woffInfo.num_glyphs) {
    console.error(
      `FAIL: num_glyphs mismatch: TTF=${ttfInfo.num_glyphs}, WOFF=${woffInfo.num_glyphs}`
    );
    hasError = true;
  }
  if (ttfInfo.ascent !== woffInfo.ascent) {
    console.error(
      `FAIL: ascent mismatch: TTF=${ttfInfo.ascent}, WOFF=${woffInfo.ascent}`
    );
    hasError = true;
  }
  if (ttfInfo.descent !== woffInfo.descent) {
    console.error(
      `FAIL: descent mismatch: TTF=${ttfInfo.descent}, WOFF=${woffInfo.descent}`
    );
    hasError = true;
  }

  if (!hasError) {
    console.log("OK: Font info matches between TTF and WOFF1");
  }

  // Compare glyphs
  console.log("\n--- Glyph Comparison (TTF vs WOFF1) ---");
  const woffGlyphs = new Map<string, { path: string; advance: number }>();
  for (const ch of TEST_CHARS) {
    const cp = ch.codePointAt(0)!;
    woffGlyphs.set(ch, {
      path: mod.glyphToSvgPath(cp, FONT_SIZE),
      advance: mod.glyphAdvance(cp, FONT_SIZE),
    });
  }

  let matchCount = 0;
  let mismatchCount = 0;
  for (const ch of TEST_CHARS) {
    const ttf = ttfGlyphs.get(ch)!;
    const woff = woffGlyphs.get(ch)!;

    if (ttf.path !== woff.path) {
      console.error(`FAIL: '${ch}' path differs between TTF and WOFF1`);
      console.error(`  TTF:  ${ttf.path.slice(0, 80)}...`);
      console.error(`  WOFF: ${woff.path.slice(0, 80)}...`);
      mismatchCount++;
      hasError = true;
    } else {
      matchCount++;
    }

    if (Math.abs(ttf.advance - woff.advance) > 0.01) {
      console.error(
        `FAIL: '${ch}' advance differs: TTF=${ttf.advance}, WOFF=${woff.advance}`
      );
      hasError = true;
    }
  }

  console.log(
    `Glyph paths: ${matchCount} match, ${mismatchCount} differ out of ${TEST_CHARS.length}`
  );

  if (hasError) {
    console.error("\nFAIL: Some tests failed");
    process.exit(1);
  } else {
    console.log("\nOK: All WOFF1 tests passed");
  }
}

main();
