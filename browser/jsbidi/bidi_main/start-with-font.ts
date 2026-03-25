/**
 * BiDi server launcher with font module pre-loaded.
 * Used for VRT to get accurate text metrics instead of monospace fallback.
 *
 * Usage: deno run -A browser/jsbidi/bidi_main/start-with-font.ts
 */
import { createTextIntrinsicFnFromMeasureText } from "../../../scripts/text-intrinsic.ts";

const fontModulePath = `${Deno.env.get("HOME")}/ghq/github.com/mizchi/font/_build/js/release/build/js/js.js`;

// Regular font candidates
const regularCandidates = [
  Deno.env.get("CRATER_TEXT_FONT_PATH"),
  "/System/Library/Fonts/Supplemental/Arial.ttf",
  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
  "/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf",
  `${Deno.env.get("HOME")}/ghq/github.com/mizchi/font/fixtures/NotoSansMono-Regular.ttf`,
].filter((p): p is string => !!p);

// Bold font candidates
const boldCandidates = [
  Deno.env.get("CRATER_TEXT_FONT_BOLD_PATH"),
  "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
  "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
  "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf",
  `${Deno.env.get("HOME")}/ghq/github.com/mizchi/font/fixtures/NotoSansMono-Bold.ttf`,
].filter((p): p is string => !!p);

function tryLoadFont(fontPath: string): Uint8Array | null {
  try {
    return Deno.readFileSync(fontPath);
  } catch {
    return null;
  }
}

let fontLoaded = false;
try {
  // Load regular font module instance
  const regularMod = await import(fontModulePath);
  const loadFont = regularMod.loadFont ?? regularMod.default?.loadFont;
  const measureText = regularMod.measureText ?? regularMod.default?.measureText;
  const glyphToSvgPath = regularMod.glyphToSvgPath ?? regularMod.default?.glyphToSvgPath;
  const glyphAdvance = regularMod.glyphAdvance ?? regularMod.default?.glyphAdvance;
  const kernAdvance = regularMod.kernAdvance ?? regularMod.default?.kernAdvance;
  const getFontInfo = regularMod.getFontInfo ?? regularMod.default?.getFontInfo;

  if (loadFont && measureText) {
    for (const fontPath of regularCandidates) {
      const bytes = tryLoadFont(fontPath);
      if (!bytes) continue;

      loadFont(bytes);
      console.error(`[font] Regular loaded: ${fontPath}`);
      fontLoaded = true;

      // Text metrics provider (for layout)
      (globalThis as any).__craterMeasureTextIntrinsic = createTextIntrinsicFnFromMeasureText(
        (text: string, fontSize: number) => measureText(text, fontSize) as number,
      );

      // Ascent ratio
      if (getFontInfo) {
        const info = JSON.parse(getFontInfo() as string);
        const ascentRatio = (info.ascent || 0) / (info.units_per_em || 2048);
        (globalThis as any).__craterFontAscentRatio = () => ascentRatio;
        console.error(`[font] Ascent ratio: ${ascentRatio.toFixed(4)}`);
      }

      // Glyph provider (regular)
      if (glyphToSvgPath && glyphAdvance) {
        (globalThis as any).__craterGlyphToSvgPath = (cp: number, fs: number) =>
          glyphToSvgPath(cp, fs);
        (globalThis as any).__craterGlyphAdvance = (cp: number, fs: number) =>
          glyphAdvance(cp, fs);
        if (kernAdvance) {
          (globalThis as any).__craterKernAdvance = (cp1: number, cp2: number, fs: number) =>
            kernAdvance(cp1, cp2, fs);
        }
        console.error(`[font] Glyph provider installed (kern=${!!kernAdvance})`);
      }

      break;
    }
  }

  // Load bold font in a separate module instance (cache-busted import)
  if (fontLoaded && glyphToSvgPath && glyphAdvance) {
    try {
      const boldMod = await import(`${fontModulePath}?weight=bold`);
      const loadBold = boldMod.loadFont ?? boldMod.default?.loadFont;
      const boldGlyphToSvgPath = boldMod.glyphToSvgPath ?? boldMod.default?.glyphToSvgPath;
      const boldGlyphAdvance = boldMod.glyphAdvance ?? boldMod.default?.glyphAdvance;
      const boldKernAdvance = boldMod.kernAdvance ?? boldMod.default?.kernAdvance;

      if (loadBold && boldGlyphToSvgPath && boldGlyphAdvance) {
        for (const fontPath of boldCandidates) {
          const bytes = tryLoadFont(fontPath);
          if (!bytes) continue;

          loadBold(bytes);
          console.error(`[font] Bold loaded: ${fontPath}`);

          (globalThis as any).__craterGlyphToSvgPathBold = (cp: number, fs: number) =>
            boldGlyphToSvgPath(cp, fs);
          (globalThis as any).__craterGlyphAdvanceBold = (cp: number, fs: number) =>
            boldGlyphAdvance(cp, fs);
          if (boldKernAdvance) {
            (globalThis as any).__craterKernAdvanceBold = (cp1: number, cp2: number, fs: number) =>
              boldKernAdvance(cp1, cp2, fs);
          }
          console.error(`[font] Bold glyph provider installed (kern=${!!boldKernAdvance})`);
          break;
        }
      }
    } catch (err) {
      console.error(`[font] Bold font module failed: ${err}`);
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
