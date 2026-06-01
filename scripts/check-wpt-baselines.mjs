#!/usr/bin/env node
//
// Enforce per-module WPT baseline floors against a shard report.
//
// Reads a wpt-runner.ts --json shard report (which now carries a per-module
// `modules` breakdown) and, for every module that has a
// tests/wpt-baselines/<module>.env file, fails when the module's passing count
// drops below BASELINE_PASSED (or its failing count rises above BASELINE_FAILED).
//
// This rides on the shard run the matrix already performs, so it adds no extra
// WPT execution time. Modules without a baseline .env are ignored, so the same
// step is safe to run on every shard.
//
// Usage:
//   node scripts/check-wpt-baselines.mjs <report.json> [<report.json> ...]
//
// Note: WPT layout comparison can flake in CI (e.g. an intermittent font-load
// fallback drifts text-bearing fixtures). A genuine regression reproduces
// locally via `just wpt <module>`; a one-off CI dip is cleared by re-running
// the shard.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const baselineDir = path.join(repoRoot, 'tests', 'wpt-baselines');

const reportPaths = process.argv.slice(2);
if (reportPaths.length === 0) {
  console.error('Usage: node scripts/check-wpt-baselines.mjs <report.json> [...]');
  process.exit(2);
}

function parseBaseline(module) {
  const file = path.join(baselineDir, `${module}.env`);
  if (!fs.existsSync(file)) return null;
  const env = {};
  for (const line of fs.readFileSync(file, 'utf-8').split('\n')) {
    const m = /^([A-Z_]+)=(.*)$/.exec(line.trim());
    if (m) env[m[1]] = m[2];
  }
  const passed = Number.parseInt(env.BASELINE_PASSED ?? '', 10);
  const failed = Number.parseInt(env.BASELINE_FAILED ?? '', 10);
  if (!Number.isFinite(passed) || !Number.isFinite(failed)) return null;
  return { passed, failed };
}

let regressed = 0;
let checked = 0;

for (const reportPath of reportPaths) {
  if (!fs.existsSync(reportPath)) {
    console.error(`✗ report not found: ${reportPath}`);
    process.exit(2);
  }
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf-8'));
  const modules = report.modules;
  if (!modules || typeof modules !== 'object') {
    console.log(`(no per-module breakdown in ${path.basename(reportPath)}; nothing to enforce)`);
    continue;
  }

  for (const [module, result] of Object.entries(modules)) {
    const baseline = parseBaseline(module);
    if (!baseline) continue;
    checked++;
    const okPassed = result.passed >= baseline.passed;
    const okFailed = result.failed <= baseline.failed;
    if (okPassed && okFailed) {
      console.log(
        `✓ ${module}: ${result.passed} passed / ${result.failed} failed ` +
          `(baseline ${baseline.passed} / ${baseline.failed})`,
      );
    } else {
      regressed++;
      console.error(
        `✗ ${module} REGRESSED: ${result.passed} passed / ${result.failed} failed ` +
          `vs baseline ${baseline.passed} passed / ${baseline.failed} failed`,
      );
    }
  }
}

if (checked === 0) {
  console.log('No pinned modules present in the given report(s); nothing to enforce.');
}

if (regressed > 0) {
  console.error(
    `\n${regressed} module(s) regressed below baseline. If this reproduces locally ` +
      `(\`just wpt <module>\`), update tests/wpt-baselines/<module>.env intentionally; ` +
      `otherwise re-run the shard to clear a CI flake.`,
  );
  process.exit(1);
}

console.log(`\nAll ${checked} pinned module baseline(s) held.`);
