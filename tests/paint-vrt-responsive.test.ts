/**
 * Responsive VRT tests: compare Crater vs Chromium at multiple viewport widths.
 * Tests that layout responds correctly to viewport changes.
 */
import path from "node:path";
import { expect, test, type Browser } from "@playwright/test";
import {
  chromiumPageForVrt,
  compareChromiumPngToImage,
  connectCraterPageForVrt,
  renderCraterHtml,
  type VisualDiffResult,
} from "./helpers/crater-vrt";

const OUTPUT_ROOT = path.join(process.cwd(), "output", "playwright", "vrt", "responsive");

const VIEWPORTS = [
  { name: "mobile", width: 320, height: 568 },
  { name: "narrow", width: 480, height: 800 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1024, height: 768 },
  { name: "wide", width: 1280, height: 800 },
] as const;

async function compareAtViewports(
  browser: Browser,
  testName: string,
  html: string,
  options: {
    viewports?: typeof VIEWPORTS[number][];
    maxDiffRatio: number;
    threshold?: number;
  },
): Promise<{ name: string; viewport: string; result: VisualDiffResult }[]> {
  const viewports = options.viewports ?? [...VIEWPORTS];
  const results: { name: string; viewport: string; result: VisualDiffResult }[] = [];

  for (const vp of viewports) {
    const viewport = { width: vp.width, height: vp.height };
    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = await connectCraterPageForVrt();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);

      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, testName, vp.name),
        threshold: options.threshold ?? 0.3,
        maxDiffRatio: options.maxDiffRatio,
        cropToContent: true,
        contentPadding: 8,
        backgroundTolerance: 18,
        maskToVisibleContent: true,
        maskPadding: 2,
      });

      console.log(`  ${testName}@${vp.name}(${vp.width}x${vp.height}): diffRatio=${result.diffRatio.toFixed(4)}`);
      results.push({ name: testName, viewport: vp.name, result });
    } finally {
      await craterPage.close();
      await chromiumPage.close();
    }
    // Brief pause between viewports to let the server settle
    await new Promise(r => setTimeout(r, 500));
  }

  return results;
}

test.describe("Responsive VRT", () => {
  test.describe.configure({ timeout: 300_000 });

  // R1: Fluid width boxes — percentage widths should scale with viewport
  test("R1: fluid width boxes", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f5f5f5; }
      .container { width: 90%; margin: 16px auto; }
      .row { display: flex; gap: 8px; margin-bottom: 8px; }
      .col-half { flex: 1; height: 60px; background: #3498db; border-radius: 4px; }
      .col-third { flex: 1; height: 60px; background: #e74c3c; border-radius: 4px; }
      .full { width: 100%; height: 40px; background: #2ecc71; border-radius: 4px; }
    </style></head><body>
      <div class="container">
        <div class="row"><div class="col-half"></div><div class="col-half"></div></div>
        <div class="row"><div class="col-third"></div><div class="col-third"></div><div class="col-third"></div></div>
        <div class="full"></div>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R1-fluid-boxes", html, {
      maxDiffRatio: 0.05,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R2: Flexbox wrapping at narrow widths
  test("R2: flex wrap at narrow viewport", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #fff; }
      .cards { display: flex; flex-wrap: wrap; gap: 12px; padding: 16px; }
      .card { min-width: 200px; flex: 1; height: 80px; background: #f0f2f5; border: 1px solid #ddd; border-radius: 8px; }
    </style></head><body>
      <div class="cards">
        <div class="card"></div>
        <div class="card"></div>
        <div class="card"></div>
        <div class="card"></div>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R2-flex-wrap", html, {
      maxDiffRatio: 0.05,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R3: Centered content with max-width
  test("R3: max-width centered content", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #eee; font-family: Arial, sans-serif; }
      .page { max-width: 600px; margin: 24px auto; background: #fff; padding: 20px; border: 1px solid #ccc; }
      h1 { margin: 0 0 12px; font-size: 20px; color: #222; }
      p { margin: 0 0 8px; font-size: 14px; color: #555; line-height: 1.5; }
    </style></head><body>
      <div class="page">
        <h1>Article Title</h1>
        <p>This content container has a max-width of 600px and is centered with margin auto.</p>
        <p>On narrow viewports it should fill the available width. On wide viewports it should stay at 600px.</p>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R3-max-width-center", html, {
      maxDiffRatio: 0.15,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R4: Sidebar + main layout — sidebar should take fixed width, main flexes
  test("R4: sidebar + main layout", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f5f5f5; }
      .layout { display: flex; min-height: 200px; }
      .sidebar { width: 180px; flex-shrink: 0; background: #2c3e50; }
      .main { flex: 1; padding: 16px; background: #fff; }
      .block { height: 40px; background: #ecf0f1; margin-bottom: 8px; border-radius: 4px; }
    </style></head><body>
      <div class="layout">
        <div class="sidebar"></div>
        <div class="main">
          <div class="block"></div>
          <div class="block"></div>
          <div class="block"></div>
        </div>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R4-sidebar-main", html, {
      maxDiffRatio: 0.05,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R5: Grid auto-fill — grid items should reflow based on available width
  test("R5: grid auto-fill responsive", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f0f2f5; }
      .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px; padding: 16px; }
      .grid-item { height: 80px; background: #fff; border: 1px solid #ddd; border-radius: 6px; }
    </style></head><body>
      <div class="grid">
        <div class="grid-item"></div>
        <div class="grid-item"></div>
        <div class="grid-item"></div>
        <div class="grid-item"></div>
        <div class="grid-item"></div>
        <div class="grid-item"></div>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R5-grid-auto-fill", html, {
      maxDiffRatio: 0.10,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R6: Text wrapping — line breaks should change with container width
  test("R6: text wrapping at different widths", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #fff; font-family: Arial, sans-serif; }
      .article { padding: 20px; max-width: 100%; }
      h1 { font-size: 24px; color: #222; margin: 0 0 12px; }
      p { font-size: 14px; color: #444; line-height: 1.6; margin: 0 0 12px; }
    </style></head><body>
      <div class="article">
        <h1>Responsive Text Layout Test</h1>
        <p>This paragraph contains enough text to demonstrate line wrapping behavior across different viewport widths. On narrow mobile screens, the text will wrap more frequently, creating more lines. On wider desktop screens, each line will contain more words.</p>
        <p>A second paragraph with different content helps verify consistent spacing between text blocks regardless of viewport width.</p>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R6-text-wrapping", html, {
      maxDiffRatio: 0.20,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R7: Horizontal scrollable container — fixed-width children in constrained viewport
  test("R7: overflow-x scroll container", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 16px; background: #fff; }
      .scroll-container { overflow-x: auto; white-space: nowrap; border: 1px solid #ddd; border-radius: 6px; padding: 12px; }
      .scroll-item { display: inline-block; width: 160px; height: 80px; margin-right: 8px; background: #f0f2f5; border-radius: 4px; vertical-align: top; }
      .scroll-item:last-child { margin-right: 0; }
    </style></head><body>
      <div class="scroll-container">
        <div class="scroll-item" style="background:#e3f2fd;"></div>
        <div class="scroll-item" style="background:#e8f5e9;"></div>
        <div class="scroll-item" style="background:#fff3e0;"></div>
        <div class="scroll-item" style="background:#fce4ec;"></div>
        <div class="scroll-item" style="background:#f3e5f5;"></div>
        <div class="scroll-item" style="background:#e0f7fa;"></div>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R7-overflow-scroll", html, {
      maxDiffRatio: 0.10,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });

  // R8: Navigation bar — items should fit differently at each viewport
  test("R8: navigation bar layout", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f5f5f5; font-family: Arial, sans-serif; }
      .nav { display: flex; background: #fff; border-bottom: 1px solid #ddd; padding: 0 12px; }
      .nav-item { padding: 12px 16px; font-size: 14px; color: #555; white-space: nowrap; }
      .nav-item.active { color: #2563eb; border-bottom: 2px solid #2563eb; }
      .content { padding: 16px; }
      .placeholder { height: 120px; background: #ecf0f1; border-radius: 6px; }
    </style></head><body>
      <div class="nav">
        <div class="nav-item active">Home</div>
        <div class="nav-item">Products</div>
        <div class="nav-item">About</div>
        <div class="nav-item">Contact</div>
        <div class="nav-item">Blog</div>
      </div>
      <div class="content">
        <div class="placeholder"></div>
      </div>
    </body></html>`;

    const results = await compareAtViewports(browser, "R8-navbar", html, {
      maxDiffRatio: 0.15,
    });
    for (const r of results) {
      expect(r.result.diffRatio, `${r.viewport}`).toBeLessThanOrEqual(r.result.maxDiffRatio);
    }
  });
});
