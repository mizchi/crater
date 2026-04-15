import path from "node:path";
import { expect, test, type Browser } from "@playwright/test";
import { CraterBidiPage } from "./helpers/crater-bidi-page";
import {
  chromiumPageForVrt,
  compareChromiumPngToImage,
  connectCraterPageForVrt,
  renderCraterHtml,
} from "./helpers/crater-vrt";
import {
  buildMergedWptVrtResultsReport,
  collectWptVrtTests,
  createWptVrtBatches,
  loadWptVrtBaseline,
  loadWptVrtConfig,
  readWptVrtResultsReport,
  prepareHtmlContent,
  saveWptVrtBaseline,
  type WptVrtBaseline,
  type WptVrtTestEntry,
  type WptVrtTestResult,
  writeWptVrtResultsReport,
} from "./helpers/wpt-vrt-utils";

const UPDATE_BASELINE = process.env.WPT_VRT_UPDATE_BASELINE === "1";
const SHARD_NAME = process.env.WPT_VRT_SHARD_NAME?.trim() || "wpt-vrt";
const SHARD_MODULES = process.env.WPT_VRT_SHARD?.split(",").map(s => s.trim()).filter(Boolean) ?? [];
const SHARD_OFFSET = Number(process.env.WPT_VRT_OFFSET) || 0;
const SHARD_LIMIT = Number(process.env.WPT_VRT_LIMIT) || 0;
const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt", "wpt");
const REGRESSION_EPSILON = 0.01;
const BATCH_SIZE = 5;
const RUN_ID = [
  SHARD_NAME,
  SHARD_MODULES.join(","),
  String(SHARD_OFFSET),
  String(SHARD_LIMIT),
  String(process.ppid),
].join(":");
const config = loadWptVrtConfig();
const allEntries = collectWptVrtTests(config);
const moduleFiltered = SHARD_MODULES.length > 0
  ? allEntries.filter(e => SHARD_MODULES.includes(e.moduleName))
  : allEntries;
const entries = SHARD_LIMIT > 0
  ? moduleFiltered.slice(SHARD_OFFSET, SHARD_OFFSET + SHARD_LIMIT)
  : moduleFiltered.slice(SHARD_OFFSET);
const baseline = loadWptVrtBaseline();
const batches = createWptVrtBatches(entries, BATCH_SIZE);

const INTER_TEST_DELAY_MS = 300;

async function runVrtTest(
  browser: Browser,
  entry: WptVrtTestEntry,
  config: { viewport: { width: number; height: number }; pixelmatchThreshold: number; defaultMaxDiffRatio: number },
): Promise<WptVrtTestResult> {
  let chromiumPage = null as Awaited<ReturnType<typeof chromiumPageForVrt>> | null;
  let craterPage = null as CraterBidiPage | null;
  try {
    const htmlContent = prepareHtmlContent(entry.testPath);
    chromiumPage = await chromiumPageForVrt(browser, config.viewport);
    craterPage = await connectCraterPageForVrt();

    await chromiumPage.setContent(htmlContent, { waitUntil: "load" });
    const chromiumPng = await chromiumPage.screenshot({ type: "png" });
    const craterImage = await renderCraterHtml(craterPage, htmlContent, config.viewport);

    const testName = entry.relativePath.replace(/\//g, "__").replace(/\.html?$/, "");
    const outputDir = path.join(OUTPUT_ROOT, entry.moduleName, testName);

    const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
      outputDir,
      threshold: config.pixelmatchThreshold,
      maxDiffRatio: config.defaultMaxDiffRatio,
      cropToContent: true,
      contentPadding: 12,
      backgroundTolerance: 18,
      maskToVisibleContent: true,
      maskPadding: 2,
    });

    const status = result.diffRatio <= config.defaultMaxDiffRatio ? "pass" : "fail";
    return { relativePath: entry.relativePath, diffRatio: result.diffRatio, status };
  } catch (error) {
    return {
      relativePath: entry.relativePath,
      diffRatio: 1.0,
      status: "fail",
      error: String(error),
    };
  } finally {
    await craterPage?.close().catch(() => {});
    await chromiumPage?.close().catch(() => {});
    // Brief pause to let BiDi server settle between tests
    await new Promise(r => setTimeout(r, INTER_TEST_DELAY_MS));
  }
}

test.describe("WPT VRT", () => {
  test.describe.configure({ timeout: 600_000 });
  const results: WptVrtTestResult[] = [];

  function flushResults() {
    const report = buildMergedWptVrtResultsReport({
      currentResults: results,
      existingReport: readWptVrtResultsReport(OUTPUT_ROOT),
      expectedTotal: entries.length,
      shard: {
        name: SHARD_NAME,
        modules: SHARD_MODULES,
        offset: SHARD_OFFSET,
        limit: SHARD_LIMIT,
      },
      config,
      baseline: baseline && !UPDATE_BASELINE ? baseline : null,
      regressionEpsilon: REGRESSION_EPSILON,
      runId: RUN_ID,
    });
    writeWptVrtResultsReport(OUTPUT_ROOT, report);
    return report;
  }

  test.beforeAll(() => {
    expect(entries.length).toBeGreaterThan(0);
    console.log(`WPT VRT: running ${entries.length} tests in ${batches.length} batches (run ${RUN_ID})`);
  });

  for (const [batchIndex, batchEntries] of batches.entries()) {
    test(`WPT CSS visual regression batch ${batchIndex + 1}/${batches.length}`, async ({ browser }) => {
      const regressions: string[] = [];

      for (const entry of batchEntries) {
        const result = await runVrtTest(browser, entry, config);
        results.push(result);

        if (baseline && !UPDATE_BASELINE) {
          const baselineEntry = baseline.tests[entry.relativePath];
          if (baselineEntry) {
            const limit = baselineEntry.diffRatio + REGRESSION_EPSILON;
            if (result.diffRatio > limit) {
              regressions.push(
                `${entry.relativePath}: diffRatio ${result.diffRatio.toFixed(4)} > baseline ${baselineEntry.diffRatio.toFixed(4)} + ${REGRESSION_EPSILON}`,
              );
            }
          }
        }
      }

      const report = flushResults();

      console.log(
        `  batch ${batchIndex + 1}/${batches.length}: completed ${Math.min((batchIndex + 1) * BATCH_SIZE, entries.length)}/${entries.length}`,
      );
      if (batchIndex === batches.length - 1 && report.closestToThreshold.length > 0) {
        const closest = report.closestToThreshold
          .slice(0, 5)
          .map((row) => `${row.relativePath}=${row.headroom.toFixed(4)}`)
          .join(", ");
        console.log(`  closest headroom: ${closest}`);
      }
      if (regressions.length > 0) {
        console.error(`  regressions: ${regressions.join(" | ")}`);
      }
      expect(regressions, `${regressions.length} regression(s) found in batch ${batchIndex + 1}`).toHaveLength(0);
    });
  }

  test.afterAll(() => {
    const report = flushResults();
    const passed = report.summary.passed;
    const failed = report.summary.failed;

    console.log(`\nWPT VRT: ${passed}/${results.length} passed (${failed} failed)`);

    if (!UPDATE_BASELINE) {
      return;
    }

    // Merge with existing baseline so shard runs don't overwrite other modules
    const existingBaseline = loadWptVrtBaseline();
    const mergedTests: Record<string, { diffRatio: number; status: "pass" | "fail" }> = {
      ...(existingBaseline?.tests ?? {}),
    };
    for (const r of results) {
      mergedTests[r.relativePath] = { diffRatio: r.diffRatio, status: r.status };
    }
    // Remove tests that are no longer in the test set
    const allTestPaths = new Set(allEntries.map(e => e.relativePath));
    for (const key of Object.keys(mergedTests)) {
      if (!allTestPaths.has(key)) {
        delete mergedTests[key];
      }
    }
    const mergedPassed = Object.values(mergedTests).filter(t => t.status === "pass").length;
    const mergedFailed = Object.values(mergedTests).filter(t => t.status === "fail").length;
    const newBaseline: WptVrtBaseline = {
      schemaVersion: 1,
      updatedAt: new Date().toISOString(),
      config: {
        viewport: config.viewport,
        pixelmatchThreshold: config.pixelmatchThreshold,
        defaultMaxDiffRatio: config.defaultMaxDiffRatio,
      },
      summary: { total: mergedPassed + mergedFailed, passed: mergedPassed, failed: mergedFailed },
      tests: mergedTests,
    };
    saveWptVrtBaseline(newBaseline);
    console.log(`Baseline updated: tests/wpt-vrt-baseline.json (${mergedPassed + mergedFailed} total, ${mergedPassed} pass, ${mergedFailed} fail)`);
  });
});
