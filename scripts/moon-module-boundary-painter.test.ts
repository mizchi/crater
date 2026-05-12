import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit painter module boundaries", () => {
  it("keeps painter boundary tests split by painter sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-painter-glyph.test.ts",
      "scripts/moon-module-boundary-painter-raster-assets.test.ts",
      "scripts/moon-module-boundary-painter-raster-core.test.ts",
      "scripts/moon-module-boundary-painter-raster-effects.test.ts",
      "scripts/moon-module-boundary-painter-raster-node.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-painter.test.ts")).toBeLessThanOrEqual(80);
  });
});
