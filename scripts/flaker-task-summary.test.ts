import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  collectFlakerTaskSummary,
  parseFlakerTaskSummaryArgs,
  renderFlakerTaskSummaryMarkdown,
  runFlakerTaskSummaryCli,
} from "./flaker-task-summary.ts";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const FLAKER_STAR = fs.readFileSync(path.join(REPO_ROOT, "flaker.star"), "utf8");

describe("parseFlakerTaskSummaryArgs", () => {
  it("parses task and output flags", () => {
    const args = parseFlakerTaskSummaryArgs([
      "--task",
      "paint-vrt",
      "--json",
      "out/summary.json",
      "--markdown",
      "out/summary.md",
    ]);

    expect(args).toMatchObject({
      taskId: "paint-vrt",
      jsonOutput: "out/summary.json",
      markdownOutput: "out/summary.md",
    });
  });
});

describe("collectFlakerTaskSummary", () => {
  it("runs eval and reason inside the task workspace", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-summary-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const invocations: Array<{ command: string; args: string[]; cwd: string }> = [];
    const summary = collectFlakerTaskSummary(
      parseFlakerTaskSummaryArgs([
        "--task",
        "paint-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
      ]),
      {
        repoRoot,
        spawnText: (command, args, options) => {
          invocations.push({ command, args, cwd: options.cwd });
          if (args.includes("eval")) {
            return {
              status: 0,
              stdout: JSON.stringify({
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
                  distribution: [{ range: "0-10%", count: 1 }],
                },
                resolution: {
                  resolvedFlaky: 1,
                  newFlaky: 1,
                  mttdDays: 0.5,
                  mttrDays: 1.5,
                },
                healthScore: 72,
              }),
            };
          }
          return {
            status: 0,
            stdout: JSON.stringify({
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
            }),
          };
        },
      },
    );

    expect(invocations).toEqual([
      {
        command: process.execPath,
        args: ["/tmp/flaker-cli.js", "eval", "--json"],
        cwd: path.join(repoRoot, ".flaker/tasks/paint-vrt"),
      },
      {
        command: process.execPath,
        args: ["/tmp/flaker-cli.js", "reason", "--json"],
        cwd: path.join(repoRoot, ".flaker/tasks/paint-vrt"),
      },
    ]);
    expect(summary.taskId).toBe("paint-vrt");
    expect(summary.eval.healthScore).toBe(72);
    expect(summary.reason.summary.totalAnalyzed).toBe(1);
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

describe("runFlakerTaskSummaryCli", () => {
  it("returns markdown stdout and optional artifact writes", () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-task-summary-cli-"));
    fs.writeFileSync(path.join(repoRoot, "flaker.star"), FLAKER_STAR, "utf8");

    const result = runFlakerTaskSummaryCli(
      [
        "--task",
        "paint-vrt",
        "--flaker-cli",
        "/tmp/flaker-cli.js",
        "--json",
        "out/summary.json",
        "--markdown",
        "out/summary.md",
      ],
      {
        repoRoot,
        spawnText: (_command, taskArgs) => {
          if (taskArgs.includes("eval")) {
            return {
              status: 0,
              stdout: JSON.stringify({
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
                  distribution: [{ range: "0-10%", count: 1 }],
                },
                resolution: {
                  resolvedFlaky: 1,
                  newFlaky: 1,
                  mttdDays: 0.5,
                  mttrDays: 1.5,
                },
                healthScore: 72,
              }),
            };
          }
          return {
            status: 0,
            stdout: JSON.stringify({
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
            }),
          };
        },
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("# Flaker Task Summary");
    expect(result.writes).toEqual([
      {
        path: path.resolve(repoRoot, "out/summary.md"),
        content: expect.stringContaining("# Flaker Task Summary"),
      },
      {
        path: path.resolve(repoRoot, "out/summary.json"),
        content: expect.stringContaining('"taskId": "paint-vrt"'),
      },
    ]);
  });
});
