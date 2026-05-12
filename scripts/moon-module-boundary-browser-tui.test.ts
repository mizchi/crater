import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI boundary test organization", () => {
  it("keeps browser TUI boundary tests split by TUI sub-domain", () => {
    const splitTestFiles = [
      "scripts/moon-module-boundary-browser-tui-adapter.test.ts",
      "scripts/moon-module-boundary-browser-tui-buffer.test.ts",
      "scripts/moon-module-boundary-browser-tui-render.test.ts",
      "scripts/moon-module-boundary-browser-tui-widgets.test.ts",
    ] as const;

    const missingFiles = splitTestFiles.filter((file) => {
      return !fs.existsSync(path.join(REPO_ROOT, file));
    });
    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-browser-tui.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
