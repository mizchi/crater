import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

describe("CI VRT parallelization", () => {
  test("runs paint-vrt as a grep-based matrix and aggregates artifacts", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");

    expect(workflow).toContain("name: paint-vrt (${{ matrix.name }})");
    expect(workflow).toContain("name: fixtures");
    expect(workflow).toContain("name: realworld");
    expect(workflow).toContain("name: url");
    expect(workflow).toContain("grep: 'fixture:'");
    expect(workflow).toContain("grep: 'real-world snapshot:|example-com visual parity'");
    expect(workflow).toContain("grep: 'url snapshot:'");
    expect(workflow).toContain("paint-vrt-summary:");
    expect(workflow).toContain("pattern: paint-vrt-artifacts-*");
  });
});
