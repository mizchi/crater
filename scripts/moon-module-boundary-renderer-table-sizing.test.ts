import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer table sizing regression boundaries", () => {
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
});
