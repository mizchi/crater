import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser shell interaction boundaries", () => {
  it("keeps browser shell interaction boundary tests split by interaction sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-browser-shell-interaction-focus.test.ts",
      "scripts/moon-module-boundary-browser-shell-interaction-input.test.ts",
      "scripts/moon-module-boundary-browser-shell-interaction-links.test.ts",
      "scripts/moon-module-boundary-browser-shell-interaction-state.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(
      countLines("scripts/moon-module-boundary-browser-shell-interaction.test.ts"),
    ).toBeLessThanOrEqual(80);
  });
});
