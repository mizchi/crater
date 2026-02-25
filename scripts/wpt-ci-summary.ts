#!/usr/bin/env npx tsx

import fs from "fs";
import path from "path";

export interface WptCompatShardReport {
  schemaVersion: 1;
  suite: string;
  target: string;
  passed: number;
  failed: number;
  errors: number;
  total: number;
  passRate: number;
  generatedAt: string;
}

export interface Counter {
  passed: number;
  failed: number;
  errors: number;
  total: number;
  passRate: number;
}

export interface AggregatedSummary {
  generatedAt: string;
  rows: WptCompatShardReport[];
  total: Counter;
  bySuite: Record<string, Counter>;
}

export interface CssBaseline {
  total: number;
  passed: number;
  failed: number;
  updatedAt?: string;
}

interface CliOptions {
  inputDir: string;
  jsonOutput?: string;
  markdownOutput?: string;
  baselineFile?: string;
}

const DEFAULT_INPUT_DIR = ".wpt-reports";
const DEFAULT_BASELINE_FILE = "tests/wpt-baseline.env";

function usage(): string {
  return [
    "WPT CI Summary generator",
    "",
    "Usage:",
    "  npx tsx scripts/wpt-ci-summary.ts [options]",
    "",
    "Options:",
    `  --input <dir>       Report directory (default: ${DEFAULT_INPUT_DIR})`,
    "  --json <file>       Write merged summary JSON",
    "  --markdown <file>   Write Markdown summary",
    `  --baseline <file>   CSS baseline env file (default: ${DEFAULT_BASELINE_FILE})`,
  ].join("\n");
}

function parseCliArgs(args: string[]): CliOptions {
  const options: CliOptions = {
    inputDir: DEFAULT_INPUT_DIR,
    baselineFile: DEFAULT_BASELINE_FILE,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--input") {
      options.inputDir = args[++i] ?? "";
      continue;
    }
    if (arg === "--json") {
      options.jsonOutput = args[++i];
      continue;
    }
    if (arg === "--markdown") {
      options.markdownOutput = args[++i];
      continue;
    }
    if (arg === "--baseline") {
      options.baselineFile = args[++i];
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.inputDir) {
    throw new Error("--input requires a directory path");
  }

  return options;
}

function formatPercent(rate: number): string {
  return `${(rate * 100).toFixed(2)}%`;
}

function addCounter(base: Counter, item: Pick<Counter, "passed" | "failed" | "errors" | "total">): Counter {
  const total = base.total + item.total;
  const passed = base.passed + item.passed;
  const failed = base.failed + item.failed;
  const errors = base.errors + item.errors;
  return {
    passed,
    failed,
    errors,
    total,
    passRate: total > 0 ? passed / total : 0,
  };
}

function emptyCounter(): Counter {
  return { passed: 0, failed: 0, errors: 0, total: 0, passRate: 0 };
}

function asNonNegativeInteger(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return 0;
  return Math.floor(value);
}

function maybeReport(value: unknown): WptCompatShardReport | null {
  if (typeof value !== "object" || value === null) return null;
  const row = value as Record<string, unknown>;
  if (row.schemaVersion !== 1) return null;
  if (typeof row.suite !== "string" || row.suite.length === 0) return null;
  if (typeof row.target !== "string" || row.target.length === 0) return null;

  const passed = asNonNegativeInteger(row.passed);
  const failed = asNonNegativeInteger(row.failed);
  const errors = asNonNegativeInteger(row.errors);
  const total = asNonNegativeInteger(row.total) || (passed + failed + errors);

  return {
    schemaVersion: 1,
    suite: row.suite,
    target: row.target,
    passed,
    failed,
    errors,
    total,
    passRate: total > 0 ? passed / total : 0,
    generatedAt: typeof row.generatedAt === "string" ? row.generatedAt : new Date().toISOString(),
  };
}

function collectJsonFilesRecursive(dir: string): string[] {
  if (!fs.existsSync(dir)) return [];
  const files: string[] = [];
  const stack: string[] = [dir];

  while (stack.length > 0) {
    const current = stack.pop()!;
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (entry.isFile() && entry.name.endsWith(".json")) {
        files.push(fullPath);
      }
    }
  }

  return files.sort();
}

export function loadReportsFromDir(inputDir: string): WptCompatShardReport[] {
  const files = collectJsonFilesRecursive(inputDir);
  const reports: WptCompatShardReport[] = [];

  for (const file of files) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(fs.readFileSync(file, "utf-8"));
    } catch {
      continue;
    }
    const report = maybeReport(parsed);
    if (report) {
      reports.push(report);
    }
  }

  return reports;
}

export function aggregateReports(reports: WptCompatShardReport[]): AggregatedSummary {
  const rows = [...reports].sort((a, b) => {
    if (a.suite === b.suite) return a.target.localeCompare(b.target);
    return a.suite.localeCompare(b.suite);
  });

  const bySuite: Record<string, Counter> = {};
  let total = emptyCounter();

  for (const row of rows) {
    total = addCounter(total, row);
    bySuite[row.suite] = addCounter(bySuite[row.suite] ?? emptyCounter(), row);
  }

  return {
    generatedAt: new Date().toISOString(),
    rows,
    total,
    bySuite,
  };
}

function withSign(value: number): string {
  if (value > 0) return `+${value}`;
  if (value < 0) return `${value}`;
  return "0";
}

export function parseCssBaselineEnv(content: string): CssBaseline | null {
  const totalMatch = content.match(/^BASELINE_TOTAL=(\d+)$/m);
  const passedMatch = content.match(/^BASELINE_PASSED=(\d+)$/m);
  const failedMatch = content.match(/^BASELINE_FAILED=(\d+)$/m);
  if (!totalMatch || !passedMatch || !failedMatch) return null;

  const updatedAtMatch = content.match(/^BASELINE_UPDATED_AT=(.+)$/m);
  return {
    total: Number(totalMatch[1]),
    passed: Number(passedMatch[1]),
    failed: Number(failedMatch[1]),
    updatedAt: updatedAtMatch?.[1],
  };
}

export function loadCssBaseline(filePath: string): CssBaseline | null {
  if (!fs.existsSync(filePath)) return null;
  const content = fs.readFileSync(filePath, "utf-8");
  return parseCssBaselineEnv(content);
}

export function renderMarkdownSummary(summary: AggregatedSummary, baseline?: CssBaseline | null): string {
  const lines: string[] = [];
  lines.push("# WPT Compatibility Summary");
  lines.push("");
  lines.push(`Generated at: ${summary.generatedAt}`);
  lines.push("");
  lines.push("| Suite | Target | Passed | Failed | Errors | Total | Pass Rate |");
  lines.push("| --- | --- | ---: | ---: | ---: | ---: | ---: |");

  for (const row of summary.rows) {
    lines.push(
      `| ${row.suite} | ${row.target} | ${row.passed} | ${row.failed} | ${row.errors} | ${row.total} | ${formatPercent(row.passRate)} |`
    );
  }

  lines.push(
    `| **TOTAL** | - | **${summary.total.passed}** | **${summary.total.failed}** | **${summary.total.errors}** | **${summary.total.total}** | **${formatPercent(summary.total.passRate)}** |`
  );
  lines.push("");

  lines.push("## Suite Totals");
  lines.push("");
  lines.push("| Suite | Passed | Failed | Errors | Total | Pass Rate |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: |");
  for (const [suite, counter] of Object.entries(summary.bySuite).sort(([a], [b]) => a.localeCompare(b))) {
    lines.push(
      `| ${suite} | ${counter.passed} | ${counter.failed} | ${counter.errors} | ${counter.total} | ${formatPercent(counter.passRate)} |`
    );
  }
  lines.push("");

  const cssTotals = summary.bySuite["wpt-css"];
  if (baseline && cssTotals) {
    const baselineRate = baseline.total > 0 ? baseline.passed / baseline.total : 0;
    lines.push("## Baseline delta (wpt-css)");
    lines.push("");
    lines.push(`- Baseline updated: ${baseline.updatedAt ?? "unknown"}`);
    lines.push(`- Passed: ${withSign(cssTotals.passed - baseline.passed)} (baseline=${baseline.passed}, current=${cssTotals.passed})`);
    lines.push(`- Failed: ${withSign(cssTotals.failed - baseline.failed)} (baseline=${baseline.failed}, current=${cssTotals.failed})`);
    lines.push(`- Total: ${withSign(cssTotals.total - baseline.total)} (baseline=${baseline.total}, current=${cssTotals.total})`);
    lines.push(`- Pass rate: ${(baselineRate * 100).toFixed(2)}% -> ${(cssTotals.passRate * 100).toFixed(2)}%`);
    lines.push("");
  }

  return lines.join("\n");
}

function ensureParentDir(filePath: string): void {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
}

export async function main(): Promise<number> {
  const options = parseCliArgs(process.argv.slice(2));
  const reports = loadReportsFromDir(options.inputDir);

  if (reports.length === 0) {
    console.error(`No compatible shard reports found in: ${options.inputDir}`);
    return 1;
  }

  const summary = aggregateReports(reports);
  const baseline = options.baselineFile ? loadCssBaseline(options.baselineFile) : null;
  const markdown = renderMarkdownSummary(summary, baseline);

  const summaryJson = {
    schemaVersion: 1,
    generatedAt: summary.generatedAt,
    reports: summary.rows,
    total: summary.total,
    bySuite: summary.bySuite,
    reportCount: summary.rows.length,
  };

  if (options.jsonOutput) {
    ensureParentDir(options.jsonOutput);
    fs.writeFileSync(options.jsonOutput, JSON.stringify(summaryJson, null, 2), "utf-8");
  }
  if (options.markdownOutput) {
    ensureParentDir(options.markdownOutput);
    fs.writeFileSync(options.markdownOutput, markdown + "\n", "utf-8");
  }

  console.log(markdown);
  return 0;
}

if (import.meta.main) {
  main().then((code) => {
    process.exitCode = code;
  }).catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
