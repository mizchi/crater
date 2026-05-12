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

describe("MoonBit browser shell module boundaries", () => {
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
});
