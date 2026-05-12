import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit painter raster effect boundaries", () => {
  it("splits raster palette helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_palette.mbt"), "utf8");

    expect(source.includes("pub struct DynamicPalette")).toBe(true);
    expect(source.includes("pub fn DynamicPalette::new(")).toBe(true);
    expect(source.includes("fn types_color_to_image(")).toBe(true);
    expect(source.includes("fn clamp_byte(")).toBe(true);
    expect(source.includes("fn palette_color_at(")).toBe(true);
    expect(source.includes("fn DynamicPalette::get_or_add(")).toBe(true);
    expect(rasterSource.includes("pub struct DynamicPalette")).toBe(false);
    expect(rasterSource.includes("fn color_hash(")).toBe(false);
    expect(rasterSource.includes("fn DynamicPalette::get_or_add(")).toBe(false);
  });

  it("splits raster clip helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_clip.mbt"), "utf8");

    expect(source.includes("pub(all) struct ClipRect")).toBe(true);
    expect(source.includes("fn clip_intersect(")).toBe(true);
    expect(source.includes("fn pixel_in_clip(")).toBe(true);
    expect(rasterSource.includes("pub(all) struct ClipRect")).toBe(false);
    expect(rasterSource.includes("fn clip_intersect(")).toBe(false);
    expect(rasterSource.includes("fn pixel_in_clip(")).toBe(false);
  });

  it("splits raster blending helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_blend.mbt"), "utf8");

    expect(source.includes("fn blend_types_color_over_pixel(")).toBe(true);
    expect(source.includes("fn blend_raster_color_over_pixel(")).toBe(true);
    expect(source.includes("fn blend_span_with_raster_color(")).toBe(true);
    expect(source.includes("fn fill_rect_with_types_color(")).toBe(true);
    expect(rasterSource.includes("fn blend_types_color_over_pixel(")).toBe(false);
    expect(rasterSource.includes("fn blend_raster_color_over_pixel(")).toBe(false);
    expect(rasterSource.includes("fn blend_span_with_raster_color(")).toBe(false);
    expect(rasterSource.includes("fn fill_rect_with_types_color(")).toBe(false);
  });

  it("splits raster clipped fill helper out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_fill.mbt"), "utf8");

    expect(source.includes("fn fill_rect_clipped(")).toBe(true);
    expect(rasterSource.includes("fn fill_rect_clipped(")).toBe(false);
  });

  it("splits raster shadow helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_shadow.mbt"), "utf8");

    expect(source.includes("fn fill_box_shadow_clipped(")).toBe(true);
    expect(source.includes("fn blurred_shadow_layer_count(")).toBe(true);
    expect(source.includes("fn fill_blurred_box_shadow_clipped(")).toBe(true);
    expect(rasterSource.includes("fn fill_box_shadow_clipped(")).toBe(false);
    expect(rasterSource.includes("fn fill_blurred_box_shadow_clipped(")).toBe(false);
  });

  it("splits rounded raster fill helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_rounded_rect.mbt"), "utf8");

    expect(source.includes("fn rounded_corner_coverage(")).toBe(true);
    expect(source.includes("fn fill_rounded_corner_pixels_fast(")).toBe(true);
    expect(source.includes("fn fill_rounded_rect_fast(")).toBe(true);
    expect(source.includes("fn fill_rounded_rect_clipped(")).toBe(true);
    expect(rasterSource.includes("fn rounded_corner_coverage(")).toBe(false);
    expect(rasterSource.includes("fn fill_rounded_rect_clipped(")).toBe(false);
  });

  it("splits raster gradient helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_gradient.mbt"), "utf8");

    expect(source.includes("fn lerp_color(")).toBe(true);
    expect(source.includes("fn sample_gradient(")).toBe(true);
    expect(source.includes("fn fill_linear_gradient_clipped(")).toBe(true);
    expect(rasterSource.includes("fn lerp_color(")).toBe(false);
    expect(rasterSource.includes("fn sample_gradient(")).toBe(false);
    expect(rasterSource.includes("fn fill_linear_gradient_clipped(")).toBe(false);
  });

  it("splits raster border helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_border.mbt"), "utf8");

    expect(source.includes("fn resolve_radius(")).toBe(true);
    expect(source.includes("fn same_types_color(")).toBe(true);
    expect(source.includes("fn can_draw_uniform_rounded_border_ring(")).toBe(true);
    expect(source.includes("fn draw_uniform_rounded_border_ring_clipped(")).toBe(true);
    expect(rasterSource.includes("fn resolve_radius(")).toBe(false);
    expect(rasterSource.includes("fn draw_uniform_rounded_border_ring_clipped(")).toBe(false);
  });

  it("splits raster group opacity helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_group.mbt"), "utf8");

    expect(source.includes("fn make_transparent_framebuffer(")).toBe(true);
    expect(source.includes("fn blend_group_framebuffer_over(")).toBe(true);
    expect(source.includes("fn render_group_opacity_clipped(")).toBe(true);
    expect(rasterSource.includes("fn make_transparent_framebuffer(")).toBe(false);
    expect(rasterSource.includes("fn render_group_opacity_clipped(")).toBe(false);
  });
});
