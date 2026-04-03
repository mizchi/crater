import type { FlakerQuarantineSummary } from "./flaker-quarantine-contract.ts";

function escapeMarkdownCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

export function renderQuarantineMarkdown(summary: FlakerQuarantineSummary): string {
  const lines: string[] = [];
  lines.push("# Flaker Quarantine Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Entries | ${summary.entryCount} |`);
  lines.push(`| Errors | ${summary.errors.length} |`);
  lines.push(`| Warnings | ${summary.warnings.length} |`);
  lines.push(`| Skip | ${summary.modeCounts.skip} |`);
  lines.push(`| Allow flaky | ${summary.modeCounts.allow_flaky} |`);
  lines.push(`| Allow failure | ${summary.modeCounts.allow_failure} |`);
  lines.push(`| Environment | ${summary.scopeCounts.environment} |`);
  lines.push(`| Flaky | ${summary.scopeCounts.flaky} |`);
  lines.push(`| Expected failure | ${summary.scopeCounts.expected_failure} |`);

  lines.push("");
  lines.push("## Entries");
  lines.push("");
  lines.push("| Id | Task | Spec | Pattern | Mode | Scope | Owner | Expires | Status |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const entry of summary.entries) {
    lines.push(
      `| ${escapeMarkdownCell(entry.id)} | ${escapeMarkdownCell(entry.taskId)} | ${escapeMarkdownCell(entry.spec)} | ${escapeMarkdownCell(entry.titlePattern)} | ${entry.mode} | ${entry.scope} | ${escapeMarkdownCell(entry.owner)} | ${entry.expiresAt} | ${entry.expiryStatus} |`,
    );
  }

  if (summary.errors.length > 0) {
    lines.push("");
    lines.push("## Errors");
    lines.push("");
    lines.push("| Code | Message |");
    lines.push("| --- | --- |");
    for (const issue of summary.errors) {
      lines.push(`| ${escapeMarkdownCell(issue.code)} | ${escapeMarkdownCell(issue.message)} |`);
    }
  }

  if (summary.warnings.length > 0) {
    lines.push("");
    lines.push("## Warnings");
    lines.push("");
    lines.push("| Code | Message |");
    lines.push("| --- | --- |");
    for (const issue of summary.warnings) {
      lines.push(`| ${escapeMarkdownCell(issue.code)} | ${escapeMarkdownCell(issue.message)} |`);
    }
  }

  return `${lines.join("\n")}\n`;
}
