import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG boundary test organization", () => {
  it("keeps SVG boundary tests split by SVG sub-domain", () => {
    const splitTestFiles = [
      "scripts/moon-module-boundary-svg-scene.test.ts",
      "scripts/moon-module-boundary-svg-types.test.ts",
    ] as const;

    const missingFiles = splitTestFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });
    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-svg.test.ts")).toBeLessThanOrEqual(80);
  });
});
