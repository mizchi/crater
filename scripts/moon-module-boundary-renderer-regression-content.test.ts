import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer content regression test boundaries", () => {
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
});
