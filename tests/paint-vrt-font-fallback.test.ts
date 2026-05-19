import path from "node:path";
import { expect, test } from "@playwright/test";
import { createVrtArtifactReportContext } from "../scripts/vrt-report-contract.ts";
import {
  closeReferenceBrowser,
  compareReferenceFixtureToImage,
  connectCraterPageForVrt,
  renderCraterHtml,
  resolveChromiumReferenceFixture,
} from "./helpers/crater-vrt";

const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt");
const SPEC = "tests/paint-vrt-font-fallback.test.ts";

function reportFor(title: string) {
  return createVrtArtifactReportContext({
    taskId: "paint-vrt-font-fallback",
    file: SPEC,
    title,
  });
}

function countDarkPixels(image: { data: Uint8Array; width: number; height: number }): number {
  let count = 0;
  for (let i = 0; i < image.data.length; i += 4) {
    const alpha = image.data[i + 3] ?? 0;
    const r = image.data[i] ?? 255;
    const g = image.data[i + 1] ?? 255;
    const b = image.data[i + 2] ?? 255;
    if (alpha > 0 && r < 120 && g < 120 && b < 120) count++;
  }
  return count;
}

test.describe("Paint VRT — font fallback", () => {
  test.describe.configure({ timeout: 300_000 });

  test.afterAll(async () => {
    await closeReferenceBrowser();
  });

  test("Japanese text uses system fallback glyphs", async () => {
    const html = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { margin: 0; padding: 32px; background: white; color: #202124; font: 28px Arial, sans-serif; }
      nav { display: flex; align-items: center; gap: 28px; }
      .actions { margin-top: 36px; display: flex; gap: 14px; }
      button { height: 54px; padding: 0 18px; border: 0; border-radius: 4px; background: #f8f9fa; color: #3c4043; font: 24px Arial, sans-serif; }
    </style>
  </head>
  <body>
    <nav>
      <span>日本語検索設定</span>
      <span>画像</span>
    </nav>
    <div class="actions">
      <button>Google 検索</button>
      <button>日本語</button>
    </div>
  </body>
</html>`;
    const reference = await resolveChromiumReferenceFixture({
      fixtureId: "font-fallback-ja-system",
      html,
      viewport: { width: 520, height: 220 },
      title: "Japanese text uses system fallback glyphs",
    });
    const craterPage = await connectCraterPageForVrt();
    try {
      const craterImage = await renderCraterHtml(
        craterPage,
        html,
        { width: 520, height: 220 },
      );
      expect(countDarkPixels(craterImage)).toBeGreaterThan(300);
      const result = await compareReferenceFixtureToImage(reference, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "font-fallback-ja-system"),
        threshold: 0.3,
        maxDiffRatio: 0.095,
        report: reportFor("Japanese text uses system fallback glyphs"),
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
  });
});
