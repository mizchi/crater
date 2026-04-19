#!/usr/bin/env npx tsx

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

type BenchGroup = "api" | "phases" | "all";
export type VrtBenchGroup = BenchGroup;

interface CliOptions {
  group: BenchGroup;
  listOnly: boolean;
  jsonOutput?: string;
  markdownOutput?: string;
}

interface BenchEntry {
  index: number;
  testName: string;
}

interface BenchRange {
  start: number;
  end: number;
}

export interface VrtBenchStatSummary {
  name: string;
  sum: number;
  min: number;
  max: number;
  mean: number;
  median: number;
  variance: number;
  std_dev: number;
  std_dev_pct: number;
  median_abs_dev: number;
  median_abs_dev_pct: number;
  quartiles: number[];
  iqr: number;
  batch_size: number;
  runs: number;
}

export interface VrtBenchRow {
  index: number;
  testName: string;
  summary: VrtBenchStatSummary;
}

export interface VrtBenchParsedRun {
  group: BenchGroup;
  rows: VrtBenchRow[];
  rawOutput: string;
}

export interface VrtBenchRunSummary {
  group: BenchGroup;
  rows: VrtBenchRow[];
  totalRows: number;
  meanTotal: number;
  medianTotal: number;
  slowest?: VrtBenchRow;
  fastest?: VrtBenchRow;
  generatedAt: string;
}

const BENCH_MANIFEST = "benchmarks/moon.mod.json";
const BENCH_PACKAGE = "mizchi/crater-benchmarks";
const BENCH_SOURCE_FILE = "vrt_api_bench.mbt";
const DRIVER_FILE_CANDIDATES = [
  "_build/js/release/bench/mizchi/crater-benchmarks/__generated_driver_for_internal_test.mbt",
  "_build/js/release/bench/benchmarks/__generated_driver_for_internal_test.mbt",
];
const INTERNAL_RUNNER_CANDIDATES = [
  "_build/js/release/bench/mizchi/crater-benchmarks/crater-benchmarks.internal_test.js",
  "_build/js/release/bench/benchmarks/benchmarks.internal_test.js",
];
const GENERATED_FILE_KEY = "vrt_api_bench.mbt";

function usage(): string {
  return [
    "VRT Bench Runner",
    "",
    "Usage:",
    "  npx tsx scripts/vrt-bench.ts [options]",
    "",
    "Options:",
    "  --group <api|phases|all>   Select VRT bench group (default: api)",
    "  --list                     List resolved bench indices without executing",
    "  --json <file>              Write parsed benchmark summary JSON",
    "  --markdown <file>          Write parsed benchmark summary Markdown",
    "  --help                     Show this help",
  ].join("\n");
}

function parseCliArgs(args: string[]): CliOptions {
  const options: CliOptions = {
    group: "api",
    listOnly: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--group") {
      const next = args[++i];
      if (next !== "api" && next !== "phases" && next !== "all") {
        throw new Error(`Unsupported group: ${next ?? ""}`);
      }
      options.group = next;
      continue;
    }
    if (arg === "--list") {
      options.listOnly = true;
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

  return options;
}

function runOrThrow(command: string, args: string[]): void {
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    stdio: "inherit",
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function buildBenchArtifacts(): void {
  runOrThrow("moon", [
    "bench",
    "--manifest-path",
    BENCH_MANIFEST,
    "-p",
    BENCH_PACKAGE,
    "-f",
    BENCH_SOURCE_FILE,
    "--build-only",
    "--no-render",
  ]);
}

function resolveArtifactPath(candidates: string[], label: string): string {
  const resolved = candidates.find((candidate) =>
    fs.existsSync(path.join(process.cwd(), candidate))
  );
  if (!resolved) {
    throw new Error(`Failed to locate ${label}: ${candidates.join(", ")}`);
  }
  return resolved;
}

function readBenchEntries(): BenchEntry[] {
  const driverPath = path.join(
    process.cwd(),
    resolveArtifactPath(DRIVER_FILE_CANDIDATES, "bench driver"),
  );
  const text = fs.readFileSync(driverPath, "utf8");
  const lines = text.split("\n");
  const start = lines.findIndex((line) =>
    line.includes(`"${GENERATED_FILE_KEY}": {`)
  );
  if (start < 0) {
    throw new Error(`Failed to locate ${GENERATED_FILE_KEY} in ${driverPath}`);
  }

  const entries: BenchEntry[] = [];
  const entryPattern = /^\s*(\d+): .*?\["([^"]+)"\]\),?$/;
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("  },") || line.trim() === "}") {
      break;
    }
    const match = line.match(entryPattern);
    if (!match) {
      continue;
    }
    entries.push({
      index: Number.parseInt(match[1], 10),
      testName: match[2],
    });
  }

  if (entries.length === 0) {
    throw new Error(`No VRT bench entries found in ${driverPath}`);
  }

  return entries.sort((a, b) => a.index - b.index);
}

function belongsToGroup(entry: BenchEntry, group: BenchGroup): boolean {
  if (!entry.testName.startsWith("bench_vrt_")) {
    return false;
  }
  if (group === "all") {
    return true;
  }
  if (group === "phases") {
    return entry.testName.startsWith("bench_vrt_phase_");
  }
  return !entry.testName.startsWith("bench_vrt_phase_");
}

function compressRanges(entries: BenchEntry[]): BenchRange[] {
  const ranges: BenchRange[] = [];
  for (const entry of entries) {
    const last = ranges.at(-1);
    if (last && last.end === entry.index) {
      last.end = entry.index + 1;
      continue;
    }
    ranges.push({
      start: entry.index,
      end: entry.index + 1,
    });
  }
  return ranges;
}

function listEntries(group: BenchGroup, entries: BenchEntry[]): void {
  console.log(`# VRT bench group: ${group}`);
  for (const entry of entries) {
    console.log(`${entry.index}\t${entry.testName}`);
  }
}

function runSelectedEntries(entries: BenchEntry[]): string {
  const runnerPath = path.join(
    process.cwd(),
    resolveArtifactPath(INTERNAL_RUNNER_CANDIDATES, "bench runner"),
  );
  const ranges = compressRanges(entries);
  const payload = JSON.stringify({
    file_and_index: [[GENERATED_FILE_KEY, ranges]],
  });
  const result = spawnSync("node", [runnerPath, payload], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";
  if (stdout) {
    process.stdout.write(stdout);
  }
  if (stderr) {
    process.stderr.write(stderr);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
  return `${stdout}${stderr}`;
}

function asNumber(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function asNumberArray(value: unknown): number[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item) => typeof item === "number" && Number.isFinite(item));
}

export function parseBenchRunOutput(
  output: string,
  group: BenchGroup,
): VrtBenchParsedRun {
  const rows: VrtBenchRow[] = [];
  const lines = output.split("\n");

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("{") || !trimmed.includes("\"test_name\"")) {
      continue;
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(trimmed);
    } catch {
      continue;
    }

    const testName =
      typeof parsed.test_name === "string" ? parsed.test_name : "";
    const index = Number.parseInt(String(parsed.index ?? "-1"), 10);
    const message = typeof parsed.message === "string" ? parsed.message : "";
    if (!testName || !Number.isFinite(index)) {
      continue;
    }
    if (!message.startsWith("@BATCH_BENCH ")) {
      continue;
    }

    let benchPayload: Record<string, unknown>;
    try {
      benchPayload = JSON.parse(message.slice("@BATCH_BENCH ".length));
    } catch {
      continue;
    }
    const summaries = Array.isArray(benchPayload.summaries)
      ? benchPayload.summaries
      : [];
    for (const summary of summaries) {
      if (typeof summary !== "object" || summary === null) {
        continue;
      }
      const row = summary as Record<string, unknown>;
      rows.push({
        index,
        testName,
        summary: {
          name: typeof row.name === "string" ? row.name : testName,
          sum: asNumber(row.sum),
          min: asNumber(row.min),
          max: asNumber(row.max),
          mean: asNumber(row.mean),
          median: asNumber(row.median),
          variance: asNumber(row.variance),
          std_dev: asNumber(row.std_dev),
          std_dev_pct: asNumber(row.std_dev_pct),
          median_abs_dev: asNumber(row.median_abs_dev),
          median_abs_dev_pct: asNumber(row.median_abs_dev_pct),
          quartiles: asNumberArray(row.quartiles),
          iqr: asNumber(row.iqr),
          batch_size: asNumber(row.batch_size),
          runs: asNumber(row.runs),
        },
      });
    }
  }

  return {
    group,
    rows,
    rawOutput: output,
  };
}

export function summarizeBenchRun(
  parsed: VrtBenchParsedRun,
): VrtBenchRunSummary {
  const rows = [...parsed.rows].sort((a, b) => b.summary.mean - a.summary.mean);
  const meanTotal = rows.reduce((sum, row) => sum + row.summary.mean, 0);
  const medianTotal = rows.reduce((sum, row) => sum + row.summary.median, 0);
  return {
    group: parsed.group,
    rows,
    totalRows: rows.length,
    meanTotal,
    medianTotal,
    slowest: rows[0],
    fastest: rows.at(-1),
    generatedAt: new Date().toISOString(),
  };
}

function fmtNumber(value: number): string {
  return value.toFixed(2);
}

export function renderMarkdownSummary(summary: VrtBenchRunSummary): string {
  const lines: string[] = [];
  lines.push(`# VRT Bench Summary (${summary.group})`);
  lines.push("");
  lines.push(`- Benchmarks: ${summary.totalRows}`);
  lines.push(`- Mean total: ${fmtNumber(summary.meanTotal)}`);
  lines.push(`- Median total: ${fmtNumber(summary.medianTotal)}`);
  if (summary.slowest) {
    lines.push(
      `- Slowest benchmark: \`${summary.slowest.testName}\` (${fmtNumber(summary.slowest.summary.mean)})`,
    );
  }
  if (summary.fastest) {
    lines.push(
      `- Fastest benchmark: \`${summary.fastest.testName}\` (${fmtNumber(summary.fastest.summary.mean)})`,
    );
  }
  lines.push("");
  lines.push("| Test | Benchmark | Mean | Median | Min | Max | Batch | Runs |");
  lines.push("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |");
  for (const row of summary.rows) {
    lines.push(
      `| ${row.testName} | ${row.summary.name} | ${fmtNumber(row.summary.mean)} | ${fmtNumber(row.summary.median)} | ${fmtNumber(row.summary.min)} | ${fmtNumber(row.summary.max)} | ${row.summary.batch_size} | ${row.summary.runs} |`,
    );
  }
  return lines.join("\n");
}

function ensureParentDir(filePath: string): void {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
}

function writeOptionalReports(
  parsed: VrtBenchParsedRun,
  options: CliOptions,
): void {
  if (!options.jsonOutput && !options.markdownOutput) {
    return;
  }
  const summary = summarizeBenchRun(parsed);
  if (options.jsonOutput) {
    ensureParentDir(options.jsonOutput);
    fs.writeFileSync(options.jsonOutput, JSON.stringify(summary, null, 2));
  }
  if (options.markdownOutput) {
    ensureParentDir(options.markdownOutput);
    fs.writeFileSync(options.markdownOutput, renderMarkdownSummary(summary));
  }
}

function main(): void {
  const options = parseCliArgs(process.argv.slice(2));
  buildBenchArtifacts();
  const selected = readBenchEntries().filter((entry) =>
    belongsToGroup(entry, options.group)
  );
  if (selected.length === 0) {
    throw new Error(`No benches matched group: ${options.group}`);
  }

  listEntries(options.group, selected);
  if (!options.listOnly) {
    const output = runSelectedEntries(selected);
    writeOptionalReports(parseBenchRunOutput(output, options.group), options);
  }
}

function isMainModule(): boolean {
  const entry = process.argv[1];
  if (!entry) {
    return false;
  }
  return path.resolve(entry) === fileURLToPath(import.meta.url);
}

if (isMainModule()) {
  try {
    main();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(message);
    process.exit(1);
  }
}
