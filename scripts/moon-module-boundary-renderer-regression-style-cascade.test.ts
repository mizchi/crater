import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer style cascade regression boundaries", () => {
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
