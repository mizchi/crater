/**
 * BiDi server launcher with system font resolution.
 * Loads multiple fonts (Arial, Verdana, etc.) and resolves CSS font-family
 * at runtime for accurate text metrics.
 *
 * Usage: deno run -A webdriver/bidi_main/start-with-font.ts
 */
import { createTextIntrinsicFnFromMeasureText } from "../../scripts/text-intrinsic.ts";
import {
  DEFAULT_TEXT_FONT_FAMILY,
  resolveEffectiveFontFamily,
} from "../../scripts/font-family-defaults.ts";
import {
  listBundledWptFonts,
  resolveBundledWptFontUrl,
} from "../../scripts/wpt-font-utils.ts";
import { resolveBidiMainBuildUrl } from "../../scripts/bidi-build-paths.mjs";
import { resolveFontRuntimeBuildUrl } from "../../scripts/font-build-paths.mjs";

const HOME = Deno.env.get("HOME") || "/tmp";
const fontModuleUrl = resolveFontRuntimeBuildUrl(Deno.cwd());

// ============================================================
// System font resolution (inline, no external deps)
// ============================================================
const MAC_FONT_DIRS = [
  "/System/Library/Fonts/Supplemental",
  "/System/Library/Fonts",
  "/Library/Fonts",
  `${HOME}/Library/Fonts`,
];
const LINUX_FONT_DIRS = [
  "/usr/share/fonts/truetype",
  "/usr/share/fonts",
  "/usr/local/share/fonts",
  `${HOME}/.fonts`,
];
const FONT_DIRS = Deno.build.os === "darwin" ? MAC_FONT_DIRS : LINUX_FONT_DIRS;

const FONT_FILE_MAP: Record<string, { regular: string[]; bold: string[] }> = {
  arial: {
    regular: ["Arial.ttf", "LiberationSans-Regular.ttf", "DejaVuSans.ttf"],
    bold: ["Arial Bold.ttf", "Arial_Bold.ttf", "arialbd.ttf", "LiberationSans-Bold.ttf", "DejaVuSans-Bold.ttf"],
  },
  verdana: {
    regular: ["Verdana.ttf", "DejaVuSans.ttf", "LiberationSans-Regular.ttf"],
    bold: ["Verdana Bold.ttf", "Verdana_Bold.ttf", "verdanab.ttf", "DejaVuSans-Bold.ttf", "LiberationSans-Bold.ttf"],
  },
  georgia: {
    regular: ["Georgia.ttf", "DejaVuSerif.ttf", "LiberationSerif-Regular.ttf", "FreeSerif.ttf"],
    bold: ["Georgia Bold.ttf", "Georgia_Bold.ttf", "georgiab.ttf", "DejaVuSerif-Bold.ttf", "LiberationSerif-Bold.ttf", "FreeSerifBold.ttf"],
  },
  "times new roman": {
    regular: ["Times New Roman.ttf", "Times_New_Roman.ttf", "times.ttf", "LiberationSerif-Regular.ttf", "DejaVuSerif.ttf"],
    bold: ["Times New Roman Bold.ttf", "Times_New_Roman_Bold.ttf", "timesbd.ttf", "LiberationSerif-Bold.ttf", "DejaVuSerif-Bold.ttf"],
  },
  "courier new": {
    regular: ["Courier New.ttf", "Courier_New.ttf", "cour.ttf", "LiberationMono-Regular.ttf", "DejaVuSansMono.ttf"],
    bold: ["Courier New Bold.ttf", "Courier_New_Bold.ttf", "courbd.ttf", "LiberationMono-Bold.ttf", "DejaVuSansMono-Bold.ttf"],
  },
  "sans-serif": {
    regular: ["Arial.ttf", "LiberationSans-Regular.ttf", "DejaVuSans.ttf", "FreeSans.ttf"],
    bold: ["Arial Bold.ttf", "LiberationSans-Bold.ttf", "DejaVuSans-Bold.ttf", "FreeSansBold.ttf"],
  },
};
const ALIASES: Record<string, string> = {
  helvetica: "arial",
  "helvetica neue": "arial",
  geneva: "verdana",
  "trebuchet ms": "verdana",
  tahoma: "verdana",
  courier: "courier new",
  times: "times new roman",
  monospace: "courier new",
  serif: "times new roman",
  "palatino linotype": "georgia",
  palatino: "georgia",
  "book antiqua": "georgia",
};

function findFont(fileName: string): string | null {
  for (const dir of FONT_DIRS) {
    try {
      const p = `${dir}/${fileName}`;
      Deno.statSync(p);
      return p;
    } catch {}
    // One level deep
    try {
      for (const entry of Deno.readDirSync(dir)) {
        if (entry.isDirectory) {
          const p = `${dir}/${entry.name}/${fileName}`;
          try { Deno.statSync(p); return p; } catch {}
        }
      }
    } catch {}
  }
  return null;
}

function resolveFont(family: string, weight: "regular" | "bold"): string | null {
  const families = family.split(",").map((f) => f.trim().replace(/['"]/g, "").toLowerCase());
  for (const f of families) {
    const norm = ALIASES[f] || f;
    const map = FONT_FILE_MAP[norm];
    if (!map) continue;
    const candidates = weight === "bold" ? map.bold : map.regular;
    for (const fileName of candidates) {
      const found = findFont(fileName);
      if (found) return found;
    }
  }
  return null;
}

// ============================================================
// Font module loading with multi-font support
// ============================================================
interface FontInstance {
  measureText: (text: string, fontSize: number) => number;
  glyphToSvgPath?: (cp: number, fs: number) => string;
  glyphOutlineCommands?: (cp: number, fs: number) => string;
  glyphAdvance?: (cp: number, fs: number) => number;
  kernAdvance?: (cp1: number, cp2: number, fs: number) => number;
  ascentRatio: number;
}

// Cache of loaded font instances: family -> { regular, bold }
const fontCache = new Map<string, { regular?: FontInstance; bold?: FontInstance }>();

function fontPathLabel(fontPath: string | URL): string {
  return fontPath instanceof URL ? fontPath.pathname : fontPath;
}

async function loadFontInstance(fontPath: string | URL): Promise<FontInstance | null> {
  try {
    const cacheBuster = `?f=${encodeURIComponent(String(fontPath))}`;
    const mod = await import(`${fontModuleUrl}${cacheBuster}`);
    const loadFont = mod.loadFont ?? mod.default?.loadFont;
    const measureText = mod.measureText ?? mod.default?.measureText;
    const glyphToSvgPath = mod.glyphToSvgPath ?? mod.default?.glyphToSvgPath;
    const glyphOutlineCommands = mod.glyphOutlineCommands ?? mod.default?.glyphOutlineCommands;
    const glyphAdvance = mod.glyphAdvance ?? mod.default?.glyphAdvance;
    const kernAdvance = mod.kernAdvance ?? mod.default?.kernAdvance;
    const getFontInfo = mod.getFontInfo ?? mod.default?.getFontInfo;

    if (!loadFont || !measureText) return null;

    const bytes = Deno.readFileSync(fontPath);
    loadFont(bytes);

    let ascentRatio = 0.8;
    if (getFontInfo) {
      try {
        const info = JSON.parse(getFontInfo() as string);
        ascentRatio = (info.ascent || 0) / (info.units_per_em || 2048);
      } catch {}
    }

    return {
      measureText: (text, fontSize) => measureText(text, fontSize) as number,
      glyphToSvgPath: glyphToSvgPath ? (cp, fs) => glyphToSvgPath(cp, fs) as string : undefined,
      glyphOutlineCommands: glyphOutlineCommands ? (cp, fs) => glyphOutlineCommands(cp, fs) as string : undefined,
      glyphAdvance: glyphAdvance ? (cp, fs) => glyphAdvance(cp, fs) as number : undefined,
      kernAdvance: kernAdvance ? (cp1, cp2, fs) => kernAdvance(cp1, cp2, fs) as number : undefined,
      ascentRatio,
    };
  } catch {
    return null;
  }
}

// Pre-load common fonts
const PRELOAD_FAMILIES = ["arial", "verdana", "georgia", "times new roman", "courier new"];

async function preloadFonts() {
  for (const family of PRELOAD_FAMILIES) {
    const regularPath = resolveFont(family, "regular");
    const boldPath = resolveFont(family, "bold");
    if (!regularPath) continue;

    const regular = await loadFontInstance(regularPath);
    if (!regular) continue;
    console.error(`[font] ${family}: ${regularPath}`);

    let bold: FontInstance | null = null;
    if (boldPath) {
      bold = await loadFontInstance(boldPath);
      if (bold) console.error(`[font] ${family} bold: ${boldPath}`);
    }

    fontCache.set(family, { regular: regular || undefined, bold: bold || undefined });
  }
  // Set sans-serif = arial
  if (fontCache.has("arial")) {
    fontCache.set("sans-serif", fontCache.get("arial")!);
    fontCache.set("helvetica", fontCache.get("arial")!);
  }
  if (fontCache.has("times new roman")) {
    fontCache.set("serif", fontCache.get("times new roman")!);
  }
  if (fontCache.has("courier new")) {
    fontCache.set("monospace", fontCache.get("courier new")!);
  }
}

async function preloadBundledWptFonts() {
  for (const font of listBundledWptFonts()) {
    const fontUrl = resolveBundledWptFontUrl(font.fileName);
    try {
      Deno.statSync(fontUrl);
    } catch {
      continue;
    }

    const regular = await loadFontInstance(fontUrl);
    if (!regular) continue;

    const entry = { regular };
    fontCache.set(font.family, entry);
    for (const alias of font.aliases ?? []) {
      fontCache.set(alias.toLowerCase(), entry);
    }
    console.error(`[font] ${font.family}: ${fontPathLabel(fontUrl)}`);
  }
}

function getFontInstance(fontFamily: string, isBold: boolean): FontInstance | null {
  const families = resolveEffectiveFontFamily(fontFamily)
    .split(",")
    .map((f) => f.trim().replace(/['"]/g, "").toLowerCase());
  for (const f of families) {
    const norm = ALIASES[f] || f;
    const entry = fontCache.get(norm);
    if (entry) {
      if (isBold && entry.bold) return entry.bold;
      if (entry.regular) return entry.regular;
    }
  }
  // Fallback to first loaded font
  const fallback = fontCache.get("arial") || fontCache.values().next().value;
  if (!fallback) return null;
  return isBold && fallback.bold ? fallback.bold : fallback.regular || null;
}

// ============================================================
// Install global providers
// ============================================================
await preloadFonts();
await preloadBundledWptFonts();

const defaultFont = getFontInstance(DEFAULT_TEXT_FONT_FAMILY, false);
if (!defaultFont) {
  console.error("[font] No font loaded, using monospace fallback");
} else {
  // Regular text metrics (uses font_family to select font)
  (globalThis as any).__craterMeasureTextIntrinsic = createTextIntrinsicFnFromMeasureText(
    (text: string, fontSize: number) => defaultFont.measureText(text, fontSize),
  );

  // Multi-font text intrinsic functions (cached per font instance)
  const intrinsicCache = new Map<FontInstance, ReturnType<typeof createTextIntrinsicFnFromMeasureText>>();
  function getIntrinsicFn(font: FontInstance) {
    let fn = intrinsicCache.get(font);
    if (!fn) {
      fn = createTextIntrinsicFnFromMeasureText(
        (text: string, fontSize: number) => font.measureText(text, fontSize),
      );
      intrinsicCache.set(font, fn);
    }
    return fn;
  }

  // Full multi-font text intrinsic (with available_width for word-wrap)
  (globalThis as any).__craterMeasureTextIntrinsicMultiFull = (
    text: string,
    fontSize: number,
    lineHeight: number,
    whiteSpace: string,
    writingMode: string,
    availableWidth: number,
    availableHeight: number,
    fontFamily: string,
    isBold: boolean,
  ) => {
    const font = getFontInstance(fontFamily, isBold);
    if (!font) return null;
    const fn = getIntrinsicFn(font);
    return fn(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight);
  };

  // Simple multi-font text metrics (backward compat)
  (globalThis as any).__craterMeasureTextIntrinsicMulti = (
    text: string,
    fontSize: number,
    fontFamily: string,
    isBold: boolean,
  ): { minWidth: number; maxWidth: number; minHeight: number; maxHeight: number } | null => {
    const font = getFontInstance(fontFamily, isBold);
    if (!font) return null;
    // Use full intrinsic measurement (with word-wrap calculation)
    const fn = getIntrinsicFn(font);
    const lineHeight = fontSize > 0 ? fontSize * 1.2 : 16;
    return fn(text, fontSize, lineHeight, "normal", "horizontal-tb", 9999, 9999);
  };

  // Ascent ratio (default font)
  (globalThis as any).__craterFontAscentRatio = () => defaultFont.ascentRatio;
  console.error(`[font] Ascent ratio: ${defaultFont.ascentRatio.toFixed(4)}`);

  // Glyph providers (default font for SVG rendering)
  if (defaultFont.glyphToSvgPath && defaultFont.glyphAdvance) {
    (globalThis as any).__craterGlyphToSvgPath = defaultFont.glyphToSvgPath;
    (globalThis as any).__craterGlyphAdvance = defaultFont.glyphAdvance;
    if (defaultFont.kernAdvance) {
      (globalThis as any).__craterKernAdvance = defaultFont.kernAdvance;
    }
    console.error(`[font] Glyph provider installed (kern=${!!defaultFont.kernAdvance})`);
  }

  // Outline commands provider (returns JSON array, avoids SVG string roundtrip)
  if (defaultFont.glyphOutlineCommands) {
    (globalThis as any).__craterGlyphOutlineCommands = defaultFont.glyphOutlineCommands;
    console.error(`[font] Outline commands provider installed`);
  }

  // Bold glyph providers
  const boldFont = getFontInstance(DEFAULT_TEXT_FONT_FAMILY, true);
  if (boldFont && boldFont.glyphToSvgPath && boldFont.glyphAdvance) {
    (globalThis as any).__craterGlyphToSvgPathBold = boldFont.glyphToSvgPath;
    (globalThis as any).__craterGlyphAdvanceBold = boldFont.glyphAdvance;
    if (boldFont.kernAdvance) {
      (globalThis as any).__craterKernAdvanceBold = boldFont.kernAdvance;
    }
    if (boldFont.glyphOutlineCommands) {
      (globalThis as any).__craterGlyphOutlineCommandsBold = boldFont.glyphOutlineCommands;
    }
    (globalThis as any).__craterMeasureTextIntrinsicBold = createTextIntrinsicFnFromMeasureText(
      (text: string, fontSize: number) => boldFont.measureText(text, fontSize),
    );
    console.error(`[font] Bold glyph provider installed`);
  }

  // Multi-font outline commands provider (returns JSON array, avoids SVG string roundtrip)
  (globalThis as any).__craterOutlineCommandsForFamily = (cp: number, fs: number, isBold: boolean, ff: string) => {
    const font = getFontInstance(ff, isBold);
    if (!font || !font.glyphOutlineCommands) return "";
    return font.glyphOutlineCommands(cp, fs);
  };

  // Multi-font glyph providers for sixel rendering
  (globalThis as any).__craterGlyphForFamily = (cp: number, fs: number, isBold: boolean, ff: string) => {
    const font = getFontInstance(ff, isBold);
    if (!font || !font.glyphToSvgPath) return "";
    return font.glyphToSvgPath(cp, fs);
  };
  (globalThis as any).__craterAdvanceForFamily = (cp: number, fs: number, isBold: boolean, ff: string) => {
    const font = getFontInstance(ff, isBold);
    if (!font || !font.glyphAdvance) return fs * 0.5;
    return font.glyphAdvance(cp, fs);
  };
  (globalThis as any).__craterKernForFamily = (cp1: number, cp2: number, fs: number, isBold: boolean, ff: string) => {
    const font = getFontInstance(ff, isBold);
    if (!font || !font.kernAdvance) return 0;
    return font.kernAdvance(cp1, cp2, fs);
  };
  (globalThis as any).__craterAscentForFamily = (ff: string) => {
    const font = getFontInstance(ff, false);
    return font ? font.ascentRatio : 0.8;
  };
}

console.error(`[font] ${fontCache.size} font families loaded`);

// Intercept stdout to capture WebSocket URL and write it to a file for test clients
const originalWrite = Deno.stdout.writeSync.bind(Deno.stdout);
const decoder = new TextDecoder();
const WS_URL_FILE = `${Deno.cwd()}/.bidi-ws-url`;

const origLog = console.log;
console.log = (...args: unknown[]) => {
  const msg = args.map(String).join(" ");
  origLog(...args);
  const match = msg.match(/Starting WebDriver BiDi server on (ws:\/\/\S+)/);
  if (match) {
    Deno.writeTextFileSync(WS_URL_FILE, match[1]);
    console.error(`[bidi] WS URL written to ${WS_URL_FILE}`);
  }
};

// Clean up URL file on exit
globalThis.addEventListener("unload", () => {
  try { Deno.removeSync(WS_URL_FILE); } catch {}
});

// Start the BiDi server (warmup_glyph_cache is called in main() before server.start())
await import(resolveBidiMainBuildUrl(Deno.cwd()));
