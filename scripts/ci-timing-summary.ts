#!/usr/bin/env npx tsx

import fs from "fs";
import path from "path";

export interface GithubJobLike {
  name: string;
  status?: string;
  conclusion?: string | null;
  createdAt?: string | null;
  startedAt?: string | null;
  completedAt?: string | null;
  created_at?: string | null;
  started_at?: string | null;
  completed_at?: string | null;
}

export interface TimingRow {
  name: string;
  status: string;
  conclusion: string;
  queueSec: number;
  durationSec: number;
  totalSec: number;
}

export interface TimingGroup {
  group: string;
  jobs: number;
  completedJobs: number;
  failedJobs: number;
  queueSec: number;
  durationSec: number;
}

export interface TimingWarning {
  name: string;
  group: string;
  durationSec: number;
  maxDurationSec: number;
}

export interface TimingSummary {
  schemaVersion: 1;
  runId?: number;
  generatedAt: string;
  totals: {
    totalJobs: number;
    completedJobs: number;
    failedJobs: number;
    inProgressJobs: number;
    queueSec: number;
    durationSec: number;
    elapsedSec: number;
  };
  rows: TimingRow[];
  byGroup: TimingGroup[];
  warnings: {
    maxShardDurationSec?: number;
    slowShards: TimingWarning[];
  };
}

interface CliOptions {
  input: string;
  jsonOutput?: string;
  markdownOutput?: string;
  maxShardDurationSec?: number;
}

interface TimingSummaryOptions {
  maxShardDurationSec?: number;
}

const DEFAULT_INPUT = "ci-timing/jobs.json";

function usage(): string {
  return [
    "CI Timing Summary",
    "",
    "Usage:",
    "  npx tsx scripts/ci-timing-summary.ts [options]",
    "",
    "Options:",
    `  --input <file>      Input jobs json (default: ${DEFAULT_INPUT})`,
    "  --json <file>       Output summary json",
    "  --markdown <file>   Output summary markdown",
    "  --max-shard-duration-sec <n>  Warn when a VRT/WPT shard exceeds this run duration",
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
    if (arg === "--json") {
      options.jsonOutput = args[++i];
      continue;
    }
    if (arg === "--markdown") {
      options.markdownOutput = args[++i];
      continue;
    }
    if (arg === "--max-shard-duration-sec") {
      const raw = args[++i] ?? "";
      const parsed = Number(raw);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        throw new Error("--max-shard-duration-sec must be a positive number");
      }
      options.maxShardDurationSec = Math.round(parsed);
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.input) throw new Error("--input is required");
  return options;
}

function toTimestamp(isoLike: string | null | undefined): number {
  if (!isoLike) return 0;
  const t = Date.parse(isoLike);
  return Number.isFinite(t) ? t : 0;
}

function diffSec(startMs: number, endMs: number): number {
  if (startMs <= 0 || endMs <= 0 || endMs < startMs) return 0;
  return Math.round((endMs - startMs) / 1000);
}

function jobGroup(name: string): string {
  if (name.startsWith("paint-vrt")) return "paint-vrt";
  if (name.startsWith("playwright-paint-vrt")) return "paint-vrt";
  if (name.startsWith("wpt-css")) return "wpt-css";
  if (name.startsWith("wpt-dom")) return "wpt-dom";
  if (name.startsWith("wpt-webdriver")) return "wpt-webdriver";
  if (name.startsWith("wpt-vrt")) return "wpt-vrt";
  return name;
}

function isTimedShard(row: TimingRow): boolean {
  if (!row.name.includes("(") || !row.name.includes(")")) return false;
  const group = jobGroup(row.name);
  return group === "paint-vrt" || group === "wpt-vrt" || group === "wpt-css";
}

function normalizeJobTimes(job: GithubJobLike): { createdMs: number; startedMs: number; completedMs: number } {
  return {
    createdMs: toTimestamp(job.createdAt ?? job.created_at),
    startedMs: toTimestamp(job.startedAt ?? job.started_at),
    completedMs: toTimestamp(job.completedAt ?? job.completed_at),
  };
}

function buildTimingWarnings(
  rows: TimingRow[],
  options: TimingSummaryOptions = {},
): TimingSummary["warnings"] {
  const maxShardDurationSec = options.maxShardDurationSec;
  if (!maxShardDurationSec) {
    return { slowShards: [] };
  }
  const slowShards = rows
    .filter((row) => isTimedShard(row) && row.durationSec > maxShardDurationSec)
    .map((row) => ({
      name: row.name,
      group: jobGroup(row.name),
      durationSec: row.durationSec,
      maxDurationSec: maxShardDurationSec,
    }));
  return { maxShardDurationSec, slowShards };
}

export function buildTimingSummary(
  jobs: GithubJobLike[],
  runId?: number,
  options: TimingSummaryOptions = {},
): TimingSummary {
  const rows: TimingRow[] = jobs.map((job) => {
    const { createdMs, startedMs, completedMs } = normalizeJobTimes(job);
    return {
      name: job.name,
      status: job.status ?? "unknown",
      conclusion: job.conclusion ?? "",
      queueSec: diffSec(createdMs, startedMs),
      durationSec: diffSec(startedMs, completedMs),
      totalSec: diffSec(createdMs, completedMs),
    };
  });

  rows.sort((a, b) => {
    if (b.durationSec !== a.durationSec) return b.durationSec - a.durationSec;
    return a.name.localeCompare(b.name);
  });

  const byGroupMap = new Map<string, TimingGroup>();
  let queueSec = 0;
  let durationSec = 0;
  let completedJobs = 0;
  let failedJobs = 0;
  let inProgressJobs = 0;
  let minCreated = 0;
  let maxCompleted = 0;

  for (let i = 0; i < jobs.length; i++) {
    const job = jobs[i];
    const row = rows.find((r) => r.name === job.name && r.queueSec >= 0)!;
    const groupName = jobGroup(job.name);
    const group = byGroupMap.get(groupName) ?? {
      group: groupName,
      jobs: 0,
      completedJobs: 0,
      failedJobs: 0,
      queueSec: 0,
      durationSec: 0,
    };
    group.jobs += 1;
    group.queueSec += row.queueSec;
    group.durationSec += row.durationSec;

    if (job.status === "completed") {
      completedJobs += 1;
      group.completedJobs += 1;
    } else {
      inProgressJobs += 1;
    }
    if (job.conclusion && job.conclusion !== "success") {
      failedJobs += 1;
      group.failedJobs += 1;
    }

    queueSec += row.queueSec;
    durationSec += row.durationSec;

    const { createdMs, completedMs } = normalizeJobTimes(job);
    if (createdMs > 0 && (minCreated === 0 || createdMs < minCreated)) {
      minCreated = createdMs;
    }
    if (completedMs > maxCompleted) {
      maxCompleted = completedMs;
    }

    byGroupMap.set(groupName, group);
    void i;
  }

  const byGroup = [...byGroupMap.values()].sort((a, b) => b.durationSec - a.durationSec);
  const elapsedSec = diffSec(minCreated, maxCompleted);
  const warnings = buildTimingWarnings(rows, options);

  return {
    schemaVersion: 1,
    runId,
    generatedAt: new Date().toISOString(),
    totals: {
      totalJobs: jobs.length,
      completedJobs,
      failedJobs,
      inProgressJobs,
      queueSec,
      durationSec,
      elapsedSec,
    },
    rows,
    byGroup,
    warnings,
  };
}

function fmtSec(sec: number): string {
  return `${sec}`;
}

export function renderTimingMarkdown(summary: TimingSummary): string {
  const lines: string[] = [];
  lines.push("# CI Timing Summary");
  lines.push("");
  lines.push(`Generated at: ${summary.generatedAt}`);
  if (summary.runId) {
    lines.push(`Run ID: ${summary.runId}`);
  }
  lines.push("");
  lines.push("- Total jobs: " + summary.totals.totalJobs);
  lines.push("- Completed jobs: " + summary.totals.completedJobs);
  lines.push("- Failed jobs: " + summary.totals.failedJobs);
  lines.push("- In progress jobs: " + summary.totals.inProgressJobs);
  lines.push("- Queue total (s): " + summary.totals.queueSec);
  lines.push("- Run total (s): " + summary.totals.durationSec);
  lines.push("- Workflow elapsed (s): " + summary.totals.elapsedSec);
  lines.push("");

  lines.push("## Slowest Jobs");
  lines.push("");
  lines.push("| Job | Status | Conclusion | Queue (s) | Run (s) |");
  lines.push("| --- | --- | --- | ---: | ---: |");
  for (const row of summary.rows.slice(0, 30)) {
    lines.push(
      `| ${row.name} | ${row.status} | ${row.conclusion || "-"} | ${fmtSec(row.queueSec)} | ${fmtSec(row.durationSec)} |`
    );
  }
  lines.push("");

  lines.push("## Group Totals");
  lines.push("");
  lines.push("| Group | Jobs | Completed | Failed | Queue Total (s) | Run Total (s) |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: |");
  for (const group of summary.byGroup) {
    lines.push(
      `| ${group.group} | ${group.jobs} | ${group.completedJobs} | ${group.failedJobs} | ${fmtSec(group.queueSec)} | ${fmtSec(group.durationSec)} |`
    );
  }
  lines.push("");

  if (summary.warnings.slowShards.length > 0) {
    lines.push("## Shard Duration Warnings");
    lines.push("");
    if (summary.warnings.maxShardDurationSec) {
      lines.push("- Target max shard run (s): " + summary.warnings.maxShardDurationSec);
      lines.push("");
    }
    lines.push("| Job | Group | Run (s) | Target (s) |");
    lines.push("| --- | --- | ---: | ---: |");
    for (const warning of summary.warnings.slowShards) {
      lines.push(
        `| ${warning.name} | ${warning.group} | ${fmtSec(warning.durationSec)} | ${fmtSec(warning.maxDurationSec)} |`
      );
    }
    lines.push("");
  }

  return lines.join("\n");
}

function ensureParent(filePath: string): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function loadJobsFromFile(filePath: string): { runId?: number; jobs: GithubJobLike[] } {
  const raw = JSON.parse(fs.readFileSync(filePath, "utf-8")) as unknown;

  if (Array.isArray(raw)) {
    return { jobs: raw as GithubJobLike[] };
  }

  if (typeof raw === "object" && raw !== null) {
    const obj = raw as Record<string, unknown>;
    if (Array.isArray(obj.jobs)) {
      const runIdValue = obj.run_id;
      const runId = typeof runIdValue === "number" ? runIdValue : undefined;
      return { runId, jobs: obj.jobs as GithubJobLike[] };
    }
  }

  throw new Error(`Unsupported input JSON format: ${filePath}`);
}

export async function main(): Promise<number> {
  const options = parseCliArgs(process.argv.slice(2));
  const { jobs, runId } = loadJobsFromFile(options.input);
  const summary = buildTimingSummary(jobs, runId, {
    maxShardDurationSec: options.maxShardDurationSec,
  });
  const markdown = renderTimingMarkdown(summary);

  if (options.jsonOutput) {
    ensureParent(options.jsonOutput);
    fs.writeFileSync(options.jsonOutput, JSON.stringify(summary, null, 2), "utf-8");
  }
  if (options.markdownOutput) {
    ensureParent(options.markdownOutput);
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
