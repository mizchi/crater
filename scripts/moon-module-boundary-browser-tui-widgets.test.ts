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

describe("MoonBit browser TUI widget boundaries", () => {
  it("keeps browser tui primitives behind the tui primitives package", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/tui/primitives/moon.pkg"))).toBe(true);

    const rootImplementationMarkers = new Map<string, readonly string[]>([
      ["browser/tui/ansi.mbt", ["priv struct AnsiStyleState", "pub(all) struct DirtyRect"]],
      ["browser/tui/buffer.mbt", ["pub struct CharBuffer", "fn is_wide_char"]],
      ["browser/tui/widget.mbt", ["fn box_chars", "pub(all) enum BoxStyle"]],
    ]);
    const offenders: string[] = [];
    for (const [relativeFile, markers] of rootImplementationMarkers) {
      const source = fs.readFileSync(path.join(REPO_ROOT, relativeFile), "utf8");
      for (const marker of markers) {
        if (source.includes(marker)) {
          offenders.push(`${relativeFile}: ${marker}`);
        }
      }
    }

    expect(offenders).toEqual([]);
  });

  it("splits browser tui scrollbar widget out of box widgets", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/widget.mbt"), "utf8");
    const scrollbarSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/scrollbar_widget.mbt"), "utf8");

    expect(scrollbarSource).toContain("pub fn draw_scrollbar(");
    expect(scrollbarSource).toContain("@tui_buffer.plan_scrollbar(");
    expect(source).not.toContain("pub fn draw_scrollbar(");
    expect(source).not.toContain("@tui_buffer.plan_scrollbar(");
  });

  it("keeps text widgets and status bars out of box primitive widgets", () => {
    const widgetSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/widget.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/text_widget.mbt"), "utf8");
    const statusSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/status_bar.mbt"), "utf8");

    expect(textSource).toContain("pub fn draw_link(");
    expect(textSource).toContain("pub fn draw_heading(");
    expect(statusSource).toContain("pub fn draw_status_bar(");
    expect(widgetSource).not.toContain("pub fn draw_link(");
    expect(widgetSource).not.toContain("pub fn draw_heading(");
    expect(widgetSource).not.toContain("pub fn draw_status_bar(");
  });
});
