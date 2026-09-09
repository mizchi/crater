import test from "node:test";
import assert from "node:assert/strict";

import {
  collectBenchmarks,
  formatMicros,
  median,
  parseBatchBench,
} from "../scripts/ab-bench.mjs";

function benchLine(name, medianUs) {
  const summary = { name, median: medianUs, mean: medianUs, runs: 10 };
  return JSON.stringify({
    type: "result",
    file: "render_bench.mbt",
    index: 27,
    message: `@BATCH_BENCH ${JSON.stringify({ summaries: [summary] })}`,
  });
}

test("parseBatchBench picks the summary out of a moon bench stdout", () => {
  const stdout = [
    "----- BEGIN MOON TEST RESULT -----",
    JSON.stringify({ type: "start", file: "render_bench.mbt", index: 27 }),
    "----- END MOON TEST RESULT -----",
    benchLine("render_large_2k5", 41226.62),
    "----- END MOON TEST RESULT -----",
  ].join("\n");

  assert.deepEqual(parseBatchBench(stdout), {
    name: "render_large_2k5",
    median: 41226.62,
  });
});

test("parseBatchBench returns null when the child produced no benchmark", () => {
  assert.equal(parseBatchBench("moonbit test driver crashed\n"), null);
});

test("median is order independent and averages the middle pair when even", () => {
  assert.equal(median([3, 1, 2]), 2);
  assert.equal(median([4, 1, 3, 2]), 2.5);
  assert.throws(() => median([]), /empty sample/);
});

test("collectBenchmarks flattens every file and honours name filters", () => {
  const info = {
    with_bench_args_tests: {
      "layout_bench.mbt": [
        { index: 0, name: "bench_flat_block_10" },
        { index: 6, name: "bench_nested_flex_depth4" },
      ],
      "parse_bench.mbt": [{ index: 3, name: "bench_parse_flat_100" }],
    },
  };

  assert.equal(collectBenchmarks(info, []).length, 3);
  assert.deepEqual(collectBenchmarks(info, ["flex", "parse_flat"]), [
    { file: "layout_bench.mbt", index: 6, test: "bench_nested_flex_depth4" },
    { file: "parse_bench.mbt", index: 3, test: "bench_parse_flat_100" },
  ]);
});

test("collectBenchmarks tolerates a bundle that declares no benchmarks", () => {
  assert.deepEqual(collectBenchmarks({}, []), []);
});

test("formatMicros switches to milliseconds past 1000 µs", () => {
  assert.equal(formatMicros(41.5), "41.50 µs");
  assert.equal(formatMicros(999.994), "999.99 µs");
  assert.equal(formatMicros(41226.62), "41.23 ms");
});
