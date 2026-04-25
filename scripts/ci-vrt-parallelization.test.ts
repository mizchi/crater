import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

describe("CI VRT parallelization", () => {
  test("runs paint-vrt as a grep-based matrix and aggregates artifacts", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");

    expect(workflow).toContain("name: paint-vrt (${{ matrix.name }})");
    expect(workflow).toContain("max-parallel: 5");
    expect(workflow).toContain("name: fixtures-a1");
    expect(workflow).toContain("name: fixtures-a2");
    expect(workflow).toContain("name: fixtures-b");
    expect(workflow).toContain("name: realworld");
    expect(workflow).toContain("name: url");
    expect(workflow).toContain("grep: 'fixture: (cards and controls|pricing cards|login form)'");
    expect(workflow).toContain("grep: 'fixture: (blog article|navigation bar|footer)'");
    expect(workflow).toContain("grep: 'fixture: (live form state|hackernews-style|canvas background|table with cellpadding and cellspacing|table with cellpadding=10)'");
    expect(workflow).toContain("grep: 'real-world snapshot:|example-com visual parity'");
    expect(workflow).toContain("grep: 'url snapshot:'");
    expect(workflow).toContain("Restore paint VRT reference fixtures");
    expect(workflow).toContain("path: .cache/paint-vrt-reference");
    expect(workflow).toContain("if: steps.paint_vrt_playwright_cache.outputs.cache-hit != 'true'");
    expect(workflow).toContain("Restore WPT VRT reference fixtures");
    expect(workflow).toContain("path: .cache/wpt-vrt-reference");
    expect(workflow).toContain("if: steps.wpt_vrt_playwright_cache.outputs.cache-hit != 'true'");
    expect(workflow).toContain("paint-vrt-summary:");
    expect(workflow).toContain("pattern: paint-vrt-artifacts-*");
  });
});
