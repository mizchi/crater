import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit SVG scene module boundaries", () => {
  it("keeps SVG scene boundary tests split by scene sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-svg-scene-animation.test.ts",
      "scripts/moon-module-boundary-svg-scene-dirty.test.ts",
      "scripts/moon-module-boundary-svg-scene-graph.test.ts",
      "scripts/moon-module-boundary-svg-scene-render.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-svg-scene.test.ts")).toBeLessThanOrEqual(80);
  });
});
