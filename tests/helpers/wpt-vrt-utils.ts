import fs from "node:fs";
import path from "node:path";
import { getTestFiles, prepareHtmlContent } from "../../scripts/wpt-html-utils.ts";

export interface WptVrtConfig {
  modules: string[];
  limitPerModule: number;
  explicitTests?: string[];
  skipPatterns?: string[];
  viewport: { width: number; height: number };
  pixelmatchThreshold: number;
  defaultMaxDiffRatio: number;
}

export interface WptVrtBaseline {
  schemaVersion: 1;
  updatedAt: string;
  config: {
    viewport: { width: number; height: number };
    pixelmatchThreshold: number;
    defaultMaxDiffRatio: number;
  };
  summary: {
    total: number;
    passed: number;
    failed: number;
  };
  tests: Record<string, { diffRatio: number; status: "pass" | "fail" }>;
}

export interface WptVrtTestResult {
  relativePath: string;
  diffRatio: number;
  status: "pass" | "fail";
  error?: string;
}

export interface WptVrtShardInfo {
  name: string;
  modules: string[];
  offset: number;
  limit: number;
}

export interface WptVrtResultsTestRecord {
  diffRatio: number;
  status: "pass" | "fail";
  error?: string;
  baselineDiffRatio?: number;
  regressionLimit?: number;
  headroom?: number;
}

export interface WptVrtResultsReport {
  schemaVersion: 1;
  suite: "wpt-vrt";
  generatedAt: string;
  runId?: string;
  shard: WptVrtShardInfo;
  config: WptVrtBaseline["config"];
  summary: {
    total: number;
    expectedTotal: number;
    passed: number;
    failed: number;
    regressions: number;
  };
  closestToThreshold: Array<{
    relativePath: string;
    diffRatio: number;
    baselineDiffRatio?: number;
    regressionLimit: number;
    headroom: number;
    status: "pass" | "fail";
  }>;
  regressions: Array<{
    relativePath: string;
    diffRatio: number;
    baselineDiffRatio?: number;
    regressionLimit: number;
    headroom: number;
    status: "pass" | "fail";
    error?: string;
  }>;
  tests: Record<string, WptVrtResultsTestRecord>;
}

export interface WptVrtTestEntry {
  testPath: string;
  relativePath: string;
  moduleName: string;
}

const CONFIG_PATH = path.join(process.cwd(), "wpt-vrt.json");
const BASELINE_PATH = path.join(process.cwd(), "tests", "wpt-vrt-baseline.json");

export function loadWptVrtConfig(): WptVrtConfig {
  const raw = fs.readFileSync(CONFIG_PATH, "utf-8");
  return JSON.parse(raw) as WptVrtConfig;
}

export function loadWptVrtBaseline(): WptVrtBaseline | null {
  try {
    const raw = fs.readFileSync(BASELINE_PATH, "utf-8");
    return JSON.parse(raw) as WptVrtBaseline;
  } catch {
    return null;
  }
}

export function saveWptVrtBaseline(baseline: WptVrtBaseline): void {
  fs.writeFileSync(BASELINE_PATH, JSON.stringify(baseline, null, 2) + "\n");
}

export function buildWptVrtResultsReport(params: {
  results: WptVrtTestResult[];
  expectedTotal: number;
  shard: WptVrtShardInfo;
  config: WptVrtConfig;
  baseline?: WptVrtBaseline | null;
  regressionEpsilon?: number;
  generatedAt?: string;
  closestLimit?: number;
  runId?: string;
}): WptVrtResultsReport {
  const {
    results,
    expectedTotal,
    shard,
    config,
    baseline = null,
    regressionEpsilon = 0.01,
    generatedAt = new Date().toISOString(),
    closestLimit = 10,
    runId,
  } = params;
  const tests: Record<string, WptVrtResultsTestRecord> = {};
  const thresholdRows: WptVrtResultsReport["closestToThreshold"] = [];
  const regressions: WptVrtResultsReport["regressions"] = [];

  for (const result of results) {
    const baselineEntry = baseline?.tests[result.relativePath];
    const regressionLimit = baselineEntry
      ? baselineEntry.diffRatio + regressionEpsilon
      : config.defaultMaxDiffRatio;
    const headroom = regressionLimit - result.diffRatio;
    tests[result.relativePath] = {
      diffRatio: result.diffRatio,
      status: result.status,
      ...(result.error ? { error: result.error } : {}),
      ...(baselineEntry
        ? {
            baselineDiffRatio: baselineEntry.diffRatio,
            regressionLimit,
            headroom,
          }
        : {}),
    };
    thresholdRows.push({
      relativePath: result.relativePath,
      diffRatio: result.diffRatio,
      baselineDiffRatio: baselineEntry?.diffRatio,
      regressionLimit,
      headroom,
      status: result.status,
    });
    if (result.diffRatio > regressionLimit) {
      regressions.push({
        relativePath: result.relativePath,
        diffRatio: result.diffRatio,
        baselineDiffRatio: baselineEntry?.diffRatio,
        regressionLimit,
        headroom,
        status: result.status,
        ...(result.error ? { error: result.error } : {}),
      });
    }
  }

  thresholdRows.sort((a, b) => a.headroom - b.headroom);
  const passed = results.filter((r) => r.status === "pass").length;
  const failed = results.filter((r) => r.status === "fail").length;

  return {
    schemaVersion: 1,
    suite: "wpt-vrt",
    generatedAt,
    ...(runId ? { runId } : {}),
    shard,
    config: {
      viewport: config.viewport,
      pixelmatchThreshold: config.pixelmatchThreshold,
      defaultMaxDiffRatio: config.defaultMaxDiffRatio,
    },
    summary: {
      total: results.length,
      expectedTotal,
      passed,
      failed,
      regressions: regressions.length,
    },
    closestToThreshold: thresholdRows.slice(0, closestLimit),
    regressions,
    tests,
  };
}

export function readWptVrtResultsReport(outputRoot: string): WptVrtResultsReport | null {
  try {
    const raw = fs.readFileSync(path.join(outputRoot, "wpt-vrt-results.json"), "utf-8");
    return JSON.parse(raw) as WptVrtResultsReport;
  } catch {
    return null;
  }
}

function reportToWptVrtTestResults(report: WptVrtResultsReport): WptVrtTestResult[] {
  return Object.entries(report.tests)
    .map(([relativePath, result]) => ({
      relativePath,
      diffRatio: result.diffRatio,
      status: result.status,
      ...(result.error ? { error: result.error } : {}),
    }))
    .sort((a, b) => a.relativePath.localeCompare(b.relativePath));
}

function mergeWptVrtTestResults(
  ...groups: WptVrtTestResult[][]
): WptVrtTestResult[] {
  const merged = new Map<string, WptVrtTestResult>();
  for (const group of groups) {
    for (const result of group) {
      merged.set(result.relativePath, result);
    }
  }
  return [...merged.values()].sort((a, b) => a.relativePath.localeCompare(b.relativePath));
}

export function buildMergedWptVrtResultsReport(params: {
  currentResults: WptVrtTestResult[];
  existingReport?: WptVrtResultsReport | null;
  expectedTotal: number;
  shard: WptVrtShardInfo;
  config: WptVrtConfig;
  baseline?: WptVrtBaseline | null;
  regressionEpsilon?: number;
  generatedAt?: string;
  closestLimit?: number;
  runId: string;
}): WptVrtResultsReport {
  const {
    currentResults,
    existingReport = null,
    expectedTotal,
    shard,
    config,
    baseline = null,
    regressionEpsilon,
    generatedAt,
    closestLimit,
    runId,
  } = params;
  const priorResults = existingReport?.runId === runId
    ? reportToWptVrtTestResults(existingReport)
    : [];
  return buildWptVrtResultsReport({
    results: mergeWptVrtTestResults(priorResults, currentResults),
    expectedTotal,
    shard,
    config,
    baseline,
    regressionEpsilon,
    generatedAt,
    closestLimit,
    runId,
  });
}

export function writeWptVrtResultsReport(
  outputRoot: string,
  report: WptVrtResultsReport,
): void {
  fs.mkdirSync(outputRoot, { recursive: true });
  fs.writeFileSync(
    path.join(outputRoot, "wpt-vrt-results.json"),
    JSON.stringify(report, null, 2) + "\n",
  );
}

function toRelativePath(testPath: string): string {
  return testPath
    .replace(/^wpt\/css\//, "")
    .replace(/^wpt[/\\]css[/\\]/, "");
}

function moduleNameFromTestPath(testPath: string): string {
  const relativePath = toRelativePath(testPath);
  const [moduleName = ""] = relativePath.split(/[/\\]/);
  return moduleName;
}

function pushUniqueEntry(
  entries: WptVrtTestEntry[],
  seen: Set<string>,
  testPath: string,
  moduleName: string,
): void {
  const relativePath = toRelativePath(testPath);
  if (seen.has(relativePath)) return;
  seen.add(relativePath);
  entries.push({ testPath, relativePath, moduleName });
}

function matchesSkipPattern(testPath: string, patterns: string[]): boolean {
  const basename = path.basename(testPath);
  return patterns.some((p) => basename.includes(p));
}

export function collectWptVrtTests(
  config: WptVrtConfig,
  getFiles: (moduleName: string) => string[] = getTestFiles,
): WptVrtTestEntry[] {
  const entries: WptVrtTestEntry[] = [];
  const seen = new Set<string>();
  const skip = config.skipPatterns ?? [];
  for (const moduleName of config.modules) {
    const files = getFiles(moduleName).filter((f) => !matchesSkipPattern(f, skip));
    const limited = files.slice(0, config.limitPerModule);
    for (const testPath of limited) {
      pushUniqueEntry(entries, seen, testPath, moduleName);
    }
  }
  for (const testPath of config.explicitTests ?? []) {
    if (!matchesSkipPattern(testPath, skip)) {
      pushUniqueEntry(entries, seen, testPath, moduleNameFromTestPath(testPath));
    }
  }
  return entries;
}

export function createWptVrtBatches(
  entries: WptVrtTestEntry[],
  batchSize: number,
): WptVrtTestEntry[][] {
  if (batchSize <= 0) {
    throw new Error("batchSize must be positive");
  }
  const batches: WptVrtTestEntry[][] = [];
  for (let i = 0; i < entries.length; i += batchSize) {
    batches.push(entries.slice(i, i + batchSize));
  }
  return batches;
}

export { prepareHtmlContent };
