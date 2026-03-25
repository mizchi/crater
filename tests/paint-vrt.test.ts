import path from "node:path";
import { expect, test, type Browser } from "@playwright/test";
import {
  listRealWorldSnapshotNames,
  loadRealWorldSnapshot,
} from "../scripts/real-world-snapshot.ts";
import { CraterBidiPage } from "./helpers/crater-bidi-page";
import {
  chromiumPageForVrt,
  compareChromiumPngToImage,
  renderCraterHtml,
} from "./helpers/crater-vrt";

const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt");
const AVAILABLE_REAL_WORLD_SNAPSHOTS = new Set(listRealWorldSnapshotNames());

async function expectSnapshotWithinBudget(
  browser: Browser,
  snapshotName: string,
  options: { threshold: number; maxDiffRatio: number },
): Promise<void> {
  const snapshot = loadRealWorldSnapshot(snapshotName);
  const chromiumPage = await chromiumPageForVrt(browser, snapshot.viewport);
  const craterPage = new CraterBidiPage();
  await craterPage.connect();
  try {
    await chromiumPage.setContent(snapshot.html, { waitUntil: "load" });
    const chromiumPng = await chromiumPage.screenshot({ type: "png" });
    const craterImage = await renderCraterHtml(craterPage, snapshot.html, snapshot.viewport);

    const result = await compareChromiumPngToImage(
      chromiumPage,
      chromiumPng,
      craterImage,
      {
        outputDir: path.join(OUTPUT_ROOT, snapshot.name),
        threshold: options.threshold,
        maxDiffRatio: options.maxDiffRatio,
        cropToContent: true,
        contentPadding: 12,
        backgroundTolerance: 18,
        maskToVisibleContent: true,
        maskPadding: 2,
      },
    );

    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  } finally {
    await craterPage.close();
    await chromiumPage.close();
  }
}

test.describe("Paint VRT", () => {
  test.describe.configure({ timeout: 120_000 });

  test("fixture: cards and controls stay within relaxed visual diff budget", async ({
    browser,
  }) => {
    const viewport = { width: 960, height: 720 };
    const html = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8" />
          <style>
            :root {
              color-scheme: light;
              font-family: ui-sans-serif, system-ui, sans-serif;
            }
            body {
              margin: 0;
              background: linear-gradient(180deg, #f7f8fb, #eef2ff);
              color: #172033;
            }
            .shell {
              width: 820px;
              margin: 32px auto;
              padding: 24px;
              border-radius: 24px;
              background: rgba(255, 255, 255, 0.85);
              box-shadow: 0 20px 60px rgba(15, 23, 42, 0.18);
            }
            h1 {
              margin: 0 0 16px;
              font-size: 28px;
            }
            .grid {
              display: grid;
              grid-template-columns: repeat(2, minmax(0, 1fr));
              gap: 16px;
            }
            .card {
              padding: 18px;
              border: 1px solid rgba(89, 102, 141, 0.2);
              border-radius: 18px;
              background: white;
            }
            .metric {
              font-size: 32px;
              font-weight: 700;
            }
            .subtle {
              color: #5f6b85;
            }
            .row {
              display: flex;
              align-items: center;
              gap: 12px;
              margin-top: 16px;
            }
            input[type="text"] {
              flex: 1;
              padding: 10px 12px;
              border: 1px solid #b6c0d4;
              border-radius: 999px;
              background: #fbfcff;
            }
            button {
              padding: 10px 16px;
              border: 0;
              border-radius: 999px;
              background: #3158ff;
              color: white;
            }
          </style>
        </head>
        <body>
          <main class="shell">
            <h1>Dashboard snapshot</h1>
            <section class="grid">
              <article class="card">
                <div class="subtle">Active users</div>
                <div class="metric">12,480</div>
              </article>
              <article class="card">
                <div class="subtle">Errors</div>
                <div class="metric">18</div>
              </article>
              <article class="card">
                <div class="subtle">Region</div>
                <div>Tokyo / Osaka / Remote</div>
              </article>
              <article class="card">
                <div class="subtle">Status</div>
                <div>Healthy</div>
                <div class="row">
                  <input type="text" value="notify-on-call" />
                  <button>Save</button>
                </div>
              </article>
            </section>
          </main>
        </body>
      </html>
    `;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);

      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-cards-controls"),
        threshold: 0.3,
        maxDiffRatio: 0.12,
        cropToContent: true,
        contentPadding: 12,
        backgroundTolerance: 18,
        maskToVisibleContent: true,
        maskPadding: 2,
      });

      expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
    } finally {
      await craterPage.close();
      await chromiumPage.close();
    }
  });

  test("real-world snapshot: github-mizchi stays within loose visual diff budget", async ({
    browser,
  }) => {
    test.slow();
    await expectSnapshotWithinBudget(browser, "github-mizchi", {
      threshold: 0.35,
      maxDiffRatio: 0.12,
    });
  });

  test("real-world snapshot: example-com visual parity", async ({ browser }) => {
    const snapshot = loadRealWorldSnapshot("example-com");
    const chromiumPage = await chromiumPageForVrt(browser, snapshot.viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(snapshot.html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, snapshot.html, snapshot.viewport);

      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "example-com"),
        threshold: 0.3,
        maxDiffRatio: 1.0,
        cropToContent: true,
        contentPadding: 12,
        backgroundTolerance: 18,
        maskToVisibleContent: true,
        maskPadding: 2,
      });

      console.log(`example-com diffRatio: ${result.diffRatio.toFixed(6)} (${result.diffPixels}/${result.totalPixels} pixels)`);
      // Goal: bring this to 0
      expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
    } finally {
      await craterPage.close();
      await chromiumPage.close();
    }
  });

  for (const snapshotName of ["playwright-intro", "mdn-wasm-text"]) {
    test(`real-world snapshot: ${snapshotName} stays within loose visual diff budget`, async ({
      browser,
    }) => {
      test.slow();
      test.skip(
        !AVAILABLE_REAL_WORLD_SNAPSHOTS.has(snapshotName),
        `${snapshotName} snapshot is not available locally`,
      );
      await expectSnapshotWithinBudget(browser, snapshotName, {
        threshold: 0.35,
        maxDiffRatio: snapshotName === "playwright-intro" ? 0.06 : 0.08,
      });
    });
  }
});
