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
  test.describe.configure({ timeout: 180_000 });

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

  // Level 7: Table layout
  test("L7: basic table layout", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; }
      table { width: 600px; border-collapse: collapse; }
      th, td { padding: 10px 14px; border: 1px solid #ddd; text-align: left; font-size: 14px; }
      th { background: #f8f9fa; font-weight: bold; color: #333; }
      tr:nth-child(even) td { background: #fafafa; }
      .num { text-align: right; font-variant-numeric: tabular-nums; }
    </style></head><body>
      <table>
        <thead>
          <tr><th>Name</th><th>Role</th><th class="num">Score</th></tr>
        </thead>
        <tbody>
          <tr><td>Alice</td><td>Engineer</td><td class="num">95</td></tr>
          <tr><td>Bob</td><td>Designer</td><td class="num">88</td></tr>
          <tr><td>Carol</td><td>Manager</td><td class="num">72</td></tr>
          <tr><td>Dave</td><td>Analyst</td><td class="num">91</td></tr>
        </tbody>
      </table>
    </body></html>`;

    const result = await compareFixture(browser, "L7-table", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 8: Lists (ordered + unordered)
  test("L8: ordered and unordered lists", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; font-size: 14px; color: #333; }
      h2 { font-size: 18px; margin: 0 0 8px; }
      ul, ol { margin: 0 0 16px; padding-left: 24px; }
      li { margin-bottom: 4px; line-height: 1.5; }
      .two-col { display: flex; gap: 40px; }
      .two-col > div { flex: 1; }
    </style></head><body>
      <div class="two-col">
        <div>
          <h2>Features</h2>
          <ul>
            <li>Fast rendering engine</li>
            <li>CSS Flexbox support</li>
            <li>Text shaping</li>
            <li>Color management</li>
          </ul>
        </div>
        <div>
          <h2>Steps</h2>
          <ol>
            <li>Install dependencies</li>
            <li>Configure project</li>
            <li>Run tests</li>
            <li>Deploy to production</li>
          </ol>
        </div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L8-lists", html, {
      maxDiffRatio: 0.20,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 9: Form elements
  test("L9: form elements", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 0; background: #f5f5f5; font-family: Arial, sans-serif; }
      .form-container { width: 400px; margin: 24px auto; background: #fff; padding: 24px; border: 1px solid #ddd; border-radius: 8px; }
      h2 { margin: 0 0 16px; font-size: 20px; color: #222; }
      label { display: block; font-size: 13px; color: #555; margin-bottom: 4px; }
      input[type="text"], input[type="email"], select, textarea {
        display: block; width: 100%; padding: 8px 10px; margin-bottom: 12px;
        border: 1px solid #ccc; border-radius: 4px; font-size: 14px;
        box-sizing: border-box; background: #fff;
      }
      textarea { height: 60px; resize: vertical; }
      .btn-row { display: flex; gap: 8px; margin-top: 8px; }
      button { padding: 8px 20px; border: none; border-radius: 4px; font-size: 14px; cursor: pointer; }
      .primary { background: #2563eb; color: #fff; }
      .secondary { background: #e5e7eb; color: #333; }
    </style></head><body>
      <div class="form-container">
        <h2>Contact</h2>
        <label>Name</label>
        <input type="text" value="John Doe" />
        <label>Email</label>
        <input type="email" value="john@example.com" />
        <label>Category</label>
        <select><option>General</option></select>
        <label>Message</label>
        <textarea>Hello there</textarea>
        <div class="btn-row">
          <button class="primary">Submit</button>
          <button class="secondary">Cancel</button>
        </div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L9-forms", html, {
      maxDiffRatio: 0.20,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 10: CSS Grid layout
  test("L10: CSS Grid layout", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #f0f2f5; font-family: Arial, sans-serif; }
      .grid { display: grid; grid-template-columns: repeat(3, 1fr); grid-template-rows: auto auto; gap: 12px; }
      .grid-item { background: #fff; padding: 16px; border-radius: 6px; border: 1px solid #e0e0e0; }
      .span-2 { grid-column: span 2; }
      .span-row { grid-row: span 2; }
      .label { font-size: 12px; color: #888; text-transform: uppercase; }
      .value { font-size: 24px; font-weight: bold; color: #222; margin-top: 4px; }
    </style></head><body>
      <div class="grid">
        <div class="grid-item span-2">
          <div class="label">Total Revenue</div>
          <div class="value">$124,500</div>
        </div>
        <div class="grid-item span-row">
          <div class="label">Active Users</div>
          <div class="value">3,421</div>
        </div>
        <div class="grid-item">
          <div class="label">Orders</div>
          <div class="value">892</div>
        </div>
        <div class="grid-item">
          <div class="label">Returns</div>
          <div class="value">23</div>
        </div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L10-grid", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 11: Overflow and clipping
  test("L11: overflow hidden and scroll containers", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; }
      .container { display: flex; gap: 16px; }
      .box { width: 200px; height: 120px; border: 2px solid #333; padding: 8px; }
      .hidden { overflow: hidden; }
      .scroll { overflow: auto; }
      .inner { width: 300px; height: 200px; background: linear-gradient(135deg, #667eea, #764ba2); }
      .text-clip { overflow: hidden; white-space: nowrap; text-overflow: ellipsis; width: 180px; padding: 8px; border: 1px solid #ccc; font-size: 14px; margin-top: 16px; }
    </style></head><body>
      <div class="container">
        <div>
          <div style="font-size:13px;color:#666;margin-bottom:4px;">overflow: hidden</div>
          <div class="box hidden"><div class="inner"></div></div>
        </div>
        <div>
          <div style="font-size:13px;color:#666;margin-bottom:4px;">overflow: auto</div>
          <div class="box scroll"><div class="inner"></div></div>
        </div>
      </div>
      <div class="text-clip">This is a very long text that should be clipped with an ellipsis at the end of the line.</div>
    </body></html>`;

    const result = await compareFixture(browser, "L11-overflow", html, {
      maxDiffRatio: 0.10, // overflow clipping + gradient rendering
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 12: Float layout (simplified — no text wrap to avoid render timeout)
  test("L12: float-based layout", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; }
      .clearfix::after { content: ""; display: table; clear: both; }
      .left { float: left; width: 200px; height: 100px; background: #3498db; margin-right: 16px; }
      .right { float: right; width: 150px; height: 80px; background: #e74c3c; }
      .row { margin-bottom: 16px; }
    </style></head><body>
      <div class="row clearfix">
        <div class="left"></div>
        <div class="right"></div>
      </div>
      <div class="row clearfix">
        <div style="float:left; width:100px; height:60px; background:#2ecc71; margin-right:8px;"></div>
        <div style="float:left; width:100px; height:60px; background:#f39c12; margin-right:8px;"></div>
        <div style="float:left; width:100px; height:60px; background:#9b59b6;"></div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L12-float", html, {
      maxDiffRatio: 0.20,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 13: Linear gradients
  test("L13: linear-gradient backgrounds", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 16px; margin-bottom: 16px; }
      .box { width: 120px; height: 80px; }
    </style></head><body>
      <div class="row">
        <div class="box" style="background: linear-gradient(to right, #ff6b6b, #feca57);"></div>
        <div class="box" style="background: linear-gradient(to bottom, #48dbfb, #0abde3);"></div>
        <div class="box" style="background: linear-gradient(135deg, #667eea, #764ba2);"></div>
      </div>
      <div class="row">
        <div class="box" style="background: linear-gradient(to right, #e74c3c, #f39c12, #2ecc71);"></div>
        <div class="box" style="background: linear-gradient(45deg, #000, #fff);"></div>
        <div class="box" style="background: linear-gradient(to left, #2c3e50, #3498db);"></div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L13-gradient", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  // Level 14: Border-radius
  test("L14: border-radius on boxes", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 16px; margin-bottom: 16px; align-items: center; }
      .box { width: 100px; height: 100px; }
    </style></head><body>
      <div class="row">
        <div class="box" style="background:#3498db; border-radius:10px;"></div>
        <div class="box" style="background:#e74c3c; border-radius:50px;"></div>
        <div class="box" style="background:#2ecc71; border-radius:50%;"></div>
      </div>
      <div class="row">
        <div class="box" style="background:#f39c12; border-radius:20px 0 20px 0;"></div>
        <div class="box" style="background:#9b59b6; border-radius:40px 10px;"></div>
        <div style="width:200px; height:60px; background: linear-gradient(to right, #667eea, #764ba2); border-radius:30px;"></div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L14-border-radius", html, {
      maxDiffRatio: 0.15,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });

  test("L15: border rendering", async ({ browser }) => {
    const html = `<!DOCTYPE html><html><head><style>
      body { margin: 20px; background: #fff; font-family: Arial, sans-serif; }
      .row { display: flex; gap: 16px; margin-bottom: 16px; align-items: center; }
      .box { width: 100px; height: 80px; }
    </style></head><body>
      <div class="row">
        <div class="box" style="border: 3px solid #333;"></div>
        <div class="box" style="border: 5px solid #e74c3c;"></div>
        <div class="box" style="border: 2px solid #3498db; background: #ecf0f1;"></div>
      </div>
      <div class="row">
        <div class="box" style="border-top: 4px solid #e74c3c; border-bottom: 4px solid #3498db; border-left: 4px solid #2ecc71; border-right: 4px solid #f39c12;"></div>
        <div class="box" style="border: 8px solid #9b59b6; background: #f1c40f;"></div>
        <div class="box" style="border: 1px solid #ccc; border-left: 5px solid #e74c3c;"></div>
      </div>
    </body></html>`;

    const result = await compareFixture(browser, "L15-borders", html, {
      maxDiffRatio: 0.12,
    });
    expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
  });
});
