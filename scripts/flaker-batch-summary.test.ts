import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import type { PlaywrightSummary } from "./playwright-report-contract.ts";
import type { FlakerTaskSummaryReport } from "./flaker-task-summary-contract.ts";
import {
  parseFlakerBatchSummaryArgs,
  runFlakerBatchSummaryCli,
} from "./flaker-batch-summary.ts";
import {
  buildFlakerBatchSummary,
  renderFlakerBatchSummaryMarkdown,
} from "./flaker-batch-summary-core.ts";

describe("parseFlakerBatchSummaryArgs", () => {
  it("parses input and outputs", () => {
    const args = parseFlakerBatchSummaryArgs([
      "--input",
      "nightly",
      "--label",
      "nightly-summary",
      "--collect-task-id",
      "flaker-daily",
      "--json",
      "out/summary.json",
      "--markdown",
      "out/summary.md",
    ]);

    expect(args).toMatchObject({
      inputDir: "nightly",
      label: "nightly-summary",
      collectTaskId: "flaker-daily",
      jsonOutput: "out/summary.json",
      markdownOutput: "out/summary.md",
    });
  });
});

describe("buildFlakerBatchSummary", () => {
  it("aggregates task summaries from loaded reports", () => {
    const summary = buildFlakerBatchSummary({
      playwrightSummaries: new Map([
        ["paint-vrt", {
          totals: {
            total: 10,
            passed: 9,
            failed: 1,
            flaky: 0,
            skipped: 0,
            timedout: 0,
            interrupted: 0,
            unknown: 0,
            retries: 1,
            durationMs: 100,
          },
        } as PlaywrightSummary],
        ["wpt-vrt", {
          totals: {
            total: 20,
            passed: 20,
            failed: 0,
            flaky: 2,
            skipped: 0,
            timedout: 0,
            interrupted: 0,
            unknown: 0,
            retries: 2,
            durationMs: 200,
          },
        } as PlaywrightSummary],
      ]),
      flakerSummaries: new Map([
        ["paint-vrt", {
          eval: {
            healthScore: 72,
            resolution: { newFlaky: 1 },
          },
          reason: {
            summary: { urgentFixes: 1 },
          },
        } as FlakerTaskSummaryReport],
      ]),
      vrtSummaries: new Map([
        ["paint-vrt", {
          failed: 1,
          unknown: 0,
          maxDiffRatio: 0.2,
        }],
        ["wpt-vrt", {
          failed: 0,
          unknown: 1,
          maxDiffRatio: 0.08,
        }],
      ]),
    });

    expect(summary.taskCount).toBe(2);
    expect(summary.failedTasks).toBe(1);
    expect(summary.flakyTasks).toBe(1);
    expect(summary.totalTests).toBe(30);
    expect(summary.tasks).toEqual([
      {
        taskId: "paint-vrt",
        totalTests: 10,
        failed: 1,
        flaky: 0,
        skipped: 0,
        healthScore: 72,
        newFlaky: 1,
        urgentFixes: 1,
        vrtFailed: 1,
        vrtUnknown: 0,
        vrtMaxDiffRatio: 0.2,
        status: "failed",
      },
      {
        taskId: "wpt-vrt",
        totalTests: 20,
        failed: 0,
        flaky: 2,
        skipped: 0,
        healthScore: undefined,
        newFlaky: undefined,
        urgentFixes: undefined,
        vrtFailed: 0,
        vrtUnknown: 1,
        vrtMaxDiffRatio: 0.08,
        status: "ok",
      },
    ]);
  });
});

describe("renderFlakerBatchSummaryMarkdown", () => {
  it("renders aggregate overview", () => {
    const markdown = renderFlakerBatchSummaryMarkdown({
      schemaVersion: 1,
      generatedAt: "2026-04-02T00:00:00.000Z",
      taskCount: 2,
      failedTasks: 1,
      flakyTasks: 1,
      healthyTasks: 0,
      totalTests: 30,
      tasks: [
        {
          taskId: "paint-vrt",
          totalTests: 10,
          failed: 1,
          flaky: 0,
          skipped: 0,
          healthScore: 72,
          newFlaky: 1,
          urgentFixes: 1,
          vrtFailed: 1,
          vrtUnknown: 0,
          vrtMaxDiffRatio: 0.2,
          status: "failed",
        },
      ],
    });

    expect(markdown).toContain("# Flaker Daily Batch Summary");
    expect(markdown).toContain("| Failed tasks | 1 |");
    expect(markdown).toContain("| paint-vrt | failed | 10 | 1 | 0 | 72 | 1 | 1 | 1 | 0 | 0.2000 |");
  });
});

describe("runFlakerBatchSummaryCli", () => {
  it("returns markdown stdout, flat writes, and collect-compatible copies", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-cli-"));
    fs.mkdirSync(path.join(root, "paint-vrt", "playwright-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "paint-vrt", "vrt-summary"), { recursive: true });
    fs.writeFileSync(
      path.join(root, "paint-vrt", "playwright-summary", "paint-vrt.json"),
      JSON.stringify({
        totals: {
          total: 1,
          passed: 1,
          failed: 0,
          flaky: 0,
          skipped: 0,
          timedout: 0,
          interrupted: 0,
          unknown: 0,
          retries: 0,
          durationMs: 10,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(root, "paint-vrt", "vrt-summary", "paint-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact-summary",
        generatedAt: "2026-04-02T00:00:00.000Z",
        label: "paint-vrt",
        total: 2,
        budgeted: 2,
        passed: 1,
        failed: 1,
        unknown: 0,
        averageDiffRatio: 0.11,
        maxObservedDiffRatio: 0.2,
        rows: [],
        failures: [],
        closestToBudget: [],
      }),
      "utf8",
    );

    const result = runFlakerBatchSummaryCli([
      "--input",
      root,
      "--label",
      "nightly-summary",
      "--collect-task-id",
      "flaker-daily",
      "--json",
      "out/summary.json",
      "--markdown",
      "out/summary.md",
    ]);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Flaker Daily Batch Summary");
    expect(result.stdout).toContain("| paint-vrt | failed | 1 | 0 | 0 | N/A | N/A | N/A | 1 | 0 | 0.2000 |");
    expect(result.writes).toEqual([
      {
        path: path.resolve(process.cwd(), "out/summary.md"),
        content: expect.stringContaining("# Flaker Daily Batch Summary"),
      },
      {
        path: path.resolve(process.cwd(), "out/summary.json"),
        content: expect.stringContaining('"taskCount": 1'),
      },
      {
        path: path.resolve(process.cwd(), "out/flaker-daily/batch-summary/flaker-daily.md"),
        content: expect.stringContaining("# Flaker Daily Batch Summary"),
      },
      {
        path: path.resolve(process.cwd(), "out/flaker-daily/batch-summary/flaker-daily.json"),
        content: expect.stringContaining('"taskCount": 1'),
      },
    ]);
  });

  it("includes WPT VRT collect artifacts in batch VRT metrics", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-wpt-vrt-cli-"));
    fs.mkdirSync(path.join(root, "wpt-vrt", "playwright-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "wpt-vrt", "wpt-vrt-summary"), { recursive: true });
    fs.writeFileSync(
      path.join(root, "wpt-vrt", "playwright-summary", "wpt-vrt.json"),
      JSON.stringify({
        totals: {
          total: 2,
          passed: 1,
          failed: 1,
          flaky: 0,
          skipped: 0,
          timedout: 0,
          interrupted: 0,
          unknown: 0,
          retries: 0,
          durationMs: 10,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(root, "wpt-vrt", "wpt-vrt-summary", "wpt-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "wpt-vrt",
        generatedAt: "2026-04-02T00:00:00.000Z",
        label: "wpt-vrt",
        shardName: "wpt-vrt",
        modules: ["css-flexbox"],
        offset: 0,
        limit: 10,
        total: 2,
        expectedTotal: 3,
        passed: 1,
        failed: 1,
        regressionCount: 1,
        passRate: 0.5,
        maxDiffRatio: 0.08,
        moduleTotals: [
          {
            module: "css-flexbox",
            total: 2,
            passed: 1,
            failed: 1,
            passRate: 0.5,
          },
        ],
        failures: [
          {
            relativePath: "css-flexbox/gap-002.html",
            module: "css-flexbox",
            diffRatio: 0.08,
            status: "fail",
          },
        ],
        closestToThreshold: [],
        regressions: [],
      }),
      "utf8",
    );

    const result = runFlakerBatchSummaryCli([
      "--input",
      root,
    ]);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("| wpt-vrt | failed | 2 | 1 | 0 | N/A | N/A | N/A | 1 | 1 | 0.0800 |");
  });
});
