import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG type facade effect boundaries", () => {
  it("keeps SVG effect boundary tests split by effect sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-svg-types-effects-filter.test.ts",
      "scripts/moon-module-boundary-svg-types-effects-resource.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-svg-types-effects.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
