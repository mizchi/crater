import path from "node:path";
import { expect, test, type Page } from "@playwright/test";
import { createVrtArtifactReportContext } from "../scripts/vrt-report-contract.ts";
import {
  captureCraterPageImage,
  closeReferenceBrowser,
  compareReferenceFixtureToImage,
  connectCraterPageForVrt,
  renderCraterHtml,
  resolveChromiumReferenceFixture,
} from "./helpers/crater-vrt";

/**
 * Dedicated SVG / logo intrinsic-sizing fixtures.
 *
 * These tests carve out the SVG intrinsic-size paint paths that previously
 * only existed inside real-URL captures (google logo, mdn icons, wikipedia
 * headings, playwright diagrams) into standalone reproducible fixtures so
 * regressions can be isolated from page-wide diffs.
 *
 * Implements: paint.svg-logo-intrinsic (P1).
 */

const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt");
const SPEC = "tests/paint-vrt-svg-intrinsic.test.ts";

function reportFor(title: string) {
  return createVrtArtifactReportContext({
    taskId: "paint-vrt-svg-intrinsic",
    file: SPEC,
    title,
  });
}

async function expectHtmlWithinBudget(options: {
  fixtureId: string;
  html: string;
  viewport: { width: number; height: number };
  outputDirName: string;
  threshold: number;
  maxDiffRatio: number;
  reportTitle: string;
  prepareChromiumPage?: (page: Page) => Promise<void>;
}): Promise<void> {
  const reference = await resolveChromiumReferenceFixture({
    fixtureId: options.fixtureId,
    html: options.html,
    viewport: options.viewport,
    title: options.reportTitle,
    preparePage: options.prepareChromiumPage,
  });
  const craterPage = await connectCraterPageForVrt();
  try {
    const craterImage = await renderCraterHtml(craterPage, options.html, options.viewport);
    const result = await compareReferenceFixtureToImage(reference, craterImage, {
      outputDir: path.join(OUTPUT_ROOT, options.outputDirName),
      threshold: options.threshold,
      maxDiffRatio: options.maxDiffRatio,
      report: reportFor(options.reportTitle),
      cropToContent: true,
      contentPadding: 12,
      backgroundTolerance: 18,
      maskToVisibleContent: true,
      maskPadding: 2,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  } finally {
    await craterPage.close();
  }
}

test.describe("Paint VRT — SVG intrinsic sizing", () => {
  test.describe.configure({ timeout: 300_000 });

  test.afterAll(async () => {
    await closeReferenceBrowser();
  });

  test("svg with explicit width and height attributes", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 32px; align-items: center; }
    </style>
  </head>
  <body>
    <div class="row">
      <svg width="80" height="48" viewBox="0 0 80 48">
        <rect x="0" y="0" width="80" height="48" fill="#3158ff" rx="8" />
      </svg>
      <svg width="120" height="60" viewBox="0 0 120 60">
        <rect x="0" y="0" width="120" height="60" fill="#ff5c5c" rx="8" />
      </svg>
    </div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "svg-intrinsic-explicit-dims",
      html,
      viewport: { width: 480, height: 200 },
      outputDirName: "svg-intrinsic-explicit-dims",
      threshold: 0.3,
      maxDiffRatio: 0.15,
      reportTitle: "svg with explicit width and height attributes",
    });
  });

  test("svg with viewBox only takes intrinsic from viewBox", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
    </style>
  </head>
  <body>
    <svg viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="200" height="80" fill="#3b82f6" rx="12" />
      <circle cx="40" cy="40" r="20" fill="white" />
    </svg>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "svg-intrinsic-viewbox-only",
      html,
      viewport: { width: 480, height: 240 },
      outputDirName: "svg-intrinsic-viewbox-only",
      threshold: 0.3,
      maxDiffRatio: 0.15,
      reportTitle: "svg with viewBox only takes intrinsic from viewBox",
    });
  });

  test("svg inside flex container honors flex sizing", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .card { display: flex; align-items: center; gap: 16px; padding: 16px; background: white; border-radius: 12px; width: 320px; }
      .icon { flex: 0 0 auto; }
      .label { flex: 1; font-size: 16px; color: #172033; }
    </style>
  </head>
  <body>
    <div class="card">
      <svg class="icon" width="32" height="32" viewBox="0 0 32 32">
        <rect x="0" y="0" width="32" height="32" fill="#10b981" rx="8" />
      </svg>
      <span class="label">All systems operational</span>
    </div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "svg-intrinsic-flex-icon",
      html,
      viewport: { width: 480, height: 200 },
      outputDirName: "svg-intrinsic-flex-icon",
      threshold: 0.3,
      maxDiffRatio: 0.15,
      reportTitle: "svg inside flex container honors flex sizing",
    });
  });

  test("inline svg as replaced text element preserves baseline", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      h1 { font-size: 24px; color: #172033; margin: 0; }
      h1 svg { vertical-align: middle; margin-right: 8px; }
    </style>
  </head>
  <body>
    <h1>
      <svg width="28" height="28" viewBox="0 0 28 28">
        <rect x="0" y="0" width="28" height="28" fill="#6366f1" rx="6" />
      </svg>
      Dashboard
    </h1>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "svg-intrinsic-inline-replaced",
      html,
      viewport: { width: 480, height: 200 },
      outputDirName: "svg-intrinsic-inline-replaced",
      threshold: 0.3,
      maxDiffRatio: 0.15,
      reportTitle: "inline svg as replaced text element preserves baseline",
    });
  });

  test("svg sized by parent container with percent width", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .frame { width: 240px; height: 120px; background: white; padding: 8px; border-radius: 12px; }
      .frame svg { width: 100%; height: 100%; display: block; }
    </style>
  </head>
  <body>
    <div class="frame">
      <svg viewBox="0 0 200 100" preserveAspectRatio="xMidYMid meet">
        <rect x="0" y="0" width="200" height="100" fill="#f59e0b" rx="8" />
      </svg>
    </div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "svg-intrinsic-percent-parent",
      html,
      viewport: { width: 480, height: 240 },
      outputDirName: "svg-intrinsic-percent-parent",
      threshold: 0.3,
      maxDiffRatio: 0.15,
      reportTitle: "svg sized by parent container with percent width",
    });
  });
});
