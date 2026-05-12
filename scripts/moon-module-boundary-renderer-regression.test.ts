import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer regression test boundaries", () => {
  it("keeps renderer regression boundary tests split by renderer feature domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-regression-api.test.ts",
      "scripts/moon-module-boundary-renderer-regression-content.test.ts",
      "scripts/moon-module-boundary-renderer-regression-elements.test.ts",
      "scripts/moon-module-boundary-renderer-regression-layout.test.ts",
      "scripts/moon-module-boundary-renderer-regression-style.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(
      countLines("scripts/moon-module-boundary-renderer-regression.test.ts"),
    ).toBeLessThanOrEqual(80);
  });
});
