import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer positioning regression boundary tests", () => {
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
});
