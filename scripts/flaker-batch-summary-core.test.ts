import { describe, expect, it } from "vitest";
import type { PlaywrightSummary } from "./playwright-report-contract.ts";
import type { FlakerTaskSummaryReport } from "./flaker-task-summary-contract.ts";
import {
  buildFlakerBatchSummary,
  renderFlakerBatchSummaryMarkdown,
} from "./flaker-batch-summary-core.ts";

describe("buildFlakerBatchSummary", () => {
  it("aggregates task summaries from prepared reports", () => {
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
          cssDeadRules: 4,
          cssTotalRules: 10,
          cssUnusedRules: 1,
          cssOverriddenRules: 1,
          cssNoEffectRules: 2,
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
        vrtCssDeadRules: 4,
        vrtCssTotalRules: 10,
        vrtCssUnusedRules: 1,
        vrtCssOverriddenRules: 1,
        vrtCssNoEffectRules: 2,
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
        vrtCssDeadRules: undefined,
        vrtCssTotalRules: undefined,
        vrtCssUnusedRules: undefined,
        vrtCssOverriddenRules: undefined,
        vrtCssNoEffectRules: undefined,
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
          vrtCssDeadRules: 4,
          vrtCssTotalRules: 10,
          status: "failed",
        },
      ],
      vrtCssReports: 1,
      vrtCssDeadRules: 4,
      vrtCssTotalRules: 10,
      vrtCssUnusedRules: 1,
      vrtCssOverriddenRules: 1,
      vrtCssNoEffectRules: 2,
    });

    expect(markdown).toContain("# Flaker Daily Batch Summary");
    expect(markdown).toContain("| Failed tasks | 1 |");
    expect(markdown).toContain("| VRT CSS Rules (total/dead) | 10 / 4 |");
    expect(markdown).toContain("| VRT CSS Unused / Overridden / No-Effect | 1 / 1 / 2 |");
    expect(markdown).toContain("| paint-vrt | failed | 10 | 1 | 0 | 72 | 1 | 1 | 1 | 0 | 0.2000 | 4/10 |");
  });
});
