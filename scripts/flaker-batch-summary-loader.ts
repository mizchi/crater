import fs from "node:fs";
import path from "node:path";
import type { PlaywrightSummary } from "./playwright-report-contract.ts";
import type { FlakerTaskSummaryReport } from "./flaker-task-summary-contract.ts";
import type {
  FlakerBatchSummaryInputs,
  FlakerBatchVrtSummary,
} from "./flaker-batch-summary-core.ts";
import type {
  WptVrtAggregateSummary,
  WptVrtShardSummary,
} from "./wpt-vrt-summary-core.ts";

function readJsonIfExists<T>(targetPath: string): T | undefined {
  if (!fs.existsSync(targetPath)) {
    return undefined;
  }
  try {
    return JSON.parse(fs.readFileSync(targetPath, "utf8")) as T;
  } catch {
    return undefined;
  }
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function asPlaywrightSummary(value: unknown): PlaywrightSummary | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }
  const summary = value as Record<string, unknown>;
  const totals = summary.totals;
  if (typeof totals !== "object" || totals === null) {
    return undefined;
  }
  const totalsRecord = totals as Record<string, unknown>;
  if (
    !isFiniteNumber(totalsRecord.total)
    || !isFiniteNumber(totalsRecord.failed)
    || !isFiniteNumber(totalsRecord.flaky)
    || !isFiniteNumber(totalsRecord.skipped)
    || !isFiniteNumber(totalsRecord.timedout)
    || !isFiniteNumber(totalsRecord.interrupted)
  ) {
    return undefined;
  }
  return summary as PlaywrightSummary;
}

function asFlakerTaskSummaryReport(value: unknown): FlakerTaskSummaryReport | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }
  const summary = value as Record<string, unknown>;
  const evalReport = summary.eval;
  const reasonReport = summary.reason;
  if (typeof evalReport !== "object" || evalReport === null) {
    return undefined;
  }
  if (typeof reasonReport !== "object" || reasonReport === null) {
    return undefined;
  }
  const evalRecord = evalReport as Record<string, unknown>;
  const resolution = evalRecord.resolution;
  const reasonRecord = reasonReport as Record<string, unknown>;
  const reasonSummary = reasonRecord.summary;
  if (typeof resolution !== "object" || resolution === null) {
    return undefined;
  }
  if (typeof reasonSummary !== "object" || reasonSummary === null) {
    return undefined;
  }
  const resolutionRecord = resolution as Record<string, unknown>;
  const reasonSummaryRecord = reasonSummary as Record<string, unknown>;
  if (
    !isFiniteNumber(evalRecord.healthScore)
    || !isFiniteNumber(resolutionRecord.newFlaky)
    || !isFiniteNumber(reasonSummaryRecord.urgentFixes)
  ) {
    return undefined;
  }
  return summary as FlakerTaskSummaryReport;
}

function asBatchVrtSummary(
  value: unknown,
): FlakerBatchVrtSummary | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }
  const summary = value as Record<string, unknown>;
  if (summary.schemaVersion !== 1 || summary.suite !== "vrt-artifact-summary") {
    return undefined;
  }
  if (
    !isFiniteNumber(summary.failed)
    || !isFiniteNumber(summary.unknown)
    || !isFiniteNumber(summary.maxObservedDiffRatio)
  ) {
    return undefined;
  }
  return {
    failed: summary.failed,
    unknown: summary.unknown,
    maxDiffRatio: summary.maxObservedDiffRatio,
  };
}

function walkJsonFiles(rootDir: string): string[] {
  if (!fs.existsSync(rootDir)) {
    return [];
  }
  const results: string[] = [];
  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    const targetPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkJsonFiles(targetPath));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith(".json")) {
      results.push(targetPath);
    }
  }
  return results;
}

function resolveCollectedTaskId(
  filePath: string,
  kind: "playwright-summary" | "flaker-summary" | "vrt-summary" | "wpt-vrt-summary",
): string | undefined {
  const kindDir = path.dirname(filePath);
  if (path.basename(kindDir) !== kind) {
    return undefined;
  }
  const taskDir = path.dirname(kindDir);
  const taskId = path.basename(taskDir);
  return taskId.length > 0 && path.basename(filePath, ".json") === taskId ? taskId : undefined;
}

function asBatchWptVrtSummary(
  value: unknown,
): FlakerBatchVrtSummary | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }
  const summary = value as Record<string, unknown>;
  if (summary.schemaVersion !== 1 || summary.suite !== "wpt-vrt") {
    return undefined;
  }

  if (
    typeof summary.failed === "number"
    && typeof summary.total === "number"
    && typeof summary.maxDiffRatio === "number"
  ) {
    const shard = summary as WptVrtShardSummary;
    return {
      failed: shard.failed,
      unknown: Math.max((shard.expectedTotal ?? shard.total) - shard.total, 0),
      maxDiffRatio: shard.maxDiffRatio,
    };
  }

  if (
    typeof summary.total === "object"
    && summary.total !== null
    && typeof (summary.total as Record<string, unknown>).failed === "number"
    && Array.isArray(summary.rows)
  ) {
    const aggregate = summary as WptVrtAggregateSummary;
    return {
      failed: aggregate.total.failed,
      unknown: aggregate.rows.reduce(
        (sum, row) => sum + Math.max((row.expectedTotal ?? row.total) - row.total, 0),
        0,
      ),
      maxDiffRatio: aggregate.rows.reduce(
        (max, row) => Math.max(max, row.maxDiffRatio),
        0,
      ),
    };
  }

  return undefined;
}

export function loadFlakerBatchSummaryInputs(
  inputDir: string,
): FlakerBatchSummaryInputs {
  const playwrightSummaries = new Map<string, PlaywrightSummary>();
  const flakerSummaries = new Map<string, FlakerTaskSummaryReport>();
  const vrtSummaries = new Map<string, FlakerBatchVrtSummary>();

  for (const filePath of walkJsonFiles(inputDir)) {
    const playwrightTaskId = resolveCollectedTaskId(filePath, "playwright-summary");
    if (playwrightTaskId) {
      const summary = asPlaywrightSummary(readJsonIfExists<unknown>(filePath));
      if (summary) {
        playwrightSummaries.set(playwrightTaskId, summary);
      }
      continue;
    }
    const flakerTaskId = resolveCollectedTaskId(filePath, "flaker-summary");
    if (flakerTaskId) {
      const summary = asFlakerTaskSummaryReport(readJsonIfExists<unknown>(filePath));
      if (summary) {
        flakerSummaries.set(flakerTaskId, summary);
      }
      continue;
    }
    const vrtTaskId = resolveCollectedTaskId(filePath, "vrt-summary");
    if (vrtTaskId) {
      const summary = asBatchVrtSummary(readJsonIfExists<unknown>(filePath));
      if (summary) {
        vrtSummaries.set(vrtTaskId, summary);
      }
      continue;
    }
    const wptVrtTaskId = resolveCollectedTaskId(filePath, "wpt-vrt-summary");
    if (wptVrtTaskId && !vrtSummaries.has(wptVrtTaskId)) {
      const summary = readJsonIfExists<unknown>(filePath);
      const normalized = summary ? asBatchWptVrtSummary(summary) : undefined;
      if (normalized) {
        vrtSummaries.set(wptVrtTaskId, normalized);
      }
    }
  }

  return {
    playwrightSummaries,
    flakerSummaries,
    vrtSummaries,
  };
}
