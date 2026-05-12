import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer core module boundaries", () => {
  it("keeps renderer core boundary tests split by renderer sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-core-contract.test.ts",
      "scripts/moon-module-boundary-renderer-core-flow.test.ts",
      "scripts/moon-module-boundary-renderer-core-layout.test.ts",
      "scripts/moon-module-boundary-renderer-core-media.test.ts",
      "scripts/moon-module-boundary-renderer-core-node.test.ts",
      "scripts/moon-module-boundary-renderer-core-style.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-renderer-core.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
