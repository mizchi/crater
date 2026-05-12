import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit painter raster core boundaries", () => {
  it("splits image raster color helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_color.mbt"), "utf8");

    expect(source.includes("pub(all) struct Color")).toBe(true);
    expect(source.includes("pub fn Color::white(")).toBe(true);
    expect(source.includes("pub fn Color::blend(")).toBe(true);
    expect(source.includes("pub fn get_depth_color(")).toBe(true);
    expect(rasterSource.includes("pub(all) struct Color")).toBe(false);
    expect(rasterSource.includes("pub fn Color::blend(")).toBe(false);
    expect(rasterSource.includes("pub fn get_depth_color(")).toBe(false);
  });

  it("splits image provider model out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/image_provider.mbt"), "utf8");

    expect(source.includes("pub(all) struct RasterImage")).toBe(true);
    expect(source.includes("pub(all) enum ResolvedImage")).toBe(true);
    expect(source.includes("pub(all) struct ImageProvider")).toBe(true);
    expect(source.includes("let image_provider_override")).toBe(true);
    expect(source.includes("pub fn set_image_provider(")).toBe(true);
    expect(source.includes("pub fn clear_image_provider(")).toBe(true);
    expect(rasterSource.includes("pub(all) struct RasterImage")).toBe(false);
    expect(rasterSource.includes("pub(all) enum ResolvedImage")).toBe(false);
    expect(rasterSource.includes("pub(all) struct ImageProvider")).toBe(false);
  });

  it("splits image raster base64 fallback out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_base64.mbt"), "utf8");

    expect(source.includes("let base64_chars")).toBe(true);
    expect(source.includes("fn write_base64_quad(")).toBe(true);
    expect(source.includes("fn encode_bytes_base64(")).toBe(true);
    expect(rasterSource.includes("let base64_chars")).toBe(false);
    expect(rasterSource.includes("fn write_base64_quad(")).toBe(false);
    expect(rasterSource.includes("fn encode_bytes_base64(")).toBe(false);
  });

  it("splits framebuffer primitives out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/framebuffer.mbt"), "utf8");

    expect(source.includes("pub struct Framebuffer")).toBe(true);
    expect(source.includes("pub fn Framebuffer::new(")).toBe(true);
    expect(source.includes("fn Framebuffer::set_pixel(")).toBe(true);
    expect(source.includes("fn Framebuffer::fill_span(")).toBe(true);
    expect(source.includes("pub fn Framebuffer::fill_rect(")).toBe(true);
    expect(source.includes("pub fn Framebuffer::stroke_rect(")).toBe(true);
    expect(source.includes("pub fn Framebuffer::fill_rect_hatched(")).toBe(true);
    expect(rasterSource.includes("pub struct Framebuffer")).toBe(false);
    expect(rasterSource.includes("pub fn Framebuffer::fill_rect(")).toBe(false);
    expect(rasterSource.includes("pub fn Framebuffer::fill_rect_hatched(")).toBe(false);
  });

  it("splits framebuffer encoding out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/framebuffer_encode.mbt"), "utf8");

    expect(source.includes("extern \"js\" fn framebuffer_to_rgba_base64_js(")).toBe(true);
    expect(source.includes("fn framebuffer_to_rgba_base64_js(")).toBe(true);
    expect(source.includes("pub fn framebuffer_to_rgba_base64(")).toBe(true);
    expect(rasterSource.includes("framebuffer_to_rgba_base64_js")).toBe(false);
    expect(rasterSource.includes("pub fn framebuffer_to_rgba_base64(")).toBe(false);
  });

  it("splits bitmap text fallback out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/bitmap_text.mbt"), "utf8");

    expect(source.includes("fn is_wide_char(")).toBe(true);
    expect(source.includes("pub fn Framebuffer::draw_char(")).toBe(true);
    expect(source.includes("pub fn Framebuffer::draw_text(")).toBe(true);
    expect(source.includes("fn draw_text_clipped(")).toBe(true);
    expect(source.includes("get_char_bitmap(c)")).toBe(true);
    expect(rasterSource.includes("pub fn Framebuffer::draw_char(")).toBe(false);
    expect(rasterSource.includes("pub fn Framebuffer::draw_text(")).toBe(false);
    expect(rasterSource.includes("fn draw_text_clipped(")).toBe(false);
  });

  it("splits bitmap font data and metrics out of the font facade", () => {
    const fontSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/font.mbt"), "utf8");
    const dataSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/bitmap_font_data.mbt"), "utf8");
    const metricsSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/bitmap_font_metrics.mbt"), "utf8");

    expect(fontSource.includes("pub fn get_char_bitmap(")).toBe(true);
    expect(fontSource.includes("pub fn is_font_supported(")).toBe(true);
    expect(fontSource.includes("let bitmap_font_data")).toBe(false);
    expect(fontSource.includes("0xFE")).toBe(false);
    expect(dataSource.includes("let bitmap_font_data")).toBe(true);
    expect(dataSource.includes("// 65: A")).toBe(true);
    expect(metricsSource.includes("pub let font_width")).toBe(true);
    expect(metricsSource.includes("pub let font_height")).toBe(true);
    expect(metricsSource.includes("fn bitmap_font_index(")).toBe(true);
  });

  it("splits raster text layout helpers out of paint_raster", () => {
    const rasterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/paint_raster.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/raster_text.mbt"), "utf8");

    expect(source.includes("fn draw_text_decoration_line(")).toBe(true);
    expect(source.includes("fn resolve_text_render_box(")).toBe(true);
    expect(source.includes("fn resolve_glyph_text_wrap_width(")).toBe(true);
    expect(rasterSource.includes("fn draw_text_decoration_line(")).toBe(false);
    expect(rasterSource.includes("fn resolve_text_render_box(")).toBe(false);
    expect(rasterSource.includes("fn resolve_glyph_text_wrap_width(")).toBe(false);
  });
});
