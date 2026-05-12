import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const SKIP_DIRS = new Set([
  ".git",
  ".moon",
  ".mooncakes",
  "_build",
  "dist",
  "node_modules",
  "output",
  "target",
  "test-results",
]);

const DIRECT_TUI_TERMINAL_PROTOCOL_FILES = new Set([
  "terminal_protocol/moon.mod.json",
  "terminal_protocol/ansi/moon.pkg",
  "terminal_protocol/kitty/moon.pkg",
  "terminal_protocol/sixel/moon.pkg",
]);

const BROWSER_TERMINAL_PROTOCOL_ANSI_FILES = new Set([
  "browser/moon.mod.json",
  "browser/tui/primitives/moon.pkg",
]);

function collectMoonPackageFiles(dir: string, out: string[] = []): string[] {
  for (const dirent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (dirent.isDirectory()) {
      if (!SKIP_DIRS.has(dirent.name)) {
        collectMoonPackageFiles(path.join(dir, dirent.name), out);
      }
      continue;
    }
    if (dirent.name === "moon.pkg" || dirent.name === "moon.mod.json") {
      out.push(path.join(dir, dirent.name));
    }
  }
  return out;
}

function collectMoonBitFiles(dir: string, out: string[] = []): string[] {
  for (const dirent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (dirent.isDirectory()) {
      if (!SKIP_DIRS.has(dirent.name)) {
        collectMoonBitFiles(path.join(dir, dirent.name), out);
      }
      continue;
    }
    if (dirent.name.endsWith(".mbt")) {
      out.push(path.join(dir, dirent.name));
    }
  }
  return out;
}

function countLines(relativePath: string): number {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8").split(/\r?\n/).length;
}

describe("MoonBit module boundaries", () => {
  it("keeps tui terminal protocol behind crater-terminal-protocol", () => {
    const offenders = collectMoonPackageFiles(REPO_ROOT)
      .filter((file) => fs.readFileSync(file, "utf8").includes("mizchi/tui-terminal-protocol"))
      .map((file) => path.relative(REPO_ROOT, file))
      .filter((file) => !DIRECT_TUI_TERMINAL_PROTOCOL_FILES.has(file));

    expect(offenders).toEqual([]);
  });

  it("keeps browser shell behind painter-terminal facade for kitty output", () => {
    const offenders = collectMoonPackageFiles(path.join(REPO_ROOT, "browser"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        const relativeFile = path.relative(REPO_ROOT, file);
        const allowedAnsiFacade = BROWSER_TERMINAL_PROTOCOL_ANSI_FILES.has(relativeFile) &&
          (source.includes("mizchi/crater-terminal-protocol/ansi") ||
            source.includes('"mizchi/crater-terminal-protocol"')) &&
          !source.includes("mizchi/crater-terminal-protocol/kitty") &&
          !source.includes("mizchi/crater-terminal-protocol/sixel");
        return (source.includes("mizchi/crater-terminal-protocol") && !allowedAnsiFacade) ||
          source.includes("mizchi/crater-painter/x/kitty") ||
          source.includes("mizchi/crater-painter-terminal/kitty");
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps terminal protocol implementation out of crater-painter", () => {
    const offenders = collectMoonPackageFiles(path.join(REPO_ROOT, "painter"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return source.includes("mizchi/crater-terminal-protocol") ||
          source.includes("mizchi/crater-painter/x/kitty");
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps framebuffer raster implementation names protocol-neutral", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/paint/raster/sixel.mbt"))).toBe(false);
  });

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

  it("keeps painter-terminal root facade behind terminal-specific packages", () => {
    const rootPackage = path.join(REPO_ROOT, "painter_terminal/moon.pkg");
    const source = fs.readFileSync(rootPackage, "utf8");

    expect(source).not.toContain("mizchi/crater-terminal-protocol");
  });

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

  it("delegates reusable browser tui buffer algorithms to tui terminal buffer", () => {
    const pkg = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/moon.pkg"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer_text.mbt"), "utf8");

    expect(pkg).toContain('"mizchi/tui-terminal-buffer/buffer" @tui_buffer');
    expect(source).toContain("@tui_buffer.clip_rect(self.width, self.height, x, y, w, h)");
    expect(textSource).toContain("@tui_buffer.char_display_width(c)");
    expect(textSource).toContain("@tui_buffer.plan_write_text(x, y, text, max_width)");
    expect(textSource).toContain("@tui_buffer.plan_write_text_pre(x, y, text, max_width, max_height)");
    expect(textSource).toContain("@tui_buffer.plan_write_text_wrapped(");
    expect(textSource).toContain("x, y, text, max_width, max_height,");
    expect(source).not.toContain("fn is_wide_char(");
    expect(source).not.toContain("fn CharBuffer::write_styled_char(");
  });

  it("splits browser tui buffer cell types out of buffer storage", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer.mbt"), "utf8");
    const cellSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer_cell.mbt"), "utf8");

    expect(cellSource).toContain("pub(all) struct CharCell");
    expect(cellSource).toContain("pub fn CharCell::default(");
    expect(cellSource).toContain("pub(all) struct TextStyle");
    expect(cellSource).toContain("pub fn TextStyle::default(");
    expect(source).not.toContain("pub(all) struct CharCell");
    expect(source).not.toContain("pub(all) struct TextStyle");
  });

  it("splits browser tui buffer text writing out of buffer storage", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/buffer_text.mbt"), "utf8");

    expect(textSource).toContain("pub fn char_display_width(");
    expect(textSource).toContain("fn CharBuffer::apply_text_write_plan(");
    expect(textSource).toContain("pub fn CharBuffer::write_text(");
    expect(textSource).toContain("pub fn CharBuffer::write_text_pre(");
    expect(textSource).toContain("pub fn CharBuffer::write_text_wrapped(");
    expect(source).not.toContain("pub fn char_display_width(");
    expect(source).not.toContain("fn CharBuffer::apply_text_write_plan(");
    expect(source).not.toContain("pub fn CharBuffer::write_text(");
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

  it("delegates reusable browser tui widget plans to tui terminal buffer", () => {
    const pkg = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/moon.pkg"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/widget.mbt"), "utf8");
    const scrollbarSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/primitives/scrollbar_widget.mbt"), "utf8");

    expect(pkg).toContain('"mizchi/tui-terminal-buffer/buffer" @tui_buffer');
    expect(source).toContain("@tui_buffer.BoxChars::single()");
    expect(source).toContain("@tui_buffer.plan_box(x, y, w, h, box_chars(style))");
    expect(source).toContain("@tui_buffer.plan_hline(x, y, w, chars.horizontal)");
    expect(source).toContain("@tui_buffer.plan_vline(x, y, h, chars.vertical)");
    expect(scrollbarSource).toContain("@tui_buffer.plan_scrollbar(");
    expect(source).not.toContain("for col = x + 1; col < x + w - 1");
    expect(source).not.toContain("let thumb_height =");
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

  it("splits browser tui hit regions out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const hitSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_region.mbt"), "utf8");

    expect(hitSource).toContain("pub(all) struct HitRegion");
    expect(hitSource).toContain("pub(all) enum HitClipShape");
    expect(hitSource).toContain("pub fn find_hit_region_at(");
    expect(hitSource).toContain("fn collect_hit_region(");
    expect(hitSource).toContain("ctx.hit_regions.push(");
    expect(hitSource).not.toContain("pub(all) struct LinkRegion");
    expect(hitSource).not.toContain("fn point_in_polygon(");
    expect(renderSource).not.toContain("pub(all) struct LinkRegion");
    expect(renderSource).not.toContain("pub(all) struct HitRegion");
    expect(renderSource).not.toContain("pub(all) enum HitClipShape");
    expect(renderSource).not.toContain("fn point_in_polygon(");
    expect(renderSource).not.toContain("ctx.hit_regions.push(");
  });

  it("splits browser tui link regions out of hit regions", () => {
    const hitSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_region.mbt"), "utf8");
    const linkSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_link_region.mbt"), "utf8");

    expect(linkSource).toContain("pub(all) struct LinkRegion");
    expect(linkSource).toContain("pub fn find_link_at(");
    expect(linkSource).toContain("pub fn find_link_region_at(");
    expect(hitSource).not.toContain("pub(all) struct LinkRegion");
    expect(hitSource).not.toContain("pub fn find_link_at(");
  });

  it("splits browser tui hit shape predicates out of hit region collection", () => {
    const hitSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_region.mbt"), "utf8");
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_shape.mbt"), "utf8");
    const containsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_contains.mbt"), "utf8");

    expect(shapeSource).toContain("fn resolve_hit_radius(");
    expect(shapeSource).toContain("fn resolve_hit_clip_shape(");
    expect(containsSource).toContain("pub fn HitRegion::contains(");
    expect(hitSource).not.toContain("fn point_in_rounded_rect(");
    expect(hitSource).not.toContain("fn point_in_hit_clip_shape(");
  });

  it("splits browser tui hit containment sampling out of shape resolution", () => {
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_shape.mbt"), "utf8");
    const containsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_contains.mbt"), "utf8");

    expect(containsSource).toContain("fn HitRegion::contains_pixel(");
    expect(containsSource).toContain("fn HitRegion::has_cell_coverage(");
    expect(containsSource).toContain("fn HitRegion::allows_cell_coverage_sampling(");
    expect(containsSource).toContain("pub fn HitRegion::contains(");
    expect(shapeSource).not.toContain("fn HitRegion::contains_pixel(");
    expect(shapeSource).not.toContain("pub fn HitRegion::contains(");
  });

  it("splits browser tui hit point predicates out of hit shape resolution", () => {
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_shape.mbt"), "utf8");
    const predicateSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_hit_predicate.mbt"), "utf8");

    expect(predicateSource).toContain("fn point_in_rounded_corner(");
    expect(predicateSource).toContain("fn point_in_rounded_rect(");
    expect(predicateSource).toContain("fn point_in_hit_clip_shape(");
    expect(predicateSource).toContain("fn point_in_polygon(");
    expect(shapeSource).not.toContain("fn point_in_rounded_corner(");
    expect(shapeSource).not.toContain("fn point_in_rounded_rect(");
    expect(shapeSource).not.toContain("fn point_in_hit_clip_shape(");
    expect(shapeSource).not.toContain("fn point_in_polygon(");
  });

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

  it("splits browser tui image rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const imageSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_image.mbt"), "utf8");

    expect(imageSource).toContain("fn render_image_node(");
    expect(imageSource).toContain("fn draw_image_placeholder(");
    expect(imageSource).toContain("ctx.image_regions.push(");
    expect(renderSource).not.toContain("ctx.image_regions.push(");
    expect(renderSource).not.toContain("let img_bg =");
    expect(renderSource).not.toContain("Draw alt text");
  });

  it("splits browser tui text rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const textSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_text.mbt"), "utf8");

    expect(textSource).toContain("fn render_text_node(");
    expect(textSource).toContain("fn resolve_text_style(");
    expect(textSource).toContain("ctx.link_regions.push(");
    expect(renderSource).not.toContain("ctx.link_regions.push(");
    expect(renderSource).not.toContain("write_text_wrapped(");
    expect(renderSource).not.toContain("let text_display_width =");
  });

  it("splits browser tui element scrollbar rendering out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const scrollbarSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_scrollbar.mbt"), "utf8");

    expect(scrollbarSource).toContain("fn render_element_scrollbar(");
    expect(scrollbarSource).toContain("ctx.element_scroll_positions.get(");
    expect(scrollbarSource).toContain("draw_scrollbar(");
    expect(renderSource).not.toContain("ctx.element_scroll_positions.get(");
    expect(renderSource).not.toContain("node.is_scrollable()");
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

  it("splits browser tui child traversal out of the main renderer", () => {
    const renderSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render.mbt"), "utf8");
    const traversalSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/render_traversal.mbt"), "utf8");

    expect(traversalSource).toContain("fn render_child_nodes(");
    expect(traversalSource).toContain("for child in node.children");
    expect(traversalSource).toContain("render_paint_node(");
    expect(renderSource).not.toContain("for child in node.children");
  });

  it("splits browser tui native UTF-8 codec out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const codecSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_utf8.mbt"), "utf8");

    expect(codecSource).toContain("fn bytes_to_string(");
    expect(codecSource).toContain("fn encode_utf8(");
    expect(nativeSource).not.toContain("fn bytes_to_string(");
    expect(nativeSource).not.toContain("fn encode_utf8(");
  });

  it("splits browser tui native input parsing out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const inputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_input.mbt"), "utf8");

    expect(inputSource).toContain("fn read_raw_key_from_prefix(");
    expect(inputSource).toContain("fn parse_mouse_event(");
    expect(inputSource).toContain("fn normalize_native_key(");
    expect(nativeSource).not.toContain("fn read_raw_key_from_prefix(");
    expect(nativeSource).not.toContain("fn parse_mouse_event(");
    expect(nativeSource).not.toContain("fn normalize_native_key(");
  });

  it("splits browser tui native FFI bindings out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const ffiSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_ffi.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(ffiSource).toContain('extern "C" fn tui_enable_raw_mode()');
    expect(ffiSource).toContain('extern "C" fn tui_read_byte()');
    expect(ffiSource).toContain('extern "C" fn tui_write_bytes_ffi(');
    expect(pkgSource).toContain('"tui_native_ffi.mbt": [ "native" ]');
    expect(nativeSource).not.toContain('extern "C" fn');
    expect(nativeSource).not.toContain("tui_write_bytes_ffi");
  });

  it("splits browser tui native terminal operations out of the native adapter", () => {
    const nativeSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native.mbt"), "utf8");
    const terminalSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_terminal.mbt"), "utf8");
    const inputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_native_input.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(terminalSource).toContain("pub fn print_raw(");
    expect(terminalSource).toContain("pub fn cleanup_stdin(");
    expect(terminalSource).toContain("pub fn get_terminal_size(");
    expect(terminalSource).toContain("pub fn enable_raw_mode(");
    expect(inputSource).toContain("pub fn read_key_with_timeout(");
    expect(inputSource).toContain("pub async fn read_line(");
    expect(pkgSource).toContain('"tui_native_terminal.mbt": [ "native" ]');
    expect(nativeSource).not.toContain("pub fn print_raw(");
    expect(nativeSource).not.toContain("pub fn read_key_with_timeout(");
    expect(nativeSource).not.toContain("pub async fn read_line(");
  });

  it("splits browser tui js input out of the js adapter", () => {
    const jsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js.mbt"), "utf8");
    const inputSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js_input.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(inputSource).toContain('extern "js" fn js_read_key_with_timeout(');
    expect(inputSource).toContain('extern "js" fn js_read_line(');
    expect(inputSource).toContain("pub async fn read_key(");
    expect(inputSource).toContain("pub async fn wait_for_enter(");
    expect(pkgSource).toContain('"tui_js_input.mbt": [ "js" ]');
    expect(jsSource).not.toContain("js_read_key_with_timeout");
    expect(jsSource).not.toContain("pub async fn read_key(");
    expect(jsSource).not.toContain("pub async fn wait_for_enter(");
  });

  it("splits browser tui js terminal io out of the js adapter", () => {
    const jsSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js.mbt"), "utf8");
    const terminalSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_js_terminal.mbt"), "utf8");
    const pkgSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/moon.pkg"), "utf8");

    expect(terminalSource).toContain('extern "js" fn js_print(');
    expect(terminalSource).toContain('extern "js" fn js_get_terminal_columns(');
    expect(terminalSource).toContain("pub fn print_raw(");
    expect(terminalSource).toContain("pub fn get_terminal_size(");
    expect(pkgSource).toContain('"tui_js_terminal.mbt": [ "js" ]');
    expect(jsSource).not.toContain("js_print");
    expect(jsSource).not.toContain("js_get_terminal_columns");
    expect(jsSource).not.toContain("pub fn print_raw(");
    expect(jsSource).not.toContain("pub fn get_terminal_size(");
  });

  it("splits browser tui mouse action parsing out of key mapping", () => {
    const tuiSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui.mbt"), "utf8");
    const mouseSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_mouse_action.mbt"), "utf8");

    expect(mouseSource).toContain("fn parse_mouse_action(");
    expect(mouseSource).toContain("enum MouseActionKind");
    expect(mouseSource).toContain("MouseScrollDownKind");
    expect(tuiSource).toContain("pub fn key_to_action(");
    expect(tuiSource).not.toContain("fn parse_mouse_action(");
    expect(tuiSource).not.toContain("enum MouseActionKind");
  });

  it("splits browser tui terminal control sequences out of action mapping", () => {
    const tuiSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui.mbt"), "utf8");
    const controlSource = fs.readFileSync(path.join(REPO_ROOT, "browser/tui/tui_terminal_control.mbt"), "utf8");

    expect(controlSource).toContain("pub fn clear_screen(");
    expect(controlSource).toContain("pub fn enter_alt_screen(");
    expect(controlSource).toContain("pub fn format_status_bar(");
    expect(tuiSource).not.toContain("pub fn clear_screen(");
    expect(tuiSource).not.toContain("pub fn format_status_bar(");
  });

  it("keeps browser shell terminal image implementation in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/terminal_image.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn stable_kitty_id",
      "fn current_kitty_placement",
      "fn Browser::build_kitty_image_overlay",
      "fn Browser::prefetch_images",
      "fn Browser::install_sixel_image_provider",
      "fn render_cached_kitty_image_with_placement",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell drag and drop helpers in their own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/drag_drop.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::is_draggable_source_id",
      "fn Browser::dispatch_drag_event_status_to_source_id",
      "fn Browser::dispatch_drag_event_to_source_id",
      "fn Browser::is_current_drop_allowed",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell form submit bridge in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/form_bridge.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn parse_navigation_request",
      "fn Browser::drain_pending_form_submission_navigation",
      "fn browser_form_submit_bridge_source",
      "fn browser_pending_form_submission_source",
      "fn browser_peek_pending_form_submission_source",
      "fn Browser::peek_pending_form_submission_navigation",
      "fn Browser::shift_pending_form_submission_navigation",
      "fn Browser::dispatch_submit_to_source_id",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell input bridge in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/input_bridge.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::dispatch_focused_key_to_source_id",
      "fn Browser::set_text_control_selection_from_cells",
      "fn Browser::set_text_control_caret_from_cell",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell DOM event bridge in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/dom_event_bridge.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::dispatch_focus_transition",
      "fn Browser::dispatch_activation_default_to_source_id",
      "fn Browser::dispatch_click_to_source_id",
      "fn Browser::dispatch_pointer_mouse_event_to_source_id",
      "fn Browser::dispatch_click_only_to_source_id",
      "fn Browser::dispatch_hover_transition",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell navigation implementation in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn resolve_url",
      "fn decode_sync_navigable_html_url",
      "fn Browser::load_sync_navigable_html_request",
      "fn Browser::navigate_sync_if_supported",
      "fn fetch_external_css",
      "fn Browser::load_url_request",
      "fn Browser::load_url_lightweight",
      "fn Browser::go_back",
      "fn Browser::go_forward",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell navigation URL helpers in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/navigation_url.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "fn resolve_url",
      "fn make_substr",
      "fn hex_digit_to_int",
      "fn percent_decode_data_url_payload",
      "fn decode_sync_navigable_html_url",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell external CSS fetch in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/external_css_fetch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "fn http_fetch_adapter",
      "fn fetch_external_css",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell rendering implementation in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::set_external_css",
      "fn Browser::clear_render_cache",
      "fn Browser::prepare_render_document_for_context",
      "fn Browser::render_graphics_node_and_layout",
      "fn Browser::render_output",
      "fn Browser::render_kitty",
      "fn Browser::render_text",
      "fn Browser::render_text_full_page",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell render cache in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/render_cache.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::set_external_css",
      "fn Browser::external_css_handle",
      "fn Browser::clear_render_cache",
      "fn Browser::prepare_render_document_for_context",
      "fn Browser::render_node_from_document",
      "fn Browser::render_node_and_layout_from_document",
      "fn Browser::render_graphics_node_and_layout",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell render dispatch in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/render_dispatch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::render_output",
      "fn Browser::write_output",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell graphics renderer in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/graphics_renderer.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::render(self : Browser)",
      "fn Browser::render_kitty",
      "fn Browser::write_kitty_output",
      "fn Browser::collect_graphics_image_regions_from_node_layout",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell text renderer in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/text_renderer.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::render_text",
      "fn Browser::build_plain_links",
      "fn Browser::render_text_full_page",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell JavaScript execution in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::set_js_runtime",
      "fn decode_js_string_result",
      "fn Browser::flush_js_logs",
      "fn escape_js_string",
      "fn Browser::execute_inline_js",
      "fn Browser::process_pending_script_tasks",
      "priv struct ScriptInfo",
      "fn extract_scripts",
      "fn Browser::init_js_execution",
      "fn Browser::execute_scripts",
      "fn Browser::execute_scripts_async",
      "fn Browser::sync_render_state_from_dom_tree",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell script extraction in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/script_extraction.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"), "utf8");
    const implementationMarkers = [
      "priv struct ScriptInfo",
      "fn is_executable_script_type",
      "fn extract_scripts",
      "char_at(html",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell external script fetching in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/script_fetch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"), "utf8");
    const implementationMarkers = [
      "@http.cached_fetch_async",
      "@http.FetchOptions::default()",
      "@http.RequestMode::NoCors",
      "http_fetch_adapter",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell script DOM runtime in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/script_dom_runtime.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/js_execution.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::init_js_execution",
      "fn Browser::sync_render_state_from_dom_tree",
      "html_source_requires_runtime_rebuild",
      "build_dom_tree_from_source_html",
      "@js.serialize_dom_to_html",
      "@renderer.get_content_height_with_document",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell source DOM reconstruction in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/source_dom.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn build_dom_tree_from_document",
      "fn html_source_has_declarative_shadow_dom",
      "priv struct SourceHtmlFragment",
      "priv struct NormalizedShadowSourceHtml",
      "fn parse_html_attributes",
      "fn extract_source_html_fragment",
      "fn write_set_attributes_js",
      "fn create_empty_html_dom_tree",
      "fn normalize_declarative_shadow_source_html_with_hint",
      "fn build_dom_tree_from_source_html",
      "fn build_dom_children",
      "fn build_dom_element",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell focus and hit testing in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::is_bounds_visible",
      "fn Browser::next_link",
      "fn Browser::prev_link",
      "fn Browser::ensure_declarative_shadow_dom_normalized",
      "fn Browser::build_accessibility_tree",
      "fn Browser::get_focused_element_name",
      "fn Browser::get_focused_source_id",
      "fn Browser::get_link_source_id_at",
      "fn Browser::get_link_href_for_source_id",
      "fn Browser::is_clickable_source_id",
      "fn Browser::get_a11y_source_id_at",
      "fn Browser::get_source_id_at",
      "fn Browser::focus_source_id",
      "fn Browser::get_visible_focus_index",
      "fn Browser::get_link_at",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell accessibility tree building in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/accessibility_tree.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn Browser::ensure_declarative_shadow_dom_normalized",
      "fn Browser::build_accessibility_tree",
      "fn Browser::build_accessibility_tree_lightweight",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell focus navigation in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/focus_navigation.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn Browser::is_bounds_visible",
      "fn Browser::is_focus_node_visible",
      "fn Browser::next_link",
      "fn Browser::prev_link",
      "fn Browser::get_focused_element_name",
      "fn Browser::get_focused_link_url",
      "fn Browser::get_focused_source_id",
      "fn Browser::focus_source_id",
      "fn Browser::get_visible_focusable_count",
      "fn Browser::get_visible_focus_index",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell interaction controller in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/interaction_controller.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn cell_to_client_x",
      "fn Browser::get_client_coords_for_source_id",
      "fn Browser::get_hit_region_for_source_id",
      "fn Browser::handle_focused_key",
      "fn Browser::activate_focused_link",
      "fn Browser::hover_at",
      "fn Browser::pointer_down_at",
      "fn Browser::pointer_move_at",
      "fn Browser::pointer_up_at",
      "fn Browser::activate_at",
      "fn Browser::activate_link_at",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell link extraction in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/link_extraction.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn char_at",
      "fn extract_links_fallback",
      "extern \"js\" fn extract_links_js",
      "fn extract_links",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell link cache refresh with link extraction", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/rendering.mbt"), "utf8");
    const implementationMarkers = ["fn Browser::refresh_links_from_render_source"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell link resolution in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/link_resolution.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/focus_hit_testing.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn Browser::get_extracted_link_href_for_source_id",
      "fn Browser::get_a11y_link_href_for_source_id",
      "fn Browser::get_link_href_for_source_id",
      "fn Browser::get_link_href_for_region",
      "fn Browser::get_href_for_source_id",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell hint mode in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/hint_mode.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::is_hint_mode",
      "fn Browser::enter_hint_mode",
      "fn generate_single_label",
      "fn Browser::exit_hint_mode",
      "fn Browser::process_hint_char",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell scroll state in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/scroll_state.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::max_scroll",
      "fn Browser::scroll_down",
      "fn Browser::scroll_up",
      "fn Browser::init_element_scroll",
      "fn Browser::clear_element_scroll_states",
      "fn Browser::init_scrollable_elements",
      "fn Browser::get_element_scroll_positions",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell output mode helpers in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/output_modes.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::debug_layout",
      "fn Browser::render_json",
      "fn Browser::render_aom",
      "fn Browser::render_arc90",
      "fn Browser::render_extract_main",
      "fn Browser::render_grounding",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell option accessors in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/browser_options.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = [
      "fn Browser::set_enable_js",
      "fn Browser::set_enable_cookies",
      "fn Browser::set_image_cache_max_bytes",
      "fn Browser::set_request_sandbox",
      "fn Browser::get_dom_tree",
      "fn Browser::get_current_url",
      "fn Browser::get_last_navigation_url",
      "fn Browser::get_viewport_height",
      "fn Browser::get_link_count",
      "fn Browser::get_focused_link_index",
      "fn Browser::toggle_selection_mode",
      "fn Browser::toggle_dark_mode",
      "fn Browser::set_dark_mode",
      "fn Browser::set_no_color",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser shell content lifecycle in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/content_lifecycle.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/browser.mbt"), "utf8");
    const implementationMarkers = ["fn Browser::set_html_content"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps navigation HTML source lifecycle out of navigation", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "html_source_has_declarative_shadow_dom",
      "normalize_declarative_shadow_source_html_with_hint",
      "@html.parse_document(self.html_content)",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps navigation fetch plumbing in its own file", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/shell/navigation_fetch.mbt"))).toBe(true);

    const source = fs.readFileSync(path.join(REPO_ROOT, "browser/shell/navigation.mbt"), "utf8");
    const implementationMarkers = [
      "@http.fetch",
      "@http.FetchOptions::default()",
      "get_cookie_header",
      "store_from_header",
      "page_headers",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi validation helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_validation.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::validate_session_subscribe_params",
      "fn BidiProtocol::validate_browser_create_user_context",
      "fn BidiProtocol::validate_network_add_intercept_params",
      "fn BidiProtocol::validate_network_set_extra_headers_params",
      "fn is_valid_network_pattern_url_pattern",
      "fn is_valid_subscription_id_format",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi JSON parameter helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_json.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn make_object",
      "fn get_field",
      "fn get_param_raw",
      "fn get_map_field_with_alias",
      "fn canonicalize_serialization_options_map",
      "fn resolve_runtime_context_id",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi message serialization out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_messages.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "priv struct BidiRequest",
      "priv struct BidiResponse",
      "priv enum BidiOutMessage",
      "fn BidiProtocol::process_message",
      "fn BidiProtocol::send_success",
      "fn response_to_json",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi wire envelopes in standalone mizchi/webdriver", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/bidi_wire/moon.pkg"))).toBe(false);

    const moduleJson = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, "webdriver/moon.mod.json"), "utf8"),
    );
    expect(moduleJson.deps["mizchi/webdriver"]).toBe("0.2.6");

    const packageSource = fs.readFileSync(path.join(REPO_ROOT, "webdriver/webdriver/moon.pkg"), "utf8");
    expect(packageSource).toContain("\"mizchi/webdriver/bidi\" @bidi_wire");

    const messageSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_messages.mbt"),
      "utf8",
    );
    expect(messageSource).toContain("@bidi_wire.parse_request(");
    expect(messageSource).toContain("@bidi_wire.success_response_to_json(");
    expect(messageSource).toContain("@bidi_wire.error_response_to_json_with_stacktrace(");
    expect(messageSource).toContain("@bidi_wire.event_to_json(");
    expect(messageSource).not.toContain("@json.parse(json_str)");
    expect(messageSource).not.toContain("\"type\"] = Json::string(\"success\")");
  });

  it("keeps WebDriver BiDi subscription state out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_subscription_state.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "subscriptions : Map[String, Bool]",
      "context_subscriptions : Map[String, Array[String]]",
      "user_context_subscriptions : Map[String, Array[String]]",
      "global_subscriptions : Array[String]",
      "global_unsubscribed_events : Array[String]",
      "subscription_events : Map[String, Array[String]]",
      "subscription_contexts : Map[String, Array[String]]",
      "subscription_user_contexts : Map[String, Array[String]]",
      "next_subscription_id : Int",
      "pending_log_entries : Map[String, Array[Json]]",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);

    const stateSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_subscription_state.mbt"),
      "utf8",
    );
    expect(stateSource).toContain("priv struct BidiSubscriptionState");
    expect(stateSource).toContain("fn BidiSubscriptionState::new(");
    expect(stateSource).toContain("fn BidiSubscriptionState::reset(");
    expect(stateSource).toContain("fn BidiSubscriptionState::generate_subscription_id(");
  });

  it("keeps WebDriver BiDi emulation state out of the protocol core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_emulation_state.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "emulation_user_agent_global : String?",
      "emulation_user_agent_by_context : Map[String, String]",
      "emulation_user_agent_by_user_context : Map[String, String]",
      "emulation_locale_global : String?",
      "emulation_locale_by_context : Map[String, String]",
      "emulation_locale_by_user_context : Map[String, String]",
      "emulation_timezone_global : String?",
      "emulation_timezone_by_context : Map[String, String]",
      "emulation_timezone_by_user_context : Map[String, String]",
      "emulation_geolocation_global : Json?",
      "emulation_geolocation_by_context : Map[String, Json]",
      "emulation_geolocation_by_user_context : Map[String, Json]",
      "emulation_network_conditions_global : Json?",
      "emulation_network_conditions_by_context : Map[String, Json]",
      "emulation_network_conditions_by_user_context : Map[String, Json]",
      "emulation_screen_orientation_global : Json?",
      "emulation_screen_orientation_by_context : Map[String, Json]",
      "emulation_screen_orientation_by_user_context : Map[String, Json]",
      "emulation_screen_area_global : Json?",
      "emulation_screen_area_by_context : Map[String, Json]",
      "emulation_screen_area_by_user_context : Map[String, Json]",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);

    const stateSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_emulation_state.mbt"),
      "utf8",
    );
    expect(stateSource).toContain("priv struct BidiEmulationState");
    expect(stateSource).toContain("fn BidiEmulationState::new(");
    expect(stateSource).toContain("fn BidiEmulationState::reset(");
  });

  it("keeps WebDriver BiDi network runtime state out of the protocol core", () => {
    const stateSource = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_network_state.mbt"),
      "utf8",
    );
    expect(stateSource).toContain("priv struct BidiNetworkState");
    expect(stateSource).toContain("fn BidiNetworkState::new(");

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "network_intercepts : Map[String, Json]",
      "next_network_intercept_id : Int",
      "next_network_request_id : Int",
      "network_cache_behavior_global : String",
      "network_extra_headers_global : Map[String, String]",
      "network_extra_headers_by_context : Map[String, Map[String, String]]",
      "network_extra_headers_by_user_context : Map[String, Map[String, String]]",
      "network_cache_behavior_by_context : Map[String, String]",
      "network_state_channel_by_context : Map[String, String]",
      "network_cached_requests_by_context : Map[String, Map[String, Bool]]",
      "network_blocked_requests : Map[String, Json]",
      "network_data_collectors : Map[String, Json]",
      "network_collected_data : Map[String, Map[String, Map[String, Json]]]",
      "next_network_data_collector_id : Int",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi dispatch routing out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_dispatch.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::dispatch(",
      "fn BidiProtocol::dispatch_session",
      "fn BidiProtocol::dispatch_browser",
      "fn BidiProtocol::dispatch_browsing_context",
      "fn BidiProtocol::dispatch_script",
      "fn BidiProtocol::dispatch_input",
      "fn BidiProtocol::dispatch_network",
      "fn BidiProtocol::dispatch_log",
      "fn split_method",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi browsing context handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_browsing_context.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_browsing_context_create_synthetic_child_context",
      "fn BidiProtocol::handle_browsing_context_get_context_scope_info",
      "fn BidiProtocol::handle_browsing_context_get_tree_contexts",
      "fn BidiProtocol::resolve_current_context_url",
      "fn BidiProtocol::create_top_level_context_from_params",
      "fn BidiProtocol::handle_browsing_context_prepare_navigate",
      "fn BidiProtocol::complete_navigate_with_state",
      "fn BidiProtocol::handle_browsing_context_close_mode",
      "fn BidiProtocol::build_context_tree",
      "fn BidiProtocol::resolve_get_tree_contexts",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi script evaluation handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_script_eval.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn resolve_sync_await_expression_fallback",
      "fn resolve_sync_await_call_expression",
      "fn BidiProtocol::try_send_sync_await_expression_fallback",
      "fn BidiProtocol::try_send_sync_await_call_fallback",
      "fn BidiProtocol::handle_script_evaluate",
      "fn BidiProtocol::handle_script_call_function",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi script fixture helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_script_fixtures.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_script_get_element_for_test",
      "fn BidiProtocol::handle_script_prepare_loaded_static_test_page",
      "fn BidiProtocol::handle_script_load_static_test_page_for_test",
      "fn BidiProtocol::resolve_script_get_element_for_test",
      "fn BidiProtocol::resolve_script_create_iframe_context_result",
      "fn BidiProtocol::handle_script_fetch_for_test",
      "fn synthetic_fetch_request_headers_from_json",
      "extern \"js\" fn js_test_page_dom_content_loaded_source",
      "extern \"js\" fn js_fetch_from_context_for_test_expression",
      "extern \"js\" fn js_test_page_create_iframe_source",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi input action handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_input_actions.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_input_perform_actions",
      "fn BidiProtocol::handle_input_release_actions",
      "fn BidiProtocol::handle_input_set_files",
      "fn BidiProtocol::validate_input_context",
      "fn BidiProtocol::resolve_pointer_origin",
      "fn BidiProtocol::push_pressed_key",
      "fn button_to_mask",
      "extern \"js\" fn js_input_apply_file_selection",
      "fn BidiProtocol::try_handle_synthetic_file_dialog_eval",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi network command handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_network_commands.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_network_add_intercept",
      "fn BidiProtocol::handle_network_add_intercept_id",
      "fn BidiProtocol::handle_network_remove_intercept",
      "fn BidiProtocol::handle_network_add_data_collector",
      "fn BidiProtocol::handle_network_add_data_collector_id",
      "fn BidiProtocol::handle_network_set_extra_headers",
      "fn BidiProtocol::handle_network_remove_data_collector",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi browser handlers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_browser.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_browser_has_user_context",
      "fn BidiProtocol::handle_browser_has_user_context_value",
      "fn BidiProtocol::resolve_browser_has_user_context_known",
      "fn BidiProtocol::resolve_browser_user_contexts_list",
      "fn BidiProtocol::resolve_browser_client_windows_list",
      "fn BidiProtocol::resolve_browser_create_user_context",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi session test helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_session.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_session_is_subscribed_for_context",
      "fn BidiProtocol::handle_session_prepare_baseline_context_for_test",
      "fn BidiProtocol::recreate_default_context_with_id",
      "fn BidiProtocol::handle_session_get_baseline_context_info_for_test",
      "fn BidiProtocol::handle_session_get_baseline_context_info_value_for_test",
      "fn BidiProtocol::build_context_info_for_test",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi log and script event helpers out of the protocol core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_log.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::emit_log_entry_with_details",
      "fn BidiProtocol::emit_log_entry",
      "fn BidiProtocol::emit_javascript_log_entry",
      "fn BidiProtocol::process_console_entries",
      "fn BidiProtocol::emit_script_message",
      "fn BidiProtocol::process_channel_messages",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi preload and context scope helpers out of the protocol core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_preload.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::collect_context_ancestry",
      "fn BidiProtocol::build_context_ancestry",
      "fn BidiProtocol::build_context_scope_info_json",
      "fn BidiProtocol::resolve_top_level_context(",
      "fn BidiProtocol::is_preload_script_applicable",
      "fn build_preload_call_expression",
      "fn extract_window_property_names",
      "fn BidiProtocol::clear_window_properties_in_context",
      "fn BidiProtocol::cleanup_removed_preload_entry",
      "fn BidiProtocol::remove_all_preload_scripts",
      "fn BidiProtocol::run_preload_script_in_context",
      "fn BidiProtocol::apply_preload_scripts_for_context",
      "fn BidiProtocol::has_mutation_observer_preload_for_context",
      "fn BidiProtocol::emit_synthetic_mutation_observer_messages",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi browsingContext rendering commands out of the protocol core", () => {
    expect(
      fs.existsSync(
        path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_browsing_context_rendering.mbt"),
      ),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn BidiProtocol::handle_set_viewport",
      "fn BidiProtocol::handle_traverse_history",
      "fn BidiProtocol::handle_capture_screenshot",
      "fn BidiProtocol::handle_capture_screenshot_data",
      "fn BidiProtocol::resolve_capture_screenshot_data",
      "fn BidiProtocol::handle_print",
      "fn BidiProtocol::handle_print_data",
      "fn BidiProtocol::resolve_print_data",
      "fn is_valid_print_page_range",
      "fn is_valid_locate_nodes_locator_type",
      "fn xpath_to_css_selector",
      "fn BidiProtocol::handle_locate_nodes",
      "fn normalize_svg_namespace_in_nodes",
      "fn BidiProtocol::locate_nodes_css",
      "fn BidiProtocol::evaluate_locate_expression",
      "fn BidiProtocol::create_synthetic_child_context_result",
      "fn BidiProtocol::locate_nodes_xpath",
      "fn BidiProtocol::locate_nodes_inner_text",
      "fn BidiProtocol::locate_nodes_accessibility",
      "fn BidiProtocol::locate_nodes_context",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime document helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_document.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_sync_runtime_html_async",
      "extern \"js\" fn js_sync_runtime_page_async",
      "pub fn sync_runtime_page",
      "pub fn sync_runtime_html",
      "extern \"js\" fn js_decode_base64",
      "pub fn decode_base64",
      "pub fn parse_data_url",
      "fn make_substr",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime eval helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_eval.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_evaluate_expression",
      "extern \"js\" fn js_evaluate_expression_fast",
      "fn evaluate_js_with_console",
      "pub fn evaluate_js",
      "extern \"js\" fn js_evaluate_expression_async",
      "extern \"js\" fn js_await_promise",
      "pub fn evaluate_js_async",
      "extern \"js\" fn js_eval_and_send_async",
      "fn eval_and_send_async_with_console",
      "pub fn eval_and_send_async",
      "pub fn await_promise",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime context helpers out of the server transport", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_context.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn reset_runtime_js_state",
      "extern \"js\" fn ensure_runtime_navigator_patch_helper",
      "extern \"js\" fn js_set_runtime_context",
      "pub fn set_runtime_context",
      "extern \"js\" fn js_reset_runtime_event_buffers",
      "pub fn reset_runtime_event_buffers",
      "extern \"js\" fn js_set_runtime_context_frames",
      "pub fn set_runtime_context_frames",
      "extern \"js\" fn js_set_runtime_context_viewport",
      "pub fn set_runtime_context_viewport",
      "extern \"js\" fn js_set_runtime_context_user_agent",
      "pub fn set_runtime_context_user_agent",
      "extern \"js\" fn js_set_runtime_context_locale",
      "pub fn set_runtime_context_locale",
      "extern \"js\" fn js_set_runtime_context_network_online",
      "pub fn set_runtime_context_network_online",
      "extern \"js\" fn js_set_runtime_context_screen_orientation",
      "pub fn set_runtime_context_screen_orientation",
      "extern \"js\" fn js_set_runtime_context_screen_area",
      "pub fn set_runtime_context_screen_area",
      "extern \"js\" fn js_has_runtime_handle",
      "pub fn has_runtime_handle",
      "extern \"js\" fn js_runtime_shared_node_center_json",
      "pub fn get_runtime_shared_node_center_json",
      "extern \"js\" fn js_runtime_href_at_point",
      "pub fn get_runtime_href_at_point",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime channel helpers out of the server transport", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_channel.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_take_channel_messages",
      "pub fn take_channel_messages_json",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime input helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_input.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_input_dispatch_key_action",
      "pub fn input_dispatch_key_action",
      "extern \"js\" fn js_input_is_single_grapheme",
      "pub fn input_is_single_grapheme",
      "extern \"js\" fn js_input_set_pointer_event_properties",
      "pub fn input_set_pointer_event_properties",
      "extern \"js\" fn js_input_clear_pointer_event_properties",
      "pub fn input_clear_pointer_event_properties",
      "extern \"js\" fn js_input_dispatch_pointer_event_with_related",
      "pub fn input_dispatch_pointer_event",
      "pub fn input_dispatch_pointer_event_with_related",
      "extern \"js\" fn js_input_dispatch_drag_event",
      "pub fn input_dispatch_drag_event",
      "extern \"js\" fn js_input_dispatch_wheel_event",
      "pub fn input_dispatch_wheel_event",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer inline-flow helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/inline_flow.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_inline_element_by_tag",
      "fn is_inline_element(",
      "fn will_have_non_inline_display",
      "fn is_inline_participating_display",
      "fn has_inline_participating_display",
      "fn is_whitespace_only_text",
      "fn is_collapsible_whitespace_char",
      "fn trim_collapsible_whitespace_edges",
      "fn trim_boundary_collapsible_whitespace_for_inline_context",
      "fn should_preserve_inter_element_whitespace",
      "fn should_preserve_inline_element",
      "fn contains_preserved_inline_descendant",
      "fn collect_text_from_inline",
      "fn contains_replaced_element",
      "fn contains_block_child",
      "fn has_direct_display_contents_child",
      "fn has_direct_contents_class_child",
      "fn is_out_of_flow_positioned",
      "fn collect_inline_content",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer replaced-element helpers out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/replaced_element.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_replaced_element",
      "fn create_image_measure",
      "fn broken_img_alt_uses_non_replaced_overflow_box",
      "fn create_input_measure",
      "fn is_text_like_input_type",
      "fn resolve_input_paint_text",
      "fn input_uses_placeholder_text",
      "fn should_preserve_auto_replaced_width",
      "fn should_preserve_auto_replaced_height",
      "fn should_apply_intrinsic_replaced_aspect_ratio",
      "fn create_br_measure",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer special element node finalization out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/special_element_node.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      'tag_lower == "input" && children.is_empty()',
      'tag_lower == "button" &&',
      'tag_lower == "textarea"',
      'tag_lower == "select"',
      'tag_lower == "svg" && children.is_empty()',
      'tag_lower == "img" && children.is_empty()',
      'tag_lower == "canvas" && children.is_empty()',
      'tag_lower == "iframe" || tag_lower == "object" || tag_lower == "embed"',
      'tag_lower == "video" || tag_lower == "audio"',
      'tag_lower == "br"',
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer styled child node construction out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/styled_children.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "let mut prev_sibling_counters",
      "let mut prev_selector_sibling",
      "html_to_selector_element_with_parent(",
      "trim_boundary_collapsible_whitespace_for_inline_context(",
      "should_preserve_inter_element_whitespace(",
      "filter_counter_state_for_style_containment(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer nested element style adjustment out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/element_style_adjust.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      'elem.attributes.contains("hidden")',
      'tag_lower == "dialog"',
      "preserve_inline_contain",
      "is_ruby_internal",
      "contains_block_child(",
      "has_direct_display_contents_child(",
      "has_direct_contents_class_child(",
      "contains_replaced_element(",
      "apply_svg_attributes_to_style(",
      "apply_svg_intrinsic_size(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer root element node construction out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/root_element_node.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn element_to_node_with_styles(",
      "empty_indexed_stylesheets.val",
      "html_to_selector_element(elem, parent)",
      "parent is None",
      "None, // Root element has no parent style",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer nested element node construction out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/nested_element_node.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn element_to_node_with_styles_internal(",
      "build_viewport_skeleton_node(",
      "compute_element_style_indexed(",
      "apply_element_visibility_attributes(",
      "should_advance_viewport_estimate(",
      "adjust_nested_element_style(",
      "compute_element_css_vars_indexed(",
      "resolve_element_counter_pseudos(",
      "build_styled_element_children(",
      "prune_closed_details_children(",
      "finalize_special_element_node(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer intrinsic-media parsers out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/intrinsic_media.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn parse_html_dimension",
      "fn url_decode",
      "fn find_string_index",
      "fn extract_svg_attribute",
      "fn parse_viewbox",
      "fn parse_svg_data_uri",
      "fn base64_char_value",
      "fn decode_base64_prefix",
      "fn parse_gif_data_uri",
      "fn parse_png_data_uri",
      "fn get_image_intrinsic_size_default",
      "fn get_image_intrinsic_size",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer document preparation out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/document_prepare.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "pub struct PseudoRule",
      "pub struct PseudoRuleIndex",
      "fn PseudoRuleIndex::build",
      "fn PseudoRuleIndex::get_candidates",
      "pub struct PreparedExternalCss",
      "let external_css_bundle_cache",
      "fn external_css_cache_key",
      "fn collect_pseudo_rules_from_stylesheet",
      "fn empty_prepared_external_css",
      "pub fn prepare_external_css",
      "pub struct PreparedRenderDocument",
      "pub fn prepare_render_document",
      "pub fn prepare_render_document_with_prepared_external_css",
      "fn prepare_render_document_with_external_css_bundle",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer generated content and counters out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/generated_content.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "priv struct CounterEntry",
      "priv struct CounterDirective",
      "priv enum ContentPart",
      "priv enum PseudoKind",
      "fn parse_counter_directives",
      "fn copy_counter_state",
      "fn filter_counter_state_for_style_containment",
      "fn apply_counter_reset_directives",
      "fn apply_counter_increment_directives",
      "fn counter_value",
      "fn resolve_pseudo_attr_functions",
      "fn resolve_pseudo_content_value",
      "fn parse_content_parts",
      "fn evaluate_content_parts",
      "fn selector_text_without_pseudo",
      "fn create_generated_pseudo_node",
      "fn apply_generated_pseudo_host_style_offsets",
      "fn resolve_pseudo_spec",
      "fn resolve_pseudo_spec_fast",
      "fn get_counter_directives",
      "fn selector_has_generated_pseudo_content",
      "fn compute_element_own_counters",
      "spec.position_relative && spec.left_offset",
      "compute_element_own_counters(",
      "resolve_pseudo_spec_fast(",
      "apply_generated_pseudo_host_style_offsets(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer SVG style helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/svg_style.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_svg_element",
      "fn selector_parent_is_svg",
      "fn normalize_svg_display_contents",
      "fn apply_svg_attributes_to_style",
      "fn apply_svg_intrinsic_size",
      "fn parse_svg_length",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer style resolution helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/style_resolve.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_root_selector",
      "fn clone_string_map",
      "fn collect_cascaded_custom_properties",
      "fn collect_inline_custom_properties",
      "fn collect_root_css_variables",
      "fn get_ua_default_style",
      "fn uses_table_normal_line_height",
      "fn normalize_display_contents_for_unusual_html",
      "fn compute_element_style_indexed",
      "fn compute_element_css_vars_indexed",
      "fn apply_css_property_with_viewport",
      "pub fn apply_css_property_debug",
      "fn apply_inline_css_with_vars",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer absolute positioning helpers out of renderer core", () => {
    expect(
      fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/absolute_positioning.mbt")),
    ).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn resolve_inset_for_root",
      "fn inset_is_definite_for_root",
      "fn resolve_out_of_flow_root_auto_size",
      "fn is_svg_container_id",
      "fn establishes_absolute_containing_block",
      "fn is_auto_inset",
      "fn compute_abspos_non_auto_inset_alignment_offset",
      "fn apply_zoom_and_scale",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer layout JSON serialization out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/layout_json.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn safe_number",
      "fn number_to_json",
      "fn write_number_json",
      "fn write_rect_json",
      "pub fn layout_to_json",
      "fn estimate_layout_json_size",
      "fn layout_to_json_impl",
      "fn escape_json_string",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer viewport skeleton helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/viewport_skeleton.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "let viewport_estimated_y",
      "let viewport_cutoff",
      "let viewport_skeleton_count",
      "let viewport_full_node_count",
      "let viewport_full_node_cutoff",
      "let viewport_skeleton_enabled",
      "let empty_indexed_stylesheets",
      "fn should_use_viewport_skeleton",
      "fn parse_skeleton_px_length",
      "fn apply_skeleton_inline_style_hints",
      "fn apply_skeleton_inline_display_hint",
      "fn apply_skeleton_inline_height_hint",
      "fn viewport_skeleton_advance",
      "fn skeleton_parent_allows_explicit_size_hints",
      "fn should_collapse_viewport_skeleton_subtree",
      "fn should_advance_viewport_estimate",
      "viewport_skeleton_count.val += 1",
      "apply_skeleton_inline_style_hints(",
      "apply_skeleton_inline_display_hint(",
      "viewport_skeleton_advance(",
      "should_collapse_viewport_skeleton_subtree(",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer render root helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/render_root.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "let active_before_index",
      "let active_after_index",
      "pub fn build_render_root_node",
      "pub fn compute_layout_from_render_root",
      "fn find_body(",
      "fn find_body_in_children",
      "fn resolve_document_root_zoom",
      "fn propagate_document_root_multicol_to_body",
      "fn should_layout_document_root",
      "fn select_render_root",
      "fn resolve_root_available_width",
      "fn node_with_style",
      "fn should_clamp_body_to_viewport",
      "fn adjust_root_height_for_viewport",
      "fn stretch_single_frameset_child_to_root",
      "fn create_zero_layout_from_node",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer text node creation out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/text_node.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn create_text_node",
      "let normalized_text = if parent_style.display == @types.TableCell",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer node id helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/node_id.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["fn node_id_is_tag", "fn make_node_id"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer details element pruning out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/details_element.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn clone_node_with_children",
      "fn find_first_summary_path_in_node",
      "fn find_first_summary_path_in_children",
      "fn prune_node_to_summary_path",
      "fn prune_closed_details_children",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table display helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/table_display.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn is_table_element",
      "fn is_table_display",
      "fn is_no_principal_table_internal_display",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table attribute normalization out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/table_attributes.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      'elem.attributes.get("cellspacing")',
      'elem.attributes.get("cellpadding")',
      'elem.attributes.get("rowspan")',
      'elem.attributes.get("colspan")',
      "current_cellpadding.val",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer box sizing helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/box_sizing.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn resolve_dimension_to_px",
      "fn resolve_dimension_with_percent_basis",
      "fn is_zero_dimension_value",
      "fn has_zero_box_offsets",
      "fn adjust_for_box_sizing",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer selector element conversion out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/selector_element.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "fn html_to_selector_element(",
      "fn html_to_selector_element_minimal",
      "fn html_to_selector_element_with_parent",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer shared string helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/string_utils.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["fn remove_suffix"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer element skip policy out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/skip_element.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["fn should_skip_element"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer simple element conversion out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/simple_element_node.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = ["pub fn element_to_node"] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer public API wrappers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/render_api.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "pub fn render(",
      "pub fn render_with_external_css",
      "pub fn render_document_with_external_css",
      "pub fn render_document_with_prepared_external_css",
      "pub fn render_to_node(",
      "pub fn render_to_node_with_external_css",
      "pub fn render_to_node_and_layout(",
      "pub fn render_to_node_and_layout_full_document",
      "pub fn render_to_node_and_layout_with_external_css",
      "pub fn render_to_node_with_document",
      "pub fn render_to_node_with_prepared_external_css",
      "pub fn render_to_node_and_layout_with_document",
      "pub fn render_to_node_and_layout_with_prepared_external_css",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer content height helpers out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/content_height.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "pub fn get_content_height_with_css",
      "pub fn get_content_height(",
      "fn calculate_content_extent",
      "pub fn get_content_height_with_document",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer layout debug printing out of renderer core", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "renderer/renderer/layout_debug.mbt"))).toBe(true);

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "pub fn print_layout_tree(",
      "pub fn print_layout_tree_with_options",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("guards split core files from size regression", () => {
    const guardedFiles = [
      { file: "webdriver/webdriver/bidi_protocol.mbt", maxLines: 8000 },
      { file: "webdriver/webdriver/bidi_server.mbt", maxLines: 400 },
      { file: "renderer/renderer/renderer.mbt", maxLines: 30 },
      { file: "painter/svg/types.mbt", maxLines: 30 },
      { file: "renderer/renderer/render_test.mbt", maxLines: 20 },
      { file: "renderer/renderer/renderer_test.mbt", maxLines: 20 },
      { file: "renderer/renderer/table_render_test.mbt", maxLines: 20 },
    ] as const;

    const offenders = guardedFiles
      .map(({ file, maxLines }) => ({ file, maxLines, lines: countLines(file) }))
      .filter(({ lines, maxLines }) => lines > maxLines);

    expect(offenders).toEqual([]);
  });

  it("keeps renderer table cell regression tests in their own file", () => {
    const tableCellTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_cell_render_test.mbt",
    );
    expect(fs.existsSync(tableCellTestFile)).toBe(true);

    const tableCellSource = fs.readFileSync(tableCellTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "wpt_table_cell_overflow_auto_respects_max_width"',
      'test "wpt_table_cell_child_overflow_measure_keeps_explicit_height"',
      'test "table_cell_defaults_to_normal_line_height_metrics"',
    ] as const;

    expect(migratedTests.every((marker) => tableCellSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table display model regression tests in their own file", () => {
    const tableDisplayTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_display_render_test.mbt",
    );
    expect(fs.existsSync(tableDisplayTestFile)).toBe(true);

    const tableDisplaySource = fs.readFileSync(tableDisplayTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "quirks_table_cell_inline_size_preserves_table_display_model"',
      'test "mixed_inline_and_table_child_keeps_table_shrink_width"',
    ] as const;

    expect(migratedTests.every((marker) => tableDisplaySource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table row visual regression tests in their own file", () => {
    const tableRowTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_row_render_test.mbt",
    );
    expect(fs.existsSync(tableRowTestFile)).toBe(true);

    const tableRowSource = fs.readFileSync(tableRowTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "wpt_visibility_collapse_border_spacing_002_layout"',
      'test "overflow alignment table keeps sixth cell width in node and layout"',
    ] as const;

    expect(migratedTests.every((marker) => tableRowSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table containment regression tests in their own file", () => {
    const tableContainmentTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_containment_render_test.mbt",
    );
    expect(fs.existsSync(tableContainmentTestFile)).toBe(true);

    const tableContainmentSource = fs.readFileSync(tableContainmentTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "contain_layout_table_row_group_has_no_principal_box"',
      'test "contain_paint_table_row_group_static_abs_keeps_static_position"',
      'test "contain_paint_table_cell_abs_does_not_contribute_intrinsic_size"',
      'test "contain_size_table_row_group_with_text_does_not_crash"',
    ] as const;

    expect(migratedTests.every((marker) => tableContainmentSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table empty-cell regression tests in their own file", () => {
    const tableEmptyCellTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_empty_cell_render_test.mbt",
    );
    expect(fs.existsSync(tableEmptyCellTestFile)).toBe(true);

    const tableEmptyCellSource = fs.readFileSync(tableEmptyCellTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "empty_td_has_zero_content_height"',
      'test "all_empty_td_row_has_zero_height"',
      'test "empty_td_with_colspan_has_zero_height"',
      'test "empty_td_with_line_height_has_zero_content_height"',
      'test "whitespace_only_td_has_zero_content_height"',
      'test "empty_td_does_not_inflate_row_with_large_line_height"',
      'test "empty_td_cellpadding_does_not_inflate_row"',
    ] as const;

    expect(migratedTests.every((marker) => tableEmptyCellSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table intrinsic sizing regression tests in their own file", () => {
    const tableIntrinsicTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_intrinsic_render_test.mbt",
    );
    expect(fs.existsSync(tableIntrinsicTestFile)).toBe(true);

    const tableIntrinsicSource = fs.readFileSync(tableIntrinsicTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "fixed_table_caption_keeps_intrinsic_width"',
      'test "size_contained_caption_contributes_border_width_to_empty_table"',
      'test "vertical writing table keeps intrinsic max-width in computed style"',
      'test "wpt_block_size_table_container_keeps_auto_size_in_computed_style"',
      'test "wpt_table_intrinsic_size_001_inline_size_floor"',
      'test "wpt_table_intrinsic_size_002_max_inline_size_floor"',
      'test "wpt_table_intrinsic_size_003_vertical_inline_size_floor"',
      'test "wpt_table_intrinsic_size_004_vertical_max_inline_size_floor"',
      'test "wpt_intrinsic_percent_replaced_018_like_table_min_content_ignores_newline_gap"',
    ] as const;

    expect(migratedTests.every((marker) => tableIntrinsicSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table flex item regression tests in their own file", () => {
    const tableFlexTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_flex_render_test.mbt",
    );
    expect(fs.existsSync(tableFlexTestFile)).toBe(true);

    const tableFlexSource = fs.readFileSync(tableFlexTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "wpt_table_as_flex_item_auto_min_width_floor"',
      'test "wpt_table_as_flex_item_fixed_min_width_floor"',
      'test "wpt_table_flex_item_auto_width_uses_flex_used_size"',
      'test "wpt_table_flex_item_percent_width_does_not_override_used_size"',
      'test "wpt_table_percent_width_inside_flex_item_wrapper_uses_used_main_size"',
    ] as const;

    expect(migratedTests.every((marker) => tableFlexSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table parser regression tests in their own file", () => {
    const tableParserTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_parser_render_test.mbt",
    );
    expect(fs.existsSync(tableParserTestFile)).toBe(true);

    const tableParserSource = fs.readFileSync(tableParserTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "table cells keep nbsp text when td end tags are omitted"',
      'test "table omitted td end tags do not double last cell width with trailing indentation"',
    ] as const;

    expect(migratedTests.every((marker) => tableParserSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table positioning regression tests in their own file", () => {
    const tablePositioningTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_positioning_render_test.mbt",
    );
    expect(fs.existsSync(tablePositioningTestFile)).toBe(true);

    const tablePositioningSource = fs.readFileSync(tablePositioningTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "relative tfoot offset does not inflate parent auto height"',
      'test "relative tfoot abs child does not inflate parent auto height"',
      'test "abspos_canvas_display_table_respects_explicit_css_height"',
    ] as const;

    expect(migratedTests.every((marker) => tablePositioningSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer table attribute regression tests in their own file", () => {
    const tableAttributesTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/table_attributes_render_test.mbt",
    );
    expect(fs.existsSync(tableAttributesTestFile)).toBe(true);

    const tableAttributesSource = fs.readFileSync(tableAttributesTestFile, "utf8");
    const tableSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "cellpadding_attribute_sets_cell_padding"',
      'test "nested_table_cell_height_ignores_surrounding_whitespace"',
      'test "table width=85% constrains content within 85% of viewport"',
    ] as const;

    expect(migratedTests.every((marker) => tableAttributesSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => tableSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer absolute positioning regression tests in their own file", () => {
    const absoluteTestFile = path.join(REPO_ROOT, "renderer/renderer/absolute_position_test.mbt");
    expect(fs.existsSync(absoluteTestFile)).toBe(true);

    const absoluteSource = fs.readFileSync(absoluteTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "position relative with negative offset"',
      'test "fixed_child_in_abspos_parent_uses_viewport_reference"',
      'test "html_abspos_root_keeps_html_as_layout_root"',
    ] as const;

    expect(migratedTests.every((marker) => absoluteSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer generated content regression tests in their own file", () => {
    const generatedTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/generated_content_render_test.mbt",
    );
    expect(fs.existsSync(generatedTestFile)).toBe(true);

    const generatedSource = fs.readFileSync(generatedTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "pseudo_content_var_from_root_custom_properties_renders_text"',
      'test "pseudo_before_after_default_inline_does_not_stack_list_item_lines"',
      'test "pseudo_empty_content_with_block_display_generates_box"',
    ] as const;

    expect(migratedTests.every((marker) => generatedSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer display contents regression tests in their own file", () => {
    const displayContentsTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/display_contents_render_test.mbt",
    );
    expect(fs.existsSync(displayContentsTestFile)).toBe(true);

    const displayContentsSource = fs.readFileSync(displayContentsTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "display_contents_inline_flex_collapses_boundary_spaces"',
      'test "display_contents keeps inline parent shrink-to-fit and preserves child span"',
      'test "display_contents text contributes to flex item intrinsic width"',
      'test "display_inline_with_contents_child_stays_inline_sized"',
    ] as const;

    expect(migratedTests.every((marker) => displayContentsSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer form control regression tests in their own file", () => {
    const formControlTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/form_control_render_test.mbt",
    );
    expect(fs.existsSync(formControlTestFile)).toBe(true);

    const formControlSource = fs.readFileSync(formControlTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "contain_size_select_single_uses_empty_control_metrics"',
      'test "input_button_like_intrinsic_width_uses_value_length"',
      'test "wpt_justify_self_widgets_textarea_keeps_browser_default_block_heights"',
    ] as const;

    expect(migratedTests.every((marker) => formControlSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer replaced media regression tests in their own file", () => {
    const replacedMediaTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/replaced_media_render_test.mbt",
    );
    expect(fs.existsSync(replacedMediaTestFile)).toBe(true);

    const replacedMediaSource = fs.readFileSync(replacedMediaTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "intrinsic_percent_replaced_wpt_style"',
      'test "video_with_source_children_keeps_explicit_replaced_size"',
      'test "br element preserved as separate node with line-height"',
    ] as const;

    expect(migratedTests.every((marker) => replacedMediaSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer multicol fragmentation regression tests in their own file", () => {
    const multicolTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/multicol_fragmentation_render_test.mbt",
    );
    expect(fs.existsSync(multicolTestFile)).toBe(true);

    const multicolSource = fs.readFileSync(multicolTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "fieldset_multicol_ignores_first_break_before_column_after_legend"',
      'test "multicol_break_inside_avoid_keeps_block_unfragmented"',
      'test "wpt_column_scroll_marker_004_fieldset_multicol_fragments"',
    ] as const;

    expect(migratedTests.every((marker) => multicolSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer grid regression tests in their own file", () => {
    const gridTestFile = path.join(REPO_ROOT, "renderer/renderer/grid_render_test.mbt");
    expect(fs.existsSync(gridTestFile)).toBe(true);

    const gridSource = fs.readFileSync(gridTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "grid_named_layout_lines_place_item_to_extended_full_end"',
      'test "renderer_grid_column"',
      'test "wpt_grid_container_as_flex_item_reflows_to_final_width"',
    ] as const;

    expect(migratedTests.every((marker) => gridSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer flex regression tests in their own file", () => {
    const flexTestFile = path.join(REPO_ROOT, "renderer/renderer/flex_render_test.mbt");
    expect(fs.existsSync(flexTestFile)).toBe(true);

    const flexSource = fs.readFileSync(flexTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "stylesheet flex-direction is applied"',
      'test "wpt_gap_rtl_direction_inheritance_for_flex"',
      'test "wpt_flex_item_min_width_min_content_like"',
    ] as const;

    expect(migratedTests.every((marker) => flexSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer ruby regression tests in their own file", () => {
    const rubyTestFile = path.join(REPO_ROOT, "renderer/renderer/ruby_render_test.mbt");
    expect(fs.existsSync(rubyTestFile)).toBe(true);

    const rubySource = fs.readFileSync(rubyTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "rt_ua_default_font_size_is_half_of_parent"',
      'test "ruby_internal_elements_default_to_inline_display"',
      'test "ruby_rt_with_non_text_child_keeps_annotation_band_above_base"',
    ] as const;

    expect(migratedTests.every((marker) => rubySource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer containment regression tests in their own file", () => {
    const containmentTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/containment_render_test.mbt",
    );
    expect(fs.existsSync(containmentTestFile)).toBe(true);

    const containmentSource = fs.readFileSync(containmentTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "contain_size_svg_leaf_collapses_to_border_box"',
      'test "contain_inline_size_uses_contain_intrinsic_inline_size_fallback"',
      'test "contain_inline_size_fieldset_uses_ua_defaults_and_legend_overlay"',
      'test "contain_inline_size_legend_respects_fieldset_ua_defaults"',
      'test "contain_size_fieldset_uses_empty_intrinsic_width"',
      'test "contain_paint_clip_abs_descendants_keep_outer_padding_box_reference"',
      'test "wpt_contain_layout_ifc_002_inline_block_keeps_vertical_margins"',
      'test "contain_layout_br_keeps_browser_like_baseline_offset"',
    ] as const;

    expect(migratedTests.every((marker) => containmentSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer inline text regression tests in their own file", () => {
    const inlineTextTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/inline_text_render_test.mbt",
    );
    expect(fs.existsSync(inlineTextTestFile)).toBe(true);

    const inlineTextSource = fs.readFileSync(inlineTextTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "empty_inline_custom_element_between_blocks_does_not_add_line_box"',
      'test "text_overflow_ellipsis_truncates_direct_text_in_paint_tree"',
      'test "inline_text_and_span_without_space_stay_on_same_line"',
      'test "letter_spacing_applied_to_text_measure"',
    ] as const;

    expect(migratedTests.every((marker) => inlineTextSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer root and body sizing regression tests in their own file", () => {
    const rootBodyTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/root_body_render_test.mbt",
    );
    expect(fs.existsSync(rootBodyTestFile)).toBe(true);

    const rootBodySource = fs.readFileSync(rootBodyTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "body_explicit_height_is_not_forced_to_viewport"',
      'test "body_auto_height_follows_content_not_viewport"',
      'test "empty_body_root_with_html_viewport_styles_keeps_viewport_height"',
      'test "frameset_root_without_content_keeps_viewport_height"',
      'test "body child percent height stays auto when body height is indefinite"',
    ] as const;

    expect(migratedTests.every((marker) => rootBodySource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer writing mode regression tests in their own file", () => {
    const writingModeTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/writing_mode_render_test.mbt",
    );
    expect(fs.existsSync(writingModeTestFile)).toBe(true);

    const writingModeSource = fs.readFileSync(writingModeTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "orthogonal_block_auto_margin_centers_in_vertical_parent"',
      'test "vertical_text_block_wraps_to_available_height"',
      'test "wpt_logical_float_vertical_rl_auto_width_shift_keeps_float_positions"',
    ] as const;

    expect(migratedTests.every((marker) => writingModeSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer style cascade regression tests in their own file", () => {
    const styleCascadeTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/style_cascade_render_test.mbt",
    );
    expect(fs.existsSync(styleCascadeTestFile)).toBe(true);

    const styleCascadeSource = fs.readFileSync(styleCascadeTestFile, "utf8");
    const sourceFiles = [
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
    ];
    const sourceText = sourceFiles.map((file) => fs.readFileSync(file, "utf8")).join("\n");
    const migratedTests = [
      'test "color_scheme_dark_resolves_light_dark_background"',
      'test "css_variable_dark_toggle_inherits_from_root"',
      'test "double_hyphen_class_selector_matches"',
      'test "ua_text_decoration_applies_to_semantic_inline_tags"',
      'test "link_color_overridden_by_css"',
      'test "link default color is blue"',
      'test "ua_list_defaults_use_block_margin_and_inline_start_padding"',
    ] as const;

    expect(migratedTests.every((marker) => styleCascadeSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => sourceText.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer overflow and scroll regression tests in their own file", () => {
    const overflowScrollTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/overflow_scroll_render_test.mbt",
    );
    expect(fs.existsSync(overflowScrollTestFile)).toBe(true);

    const overflowScrollSource = fs.readFileSync(overflowScrollTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "mixed_block_parent_ignores_overflowing_descendants_of_fixed_height_child"',
      'test "scroll_snap_center_applies_initial_horizontal_offset"',
    ] as const;

    expect(migratedTests.every((marker) => overflowScrollSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer intrinsic sizing regression tests in their own file", () => {
    const sizingTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/sizing_render_test.mbt",
    );
    expect(fs.existsSync(sizingTestFile)).toBe(true);

    const sizingSource = fs.readFileSync(sizingTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "wpt_intrinsic_percent_non_replaced_calc_mixed_static_layout"',
      'test "wpt_margin_collapse_indefinite_block_size_005_like_stretch_behaves_as_auto"',
      'test "wpt_min_content_le_max_content_zero_font_whitespace_has_zero_advance"',
    ] as const;

    expect(migratedTests.every((marker) => sizingSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer public render API contract tests in their own file", () => {
    const renderApiTestFile = path.join(REPO_ROOT, "renderer/renderer/render_api_test.mbt");
    expect(fs.existsSync(renderApiTestFile)).toBe(true);

    const renderApiSource = fs.readFileSync(renderApiTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "layout_to_json serializes box model fields without changing schema"',
      'test "render_to_node_and_layout_with_external_css is stable across repeated calls"',
      'test "prepared external css renders same layout as css array path"',
      'test "shared node_and_layout render matches separate passes"',
    ] as const;

    expect(migratedTests.every((marker) => renderApiSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer style resolution tests in their own file", () => {
    const styleResolutionTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/style_resolution_test.mbt",
    );
    expect(fs.existsSync(styleResolutionTestFile)).toBe(true);

    const styleResolutionSource = fs.readFileSync(styleResolutionTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "debug node style from stylesheet"',
      'test "debug stylesheet cascading"',
      'test "stylesheet margin-trim is applied"',
      'test "render_to_node applies margin-trim from stylesheet"',
      'test "font-size cascading from stylesheet"',
      'test "render_to_node resolves inline custom properties in gradient background"',
      'test "render_to_node resolves stylesheet custom properties in gradient background"',
      'test "font-size with nested selectors like WPT"',
    ] as const;

    expect(migratedTests.every((marker) => styleResolutionSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer font inheritance regression tests in their own file", () => {
    const fontInheritanceTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/font_inheritance_regression_test.mbt",
    );
    expect(fs.existsSync(fontInheritanceTestFile)).toBe(true);

    const fontInheritanceSource = fs.readFileSync(fontInheritanceTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "font-size inheritance in full render"',
      'test "font shorthand inherits line-height to descendant text nodes"',
      'test "font-family and spacing inherit to descendant text nodes"',
      'test "body defaults descendant text nodes to serif font-family"',
      'test "later font shorthand overrides earlier reset longhands in computed style"',
    ] as const;

    expect(migratedTests.every((marker) => fontInheritanceSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer metrics provider regression tests in their own file", () => {
    const metricsProviderTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/metrics_provider_test.mbt",
    );
    expect(fs.existsSync(metricsProviderTestFile)).toBe(true);

    const metricsProviderSource = fs.readFileSync(metricsProviderTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "custom text metrics provider overrides text measurement"',
      'test "clear text metrics provider restores default text measurement"',
      'test "text metrics provider affects default text input intrinsic width"',
      'test "builtin text advance ratio override affects boundary whitespace text width"',
      'test "custom image intrinsic size provider overrides unresolved src size"',
      'test "clear image intrinsic size provider restores default unresolved src size"',
    ] as const;

    expect(migratedTests.every((marker) => metricsProviderSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer style property regression tests in their own file", () => {
    const stylePropertyTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/style_property_render_test.mbt",
    );
    expect(fs.existsSync(stylePropertyTestFile)).toBe(true);

    const stylePropertySource = fs.readFileSync(stylePropertyTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "html_max_width_constrains_body_layout_width"',
      'test "inline style min-height does not set height"',
      'test "repeated inline styles do not reuse default cache across inherited font sizes"',
      'test "logical properties inline-size and block-size"',
      'test "visually hidden element should be skipped"',
    ] as const;

    expect(migratedTests.every((marker) => stylePropertySource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer content flow regression tests in their own file", () => {
    const contentFlowTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/content_flow_render_test.mbt",
    );
    expect(fs.existsSync(contentFlowTestFile)).toBe(true);

    const contentFlowSource = fs.readFileSync(contentFlowTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "debug_text_wrapping_in_narrow_container"',
      'test "debug_mixed_inline_block_content"',
      'test "debug_heading_text_rendering"',
      'test "debug_inline_text_with_block_sibling"',
      'test "tall_content_scrollability"',
    ] as const;

    expect(migratedTests.every((marker) => contentFlowSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps renderer CSS selector and media regression tests in their own file", () => {
    const selectorTestFile = path.join(
      REPO_ROOT,
      "renderer/renderer/css_selector_render_test.mbt",
    );
    expect(fs.existsSync(selectorTestFile)).toBe(true);

    const selectorSource = fs.readFileSync(selectorTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "CSS :not() hides sidebar when body lacks class"',
      'test "CSS :not() does NOT hide sidebar when body has class"',
      'test "CSS class on html element affects body descendants via cascade"',
      'test "CSS @media print rules do not apply in screen context"',
      'test "style media attribute max-width rules do not leak at desktop viewport"',
      'test "CSS descendant selector from html class hides nested element"',
      'test "CSS 3-level descendant from html class - Wikipedia sidebar pattern"',
      'test "Wikipedia CSS: @media print rules have media_query"',
      'test "Wikipedia actual @media print block does not leak to screen"',
    ] as const;

    expect(migratedTests.every((marker) => selectorSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser JS runtime regression tests in their own file", () => {
    const runtimeTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_runtime_wbtest.mbt");
    expect(fs.existsSync(runtimeTestFile)).toBe(true);

    const runtimeSource = fs.readFileSync(runtimeTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "extract_scripts extracts inline script"',
      'test "Browser init_js_execution creates DOM tree"',
      'test "Browser execute_scripts runs inline scripts"',
      'test "WPT-style: createElement and appendChild"',
      'test "Browser tick_js applies queued JS tasks to render output"',
    ] as const;

    expect(migratedTests.every((marker) => runtimeSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser JS interaction regression tests in their own file", () => {
    const interactionTestFile = path.join(
      REPO_ROOT,
      "browser/shell/browser_js_interaction_wbtest.mbt",
    );
    expect(fs.existsSync(interactionTestFile)).toBe(true);

    const interactionSource = fs.readFileSync(interactionTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const migratedTests = [
      'async test "Browser activate_focused_link dispatches onclick and repaints"',
      'async test "Browser activate_at prefers topmost overlapping painted element"',
      'async test "Browser pointer drag dispatches drag sequence between source and target"',
      'async test "Browser activate_at prefers topmost persisted addEventListener element"',
    ] as const;

    expect(migratedTests.every((marker) => interactionSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps browser JS navigation and form regression tests in their own file", () => {
    const navigationTestFile = path.join(
      REPO_ROOT,
      "browser/shell/browser_js_navigation_wbtest.mbt",
    );
    expect(fs.existsSync(navigationTestFile)).toBe(true);

    const navigationSource = fs.readFileSync(navigationTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const migratedTests = [
      'async test "Browser activate_at submits GET form and navigates"',
      'test "Browser execute_inline_js form.requestSubmit preserves post body metadata"',
      'async test "Browser execute_inline_js_async requestSubmit posts body to external fetch"',
      'async test "Browser activate_focused_link submits focused button form"',
      'async test "Browser execute_inline_js setRangeText updates focused text input"',
    ] as const;

    expect(migratedTests.every((marker) => navigationSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps remaining browser JS render, shadow DOM, and focus tests split by domain", () => {
    const renderTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_render_wbtest.mbt");
    const shadowTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_shadow_wbtest.mbt");
    const focusTestFile = path.join(REPO_ROOT, "browser/shell/browser_js_focus_wbtest.mbt");
    expect(fs.existsSync(renderTestFile)).toBe(true);
    expect(fs.existsSync(shadowTestFile)).toBe(true);
    expect(fs.existsSync(focusTestFile)).toBe(true);

    const renderSource = fs.readFileSync(renderTestFile, "utf8");
    const shadowSource = fs.readFileSync(shadowTestFile, "utf8");
    const focusSource = fs.readFileSync(focusTestFile, "utf8");
    const browserJsSource = fs.readFileSync(
      path.join(REPO_ROOT, "browser/shell/browser_js_wbtest.mbt"),
      "utf8",
    );
    const renderTests = [
      'test "Browser getter API returns initial state"',
      'test "kitty render overlays cached image data for img src regions"',
      'test "sixel render composites cached data png image for img src"',
    ] as const;
    const shadowTests = [
      'async test "Browser sync_render_state_from_dom_tree renders shadow root composed content"',
      'test "Browser render_output normalizes declarative shadow DOM from initial HTML"',
      'async test "Browser sync_render_state_from_dom_tree renders distributed slot content"',
    ] as const;
    const focusTests = [
      'async test "Browser handle_focused_key dispatches change event for focused text input on Enter"',
      'async test "Browser pointer drag selects text in focused input before typing"',
      'async test "Browser activate_at resets form controls for reset button"',
    ] as const;
    const migratedTests = [...renderTests, ...shadowTests, ...focusTests] as const;

    expect(renderTests.every((marker) => renderSource.includes(marker))).toBe(true);
    expect(shadowTests.every((marker) => shadowSource.includes(marker))).toBe(true);
    expect(focusTests.every((marker) => focusSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => browserJsSource.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver BiDi protocol regression tests split by command domain", () => {
    const sourceFile = path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_wbtest.mbt");
    const splitFiles = [
      {
        file: "webdriver/webdriver/bidi_protocol_session_context_wbtest.mbt",
        markers: [
          'test "bidi session status"',
          'test "bidi browsingContext create emits events before response"',
          'test "bidi browsingContext getCurrentUrlValue rejects invalid context type"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_fixture_wbtest.mbt",
        markers: [
          'test "bidi script getElementForTest returns first matching node"',
          'test "bidi script prepareLoadedStaticTestPage dispatches DOMContentLoaded and resets allEvents"',
          'test "bidi session isSubscribedForContext follows parent context subscriptions"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_prompt_subscription_wbtest.mbt",
        markers: [
          'test "bidi browsingContext close promptUnload waits for handleUserPrompt"',
          'test "bidi session subscribe returns subscription id"',
          'test "bidi browser setDownloadBehavior accepts user_contexts alias"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_input_wbtest.mbt",
        markers: [
          'test "bidi input performActions validates context type"',
          'test "bidi input pointer drag actions emit drag sequence"',
          'test "bidi input setFiles accepts files alias and derives display name"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_preload_realm_wbtest.mbt",
        markers: [
          'test "bidi script removeAllPreloadScripts clears future contexts"',
          'test "bidi script addPreloadScript accepts snake_case aliases"',
          'test "bidi script getRealmsList returns raw realms array"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_navigation_state_wbtest.mbt",
        markers: [
          'test "bidi browsingContext prepareNavigate reuses blocked navigation preparation"',
          'test "bidi browsingContext navigateWithState defers blocked synthetic request"',
          'test "bidi browsingContext closeWithState reports waitForDestroyed before closing"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_script_eval_wbtest.mbt",
        markers: [
          'test "bidi script evaluate validates snake_case serializationOptions aliases"',
          'test "bidi script evaluateResult keeps exceptionDetails payload"',
          'test "bidi script callFunctionResult unwraps synthetic document focus state"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_extended_domains_wbtest.mbt",
        markers: [
          'test "bidi permissions setPermission validates descriptor type"',
          'test "bidi bluetooth requestDevice emits prompt event and resolves on accept"',
          'test "bidi emulation setScreenSettingsOverride updates runtime screen metrics and matchMedia"',
        ],
      },
    ] as const;

    const source = fs.readFileSync(sourceFile, "utf8");
    const migratedTests = splitFiles.flatMap(({ markers }) => markers);
    for (const { file, markers } of splitFiles) {
      const targetFile = path.join(REPO_ROOT, file);
      expect(fs.existsSync(targetFile)).toBe(true);
      const targetSource = fs.readFileSync(targetFile, "utf8");
      expect(markers.every((marker) => targetSource.includes(marker))).toBe(true);
    }
    const offenders = migratedTests.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("delegates SVG viewBox transform math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/viewbox.mbt"), "utf8");

    expect(source.includes("pub(all) struct ViewBox")).toBe(true);
    expect(source.includes("pub(all) struct PreserveAspectRatio")).toBe(true);
    expect(source.includes("pub fn ViewBox::get_transform(")).toBe(true);
    expect(source.includes("@msvg.ViewBox::")).toBe(true);
    expect(source.includes("fn get_alignment_factors(")).toBe(false);
    expect(typesSource.includes("pub(all) struct ViewBox")).toBe(false);
    expect(typesSource.includes("pub(all) struct PreserveAspectRatio")).toBe(false);
  });

  it("delegates SVG gradient color interpolation to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/gradient.mbt"), "utf8");

    expect(source.includes("pub(all) struct GradientStop")).toBe(true);
    expect(source.includes("pub(all) struct LinearGradient")).toBe(true);
    expect(source.includes("pub(all) struct RadialGradient")).toBe(true);
    expect(source.includes("pub(all) enum SpreadMethod")).toBe(true);
    expect(source.includes("@msvg.LinearGradient::new(")).toBe(true);
    expect(source.includes("@msvg.LinearGradient::horizontal(")).toBe(true);
    expect(source.includes("@msvg.LinearGradient::vertical(")).toBe(true);
    expect(source.includes("linear_gradient_from_msvg(")).toBe(true);
    expect(source.includes("pub fn LinearGradient::color_at(")).toBe(true);
    expect(source.includes("@msvg.RadialGradient::new(")).toBe(true);
    expect(source.includes("radial_gradient_from_msvg(")).toBe(true);
    expect(source.includes("pub fn RadialGradient::color_at(")).toBe(true);
    expect(source.includes("linear_gradient_to_msvg(self).color_at(")).toBe(true);
    expect(source.includes("radial_gradient_to_msvg(self).color_at(")).toBe(true);
    expect(source.includes("fn apply_spread(")).toBe(false);
    expect(source.includes("fn interpolate_gradient_color(")).toBe(false);
    expect(typesSource.includes("pub(all) struct LinearGradient")).toBe(false);
    expect(typesSource.includes("pub(all) struct RadialGradient")).toBe(false);
  });

  it("delegates SVG path rasterization to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/path.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("@msvg.parse_path(data)")).toBe(true);
    expect(source.includes("@msvg.path_to_polylines(")).toBe(true);
    expect(source.includes("@msvg.raster_path(")).toBe(true);
    expect(source.includes("@msvg.path_bbox(")).toBe(true);
    expect(interopSource.includes("fn path_commands_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn pixel_setter_to_msvg(")).toBe(true);
    expect(source.includes("let polylines = path_to_polylines(commands, flatness)")).toBe(false);
    expect(source.includes("raster_polygon_fill(int_points, color, setter)")).toBe(false);
  });

  it("delegates SVG pixel setter clipping to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/raster.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pixel_setter_from_msvg(")).toBe(true);
    expect(source.includes("pixel_setter_to_msvg(self).with_clip(")).toBe(true);
    expect(source.includes("pixel_setter_to_msvg(self).with_clip_and_offset(")).toBe(true);
    expect(interopSource.includes("fn pixel_setter_from_msvg(")).toBe(true);
    expect(source.includes("if clip.contains(")).toBe(false);
  });

  it("delegates SVG pointer event state to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/event.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("@msvg.PointerEvent::new(")).toBe(true);
    expect(source.includes("pointer_event_from_msvg(")).toBe(true);
    expect(source.includes("pointer_event_to_msvg(self)")).toBe(true);
    expect(source.includes("event.stop_propagation()")).toBe(true);
    expect(interopSource.includes("fn pointer_event_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn pointer_event_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_pointer_event_state_from_msvg(")).toBe(true);
    expect(source.includes("self.propagation_stopped = true")).toBe(false);
  });

  it("delegates SVG text whitespace helpers to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/text.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) enum WhiteSpace")).toBe(true);
    expect(source.includes("pub(all) enum TextOverflow")).toBe(true);
    expect(source.includes("@msvg.process_white_space(")).toBe(true);
    expect(source.includes("@msvg.apply_text_overflow(")).toBe(true);
    expect(source.includes("white_space_to_msvg(mode)")).toBe(true);
    expect(source.includes("text_overflow_to_msvg(overflow)")).toBe(true);
    expect(interopSource.includes("fn white_space_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn text_overflow_to_msvg(")).toBe(true);
    expect(source.includes("fn take_chars(")).toBe(false);
    expect(typesSource.includes("pub(all) enum WhiteSpace")).toBe(false);
    expect(typesSource.includes("pub fn process_white_space(")).toBe(false);
  });

  it("delegates SVG text blocks to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/text.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct TextStyle")).toBe(true);
    expect(source.includes("pub(all) struct TextSpan")).toBe(true);
    expect(source.includes("pub(all) struct TextBlock")).toBe(true);
    expect(source.includes("@msvg.TextDecorationFull::default()")).toBe(true);
    expect(source.includes("text_style_from_msvg(@msvg.TextStyle::default())")).toBe(true);
    expect(source.includes("text_span_from_msvg(@msvg.TextSpan::new(text))")).toBe(true);
    expect(source.includes("text_block_from_msvg(@msvg.TextBlock::new(")).toBe(true);
    expect(source.includes("text_block_to_msvg(self).get_width()")).toBe(true);
    expect(source.includes("text_block_to_msvg(self).wrap_text()")).toBe(true);
    expect(interopSource.includes("fn text_style_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn text_block_to_msvg(")).toBe(true);
    expect(source.includes("fn split_words(")).toBe(false);
    expect(typesSource.includes("pub(all) struct TextBlock")).toBe(false);
    expect(typesSource.includes("pub fn TextBlock::new(")).toBe(false);
  });

  it("delegates SVG use element helpers to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/use_symbol.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const instantiateStart = source.indexOf("pub fn UseElement::instantiate(");
    const instantiateEnd = source.length;
    const instantiateSource = source.slice(instantiateStart, instantiateEnd);

    expect(source.includes("pub(all) struct UseElement")).toBe(true);
    expect(source.includes("@msvg.UseElement::new(")).toBe(true);
    expect(source.includes("@msvg.UseElement::with_size(")).toBe(true);
    expect(source.includes("use_element_from_msvg(")).toBe(true);
    expect(source.includes("use_element_to_msvg(self).get_id()")).toBe(true);
    expect(instantiateSource.includes("use_element_to_msvg(self).instantiate(symbol_registry_to_msvg(registry))")).toBe(true);
    expect(interopSource.includes("fn use_element_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn use_element_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn symbol_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn symbol_registry_to_msvg(")).toBe(true);
    expect(source.includes("fn hex_value(")).toBe(false);
    expect(source.includes("fn decode_percent(")).toBe(false);
    expect(instantiateSource.includes("registry.get(id)")).toBe(false);
    expect(instantiateSource.includes("symbol.content.clone()")).toBe(false);
    expect(typesSource.includes("pub(all) struct UseElement")).toBe(false);
    expect(typesSource.includes("pub fn UseElement::new(")).toBe(false);
  });

  it("delegates SVG symbol constructors to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/use_symbol.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Symbol")).toBe(true);
    expect(source.includes("pub(all) struct SymbolRegistry")).toBe(true);
    expect(source.includes("@msvg.Symbol::new(")).toBe(true);
    expect(source.includes("@msvg.Symbol::with_viewbox(")).toBe(true);
    expect(source.includes("symbol_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn symbol_from_msvg(")).toBe(true);
    expect(source.includes("view_box: None,\n    preserve_aspect_ratio: PreserveAspectRatio::default(),")).toBe(false);
    expect(typesSource.includes("pub(all) struct Symbol")).toBe(false);
    expect(typesSource.includes("pub fn Symbol::new(")).toBe(false);
  });

  it("delegates SVG node cloning to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/node.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct SVGNode")).toBe(true);
    expect(source.includes("svg_node_from_msvg(svg_node_to_msvg(self).clone())")).toBe(true);
    expect(interopSource.includes("fn svg_node_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn svg_node_from_msvg(")).toBe(true);
    expect(source.includes("let children : Array[SVGNode] = []")).toBe(false);
    expect(source.includes("let filters : Array[Filter] = []")).toBe(false);
    expect(typesSource.includes("pub(all) struct SVGNode")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::clone(")).toBe(false);
  });

  it("keeps SVG event system in a dedicated module", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const eventSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/event.mbt"), "utf8");

    expect(eventSource.includes("pub(all) struct PointerEvent")).toBe(true);
    expect(eventSource.includes("pub(all) struct EventManager")).toBe(true);
    expect(eventSource.includes("pub fn EventManager::dispatch_click(")).toBe(true);
    expect(eventSource.includes("fn EventManager::dispatch_to_node(")).toBe(true);
    expect(typesSource.includes("pub(all) struct EventManager")).toBe(false);
    expect(typesSource.includes("fn EventManager::dispatch_to_node(")).toBe(false);
  });

  it("delegates SVG color and stroke defaults to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const colorSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/color.mbt"), "utf8");
    const paintSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/paint.mbt"), "utf8");

    expect(colorSource.includes("pub(all) struct Color")).toBe(true);
    expect(colorSource.includes("@msvg.Color::rgb(")).toBe(true);
    expect(colorSource.includes("@msvg.Color::rgba(")).toBe(true);
    expect(colorSource.includes("@msvg.Color::transparent()")).toBe(true);
    expect(colorSource.includes("@msvg.Color::black()")).toBe(true);
    expect(colorSource.includes("@msvg.Color::white()")).toBe(true);
    expect(colorSource.includes("color_to_msvg(self).is_transparent()")).toBe(true);
    expect(paintSource.includes("pub(all) enum Paint")).toBe(true);
    expect(paintSource.includes("pub(all) struct StrokeStyle")).toBe(true);
    expect(paintSource.includes("@msvg.StrokeStyle::default()")).toBe(true);
    expect(typesSource.includes("pub(all) struct Color")).toBe(false);
    expect(typesSource.includes("pub(all) struct StrokeStyle")).toBe(false);
  });

  it("delegates SVG node effect setters to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/node.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const effectStart = source.indexOf("/// Add a filter to the node");
    const effectEnd = source.indexOf("///|\n/// Clone an SVGNode", effectStart);
    const effectSource = source.slice(effectStart, effectEnd);

    expect(effectSource.includes("let node = svg_node_to_msvg(self)")).toBe(true);
    expect(effectSource.includes("node.add_filter(filter_to_msvg(filter))")).toBe(true);
    expect(effectSource.includes("node.clear_filters()")).toBe(true);
    expect(effectSource.includes("node.set_mask(mask_id)")).toBe(true);
    expect(effectSource.includes("node.clear_mask()")).toBe(true);
    expect(effectSource.includes("node.set_clip_path(clip_path_id)")).toBe(true);
    expect(effectSource.includes("node.clear_clip_path()")).toBe(true);
    expect(effectSource.includes("copy_svg_node_effect_state_from_msvg(self, node)")).toBe(true);
    expect(interopSource.includes("fn copy_svg_node_effect_state_from_msvg(")).toBe(true);
    expect(effectSource.includes("self.filters.push(")).toBe(false);
    expect(effectSource.includes("self.filters.clear()")).toBe(false);
    expect(effectSource.includes("self.mask_id =")).toBe(false);
    expect(effectSource.includes("self.clip_path_id =")).toBe(false);
    expect(effectSource.includes("self.node_dirty =")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::add_filter(")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::set_mask(")).toBe(false);
  });

  it("delegates SVG transform operations to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/transform.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");

    expect(source.includes("pub(all) struct Transform")).toBe(true);
    expect(source.includes("@msvg.Transform::")).toBe(true);
    expect(source.includes("@msvg.Transform::matrix(")).toBe(true);
    expect(source.includes("@math.cos")).toBe(false);
    expect(source.includes("@math.tan")).toBe(false);
    expect(source.includes("@math.atan2")).toBe(false);
    expect(source.includes("Matrix multiplication:")).toBe(false);
    expect(source.includes("  { a, b, c, d, e, f }")).toBe(false);
    expect(interopSource.includes("Transform::matrix(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Transform")).toBe(false);
  });

  it("delegates SVG scene node factories to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_factory.mbt"), "utf8");
    const factoryStart = source.indexOf("/// Helper: Create a rectangle node");
    const factoryEnd = source.length;
    const factorySource = source.slice(factoryStart, factoryEnd);
    const groupStart = source.indexOf("pub fn group(", factoryStart);
    const groupEnd = source.indexOf("///|", groupStart + 1);
    const groupSource = source.slice(groupStart, groupEnd);

    expect(factorySource.includes("svg_node_from_msvg(@msvg.rect(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.circle(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.line(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.path(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.text(")).toBe(true);
    expect(factorySource.includes("svg_node_from_msvg(@msvg.group(")).toBe(false);
    expect(groupSource.includes("node.children.push(child)")).toBe(true);
    expect(sceneSource.includes("pub fn rect(")).toBe(false);
    expect(sceneSource.includes("pub fn group(")).toBe(false);
  });

  it("delegates SVG scene render entrypoints to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_render.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(source.includes("scene.render(render_context_to_msvg(ctx))")).toBe(true);
    expect(source.includes("scene.render_with_camera(")).toBe(true);
    expect(source.includes("scene.render_with_viewbox(")).toBe(true);
    expect(source.includes("scene.render_with_viewbox_and_camera(")).toBe(true);
    expect(interopSource.includes("fn render_context_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn scene_to_msvg(")).toBe(true);
    expect(source.includes("render_node(self.root, Transform::identity(), ctx)")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::render(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::render_with_camera(")).toBe(false);
  });

  it("delegates SVG render context constructors to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/render_context.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct RenderContext")).toBe(true);
    expect(source.includes("render_context_from_msvg(")).toBe(true);
    expect(source.includes("@msvg.RenderContext::new(")).toBe(true);
    expect(source.includes("@msvg.RenderContext::with_clip(")).toBe(true);
    expect(source.includes("@msvg.RenderContext::for_camera(")).toBe(true);
    expect(interopSource.includes("fn render_context_from_msvg(")).toBe(true);
    expect(source.includes("{ setter, width, height, flatness: 0.5, clip: None }")).toBe(false);
    expect(source.includes("{ setter, width, height, flatness: 0.5, clip: Some(clip) }")).toBe(false);
    expect(source.includes("let clip = ClipRect::from_size(camera.viewport_width, camera.viewport_height)")).toBe(false);
    expect(sceneSource.includes("pub(all) struct RenderContext")).toBe(false);
    expect(sceneSource.includes("pub fn RenderContext::new(")).toBe(false);
  });

  it("delegates SVG scene queries to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_dirty.mbt"), "utf8");

    expect(sceneSource.includes("svg_scene_from_msvg(@msvg.Scene::empty())")).toBe(true);
    expect(source.includes("bounding_box_from_msvg(scene_to_msvg(self).get_bounds())")).toBe(true);
    expect(source.includes("bounding_box_from_msvg(scene_to_msvg(self).get_dirty_region())")).toBe(true);
    expect(source.includes("compute_bounds(self.root, Transform::identity())")).toBe(false);
    expect(source.includes("compute_dirty_region(self.root, Transform::identity())")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::get_bounds(")).toBe(false);
  });

  it("delegates SVG dirty rendering to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_dirty.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const renderDirtyStart = source.indexOf("pub fn Scene::render_dirty(");
    const renderDirtyEnd = source.indexOf("///|\n/// Mark a node", renderDirtyStart);
    const renderDirtySource = source.slice(renderDirtyStart, renderDirtyEnd);

    expect(renderDirtySource.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(renderDirtySource.includes("scene.render_dirty(render_context_to_msvg(ctx))")).toBe(true);
    expect(renderDirtySource.includes("copy_svg_scene_dirty_state_from_msvg(self, scene)")).toBe(true);
    expect(renderDirtySource.includes("RenderContext::with_clip(")).toBe(false);
    expect(source.includes("fn render_and_update_dirty(")).toBe(false);
    expect(source.includes("fn render_node(")).toBe(false);
    expect(source.includes("fn render_rect(")).toBe(false);
    expect(source.includes("fn apply_opacity(")).toBe(false);
    expect(interopSource.includes("fn copy_svg_scene_dirty_state_from_msvg(")).toBe(true);
    expect(sceneSource.includes("pub fn Scene::render_dirty(")).toBe(false);
  });

  it("delegates SVG scene dirty flag operations to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_dirty.mbt"), "utf8");
    const markStart = source.indexOf("pub fn Scene::mark_node_dirty(");
    const markEnd = source.indexOf("///|\n/// Clear all dirty flags", markStart);
    const markSource = source.slice(markStart, markEnd);
    const clearStart = source.indexOf("pub fn Scene::clear_all_dirty(");
    const clearEnd = source.indexOf("///|\n/// Set z_index", clearStart);
    const clearSource = source.slice(clearStart, clearEnd);

    expect(markSource.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(markSource.includes("scene.mark_node_dirty(id)")).toBe(true);
    expect(markSource.includes("copy_svg_scene_dirty_state_from_msvg(self, scene)")).toBe(true);
    expect(clearSource.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(clearSource.includes("scene.clear_all_dirty()")).toBe(true);
    expect(clearSource.includes("copy_svg_scene_dirty_state_from_msvg(self, scene)")).toBe(true);
    expect(source.includes("fn clear_dirty_recursive(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::mark_node_dirty(")).toBe(false);
  });

  it("delegates SVG scene z-index operations to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_z_order.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("scene.set_z_index(id, z_index)")).toBe(true);
    expect(source.includes("scene.bring_to_front(id)")).toBe(true);
    expect(source.includes("scene.send_to_back(id)")).toBe(true);
    expect(source.includes("copy_svg_scene_z_order_state_from_msvg(self, scene)")).toBe(true);
    expect(interopSource.includes("fn copy_svg_scene_z_order_state_from_msvg(")).toBe(true);
    expect(source.includes("fn find_parent_and_node(")).toBe(false);
    expect(source.includes("fn get_max_z_index(")).toBe(false);
    expect(source.includes("fn get_min_z_index(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::set_z_index(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::bring_to_front(")).toBe(false);
  });

  it("isolates SVG scene graph mutation helpers from scene type", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene_graph.mbt"), "utf8");

    expect(source.includes("pub fn Scene::update_node(")).toBe(true);
    expect(source.includes("fn update_node_recursive(")).toBe(true);
    expect(source.includes("pub fn Scene::find_node(")).toBe(true);
    expect(source.includes("fn find_node_recursive(")).toBe(true);
    expect(source.includes("pub fn Scene::add_child(")).toBe(true);
    expect(source.includes("fn add_child_recursive(")).toBe(true);
    expect(source.includes("pub fn Scene::remove_node(")).toBe(true);
    expect(source.includes("fn remove_node_recursive(")).toBe(true);
    expect(sceneSource.includes("pub fn Scene::update_node(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::find_node(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::add_child(")).toBe(false);
    expect(sceneSource.includes("pub fn Scene::remove_node(")).toBe(false);
  });

  it("delegates SVG bounding boxes and clip rects to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/geometry.mbt"), "utf8");

    expect(source.includes("pub(all) struct BoundingBox")).toBe(true);
    expect(source.includes("pub(all) struct ClipRect")).toBe(true);
    expect(source.includes("@msvg.BoundingBox::empty()")).toBe(true);
    expect(source.includes("@msvg.BoundingBox::from_rect(")).toBe(true);
    expect(source.includes("bounding_box_to_msvg(self).width()")).toBe(true);
    expect(source.includes("@msvg.ClipRect::")).toBe(true);
    expect(source.includes("fn min(")).toBe(false);
    expect(source.includes("fn max(")).toBe(false);
    expect(typesSource.includes("pub(all) struct BoundingBox")).toBe(false);
    expect(typesSource.includes("pub fn ClipRect::new(")).toBe(false);
  });

  it("delegates SVG shape hit testing to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const shapeSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/shape.mbt"), "utf8");
    const hitTestSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/hit_testing.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const nodeHitStart = hitTestSource.indexOf("pub fn SVGNode::hit_test(");
    const nodeHitEnd = hitTestSource.indexOf("///|\n/// Find all nodes", nodeHitStart);
    const nodeHitSource = hitTestSource.slice(nodeHitStart, nodeHitEnd);

    expect(shapeSource.includes("pub(all) enum PathCommand")).toBe(true);
    expect(shapeSource.includes("pub(all) enum Shape")).toBe(true);
    expect(shapeSource.includes("pub impl Show for Shape")).toBe(true);
    expect(hitTestSource.includes("pub fn hit_test_shape(")).toBe(true);
    expect(hitTestSource.includes("@msvg.hit_test_shape(px, py, shape_to_msvg(shape))")).toBe(true);
    expect(nodeHitSource.includes("svg_node_to_msvg(self).hit_test(px, py)")).toBe(true);
    expect(nodeHitSource.includes("let inv = self.transform.inverse()")).toBe(false);
    expect(nodeHitSource.includes("hit_test_shape(local_x, local_y, self.shape)")).toBe(false);
    expect(interopSource.includes("fn shape_to_msvg(")).toBe(true);
    expect(hitTestSource.includes("fn hit_test_rect(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_circle(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_ellipse(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_polygon(")).toBe(false);
    expect(hitTestSource.includes("fn hit_test_line(")).toBe(false);
    expect(typesSource.includes("pub(all) enum PathCommand")).toBe(false);
    expect(typesSource.includes("pub(all) enum Shape")).toBe(false);
    expect(typesSource.includes("pub fn hit_test_shape(")).toBe(false);
    expect(typesSource.includes("fn hit_test_recursive(")).toBe(false);
  });

  it("delegates SVG clip paths to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/clip_path.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");
    const containsStart = source.indexOf("pub fn ClipPath::contains(");
    const containsEnd = source.indexOf("///|\n/// Clip path registry", containsStart);
    const containsSource = source.slice(containsStart, containsEnd);

    expect(source.includes("pub(all) struct ClipPath")).toBe(true);
    expect(source.includes("pub(all) struct ClipPathRegistry")).toBe(true);
    expect(source.includes("@msvg.ClipPath::new(")).toBe(true);
    expect(source.includes("clip_path_from_msvg(")).toBe(true);
    expect(source.includes("clip_path_to_msvg(self).contains(x, y)")).toBe(true);
    expect(interopSource.includes("fn clip_path_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn clip_path_to_msvg(")).toBe(true);
    expect(containsSource.includes("let inv = self.transform.inverse()")).toBe(false);
    expect(containsSource.includes("hit_test_shape(cx, cy, self.shape)")).toBe(false);
    expect(typesSource.includes("pub(all) struct ClipPath")).toBe(false);
    expect(typesSource.includes("pub fn ClipPath::new(")).toBe(false);
  });

  it("delegates SVG camera math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/camera.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Camera")).toBe(true);
    expect(source.includes("@msvg.Camera::new(")).toBe(true);
    expect(source.includes("camera_to_msvg(self).get_visible_bounds()")).toBe(true);
    expect(source.includes("camera_to_msvg(self).world_to_screen(")).toBe(true);
    expect(source.includes("camera_to_msvg(self).screen_to_world(")).toBe(true);
    expect(source.includes("camera_to_msvg(self).get_transform()")).toBe(true);
    expect(interopSource.includes("fn camera_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_camera_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn camera_to_msvg(")).toBe(true);
    expect(source.includes("self.x = self.x + dx")).toBe(false);
    expect(source.includes("self.viewport_width.to_double() / 2.0")).toBe(false);
    expect(typesSource.includes("pub(all) struct Camera")).toBe(false);
    expect(typesSource.includes("pub fn Camera::new(")).toBe(false);
  });

  it("delegates SVG color filter math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/filter.mbt"), "utf8");

    expect(source.includes("pub(all) enum Filter")).toBe(true);
    expect(source.includes("@msvg.apply_brightness(")).toBe(true);
    expect(source.includes("@msvg.apply_grayscale(")).toBe(true);
    expect(source.includes("@msvg.apply_contrast(")).toBe(true);
    expect(source.includes("@msvg.apply_sepia(")).toBe(true);
    expect(source.includes("@msvg.apply_hue_rotate(")).toBe(true);
    expect(source.includes("@msvg.apply_invert(")).toBe(true);
    expect(source.includes("@msvg.apply_saturate(")).toBe(true);
    expect(source.includes("@msvg.apply_color_matrix(")).toBe(true);
    expect(source.includes("@msvg.identity_matrix()")).toBe(true);
    expect(source.includes("@msvg.saturate_matrix(")).toBe(true);
    expect(source.includes("@msvg.hue_rotate_matrix(")).toBe(true);
    expect(source.includes("@msvg.luminance_to_alpha_matrix()")).toBe(true);
    expect(source.includes("fn cos_approx(")).toBe(false);
    expect(source.includes("fn sin_approx(")).toBe(false);
    expect(source.includes("Hue rotation matrix")).toBe(false);
    expect(source.includes("Sepia matrix coefficients")).toBe(false);
    expect(typesSource.includes("pub(all) enum Filter")).toBe(false);
    expect(typesSource.includes("pub fn apply_filter(image : Image")).toBe(false);
  });

  it("delegates SVG image and sprite operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/image.mbt"), "utf8");
    const filterSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/filter.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Image")).toBe(true);
    expect(source.includes("pub(all) struct Sprite")).toBe(true);
    expect(source.includes("pub(all) struct SpriteSheet")).toBe(true);
    expect(source.includes("@msvg.Image::new(")).toBe(true);
    expect(source.includes("@msvg.Image::filled(")).toBe(true);
    expect(source.includes("image_to_msvg(self).get_pixel(")).toBe(true);
    expect(source.includes("image_to_msvg(self).clone()")).toBe(true);
    expect(filterSource.includes("@msvg.apply_blur(")).toBe(true);
    expect(filterSource.includes("@msvg.apply_drop_shadow(")).toBe(true);
    expect(filterSource.includes("@msvg.apply_filter(")).toBe(true);
    expect(source.includes("@msvg.blit(")).toBe(true);
    expect(source.includes("@msvg.blit_sprite(")).toBe(true);
    expect(source.includes("@msvg.blit_scaled(")).toBe(true);
    expect(source.includes("image_to_msvg(self).flip_horizontal()")).toBe(true);
    expect(source.includes("image_to_msvg(self).rotate_90_cw()")).toBe(true);
    expect(interopSource.includes("fn copy_image_pixels_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn sprite_to_msvg(")).toBe(true);
    expect(source.includes("Box blur")).toBe(false);
    expect(source.includes("Alpha blend foreground over background")).toBe(false);
    expect(source.includes("Nearest-neighbor sampling")).toBe(false);
    expect(source.includes("fn blend_colors(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Image")).toBe(false);
    expect(typesSource.includes("pub fn Image::new(")).toBe(false);
  });

  it("delegates SVG animated sprite operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/image.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct AnimatedSprite")).toBe(true);
    expect(source.includes("@msvg.AnimatedSprite::new(")).toBe(true);
    expect(source.includes("@msvg.AnimatedSprite::from_range(")).toBe(true);
    expect(source.includes("animated_sprite_to_msvg(self).get_current_sprite()")).toBe(true);
    expect(source.includes("let sprite = animated_sprite_to_msvg(self)")).toBe(true);
    expect(source.includes("sprite.update(dt)")).toBe(true);
    expect(interopSource.includes("fn animated_sprite_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_animated_sprite_state_from_msvg(")).toBe(true);
    expect(source.includes("while self.elapsed >= self.frame_duration")).toBe(false);
    expect(source.includes("self.current_frame = self.current_frame + 1")).toBe(false);
    expect(typesSource.includes("pub(all) struct AnimatedSprite")).toBe(false);
  });

  it("delegates SVG particle operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/particle.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Particle")).toBe(true);
    expect(source.includes("pub(all) struct ParticleEmitter")).toBe(true);
    expect(source.includes("pub(all) struct SimpleRNG")).toBe(true);
    expect(source.includes("@msvg.Particle::new(")).toBe(true);
    expect(source.includes("@msvg.EmitterConfig::default(")).toBe(true);
    expect(source.includes("@msvg.ParticleEmitter::new(")).toBe(true);
    expect(source.includes("particle_emitter_to_msvg(self)")).toBe(true);
    expect(source.includes("emitter.update(dt)")).toBe(true);
    expect(source.includes("particle_emitter_to_msvg(self).active_count()")).toBe(true);
    expect(interopSource.includes("fn particle_emitter_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_particle_emitter_state_from_msvg(")).toBe(true);
    expect(source.includes("fn ParticleEmitter::emit_one(")).toBe(false);
    expect(source.includes("fn random_range(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Particle")).toBe(false);
    expect(typesSource.includes("pub fn ParticleEmitter::new(")).toBe(false);
  });

  it("delegates SVG path follower operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/path_animation.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct PathFollower")).toBe(true);
    expect(source.includes("@msvg.PathFollower::new(")).toBe(true);
    expect(source.includes("path_follower_to_msvg(self).get_position()")).toBe(true);
    expect(source.includes("let follower = path_follower_to_msvg(self)")).toBe(true);
    expect(source.includes("follower.update(dt, speed)")).toBe(true);
    expect(interopSource.includes("fn path_follower_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_path_follower_state_from_msvg(")).toBe(true);
    expect(source.includes("fn flatten_path(")).toBe(false);
    expect(source.includes("fn compute_path_lengths(")).toBe(false);
    expect(typesSource.includes("pub(all) struct PathFollower")).toBe(false);
    expect(typesSource.includes("pub fn PathFollower::new(")).toBe(false);
  });

  it("delegates SVG tween operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/tween.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) enum Easing")).toBe(true);
    expect(source.includes("pub(all) enum AnimProperty")).toBe(true);
    expect(source.includes("pub(all) struct Tween")).toBe(true);
    expect(source.includes("@msvg.Tween::new(")).toBe(true);
    expect(source.includes("tween_to_msvg(self).is_complete()")).toBe(true);
    expect(source.includes("let tween = tween_to_msvg(self)")).toBe(true);
    expect(source.includes("tween.update(dt, msvg_node)")).toBe(true);
    expect(interopSource.includes("fn easing_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn tween_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_tween_state_from_msvg(")).toBe(true);
    expect(source.includes("fn capture_property(")).toBe(false);
    expect(source.includes("fn apply_interpolated_property(")).toBe(false);
    expect(source.includes("fn lerp_color(")).toBe(false);
    expect(typesSource.includes("pub(all) struct Tween")).toBe(false);
    expect(typesSource.includes("pub fn Tween::new(")).toBe(false);
  });

  it("delegates SVG animation manager operations to mizchi/svg", () => {
    const sceneSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/animation_manager.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct AnimationManager")).toBe(true);
    expect(source.includes("animation_manager_from_msvg(@msvg.AnimationManager::new())")).toBe(true);
    expect(source.includes("let manager = animation_manager_to_msvg(self)")).toBe(true);
    expect(source.includes("manager.animate_translate(")).toBe(true);
    expect(source.includes("manager.animate_opacity(")).toBe(true);
    expect(source.includes("manager.animate_scale(")).toBe(true);
    expect(source.includes("manager.update(dt, msvg_scene)")).toBe(true);
    expect(source.includes("manager.cleanup()")).toBe(true);
    expect(source.includes("animation_manager_to_msvg(self).is_animating()")).toBe(true);
    expect(source.includes("manager.clear()")).toBe(true);
    expect(interopSource.includes("fn animation_manager_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn animation_manager_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_animation_manager_state_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn copy_svg_scene_animation_state_from_msvg(")).toBe(true);
    expect(source.includes("for tween in self.tweens")).toBe(false);
    expect(source.includes("Remove completed tweens")).toBe(false);
    expect(source.includes("self.tweens.clear()")).toBe(false);
    expect(sceneSource.includes("pub(all) struct AnimationManager")).toBe(false);
    expect(sceneSource.includes("pub fn AnimationManager::new(")).toBe(false);
  });

  it("delegates SVG collision operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/collision.mbt"), "utf8");

    expect(source.includes("@msvg.collide_circle_circle(")).toBe(true);
    expect(source.includes("@msvg.collide_rect_rect(")).toBe(true);
    expect(source.includes("@msvg.collide_circle_rect(")).toBe(true);
    expect(source.includes("@msvg.collide_shapes(shape_to_msvg(shape1), shape_to_msvg(shape2))")).toBe(true);
    expect(source.includes("svg_node_to_msvg(self).collides_with(svg_node_to_msvg(other))")).toBe(true);
    expect(source.includes("fn get_shape_bbox(")).toBe(false);
    expect(source.includes("Fall back to bounding box collision")).toBe(false);
    expect(typesSource.includes("pub fn collide_circle_circle(")).toBe(false);
    expect(typesSource.includes("pub fn SVGNode::collides_with(")).toBe(false);
  });

  it("delegates SVG object pool operations to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/object_pool.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("@msvg.ObjectPool::new(")).toBe(true);
    expect(source.includes("object_pool_from_msvg(")).toBe(true);
    expect(source.includes("object_pool_to_msvg(self).acquire()")).toBe(true);
    expect(source.includes("object_pool_to_msvg(self).release(obj)")).toBe(true);
    expect(source.includes("object_pool_to_msvg(self).available_count()")).toBe(true);
    expect(interopSource.includes("fn[T] object_pool_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn[T] object_pool_to_msvg(")).toBe(true);
    expect(source.includes("self.available.pop().unwrap()")).toBe(false);
    expect(typesSource.includes("pub(all) struct ObjectPool")).toBe(false);
    expect(typesSource.includes("pub fn[T] ObjectPool::new(")).toBe(false);
  });

  it("delegates SVG blend mode math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/blend.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) enum BlendMode")).toBe(true);
    expect(source.includes("pub(all) enum Isolation")).toBe(true);
    expect(source.includes("@msvg.blend_with_mode(")).toBe(true);
    expect(source.includes("@msvg.blend_images(")).toBe(true);
    expect(interopSource.includes("fn blend_mode_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn image_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn image_from_msvg(")).toBe(true);
    expect(source.includes("fn blend_overlay_channel(")).toBe(false);
    expect(source.includes("fn blend_color_dodge_channel(")).toBe(false);
    expect(source.includes("fn blend_color_burn_channel(")).toBe(false);
    expect(source.includes("fn blend_soft_light_channel(")).toBe(false);
    expect(source.includes("fn rgb_to_hsl(")).toBe(false);
    expect(source.includes("fn hsl_to_rgb(")).toBe(false);
    expect(source.includes("fn sqrt_approx(")).toBe(false);
    expect(typesSource.includes("pub(all) enum BlendMode")).toBe(false);
    expect(typesSource.includes("pub fn blend_images(")).toBe(false);
  });

  it("delegates SVG mask math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/mask.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) enum MaskUnits")).toBe(true);
    expect(source.includes("pub(all) enum MaskType")).toBe(true);
    expect(source.includes("pub(all) struct Mask")).toBe(true);
    expect(source.includes("pub(all) struct MaskRegistry")).toBe(true);
    expect(source.includes("@msvg.Mask::new(")).toBe(true);
    expect(source.includes("@msvg.Mask::with_bounds(")).toBe(true);
    expect(source.includes("@msvg.compute_luminance(")).toBe(true);
    expect(source.includes("@msvg.compute_alpha_mask(")).toBe(true);
    expect(source.includes("mask_to_msvg(self).get_mask_bounds(")).toBe(true);
    expect(source.includes("@msvg.apply_mask_to_image(")).toBe(true);
    expect(interopSource.includes("fn mask_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn mask_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn mask_type_to_msvg(")).toBe(true);
    expect(source.includes("fn resolve_mask_coord(")).toBe(false);
    expect(source.includes("fn resolve_mask_size(")).toBe(false);
    expect(source.includes("Standard luminance formula")).toBe(false);
    expect(typesSource.includes("pub(all) struct Mask")).toBe(false);
    expect(typesSource.includes("pub fn Mask::new(")).toBe(false);
  });

  it("delegates SVG pattern sampling to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/pattern.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Pattern")).toBe(true);
    expect(source.includes("pub(all) enum PatternUnits")).toBe(true);
    expect(source.includes("pub(all) struct PatternRegistry")).toBe(true);
    expect(source.includes("@msvg.Pattern::new(")).toBe(true);
    expect(source.includes("pattern_to_msvg(self).get_color_at(")).toBe(true);
    expect(interopSource.includes("fn pattern_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn pattern_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn svg_node_to_msvg(")).toBe(true);
    expect(source.includes("Calculate pattern space coordinates")).toBe(false);
    expect(source.includes("Get position within pattern tile")).toBe(false);
    expect(typesSource.includes("pub(all) struct Pattern")).toBe(false);
    expect(typesSource.includes("pub fn Pattern::new(")).toBe(false);
  });

  it("delegates SVG marker transforms to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/marker.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct Marker")).toBe(true);
    expect(source.includes("pub(all) enum MarkerOrient")).toBe(true);
    expect(source.includes("pub(all) enum MarkerUnits")).toBe(true);
    expect(source.includes("pub(all) struct MarkerRegistry")).toBe(true);
    expect(source.includes("@msvg.Marker::new(")).toBe(true);
    expect(source.includes("@msvg.Marker::arrow(")).toBe(true);
    expect(source.includes("@msvg.Marker::dot(")).toBe(true);
    expect(source.includes("marker_to_msvg(self).get_transform(")).toBe(true);
    expect(interopSource.includes("fn marker_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn marker_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn marker_orient_to_msvg(")).toBe(true);
    expect(source.includes("let orient_angle = match self.orient")).toBe(false);
    expect(source.includes("Translate to position, rotate, scale")).toBe(false);
    expect(typesSource.includes("pub(all) struct Marker")).toBe(false);
    expect(typesSource.includes("pub fn Marker::new(")).toBe(false);
  });

  it("delegates SVG marked line angle math to mizchi/svg", () => {
    const typesSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/types.mbt"), "utf8");
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/marker.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("pub(all) struct MarkedLine")).toBe(true);
    expect(source.includes("@msvg.MarkedLine::new(")).toBe(true);
    expect(source.includes("@msvg.MarkedLine::with_markers(")).toBe(true);
    expect(source.includes("marked_line_to_msvg(self).get_angle_at(index)")).toBe(true);
    expect(interopSource.includes("fn marked_line_from_msvg(")).toBe(true);
    expect(interopSource.includes("fn marked_line_to_msvg(")).toBe(true);
    expect(source.includes("let a1 = @math.atan2(dy1, dx1)")).toBe(false);
    expect(typesSource.includes("pub(all) struct MarkedLine")).toBe(false);
    expect(typesSource.includes("pub fn MarkedLine::new(")).toBe(false);
  });

  it("keeps terminal output helpers out of crater-renderer", () => {
    const terminalOutputMarkers = [
      "mizchi/crater-painter-terminal/kitty",
      "mizchi/crater-painter/paint/raster",
      "render_to_sixel",
      "render_to_kitty",
      "write_kitty",
    ] as const;
    const offenders = collectMoonPackageFiles(path.join(REPO_ROOT, "renderer"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return terminalOutputMarkers.some((marker) => source.includes(marker));
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps terminal image cache implementation out of browser shell", () => {
    const implementationMarkers = [
      "pub struct ImageCache",
      "pub(all) struct RgbaCacheEntry",
      "pub(all) enum TerminalImageCacheEntry",
      "js_decode_raster_image_to_rgba_base64",
      "js_transcode_raster_image_to_png_base64",
    ] as const;
    const offenders = collectMoonBitFiles(path.join(REPO_ROOT, "browser_shell"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return implementationMarkers.some((marker) => source.includes(marker));
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("keeps html asset discovery implementation out of browser shell", () => {
    const implementationMarkers = [
      "is_img_tag_start",
      "is_html_attr_name_char",
      "read_html_attr_value",
    ] as const;
    const offenders = collectMoonBitFiles(path.join(REPO_ROOT, "browser_shell"))
      .filter((file) => {
        const source = fs.readFileSync(file, "utf8");
        return implementationMarkers.some((marker) => source.includes(marker));
      })
      .map((file) => path.relative(REPO_ROOT, file));

    expect(offenders).toEqual([]);
  });

  it("documents compatibility bridge ownership", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "docs/compatibility-bridges.md"), "utf8");
    const requiredBridges = [
      "mizchi/crater/css",
      "mizchi/crater-browser/js",
      "mizchi/crater-browser-shell",
      "mizchi/crater-dom/layout/html_bridge",
      "mizchi/crater-painter/paint/layout_bridge",
      "mizchi/crater-painter/paint/render_bridge",
      "mizchi/crater-painter/paint/glyph",
    ] as const;

    const missing = requiredBridges.filter((bridge) => !source.includes(bridge));
    expect(missing).toEqual([]);
  });
});
