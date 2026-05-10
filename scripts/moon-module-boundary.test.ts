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
      "fn resolve_pseudo_spec",
      "fn resolve_pseudo_spec_fast",
      "fn get_counter_directives",
      "fn selector_has_generated_pseudo_content",
      "fn compute_element_own_counters",
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
