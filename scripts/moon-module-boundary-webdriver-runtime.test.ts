import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver runtime module boundaries", () => {
  it("keeps WebDriver runtime boundary tests split by runtime sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-webdriver-runtime-context.test.ts",
      "scripts/moon-module-boundary-webdriver-runtime-document.test.ts",
      "scripts/moon-module-boundary-webdriver-runtime-state.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-webdriver-runtime.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
