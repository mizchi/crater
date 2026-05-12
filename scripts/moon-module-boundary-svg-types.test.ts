import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade boundaries", () => {
  it("keeps SVG type facade boundary tests split by SVG sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-svg-types-animation.test.ts",
      "scripts/moon-module-boundary-svg-types-core.test.ts",
      "scripts/moon-module-boundary-svg-types-effects.test.ts",
      "scripts/moon-module-boundary-svg-types-interaction.test.ts",
      "scripts/moon-module-boundary-svg-types-raster.test.ts",
      "scripts/moon-module-boundary-svg-types-text-symbol.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-svg-types.test.ts")).toBeLessThanOrEqual(80);
  });
});
