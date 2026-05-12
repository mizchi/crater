import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer table structure regression boundaries", () => {
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
