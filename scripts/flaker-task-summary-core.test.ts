import { describe, expect, it } from "vitest";
import {
  buildFlakerTaskSummaryReport,
  renderFlakerTaskSummaryMarkdown,
} from "./flaker-task-summary-core.ts";

describe("buildFlakerTaskSummaryReport", () => {
  it("builds a report from eval and reason outputs", () => {
    const summary = buildFlakerTaskSummaryReport({
      taskId: "paint-vrt",
      workspaceDir: "/tmp/.flaker/tasks/paint-vrt",
      eval: {
        dataSufficiency: {
          totalRuns: 4,
          totalResults: 28,
          uniqueTests: 7,
          firstDate: "2026-04-01T00:00:00.000Z",
          lastDate: "2026-04-02T00:00:00.000Z",
          avgRunsPerTest: 4,
        },
        detection: {
          flakyTests: 2,
          trueFlakyTests: 1,
          quarantinedTests: 0,
          distribution: [],
        },
        resolution: {
          resolvedFlaky: 1,
          newFlaky: 1,
          mttdDays: 0.5,
          mttrDays: 1.5,
        },
        healthScore: 72,
      },
      reason: {
        classifications: [],
        patterns: [],
        riskPredictions: [],
        summary: {
          totalAnalyzed: 1,
          trueFlakyCount: 0,
          regressionCount: 0,
          quarantineRecommended: 0,
          urgentFixes: 0,
        },
      },
    });

    expect(summary).toMatchObject({
      schemaVersion: 1,
      taskId: "paint-vrt",
      workspaceDir: "/tmp/.flaker/tasks/paint-vrt",
    });
    expect(summary.generatedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });
});

describe("renderFlakerTaskSummaryMarkdown", () => {
  it("renders key eval and reason sections", () => {
    const markdown = renderFlakerTaskSummaryMarkdown({
      schemaVersion: 1,
      generatedAt: "2026-04-02T00:00:00.000Z",
      taskId: "paint-vrt",
      workspaceDir: "/tmp/.flaker/tasks/paint-vrt",
      eval: {
        dataSufficiency: {
          totalRuns: 4,
          totalResults: 28,
          uniqueTests: 7,
          firstDate: "2026-04-01T00:00:00.000Z",
          lastDate: "2026-04-02T00:00:00.000Z",
          avgRunsPerTest: 4,
        },
        detection: {
          flakyTests: 2,
          trueFlakyTests: 1,
          quarantinedTests: 0,
          distribution: [],
        },
        resolution: {
          resolvedFlaky: 1,
          newFlaky: 1,
          mttdDays: 0.5,
          mttrDays: 1.5,
        },
        healthScore: 72,
      },
      reason: {
        classifications: [
          {
            suite: "tests/paint-vrt.test.ts",
            testName: "fixture: cards",
            classification: "intermittent",
            confidence: 0.7,
            recommendation: "monitor",
            priority: "medium",
            evidence: ["passes on retry"],
          },
        ],
        patterns: [
          {
            type: "suite-instability",
            description: "Suite has multiple flaky tests",
            severity: "medium",
            affectedTests: ["fixture: cards"],
          },
        ],
        riskPredictions: [
          {
            suite: "tests/paint-vrt.test.ts",
            testName: "fixture: cards",
            riskScore: 55,
            reason: "recent failure",
          },
        ],
        summary: {
          totalAnalyzed: 1,
          trueFlakyCount: 0,
          regressionCount: 0,
          quarantineRecommended: 0,
          urgentFixes: 0,
        },
      },
    });

    expect(markdown).toContain("# Flaker Task Summary");
    expect(markdown).toContain("| Health score | 72 |");
    expect(markdown).toContain("## Priority Tests");
    expect(markdown).toContain("## Patterns");
    expect(markdown).toContain("## Risk Predictions");
  });
});
