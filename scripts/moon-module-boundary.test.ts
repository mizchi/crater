import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit module boundary test organization", () => {
  it("keeps MoonBit module boundary tests split by domain", () => {
    const splitTestFiles = [
      "scripts/moon-module-boundary-browser-shell.test.ts",
      "scripts/moon-module-boundary-browser-tui.test.ts",
      "scripts/moon-module-boundary-painter.test.ts",
      "scripts/moon-module-boundary-package.test.ts",
      "scripts/moon-module-boundary-renderer.test.ts",
      "scripts/moon-module-boundary-webdriver.test.ts",
    ] as const;

    const missingFiles = splitTestFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });
    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary.test.ts")).toBeLessThanOrEqual(80);
  });
});
