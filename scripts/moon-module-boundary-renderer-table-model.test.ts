import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer table model regression boundaries", () => {
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
});
