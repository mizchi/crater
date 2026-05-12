import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit painter raster node boundaries", () => {
  it("splits raster node text rendering out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_node_text.mbt"), "utf8");

    expect(source.includes("fn render_node_text_content(")).toBe(true);
    expect(source.includes("fn render_node_text_decorations(")).toBe(true);
    expect(source.includes("@glyph.get_glyph_provider()")).toBe(true);
    expect(source.includes("draw_text_decoration_line(")).toBe(true);
    expect(rasterSource.includes("glyph_provider_override.val")).toBe(false);
    expect(rasterSource.includes("draw_text_decoration_line(")).toBe(false);
  });

  it("splits raster node box decorations out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_node_box.mbt"), "utf8");

    expect(source.includes("fn render_node_box_decorations(")).toBe(true);
    expect(source.includes("fill_blurred_box_shadow_clipped(")).toBe(true);
    expect(source.includes("fill_linear_gradient_clipped(")).toBe(true);
    expect(source.includes("draw_uniform_rounded_border_ring_clipped(")).toBe(true);
    expect(source.includes("let rounded_border_drawn")).toBe(true);
    expect(rasterSource.includes("fill_blurred_box_shadow_clipped(")).toBe(false);
    expect(rasterSource.includes("fill_linear_gradient_clipped(")).toBe(false);
    expect(rasterSource.includes("draw_uniform_rounded_border_ring_clipped(")).toBe(false);
  });

  it("splits raster node content rendering out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_node_content.mbt"), "utf8");

    expect(source.includes("fn render_node_content(")).toBe(true);
    expect(source.includes("render_image_src_into_region(")).toBe(true);
    expect(source.includes("render_node_text_content(")).toBe(true);
    expect(source.includes("render_node_text_decorations(")).toBe(true);
    expect(rasterSource.includes("let drew_replaced_image")).toBe(false);
    expect(rasterSource.includes("render_image_src_into_region(")).toBe(false);
  });

  it("splits raster node child rendering out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_node_children.mbt"), "utf8");

    expect(source.includes("fn render_node_children_clipped(")).toBe(true);
    expect(source.includes("clip_intersect(")).toBe(true);
    expect(source.includes("let child_with_opacity")).toBe(true);
    expect(source.includes("render_paint_node_clipped(")).toBe(true);
    expect(rasterSource.includes("let child_with_opacity")).toBe(false);
    expect(rasterSource.includes("clip_intersect(")).toBe(false);
  });

  it("splits raster node visibility helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_node_visibility.mbt"), "utf8");

    expect(source.includes("fn is_visually_hidden_paint_node(")).toBe(true);
    expect(source.includes("fn is_node_outside_framebuffer(")).toBe(true);
    expect(source.includes("fn is_node_outside_clip(")).toBe(true);
    expect(source.includes('node.tag == "#text"')).toBe(true);
    expect(rasterSource.includes('node.tag == "#text"')).toBe(false);
    expect(rasterSource.includes("x >= fb.width || y >= fb.height")).toBe(false);
  });
});
