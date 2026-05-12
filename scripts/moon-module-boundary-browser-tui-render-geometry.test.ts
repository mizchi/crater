import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI render geometry boundaries", () => {
  it("splits browser tui render geometry out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const geometrySource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_geometry.mbt"), "utf8");

    expect(geometrySource).toContain("pub fn px_to_col(");
    expect(geometrySource).toContain("pub fn dirty_rects_to_cells(");
    expect(renderSource).not.toContain("fn px_to_col_width(");
    expect(renderSource).not.toContain("pub fn dirty_rects_to_cells(");
  });

  it("splits browser tui render context types out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const contextSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_context.mbt"), "utf8");

    expect(contextSource).toContain("pub(all) struct ElementScrollPos");
    expect(contextSource).toContain("pub struct TuiContext");
    expect(contextSource).toContain("element_scroll_positions : Map[String, ElementScrollPos]");
    expect(renderSource).not.toContain("pub(all) struct ElementScrollPos");
    expect(renderSource).not.toContain("pub struct TuiContext");
  });

  it("splits browser tui render clipping out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const clipSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_clip.mbt"), "utf8");

    expect(clipSource).toContain("fn get_local_clip_rect(");
    expect(clipSource).toContain("fn combine_clip_rects(");
    expect(renderSource).not.toContain("fn get_local_clip_rect(");
    expect(renderSource).not.toContain("fn resolve_clip_path_rect(");
  });

  it("splits browser tui clip-path resolution out of clip composition", () => {
    const clipSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_clip.mbt"), "utf8");
    const clipPathSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_clip_path.mbt"), "utf8");
    const valueSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_clip_path_value.mbt"), "utf8");

    expect(valueSource).toContain("fn resolve_clip_path_position(");
    expect(clipPathSource).toContain("fn resolve_clip_path_rect(");
    expect(clipPathSource).toContain("fn resolve_clip_path_circle(");
    expect(clipPathSource).toContain("fn polygon_bounding_rect(");
    expect(clipSource).not.toContain("fn resolve_clip_path_position(");
    expect(clipSource).not.toContain("fn resolve_clip_path_rect(");
    expect(clipSource).not.toContain("fn polygon_bounding_rect(");
  });

  it("splits browser tui clip-path scalar resolution out of shape resolution", () => {
    const clipPathSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_clip_path.mbt"), "utf8");
    const valueSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_clip_path_value.mbt"), "utf8");

    expect(valueSource).toContain("fn resolve_clip_path_position(");
    expect(valueSource).toContain("fn resolve_clip_path_axis_radius(");
    expect(valueSource).toContain("fn resolve_clip_path_radius(");
    expect(valueSource).toContain("fn resolve_clip_path_inset(");
    expect(clipPathSource).toContain("fn resolve_clip_path_polygon(");
    expect(clipPathSource).not.toContain("fn resolve_clip_path_position(");
    expect(clipPathSource).not.toContain("fn resolve_clip_path_inset(");
  });
});
