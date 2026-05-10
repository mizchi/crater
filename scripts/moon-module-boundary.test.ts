import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const SKIP_DIRS = new Set([
  ".git",
  ".moon",
  ".mooncakes",
  "_build",
  "dist",
  "node_modules",
  "output",
  "target",
  "test-results",
]);

const DIRECT_TUI_TERMINAL_PROTOCOL_FILES = new Set([
  "terminal_protocol/moon.mod.json",
  "terminal_protocol/kitty/moon.pkg",
  "terminal_protocol/sixel/moon.pkg",
]);

function collectMoonPackageFiles(dir: string, out: string[] = []): string[] {
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

function collectMoonBitFiles(dir: string, out: string[] = []): string[] {
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

describe("MoonBit module boundaries", () => {
  it("keeps tui terminal protocol behind crater-terminal-protocol", () => {
    const offenders = collectMoonPackageFiles(REPO_ROOT)
      .filter((file) => fs.readFileSync(file, "utf8").includes("mizchi/tui-terminal-protocol"))
      .map((file) => path.relative(REPO_ROOT, file))
      .filter((file) => !DIRECT_TUI_TERMINAL_PROTOCOL_FILES.has(file));

    expect(offenders).toEqual([]);
  });

  it("keeps browser shell behind painter-terminal facade for kitty output", () => {
    const offenders = collectMoonPackageFiles(path.join(REPO_ROOT, "browser"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return source.includes("mizchi/crater-terminal-protocol") ||
          source.includes("mizchi/crater-painter/x/kitty");
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps terminal image cache implementation out of browser shell", () => {
    const implementationMarkers = [
      "pub struct ImageCache",
      "pub(all) struct RgbaCacheEntry",
      "pub(all) enum TerminalImageCacheEntry",
      "js_decode_raster_image_to_rgba_base64",
      "js_transcode_raster_image_to_png_base64",
    ] as const;
    const offenders = collectMoonBitFiles(path.join(REPO_ROOT, "browser_shell"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return implementationMarkers.some((marker) => source.includes(marker));
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });
});
