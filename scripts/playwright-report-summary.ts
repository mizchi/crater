#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export interface PlaywrightJsonResultError {
  message?: string;
  value?: string;
}

export interface PlaywrightJsonResult {
  retry?: number;
  workerIndex?: number;
  status?: string;
  duration?: number;
  startTime?: string;
  errors?: PlaywrightJsonResultError[];
}

export interface PlaywrightJsonTest {
  projectName?: string;
  projectId?: string;
  expectedStatus?: string;
  status?: string;
  annotations?: Array<{ type?: string; description?: string }>;
  results?: PlaywrightJsonResult[];
}

export interface PlaywrightJsonSpec {
  title?: string;
  ok?: boolean;
  file?: string;
  line?: number;
  column?: number;
  tags?: string[];
  tests?: PlaywrightJsonTest[];
}

export interface PlaywrightJsonSuite {
  title?: string;
  file?: string;
  line?: number;
  column?: number;
  specs?: PlaywrightJsonSpec[];
  suites?: PlaywrightJsonSuite[];
}

export interface PlaywrightJsonReport {
  config?: unknown;
  suites?: PlaywrightJsonSuite[];
  errors?: PlaywrightJsonResultError[];
  stats?: {
    startTime?: string;
    duration?: number;
    expected?: number;
    skipped?: number;
    unexpected?: number;
    flaky?: number;
  };
}

export type PlaywrightOutcome =
  | "passed"
  | "failed"
  | "flaky"
  | "skipped"
  | "timedout"
  | "interrupted"
  | "unknown";

export interface PlaywrightTestRow {
  id: string;
  file: string;
  title: string;
  titlePath: string[];
  projectName: string;
  expectedStatus: string;
  rawStatus: string;
  outcome: PlaywrightOutcome;
  attempts: string[];
  retryCount: number;
  durationMs: number;
  errorMessages: string[];
}

export interface PlaywrightFileSummary {
  file: string;
  total: number;
  passed: number;
  failed: number;
  flaky: number;
  skipped: number;
  retries: number;
  durationMs: number;
}

export interface PlaywrightSummaryTotals {
  total: number;
  passed: number;
  failed: number;
  flaky: number;
  skipped: number;
  timedout: number;
  interrupted: number;
  unknown: number;
  retries: number;
  durationMs: number;
}

export interface PlaywrightSummary {
  schemaVersion: 1;
  generatedAt: string;
  label: string;
  sourceFile?: string;
  totals: PlaywrightSummaryTotals;
  files: PlaywrightFileSummary[];
  tests: PlaywrightTestRow[];
}

interface CliOptions {
  input: string;
  label?: string;
  jsonOutput?: string;
  markdownOutput?: string;
}

const DEFAULT_INPUT = "playwright-report.json";

function usage(): string {
  return [
    "Playwright Report Summary",
    "",
    "Usage:",
    "  npx tsx scripts/playwright-report-summary.ts [options]",
    "",
    "Options:",
    `  --input <file>      Playwright JSON report (default: ${DEFAULT_INPUT})`,
    "  --label <name>      Summary label shown in markdown/json",
    "  --json <file>       Write normalized summary JSON",
    "  --markdown <file>   Write markdown summary",
    "  --help              Show this help",
  ].join("\n");
}

function parseCliArgs(args: string[]): CliOptions {
  const options: CliOptions = { input: DEFAULT_INPUT };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--input") {
      options.input = args[++i] ?? "";
      continue;
    }
    if (arg === "--label") {
      options.label = args[++i];
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
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.input) {
    throw new Error("--input is required");
  }

  return options;
}

function writeOutput(filePath: string, content: string): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, "utf8");
}

function asArray<T>(value: T[] | undefined | null): T[] {
  return Array.isArray(value) ? value : [];
}

function pickFile(
  candidates: Array<string | undefined>,
  fallback: string,
): string {
  for (const candidate of candidates) {
    if (candidate && candidate.trim().length > 0) {
      return candidate;
    }
  }
  return fallback;
}

function basenameWithoutExt(filePath: string): string {
  const base = path.basename(filePath);
  return base.replace(/\.[^.]+$/, "");
}

function normalizeAttemptStatus(status: string | undefined): string {
  const normalized = (status ?? "").trim().toLowerCase();
  if (!normalized) return "unknown";
  return normalized;
}

function normalizeOutcome(
  rawStatus: string,
  attemptStatuses: string[],
): PlaywrightOutcome {
  if (rawStatus === "skipped") return "skipped";
  if (rawStatus === "flaky") return "flaky";

  if (attemptStatuses.includes("timedout")) return "timedout";
  if (attemptStatuses.includes("interrupted")) return "interrupted";

  const finalAttempt = attemptStatuses.at(-1) ?? "unknown";
  if (finalAttempt === "skipped") return "skipped";
  if (finalAttempt === "passed") {
    const unique = new Set(attemptStatuses);
    return unique.size > 1 ? "flaky" : "passed";
  }
  if (finalAttempt === "failed") return "failed";
  if (finalAttempt === "timedout") return "timedout";
  if (finalAttempt === "interrupted") return "interrupted";
  return "unknown";
}

function pushCount(totals: PlaywrightSummaryTotals, outcome: PlaywrightOutcome): void {
  totals.total += 1;
  if (outcome === "passed") totals.passed += 1;
  else if (outcome === "failed") totals.failed += 1;
  else if (outcome === "flaky") totals.flaky += 1;
  else if (outcome === "skipped") totals.skipped += 1;
  else if (outcome === "timedout") totals.timedout += 1;
  else if (outcome === "interrupted") totals.interrupted += 1;
  else totals.unknown += 1;
}

function createEmptyTotals(): PlaywrightSummaryTotals {
  return {
    total: 0,
    passed: 0,
    failed: 0,
    flaky: 0,
    skipped: 0,
    timedout: 0,
    interrupted: 0,
    unknown: 0,
    retries: 0,
    durationMs: 0,
  };
}

function rowId(file: string, titlePath: string[], projectName: string): string {
  const base = `${file}::${titlePath.join(" > ")}`;
  return projectName ? `${base} [${projectName}]` : base;
}

function collectRowsFromSuite(
  suite: PlaywrightJsonSuite,
  parentTitles: string[],
  inheritedFile: string | undefined,
  rows: PlaywrightTestRow[],
): void {
  const suiteTitle = suite.title?.trim() ?? "";
  const nextTitles = suiteTitle ? [...parentTitles, suiteTitle] : [...parentTitles];
  const suiteFile = suite.file ?? inheritedFile;

  for (const spec of asArray(suite.specs)) {
    const specTitle = spec.title?.trim() ?? "unnamed";
    const specFile = pickFile(
      [spec.file, suite.file, inheritedFile],
      "unknown",
    );
    const specTitlePath = [...nextTitles, specTitle];

    for (const test of asArray(spec.tests)) {
      const attemptStatuses = asArray(test.results).map((result) =>
        normalizeAttemptStatus(result.status),
      );
      const rawStatus = normalizeAttemptStatus(test.status);
      const outcome = normalizeOutcome(rawStatus, attemptStatuses);
      const retryCount = Math.max(
        0,
        ...asArray(test.results).map((result) =>
          typeof result.retry === "number" ? result.retry : 0,
        ),
      );
      const durationMs = asArray(test.results).reduce(
        (sum, result) => sum + (typeof result.duration === "number" ? result.duration : 0),
        0,
      );
      const errorMessages = asArray(test.results).flatMap((result) =>
        asArray(result.errors)
          .map((error) => error.message ?? error.value ?? "")
          .filter((message) => message.length > 0),
      );
      const projectName = test.projectName ?? test.projectId ?? "";

      rows.push({
        id: rowId(specFile, specTitlePath, projectName),
        file: specFile,
        title: specTitle,
        titlePath: specTitlePath,
        projectName,
        expectedStatus: test.expectedStatus ?? "passed",
        rawStatus,
        outcome,
        attempts: attemptStatuses,
        retryCount,
        durationMs,
        errorMessages,
      });
    }
  }

  for (const childSuite of asArray(suite.suites)) {
    collectRowsFromSuite(childSuite, nextTitles, suiteFile, rows);
  }
}

export function buildPlaywrightSummary(
  report: PlaywrightJsonReport,
  label: string,
  sourceFile?: string,
): PlaywrightSummary {
  const rows: PlaywrightTestRow[] = [];
  for (const suite of asArray(report.suites)) {
    collectRowsFromSuite(suite, [], suite.file, rows);
  }

  rows.sort((a, b) => {
    if (b.durationMs !== a.durationMs) return b.durationMs - a.durationMs;
    return a.id.localeCompare(b.id);
  });

  const totals = createEmptyTotals();
  const byFile = new Map<string, PlaywrightFileSummary>();

  for (const row of rows) {
    pushCount(totals, row.outcome);
    totals.retries += row.retryCount;
    totals.durationMs += row.durationMs;

    const fileSummary = byFile.get(row.file) ?? {
      file: row.file,
      total: 0,
      passed: 0,
      failed: 0,
      flaky: 0,
      skipped: 0,
      retries: 0,
      durationMs: 0,
    };

    fileSummary.total += 1;
    if (row.outcome === "passed") fileSummary.passed += 1;
    else if (row.outcome === "failed") fileSummary.failed += 1;
    else if (row.outcome === "flaky") fileSummary.flaky += 1;
    else if (row.outcome === "skipped") fileSummary.skipped += 1;
    fileSummary.retries += row.retryCount;
    fileSummary.durationMs += row.durationMs;

    byFile.set(row.file, fileSummary);
  }

  const files = [...byFile.values()].sort((a, b) => {
    if (b.failed !== a.failed) return b.failed - a.failed;
    if (b.flaky !== a.flaky) return b.flaky - a.flaky;
    if (b.durationMs !== a.durationMs) return b.durationMs - a.durationMs;
    return a.file.localeCompare(b.file);
  });

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    label,
    sourceFile,
    totals,
    files,
    tests: rows,
  };
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

function fmtMs(value: number): string {
  return `${value}`;
}

export function renderPlaywrightMarkdown(summary: PlaywrightSummary): string {
  const lines: string[] = [];
  lines.push("# Playwright Report Summary");
  lines.push("");
  lines.push("| Metric | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Label | ${escapeCell(summary.label)} |`);
  if (summary.sourceFile) {
    lines.push(`| Source | ${escapeCell(summary.sourceFile)} |`);
  }
  lines.push(`| Total | ${summary.totals.total} |`);
  lines.push(`| Passed | ${summary.totals.passed} |`);
  lines.push(`| Failed | ${summary.totals.failed} |`);
  lines.push(`| Flaky | ${summary.totals.flaky} |`);
  lines.push(`| Skipped | ${summary.totals.skipped} |`);
  lines.push(`| Timed out | ${summary.totals.timedout} |`);
  lines.push(`| Interrupted | ${summary.totals.interrupted} |`);
  lines.push(`| Retries | ${summary.totals.retries} |`);
  lines.push(`| Duration (ms) | ${summary.totals.durationMs} |`);

  lines.push("");
  lines.push("## Files");
  lines.push("");
  lines.push("| File | Total | Passed | Failed | Flaky | Skipped | Retries | Duration (ms) |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const file of summary.files) {
    lines.push(
      `| ${escapeCell(file.file)} | ${file.total} | ${file.passed} | ${file.failed} | ${file.flaky} | ${file.skipped} | ${file.retries} | ${fmtMs(file.durationMs)} |`,
    );
  }

  const unstableTests = summary.tests.filter((row) =>
    row.outcome === "failed" || row.outcome === "flaky" || row.retryCount > 0,
  );
  if (unstableTests.length > 0) {
    lines.push("");
    lines.push("## Flaky / Retried Tests");
    lines.push("");
    lines.push("| Test | Outcome | Attempts | Retries | Duration (ms) |");
    lines.push("| --- | --- | --- | --- | --- |");
    for (const row of unstableTests) {
      lines.push(
        `| ${escapeCell(row.id)} | ${row.outcome} | ${escapeCell(row.attempts.join(" -> "))} | ${row.retryCount} | ${fmtMs(row.durationMs)} |`,
      );
    }
  }

  return `${lines.join("\n")}\n`;
}

function isMainModule(): boolean {
  if (!import.meta.url.startsWith("file:")) {
    return false;
  }
  return process.argv[1] === fileURLToPath(import.meta.url);
}

if (isMainModule()) {
  try {
    const options = parseCliArgs(process.argv.slice(2));
    const inputPath = path.resolve(process.cwd(), options.input);
    const report = JSON.parse(fs.readFileSync(inputPath, "utf8")) as PlaywrightJsonReport;
    const label = options.label ?? basenameWithoutExt(inputPath);
    const summary = buildPlaywrightSummary(
      report,
      label,
      path.relative(process.cwd(), inputPath),
    );
    const markdown = renderPlaywrightMarkdown(summary);
    process.stdout.write(markdown);

    if (options.jsonOutput) {
      writeOutput(options.jsonOutput, `${JSON.stringify(summary, null, 2)}\n`);
    }
    if (options.markdownOutput) {
      writeOutput(options.markdownOutput, markdown);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(message);
    process.exit(1);
  }
}
