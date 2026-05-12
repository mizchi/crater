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

describe("MoonBit renderer regression test boundaries", () => {
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
});
