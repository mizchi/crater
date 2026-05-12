import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer table core boundaries", () => {
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
});
