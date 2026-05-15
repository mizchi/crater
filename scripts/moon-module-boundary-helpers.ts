import fs from "node:fs";
import path from "node:path";

export const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const SKIP_DIRS = new Set([
  ".git",
  ".moon",
  ".mooncakes",
  ".repos",
  "_build",
  "dist",
  "node_modules",
  "output",
  "target",
  "test-results",
]);

export const DIRECT_TUI_TERMINAL_PROTOCOL_FILES = new Set([
  "terminal_protocol/moon.mod.json",
  "terminal_protocol/ansi/moon.pkg",
  "terminal_protocol/kitty/moon.pkg",
  "terminal_protocol/sixel/moon.pkg",
]);

export const BROWSER_TERMINAL_PROTOCOL_ANSI_FILES = new Set([
  "browser/moon.mod.json",
  "browser/tui/primitives/moon.pkg",
]);

export function collectMoonPackageFiles(dir: string, out: string[] = []): string[] {
  for (const dirent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (dirent.isDirectory()) {
      if (!SKIP_DIRS.has(dirent.name)) {
        collectMoonPackageFiles(path.join(dir, dirent.name), out);
      }
      continue;
    }
    if (dirent.name === "moon.pkg" || dirent.name === "moon.mod.json") {
      out.push(path.join(dir, dirent.name));
    }
  }
  return out;
}

export function collectMoonBitFiles(dir: string, out: string[] = []): string[] {
  for (const dirent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (dirent.isDirectory()) {
      if (!SKIP_DIRS.has(dirent.name)) {
        collectMoonBitFiles(path.join(dir, dirent.name), out);
      }
      continue;
    }
    if (dirent.name.endsWith(".mbt")) {
      out.push(path.join(dir, dirent.name));
    }
  }
  return out;
}

export function countLines(relativePath: string): number {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8").split(/\r?\n/).length;
}

export function readSvgInteropSources(): string {
  const svgDir = path.join(REPO_ROOT, "painter/svg");
  return fs
    .readdirSync(svgDir)
    .filter((file) => file === "interop.mbt" || /^interop_[a-z_]+\.mbt$/.test(file))
    .sort()
    .map((file) => fs.readFileSync(path.join(svgDir, file), "utf8"))
    .join("\n");
}
