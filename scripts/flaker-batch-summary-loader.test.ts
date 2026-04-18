import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { loadFlakerBatchSummaryInputs } from "./flaker-batch-summary-loader.ts";

describe("loadFlakerBatchSummaryInputs", () => {
  it("loads playwright, flaker, and vrt summaries from downloaded artifacts", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-"));
    fs.mkdirSync(path.join(root, "paint-vrt", "playwright-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "paint-vrt", "flaker-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "paint-vrt", "vrt-summary"), { recursive: true });

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
    fs.writeFileSync(
      path.join(root, "paint-vrt", "vrt-summary", "paint-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact-summary",
        generatedAt: "2026-04-02T00:00:00.000Z",
        label: "paint-vrt",
        total: 3,
        budgeted: 3,
        passed: 2,
        failed: 1,
        unknown: 0,
        averageDiffRatio: 0.08,
        maxObservedDiffRatio: 0.2,
        cssRuleUsage: {
          reports: 1,
          totalRules: 10,
          deadRules: 4,
          unusedRules: 1,
          overriddenRules: 1,
          noEffectRules: 2,
        },
        rows: [],
        failures: [],
        closestToBudget: [],
      }),
      "utf8",
    );

    const loaded = loadFlakerBatchSummaryInputs(root);

    expect(loaded.playwrightSummaries.get("paint-vrt")?.totals.total).toBe(10);
    expect(loaded.flakerSummaries.get("paint-vrt")?.eval.healthScore).toBe(72);
    expect(loaded.vrtSummaries.get("paint-vrt")).toEqual({
      failed: 1,
      unknown: 0,
      maxDiffRatio: 0.2,
      cssDeadRules: 4,
      cssTotalRules: 10,
      cssUnusedRules: 1,
      cssOverriddenRules: 1,
      cssNoEffectRules: 2,
    });
  });

  it("normalizes wpt-vrt summary artifacts into batch VRT metrics", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-wpt-vrt-"));
    fs.mkdirSync(path.join(root, "wpt-vrt", "wpt-vrt-summary"), { recursive: true });

    fs.writeFileSync(
      path.join(root, "wpt-vrt", "wpt-vrt-summary", "wpt-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "wpt-vrt",
        generatedAt: "2026-04-02T00:00:00.000Z",
        label: "wpt-vrt",
        shardName: "wpt-vrt",
        modules: ["css-flexbox"],
        offset: 0,
        limit: 10,
        total: 2,
        expectedTotal: 3,
        passed: 1,
        failed: 1,
        regressionCount: 1,
        passRate: 0.5,
        maxDiffRatio: 0.08,
        moduleTotals: [
          {
            module: "css-flexbox",
            total: 2,
            passed: 1,
            failed: 1,
            passRate: 0.5,
          },
        ],
        failures: [
          {
            relativePath: "css-flexbox/gap-002.html",
            module: "css-flexbox",
            diffRatio: 0.08,
            status: "fail",
          },
        ],
        closestToThreshold: [],
        regressions: [],
      }),
      "utf8",
    );

    const loaded = loadFlakerBatchSummaryInputs(root);

    expect(loaded.vrtSummaries.get("wpt-vrt")).toEqual({
      failed: 1,
      unknown: 1,
      maxDiffRatio: 0.08,
    });
  });

  it("ignores aggregate wpt-vrt summary artifacts that are not task-scoped collect paths", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-wpt-vrt-aggregate-"));
    fs.mkdirSync(path.join(root, "wpt-vrt", "wpt-vrt-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "wpt-vrt-summary"), { recursive: true });

    fs.writeFileSync(
      path.join(root, "wpt-vrt", "wpt-vrt-summary", "wpt-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "wpt-vrt",
        generatedAt: "2026-04-02T00:00:00.000Z",
        label: "wpt-vrt",
        shardName: "wpt-vrt",
        modules: ["css-flexbox"],
        offset: 0,
        limit: 10,
        total: 2,
        expectedTotal: 3,
        passed: 1,
        failed: 1,
        regressionCount: 1,
        passRate: 0.5,
        maxDiffRatio: 0.08,
        moduleTotals: [
          {
            module: "css-flexbox",
            total: 2,
            passed: 1,
            failed: 1,
            passRate: 0.5,
          },
        ],
        failures: [
          {
            relativePath: "css-flexbox/gap-002.html",
            module: "css-flexbox",
            diffRatio: 0.08,
            status: "fail",
          },
        ],
        closestToThreshold: [],
        regressions: [],
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(root, "wpt-vrt-summary", "wpt-vrt-summary.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "wpt-vrt",
        generatedAt: "2026-04-02T00:00:00.000Z",
        rows: [
          {
            schemaVersion: 1,
            suite: "wpt-vrt",
            generatedAt: "2026-04-02T00:00:00.000Z",
            label: "wpt-vrt",
            shardName: "wpt-vrt",
            modules: ["css-flexbox"],
            offset: 0,
            limit: 10,
            total: 2,
            expectedTotal: 3,
            passed: 1,
            failed: 1,
            regressionCount: 1,
            passRate: 0.5,
            maxDiffRatio: 0.08,
            moduleTotals: [
              {
                module: "css-flexbox",
                total: 2,
                passed: 1,
                failed: 1,
                passRate: 0.5,
              },
            ],
            failures: [
              {
                relativePath: "css-flexbox/gap-002.html",
                module: "css-flexbox",
                diffRatio: 0.08,
                status: "fail",
              },
            ],
            closestToThreshold: [],
            regressions: [],
          },
        ],
        total: {
          total: 2,
          passed: 1,
          failed: 1,
          regressions: 1,
          passRate: 0.5,
          shards: 1,
        },
        byModule: [],
        topFailures: [],
        topRegressions: [],
      }),
      "utf8",
    );

    const loaded = loadFlakerBatchSummaryInputs(root);

    expect(loaded.vrtSummaries.get("wpt-vrt")).toEqual({
      failed: 1,
      unknown: 1,
      maxDiffRatio: 0.08,
    });
    expect(loaded.vrtSummaries.has("wpt-vrt-summary")).toBe(false);
  });

  it("ignores malformed collected summaries instead of throwing", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "crater-flaker-batch-summary-invalid-"));
    fs.mkdirSync(path.join(root, "paint-vrt", "playwright-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "paint-vrt", "flaker-summary"), { recursive: true });
    fs.mkdirSync(path.join(root, "paint-vrt", "vrt-summary"), { recursive: true });

    fs.writeFileSync(
      path.join(root, "paint-vrt", "playwright-summary", "paint-vrt.json"),
      "{not-json",
      "utf8",
    );
    fs.writeFileSync(
      path.join(root, "paint-vrt", "flaker-summary", "paint-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        taskId: "paint-vrt",
      }),
      "utf8",
    );
    fs.writeFileSync(
      path.join(root, "paint-vrt", "vrt-summary", "paint-vrt.json"),
      JSON.stringify({
        schemaVersion: 1,
        suite: "vrt-artifact-summary",
        generatedAt: "2026-04-02T00:00:00.000Z",
        label: "paint-vrt",
        total: 1,
        budgeted: 1,
        passed: 0,
        failed: 1,
        unknown: 0,
        averageDiffRatio: 0.2,
        maxObservedDiffRatio: 0.2,
        rows: [],
        failures: [],
        closestToBudget: [],
      }),
      "utf8",
    );

    const loaded = loadFlakerBatchSummaryInputs(root);

    expect(loaded.playwrightSummaries.size).toBe(0);
    expect(loaded.flakerSummaries.size).toBe(0);
    expect(loaded.vrtSummaries.get("paint-vrt")).toEqual({
      failed: 1,
      unknown: 0,
      maxDiffRatio: 0.2,
    });
  });
});
