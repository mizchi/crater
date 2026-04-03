import { describe, expect, it } from "vitest";
import { runWptVrtSummaryCli } from "./wpt-vrt-summary.ts";

describe("runWptVrtSummaryCli", () => {
  it("returns shard markdown and writes for raw input", () => {
    const result = runWptVrtSummaryCli(
      [
        "--input",
        "output/playwright/vrt/wpt/wpt-vrt-results.json",
        "--label",
        "flexbox-1",
        "--json",
        "out/shard.json",
        "--markdown",
        "out/shard.md",
      ],
      {
        cwd: "/repo",
        readFile: () => JSON.stringify({
          schemaVersion: 1,
          suite: "wpt-vrt",
          shard: {
            name: "flexbox-1",
            modules: ["css-flexbox"],
          },
          summary: {
            total: 1,
            passed: 1,
            failed: 0,
          },
          tests: {
            "css-flexbox/gap-001.html": { diffRatio: 0.0, status: "pass" },
          },
        }),
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# WPT VRT Shard Summary");
    expect(result.writes).toEqual([
      {
        path: "/repo/out/shard.md",
        content: expect.stringContaining("# WPT VRT Shard Summary"),
      },
      {
        path: "/repo/out/shard.json",
        content: expect.stringContaining('"suite": "wpt-vrt"'),
      },
    ]);
  });

  it("returns aggregate markdown and writes for summary directory", () => {
    const result = runWptVrtSummaryCli(
      [
        "--aggregate",
        "wpt-vrt-reports",
        "--json",
        "out/aggregate.json",
        "--markdown",
        "out/aggregate.md",
      ],
      {
        cwd: "/repo",
        jsonFilesByDir: new Map([
          ["/repo/wpt-vrt-reports", ["/repo/wpt-vrt-reports/flexbox-1.json"]],
        ]),
        readFile: () => JSON.stringify({
          schemaVersion: 1,
          suite: "wpt-vrt",
          generatedAt: "2026-04-01T00:00:00.000Z",
          label: "flexbox-1",
          shardName: "flexbox-1",
          modules: ["css-flexbox"],
          offset: 0,
          limit: 10,
          total: 1,
          passed: 1,
          failed: 0,
          passRate: 1,
          maxDiffRatio: 0,
          moduleTotals: [
            { module: "css-flexbox", total: 1, passed: 1, failed: 0, passRate: 1 },
          ],
          failures: [],
        }),
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# WPT VRT Aggregate Summary");
    expect(result.writes).toEqual([
      {
        path: "/repo/out/aggregate.md",
        content: expect.stringContaining("# WPT VRT Aggregate Summary"),
      },
      {
        path: "/repo/out/aggregate.json",
        content: expect.stringContaining('"shards": 1'),
      },
    ]);
  });
});
