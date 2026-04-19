import { describe, expect, it } from "vitest";
import {
  parseBenchRunOutput,
  renderMarkdownSummary,
  summarizeBenchRun,
  type VrtBenchGroup,
} from "./vrt-bench.ts";

function sampleOutput(): string {
  return `
# VRT bench group: api
0\tbench_vrt_render_paint_tree_dashboard
1\tbench_vrt_render_paint_tree_json_component
----- BEGIN MOON TEST RESULT -----
{"package":"mizchi/crater-benchmarks","filename":"vrt_api_bench.mbt","index":"0","test_name":"bench_vrt_render_paint_tree_dashboard","message":"@BATCH_BENCH { \\"summaries\\": [{\\"name\\":\\"vrt_render_paint_tree_dashboard\\",\\"sum\\":1000,\\"min\\":90,\\"max\\":110,\\"mean\\":100,\\"median\\":98,\\"variance\\":4,\\"std_dev\\":2,\\"std_dev_pct\\":2,\\"median_abs_dev\\":1,\\"median_abs_dev_pct\\":1,\\"quartiles\\":[95,98,104],\\"iqr\\":9,\\"batch_size\\":64,\\"runs\\":10}] }"}
----- END MOON TEST RESULT -----
----- BEGIN MOON TEST RESULT -----
{"package":"mizchi/crater-benchmarks","filename":"vrt_api_bench.mbt","index":"1","test_name":"bench_vrt_render_paint_tree_json_component","message":"@BATCH_BENCH { \\"summaries\\": [{\\"name\\":\\"vrt_render_paint_tree_json_component\\",\\"sum\\":550,\\"min\\":50,\\"max\\":60,\\"mean\\":55,\\"median\\":54,\\"variance\\":2,\\"std_dev\\":1.4,\\"std_dev_pct\\":2.5,\\"median_abs_dev\\":1,\\"median_abs_dev_pct\\":1.8,\\"quartiles\\":[53,54,56],\\"iqr\\":3,\\"batch_size\\":128,\\"runs\\":10}] }"}
----- END MOON TEST RESULT -----
`;
}

describe("parseBenchRunOutput", () => {
  it("extracts group and rows from moon bench output", () => {
    const parsed = parseBenchRunOutput(sampleOutput(), "api");

    expect(parsed.group).toBe<VrtBenchGroup>("api");
    expect(parsed.rows).toHaveLength(2);
    expect(parsed.rows[0]?.testName).toBe("bench_vrt_render_paint_tree_dashboard");
    expect(parsed.rows[0]?.summary.name).toBe("vrt_render_paint_tree_dashboard");
    expect(parsed.rows[1]?.summary.batch_size).toBe(128);
  });
});

describe("summarizeBenchRun", () => {
  it("computes totals and highlights the slowest benchmark", () => {
    const parsed = parseBenchRunOutput(sampleOutput(), "api");
    const summary = summarizeBenchRun(parsed);

    expect(summary.totalRows).toBe(2);
    expect(summary.slowest?.testName).toBe("bench_vrt_render_paint_tree_dashboard");
    expect(summary.meanTotal).toBe(155);
  });
});

describe("renderMarkdownSummary", () => {
  it("renders markdown table with headline metrics", () => {
    const parsed = parseBenchRunOutput(sampleOutput(), "api");
    const summary = summarizeBenchRun(parsed);
    const markdown = renderMarkdownSummary(summary);

    expect(markdown).toContain("# VRT Bench Summary (api)");
    expect(markdown).toContain("| Test | Benchmark | Mean | Median | Min | Max | Batch | Runs |");
    expect(markdown).toContain("| bench_vrt_render_paint_tree_dashboard | vrt_render_paint_tree_dashboard | 100.00 | 98.00 | 90.00 | 110.00 | 64 | 10 |");
    expect(markdown).toContain("Slowest benchmark");
  });
});
