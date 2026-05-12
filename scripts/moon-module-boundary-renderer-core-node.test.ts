import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core node boundaries", () => {
  it("keeps renderer core node boundary tests split by node sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-core-node-build.test.ts",
      "scripts/moon-module-boundary-renderer-core-node-utils.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-renderer-core-node.test.ts")).toBeLessThanOrEqual(80);
  });
});
