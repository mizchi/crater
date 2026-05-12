import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core layout boundaries", () => {
  it("keeps renderer core layout boundary tests split by layout sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-core-layout-output.test.ts",
      "scripts/moon-module-boundary-renderer-core-layout-positioning.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-renderer-core-layout.test.ts")).toBeLessThanOrEqual(80);
  });
});
