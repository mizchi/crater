import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit browser TUI render boundaries", () => {
  it("keeps browser TUI render boundary tests split by render sub-domain", () => {
    const expectedFiles = [
      "scripts/moon-module-boundary-browser-tui-render-geometry.test.ts",
      "scripts/moon-module-boundary-browser-tui-render-hit.test.ts",
      "scripts/moon-module-boundary-browser-tui-render-output.test.ts",
      "scripts/moon-module-boundary-browser-tui-render-paint.test.ts",
    ];
    const missingFiles = expectedFiles.filter((file) => !fs.existsSync(path.join(REPO_ROOT, file)));

    expect(missingFiles).toEqual([]);
    expect(countLines("scripts/moon-module-boundary-browser-tui-render.test.ts")).toBeLessThanOrEqual(
      80,
    );
  });
});
