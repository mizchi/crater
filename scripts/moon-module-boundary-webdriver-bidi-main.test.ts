import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

const ALLOWED_WEBDRIVER_REFS = new Set<string>([
  "@webdriver.BidiServer",
  "@webdriver.BidiServerConfig",
  "@webdriver.generate_auth_token",
  "@webdriver.warmup_glyph_cache",
]);

describe("MoonBit webdriver/bidi_main boundary", () => {
  it("only consumes the minimum BiDi server surface from @webdriver", () => {
    const mainSource = read("webdriver/bidi_main/main.mbt");
    const moonPkg = read("webdriver/bidi_main/moon.pkg");

    // bidi_main's only crater-side dependency must be @webdriver.
    expect(moonPkg).toContain('"mizchi/crater-webdriver-bidi/webdriver" @webdriver');
    for (const forbidden of [
      "mizchi/crater-webdriver-bidi/runtime",
      "mizchi/crater-webdriver-bidi/rendering",
      "mizchi/crater-webdriver-bidi/browser_domain",
      "mizchi/crater-webdriver-bidi/protocol",
      "mizchi/crater-webdriver-bidi/rpc",
      "mizchi/crater-network",
      "mizchi/crater-renderer",
      "mizchi/crater-painter",
      "mizchi/crater-browser",
      "mizchi/crater-dom",
    ]) {
      expect(moonPkg).not.toContain(forbidden);
    }

    const matches = mainSource.match(/@webdriver\.[a-zA-Z_][a-zA-Z_0-9]*/g) ?? [];
    const uniqueRefs = new Set(matches);
    expect(uniqueRefs.size).toBeGreaterThan(0);

    const unexpected = [...uniqueRefs].filter((ref) => !ALLOWED_WEBDRIVER_REFS.has(ref));
    expect(unexpected).toEqual([]);
  });

  it("keeps this boundary test small enough to stay focused", () => {
    expect(countLines("scripts/moon-module-boundary-webdriver-bidi-main.test.ts")).toBeLessThanOrEqual(60);
  });
});
