import type { PlaywrightSummary } from "./playwright-report-contract.ts";
import type { FlakerTaskSummaryReport } from "./flaker-task-summary-contract.ts";

export interface FlakerBatchTaskSummary {
  taskId: string;
  totalTests: number;
  failed: number;
  flaky: number;
  skipped: number;
  healthScore?: number;
  newFlaky?: number;
  urgentFixes?: number;
  status: "ok" | "failed" | "missing";
}

export interface FlakerBatchSummary {
  schemaVersion: 1;
  generatedAt: string;
  taskCount: number;
  failedTasks: number;
  flakyTasks: number;
  healthyTasks: number;
  totalTests: number;
  tasks: FlakerBatchTaskSummary[];
}

export interface FlakerBatchSummaryInputs {
  playwrightSummaries: Map<string, PlaywrightSummary>;
  flakerSummaries: Map<string, FlakerTaskSummaryReport>;
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

export function buildFlakerBatchSummary(
  inputs: FlakerBatchSummaryInputs,
): FlakerBatchSummary {
  const taskIds = [
    ...new Set([
      ...inputs.playwrightSummaries.keys(),
      ...inputs.flakerSummaries.keys(),
    ]),
  ].sort();

  const tasks: FlakerBatchTaskSummary[] = taskIds.map((taskId) => {
    const playwrightSummary = inputs.playwrightSummaries.get(taskId);
    const flakerSummary = inputs.flakerSummaries.get(taskId);

    if (!playwrightSummary) {
      return {
        taskId,
        totalTests: 0,
        failed: 0,
        flaky: 0,
        skipped: 0,
        status: "missing",
      };
    }

    const failed =
      playwrightSummary.totals.failed
      + playwrightSummary.totals.timedout
      + playwrightSummary.totals.interrupted;

    return {
      taskId,
      totalTests: playwrightSummary.totals.total,
      failed,
      flaky: playwrightSummary.totals.flaky,
      skipped: playwrightSummary.totals.skipped,
      healthScore: flakerSummary?.eval.healthScore,
      newFlaky: flakerSummary?.eval.resolution.newFlaky,
      urgentFixes: flakerSummary?.reason.summary.urgentFixes,
      status: failed > 0 ? "failed" : "ok",
    };
  });

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    taskCount: tasks.length,
    failedTasks: tasks.filter((task) => task.status === "failed").length,
    flakyTasks: tasks.filter((task) => task.flaky > 0).length,
    healthyTasks: tasks.filter((task) => (task.healthScore ?? 0) >= 80).length,
    totalTests: tasks.reduce((sum, task) => sum + task.totalTests, 0),
    tasks,
  };
}

export function renderFlakerBatchSummaryMarkdown(
  summary: FlakerBatchSummary,
): string {
  const lines: string[] = [];
  lines.push("# Flaker Daily Batch Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Tasks | ${summary.taskCount} |`);
  lines.push(`| Failed tasks | ${summary.failedTasks} |`);
  lines.push(`| Flaky tasks | ${summary.flakyTasks} |`);
  lines.push(`| Healthy tasks | ${summary.healthyTasks} |`);
  lines.push(`| Total tests | ${summary.totalTests} |`);
  lines.push("");
  lines.push("| Task | Status | Total | Failed | Flaky | Health | New flaky | Urgent fixes |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const task of summary.tasks) {
    lines.push(
      `| ${escapeCell(task.taskId)} | ${task.status} | ${task.totalTests} | ${task.failed} | ${task.flaky} | ${task.healthScore ?? "N/A"} | ${task.newFlaky ?? "N/A"} | ${task.urgentFixes ?? "N/A"} |`,
    );
  }
  return `${lines.join("\n")}\n`;
}
