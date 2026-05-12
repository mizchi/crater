import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI buffer and ANSI boundaries", () => {
  it("keeps browser TUI buffer boundary tests split by buffer sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-browser-tui-buffer-ansi.test.ts",
      "scripts/moon-module-boundary-browser-tui-buffer-core.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-browser-tui-buffer.test.ts")).toBeLessThanOrEqual(80);
  });
});
