import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI render output boundaries", () => {
  it("splits browser tui render output entrypoints out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const outputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_output.mbt"), "utf8");
    const resultSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_result.mbt"), "utf8");

    expect(resultSource).toContain("pub(all) struct RenderResult");
    expect(resultSource).toContain("pub(all) struct ImageRegion");
    expect(resultSource).toContain("pub(all) struct BufferRenderResult");
    expect(outputSource).toContain("pub fn render_to_buffer(");
    expect(outputSource).toContain("pub fn get_content_extent(");
    expect(outputSource).not.toContain("pub(all) struct RenderResult");
    expect(outputSource).not.toContain("pub(all) struct BufferRenderResult");
    expect(outputSource).not.toContain("pub fn render_to_buffer_with_status(");
    expect(outputSource).not.toContain("pub fn render_to_buffer_with_hints(");
    expect(renderSource).not.toContain("pub fn render_to_buffer(");
    expect(renderSource).not.toContain("pub fn render_to_buffer_with_status(");
    expect(renderSource).not.toContain("pub(all) struct RenderResult");
  });

  it("splits browser tui status output entrypoints out of base render output", () => {
    const outputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_output.mbt"), "utf8");
    const statusSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_status_output.mbt"), "utf8");

    expect(statusSource).toContain("pub fn render_to_ansi_with_status(");
    expect(statusSource).toContain("pub fn render_to_buffer_with_status(");
    expect(statusSource).toContain("draw_status_bar(");
    expect(outputSource).not.toContain("pub fn render_to_ansi_with_status(");
    expect(outputSource).not.toContain("pub fn render_to_buffer_with_status(");
  });

  it("splits browser tui hint output entrypoints out of base render output", () => {
    const outputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_output.mbt"), "utf8");
    const hintOutputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hints_output.mbt"), "utf8");

    expect(hintOutputSource).toContain("pub fn render_to_ansi_with_hints(");
    expect(hintOutputSource).toContain("pub fn render_to_buffer_with_hints(");
    expect(hintOutputSource).toContain("draw_hint_mode_status_bar(");
    expect(outputSource).not.toContain("pub fn render_to_ansi_with_hints(");
    expect(outputSource).not.toContain("pub fn render_to_buffer_with_hints(");
  });

  it("splits browser tui hint overlay rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const hintSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hints.mbt"), "utf8");
    const textMeasureSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_text_measure.mbt"), "utf8");

    expect(hintSource).toContain("pub(all) struct HintData");
    expect(hintSource).toContain("fn draw_hints(");
    expect(hintSource).toContain("fn draw_hint_mode_status_bar(");
    expect(textMeasureSource).toContain("fn calculate_text_display_width(");
    expect(renderSource).not.toContain("pub(all) struct HintData");
    expect(renderSource).not.toContain("fn draw_hints(");
    expect(renderSource).not.toContain("fn calculate_text_display_width(");
  });
});
