export interface BundledWptFontDefinition {
  family: string;
  fileName: string;
  aliases?: string[];
}

const WPT_FONTS_DIR_URL = new URL("../wpt/fonts/", import.meta.url);

const BUNDLED_WPT_FONTS: readonly BundledWptFontDefinition[] = [
  {
    family: "ahem",
    fileName: "Ahem.ttf",
  },
] as const;

function normalizeFontFamily(family: string): string {
  return family.trim().replace(/['"]/g, "").toLowerCase();
}

export function listBundledWptFonts(): readonly BundledWptFontDefinition[] {
  return BUNDLED_WPT_FONTS;
}

export function resolveBundledWptFontByFamily(
  family: string,
): BundledWptFontDefinition | null {
  const normalized = normalizeFontFamily(family);
  if (!normalized) {
    return null;
  }
  for (const font of BUNDLED_WPT_FONTS) {
    if (font.family === normalized) {
      return font;
    }
    if (font.aliases?.some((alias) => normalizeFontFamily(alias) === normalized)) {
      return font;
    }
  }
  return null;
}

export function resolveBundledWptFontUrl(fileName: string): URL {
  return new URL(fileName, WPT_FONTS_DIR_URL);
}
