import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser shell boundary test organization", () => {
  it("keeps browser shell boundary tests split by shell sub-domain", () => {
    const splitTestFiles = [
      "scripts/moon-module-boundary-browser-shell-interaction.test.ts",
      "scripts/moon-module-boundary-browser-shell-navigation.test.ts",
      "scripts/moon-module-boundary-browser-shell-rendering.test.ts",
      "scripts/moon-module-boundary-browser-shell-script.test.ts",
      "scripts/moon-module-boundary-browser-shell-tests.test.ts",
    ] as const;

    const missingFiles = splitTestFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });
    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-browser-shell.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
