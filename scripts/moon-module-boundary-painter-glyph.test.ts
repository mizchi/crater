import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit painter glyph boundaries", () => {
  it("splits glyph rasterization helpers out of glyph_render", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_render.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/glyph/rasterizer.mbt"), "utf8");

    expect(source.includes("pub(all) struct GlyphBitmap")).toBe(true);
    expect(source.includes("fn insert_sorted_double(")).toBe(true);
    expect(source.includes("fn scanline_intersections_even_odd(")).toBe(true);
    expect(source.includes("fn rasterize_compound_path_even_odd_to_pixels(")).toBe(true);
    expect(source.includes("fn rasterize_glyph_to_bitmap(")).toBe(true);
    expect(renderSource.includes("priv struct GlyphBitmap")).toBe(false);
    expect(renderSource.includes("fn insert_sorted_double(")).toBe(false);
    expect(renderSource.includes("fn scanline_intersections_even_odd(")).toBe(false);
    expect(renderSource.includes("fn rasterize_compound_path_even_odd_to_pixels(")).toBe(false);
    expect(renderSource.includes("fn rasterize_glyph_to_bitmap(")).toBe(false);
  });

  it("splits glyph bitmap cache helpers out of glyph_render", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_render.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/glyph/cache.mbt"), "utf8");

    expect(source.includes("let glyph_bitmap_cache")).toBe(true);
    expect(source.includes("let glyph_cache")).toBe(true);
    expect(source.includes("fn glyph_cache_key(")).toBe(true);
    expect(source.includes("pub fn clear_glyph_caches(")).toBe(true);
    expect(source.includes("pub fn cached_glyph_bitmap(")).toBe(true);
    expect(source.includes("pub fn pre_rasterize_glyphs(")).toBe(true);
    expect(renderSource.includes("let glyph_bitmap_cache")).toBe(false);
    expect(renderSource.includes("let glyph_cache")).toBe(false);
    expect(renderSource.includes("fn glyph_cache_key(")).toBe(false);
    expect(renderSource.includes("pub fn pre_rasterize_glyphs(")).toBe(false);
  });

  it("splits glyph text layout helpers out of glyph_render", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_render.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/glyph/layout.mbt"), "utf8");

    expect(source.includes("let text_wrap_tolerance")).toBe(true);
    expect(source.includes("pub fn resolve_text_wrap_tolerance(")).toBe(true);
    expect(source.includes("pub fn measure_word_width(")).toBe(true);
    expect(source.includes("pub fn collapsed_space_advance(")).toBe(true);
    expect(source.includes("pub fn split_text_into_words(")).toBe(true);
    expect(renderSource.includes("let text_wrap_tolerance")).toBe(false);
    expect(renderSource.includes("fn resolve_text_wrap_tolerance(")).toBe(false);
    expect(renderSource.includes("fn measure_word_width(")).toBe(false);
    expect(renderSource.includes("fn collapsed_space_advance(")).toBe(false);
    expect(renderSource.includes("fn split_text_into_words(")).toBe(false);
  });

  it("splits glyph provider adapter helpers out of glyph_render", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_render.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/glyph/provider.mbt"), "utf8");

    expect(source.includes("pub(all) struct GlyphProvider")).toBe(true);
    expect(source.includes("let glyph_provider_override")).toBe(true);
    expect(source.includes("pub fn get_glyph_provider(")).toBe(true);
    expect(source.includes("pub fn glyph_provider_from_delegate(")).toBe(true);
    expect(source.includes("pub fn glyph_provider_from_font(")).toBe(true);
    expect(source.includes("pub fn resolve_effective_font_weight(")).toBe(true);
    expect(source.includes("fn glyph_from_provider(")).toBe(true);
    expect(source.includes("pub fn kern_from_provider(")).toBe(true);
    expect(source.includes("fn get_advance(")).toBe(true);
    expect(renderSource.includes("pub(all) struct GlyphProvider")).toBe(false);
    expect(renderSource.includes("pub fn glyph_provider_from_delegate(")).toBe(false);
    expect(renderSource.includes("fn glyph_from_provider(")).toBe(false);
    expect(renderSource.includes("fn kern_from_provider(")).toBe(false);
  });

  it("splits glyph path translation helpers out of glyph_render", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_render.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/glyph/path.mbt"), "utf8");

    expect(source.includes("fn translate_path_commands(")).toBe(true);
    expect(source.includes("@svg.PathCommand::MoveTo")).toBe(true);
    expect(renderSource.includes("fn translate_path_commands(")).toBe(false);
  });

  it("keeps glyph provider implementation behind the glyph package", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/glyph/moon.pkg"))).toBe(true);
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_provider.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_cache.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_layout.mbt"))).toBe(false);
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_rasterizer.mbt"))).toBe(false);

    const compatSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_compat.mbt"), "utf8");
    expect(compatSource.includes("pub using @glyph {type GlyphProvider}")).toBe(true);
    expect(compatSource.includes("@glyph.set_glyph_provider(provider)")).toBe(true);
    expect(compatSource.includes("@glyph.pre_rasterize_glyphs(")).toBe(true);
  });

  it("splits glyph bitmap blitting helpers out of glyph_render", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_render.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/paint/raster/glyph_blit.mbt"), "utf8");

    expect(source.includes("fn clamp_opacity(")).toBe(true);
    expect(source.includes("fn blend_color_over_pixel_alpha(")).toBe(true);
    expect(source.includes("fn blit_glyph_bitmap(")).toBe(true);
    expect(source.includes("bitmap.coverage")).toBe(true);
    expect(renderSource.includes("fn clamp_opacity(")).toBe(false);
    expect(renderSource.includes("fn blend_color_over_pixel_alpha(")).toBe(false);
    expect(renderSource.includes("bitmap.coverage")).toBe(false);
  });
});
