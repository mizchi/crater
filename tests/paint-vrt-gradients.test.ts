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
 * Dedicated VRT fixtures for CSS background gradients beyond plain linear ones.
 *
 * The existing paint-vrt suite only covers basic linear-gradient. This file
 * adds focused fixtures for radial-gradient, conic-gradient, repeating
 * variants, and linear gradients with explicit color-stop positions so
 * painter regressions in each gradient family surface against a dedicated
 * baseline instead of being masked inside a real-page diff.
 *
 * Implements: compat.css-background-gradient-vrt (P1).
 */

const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt");
const SPEC = "tests/paint-vrt-gradients.test.ts";

function reportFor(title: string) {
  return createVrtArtifactReportContext({
    taskId: "paint-vrt-gradients",
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

test.describe("Paint VRT — CSS background gradients", () => {
  test.describe.configure({ timeout: 300_000 });

  test.afterAll(async () => {
    await closeReferenceBrowser();
  });

  test("radial-gradient renders centred circle and offset ellipse", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 24px; }
      .swatch { width: 200px; height: 160px; border-radius: 12px; }
      .circle { background: radial-gradient(circle, #3b82f6, #1e3a8a); }
      .ellipse { background: radial-gradient(ellipse at 20% 30%, #f59e0b, #b45309 80%); }
    </style>
  </head>
  <body>
    <div class="row">
      <div class="swatch circle"></div>
      <div class="swatch ellipse"></div>
    </div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "gradient-radial-basic",
      html,
      viewport: { width: 540, height: 280 },
      outputDirName: "gradient-radial-basic",
      threshold: 0.35,
      maxDiffRatio: 0.2,
      reportTitle: "radial-gradient renders centred circle and offset ellipse",
    });
  });

  test("conic-gradient renders rotation and from-angle variants", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 24px; }
      .swatch { width: 200px; height: 160px; border-radius: 12px; }
      .wheel { background: conic-gradient(#ef4444, #f59e0b, #10b981, #3b82f6, #8b5cf6, #ef4444); }
      .pie { background: conic-gradient(from 45deg, #1f2937 0deg 90deg, #f3f4f6 90deg 360deg); }
    </style>
  </head>
  <body>
    <div class="row">
      <div class="swatch wheel"></div>
      <div class="swatch pie"></div>
    </div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "gradient-conic-basic",
      html,
      viewport: { width: 540, height: 280 },
      outputDirName: "gradient-conic-basic",
      threshold: 0.35,
      maxDiffRatio: 0.2,
      reportTitle: "conic-gradient renders rotation and from-angle variants",
    });
  });

  test("repeating-linear-gradient renders evenly spaced stripes", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 24px; }
      .swatch { width: 220px; height: 160px; border-radius: 12px; }
      .horiz { background: repeating-linear-gradient(to right, #1e3a8a 0, #1e3a8a 12px, #3b82f6 12px, #3b82f6 24px); }
      .diag { background: repeating-linear-gradient(45deg, #b91c1c 0, #b91c1c 10px, #f87171 10px, #f87171 20px); }
    </style>
  </head>
  <body>
    <div class="row">
      <div class="swatch horiz"></div>
      <div class="swatch diag"></div>
    </div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "gradient-repeating-linear",
      html,
      viewport: { width: 580, height: 280 },
      outputDirName: "gradient-repeating-linear",
      threshold: 0.35,
      maxDiffRatio: 0.2,
      reportTitle: "repeating-linear-gradient renders evenly spaced stripes",
    });
  });

  test("repeating-radial-gradient renders concentric rings", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .swatch { width: 240px; height: 200px; border-radius: 12px; background: repeating-radial-gradient(circle at center, #312e81 0 12px, #818cf8 12px 24px); }
    </style>
  </head>
  <body>
    <div class="swatch"></div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "gradient-repeating-radial",
      html,
      viewport: { width: 360, height: 300 },
      outputDirName: "gradient-repeating-radial",
      threshold: 0.35,
      maxDiffRatio: 0.2,
      reportTitle: "repeating-radial-gradient renders concentric rings",
    });
  });

  test("linear-gradient respects explicit color-stop positions", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: #f6f7fb; font-family: Arial, sans-serif; }
      .swatch { width: 320px; height: 80px; border-radius: 12px; margin-bottom: 16px; }
      .stops { background: linear-gradient(to right, #ef4444 20%, #ffffff 50%, #2563eb 80%); }
      .hard { background: linear-gradient(to right, #10b981 0 33%, #f59e0b 33% 66%, #6366f1 66% 100%); }
    </style>
  </head>
  <body>
    <div class="swatch stops"></div>
    <div class="swatch hard"></div>
  </body>
</html>`;
    await expectHtmlWithinBudget({
      fixtureId: "gradient-linear-stops",
      html,
      viewport: { width: 420, height: 280 },
      outputDirName: "gradient-linear-stops",
      threshold: 0.35,
      maxDiffRatio: 0.2,
      reportTitle: "linear-gradient respects explicit color-stop positions",
    });
  });
});
