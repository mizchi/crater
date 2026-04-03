import type { FlakerSelection, FlakerSummary } from "./flaker-config-contract.ts";

function escapeMarkdownCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

export function renderMarkdownSummary(summary: FlakerSummary): string {
  const lines: string[] = [];

  lines.push("# Flaker Config Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Workflow | ${escapeMarkdownCell(summary.workflow?.name ?? "unknown")} |`);
  lines.push(`| Nodes | ${summary.nodeCount} |`);
  lines.push(`| Tasks | ${summary.taskCount} |`);
  lines.push(`| Managed specs | ${summary.managedSpecs.length} |`);
  lines.push(`| Unmanaged specs | ${summary.unmanagedSpecs.length} |`);
  lines.push(`| Errors | ${summary.errors.length} |`);
  lines.push(`| Warnings | ${summary.warnings.length} |`);

  lines.push("");
  lines.push("## Tasks");
  lines.push("");
  lines.push("| Task | Node | Specs | Filter | Needs | Trigger | Srcs |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- |");
  for (const task of summary.tasks) {
    lines.push(
      `| ${escapeMarkdownCell(task.id)} | ${escapeMarkdownCell(task.node)} | ${escapeMarkdownCell(task.specs.join("<br>"))} | ${escapeMarkdownCell(task.grep ?? task.grepInvert ?? "")} | ${escapeMarkdownCell(task.needs.join(", "))} | ${escapeMarkdownCell(task.trigger ?? "")} | ${task.srcCount} |`,
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

  if (summary.unmanagedSpecs.length > 0) {
    lines.push("");
    lines.push("## Unmanaged Specs");
    lines.push("");
    for (const spec of summary.unmanagedSpecs) {
      lines.push(`- ${spec}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

export function renderAffectedTasksMarkdown(selection: FlakerSelection): string {
  const lines: string[] = [];
  lines.push("# Flaker Affected Tasks");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Changed paths | ${selection.changedPaths.length} |`);
  lines.push(`| Direct matches | ${selection.matchedTaskIds.length} |`);
  lines.push(`| Selected tasks | ${selection.selectedTaskIds.length} |`);
  lines.push(`| Unmatched paths | ${selection.unmatchedPaths.length} |`);

  if (selection.changedPaths.length > 0) {
    lines.push("");
    lines.push("## Changed Paths");
    lines.push("");
    for (const changedPath of selection.changedPaths) {
      lines.push(`- ${changedPath}`);
    }
  }

  lines.push("");
  lines.push("## Selected Tasks");
  lines.push("");
  lines.push("| Task | Included By | Match Reasons |");
  lines.push("| --- | --- | --- |");
  for (const task of selection.selectedTasks) {
    lines.push(
      `| ${escapeMarkdownCell(task.id)} | ${escapeMarkdownCell(task.includedBy.join(", "))} | ${escapeMarkdownCell(task.matchReasons.join("<br>"))} |`,
    );
  }

  if (selection.unmatchedPaths.length > 0) {
    lines.push("");
    lines.push("## Unmatched Paths");
    lines.push("");
    for (const changedPath of selection.unmatchedPaths) {
      lines.push(`- ${changedPath}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

export function renderTaskList(summary: FlakerSummary): string {
  const lines = summary.tasks.map((task) => {
    const filter = task.grep ?? task.grepInvert;
    const suffix = filter ? ` [grep=${filter}]` : "";
    return `${task.id}\t${task.specs.join(", ")}${suffix}`;
  });
  return lines.length > 0 ? `${lines.join("\n")}\n` : "";
}

export function renderAffectedTaskList(selection: FlakerSelection): string {
  const lines: string[] = [];
  for (const task of selection.selectedTasks) {
    const reasons = task.matchReasons.length > 0 ? task.matchReasons.join(", ") : "dependency";
    const includedBy = task.includedBy.length > 0
      ? ` [included-by=${task.includedBy.join(",")}]`
      : "";
    lines.push(`${task.id}\t${reasons}${includedBy}`);
  }
  for (const changedPath of selection.unmatchedPaths) {
    lines.push(`UNMATCHED\t${changedPath}`);
  }
  return lines.length > 0 ? `${lines.join("\n")}\n` : "";
}
