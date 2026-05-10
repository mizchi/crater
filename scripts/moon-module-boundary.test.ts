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
  "terminal_protocol/kitty/moon.pkg",
  "terminal_protocol/sixel/moon.pkg",
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
        return source.includes("mizchi/crater-terminal-protocol") ||
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
    expect(fs.existsSync(path.join(REPO_ROOT, "painter/x/image/sixel.mbt"))).toBe(false);
  });

  it("keeps painter-terminal root facade behind terminal-specific packages", () => {
    const rootPackage = path.join(REPO_ROOT, "painter_terminal/moon.pkg");
    const source = fs.readFileSync(rootPackage, "utf8");

    expect(source).not.toContain("mizchi/crater-terminal-protocol");
  });

  it("keeps browser tui core primitives behind the tui core package", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "browser/tui/core/moon.pkg"))).toBe(true);

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

  it("keeps terminal output helpers out of crater-renderer", () => {
    const terminalOutputMarkers = [
      "mizchi/crater-painter-terminal/kitty",
      "mizchi/crater-painter/x/image",
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
});
