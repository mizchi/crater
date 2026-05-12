import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver protocol module boundaries", () => {
  it("keeps WebDriver protocol boundary tests split by protocol sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-webdriver-protocol-commands.test.ts",
      "scripts/moon-module-boundary-webdriver-protocol-core.test.ts",
      "scripts/moon-module-boundary-webdriver-protocol-rendering.test.ts",
      "scripts/moon-module-boundary-webdriver-protocol-routing.test.ts",
      "scripts/moon-module-boundary-webdriver-protocol-script.test.ts",
      "scripts/moon-module-boundary-webdriver-protocol-state.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(
      countLines("scripts/moon-module-boundary-webdriver-protocol.test.ts"),
    ).toBeLessThanOrEqual(80);
  });
});
