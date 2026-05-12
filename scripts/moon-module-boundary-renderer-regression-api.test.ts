import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer API regression test boundaries", () => {
  it("keeps renderer public render API contract tests in their own file", () => {
    const renderApiTestFile = path.join(REPO_ROOT, "renderer/renderer/render_api_test.mbt");
    expect(fs.existsSync(renderApiTestFile)).toBe(true);

    const renderApiSource = fs.readFileSync(renderApiTestFile, "utf8");
    const rendererTestSource = fs.readFileSync(
      path.join(REPO_ROOT, "renderer/renderer/renderer_test.mbt"),
      "utf8",
    );
    const migratedTests = [
      'test "layout_to_json serializes box model fields without changing schema"',
      'test "render_to_node_and_layout_with_external_css is stable across repeated calls"',
      'test "prepared external css renders same layout as css array path"',
      'test "shared node_and_layout render matches separate passes"',
    ] as const;

    expect(migratedTests.every((marker) => renderApiSource.includes(marker))).toBe(true);
    const offenders = migratedTests.filter((marker) => rendererTestSource.includes(marker));
    expect(offenders).toEqual([]);
  });
});
