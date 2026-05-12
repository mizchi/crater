import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer boundary test organization", () => {
  it("keeps renderer boundary tests split by renderer sub-domain", () => {
    const splitTestFiles = [
      "scripts/moon-module-boundary-renderer-core.test.ts",
      "scripts/moon-module-boundary-renderer-regression.test.ts",
      "scripts/moon-module-boundary-renderer-table.test.ts",
    ] as const;

    const missingFiles = splitTestFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });
    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-renderer.test.ts")).toBeLessThanOrEqual(80);
  });
});
