/**
 * BiDi server launcher with font module pre-loaded.
 * Used for VRT to get accurate text metrics instead of monospace fallback.
 *
 * Usage: deno run -A browser/jsbidi/bidi_main/start-with-font.ts
 */
import { createTextIntrinsicFnFromMeasureText } from "../../../scripts/text-intrinsic.ts";

const fontCandidates = [
  Deno.env.get("CRATER_TEXT_FONT_PATH"),
  "/System/Library/Fonts/Supplemental/Arial.ttf",            // macOS
  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",          // Linux (Debian/Ubuntu)
  "/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf", // Linux (Fedora)
  `${Deno.env.get("HOME")}/ghq/github.com/mizchi/font/fixtures/NotoSansMono-Regular.ttf`,
].filter((p): p is string => !!p);

const fontModulePath = `${Deno.env.get("HOME")}/ghq/github.com/mizchi/font/_build/js/release/build/js/js.js`;

let fontLoaded = false;
try {
  const fontMod = await import(fontModulePath);
  const loadFont = fontMod.loadFont ?? fontMod.default?.loadFont;
  const measureText = fontMod.measureText ?? fontMod.default?.measureText;

  const glyphToSvgPath = fontMod.glyphToSvgPath ?? fontMod.default?.glyphToSvgPath;
  const glyphAdvance = fontMod.glyphAdvance ?? fontMod.default?.glyphAdvance;

  if (loadFont && measureText) {
    for (const fontPath of fontCandidates) {
      try {
        const fontBytes = Deno.readFileSync(fontPath);
        loadFont(fontBytes);
        console.error(`[font] Loaded: ${fontPath}`);
        fontLoaded = true;

        (globalThis as any).__craterMeasureTextIntrinsic = createTextIntrinsicFnFromMeasureText(
          (text: string, fontSize: number) => measureText(text, fontSize) as number,
        );
        console.error(`[font] Text metrics provider installed`);

        // Set up glyph rendering functions for SVG-based text paint
        if (glyphToSvgPath && glyphAdvance) {
          (globalThis as any).__craterGlyphToSvgPath = (cp: number, fs: number) =>
            glyphToSvgPath(cp, fs);
          (globalThis as any).__craterGlyphAdvance = (cp: number, fs: number) =>
            glyphAdvance(cp, fs);
          console.error(`[font] Glyph provider installed`);
        }
        break;
      } catch {
        // Try next candidate
      }
    }
  }
} catch (err) {
  console.error(`[font] Module not available: ${err}`);
}

if (!fontLoaded) {
  console.error(`[font] No font loaded, using monospace fallback`);
}

// Start the BiDi server
await import("../_build/js/release/build/bidi_main/bidi_main.js");
