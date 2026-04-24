import test from "node:test";
import assert from "node:assert/strict";

import {
  BENCHMARK_CONFIG,
  aggregateBenchSamples,
  checkBaseline,
  parseBenchOutput,
} from "../scripts/component-vrt-bench-baseline.mjs";

function buildBenchLine(name, meanValue, meanUnit, stddevValue, stddevUnit, minValue, minUnit, maxValue, maxUnit, sampleRuns) {
  return `${name} ${meanValue} ${meanUnit} ± ${stddevValue} ${stddevUnit} ${minValue} ${minUnit} … ${maxValue} ${maxUnit} in 10 × ${sampleRuns} runs`;
}

function buildParsedSample(meanOverrides = {}) {
  const metrics = {};
  let offset = 1;
  for (const name of Object.keys(BENCHMARK_CONFIG)) {
    const meanMs = meanOverrides[name] ?? offset;
    metrics[name] = {
      meanMs,
      stddevMs: meanMs / 10,
      minMs: meanMs * 0.95,
      maxMs: meanMs * 1.05,
      sampleRuns: 10 + offset,
    };
    offset += 1;
  }
  return {
    command: ["moon", "bench"],
    metrics,
  };
}

test("parseBenchOutput parses the full component VRT benchmark table", () => {
  const lines = [];
  const keys = Object.keys(BENCHMARK_CONFIG);
  let offset = 1;
  for (const name of keys) {
    lines.push(buildBenchLine(name, `${offset}.00`, "ms", "0.10", "ms", `${offset - 0.1}`, "ms", `${offset + 0.2}`, "ms", 10 + offset));
    offset += 1;
  }
  const parsed = parseBenchOutput(lines.join("\n"));
  assert.equal(parsed.metrics.component_landmarks_xs.meanMs, keys.indexOf("component_landmarks_xs") + 1);
  assert.equal(parsed.metrics.component_image_m.meanMs, keys.indexOf("component_image_m") + 1);
  assert.equal(parsed.metrics.component_phase_encode_m.sampleRuns, 11 + keys.indexOf("component_phase_encode_m"));
});

test("aggregateBenchSamples stores p50 and p95 across repeated suite runs", () => {
  const samples = [
    buildParsedSample({ component_layout_m: 15 }),
    buildParsedSample({ component_layout_m: 16 }),
    buildParsedSample({ component_layout_m: 17 }),
    buildParsedSample({ component_layout_m: 18 }),
    buildParsedSample({ component_layout_m: 25 }),
  ];
  const aggregated = aggregateBenchSamples(samples, { warmupRuns: 1, measuredRuns: 5 });
  assert.equal(aggregated.metrics.component_layout_m.p50Ms, 17);
  assert.equal(aggregated.metrics.component_layout_m.p95Ms, 25);
  assert.equal(aggregated.metrics.component_layout_m.suiteRuns, 5);
});

test("checkBaseline accepts a repeated suite sample within p50 and p95 budgets", () => {
  const baseline = {
    metrics: {
      component_landmarks_xs: { p50Ms: 0.04, p95Ms: 0.05 },
      component_landmarks_s: { p50Ms: 0.09, p95Ms: 0.12 },
      component_landmarks_m: { p50Ms: 0.31, p95Ms: 0.35 },
      component_landmarks_l: { p50Ms: 0.5, p95Ms: 0.56 },
      component_layout_xs: { p50Ms: 1.0, p95Ms: 1.1 },
      component_layout_s: { p50Ms: 3.0, p95Ms: 3.4 },
      component_layout_m: { p50Ms: 16.0, p95Ms: 18.0 },
      component_layout_l: { p50Ms: 22.0, p95Ms: 25.0 },
      component_image_xs: { p50Ms: 1.8, p95Ms: 2.0 },
      component_image_s: { p50Ms: 5.8, p95Ms: 6.4 },
      component_image_m: { p50Ms: 27.0, p95Ms: 30.0 },
      component_image_l: { p50Ms: 42.0, p95Ms: 48.0 },
      component_phase_node_layout_m: { p50Ms: 15.5, p95Ms: 17.0 },
      component_phase_extract_m: { p50Ms: 0.00012, p95Ms: 0.00013 },
      component_phase_layout_serialize_m: { p50Ms: 0.06, p95Ms: 0.065 },
      component_phase_aom_build_m: { p50Ms: 0.25, p95Ms: 0.3 },
      component_phase_landmark_extract_m: { p50Ms: 0.0012, p95Ms: 0.0013 },
      component_phase_landmark_serialize_m: { p50Ms: 0.0003, p95Ms: 0.00035 },
      component_phase_paint_m: { p50Ms: 0.015, p95Ms: 0.017 },
      component_phase_raster_m: { p50Ms: 8.3, p95Ms: 8.9 },
      component_phase_encode_m: { p50Ms: 2.8, p95Ms: 3.1 },
    },
  };
  const current = {
    metrics: {
      component_landmarks_xs: { p50Ms: 0.041, p95Ms: 0.055 },
      component_landmarks_s: { p50Ms: 0.095, p95Ms: 0.13 },
      component_landmarks_m: { p50Ms: 0.33, p95Ms: 0.39 },
      component_landmarks_l: { p50Ms: 0.52, p95Ms: 0.6 },
      component_layout_xs: { p50Ms: 1.02, p95Ms: 1.12 },
      component_layout_s: { p50Ms: 3.15, p95Ms: 3.55 },
      component_layout_m: { p50Ms: 16.8, p95Ms: 19.4 },
      component_layout_l: { p50Ms: 22.6, p95Ms: 26.5 },
      component_image_xs: { p50Ms: 1.9, p95Ms: 2.1 },
      component_image_s: { p50Ms: 6.0, p95Ms: 6.8 },
      component_image_m: { p50Ms: 28.5, p95Ms: 33.0 },
      component_image_l: { p50Ms: 43.0, p95Ms: 50.0 },
      component_phase_node_layout_m: { p50Ms: 16.2, p95Ms: 18.5 },
      component_phase_extract_m: { p50Ms: 0.00013, p95Ms: 0.00014 },
      component_phase_layout_serialize_m: { p50Ms: 0.062, p95Ms: 0.07 },
      component_phase_aom_build_m: { p50Ms: 0.27, p95Ms: 0.33 },
      component_phase_landmark_extract_m: { p50Ms: 0.0013, p95Ms: 0.00145 },
      component_phase_landmark_serialize_m: { p50Ms: 0.00032, p95Ms: 0.00038 },
      component_phase_paint_m: { p50Ms: 0.0155, p95Ms: 0.0175 },
      component_phase_raster_m: { p50Ms: 8.6, p95Ms: 9.2 },
      component_phase_encode_m: { p50Ms: 2.9, p95Ms: 3.2 },
    },
  };
  assert.doesNotThrow(() => checkBaseline(current, baseline));
});
