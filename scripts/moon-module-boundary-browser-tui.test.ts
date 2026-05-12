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

describe("MoonBit browser TUI module boundaries", () => {
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
});
