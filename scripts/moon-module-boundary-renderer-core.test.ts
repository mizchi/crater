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

describe("MoonBit renderer core module boundaries", () => {
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
});
