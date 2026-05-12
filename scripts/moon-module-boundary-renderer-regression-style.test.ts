import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer style regression test boundaries", () => {
  it("keeps renderer style regression boundary tests split by style sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-regression-style-cascade.test.ts",
      "scripts/moon-module-boundary-renderer-regression-style-font.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(
      countLines("scripts/moon-module-boundary-renderer-regression-style.test.ts"),
    ).toBeLessThanOrEqual(80);
  });
});
