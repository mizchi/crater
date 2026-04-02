import {
  accumulatePlaywrightFileSummary,
  accumulatePlaywrightSummaryTotals,
  buildStablePlaywrightIdentity,
  createEmptyPlaywrightFileSummary,
  createEmptyPlaywrightSummaryTotals,
  type PlaywrightFileSummary,
  type PlaywrightOutcome,
  type PlaywrightSummary,
  type PlaywrightTestRow,
} from "./playwright-report-contract.ts";

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

function rowId(file: string, titlePath: string[], projectName: string): string {
  const base = `${file}::${titlePath.join(" > ")}`;
  return projectName ? `${base} [${projectName}]` : base;
}

function isFileContainerSuite(suite: PlaywrightJsonSuite): boolean {
  return typeof suite.file === "string"
    || /\.(spec|test)\.[cm]?[jt]sx?$/.test(suite.title ?? "");
}

function collectRowsFromSuite(
  suite: PlaywrightJsonSuite,
  parentTitles: string[],
  inheritedFile: string | undefined,
  rows: PlaywrightTestRow[],
): void {
  const suiteTitle = suite.title?.trim() ?? "";
  const fileContainer = isFileContainerSuite(suite);
  const nextTitles = fileContainer
    ? [...parentTitles]
    : suiteTitle
    ? [...parentTitles, suiteTitle]
    : [...parentTitles];
  const suiteFile = suite.file ?? inheritedFile ?? (fileContainer ? suiteTitle : undefined);
  const currentTitle = nextTitles[nextTitles.length - 1] ?? suiteTitle ?? suiteFile ?? "unknown";

  for (const spec of asArray(suite.specs)) {
    const specTitle = spec.title?.trim() ?? "unnamed";
    const specFile = pickFile(
      [spec.file, suiteFile, inheritedFile],
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
      const identity = buildStablePlaywrightIdentity({
        suite: currentTitle,
        testName: specTitle,
        spec: specFile,
        titlePath: specTitlePath,
        variant: projectName ? { project: projectName } : {},
      });

      rows.push({
        id: rowId(specFile, specTitlePath, projectName),
        file: specFile,
        title: specTitle,
        titlePath: specTitlePath,
        identityKey: identity.key,
        identity,
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

  const totals = createEmptyPlaywrightSummaryTotals();
  const byFile = new Map<string, PlaywrightFileSummary>();

  for (const row of rows) {
    accumulatePlaywrightSummaryTotals(totals, row);
    const fileSummary = byFile.get(row.file) ?? createEmptyPlaywrightFileSummary(row.file);
    accumulatePlaywrightFileSummary(fileSummary, row);
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
