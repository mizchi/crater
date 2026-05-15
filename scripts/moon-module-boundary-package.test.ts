import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  BROWSER_TERMINAL_PROTOCOL_ANSI_FILES,
  DIRECT_TUI_TERMINAL_PROTOCOL_FILES,
  REPO_ROOT,
  collectMoonBitFiles,
  collectMoonPackageFiles,
  countLines,
} from "./moon-module-boundary-helpers";

describe("MoonBit package and compatibility boundaries", () => {
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
        const relativeFile = path.relative(REPO_ROOT, file);
        const allowedAnsiFacade = BROWSER_TERMINAL_PROTOCOL_ANSI_FILES.has(relativeFile) &&
          (source.includes("mizchi/crater-terminal-protocol/ansi") ||
            source.includes('"mizchi/crater-terminal-protocol"')) &&
          !source.includes("mizchi/crater-terminal-protocol/kitty") &&
          !source.includes("mizchi/crater-terminal-protocol/sixel");
        return (source.includes("mizchi/crater-terminal-protocol") && !allowedAnsiFacade) ||
          source.includes("mizchi/crater-painter/x/kitty") ||
          source.includes("mizchi/crater-painter-terminal/kitty");
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps terminal protocol implementation out of crater-painter", () => {
    const offenders = collectMoonPackageFiles(path.join(REPO_ROOT, "painter"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return source.includes("mizchi/crater-terminal-protocol") ||
          source.includes("mizchi/crater-painter/x/kitty");
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps framebuffer raster implementation names protocol-neutral", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/raster/sixel.mbt"))).toBe(false);
  });

  it("keeps painter-terminal root facade behind terminal-specific packages", () => {
    const rootPackage = path.join(REPO_ROOT, "painter_terminal/moon.pkg");
    const source = fs.readFileSync(rootPackage, "utf8");

    expect(source).not.toContain("mizchi/crater-terminal-protocol");
  });

  it("keeps terminal output helpers out of crater-renderer", () => {
    const terminalOutputMarkers = [
      "mizchi/crater-painter-terminal/kitty",
      "mizchi/crater-painter/paint/raster",
      "render_to_sixel",
      "render_to_kitty",
      "write_kitty",
    ] as const;
    const offenders = collectMoonPackageFiles(path.join(REPO_ROOT, "renderer"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return terminalOutputMarkers.some((marker) => source.includes(marker));
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps the retired browser_shell facade out of the workspace", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser_shell"))).toBe(false);
    const workspace = fs.readFileSync(path.join(REPO_ROOT, "moon.work"), "utf8");
    expect(workspace).not.toContain('"./browser_shell"');
  });

  it("documents compatibility bridge ownership", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "docs/compatibility-bridges.md"), "utf8");
    const requiredBridges = [
      "mizchi/crater-browser/js",
      "mizchi/crater-dom/layout/html_bridge",
      "mizchi/crater-painter/paint/layout_bridge",
      "mizchi/crater-painter/paint/render_bridge",
      "mizchi/crater-painter/paint/glyph",
      "mizchi/crater-webdriver-bidi/contract",
      "mizchi/crater-webdriver-bidi/rpc",
      "mizchi/crater-webdriver-bidi/runtime",
      "mizchi/crater-webdriver-bidi/protocol",
      "mizchi/crater-webdriver-bidi/protocol/wire",
      "mizchi/crater-webdriver-bidi/network",
      "mizchi/crater-network",
    ] as const;

    const missing = requiredBridges.filter((bridge) => !source.includes(bridge));
    expect(missing).toEqual([]);
  });
});
