/**
 * Graduated VRT tests: simple to complex CSS features.
 * Each level tests a specific rendering capability.
 */
import path from "node:path";
import { expect, test, type Browser } from "@playwright/test";
import { CraterBidiPage } from "./helpers/crater-bidi-page";
import {
  chromiumPageForVrt,
  compareChromiumPngToImage,
  renderCraterHtml,
  type VisualDiffResult,
} from "./helpers/crater-vrt";

const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt", "levels");

async function compareFixture(
  browser: Browser,
  name: string,
  html: string,
  options: {
    viewport?: { width: number; height: number };
    maxDiffRatio: number;
    threshold?: number;
  },
): Promise<VisualDiffResult> {
  const viewport = options.viewport ?? { width: 800, height: 600 };
  const chromiumPage = await chromiumPageForVrt(browser, viewport);
  const craterPage = new CraterBidiPage();
  await craterPage.connect();
  try {
    await chromiumPage.setContent(html, { waitUntil: "load" });
    const chromiumPng = await chromiumPage.screenshot({ type: "png" });
    const craterImage = await renderCraterHtml(craterPage, html, viewport);

    const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
      outputDir: path.join(OUTPUT_ROOT, name),
      threshold: options.threshold ?? 0.3,
      maxDiffRatio: options.maxDiffRatio,
      cropToContent: true,
      contentPadding: 8,
      backgroundTolerance: 18,
      maskToVisibleContent: true,
      maskPadding: 2,
    });

    console.log(`  ${name}: diffRatio=${result.diffRatio.toFixed(4)} (${result.diffPixels}px)`);
    return result;
  } finally {
    await craterPage.close();
    await chromiumPage.close();
  }
}

test.describe("VRT Levels", () => {
  test.describe.configure({ timeout: 120_000 });

  // Level 1: Pure boxes — no text, just background colors, borders, sizes
  test("L1: colored boxes with margin and padding", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f5f5f5; }
      .box { width: 200px; height: 100px; margin: 20px; }
      .red { background: #e74c3c; }
      .blue { background: #3498db; }
      .green { background: #2ecc71; border: 4px solid #27ae60; }
      .nested { background: #fff; padding: 16px; margin: 20px; border: 2px solid #ccc; }
      .inner { background: #9b59b6; width: 100px; height: 50px; }
    </style></head><body>
      <div class="box red"></div>
      <div class="box blue"></div>
      <div class="box green"></div>
      <div class="nested"><div class="inner"></div></div>
    </body></html>`;

    const result = await compareFixture(browser, "L1-colored-boxes", html, {
      maxDiffRatio: 0.01,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 2: Text basics — font-size, color, alignment (no wrapping)
  test("L2: basic text rendering", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #fff; font-family: Arial, sans-serif; }
      .title { font-size: 24px; color: #333; padding: 16px; }
      .subtitle { font-size: 16px; color: #666; padding: 0 16px; }
      .highlight { font-size: 14px; color: #e74c3c; padding: 8px 16px; }
    </style></head><body>
      <div class="title">Hello World</div>
      <div class="subtitle">Simple text test</div>
      <div class="highlight">Red text here</div>
    </body></html>`;

    const result = await compareFixture(browser, "L2-basic-text", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 3: Flexbox layout
  test("L3: flexbox row layout", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f0f0f0; }
      .row { display: flex; gap: 12px; padding: 16px; }
      .card { flex: 1; background: #fff; padding: 16px; border-radius: 8px; border: 1px solid #ddd; }
      .card-title { font-size: 18px; color: #333; font-family: Arial, sans-serif; }
      .card-value { font-size: 32px; color: #2c3e50; font-family: Arial, sans-serif; font-weight: bold; }
    </style></head><body>
      <div class="row">
        <div class="card">
          <div class="card-title">Users</div>
          <div class="card-value">1,234</div>
        </div>
        <div class="card">
          <div class="card-title">Orders</div>
          <div class="card-value">567</div>
        </div>
        <div class="card">
          <div class="card-title">Revenue</div>
          <div class="card-value">$89k</div>
        </div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L3-flexbox", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 4: Block centering with margin auto
  test("L4: centered content with margin auto", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #eee; }
      .container { width: 400px; margin: 40px auto; background: #fff; padding: 24px; border: 1px solid #ccc; }
      h1 { margin: 0 0 12px; font-size: 20px; color: #222; font-family: Arial, sans-serif; }
      p { margin: 0; font-size: 14px; color: #555; line-height: 1.5; font-family: Arial, sans-serif; }
    </style></head><body>
      <div class="container">
        <h1>Centered Box</h1>
        <p>This container is centered with margin auto.</p>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L4-centered", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 5: Absolute positioning
  test("L5: absolute positioning", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f5f5f5; }
      .relative { position: relative; width: 300px; height: 200px; margin: 20px; background: #fff; border: 2px solid #333; }
      .abs-tl { position: absolute; top: 10px; left: 10px; width: 60px; height: 60px; background: #e74c3c; }
      .abs-br { position: absolute; bottom: 10px; right: 10px; width: 80px; height: 40px; background: #3498db; }
      .abs-center { position: absolute; top: 50%; left: 50%; width: 40px; height: 40px; background: #2ecc71; transform: translate(-50%, -50%); }
    </style></head><body>
      <div class="relative">
        <div class="abs-tl"></div>
        <div class="abs-br"></div>
        <div class="abs-center"></div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L5-absolute", html, {
      maxDiffRatio: 0.02,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 6: Inline text with different styles
  test("L6: mixed inline text styles", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 16px; background: #fff; font-family: Arial, sans-serif; font-size: 16px; color: #333; line-height: 1.6; }
      b { font-weight: bold; }
      .blue { color: #2980b9; }
      .small { font-size: 12px; color: #999; }
    </style></head><body>
      <p>This is <b>bold text</b> and <span class="blue">blue text</span> in a paragraph.</p>
      <p class="small">A smaller line below.</p>
    </body></html>`;

    const result = await compareFixture(browser, "L6-inline-styles", html, {
      maxDiffRatio: 0.20,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });
});
