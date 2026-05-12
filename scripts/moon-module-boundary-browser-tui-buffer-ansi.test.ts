import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI buffer ANSI boundaries", () => {
  it("delegates reusable browser tui ANSI primitives to crater terminal protocol ansi", () => {
    const pkg = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/moon.pkg"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi.mbt"), "utf8");
    const colorSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi_color.mbt"), "utf8");

    expect(pkg).toContain('"mizchi/crater-terminal-protocol/ansi" @tui_ansi');
    expect(source).toContain("@tui_ansi.ansi_reset()");
    expect(source).toContain("@tui_ansi.ansi_bold()");
    expect(source).toContain("@tui_ansi.ansi_underline()");
    expect(source).toContain("@tui_ansi.ansi_reverse()");
    expect(source).toContain("@tui_ansi.ansi_fg_256(color_idx)");
    expect(source).toContain("@tui_ansi.ansi_bg_256(color_idx)");
    expect(source).toContain("@tui_ansi.ansi_move_to(row - 1, col - 1)");
    expect(colorSource).toContain("@tui_ansi.rgb_to_256(r, g, b)");
    expect(source).not.toContain("pub fn rgb_to_256(");
    expect(source).toContain("@tui_ansi.enable_mouse_all()");
    expect(source).toContain("@tui_ansi.disable_mouse_all()");
  });

  it("delegates browser tui ANSI cell scan planning to tui terminal buffer", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi.mbt"), "utf8");
    const diffSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi_diff.mbt"), "utf8");

    expect(source).toContain("@tui_buffer.plan_buffer_cells(");
    expect(diffSource).toContain("@tui_buffer.plan_dirty_cells(");
    expect(source).not.toContain("let visited : Array[Bool]");
    expect(source).not.toContain("let mut x0 = rect.col");
  });

  it("splits browser tui ANSI style state out of the ANSI facade", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi.mbt"), "utf8");
    const styleSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi_style.mbt"), "utf8");

    expect(styleSource).toContain("priv struct AnsiStyleState");
    expect(styleSource).toContain("fn AnsiStyleState::write_cell_style(");
    expect(source).not.toContain("priv struct AnsiStyleState");
    expect(source).not.toContain("fn AnsiStyleState::write_cell_style(");
  });

  it("splits browser tui ANSI diff rendering out of the ANSI facade", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi.mbt"), "utf8");
    const diffSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi_diff.mbt"), "utf8");

    expect(diffSource).toContain("pub(all) struct DirtyRect");
    expect(diffSource).toContain("pub fn buffer_diff_to_ansi(");
    expect(diffSource).toContain("pub fn buffer_diff_to_ansi_rects(");
    expect(source).not.toContain("pub(all) struct DirtyRect");
    expect(source).not.toContain("pub fn buffer_diff_to_ansi(");
    expect(source).not.toContain("pub fn buffer_diff_to_ansi_rects(");
  });

  it("splits browser tui plain ANSI rendering out of the ANSI facade", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi.mbt"), "utf8");
    const plainSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/ansi_plain.mbt"), "utf8");

    expect(plainSource).toContain("pub(all) struct PlainLink");
    expect(plainSource).toContain("priv struct PlainStyleState");
    expect(plainSource).toContain("pub fn buffer_to_plain(");
    expect(plainSource).toContain("pub fn buffer_to_plain_with_links(");
    expect(source).not.toContain("pub(all) struct PlainLink");
    expect(source).not.toContain("priv struct PlainStyleState");
    expect(source).not.toContain("pub fn buffer_to_plain(");
    expect(source).not.toContain("pub fn buffer_to_plain_with_links(");
  });

  it("centralizes browser tui ANSI render result projection", () => {
    const resultSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_result.mbt"), "utf8");
    const outputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_output.mbt"), "utf8");
    const hintsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hints_output.mbt"), "utf8");
    const statusSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_status_output.mbt"), "utf8");

    expect(resultSource).toContain("fn buffer_render_result_to_ansi(");
    expect(outputSource).toContain("buffer_render_result_to_ansi(result)");
    expect(hintsSource).toContain("buffer_render_result_to_ansi(result)");
    expect(statusSource).toContain("buffer_render_result_to_ansi(result)");
    expect(outputSource).not.toContain("ansi: buffer_to_ansi(result.buffer)");
    expect(hintsSource).not.toContain("ansi: buffer_to_ansi(result.buffer)");
    expect(statusSource).not.toContain("ansi: buffer_to_ansi(result.buffer)");
  });

  it("centralizes browser tui empty buffer render results", () => {
    const resultSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_result.mbt"), "utf8");
    const outputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_output.mbt"), "utf8");
    const hintsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hints_output.mbt"), "utf8");
    const statusSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_status_output.mbt"), "utf8");

    expect(resultSource).toContain("fn empty_buffer_render_result(");
    expect(outputSource).toContain("return empty_buffer_render_result(buf)");
    expect(hintsSource).toContain("return empty_buffer_render_result(buf)");
    expect(statusSource).toContain("return empty_buffer_render_result(buf)");
    expect(outputSource).not.toContain("scrollable_elements: []");
    expect(hintsSource).not.toContain("scrollable_elements: []");
    expect(statusSource).not.toContain("scrollable_elements: []");
  });
});
