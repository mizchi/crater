import {
  readVrtArtifactDurationMs,
  readVrtArtifactIdentity,
  readVrtArtifactIdentityKey,
  readVrtArtifactMetrics,
  readVrtArtifactStatus,
  type VrtStableIdentity,
  type VrtArtifactRawReport,
} from "./vrt-report-contract.ts";

export interface LoadedVrtArtifactReport {
  label: string;
  reportPath: string;
  report: VrtArtifactRawReport;
}

export type VrtArtifactBudgetStatus = "pass" | "fail" | "unknown";

export interface VrtArtifactSummaryRow {
  label: string;
  reportPath: string;
  status: VrtArtifactBudgetStatus;
  diffRatio: number;
  maxDiffRatio?: number;
  headroom?: number;
  threshold?: number;
  width?: number;
  height?: number;
  diffPixels?: number;
  totalPixels?: number;
  maskPixels?: number;
  durationMs?: number;
  identityKey?: string;
  identity?: VrtStableIdentity;
  backend?: string;
  snapshotKind?: string;
}

export interface VrtArtifactSummary {
  schemaVersion: 1;
  suite: "vrt-artifact-summary";
  generatedAt: string;
  label: string;
  total: number;
  budgeted: number;
  passed: number;
  failed: number;
  unknown: number;
  averageDiffRatio: number;
  maxObservedDiffRatio: number;
  rows: VrtArtifactSummaryRow[];
  failures: VrtArtifactSummaryRow[];
  closestToBudget: VrtArtifactSummaryRow[];
}

function compareRows(a: VrtArtifactSummaryRow, b: VrtArtifactSummaryRow): number {
  const severity = (status: VrtArtifactBudgetStatus): number => {
    if (status === "fail") return 0;
    if (status === "pass") return 1;
    return 2;
  };
  const severityDiff = severity(a.status) - severity(b.status);
  if (severityDiff !== 0) {
    return severityDiff;
  }
  const aDistance = a.headroom === undefined ? Number.POSITIVE_INFINITY : Math.abs(a.headroom);
  const bDistance = b.headroom === undefined ? Number.POSITIVE_INFINITY : Math.abs(b.headroom);
  if (aDistance !== bDistance) {
    return aDistance - bDistance;
  }
  if (b.diffRatio !== a.diffRatio) {
    return b.diffRatio - a.diffRatio;
  }
  return a.label.localeCompare(b.label);
}

function compareFailures(a: VrtArtifactSummaryRow, b: VrtArtifactSummaryRow): number {
  if (b.diffRatio !== a.diffRatio) {
    return b.diffRatio - a.diffRatio;
  }
  return a.label.localeCompare(b.label);
}

function compareClosestToBudget(a: VrtArtifactSummaryRow, b: VrtArtifactSummaryRow): number {
  const aDistance = Math.abs(a.headroom ?? Number.POSITIVE_INFINITY);
  const bDistance = Math.abs(b.headroom ?? Number.POSITIVE_INFINITY);
  if (aDistance !== bDistance) {
    return aDistance - bDistance;
  }
  if (a.status !== b.status) {
    return a.status === "fail" ? -1 : 1;
  }
  if (b.diffRatio !== a.diffRatio) {
    return b.diffRatio - a.diffRatio;
  }
  return a.label.localeCompare(b.label);
}

function formatRatio(value: number | undefined): string {
  return typeof value === "number" ? value.toFixed(4) : "";
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

function resolveBudgetStatus(report: VrtArtifactRawReport): {
  status: VrtArtifactBudgetStatus;
  headroom?: number;
  maxDiffRatio?: number;
} {
  const metrics = readVrtArtifactMetrics(report);
  const diffRatio = metrics?.diffRatio;
  const maxDiffRatio = metrics?.maxDiffRatio;
  const status = readVrtArtifactStatus(report);
  if (diffRatio === undefined || maxDiffRatio === undefined) {
    return { status };
  }
  const headroom = maxDiffRatio - diffRatio;
  return {
    status,
    headroom,
    maxDiffRatio,
  };
}

export function buildVrtArtifactSummary(
  reports: LoadedVrtArtifactReport[],
  label: string,
): VrtArtifactSummary {
  const rows: VrtArtifactSummaryRow[] = reports.map(({ label: reportLabel, reportPath, report }) => {
    const metrics = readVrtArtifactMetrics(report);
    const diffRatio = metrics?.diffRatio ?? 0;
    const budget = resolveBudgetStatus(report);
    return {
      label: reportLabel,
      reportPath,
      status: budget.status,
      diffRatio,
      maxDiffRatio: budget.maxDiffRatio,
      headroom: budget.headroom,
      threshold: metrics?.threshold,
      width: metrics?.width,
      height: metrics?.height,
      diffPixels: metrics?.diffPixels,
      totalPixels: metrics?.totalPixels,
      maskPixels: metrics?.maskPixels,
      durationMs: readVrtArtifactDurationMs(report),
      identityKey: readVrtArtifactIdentityKey(report),
      identity: readVrtArtifactIdentity(report),
      backend: metrics?.backend,
      snapshotKind: metrics?.snapshotKind,
    };
  }).sort(compareRows);

  const total = rows.length;
  const passed = rows.filter((row) => row.status === "pass").length;
  const failed = rows.filter((row) => row.status === "fail").length;
  const unknown = rows.filter((row) => row.status === "unknown").length;
  const budgeted = passed + failed;
  const averageDiffRatio = total === 0
    ? 0
    : rows.reduce((sum, row) => sum + row.diffRatio, 0) / total;
  const maxObservedDiffRatio = rows.reduce(
    (max, row) => Math.max(max, row.diffRatio),
    0,
  );
  const failures = rows.filter((row) => row.status === "fail").sort(compareFailures);
  const closestToBudget = rows
    .filter((row) => row.headroom !== undefined)
    .sort(compareClosestToBudget);

  return {
    schemaVersion: 1,
    suite: "vrt-artifact-summary",
    generatedAt: new Date().toISOString(),
    label,
    total,
    budgeted,
    passed,
    failed,
    unknown,
    averageDiffRatio,
    maxObservedDiffRatio,
    rows,
    failures,
    closestToBudget,
  };
}

export function renderVrtArtifactSummaryMarkdown(summary: VrtArtifactSummary): string {
  const reportLimit = 25;
  const failureLimit = 25;
  const closestLimit = 10;
  const lines: string[] = [];
  lines.push("# VRT Artifact Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Label | ${escapeCell(summary.label)} |`);
  lines.push(`| Total Reports | ${summary.total} |`);
  lines.push(`| Budgeted Reports | ${summary.budgeted} |`);
  lines.push(`| Passed | ${summary.passed} |`);
  lines.push(`| Failed | ${summary.failed} |`);
  lines.push(`| Unknown Budget | ${summary.unknown} |`);
  lines.push(`| Average Diff Ratio | ${formatRatio(summary.averageDiffRatio)} |`);
  lines.push(`| Max Diff Ratio | ${formatRatio(summary.maxObservedDiffRatio)} |`);

  lines.push("");
  lines.push("## Priority Reports");
  lines.push("");
  if (summary.rows.length > reportLimit) {
    lines.push(`Showing first ${reportLimit} of ${summary.rows.length} reports, ordered by severity and budget headroom.`);
    lines.push("");
  }
  lines.push("| Target | Status | Diff | Budget | Headroom | Threshold | Size |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- |");
  if (summary.rows.length === 0) {
    lines.push("| _(none)_ |  |  |  |  |  |  |");
  } else {
    for (const row of summary.rows.slice(0, reportLimit)) {
      const size = row.width && row.height ? `${row.width}x${row.height}` : "";
      lines.push(
        `| ${escapeCell(row.label)} | ${row.status} | ${formatRatio(row.diffRatio)} | ${formatRatio(row.maxDiffRatio)} | ${formatRatio(row.headroom)} | ${formatRatio(row.threshold)} | ${size} |`,
      );
    }
  }

  if (summary.failures.length > 0) {
    lines.push("");
    lines.push("## Over Budget");
    lines.push("");
    if (summary.failures.length > failureLimit) {
      lines.push(`Showing first ${failureLimit} of ${summary.failures.length} over-budget reports.`);
      lines.push("");
    }
    lines.push("| Target | Diff | Budget | Headroom |");
    lines.push("| --- | --- | --- | --- |");
    for (const row of summary.failures.slice(0, failureLimit)) {
      lines.push(
        `| ${escapeCell(row.label)} | ${formatRatio(row.diffRatio)} | ${formatRatio(row.maxDiffRatio)} | ${formatRatio(row.headroom)} |`,
      );
    }
  }

  if (summary.closestToBudget.length > 0) {
    lines.push("");
    lines.push("## Closest To Budget");
    lines.push("");
    lines.push("| Target | Status | Diff | Budget | Headroom |");
    lines.push("| --- | --- | --- | --- | --- |");
    for (const row of summary.closestToBudget.slice(0, closestLimit)) {
      lines.push(
        `| ${escapeCell(row.label)} | ${row.status} | ${formatRatio(row.diffRatio)} | ${formatRatio(row.maxDiffRatio)} | ${formatRatio(row.headroom)} |`,
      );
    }
  }

  return `${lines.join("\n")}\n`;
}
