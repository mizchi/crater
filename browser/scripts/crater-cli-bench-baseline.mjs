#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { performance } from "node:perf_hooks";
import { pathToFileURL } from "node:url";

const REPO_ROOT = process.cwd();
const DIST_CRATER_PATH = path.join(REPO_ROOT, "dist", "crater.js");
const BASELINE_PATH = path.join(REPO_ROOT, "tests", "crater-cli-bench-baseline.json");
const DEFAULT_WARMUP_RUNS = 2;
const DEFAULT_MEASURED_RUNS = 9;

const FIXTURE_BASELINE_CSS = String.raw`
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: system-ui, sans-serif;
  background: #f5f7fb;
  color: #162033;
}
a { color: inherit; text-decoration: none; }
button {
  font: inherit;
  border: 0;
  background: transparent;
}
`;

const FIXTURE_DEFINITIONS = {
  s: {
    selector: ".card.primary",
    viewport: { width: 640, height: 480 },
    html: `<!DOCTYPE html>
<html>
  <body>
    <div class="noise-strip"></div>
    <section id="billing-card-root" class="card primary" role="region" aria-label="Billing Card">
      <header class="card-header">
        <p class="eyebrow">Plan</p>
        <h2>Billing</h2>
      </header>
      <nav aria-label="Card Nav" class="card-nav">
        <a href="/">Overview</a>
        <a href="/invoices">Invoices</a>
      </nav>
      <div class="stack">
        <div class="stat-row"><span>Total</span><strong>$128</strong></div>
        <div class="stat-row"><span>Renewal</span><strong>2026-04-18</strong></div>
        <div class="stat-row"><span>Users</span><strong>12 seats</strong></div>
      </div>
      <footer role="contentinfo" aria-label="Card Actions" class="card-footer">
        <button>Upgrade</button>
        <button>Export</button>
      </footer>
    </section>
  </body>
</html>`,
    componentCss: String.raw`
body { padding: 24px; }
.noise-strip {
  width: 420px;
  height: 18px;
  margin-bottom: 12px;
  border-radius: 999px;
  background: #d8e1ef;
}
.card {
  width: 320px;
  padding: 18px;
  border: 1px solid #b8c4da;
  border-radius: 18px;
  background: linear-gradient(180deg, #ffffff 0%, #eef4ff 100%);
}
.card-header h2 {
  margin: 2px 0 0 0;
  font-size: 22px;
}
.eyebrow {
  margin: 0;
  color: #5b6f92;
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.card-nav {
  margin-top: 14px;
}
.card-nav a {
  display: inline-block;
  padding: 6px 10px;
  border-radius: 999px;
  background: #dbe8ff;
}
.card-nav a + a { margin-left: 8px; }
.stack { margin-top: 16px; }
.stat-row {
  padding: 10px 12px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.86);
}
.stat-row + .stat-row { margin-top: 8px; }
.stat-row strong { float: right; }
.card-footer {
  margin-top: 16px;
}
.card-footer button {
  padding: 10px 14px;
  border-radius: 12px;
  background: #162033;
  color: #ffffff;
}
.card-footer button + button {
  margin-left: 8px;
  background: #7f8da8;
}
`,
  },
  m: {
    selector: ".panel.analytics",
    viewport: { width: 800, height: 640 },
    html: `<!DOCTYPE html>
<html>
  <body>
    <div class="hero-shell"></div>
    <section id="analytics-panel-root" class="panel analytics" role="main" aria-label="Analytics Panel">
      <header class="panel-header">
        <div class="title-block">
          <p class="eyebrow">Quarterly Overview</p>
          <h1>Revenue Dashboard</h1>
        </div>
        <nav aria-label="Panel Nav" class="panel-nav">
          <a href="/">Summary</a>
          <a href="/cohorts">Cohorts</a>
          <a href="/alerts">Alerts</a>
        </nav>
      </header>
      <div class="metric-grid">
        <article class="metric-card">
          <h2>Net Revenue</h2>
          <p class="metric-value">$128k</p>
          <p class="metric-note">+14% vs last month</p>
        </article>
        <article class="metric-card">
          <h2>Activation</h2>
          <p class="metric-value">63%</p>
          <p class="metric-note">Up from 58%</p>
        </article>
        <article class="metric-card">
          <h2>Downgrade Risk</h2>
          <p class="metric-value">12 accts</p>
          <p class="metric-note">3 need review</p>
        </article>
      </div>
      <div class="list-panel">
        <div class="list-row list-head">
          <span>Segment</span>
          <span>MRR</span>
          <span>Growth</span>
        </div>
        <div class="list-row"><span>Starter</span><strong>$18k</strong><span>+8%</span></div>
        <div class="list-row"><span>Team</span><strong>$44k</strong><span>+12%</span></div>
        <div class="list-row"><span>Scale</span><strong>$66k</strong><span>+19%</span></div>
        <div class="list-row"><span>Enterprise</span><strong>$96k</strong><span>+27%</span></div>
      </div>
      <aside class="note-stack">
        <section class="note-card" role="region" aria-label="Top Movers">
          <h2>Top Movers</h2>
          <ul>
            <li>Northwind upgraded to annual</li>
            <li>Delta cohort reached 71% activation</li>
            <li>APAC trial churn fell below 4%</li>
          </ul>
        </section>
        <section class="note-card" role="region" aria-label="Risks">
          <h2>Risks</h2>
          <ul>
            <li>3 enterprise renewals due in 10 days</li>
            <li>Auth latency still above SLO in eu-west</li>
            <li>One invoice export queue is backlogged</li>
          </ul>
        </section>
      </aside>
      <footer role="contentinfo" aria-label="Panel Actions" class="panel-footer">
        <button>Share</button>
        <button>Export CSV</button>
        <button>Open Brief</button>
      </footer>
    </section>
  </body>
</html>`,
    componentCss: String.raw`
body { padding: 24px; }
.hero-shell {
  width: 720px;
  height: 20px;
  margin-bottom: 16px;
  border-radius: 999px;
  background: linear-gradient(90deg, #d8e1ef 0%, #eef4ff 100%);
}
.panel {
  width: 680px;
  padding: 20px;
  border: 1px solid #b8c4da;
  border-radius: 20px;
  background: linear-gradient(180deg, #ffffff 0%, #eef4ff 100%);
}
.panel-header { overflow: hidden; }
.title-block { float: left; width: 280px; }
.title-block h1 {
  margin: 4px 0 0 0;
  font-size: 26px;
}
.eyebrow {
  margin: 0;
  color: #5b6f92;
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.panel-nav { float: right; width: 280px; text-align: right; }
.panel-nav a {
  display: inline-block;
  padding: 6px 10px;
  border-radius: 999px;
  background: #dbe8ff;
}
.panel-nav a + a { margin-left: 8px; }
.metric-grid { margin-top: 20px; }
.metric-card {
  display: inline-block;
  width: 205px;
  min-height: 112px;
  padding: 14px;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.86);
  vertical-align: top;
}
.metric-card + .metric-card { margin-left: 8px; }
.metric-card h2 {
  margin: 0;
  font-size: 16px;
}
.metric-value {
  margin: 10px 0 0 0;
  font-size: 28px;
  font-weight: 700;
}
.metric-note {
  margin: 8px 0 0 0;
  color: #5b6f92;
}
.list-panel {
  margin-top: 18px;
  padding: 14px;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.86);
}
.list-row {
  padding: 8px 0;
  border-top: 1px solid #d7dfef;
}
.list-row span,
.list-row strong {
  display: inline-block;
  width: 32%;
}
.list-head {
  border-top: 0;
  color: #5b6f92;
  font-size: 13px;
  text-transform: uppercase;
}
.note-stack { margin-top: 18px; }
.note-card {
  display: inline-block;
  width: 327px;
  min-height: 138px;
  padding: 14px;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.86);
  vertical-align: top;
}
.note-card + .note-card { margin-left: 8px; }
.note-card h2 {
  margin: 0 0 10px 0;
  font-size: 18px;
}
.note-card ul {
  margin: 0;
  padding-left: 18px;
}
.note-card li + li { margin-top: 8px; }
.panel-footer { margin-top: 18px; }
.panel-footer button {
  padding: 10px 14px;
  border-radius: 12px;
  background: #162033;
  color: #ffffff;
}
.panel-footer button + button {
  margin-left: 8px;
  background: #7f8da8;
}
`,
  },
};

export const BENCHMARK_CONFIG = {
  crater_cli_landmarks_selector_s: {
    fixture: "s",
    artifact: "landmarks",
    outputMode: "stdout",
    useCssFiles: false,
    absoluteP50Ms: 70,
    absoluteP95Ms: 100,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  crater_cli_landmarks_selector_m: {
    fixture: "m",
    artifact: "landmarks",
    outputMode: "stdout",
    useCssFiles: false,
    absoluteP50Ms: 70,
    absoluteP95Ms: 105,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  crater_cli_layout_selector_s: {
    fixture: "s",
    artifact: "layout",
    outputMode: "stdout",
    useCssFiles: true,
    absoluteP50Ms: 105,
    absoluteP95Ms: 130,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  crater_cli_layout_selector_m: {
    fixture: "m",
    artifact: "layout",
    outputMode: "stdout",
    useCssFiles: true,
    absoluteP50Ms: 125,
    absoluteP95Ms: 180,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  crater_cli_image_selector_s_file: {
    fixture: "s",
    artifact: "image",
    outputMode: "file",
    useCssFiles: true,
    absoluteP50Ms: 135,
    absoluteP95Ms: 175,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
  crater_cli_image_selector_m_file: {
    fixture: "m",
    artifact: "image",
    outputMode: "file",
    useCssFiles: true,
    absoluteP50Ms: 270,
    absoluteP95Ms: 350,
    maxP50RegressionRatio: 0.1,
    maxP95RegressionRatio: 0.25,
  },
};

function parsePositiveInt(value, label) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${label} must be a non-negative integer: ${value}`);
  }
  return parsed;
}

export function formatMs(value) {
  return `${value.toFixed(2)}ms`;
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

function stddev(values) {
  if (values.length === 0) {
    throw new Error("stddev() requires at least one value");
  }
  const mean = average(values);
  const variance = average(values.map((value) => (value - mean) ** 2));
  return Math.sqrt(variance);
}

export function nearestRank(values, ratio) {
  if (values.length === 0) {
    throw new Error("nearestRank() requires at least one value");
  }
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(sorted.length * ratio) - 1));
  return sorted[index];
}

export function interpolatedPercentile(values, ratio) {
  if (values.length === 0) {
    throw new Error("interpolatedPercentile() requires at least one value");
  }
  const sorted = [...values].sort((left, right) => left - right);
  if (sorted.length === 1) {
    return sorted[0];
  }
  const position = Math.min(sorted.length - 1, Math.max(0, ratio * (sorted.length - 1)));
  const lowerIndex = Math.floor(position);
  const upperIndex = Math.ceil(position);
  if (lowerIndex === upperIndex) {
    return sorted[lowerIndex];
  }
  const fraction = position - lowerIndex;
  return sorted[lowerIndex] + (sorted[upperIndex] - sorted[lowerIndex]) * fraction;
}

function ensureCraterDistBuilt() {
  const commands = [
    ["npm", ["run", "build:moon"]],
    ["npm", ["run", "build:minify:crater"]],
  ];
  for (const [command, args] of commands) {
    const result = spawnSync(command, args, {
      cwd: REPO_ROOT,
      encoding: "utf8",
      env: {
        ...process.env,
        TERM: "dumb",
      },
    });
    if (result.status !== 0) {
      process.stderr.write(`${result.stdout ?? ""}${result.stderr ?? ""}`);
      process.exit(result.status ?? 1);
    }
  }
}

function createFixtureFiles() {
  const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-cli-bench-"));
  const fixtures = {
    rootDir,
  };
  for (const [name, definition] of Object.entries(FIXTURE_DEFINITIONS)) {
    const htmlPath = path.join(rootDir, `${name}.html`);
    const baselineCssPath = path.join(rootDir, `${name}-baseline.css`);
    const componentCssPath = path.join(rootDir, `${name}-component.css`);
    fs.writeFileSync(htmlPath, definition.html, "utf8");
    fs.writeFileSync(baselineCssPath, FIXTURE_BASELINE_CSS, "utf8");
    fs.writeFileSync(componentCssPath, definition.componentCss, "utf8");
    fixtures[name] = {
      ...definition,
      htmlPath,
      baselineCssPath,
      componentCssPath,
    };
  }
  return fixtures;
}

function cleanupFixtureFiles(fixtures) {
  if (!fixtures?.rootDir) return;
  fs.rmSync(fixtures.rootDir, { recursive: true, force: true });
}

function outputPathForMetric(fixtures, metricName) {
  return path.join(fixtures.rootDir, `${metricName}.json`);
}

function buildMetricArgs(metricName, fixtures) {
  const config = BENCHMARK_CONFIG[metricName];
  const fixture = fixtures[config.fixture];
  const args = [
    DIST_CRATER_PATH,
    "--html-file",
    fixture.htmlPath,
    "--target-selector",
    fixture.selector,
    "--artifact",
    config.artifact,
    "--viewport-width",
    String(fixture.viewport.width),
    "--viewport-height",
    String(fixture.viewport.height),
  ];
  if (config.useCssFiles) {
    args.push("--css-file", fixture.baselineCssPath, "--css-file", fixture.componentCssPath);
  }
  if (config.outputMode === "file") {
    args.push("--output-file", outputPathForMetric(fixtures, metricName));
  }
  return args;
}

export function validateMetricOutput(metricName, artifactText) {
  const config = BENCHMARK_CONFIG[metricName];
  const parsed = JSON.parse(artifactText);
  if (parsed.artifact !== config.artifact) {
    throw new Error(`${metricName}: expected artifact ${config.artifact}, got ${parsed.artifact}`);
  }
  if (typeof parsed.targetId !== "string" || parsed.targetId.length === 0) {
    throw new Error(`${metricName}: targetId was not resolved`);
  }
  if (config.artifact === "landmarks" && !Array.isArray(parsed.data)) {
    throw new Error(`${metricName}: landmarks data must be an array`);
  }
  if (config.artifact === "layout" && (typeof parsed.data !== "object" || parsed.data == null)) {
    throw new Error(`${metricName}: layout data must be an object`);
  }
  if (
    config.artifact === "image" &&
    (
      parsed.encoding !== "png-base64" ||
      typeof parsed.data !== "string" ||
      parsed.data.length === 0 ||
      !parsed.data.startsWith("iVBORw0KGgo")
    )
  ) {
    throw new Error(`${metricName}: image data must be png-base64`);
  }
  return parsed;
}

function runMetricOnce(metricName, fixtures) {
  const args = buildMetricArgs(metricName, fixtures);
  const outputPath = outputPathForMetric(fixtures, metricName);
  fs.rmSync(outputPath, { force: true });
  const start = performance.now();
  const result = spawnSync(process.execPath, args, {
    cwd: REPO_ROOT,
    encoding: "utf8",
    env: {
      ...process.env,
      TERM: "dumb",
      CRATER_RENDERER_PERF_LOG: "0",
    },
  });
  const durationMs = performance.now() - start;
  if (result.status !== 0) {
    throw new Error(`${metricName} failed:\n${result.stdout ?? ""}${result.stderr ?? ""}`);
  }
  const artifactText =
    BENCHMARK_CONFIG[metricName].outputMode === "file"
      ? fs.readFileSync(outputPath, "utf8")
      : result.stdout;
  validateMetricOutput(metricName, artifactText);
  return {
    durationMs,
    outputBytes: Buffer.byteLength(artifactText),
  };
}

export function aggregateInvocationSamples(samplesByMetric, options = {}) {
  const metrics = {};
  for (const name of Object.keys(BENCHMARK_CONFIG)) {
    const rawSamples = samplesByMetric[name];
    if (!rawSamples || rawSamples.length === 0) {
      throw new Error(`Missing samples for benchmark: ${name}`);
    }
    const normalized = rawSamples.map((sample) =>
      typeof sample === "number"
        ? { durationMs: sample, outputBytes: 0 }
        : { durationMs: sample.durationMs, outputBytes: sample.outputBytes ?? 0 },
    );
    const durations = normalized.map((sample) => sample.durationMs);
    const outputBytes = normalized.map((sample) => sample.outputBytes);
    metrics[name] = {
      meanMs: average(durations),
      p50Ms: interpolatedPercentile(durations, 0.5),
      p95Ms: interpolatedPercentile(durations, 0.95),
      bestMs: Math.min(...durations),
      worstMs: Math.max(...durations),
      stddevMs: stddev(durations),
      meanOutputBytes: average(outputBytes),
      sampleCount: durations.length,
      samplesMs: durations,
    };
  }
  return {
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
    command: [process.execPath, DIST_CRATER_PATH],
    warmupRuns: options.warmupRuns ?? 0,
    measuredRuns: options.measuredRuns ?? 0,
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

function printSummary(data) {
  for (const name of Object.keys(BENCHMARK_CONFIG)) {
    const metric = data.metrics[name];
    console.log(
      `${name}: p50=${formatMs(metric.p50Ms)} p95=${formatMs(metric.p95Ms)} mean=${formatMs(metric.meanMs)} spread=${formatMs(metric.bestMs)}..${formatMs(metric.worstMs)} bytes=${Math.round(metric.meanOutputBytes)}`,
    );
  }
}

export function checkBaseline(current, baseline) {
  const failures = [];
  for (const [name, config] of Object.entries(BENCHMARK_CONFIG)) {
    const curr = current.metrics[name];
    const base = baseline.metrics[name];
    if (!curr) {
      failures.push(`${name}: missing from current sample`);
      continue;
    }
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
    throw new Error(failures.join("\n"));
  }
}

function runMeasuredBenchmarks(options) {
  const fixtures = createFixtureFiles();
  try {
    for (let index = 0; index < options.warmupRuns; index += 1) {
      console.error(`warmup ${index + 1}/${options.warmupRuns}`);
      for (const name of Object.keys(BENCHMARK_CONFIG)) {
        runMetricOnce(name, fixtures);
      }
    }
    const samplesByMetric = Object.fromEntries(
      Object.keys(BENCHMARK_CONFIG).map((name) => [name, []]),
    );
    for (let index = 0; index < options.measuredRuns; index += 1) {
      console.error(`measure ${index + 1}/${options.measuredRuns}`);
      for (const name of Object.keys(BENCHMARK_CONFIG)) {
        samplesByMetric[name].push(runMetricOnce(name, fixtures));
      }
    }
    return aggregateInvocationSamples(samplesByMetric, options);
  } finally {
    cleanupFixtureFiles(fixtures);
  }
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
  console.error("Usage: node scripts/crater-cli-bench-baseline.mjs [check|update|print] [--warmup N] [--runs N]");
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
  ensureCraterDistBuilt();
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
    console.error("Run: node scripts/crater-cli-bench-baseline.mjs update");
    process.exit(1);
  }
  try {
    checkBaseline(current, baseline);
  } catch (error) {
    console.error("\nCrater CLI bench baseline check failed:");
    for (const line of String(error.message ?? error).split("\n")) {
      console.error(`- ${line}`);
    }
    process.exit(1);
  }
  console.log("\nCrater CLI bench baseline check passed.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
