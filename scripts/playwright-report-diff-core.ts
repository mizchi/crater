import {
  isPlaywrightOutcomeUnstable,
  playwrightOutcomeSeverity,
  resolvePlaywrightTestIdentityKey,
  type PlaywrightOutcome,
  type PlaywrightSummary,
  type PlaywrightTestRow,
} from "./playwright-report-contract.ts";

export type PlaywrightDiffKind =
  | "new_failure"
  | "worsened_failure"
  | "new_flaky"
  | "resolved"
  | "improved"
  | "removed_unstable"
  | "persistent_failure"
  | "persistent_flaky";

export interface PlaywrightDiffRow {
  id: string;
  identityKey: string;
  file: string;
  title: string;
  projectName: string;
  kind: PlaywrightDiffKind;
  baseOutcome?: PlaywrightOutcome;
  headOutcome?: PlaywrightOutcome;
  baseAttempts: string[];
  headAttempts: string[];
}

export interface PlaywrightDiffTotals {
  baseTotal: number;
  headTotal: number;
  addedTests: number;
  removedTests: number;
  regressions: number;
  newFailures: number;
  worsenedFailures: number;
  newFlaky: number;
  improvements: number;
  resolved: number;
  improved: number;
  removedUnstable: number;
  persistentUnstable: number;
  persistentFailures: number;
  persistentFlaky: number;
}

export interface PlaywrightDiff {
  schemaVersion: 1;
  generatedAt: string;
  label: string;
  baseLabel: string;
  headLabel: string;
  baseSourceFile?: string;
  headSourceFile?: string;
  totals: PlaywrightDiffTotals;
  regressions: PlaywrightDiffRow[];
  improvements: PlaywrightDiffRow[];
  persistentUnstable: PlaywrightDiffRow[];
}

function createTotals(
  base: PlaywrightSummary,
  head: PlaywrightSummary,
): PlaywrightDiffTotals {
  return {
    baseTotal: base.tests.length,
    headTotal: head.tests.length,
    addedTests: 0,
    removedTests: 0,
    regressions: 0,
    newFailures: 0,
    worsenedFailures: 0,
    newFlaky: 0,
    improvements: 0,
    resolved: 0,
    improved: 0,
    removedUnstable: 0,
    persistentUnstable: 0,
    persistentFailures: 0,
    persistentFlaky: 0,
  };
}

function createRow(
  kind: PlaywrightDiffKind,
  baseRow: PlaywrightTestRow | undefined,
  headRow: PlaywrightTestRow | undefined,
): PlaywrightDiffRow {
  const row = headRow ?? baseRow;
  if (!row) {
    throw new Error("Diff row requires a base or head test row");
  }
  return {
    id: row.id,
    identityKey: resolvePlaywrightTestIdentityKey(row),
    file: row.file,
    title: row.title,
    projectName: row.projectName,
    kind,
    baseOutcome: baseRow?.outcome,
    headOutcome: headRow?.outcome,
    baseAttempts: [...(baseRow?.attempts ?? [])],
    headAttempts: [...(headRow?.attempts ?? [])],
  };
}

function compareRows(
  baseRow: PlaywrightTestRow | undefined,
  headRow: PlaywrightTestRow | undefined,
  totals: PlaywrightDiffTotals,
  regressions: PlaywrightDiffRow[],
  improvements: PlaywrightDiffRow[],
  persistentUnstable: PlaywrightDiffRow[],
): void {
  if (!baseRow && headRow) {
    totals.addedTests += 1;
    const headSeverity = playwrightOutcomeSeverity(headRow.outcome);
    if (headSeverity === 2) {
      totals.regressions += 1;
      totals.newFailures += 1;
      regressions.push(createRow("new_failure", undefined, headRow));
    } else if (headSeverity === 1) {
      totals.regressions += 1;
      totals.newFlaky += 1;
      regressions.push(createRow("new_flaky", undefined, headRow));
    }
    return;
  }

  if (baseRow && !headRow) {
    totals.removedTests += 1;
    if (isPlaywrightOutcomeUnstable(baseRow.outcome)) {
      totals.improvements += 1;
      totals.removedUnstable += 1;
      improvements.push(createRow("removed_unstable", baseRow, undefined));
    }
    return;
  }

  if (!baseRow || !headRow) {
    return;
  }

  const baseSeverity = playwrightOutcomeSeverity(baseRow.outcome);
  const headSeverity = playwrightOutcomeSeverity(headRow.outcome);

  if (headSeverity > baseSeverity) {
    totals.regressions += 1;
    if (headSeverity === 2 && baseSeverity === 1) {
      totals.worsenedFailures += 1;
      regressions.push(createRow("worsened_failure", baseRow, headRow));
    } else if (headSeverity === 2) {
      totals.newFailures += 1;
      regressions.push(createRow("new_failure", baseRow, headRow));
    } else {
      totals.newFlaky += 1;
      regressions.push(createRow("new_flaky", baseRow, headRow));
    }
    return;
  }

  if (headSeverity < baseSeverity) {
    totals.improvements += 1;
    if (headSeverity === 0) {
      totals.resolved += 1;
      improvements.push(createRow("resolved", baseRow, headRow));
    } else {
      totals.improved += 1;
      improvements.push(createRow("improved", baseRow, headRow));
    }
    return;
  }

  if (headSeverity === 0) {
    return;
  }

  totals.persistentUnstable += 1;
  if (headSeverity === 2) {
    totals.persistentFailures += 1;
    persistentUnstable.push(createRow("persistent_failure", baseRow, headRow));
  } else {
    totals.persistentFlaky += 1;
    persistentUnstable.push(createRow("persistent_flaky", baseRow, headRow));
  }
}

function compareId(a: { id: string }, b: { id: string }): number {
  return a.id.localeCompare(b.id);
}

export function buildPlaywrightDiff(
  base: PlaywrightSummary,
  head: PlaywrightSummary,
  label = head.label,
): PlaywrightDiff {
  const baseById = new Map(base.tests.map((row) => [resolvePlaywrightTestIdentityKey(row), row]));
  const headById = new Map(head.tests.map((row) => [resolvePlaywrightTestIdentityKey(row), row]));
  const ids = new Set([...baseById.keys(), ...headById.keys()]);

  const totals = createTotals(base, head);
  const regressions: PlaywrightDiffRow[] = [];
  const improvements: PlaywrightDiffRow[] = [];
  const persistentUnstable: PlaywrightDiffRow[] = [];

  for (const id of [...ids].sort()) {
    compareRows(
      baseById.get(id),
      headById.get(id),
      totals,
      regressions,
      improvements,
      persistentUnstable,
    );
  }

  regressions.sort(compareId);
  improvements.sort(compareId);
  persistentUnstable.sort(compareId);

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    label,
    baseLabel: base.label,
    headLabel: head.label,
    baseSourceFile: base.sourceFile,
    headSourceFile: head.sourceFile,
    totals,
    regressions,
    improvements,
    persistentUnstable,
  };
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

function outcomeLabel(outcome: PlaywrightOutcome | undefined): string {
  return outcome ?? "-";
}

function attemptsLabel(attempts: string[]): string {
  return attempts.length > 0 ? attempts.join(" -> ") : "-";
}

function renderRows(rows: PlaywrightDiffRow[]): string[] {
  const lines: string[] = [];
  lines.push("| Kind | Test | Base | Head | Base Attempts | Head Attempts |");
  lines.push("| --- | --- | --- | --- | --- | --- |");
  for (const row of rows) {
    lines.push(
      `| ${row.kind} | ${escapeCell(row.id)} | ${outcomeLabel(row.baseOutcome)} | ${outcomeLabel(row.headOutcome)} | ${escapeCell(attemptsLabel(row.baseAttempts))} | ${escapeCell(attemptsLabel(row.headAttempts))} |`,
    );
  }
  return lines;
}

export function renderPlaywrightDiffMarkdown(diff: PlaywrightDiff): string {
  const lines: string[] = [];
  lines.push("# Playwright Baseline Diff");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Label | ${escapeCell(diff.label)} |`);
  lines.push(`| Base | ${escapeCell(diff.baseLabel)} |`);
  lines.push(`| Head | ${escapeCell(diff.headLabel)} |`);
  if (diff.baseSourceFile) {
    lines.push(`| Base Source | ${escapeCell(diff.baseSourceFile)} |`);
  }
  if (diff.headSourceFile) {
    lines.push(`| Head Source | ${escapeCell(diff.headSourceFile)} |`);
  }
  lines.push(`| Base Total | ${diff.totals.baseTotal} |`);
  lines.push(`| Head Total | ${diff.totals.headTotal} |`);
  lines.push(`| Regressions | ${diff.totals.regressions} |`);
  lines.push(`| Improvements | ${diff.totals.improvements} |`);
  lines.push(`| Persistent Unstable | ${diff.totals.persistentUnstable} |`);
  lines.push(`| Added Tests | ${diff.totals.addedTests} |`);
  lines.push(`| Removed Tests | ${diff.totals.removedTests} |`);

  if (diff.regressions.length > 0) {
    lines.push("");
    lines.push("## Regressions");
    lines.push("");
    lines.push(...renderRows(diff.regressions));
  }

  if (diff.improvements.length > 0) {
    lines.push("");
    lines.push("## Improvements");
    lines.push("");
    lines.push(...renderRows(diff.improvements));
  }

  if (diff.persistentUnstable.length > 0) {
    lines.push("");
    lines.push("## Persistent Unstable");
    lines.push("");
    lines.push(...renderRows(diff.persistentUnstable));
  }

  return `${lines.join("\n")}\n`;
}
