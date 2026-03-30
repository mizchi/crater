import test from "node:test";
import assert from "node:assert/strict";

import {
  BENCHMARK_CONFIG,
  aggregateInvocationSamples,
  checkBaseline,
  validateMetricOutput,
} from "../scripts/crater-cli-bench-baseline.mjs";

function buildSamples(overrides = {}) {
  const samples = {};
  let offset = 1;
  for (const name of Object.keys(BENCHMARK_CONFIG)) {
    samples[name] = overrides[name] ?? [offset, offset + 1, offset + 2];
    offset += 10;
  }
  return samples;
}

function buildAcceptedMetrics() {
  const metrics = {};
  let offset = 1;
  for (const [name, config] of Object.entries(BENCHMARK_CONFIG)) {
    const p50Ms = config.absoluteP50Ms != null ? config.absoluteP50Ms * 0.7 : offset;
    const p95Ms = config.absoluteP95Ms != null ? config.absoluteP95Ms * 0.7 : p50Ms * 1.1;
    metrics[name] = {
      meanMs: (p50Ms + p95Ms) / 2,
      p50Ms,
      p95Ms,
      bestMs: p50Ms * 0.9,
      worstMs: p95Ms * 1.05,
      stddevMs: p50Ms * 0.05,
      sampleCount: 9,
      samplesMs: [p50Ms, p95Ms],
    };
    offset += 1;
  }
  return metrics;
}

test("aggregateInvocationSamples stores p50 and p95 for each CLI metric", () => {
  const aggregated = aggregateInvocationSamples(
    buildSamples({
      crater_cli_layout_selector_s: [32, 34, 33, 36, 41],
    }),
    { warmupRuns: 2, measuredRuns: 5 },
  );
  assert.equal(aggregated.metrics.crater_cli_layout_selector_s.p50Ms, 34);
  assert.equal(aggregated.metrics.crater_cli_layout_selector_s.p95Ms, 40);
  assert.equal(aggregated.metrics.crater_cli_layout_selector_s.sampleCount, 5);
  assert.equal(aggregated.warmupRuns, 2);
  assert.equal(aggregated.measuredRuns, 5);
});

test("checkBaseline accepts CLI samples within absolute and regression budgets", () => {
  const baseline = { metrics: buildAcceptedMetrics() };
  const current = { metrics: buildAcceptedMetrics() };
  for (const [name, metric] of Object.entries(current.metrics)) {
    metric.p50Ms *= 1.04;
    metric.p95Ms *= 1.06;
    metric.meanMs = (metric.p50Ms + metric.p95Ms) / 2;
  }
  assert.doesNotThrow(() => checkBaseline(current, baseline));
});

test("checkBaseline rejects a CLI metric that exceeds the p95 regression budget", () => {
  const baseline = { metrics: buildAcceptedMetrics() };
  const current = { metrics: buildAcceptedMetrics() };
  current.metrics.crater_cli_image_selector_m_file.p95Ms =
    baseline.metrics.crater_cli_image_selector_m_file.p95Ms * 1.5;
  assert.throws(
    () => checkBaseline(current, baseline),
    /crater_cli_image_selector_m_file: p95 regression budget exceeded/,
  );
});

test("validateMetricOutput accepts png-base64 image artifacts", () => {
  const parsed = validateMetricOutput(
    "crater_cli_image_selector_s_file",
    JSON.stringify({
      schemaVersion: 1,
      artifact: "image",
      targetId: "billing-card-root",
      viewport: { width: 640, height: 480 },
      encoding: "png-base64",
      width: 320,
      height: 244,
      data: "iVBORw0KGgoAAAANSUhEUgAA",
    }),
  );
  assert.equal(parsed.encoding, "png-base64");
});

test("validateMetricOutput rejects legacy rgba-base64 image artifacts", () => {
  assert.throws(
    () =>
      validateMetricOutput(
        "crater_cli_image_selector_s_file",
        JSON.stringify({
          schemaVersion: 1,
          artifact: "image",
          targetId: "billing-card-root",
          viewport: { width: 640, height: 480 },
          encoding: "rgba-base64",
          width: 320,
          height: 244,
          data: "AAAA",
        }),
      ),
    /image data must be png-base64/,
  );
});
