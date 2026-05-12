import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit renderer table regression boundaries", () => {
  it("keeps renderer table boundary tests split by table sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-renderer-table-core.test.ts",
      "scripts/moon-module-boundary-renderer-table-model.test.ts",
      "scripts/moon-module-boundary-renderer-table-sizing.test.ts",
      "scripts/moon-module-boundary-renderer-table-structure.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-renderer-table.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
