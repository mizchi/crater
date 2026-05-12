import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer layout regression test boundaries", () => {
  it("keeps renderer layout regression boundary tests split by layout sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-regression-layout-formatting.test.ts",
      "scripts/moon-module-boundary-renderer-regression-layout-positioning.test.ts",
      "scripts/moon-module-boundary-renderer-regression-layout-sizing.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(
      countLines("scripts/moon-module-boundary-renderer-regression-layout.test.ts"),
    ).toBeLessThanOrEqual(80);
  });
});
