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

describe("MoonBit painter module boundaries", () => {
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
