import fs from "node:fs";
import path from "node:path";
import { expect, test, type Browser } from "@playwright/test";
import { CraterBidiPage } from "./helpers/crater-bidi-page";
import {
  chromiumPageForVrt,
  compareChromiumPngToImage,
  renderCraterHtml,
} from "./helpers/crater-vrt";
import {
  collectWptVrtTests,
  loadWptVrtBaseline,
  loadWptVrtConfig,
  prepareHtmlContent,
  saveWptVrtBaseline,
  type WptVrtBaseline,
  type WptVrtTestEntry,
} from "./helpers/wpt-vrt-utils";

const UPDATE_BASELINE = process.env.WPT_VRT_UPDATE_BASELINE === "1";
const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt", "wpt");
const REGRESSION_EPSILON = 0.01;
const BATCH_SIZE = 10;

interface TestResult {
  relativePath: string;
  diffRatio: number;
  status: "pass" | "fail";
  error?: string;
}

async function runVrtTest(
  browser: Browser,
  entry: WptVrtTestEntry,
  config: { viewport: { width: number; height: number }; pixelmatchThreshold: number; defaultMaxDiffRatio: number },
): Promise<TestResult> {
  const htmlContent = prepareHtmlContent(entry.testPath);
  const chromiumPage = await chromiumPageForVrt(browser, config.viewport);
  const craterPage = new CraterBidiPage();
  await craterPage.connect();

  try {
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
    await craterPage.close();
    await chromiumPage.close();
  }
}

test.describe("WPT VRT", () => {
  test.describe.configure({ timeout: 600_000 });

  test("WPT CSS visual regression tests", async ({ browser }) => {
    const config = loadWptVrtConfig();
    const entries = collectWptVrtTests(config);
    const baseline = loadWptVrtBaseline();

    expect(entries.length).toBeGreaterThan(0);
    console.log(`WPT VRT: running ${entries.length} tests`);

    const results: TestResult[] = [];
    const regressions: string[] = [];

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (i > 0 && i % BATCH_SIZE === 0) {
        console.log(`  progress: ${i}/${entries.length}`);
      }
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

    const passed = results.filter((r) => r.status === "pass").length;
    const failed = results.filter((r) => r.status === "fail").length;

    // Write results JSON
    fs.mkdirSync(OUTPUT_ROOT, { recursive: true });
    const resultsJson = {
      generatedAt: new Date().toISOString(),
      config: {
        viewport: config.viewport,
        pixelmatchThreshold: config.pixelmatchThreshold,
        defaultMaxDiffRatio: config.defaultMaxDiffRatio,
      },
      summary: { total: results.length, passed, failed },
      tests: Object.fromEntries(
        results.map((r) => [
          r.relativePath,
          { diffRatio: r.diffRatio, status: r.status, ...(r.error ? { error: r.error } : {}) },
        ]),
      ),
    };
    fs.writeFileSync(
      path.join(OUTPUT_ROOT, "wpt-vrt-results.json"),
      JSON.stringify(resultsJson, null, 2) + "\n",
    );

    console.log(`\nWPT VRT: ${passed}/${results.length} passed (${failed} failed)`);

    if (UPDATE_BASELINE) {
      const newBaseline: WptVrtBaseline = {
        schemaVersion: 1,
        updatedAt: new Date().toISOString(),
        config: {
          viewport: config.viewport,
          pixelmatchThreshold: config.pixelmatchThreshold,
          defaultMaxDiffRatio: config.defaultMaxDiffRatio,
        },
        summary: { total: results.length, passed, failed },
        tests: Object.fromEntries(
          results.map((r) => [r.relativePath, { diffRatio: r.diffRatio, status: r.status }]),
        ),
      };
      saveWptVrtBaseline(newBaseline);
      console.log("Baseline updated: tests/wpt-vrt-baseline.json");
    } else if (regressions.length > 0) {
      console.log("\nRegressions detected:");
      for (const msg of regressions) {
        console.log(`  - ${msg}`);
      }
      expect(regressions, `${regressions.length} regression(s) found`).toHaveLength(0);
    }
  });
});
