import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit painter raster asset boundaries", () => {
  it("splits raster SVG data URI helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_svg_data_uri.mbt"), "utf8");

    expect(source.includes("fn decode_svg_data_uri(")).toBe(true);
    expect(source.includes("fn url_decode_simple(")).toBe(true);
    expect(source.includes("fn hex_digit(")).toBe(true);
    expect(rasterSource.includes("fn decode_svg_data_uri(")).toBe(false);
    expect(rasterSource.includes("fn url_decode_simple(")).toBe(false);
    expect(rasterSource.includes("fn hex_digit(")).toBe(false);
  });

  it("splits raster SVG region rendering out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_svg_render.mbt"), "utf8");

    expect(source.includes("fn render_svg_into_region(")).toBe(true);
    expect(source.includes("@svg.parse_svg(svg_text)")).toBe(true);
    expect(source.includes("render_svg_scene_with_camera(")).toBe(true);
    expect(rasterSource.includes("fn render_svg_into_region(")).toBe(false);
  });

  it("splits raster image source rendering out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_image_render.mbt"), "utf8");

    expect(source.includes("fn resolve_image_src(")).toBe(true);
    expect(source.includes("fn render_image_src_into_region(")).toBe(true);
    expect(source.includes("fn render_raster_image_into_region(")).toBe(true);
    expect(source.includes("image_provider_override.val")).toBe(true);
    expect(rasterSource.includes("fn resolve_image_src(")).toBe(false);
    expect(rasterSource.includes("fn render_image_src_into_region(")).toBe(false);
    expect(rasterSource.includes("fn render_raster_image_into_region(")).toBe(false);
  });

  it("splits raster canvas background helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_canvas_background.mbt"), "utf8");

    expect(source.includes("fn resolve_canvas_background_color(")).toBe(true);
    expect(source.includes("fn fill_canvas_background(")).toBe(true);
    expect(source.includes('child.tag == "body"')).toBe(true);
    expect(rasterSource.includes("let mut canvas_bg")).toBe(false);
    expect(rasterSource.includes('child.tag == "body"')).toBe(false);
  });
});
