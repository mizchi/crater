import type { PlaywrightSummary } from "./playwright-report-contract.ts";
import type { FlakerTaskSummaryReport } from "./flaker-task-summary-contract.ts";

export interface FlakerBatchVrtSummary {
  failed: number;
  unknown: number;
  maxDiffRatio: number;
  cssDeadRules?: number;
  cssTotalRules?: number;
  cssUnusedRules?: number;
  cssOverriddenRules?: number;
  cssNoEffectRules?: number;
}

export interface FlakerBatchTaskSummary {
  taskId: string;
  totalTests: number;
  failed: number;
  flaky: number;
  skipped: number;
  healthScore?: number;
  newFlaky?: number;
  urgentFixes?: number;
  vrtFailed?: number;
  vrtUnknown?: number;
  vrtMaxDiffRatio?: number;
  vrtCssDeadRules?: number;
  vrtCssTotalRules?: number;
  vrtCssUnusedRules?: number;
  vrtCssOverriddenRules?: number;
  vrtCssNoEffectRules?: number;
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
  vrtCssReports: number;
  vrtCssDeadRules: number;
  vrtCssTotalRules: number;
  vrtCssUnusedRules: number;
  vrtCssOverriddenRules: number;
  vrtCssNoEffectRules: number;
  tasks: FlakerBatchTaskSummary[];
}

export interface FlakerBatchSummaryInputs {
  playwrightSummaries: Map<string, PlaywrightSummary>;
  flakerSummaries: Map<string, FlakerTaskSummaryReport>;
  vrtSummaries: Map<string, FlakerBatchVrtSummary>;
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

function formatCssDead(deadRules?: number, totalRules?: number): string {
  return deadRules !== undefined && totalRules !== undefined
    ? `${deadRules}/${totalRules}`
    : "N/A";
}

export function buildFlakerBatchSummary(
  inputs: FlakerBatchSummaryInputs,
): FlakerBatchSummary {
  const taskIds = [
      ...new Set([
        ...inputs.playwrightSummaries.keys(),
        ...inputs.flakerSummaries.keys(),
        ...inputs.vrtSummaries.keys(),
      ]),
  ].sort();

  const tasks: FlakerBatchTaskSummary[] = taskIds.map((taskId) => {
    const playwrightSummary = inputs.playwrightSummaries.get(taskId);
    const flakerSummary = inputs.flakerSummaries.get(taskId);
    const vrtSummary = inputs.vrtSummaries.get(taskId);

    if (!playwrightSummary) {
      return {
        taskId,
        totalTests: 0,
        failed: 0,
        flaky: 0,
        skipped: 0,
        vrtFailed: vrtSummary?.failed,
        vrtUnknown: vrtSummary?.unknown,
        vrtMaxDiffRatio: vrtSummary?.maxDiffRatio,
        vrtCssDeadRules: vrtSummary?.cssDeadRules,
        vrtCssTotalRules: vrtSummary?.cssTotalRules,
        vrtCssUnusedRules: vrtSummary?.cssUnusedRules,
        vrtCssOverriddenRules: vrtSummary?.cssOverriddenRules,
        vrtCssNoEffectRules: vrtSummary?.cssNoEffectRules,
        status: "missing",
      };
    }

    const failed =
      playwrightSummary.totals.failed
      + playwrightSummary.totals.timedout
      + playwrightSummary.totals.interrupted;
    const vrtFailed = vrtSummary?.failed;

    return {
      taskId,
      totalTests: playwrightSummary.totals.total,
      failed,
      flaky: playwrightSummary.totals.flaky,
      skipped: playwrightSummary.totals.skipped,
      healthScore: flakerSummary?.eval.healthScore,
      newFlaky: flakerSummary?.eval.resolution.newFlaky,
      urgentFixes: flakerSummary?.reason.summary.urgentFixes,
      vrtFailed,
      vrtUnknown: vrtSummary?.unknown,
      vrtMaxDiffRatio: vrtSummary?.maxDiffRatio,
      vrtCssDeadRules: vrtSummary?.cssDeadRules,
      vrtCssTotalRules: vrtSummary?.cssTotalRules,
      vrtCssUnusedRules: vrtSummary?.cssUnusedRules,
      vrtCssOverriddenRules: vrtSummary?.cssOverriddenRules,
      vrtCssNoEffectRules: vrtSummary?.cssNoEffectRules,
      status: failed > 0 || (vrtFailed ?? 0) > 0 ? "failed" : "ok",
    };
  });

  const vrtCssRows = tasks.filter((task) =>
    task.vrtCssDeadRules !== undefined && task.vrtCssTotalRules !== undefined
  );

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    taskCount: tasks.length,
    failedTasks: tasks.filter((task) => task.status === "failed").length,
    flakyTasks: tasks.filter((task) => task.flaky > 0).length,
    healthyTasks: tasks.filter((task) => (task.healthScore ?? 0) >= 80).length,
    totalTests: tasks.reduce((sum, task) => sum + task.totalTests, 0),
    vrtCssReports: vrtCssRows.length,
    vrtCssDeadRules: vrtCssRows.reduce((sum, task) => sum + (task.vrtCssDeadRules ?? 0), 0),
    vrtCssTotalRules: vrtCssRows.reduce((sum, task) => sum + (task.vrtCssTotalRules ?? 0), 0),
    vrtCssUnusedRules: vrtCssRows.reduce((sum, task) => sum + (task.vrtCssUnusedRules ?? 0), 0),
    vrtCssOverriddenRules: vrtCssRows.reduce((sum, task) => sum + (task.vrtCssOverriddenRules ?? 0), 0),
    vrtCssNoEffectRules: vrtCssRows.reduce((sum, task) => sum + (task.vrtCssNoEffectRules ?? 0), 0),
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
  if (summary.vrtCssReports > 0) {
    lines.push(`| VRT CSS Reports | ${summary.vrtCssReports} |`);
    lines.push(`| VRT CSS Rules (total/dead) | ${summary.vrtCssTotalRules} / ${summary.vrtCssDeadRules} |`);
    lines.push(
      `| VRT CSS Unused / Overridden / No-Effect | ${summary.vrtCssUnusedRules} / ${summary.vrtCssOverriddenRules} / ${summary.vrtCssNoEffectRules} |`,
    );
  }
  lines.push("");
  lines.push("| Task | Status | Total | Failed | Flaky | Health | New flaky | Urgent fixes | VRT fail | VRT unk | VRT max diff | VRT CSS dead |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const task of summary.tasks) {
    lines.push(
      `| ${escapeCell(task.taskId)} | ${task.status} | ${task.totalTests} | ${task.failed} | ${task.flaky} | ${task.healthScore ?? "N/A"} | ${task.newFlaky ?? "N/A"} | ${task.urgentFixes ?? "N/A"} | ${task.vrtFailed ?? "N/A"} | ${task.vrtUnknown ?? "N/A"} | ${task.vrtMaxDiffRatio?.toFixed(4) ?? "N/A"} | ${formatCssDead(task.vrtCssDeadRules, task.vrtCssTotalRules)} |`,
    );
  }
  return `${lines.join("\n")}\n`;
}
