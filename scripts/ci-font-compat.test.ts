import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, test } from "vitest";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

describe("CI compatible font setup", () => {
  test("installs compatible fonts in VRT jobs", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const matches = workflow.match(/bash scripts\/ci\/install-compatible-fonts\.sh/g) ?? [];
    expect(matches).toHaveLength(2);
  });

  test("restores Playwright browser cache for both VRT workflows", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const matches = workflow.match(/Restore Playwright Chromium browser cache/g) ?? [];
    expect(matches).toHaveLength(2);
    expect(workflow).toContain("id: paint_vrt_playwright_cache");
    expect(workflow).toContain("id: wpt_vrt_playwright_cache");
    expect(workflow).toContain("if: steps.paint_vrt_playwright_cache.outputs.cache-hit != 'true'");
    expect(workflow).toContain("if: steps.wpt_vrt_playwright_cache.outputs.cache-hit != 'true'");
  });

  test("restores rusty_v8 source binding cache in all native or BiDi jobs", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const matches = workflow.match(/Restore rusty_v8 source binding cache/g) ?? [];
    expect(matches).toHaveLength(5);
    expect(workflow).toContain("path: ~/.cargo/.rusty_v8");
    expect(workflow).toContain("node scripts/prefetch-rusty-v8-source-binding.mjs --module-root browser/native");
    expect(workflow).toContain("node scripts/prefetch-rusty-v8-source-binding.mjs --module-root webdriver");
  });

  test("pins Deno 1 for BiDi and VRT workflows to keep rusty_v8 fallback compatible", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const matches = workflow.match(/deno-version: v1\.46\.3/g) ?? [];
    expect(matches).toHaveLength(4);
  });

  test("font install script retries flaky msttcorefonts extraction", () => {
    const script = readRepoFile("scripts/ci/install-compatible-fonts.sh");

    expect(script).toContain("for attempt in 1 2 3; do");
    expect(script).toContain("sudo dpkg-reconfigure ttf-mscorefonts-installer || true");
    expect(script).toContain("sudo rm -f /var/lib/update-notifier/package-data-downloads/partial/* || true");
    expect(script).toContain("sudo apt-get install -y --reinstall --no-install-recommends ttf-mscorefonts-installer || true");
  });

  test("font resolvers include msttcorefonts file variants", () => {
    const bidiSource = readRepoFile("webdriver/bidi_main/start-with-font.ts");
    const resolverSource = readRepoFile("scripts/system-font-resolver.ts");

    for (const source of [bidiSource, resolverSource]) {
      expect(source).toContain("Times_New_Roman.ttf");
      expect(source).toContain("Times_New_Roman_Bold.ttf");
      expect(source).toContain("Courier_New.ttf");
      expect(source).toContain("Georgia_Bold.ttf");
      expect(source).toContain("verdanab.ttf");
    }
  });

  test("start-with-font resolves helper scripts from the repo root after webdriver split", () => {
    const bidiPath = new URL("../webdriver/bidi_main/start-with-font.ts", import.meta.url);
    const textIntrinsicPath = new URL("../../scripts/text-intrinsic.ts", bidiPath);
    const fontDefaultsPath = new URL("../../scripts/font-family-defaults.ts", bidiPath);

    expect(path.basename(textIntrinsicPath.pathname)).toBe("text-intrinsic.ts");
    expect(path.basename(fontDefaultsPath.pathname)).toBe("font-family-defaults.ts");
    expect(textIntrinsicPath.pathname).toContain("/crater/scripts/");
    expect(fontDefaultsPath.pathname).toContain("/crater/scripts/");
  });
});
