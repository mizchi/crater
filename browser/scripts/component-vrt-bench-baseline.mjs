#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const BASELINE_PATH = path.join(process.cwd(), "tests", "component-vrt-bench-baseline.json");
const BENCH_COMMAND = [
  "bench",
  "-p",
  "mizchi/crater-browser/shell",
  "-f",
  "component_vrt_bench_wbtest.mbt",
  "--target",
  "js",
  "--frozen",
];
const DEFAULT_WARMUP_RUNS = 1;
const DEFAULT_MEASURED_RUNS = 5;

export const BENCHMARK_CONFIG = {
  component_landmarks_xs: {
    absoluteP50Ms: 0.08,
    absoluteP95Ms: 0.12,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_landmarks_s: {
    absoluteP50Ms: 0.2,
    absoluteP95Ms: 0.3,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_landmarks_m: {
    absoluteP50Ms: 0.5,
    absoluteP95Ms: 0.8,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_landmarks_l: {
    absoluteP50Ms: 0.8,
    absoluteP95Ms: 1.2,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_layout_xs: {
    absoluteP50Ms: 4,
    absoluteP95Ms: 8,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_layout_s: {
    absoluteP50Ms: 8,
    absoluteP95Ms: 15,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_layout_m: {
    absoluteP50Ms: 20,
    absoluteP95Ms: 35,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_layout_l: {
    absoluteP50Ms: 40,
    absoluteP95Ms: 75,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_image_xs: {
    absoluteP50Ms: 8,
    absoluteP95Ms: 15,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  component_image_s: {
    absoluteP50Ms: 15,
    absoluteP95Ms: 28,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  component_image_m: {
    absoluteP50Ms: 35,
    absoluteP95Ms: 60,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  component_image_l: {
    absoluteP50Ms: 80,
    absoluteP95Ms: 140,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  component_phase_node_layout_m: {
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_phase_extract_m: {
    maxP50RegressionRatio: 0.15,
    maxP95RegressionRatio: 0.2,
  },
  component_phase_layout_serialize_m: {
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_phase_aom_build_m: {
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_phase_landmark_extract_m: {
    maxP50RegressionRatio: 0.15,
    maxP95RegressionRatio: 0.2,
  },
  component_phase_landmark_serialize_m: {
    maxP50RegressionRatio: 0.15,
    maxP95RegressionRatio: 0.2,
  },
  component_phase_paint_m: {
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_phase_raster_m: {
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
  component_phase_encode_m: {
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.15,
  },
};

function parsePositiveInt(value, label) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${label} must be a non-negative integer: ${value}`);
  }
  return parsed;
}

export function unitToMs(value, unit) {
  if (unit === "s") return value * 1000;
  if (unit === "ms") return value;
  if (unit === "us" || unit === "µs" || unit === "μs") return value / 1000;
  if (unit === "ns") return value / 1_000_000;
  throw new Error(`Unsupported unit: ${unit}`);
}

export function formatMs(value) {
  if (value >= 1) return `${value.toFixed(2)}ms`;
  if (value >= 0.001) return `${(value * 1000).toFixed(2)}us`;
  return `${(value * 1_000_000).toFixed(2)}ns`;
}

function withSign(value) {
  return `${value >= 0 ? "+" : ""}${value.toFixed(2)}%`;
}

function average(values) {
  if (values.length === 0) {
    throw new Error("average() requires at least one value");
  }
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

export function nearestRank(values, ratio) {
  if (values.length === 0) {
    throw new Error("nearestRank() requires at least one value");
  }
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(sorted.length * ratio) - 1));
  return sorted[index];
}

function runBenchOnce() {
  const result = spawnSync("moon", BENCH_COMMAND, {
    cwd: process.cwd(),
    encoding: "utf8",
    env: {
      ...process.env,
      CRATER_RENDERER_PERF_LOG: "0",
      TERM: "dumb",
    },
  });
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  if (result.status !== 0) {
    process.stderr.write(output);
    process.exit(result.status ?? 1);
  }
  return parseBenchOutput(output);
}

export function parseBenchOutput(output) {
  const metrics = {};
  const linePattern =
    /^(component_[a-z_]+)\s+([0-9.]+)\s+(ns|us|µs|μs|ms|s)\s+±\s+([0-9.]+)\s+(ns|us|µs|μs|ms|s)\s+([0-9.]+)\s+(ns|us|µs|μs|ms|s)\s+…\s+([0-9.]+)\s+(ns|us|µs|μs|ms|s)\s+in\s+\d+\s+×\s+(\d+)\s+runs$/;
  for (const rawLine of output.split(/\r?\n/)) {
    const line = rawLine.trim();
    const match = line.match(linePattern);
    if (!match) continue;
    const [
      ,
      name,
      meanValue,
      meanUnit,
      stddevValue,
      stddevUnit,
      minValue,
      minUnit,
      maxValue,
      maxUnit,
      sampleRuns,
    ] = match;
    metrics[name] = {
      meanMs: unitToMs(Number(meanValue), meanUnit),
      stddevMs: unitToMs(Number(stddevValue), stddevUnit),
      minMs: unitToMs(Number(minValue), minUnit),
      maxMs: unitToMs(Number(maxValue), maxUnit),
      sampleRuns: Number(sampleRuns),
    };
  }
  const expectedNames = Object.keys(BENCHMARK_CONFIG);
  const missing = expectedNames.filter((name) => !(name in metrics));
  if (missing.length > 0) {
    throw new Error(`Failed to parse benchmark output for: ${missing.join(", ")}`);
  }
  return {
    command: ["moon", ...BENCH_COMMAND],
    metrics,
  };
}

export function aggregateBenchSamples(samples, options = {}) {
  if (samples.length === 0) {
    throw new Error("aggregateBenchSamples() requires at least one measured sample");
  }
  const metrics = {};
  for (const name of Object.keys(BENCHMARK_CONFIG)) {
    const meanValues = samples.map((sample) => sample.metrics[name].meanMs);
    const stddevValues = samples.map((sample) => sample.metrics[name].stddevMs);
    const minValues = samples.map((sample) => sample.metrics[name].minMs);
    const maxValues = samples.map((sample) => sample.metrics[name].maxMs);
    metrics[name] = {
      meanMs: average(meanValues),
      p50Ms: nearestRank(meanValues, 0.5),
      p95Ms: nearestRank(meanValues, 0.95),
      bestMs: Math.min(...minValues),
      worstMs: Math.max(...maxValues),
      meanStddevMs: average(stddevValues),
      suiteRuns: samples.length,
      sampleRuns: samples.map((sample) => sample.metrics[name].sampleRuns),
      perRunMeanMs: meanValues,
    };
  }
  return {
    schemaVersion: 2,
    updatedAt: new Date().toISOString(),
    command: ["moon", ...BENCH_COMMAND],
    warmupRuns: options.warmupRuns ?? 0,
    measuredRuns: options.measuredRuns ?? samples.length,
    metrics,
  };
}

function loadBaseline() {
  try {
    return JSON.parse(fs.readFileSync(BASELINE_PATH, "utf8"));
  } catch {
    return null;
  }
}

function saveBaseline(data) {
  fs.writeFileSync(BASELINE_PATH, `${JSON.stringify(data, null, 2)}\n`);
}

function getMetricStats(metric) {
  if (metric.p50Ms != null && metric.p95Ms != null) {
    return {
      meanMs: metric.meanMs,
      p50Ms: metric.p50Ms,
      p95Ms: metric.p95Ms,
      bestMs: metric.bestMs,
      worstMs: metric.worstMs,
      meanStddevMs: metric.meanStddevMs,
      suiteRuns: metric.suiteRuns ?? 1,
    };
  }
  return {
    meanMs: metric.meanMs,
    p50Ms: metric.meanMs,
    p95Ms: metric.meanMs,
    bestMs: metric.minMs,
    worstMs: metric.maxMs,
    meanStddevMs: metric.stddevMs ?? 0,
    suiteRuns: 1,
  };
}

function printSummary(data) {
  for (const name of Object.keys(BENCHMARK_CONFIG)) {
    const metric = getMetricStats(data.metrics[name]);
    console.log(
      `${name}: p50=${formatMs(metric.p50Ms)} p95=${formatMs(metric.p95Ms)} mean=${formatMs(metric.meanMs)} spread=${formatMs(metric.bestMs)}..${formatMs(metric.worstMs)} suiteRuns=${metric.suiteRuns}`,
    );
  }
}

export function checkBaseline(current, baseline) {
  const failures = [];
  for (const [name, config] of Object.entries(BENCHMARK_CONFIG)) {
    const curr = getMetricStats(current.metrics[name]);
    const base = baseline.metrics[name] ? getMetricStats(baseline.metrics[name]) : null;
    if (!base) {
      failures.push(`${name}: missing from baseline`);
      continue;
    }
    const p50RegressionRatio = base.p50Ms > 0 ? (curr.p50Ms - base.p50Ms) / base.p50Ms : 0;
    const p95RegressionRatio = base.p95Ms > 0 ? (curr.p95Ms - base.p95Ms) / base.p95Ms : 0;
    console.log(
      `${name}: p50 baseline=${formatMs(base.p50Ms)} current=${formatMs(curr.p50Ms)} delta=${withSign(p50RegressionRatio * 100)} | p95 baseline=${formatMs(base.p95Ms)} current=${formatMs(curr.p95Ms)} delta=${withSign(p95RegressionRatio * 100)}`,
    );
    if (config.absoluteP50Ms != null && curr.p50Ms > config.absoluteP50Ms) {
      failures.push(`${name}: p50 absolute budget exceeded (${formatMs(curr.p50Ms)} > ${formatMs(config.absoluteP50Ms)})`);
    }
    if (config.absoluteP95Ms != null && curr.p95Ms > config.absoluteP95Ms) {
      failures.push(`${name}: p95 absolute budget exceeded (${formatMs(curr.p95Ms)} > ${formatMs(config.absoluteP95Ms)})`);
    }
    if (p50RegressionRatio > config.maxP50RegressionRatio) {
      failures.push(
        `${name}: p50 regression budget exceeded (${withSign(p50RegressionRatio * 100)} > +${(config.maxP50RegressionRatio * 100).toFixed(2)}%)`,
      );
    }
    if (p95RegressionRatio > config.maxP95RegressionRatio) {
      failures.push(
        `${name}: p95 regression budget exceeded (${withSign(p95RegressionRatio * 100)} > +${(config.maxP95RegressionRatio * 100).toFixed(2)}%)`,
      );
    }
  }
  if (failures.length > 0) {
    console.error("\nComponent VRT bench baseline check failed:");
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exit(1);
  }
  console.log("\nComponent VRT bench baseline check passed.");
}

function runMeasuredBenchmarks(options) {
  for (let index = 0; index < options.warmupRuns; index += 1) {
    console.error(`warmup ${index + 1}/${options.warmupRuns}`);
    runBenchOnce();
  }
  const measured = [];
  for (let index = 0; index < options.measuredRuns; index += 1) {
    console.error(`measure ${index + 1}/${options.measuredRuns}`);
    measured.push(runBenchOnce());
  }
  return aggregateBenchSamples(measured, options);
}

function parseArgs(argv) {
  let mode = "check";
  let warmupRuns = DEFAULT_WARMUP_RUNS;
  let measuredRuns = DEFAULT_MEASURED_RUNS;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "check" || arg === "update" || arg === "print") {
      mode = arg;
      continue;
    }
    if (arg === "--warmup") {
      warmupRuns = parsePositiveInt(argv[index + 1], "--warmup");
      index += 1;
      continue;
    }
    if (arg === "--runs") {
      measuredRuns = parsePositiveInt(argv[index + 1], "--runs");
      index += 1;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }
  if (measuredRuns === 0) {
    throw new Error("--runs must be greater than zero");
  }
  return { mode, warmupRuns, measuredRuns };
}

function printUsage() {
  console.error("Usage: node scripts/component-vrt-bench-baseline.mjs [check|update|print] [--warmup N] [--runs N]");
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(String(error.message ?? error));
    printUsage();
    process.exit(1);
  }
  const current = runMeasuredBenchmarks(args);
  if (args.mode === "update") {
    saveBaseline(current);
    console.log(`Updated baseline: ${BASELINE_PATH}`);
    printSummary(current);
    return;
  }
  if (args.mode === "print") {
    printSummary(current);
    return;
  }
  const baseline = loadBaseline();
  if (!baseline) {
    console.error(`Baseline file not found: ${BASELINE_PATH}`);
    console.error("Run: node scripts/component-vrt-bench-baseline.mjs update");
    process.exit(1);
  }
  checkBaseline(current, baseline);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
