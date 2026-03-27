/**
 * System font resolver — maps CSS font-family names to local file paths.
 * Works on macOS and Linux.
 */
import * as fs from "node:fs";
import * as path from "node:path";
import { execSync } from "node:child_process";

const HOME = process.env.HOME || Deno?.env?.get?.("HOME") || "/tmp";

interface FontEntry {
  family: string;
  style: "regular" | "bold" | "italic" | "bolditalic";
  path: string;
}

// macOS font directories
const MAC_FONT_DIRS = [
  "/System/Library/Fonts",
  "/System/Library/Fonts/Supplemental",
  "/Library/Fonts",
  `${HOME}/Library/Fonts`,
];

// Linux font directories
const LINUX_FONT_DIRS = [
  "/usr/share/fonts",
  "/usr/local/share/fonts",
  `${HOME}/.fonts`,
  `${HOME}/.local/share/fonts`,
];

// Well-known font mappings (family name → file name patterns)
const FONT_FILE_MAP: Record<string, { regular: string[]; bold: string[] }> = {
  arial: {
    regular: ["Arial.ttf", "arial.ttf", "LiberationSans-Regular.ttf", "DejaVuSans.ttf"],
    bold: ["Arial Bold.ttf", "arial-bold.ttf", "LiberationSans-Bold.ttf", "DejaVuSans-Bold.ttf"],
  },
  verdana: {
    regular: ["Verdana.ttf", "verdana.ttf"],
    bold: ["Verdana Bold.ttf", "verdana-bold.ttf"],
  },
  "times new roman": {
    regular: ["Times New Roman.ttf", "timesnewroman.ttf", "LiberationSerif-Regular.ttf", "DejaVuSerif.ttf"],
    bold: ["Times New Roman Bold.ttf", "LiberationSerif-Bold.ttf", "DejaVuSerif-Bold.ttf"],
  },
  georgia: {
    regular: ["Georgia.ttf", "georgia.ttf"],
    bold: ["Georgia Bold.ttf", "georgia-bold.ttf"],
  },
  courier: {
    regular: ["Courier New.ttf", "courier-new.ttf", "LiberationMono-Regular.ttf", "DejaVuSansMono.ttf"],
    bold: ["Courier New Bold.ttf", "LiberationMono-Bold.ttf", "DejaVuSansMono-Bold.ttf"],
  },
  "sans-serif": {
    regular: ["Arial.ttf", "LiberationSans-Regular.ttf", "DejaVuSans.ttf", "NotoSans-Regular.ttf"],
    bold: ["Arial Bold.ttf", "LiberationSans-Bold.ttf", "DejaVuSans-Bold.ttf", "NotoSans-Bold.ttf"],
  },
  serif: {
    regular: ["Times New Roman.ttf", "LiberationSerif-Regular.ttf", "DejaVuSerif.ttf", "NotoSerif-Regular.ttf"],
    bold: ["Times New Roman Bold.ttf", "LiberationSerif-Bold.ttf", "DejaVuSerif-Bold.ttf"],
  },
  monospace: {
    regular: ["Courier New.ttf", "LiberationMono-Regular.ttf", "DejaVuSansMono.ttf", "NotoSansMono-Regular.ttf"],
    bold: ["Courier New Bold.ttf", "LiberationMono-Bold.ttf", "DejaVuSansMono-Bold.ttf"],
  },
};

// Aliases
const FAMILY_ALIASES: Record<string, string> = {
  "helvetica": "arial",
  "helvetica neue": "arial",
  "courier new": "courier",
  "times": "times new roman",
  "dejavu sans": "sans-serif",
  "liberation sans": "arial",
  "noto sans": "sans-serif",
};

function getFontDirs(): string[] {
  const platform = typeof Deno !== "undefined" ? Deno.build.os : process.platform;
  if (platform === "darwin") return MAC_FONT_DIRS;
  return LINUX_FONT_DIRS;
}

function findFontFile(fileName: string, dirs: string[]): string | null {
  for (const dir of dirs) {
    // Direct match
    const direct = path.join(dir, fileName);
    try {
      if (fs.statSync(direct).isFile()) return direct;
    } catch {}
    // Recursive search (one level deep)
    try {
      for (const sub of fs.readdirSync(dir)) {
        const subPath = path.join(dir, sub, fileName);
        try {
          if (fs.statSync(subPath).isFile()) return subPath;
        } catch {}
      }
    } catch {}
  }
  return null;
}

// Try fc-match on Linux
function fcMatch(family: string, style: string = "regular"): string | null {
  try {
    const result = execSync(
      `fc-match -f "%{file}" "${family}:style=${style}"`,
      { encoding: "utf8", timeout: 3000, stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
    if (result && fs.existsSync(result)) return result;
  } catch {}
  return null;
}

/**
 * Resolve a CSS font-family string to a file path.
 * Handles comma-separated font lists like "Verdana, Geneva, sans-serif".
 */
export function resolveFont(
  fontFamily: string,
  weight: "regular" | "bold" = "regular",
): string | null {
  const dirs = getFontDirs();
  const families = fontFamily.split(",").map((f) => f.trim().replace(/['"]/g, "").toLowerCase());

  for (const family of families) {
    const normalized = FAMILY_ALIASES[family] || family;
    const mapping = FONT_FILE_MAP[normalized];
    if (mapping) {
      const candidates = weight === "bold" ? mapping.bold : mapping.regular;
      for (const fileName of candidates) {
        const found = findFontFile(fileName, dirs);
        if (found) return found;
      }
    }
    // Try fc-match (Linux)
    const fcResult = fcMatch(family, weight === "bold" ? "Bold" : "Regular");
    if (fcResult) return fcResult;
  }
  return null;
}

/**
 * Resolve default fallback font.
 */
export function resolveDefaultFont(weight: "regular" | "bold" = "regular"): string | null {
  return resolveFont("arial, sans-serif", weight);
}

/**
 * Build a font map: family name → { regular: path, bold: path }
 */
export function buildFontMap(families: string[]): Map<string, { regular: string | null; bold: string | null }> {
  const map = new Map<string, { regular: string | null; bold: string | null }>();
  for (const family of families) {
    map.set(family.toLowerCase(), {
      regular: resolveFont(family, "regular"),
      bold: resolveFont(family, "bold"),
    });
  }
  return map;
}

// CLI usage
if (import.meta.main || (typeof require !== "undefined" && require.main === module)) {
  const families = ["Arial", "Verdana", "Georgia", "Times New Roman", "Courier New", "sans-serif", "serif", "monospace"];
  console.log("System Font Resolution:");
  for (const f of families) {
    const regular = resolveFont(f, "regular");
    const bold = resolveFont(f, "bold");
    console.log(`  ${f}:`);
    console.log(`    Regular: ${regular || "NOT FOUND"}`);
    console.log(`    Bold: ${bold || "NOT FOUND"}`);
  }
}
