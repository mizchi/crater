import { describe, expect, it } from "vitest";
import type { FlakerBatchSummary as BaseFlakerBatchSummary } from "@mizchi/flaker/reporting/flaker-batch-summary-core";
import {
  applyFlakerBatchVrtExtension,
  renderFlakerBatchVrtMarkdown,
} from "./flaker-batch-vrt-extension.ts";

describe("applyFlakerBatchVrtExtension", () => {
  it("adds VRT task metrics without owning the generic batch aggregate", () => {
    const baseSummary: BaseFlakerBatchSummary = {
      schemaVersion: 1,
      generatedAt: "2026-05-10T00:00:00.000Z",
      taskCount: 1,
      failedTasks: 0,
      flakyTasks: 0,
      healthyTasks: 1,
      totalTests: 10,
      tasks: [
        {
          taskId: "paint-vrt",
          totalTests: 10,
          failed: 0,
          flaky: 0,
          skipped: 0,
          healthScore: 90,
          newFlaky: 0,
          urgentFixes: 0,
          status: "ok",
        },
      ],
    };

    const summary = applyFlakerBatchVrtExtension(baseSummary, new Map([
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
    ]));

    expect(summary.generatedAt).toBe("2026-05-10T00:00:00.000Z");
    expect(summary.taskCount).toBe(2);
    expect(summary.failedTasks).toBe(1);
    expect(summary.healthyTasks).toBe(1);
    expect(summary.totalTests).toBe(10);
    expect(summary.vrtCssReports).toBe(1);
    expect(summary.vrtCssDeadRules).toBe(4);
    expect(summary.vrtCssTotalRules).toBe(10);
    expect(summary.tasks.map((task) => task.taskId)).toEqual(["paint-vrt", "wpt-vrt"]);
    expect(summary.tasks[0]?.status).toBe("failed");
    expect(summary.tasks[1]).toMatchObject({
      taskId: "wpt-vrt",
      totalTests: 0,
      failed: 0,
      status: "missing",
      vrtUnknown: 1,
      vrtMaxDiffRatio: 0.08,
    });
  });
});

describe("renderFlakerBatchVrtMarkdown", () => {
  it("renders the VRT extension columns on top of the batch summary", () => {
    const markdown = renderFlakerBatchVrtMarkdown({
      schemaVersion: 1,
      generatedAt: "2026-05-10T00:00:00.000Z",
      taskCount: 1,
      failedTasks: 1,
      flakyTasks: 0,
      healthyTasks: 0,
      totalTests: 10,
      vrtCssReports: 1,
      vrtCssDeadRules: 4,
      vrtCssTotalRules: 10,
      vrtCssUnusedRules: 1,
      vrtCssOverriddenRules: 1,
      vrtCssNoEffectRules: 2,
      tasks: [
        {
          taskId: "paint-vrt",
          totalTests: 10,
          failed: 0,
          flaky: 0,
          skipped: 0,
          status: "failed",
          vrtFailed: 1,
          vrtUnknown: 0,
          vrtMaxDiffRatio: 0.2,
          vrtCssDeadRules: 4,
          vrtCssTotalRules: 10,
        },
      ],
    });

    expect(markdown).toContain("| VRT CSS Rules (total/dead) | 10 / 4 |");
    expect(markdown).toContain("| VRT fail | VRT unk | VRT max diff | VRT CSS dead |");
    expect(markdown).toContain("| paint-vrt | failed | 10 | 0 | 0 | N/A | N/A | N/A | 1 | 0 | 0.2000 | 4/10 |");
  });
});
