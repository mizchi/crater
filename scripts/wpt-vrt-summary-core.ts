type WptVrtStatus = "pass" | "fail";

export interface WptVrtRawTestResult {
  diffRatio: number;
  status: WptVrtStatus;
  error?: string;
}

export interface WptVrtRawReport {
  schemaVersion?: 1;
  suite?: "wpt-vrt";
  generatedAt?: string;
  shard?: {
    name?: string;
    modules?: string[];
    offset?: number;
    limit?: number;
  };
  config?: {
    viewport?: { width: number; height: number };
    pixelmatchThreshold?: number;
    defaultMaxDiffRatio?: number;
  };
  summary?: {
    total?: number;
    passed?: number;
    failed?: number;
  };
  tests?: Record<string, WptVrtRawTestResult>;
}

export interface WptVrtModuleSummary {
  module: string;
  total: number;
  passed: number;
  failed: number;
  passRate: number;
}

export interface WptVrtFailureRow {
  relativePath: string;
  module: string;
  diffRatio: number;
  status: "fail";
  error?: string;
}

export interface WptVrtShardSummary {
  schemaVersion: 1;
  suite: "wpt-vrt";
  generatedAt: string;
  label: string;
  shardName: string;
  modules: string[];
  offset: number;
  limit: number;
  total: number;
  passed: number;
  failed: number;
  passRate: number;
  maxDiffRatio: number;
  moduleTotals: WptVrtModuleSummary[];
  failures: WptVrtFailureRow[];
}

export interface WptVrtAggregateTotals {
  total: number;
  passed: number;
  failed: number;
  passRate: number;
  shards: number;
}

export interface WptVrtAggregateSummary {
  schemaVersion: 1;
  suite: "wpt-vrt";
  generatedAt: string;
  rows: WptVrtShardSummary[];
  total: WptVrtAggregateTotals;
  byModule: WptVrtModuleSummary[];
  topFailures: Array<WptVrtFailureRow & { label: string }>;
}

function moduleNameFromRelativePath(relativePath: string): string {
  const [moduleName = "unknown"] = relativePath.split("/");
  return moduleName || "unknown";
}

function formatPercent(value: number): string {
  return `${(value * 100).toFixed(2)}%`;
}

function formatRatio(value: number): string {
  return value.toFixed(4);
}

function compareModule(a: WptVrtModuleSummary, b: WptVrtModuleSummary): number {
  if (b.failed !== a.failed) return b.failed - a.failed;
  if (a.module !== b.module) return a.module.localeCompare(b.module);
  return 0;
}

function compareFailure(
  a: WptVrtFailureRow | (WptVrtFailureRow & { label: string }),
  b: WptVrtFailureRow | (WptVrtFailureRow & { label: string }),
): number {
  if (b.diffRatio !== a.diffRatio) return b.diffRatio - a.diffRatio;
  return a.relativePath.localeCompare(b.relativePath);
}

export function asWptVrtShardSummary(value: unknown): WptVrtShardSummary | null {
  if (typeof value !== "object" || value === null) return null;
  const row = value as Record<string, unknown>;
  if (row.schemaVersion !== 1 || row.suite !== "wpt-vrt") return null;
  if (typeof row.label !== "string" || typeof row.shardName !== "string") return null;
  if (
    typeof row.total !== "number"
    || typeof row.passed !== "number"
    || typeof row.failed !== "number"
  ) {
    return null;
  }
  if (!Array.isArray(row.modules) || !Array.isArray(row.moduleTotals) || !Array.isArray(row.failures)) {
    return null;
  }
  return value as WptVrtShardSummary;
}

export function buildWptVrtShardSummary(
  report: WptVrtRawReport,
  label?: string,
): WptVrtShardSummary {
  const entries = Object.entries(report.tests ?? {}).sort(([a], [b]) => a.localeCompare(b));
  const moduleMap = new Map<string, { total: number; passed: number; failed: number }>();
  const failures: WptVrtFailureRow[] = [];
  let maxDiffRatio = 0;
  let passed = 0;
  let failed = 0;

  for (const [relativePath, result] of entries) {
    const module = moduleNameFromRelativePath(relativePath);
    const current = moduleMap.get(module) ?? { total: 0, passed: 0, failed: 0 };
    current.total += 1;
    if (result.status === "pass") {
      current.passed += 1;
      passed += 1;
    } else {
      current.failed += 1;
      failed += 1;
      failures.push({
        relativePath,
        module,
        diffRatio: result.diffRatio,
        status: "fail",
        ...(result.error ? { error: result.error } : {}),
      });
    }
    if (result.diffRatio > maxDiffRatio) {
      maxDiffRatio = result.diffRatio;
    }
    moduleMap.set(module, current);
  }

  const total = entries.length;
  const summaryPassed = report.summary?.passed ?? passed;
  const summaryFailed = report.summary?.failed ?? failed;
  const shardName = report.shard?.name ?? label ?? "wpt-vrt";
  const shardModules = report.shard?.modules ?? [];
  const moduleTotals = [...moduleMap.entries()]
    .map(([module, counts]) => ({
      module,
      total: counts.total,
      passed: counts.passed,
      failed: counts.failed,
      passRate: counts.total > 0 ? counts.passed / counts.total : 0,
    }))
    .sort(compareModule);

  return {
    schemaVersion: 1,
    suite: "wpt-vrt",
    generatedAt: report.generatedAt ?? new Date().toISOString(),
    label: label ?? shardName,
    shardName,
    modules: shardModules,
    offset: report.shard?.offset ?? 0,
    limit: report.shard?.limit ?? 0,
    total: report.summary?.total ?? total,
    passed: summaryPassed,
    failed: summaryFailed,
    passRate: total > 0 ? summaryPassed / total : 0,
    maxDiffRatio,
    moduleTotals,
    failures: failures.sort(compareFailure),
  };
}

export function aggregateWptVrtSummaries(
  rows: WptVrtShardSummary[],
): WptVrtAggregateSummary {
  const sortedRows = [...rows].sort((a, b) => a.label.localeCompare(b.label));
  const byModule = new Map<string, { total: number; passed: number; failed: number }>();
  const topFailures: Array<WptVrtFailureRow & { label: string }> = [];
  let total = 0;
  let passed = 0;
  let failed = 0;

  for (const row of sortedRows) {
    total += row.total;
    passed += row.passed;
    failed += row.failed;
    for (const moduleRow of row.moduleTotals) {
      const current = byModule.get(moduleRow.module) ?? { total: 0, passed: 0, failed: 0 };
      current.total += moduleRow.total;
      current.passed += moduleRow.passed;
      current.failed += moduleRow.failed;
      byModule.set(moduleRow.module, current);
    }
    for (const failure of row.failures) {
      topFailures.push({ ...failure, label: row.label });
    }
  }

  return {
    schemaVersion: 1,
    suite: "wpt-vrt",
    generatedAt: new Date().toISOString(),
    rows: sortedRows,
    total: {
      total,
      passed,
      failed,
      passRate: total > 0 ? passed / total : 0,
      shards: sortedRows.length,
    },
    byModule: [...byModule.entries()]
      .map(([module, counts]) => ({
        module,
        total: counts.total,
        passed: counts.passed,
        failed: counts.failed,
        passRate: counts.total > 0 ? counts.passed / counts.total : 0,
      }))
      .sort(compareModule),
    topFailures: topFailures.sort(compareFailure),
  };
}

export function renderWptVrtShardMarkdown(summary: WptVrtShardSummary): string {
  const lines: string[] = [];
  lines.push("# WPT VRT Shard Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Label | ${summary.label} |`);
  lines.push(`| Shard | ${summary.shardName} |`);
  lines.push(`| Modules | ${summary.modules.join(", ") || "-"} |`);
  lines.push(`| Passed | ${summary.passed} |`);
  lines.push(`| Failed | ${summary.failed} |`);
  lines.push(`| Total | ${summary.total} |`);
  lines.push(`| Pass Rate | ${formatPercent(summary.passRate)} |`);
  lines.push(`| Max Diff | ${formatRatio(summary.maxDiffRatio)} |`);

  lines.push("");
  lines.push("## Module Totals");
  lines.push("");
  lines.push("| Module | Passed | Failed | Total | Pass Rate |");
  lines.push("| --- | ---: | ---: | ---: | ---: |");
  for (const row of summary.moduleTotals) {
    lines.push(
      `| ${row.module} | ${row.passed} | ${row.failed} | ${row.total} | ${formatPercent(row.passRate)} |`,
    );
  }

  if (summary.failures.length > 0) {
    lines.push("");
    lines.push("## Failures");
    lines.push("");
    lines.push("| Test | Module | Diff Ratio | Error |");
    lines.push("| --- | --- | ---: | --- |");
    for (const failure of summary.failures) {
      lines.push(
        `| ${failure.relativePath} | ${failure.module} | ${formatRatio(failure.diffRatio)} | ${failure.error ?? ""} |`,
      );
    }
  }

  return `${lines.join("\n")}\n`;
}

export function renderWptVrtAggregateMarkdown(summary: WptVrtAggregateSummary): string {
  const lines: string[] = [];
  lines.push("# WPT VRT Aggregate Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Shards | ${summary.total.shards} |`);
  lines.push(`| Passed | ${summary.total.passed} |`);
  lines.push(`| Failed | ${summary.total.failed} |`);
  lines.push(`| Total | ${summary.total.total} |`);
  lines.push(`| Pass Rate | ${formatPercent(summary.total.passRate)} |`);

  lines.push("");
  lines.push("## Shards");
  lines.push("");
  lines.push("| Shard | Modules | Passed | Failed | Total | Pass Rate | Max Diff |");
  lines.push("| --- | --- | ---: | ---: | ---: | ---: | ---: |");
  for (const row of summary.rows) {
    lines.push(
      `| ${row.label} | ${row.modules.join(", ") || "-"} | ${row.passed} | ${row.failed} | ${row.total} | ${formatPercent(row.passRate)} | ${formatRatio(row.maxDiffRatio)} |`,
    );
  }

  lines.push("");
  lines.push("## Module Totals");
  lines.push("");
  lines.push("| Module | Passed | Failed | Total | Pass Rate |");
  lines.push("| --- | ---: | ---: | ---: | ---: |");
  for (const row of summary.byModule) {
    lines.push(
      `| ${row.module} | ${row.passed} | ${row.failed} | ${row.total} | ${formatPercent(row.passRate)} |`,
    );
  }

  if (summary.topFailures.length > 0) {
    lines.push("");
    lines.push("## Top Failures");
    lines.push("");
    lines.push("| Shard | Test | Module | Diff Ratio | Error |");
    lines.push("| --- | --- | --- | ---: | --- |");
    for (const failure of summary.topFailures.slice(0, 20)) {
      lines.push(
        `| ${failure.label} | ${failure.relativePath} | ${failure.module} | ${formatRatio(failure.diffRatio)} | ${failure.error ?? ""} |`,
      );
    }
  }

  return `${lines.join("\n")}\n`;
}
