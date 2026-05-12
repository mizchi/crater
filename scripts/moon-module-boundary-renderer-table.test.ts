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

describe("MoonBit renderer table regression boundaries", () => {
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
});
