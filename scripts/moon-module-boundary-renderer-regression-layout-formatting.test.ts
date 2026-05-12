import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer formatting-model regression boundary tests", () => {
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
});
