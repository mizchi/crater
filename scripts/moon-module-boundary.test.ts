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

  it("keeps renderer table layout regression tests in their own file", () => {
    const tableTestFile = path.join(REPO_ROOT, "renderer/renderer/table_render_test.mbt");
    expect(fs.existsSync(tableTestFile)).toBe(true);

    const tableSource = fs.readFileSync(tableTestFile, "utf8");
    const renderSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/render_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "wpt_table_as_flex_item_auto_min_width_floor"',
      'test "wpt_table_cell_overflow_auto_respects_max_width"',
      'test "empty_td_cellpadding_does_not_inflate_row"',
    ] as const;

    expect(migratedTests.every((marker) => tableSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => renderSource.includes(marker));
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
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const factoryStart = source.indexOf("/// Helper: Create a rectangle node");
    const factoryEnd = source.indexOf("/// Create a RenderContext", factoryStart);
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
  });

  it("delegates SVG scene render entrypoints to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("let scene = scene_to_msvg(self)")).toBe(true);
    expect(source.includes("scene.render(render_context_to_msvg(ctx))")).toBe(true);
    expect(source.includes("scene.render_with_camera(")).toBe(true);
    expect(source.includes("scene.render_with_viewbox(")).toBe(true);
    expect(source.includes("scene.render_with_viewbox_and_camera(")).toBe(true);
    expect(interopSource.includes("fn render_context_to_msvg(")).toBe(true);
    expect(interopSource.includes("fn scene_to_msvg(")).toBe(true);
    expect(source.includes("render_node(self.root, Transform::identity(), ctx)")).toBe(false);
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
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");

    expect(source.includes("svg_scene_from_msvg(@msvg.Scene::empty())")).toBe(true);
    expect(source.includes("bounding_box_from_msvg(scene_to_msvg(self).get_bounds())")).toBe(true);
    expect(source.includes("bounding_box_from_msvg(scene_to_msvg(self).get_dirty_region())")).toBe(true);
    expect(source.includes("compute_bounds(self.root, Transform::identity())")).toBe(false);
    expect(source.includes("compute_dirty_region(self.root, Transform::identity())")).toBe(false);
  });

  it("delegates SVG dirty rendering to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
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
  });

  it("delegates SVG scene dirty flag operations to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
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
  });

  it("delegates SVG scene z-index operations to mizchi/svg", () => {
    const source = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/scene.mbt"), "utf8");
    const interopSource = fs.readFileSync(path.join(REPO_ROOT, "painter/svg/interop.mbt"), "utf8");

    expect(source.includes("scene.set_z_index(id, z_index)")).toBe(true);
    expect(source.includes("scene.bring_to_front(id)")).toBe(true);
    expect(source.includes("scene.send_to_back(id)")).toBe(true);
    expect(source.includes("copy_svg_scene_z_order_state_from_msvg(self, scene)")).toBe(true);
    expect(interopSource.includes("fn copy_svg_scene_z_order_state_from_msvg(")).toBe(true);
    expect(source.includes("fn find_parent_and_node(")).toBe(false);
    expect(source.includes("fn get_max_z_index(")).toBe(false);
    expect(source.includes("fn get_min_z_index(")).toBe(false);
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
