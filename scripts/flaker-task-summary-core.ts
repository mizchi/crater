import type {
  FlakerEvalReport,
  FlakerReasonReport,
  FlakerTaskSummaryReport,
} from "./flaker-task-summary-contract.ts";

export interface BuildFlakerTaskSummaryInput {
  taskId: string;
  workspaceDir: string;
  eval: FlakerEvalReport;
  reason: FlakerReasonReport;
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

function formatNumber(value: number | null): string {
  if (value == null) {
    return "N/A";
  }
  return `${value}`;
}

export function buildFlakerTaskSummaryReport(
  input: BuildFlakerTaskSummaryInput,
): FlakerTaskSummaryReport {
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    taskId: input.taskId,
    workspaceDir: input.workspaceDir,
    eval: input.eval,
    reason: input.reason,
  };
}

export function renderFlakerTaskSummaryMarkdown(summary: FlakerTaskSummaryReport): string {
  const lines: string[] = [];
  lines.push("# Flaker Task Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Task | ${escapeCell(summary.taskId)} |`);
  lines.push(`| Health score | ${summary.eval.healthScore} |`);
  lines.push(`| Workflow runs | ${summary.eval.dataSufficiency.totalRuns} |`);
  lines.push(`| Test results | ${summary.eval.dataSufficiency.totalResults} |`);
  lines.push(`| Unique tests | ${summary.eval.dataSufficiency.uniqueTests} |`);
  lines.push(`| Avg runs/test | ${summary.eval.dataSufficiency.avgRunsPerTest} |`);
  lines.push(`| Flaky tests | ${summary.eval.detection.flakyTests} |`);
  lines.push(`| True flaky | ${summary.eval.detection.trueFlakyTests} |`);
  lines.push(`| Quarantined | ${summary.eval.detection.quarantinedTests} |`);
  lines.push(`| New flaky | ${summary.eval.resolution.newFlaky} |`);
  lines.push(`| Resolved flaky | ${summary.eval.resolution.resolvedFlaky} |`);
  lines.push(`| Quarantine recommended | ${summary.reason.summary.quarantineRecommended} |`);
  lines.push(`| Urgent fixes | ${summary.reason.summary.urgentFixes} |`);

  if (summary.reason.classifications.length > 0) {
    lines.push("");
    lines.push("## Priority Tests");
    lines.push("");
    lines.push("| Test | Classification | Recommendation | Priority | Confidence |");
    lines.push("| --- | --- | --- | --- | --- |");
    for (const classification of summary.reason.classifications.slice(0, 5)) {
      lines.push(
        `| ${escapeCell(`${classification.suite} > ${classification.testName}`)} | ${escapeCell(classification.classification)} | ${escapeCell(classification.recommendation)} | ${escapeCell(classification.priority)} | ${classification.confidence.toFixed(2)} |`,
      );
    }
  }

  if (summary.reason.patterns.length > 0) {
    lines.push("");
    lines.push("## Patterns");
    lines.push("");
    for (const pattern of summary.reason.patterns.slice(0, 5)) {
      lines.push(`- ${pattern.severity.toUpperCase()}: ${pattern.description}`);
    }
  }

  if (summary.reason.riskPredictions.length > 0) {
    lines.push("");
    lines.push("## Risk Predictions");
    lines.push("");
    lines.push("| Test | Risk score | Reason |");
    lines.push("| --- | --- | --- |");
    for (const risk of summary.reason.riskPredictions.slice(0, 5)) {
      lines.push(
        `| ${escapeCell(`${risk.suite} > ${risk.testName}`)} | ${risk.riskScore} | ${escapeCell(risk.reason)} |`,
      );
    }
  }

  lines.push("");
  lines.push("## Windows");
  lines.push("");
  lines.push(`- Date range: ${summary.eval.dataSufficiency.firstDate ?? "N/A"} -> ${summary.eval.dataSufficiency.lastDate ?? "N/A"}`);
  lines.push(`- Avg MTTD: ${formatNumber(summary.eval.resolution.mttdDays)}`);
  lines.push(`- Avg MTTR: ${formatNumber(summary.eval.resolution.mttrDays)}`);
  return `${lines.join("\n")}\n`;
}
