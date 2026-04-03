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
      "--json",
      "out/summary.json",
      "--markdown",
      "out/summary.md",
    ]);

    expect(args).toMatchObject({
      inputDir: "nightly",
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
          status: "failed",
        },
      ],
    });

    expect(markdown).toContain("# Flaker Daily Batch Summary");
    expect(markdown).toContain("| Failed tasks | 1 |");
    expect(markdown).toContain("| paint-vrt | failed | 10 | 1 | 0 | 72 | 1 | 1 |");
  });
});

describe("runFlakerBatchSummaryCli", () => {
  it("returns markdown stdout and artifact writes", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-cli-"));
    fs.mkdirSync(path.join(root, "paint-vrt", "playwright-summary"), { recursive: true });
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

    const result = runFlakerBatchSummaryCli([
      "--input",
      root,
      "--json",
      "out/summary.json",
      "--markdown",
      "out/summary.md",
    ]);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Flaker Daily Batch Summary");
    expect(result.writes).toEqual([
      {
        path: path.resolve(process.cwd(), "out/summary.md"),
        content: expect.stringContaining("# Flaker Daily Batch Summary"),
      },
      {
        path: path.resolve(process.cwd(), "out/summary.json"),
        content: expect.stringContaining('"taskCount": 1'),
      },
    ]);
  });
});
