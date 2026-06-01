/**
 * Vendored-font text advance measurement for the WPT runner.
 *
 * The WPT runner compares Crater's computed layout against Chromium. Crater's
 * text advances come from `globalThis.__craterMeasureTextIntrinsic`. When no
 * external `mizchi/text` module is available, we measure real glyph advances
 * with opentype.js against a font that is metric-compatible with Chromium's
 * default font (Times New Roman -> Tinos), instead of a `length * 0.5` guess.
 *
 * See tests/wpt-fonts/README.md for the rationale and licensing.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import opentype from 'opentype.js';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const TINOS_PATH = path.join(SCRIPT_DIR, '..', 'tests', 'wpt-fonts', 'Tinos-Regular.ttf');

// Advance of a typical monospace face (e.g. Noto Sans Mono) is 600/1000 em.
const MONOSPACE_ADVANCE_RATIO = 0.6;
// Final safety net when the vendored font cannot be parsed.
const HEURISTIC_ADVANCE_RATIO = 0.5;

type OpentypeFont = {
  unitsPerEm: number;
  charToGlyph: (ch: string) => { advanceWidth?: number } | undefined;
};

/**
 * Returns a `measureText(text, fontSize, fontFamily) => advanceWidthPx` function
 * suitable for `createTextIntrinsicFnFromMeasureText`. Loads the vendored Tinos
 * font lazily and degrades gracefully to a ratio heuristic if it is unavailable.
 */
export function createVendoredFontMeasure(
  fontPath: string = TINOS_PATH,
): (text: string, fontSize: number, fontFamily: string) => number {
  let font: OpentypeFont | null = null;
  let loadAttempted = false;

  const loadFont = (): OpentypeFont | null => {
    if (loadAttempted) return font;
    loadAttempted = true;
    try {
      const buf = fs.readFileSync(fontPath);
      const ab = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
      font = opentype.parse(ab) as unknown as OpentypeFont;
    } catch {
      font = null;
    }
    return font;
  };

  const advanceFromFont = (f: OpentypeFont, text: string, fontSize: number): number => {
    const scale = fontSize / (f.unitsPerEm || 1000);
    let width = 0;
    for (const ch of text) {
      const glyph = f.charToGlyph(ch);
      const adv =
        glyph && typeof glyph.advanceWidth === 'number'
          ? glyph.advanceWidth
          : (f.unitsPerEm || 1000) * HEURISTIC_ADVANCE_RATIO;
      width += adv * scale;
    }
    return width;
  };

  return (text: string, fontSize: number, fontFamily: string): number => {
    if (text.length === 0) return 0;
    const size = fontSize > 0 ? fontSize : 16;
    const family = (fontFamily || '').toLowerCase();
    // Ahem glyphs are 1em squares; keep them exact.
    if (family.includes('ahem')) return text.length * size;
    // Explicit monospace families: proportional measurement would be wrong.
    if (family.includes('mono')) return text.length * size * MONOSPACE_ADVANCE_RATIO;
    const f = loadFont();
    if (f) return advanceFromFont(f, text, size);
    return text.length * size * HEURISTIC_ADVANCE_RATIO;
  };
}
