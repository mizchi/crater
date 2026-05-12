import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core style boundaries", () => {
  it("keeps renderer core style boundary tests split by style sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-core-style-document.test.ts",
      "scripts/moon-module-boundary-renderer-core-style-resolve.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-renderer-core-style.test.ts")).toBeLessThanOrEqual(80);
  });
});
