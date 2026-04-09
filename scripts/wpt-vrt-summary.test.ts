import { describe, expect, it } from "vitest";
import {
  aggregateWptVrtSummaries,
  buildWptVrtShardSummary,
  renderWptVrtAggregateMarkdown,
  renderWptVrtShardMarkdown,
  type WptVrtRawReport,
  type WptVrtShardSummary,
} from "./wpt-vrt-summary-core.ts";

function makeRawReport(
  overrides: Partial<WptVrtRawReport> = {},
): WptVrtRawReport {
  return {
    schemaVersion: 1,
    suite: "wpt-vrt",
    generatedAt: "2026-04-01T00:00:00.000Z",
    shard: {
      name: "flexbox-1",
      modules: ["css-flexbox"],
      offset: 0,
      limit: 21,
    },
    config: {
      viewport: { width: 800, height: 600 },
      pixelmatchThreshold: 0.1,
      defaultMaxDiffRatio: 0.02,
    },
    summary: {
      total: 3,
      passed: 2,
      failed: 1,
    },
    tests: {
      "css-flexbox/gap-001.html": { diffRatio: 0.004, status: "pass" },
      "css-flexbox/gap-002.html": { diffRatio: 0.033, status: "fail" },
      "css-box/block-001.html": { diffRatio: 0.0, status: "pass" },
    },
    ...overrides,
  };
}

function makeShardSummary(
  overrides: Partial<WptVrtShardSummary> = {},
): WptVrtShardSummary {
  const base = buildWptVrtShardSummary(makeRawReport(), "flexbox-1");
  return {
    ...base,
    ...overrides,
  };
}

describe("buildWptVrtShardSummary", () => {
  it("normalizes raw WPT VRT results into shard summary", () => {
    const summary = buildWptVrtShardSummary(makeRawReport(), "flexbox-1");

    expect(summary.label).toBe("flexbox-1");
    expect(summary.total).toBe(3);
    expect(summary.passed).toBe(2);
    expect(summary.failed).toBe(1);
    expect(summary.passRate).toBeCloseTo(2 / 3);
    expect(summary.maxDiffRatio).toBe(0.033);
    expect(summary.moduleTotals.map((row) => `${row.module}:${row.total}`)).toEqual([
      "css-flexbox:2",
      "css-box:1",
    ]);
    expect(summary.failures).toEqual([
      {
        relativePath: "css-flexbox/gap-002.html",
        module: "css-flexbox",
        diffRatio: 0.033,
        status: "fail",
      },
    ]);
  });

  it("preserves baseline regressions even when raw test statuses are all pass", () => {
    const summary = buildWptVrtShardSummary(makeRawReport({
      shard: {
        name: "display",
        modules: ["css-display"],
        offset: 35,
        limit: 4,
      },
      summary: {
        total: 2,
        expectedTotal: 39,
        passed: 2,
        failed: 0,
        regressions: 1,
      },
      tests: {
        "css-display/display-contents-text-only-001.html": {
          diffRatio: 0.021,
          status: "pass",
          baselineDiffRatio: 0.009,
          regressionLimit: 0.019,
          headroom: -0.002,
        },
        "css-display/display-contents-dynamic-multicol-001-inline.html": {
          diffRatio: 0.0183,
          status: "pass",
          baselineDiffRatio: 0.009,
          regressionLimit: 0.019,
          headroom: 0.0007,
        },
      },
      regressions: [
        {
          relativePath: "css-display/display-contents-text-only-001.html",
          diffRatio: 0.021,
          baselineDiffRatio: 0.009,
          regressionLimit: 0.019,
          headroom: -0.002,
          status: "pass",
        },
      ],
      closestToThreshold: [
        {
          relativePath: "css-display/display-contents-text-only-001.html",
          diffRatio: 0.021,
          baselineDiffRatio: 0.009,
          regressionLimit: 0.019,
          headroom: -0.002,
          status: "pass",
        },
        {
          relativePath: "css-display/display-contents-dynamic-multicol-001-inline.html",
          diffRatio: 0.0183,
          baselineDiffRatio: 0.009,
          regressionLimit: 0.019,
          headroom: 0.0007,
          status: "pass",
        },
      ],
    }), "display");

    expect(summary.expectedTotal).toBe(39);
    expect(summary.regressionCount).toBe(1);
    expect(summary.regressions).toEqual([
      {
        relativePath: "css-display/display-contents-text-only-001.html",
        module: "css-display",
        diffRatio: 0.021,
        baselineDiffRatio: 0.009,
        regressionLimit: 0.019,
        headroom: -0.002,
        status: "pass",
      },
    ]);
    expect(summary.closestToThreshold).toEqual([
      {
        relativePath: "css-display/display-contents-text-only-001.html",
        module: "css-display",
        diffRatio: 0.021,
        baselineDiffRatio: 0.009,
        regressionLimit: 0.019,
        headroom: -0.002,
        status: "pass",
      },
      {
        relativePath: "css-display/display-contents-dynamic-multicol-001-inline.html",
        module: "css-display",
        diffRatio: 0.0183,
        baselineDiffRatio: 0.009,
        regressionLimit: 0.019,
        headroom: 0.0007,
        status: "pass",
      },
    ]);
  });
});

describe("aggregateWptVrtSummaries", () => {
  it("aggregates shard summaries and merges failures by module", () => {
    const summary = aggregateWptVrtSummaries([
      makeShardSummary(),
      makeShardSummary({
        label: "display",
        shardName: "display",
        modules: ["css-display"],
        total: 2,
        passed: 1,
        failed: 1,
        passRate: 0.5,
        maxDiffRatio: 0.081,
        moduleTotals: [
          { module: "css-display", total: 2, passed: 1, failed: 1, passRate: 0.5 },
        ],
        failures: [
          {
            relativePath: "css-display/run-in-001.html",
            module: "css-display",
            diffRatio: 0.081,
            status: "fail",
            error: "layout shifted",
          },
        ],
      }),
    ]);

    expect(summary.rows).toHaveLength(2);
    expect(summary.total.total).toBe(5);
    expect(summary.total.passed).toBe(3);
    expect(summary.total.failed).toBe(2);
    expect(summary.total.regressions).toBe(0);
    expect(summary.byModule.map((row) => `${row.module}:${row.failed}`)).toEqual([
      "css-display:1",
      "css-flexbox:1",
      "css-box:0",
    ]);
    expect(summary.topFailures.map((row) => row.relativePath)).toEqual([
      "css-display/run-in-001.html",
      "css-flexbox/gap-002.html",
    ]);
  });

  it("aggregates shard regressions separately from raw failures", () => {
    const summary = aggregateWptVrtSummaries([
      makeShardSummary({
        label: "display",
        shardName: "display",
        modules: ["css-display"],
        total: 2,
        expectedTotal: 39,
        passed: 2,
        failed: 0,
        regressionCount: 1,
        passRate: 1,
        maxDiffRatio: 0.021,
        moduleTotals: [
          { module: "css-display", total: 2, passed: 2, failed: 0, passRate: 1 },
        ],
        failures: [],
        regressions: [
          {
            relativePath: "css-display/display-contents-text-only-001.html",
            module: "css-display",
            diffRatio: 0.021,
            baselineDiffRatio: 0.009,
            regressionLimit: 0.019,
            headroom: -0.002,
            status: "pass",
          },
        ],
        closestToThreshold: [],
      }),
    ]);

    expect(summary.total.regressions).toBe(1);
    expect(summary.topRegressions).toEqual([
      {
        label: "display",
        relativePath: "css-display/display-contents-text-only-001.html",
        module: "css-display",
        diffRatio: 0.021,
        baselineDiffRatio: 0.009,
        regressionLimit: 0.019,
        headroom: -0.002,
        status: "pass",
      },
    ]);
  });
});

describe("render markdown", () => {
  it("renders shard and aggregate summaries", () => {
    const shardMarkdown = renderWptVrtShardMarkdown(
      buildWptVrtShardSummary(makeRawReport(), "flexbox-1"),
    );
    const aggregateMarkdown = renderWptVrtAggregateMarkdown(
      aggregateWptVrtSummaries([
        makeShardSummary(),
        makeShardSummary({
          label: "display",
          shardName: "display",
          modules: ["css-display"],
          total: 2,
          passed: 1,
          failed: 1,
          passRate: 0.5,
          maxDiffRatio: 0.081,
          moduleTotals: [
            { module: "css-display", total: 2, passed: 1, failed: 1, passRate: 0.5 },
          ],
          failures: [
            {
              relativePath: "css-display/run-in-001.html",
              module: "css-display",
              diffRatio: 0.081,
              status: "fail",
              error: "layout shifted",
            },
          ],
        }),
      ]),
    );

    expect(shardMarkdown).toContain("# WPT VRT Shard Summary");
    expect(shardMarkdown).toContain("| Label | flexbox-1 |");
    expect(shardMarkdown).toContain("## Failures");
    expect(shardMarkdown).toContain("| Regressions | 0 |");
    expect(aggregateMarkdown).toContain("# WPT VRT Aggregate Summary");
    expect(aggregateMarkdown).toContain("| Shard | Modules | Passed | Failed | Regressions | Total | Pass Rate | Max Diff |");
    expect(aggregateMarkdown).toContain("| display | css-display | 1 | 1 | 0 | 2 | 50.00% | 0.0810 |");
    expect(aggregateMarkdown).toContain("## Top Failures");
    expect(aggregateMarkdown).toContain("css-display/run-in-001.html");
  });

  it("renders regression tables when baseline headroom is exhausted", () => {
    const shardMarkdown = renderWptVrtShardMarkdown(
      makeShardSummary({
        label: "display",
        shardName: "display",
        modules: ["css-display"],
        total: 2,
        expectedTotal: 39,
        passed: 2,
        failed: 0,
        regressionCount: 1,
        passRate: 1,
        maxDiffRatio: 0.021,
        moduleTotals: [
          { module: "css-display", total: 2, passed: 2, failed: 0, passRate: 1 },
        ],
        failures: [],
        regressions: [
          {
            relativePath: "css-display/display-contents-text-only-001.html",
            module: "css-display",
            diffRatio: 0.021,
            baselineDiffRatio: 0.009,
            regressionLimit: 0.019,
            headroom: -0.002,
            status: "pass",
          },
        ],
        closestToThreshold: [
          {
            relativePath: "css-display/display-contents-dynamic-multicol-001-inline.html",
            module: "css-display",
            diffRatio: 0.0183,
            baselineDiffRatio: 0.009,
            regressionLimit: 0.019,
            headroom: 0.0007,
            status: "pass",
          },
        ],
      }),
    );
    const aggregateMarkdown = renderWptVrtAggregateMarkdown(
      aggregateWptVrtSummaries([
        makeShardSummary({
          label: "display",
          shardName: "display",
          modules: ["css-display"],
          total: 2,
          expectedTotal: 39,
          passed: 2,
          failed: 0,
          regressionCount: 1,
          passRate: 1,
          maxDiffRatio: 0.021,
          moduleTotals: [
            { module: "css-display", total: 2, passed: 2, failed: 0, passRate: 1 },
          ],
          failures: [],
          regressions: [
            {
              relativePath: "css-display/display-contents-text-only-001.html",
              module: "css-display",
              diffRatio: 0.021,
              baselineDiffRatio: 0.009,
              regressionLimit: 0.019,
              headroom: -0.002,
              status: "pass",
            },
          ],
          closestToThreshold: [],
        }),
      ]),
    );

    expect(shardMarkdown).toContain("## Closest To Threshold");
    expect(shardMarkdown).toContain("## Regressions");
    expect(shardMarkdown).toContain("display-contents-text-only-001.html");
    expect(aggregateMarkdown).toContain("## Top Regressions");
    expect(aggregateMarkdown).toContain("display-contents-text-only-001.html");
  });
});
