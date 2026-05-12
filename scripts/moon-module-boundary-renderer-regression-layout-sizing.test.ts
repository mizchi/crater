import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer sizing regression boundary tests", () => {
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
});
