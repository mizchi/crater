#!/usr/bin/env node

// Interleaved A/B benchmark runner.
//
// `moon bench` reports each benchmark once per invocation, so the obvious way to
// judge an optimization -- run the whole suite before, run it again after, diff
// the two tables -- charges every benchmark whatever the machine happened to be
// doing at the moment it ran. On a shared or virtualized runner that is enough
// to swamp the signal: a change that touches only layout can come back showing
// double-digit swings in both directions on the HTML tokenizer.
//
// This runner instead alternates the two builds benchmark by benchmark and
// repeats the whole sweep, so both variants meet the same machine within seconds
// of each other, and reports the median of each variant's per-run medians.
// Include a benchmark the change cannot possibly affect (a parser or selector
// benchmark for a layout change) and read its delta as the run's noise floor.
//
// Usage:
//   moon -C benchmarks bench --target js --build-only
//   cp _build/js/release/bench/mizchi/crater-benchmarks/{crater-benchmarks.internal_test.js,package.json,__internal_test_info.json} /tmp/ab/after/
//   git stash && moon -C benchmarks bench --target js --build-only && cp ... /tmp/ab/before/ && git stash pop
//   node benchmarks/scripts/ab-bench.mjs --before /tmp/ab/before --after /tmp/ab/after --reps 9 \
//     --filter deep_flex --filter render_flex --filter parse_simple

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

const BUNDLE_NAME = "crater-benchmarks.internal_test.js";
const INFO_NAME = "__internal_test_info.json";
const PACKAGE = "mizchi/crater-benchmarks";
const DEFAULT_REPS = 9;
const RUN_TIMEOUT_MS = 600_000;

/** Pull the summary object out of one `moon bench` child-process stdout. */
export function parseBatchBench(stdout) {
  for (const line of stdout.split("\n")) {
    if (!line.includes("@BATCH_BENCH")) continue;
    const message = JSON.parse(line).message;
    const payload = message.slice(message.indexOf("@BATCH_BENCH ") + "@BATCH_BENCH ".length);
    const summary = JSON.parse(payload).summaries[0];
    return { name: summary.name, median: summary.median };
  }
  return null;
}

export function median(values) {
  if (values.length === 0) throw new Error("median of an empty sample");
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length >> 1;
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/** Every `b.bench(...)` entry the bundle can run, in declaration order. */
export function collectBenchmarks(info, filters) {
  const out = [];
  for (const [file, entries] of Object.entries(info.with_bench_args_tests ?? {})) {
    for (const entry of entries) {
      if (filters.length > 0 && !filters.some((f) => entry.name.includes(f))) continue;
      out.push({ file, index: entry.index, test: entry.name });
    }
  }
  return out;
}

export function formatMicros(us) {
  return us < 1000 ? `${us.toFixed(2)} µs` : `${(us / 1000).toFixed(2)} ms`;
}

function parseArgs(argv) {
  const args = { reps: DEFAULT_REPS, filter: [], json: null, before: null, after: null };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) throw new Error(`${arg} needs a value`);
      return argv[i];
    };
    if (arg === "--before") args.before = next();
    else if (arg === "--after") args.after = next();
    else if (arg === "--reps") args.reps = Number.parseInt(next(), 10);
    else if (arg === "--filter") args.filter.push(next());
    else if (arg === "--json") args.json = next();
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (!args.before || !args.after) throw new Error("--before and --after are both required");
  if (!Number.isInteger(args.reps) || args.reps < 1) throw new Error("--reps must be a positive integer");
  return args;
}

function runOne(variantDir, item) {
  const filter = JSON.stringify({
    package: PACKAGE,
    file_and_index: [[item.file, [{ start: item.index, end: item.index + 1 }]]],
  });
  const result = spawnSync(process.execPath, [path.join(variantDir, BUNDLE_NAME), filter], {
    encoding: "utf8",
    timeout: RUN_TIMEOUT_MS,
  });
  const parsed = result.stdout ? parseBatchBench(result.stdout) : null;
  if (!parsed) {
    throw new Error(`no benchmark result for ${item.test} in ${variantDir}: ${result.stderr?.slice(0, 400) ?? ""}`);
  }
  return parsed;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const info = JSON.parse(fs.readFileSync(path.join(args.after, INFO_NAME), "utf8"));
  const items = collectBenchmarks(info, args.filter);
  if (items.length === 0) throw new Error("no benchmarks matched --filter");

  const samples = { before: new Map(), after: new Map() };
  const reported = new Map();
  for (let rep = 0; rep < args.reps; rep += 1) {
    for (const item of items) {
      for (const [variant, dir] of [["before", args.before], ["after", args.after]]) {
        const { name, median: value } = runOne(dir, item);
        reported.set(item.test, name);
        const bucket = samples[variant];
        if (!bucket.has(item.test)) bucket.set(item.test, []);
        bucket.get(item.test).push(value);
      }
    }
    process.stderr.write(`  rep ${rep + 1}/${args.reps} done\n`);
  }

  const rows = items.map((item) => {
    const before = median(samples.before.get(item.test));
    const after = median(samples.after.get(item.test));
    return { name: reported.get(item.test), before, after, delta: (100 * (after - before)) / before };
  });

  console.log(`${"delta".padStart(8)}  ${"before".padStart(11)}  ${"after".padStart(11)}  benchmark   (median of ${args.reps} runs)`);
  for (const row of rows) {
    const delta = `${row.delta >= 0 ? "+" : ""}${row.delta.toFixed(1)}%`;
    console.log(
      `${delta.padStart(8)}  ${formatMicros(row.before).padStart(11)}  ${formatMicros(row.after).padStart(11)}  ${row.name}`,
    );
  }
  const overall = median(rows.map((r) => r.delta));
  console.log(`\nmedian delta across ${rows.length} benchmarks: ${overall >= 0 ? "+" : ""}${overall.toFixed(1)}%`);
  if (args.json) fs.writeFileSync(args.json, `${JSON.stringify({ reps: args.reps, rows }, null, 2)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname)) {
  main();
}
