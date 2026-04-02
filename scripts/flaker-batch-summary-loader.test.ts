import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { loadFlakerBatchSummaryInputs } from "./flaker-batch-summary-loader.ts";

describe("loadFlakerBatchSummaryInputs", () => {
  it("loads playwright and flaker summaries from downloaded artifacts", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-"));
    fs.mkdirSync(path.join(root, "paint-vrt", "playwright-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "paint-vrt", "flaker-summary"), { recursive: true });

    fs.writeFileSync(
      path.join(root, "paint-vrt", "playwright-summary", "paint-vrt.json"),
      JSON.stringify({
        totals: {
          total: 10,
          passed: 9,
          failed: 1,
          flaky: 0,
          skipped: 0,
          timedout: 0,
          interrupted: 0,
          unknown: 0,
          retries: 1,
          durationMs: 100,
        },
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(root, "paint-vrt", "flaker-summary", "paint-vrt.json"),
      JSON.stringify({
        eval: {
          healthScore: 72,
          resolution: { newFlaky: 1 },
        },
        reason: {
          summary: { urgentFixes: 1 },
        },
      }),
      "utf8",
    );

    const loaded = loadFlakerBatchSummaryInputs(root);

    expect(loaded.playwrightSummaries.get("paint-vrt")?.totals.total).toBe(10);
    expect(loaded.flakerSummaries.get("paint-vrt")?.eval.healthScore).toBe(72);
  });
});
