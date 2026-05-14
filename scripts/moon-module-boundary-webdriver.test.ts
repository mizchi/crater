import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver boundary test organization", () => {
  it("keeps WebDriver boundary tests split by WebDriver sub-domain", () => {
    const splitTestFiles = [
      "scripts/moon-module-boundary-webdriver-facade.test.ts",
      "scripts/moon-module-boundary-webdriver-protocol.test.ts",
      "scripts/moon-module-boundary-webdriver-runtime.test.ts",
      "scripts/moon-module-boundary-webdriver-tests.test.ts",
    ] as const;

    const missingFiles = splitTestFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });
    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-webdriver.test.ts")).toBeLessThanOrEqual(80);
  });
});
