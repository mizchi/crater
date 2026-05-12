import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer font and metrics regression boundaries", () => {
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
});
