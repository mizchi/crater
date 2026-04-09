import { describe, expect, it } from "vitest";
import {
  buildMergedWptVrtResultsReport,
  buildWptVrtResultsReport,
  collectWptVrtTests,
  createWptVrtBatches,
  type WptVrtConfig,
} from "./wpt-vrt-utils.ts";

const baseConfig: Omit<WptVrtConfig, "modules" | "limitPerModule"> = {
  viewport: { width: 800, height: 600 },
  pixelmatchThreshold: 0.3,
  defaultMaxDiffRatio: 0.15,
};

describe("collectWptVrtTests", () => {
  it("merges explicit tests after module slices without duplicates", () => {
    const config: WptVrtConfig = {
      ...baseConfig,
      modules: ["css-flexbox", "css-display"],
      limitPerModule: 1,
      explicitTests: [
        "wpt/css/css-flexbox/flexbox-whitespace-handling-001a.xhtml",
        "wpt/css/css-display/display-contents-inline-flex-001.html",
        "wpt/css/css-flexbox/flex-001.html",
      ],
    };

    const entries = collectWptVrtTests(config, (moduleName) => {
      if (moduleName === "css-flexbox") {
        return [
          "wpt/css/css-flexbox/flex-001.html",
          "wpt/css/css-flexbox/flex-002.html",
        ];
      }
      if (moduleName === "css-display") {
        return [
          "wpt/css/css-display/display-001.html",
          "wpt/css/css-display/display-002.html",
        ];
      }
      return [];
    });

    expect(entries.map((entry) => entry.relativePath)).toEqual([
      "css-flexbox/flex-001.html",
      "css-display/display-001.html",
      "css-flexbox/flexbox-whitespace-handling-001a.xhtml",
      "css-display/display-contents-inline-flex-001.html",
    ]);
  });

  it("infers module names for explicit tests outside the module list", () => {
    const config: WptVrtConfig = {
      ...baseConfig,
      modules: [],
      limitPerModule: 0,
      explicitTests: [
        "wpt/css/css-position/position-absolute-center-001.html",
      ],
    };

    const entries = collectWptVrtTests(config, () => []);

    expect(entries).toEqual([
      {
        testPath: "wpt/css/css-position/position-absolute-center-001.html",
        relativePath: "css-position/position-absolute-center-001.html",
        moduleName: "css-position",
      },
    ]);
  });
});

describe("createWptVrtBatches", () => {
  it("splits entries into fixed-size batches while preserving order", () => {
    const entries = [
      { testPath: "a", relativePath: "a", moduleName: "m" },
      { testPath: "b", relativePath: "b", moduleName: "m" },
      { testPath: "c", relativePath: "c", moduleName: "m" },
      { testPath: "d", relativePath: "d", moduleName: "m" },
      { testPath: "e", relativePath: "e", moduleName: "m" },
    ];

    expect(createWptVrtBatches(entries, 2)).toEqual([
      [entries[0], entries[1]],
      [entries[2], entries[3]],
      [entries[4]],
    ]);
  });

  it("returns a single batch when the batch size is larger than the input", () => {
    const entries = [
      { testPath: "a", relativePath: "a", moduleName: "m" },
      { testPath: "b", relativePath: "b", moduleName: "m" },
    ];

    expect(createWptVrtBatches(entries, 10)).toEqual([entries]);
  });
});

describe("buildWptVrtResultsReport", () => {
  it("annotates tests with baseline headroom and sorts closest thresholds first", () => {
    const report = buildWptVrtResultsReport({
      results: [
        {
          relativePath: "css-display/a.html",
          diffRatio: 0.12,
          status: "pass",
        },
        {
          relativePath: "css-display/b.html",
          diffRatio: 0.03,
          status: "pass",
        },
      ],
      expectedTotal: 39,
      shard: {
        name: "display",
        modules: ["css-display"],
        offset: 0,
        limit: 0,
      },
      config: {
        ...baseConfig,
        modules: ["css-display"],
        limitPerModule: 30,
      },
      baseline: {
        schemaVersion: 1,
        updatedAt: "2026-04-09T00:00:00.000Z",
        config: {
          viewport: baseConfig.viewport,
          pixelmatchThreshold: baseConfig.pixelmatchThreshold,
          defaultMaxDiffRatio: baseConfig.defaultMaxDiffRatio,
        },
        summary: {
          total: 2,
          passed: 2,
          failed: 0,
        },
        tests: {
          "css-display/a.html": { diffRatio: 0.115, status: "pass" },
          "css-display/b.html": { diffRatio: 0.01, status: "pass" },
        },
      },
      generatedAt: "2026-04-09T00:00:00.000Z",
    });

    expect(report.summary).toEqual({
      total: 2,
      expectedTotal: 39,
      passed: 2,
      failed: 0,
      regressions: 1,
    });
    expect(report.closestToThreshold.map((row) => row.relativePath)).toEqual([
      "css-display/b.html",
      "css-display/a.html",
    ]);
    expect(report.tests["css-display/a.html"]?.baselineDiffRatio).toBe(0.115);
    expect(report.tests["css-display/a.html"]?.regressionLimit).toBe(0.125);
    expect(report.tests["css-display/a.html"]?.headroom).toBeCloseTo(0.005, 10);
    expect(report.regressions).toEqual([
      {
        relativePath: "css-display/b.html",
        diffRatio: 0.03,
        baselineDiffRatio: 0.01,
        regressionLimit: 0.02,
        headroom: -0.009999999999999998,
        status: "pass",
      },
    ]);
  });

  it("falls back to the default diff threshold when no baseline is present", () => {
    const report = buildWptVrtResultsReport({
      results: [
        {
          relativePath: "css-display/c.html",
          diffRatio: 0.05,
          status: "pass",
        },
      ],
      expectedTotal: 1,
      shard: {
        name: "display",
        modules: ["css-display"],
        offset: 0,
        limit: 1,
      },
      config: {
        ...baseConfig,
        modules: ["css-display"],
        limitPerModule: 30,
      },
      generatedAt: "2026-04-09T00:00:00.000Z",
    });

    expect(report.closestToThreshold).toEqual([
      {
        relativePath: "css-display/c.html",
        diffRatio: 0.05,
        baselineDiffRatio: undefined,
        regressionLimit: 0.15,
        headroom: 0.09999999999999999,
        status: "pass",
      },
    ]);
    expect(report.tests["css-display/c.html"]).toEqual({
      diffRatio: 0.05,
      status: "pass",
    });
    expect(report.regressions).toEqual([]);
  });
});

describe("buildMergedWptVrtResultsReport", () => {
  const shard = {
    name: "display",
    modules: ["css-display"],
    offset: 0,
    limit: 0,
  } as const;
  const config: WptVrtConfig = {
    ...baseConfig,
    modules: ["css-display"],
    limitPerModule: 30,
  };

  it("merges prior shard results when the run id matches", () => {
    const existingReport = buildWptVrtResultsReport({
      results: [
        {
          relativePath: "css-display/a.html",
          diffRatio: 0.01,
          status: "pass",
        },
        {
          relativePath: "css-display/b.html",
          diffRatio: 0.02,
          status: "pass",
        },
      ],
      expectedTotal: 3,
      shard,
      config,
      generatedAt: "2026-04-09T00:00:00.000Z",
      runId: "run-1",
    });

    const report = buildMergedWptVrtResultsReport({
      currentResults: [
        {
          relativePath: "css-display/b.html",
          diffRatio: 0.03,
          status: "fail",
          error: "latest batch result wins",
        },
        {
          relativePath: "css-display/c.html",
          diffRatio: 0.04,
          status: "pass",
        },
      ],
      existingReport,
      expectedTotal: 3,
      shard,
      config,
      generatedAt: "2026-04-09T00:01:00.000Z",
      runId: "run-1",
    });

    expect(report.runId).toBe("run-1");
    expect(report.summary).toEqual({
      total: 3,
      expectedTotal: 3,
      passed: 2,
      failed: 1,
      regressions: 0,
    });
    expect(Object.keys(report.tests)).toEqual([
      "css-display/a.html",
      "css-display/b.html",
      "css-display/c.html",
    ]);
    expect(report.tests["css-display/b.html"]).toEqual({
      diffRatio: 0.03,
      status: "fail",
      error: "latest batch result wins",
    });
  });

  it("ignores stale reports from a different run id", () => {
    const existingReport = buildWptVrtResultsReport({
      results: [
        {
          relativePath: "css-display/a.html",
          diffRatio: 0.01,
          status: "pass",
        },
      ],
      expectedTotal: 2,
      shard,
      config,
      generatedAt: "2026-04-09T00:00:00.000Z",
      runId: "run-old",
    });

    const report = buildMergedWptVrtResultsReport({
      currentResults: [
        {
          relativePath: "css-display/b.html",
          diffRatio: 0.02,
          status: "pass",
        },
      ],
      existingReport,
      expectedTotal: 2,
      shard,
      config,
      generatedAt: "2026-04-09T00:01:00.000Z",
      runId: "run-new",
    });

    expect(report.summary.total).toBe(1);
    expect(report.tests).toEqual({
      "css-display/b.html": {
        diffRatio: 0.02,
        status: "pass",
      },
    });
  });
});
