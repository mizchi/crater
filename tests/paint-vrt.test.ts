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
  test.describe.configure({ timeout: 300_000 });

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
      // Target: ≤ 5% with native backend, ≤ 12% with sixel
      const target = process.env.CRATER_PAINT_BACKEND === "native" ? 0.10 : 0.12;
      expect(result.diffRatio).toBeLessThanOrEqual(target);
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

  // --- Inline real-world page pattern fixtures ---

  test("fixture: blog article page layout", async ({ browser }) => {
    const viewport = { width: 960, height: 720 };
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      :root { color-scheme: light; }
      body { margin: 0; background: #fff; font-family: Georgia, "Times New Roman", serif; color: #1a1a1a; }
      header { background: #1a1a2e; color: #fff; padding: 12px 0; }
      header .inner { max-width: 720px; margin: 0 auto; display: flex; align-items: center; justify-content: space-between; }
      header .logo { font-size: 20px; font-weight: bold; font-family: Arial, sans-serif; }
      nav a { color: #ccc; text-decoration: none; font-family: Arial, sans-serif; font-size: 14px; margin-left: 20px; }
      article { max-width: 720px; margin: 32px auto; padding: 0 16px; }
      h1 { font-size: 32px; line-height: 1.3; margin: 0 0 8px; }
      .meta { font-size: 14px; color: #666; font-family: Arial, sans-serif; margin-bottom: 24px; }
      .content p { font-size: 17px; line-height: 1.8; margin: 0 0 16px; }
      .content blockquote { margin: 16px 0; padding: 12px 20px; border-left: 4px solid #3498db; background: #f8f9fa; font-style: italic; }
      .tags { margin-top: 24px; display: flex; gap: 8px; }
      .tag { display: inline-block; padding: 4px 12px; background: #eef2ff; color: #3b5998; font-size: 12px; border-radius: 12px; font-family: Arial, sans-serif; }
    </style></head><body>
      <header><div class="inner"><span class="logo">TechBlog</span><nav><a href="#">Home</a><a href="#">Archive</a><a href="#">About</a></nav></div></header>
      <article>
        <h1>Understanding CSS Layout Engines</h1>
        <div class="meta">March 15, 2026 &middot; 8 min read</div>
        <div class="content">
          <p>Modern CSS layout uses several key algorithms to position elements.</p>
          <blockquote>The box model defines how elements occupy space.</blockquote>
          <p>Flexbox and Grid replaced older float-based techniques.</p>
        </div>
        <div class="tags"><span class="tag">CSS</span><span class="tag">Layout</span><span class="tag">Web</span></div>
      </article>
    </body></html>`;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);
      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-blog-article"),
        threshold: 0.3,
        maxDiffRatio: 0.15,
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

  test("fixture: navigation bar with dropdown-style layout", async ({ browser }) => {
    const viewport = { width: 1024, height: 200 };
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      :root { color-scheme: light; }
      body { margin: 0; background: #f5f5f5; font-family: Arial, sans-serif; }
      .navbar { background: #fff; border-bottom: 1px solid #e0e0e0; padding: 0 24px; display: flex; align-items: center; height: 56px; }
      .brand { font-size: 18px; font-weight: bold; color: #111; margin-right: 32px; }
      .nav-links { display: flex; gap: 4px; flex: 1; }
      .nav-link { padding: 8px 14px; font-size: 14px; color: #555; text-decoration: none; border-radius: 6px; }
      .nav-link.active { background: #eef2ff; color: #2563eb; font-weight: 600; }
      .nav-right { display: flex; align-items: center; gap: 12px; }
      .search-box { padding: 6px 12px; border: 1px solid #d0d0d0; border-radius: 16px; font-size: 13px; width: 180px; background: #fafafa; }
      .avatar { width: 32px; height: 32px; border-radius: 50%; background: #7c3aed; }
      .sub-nav { background: #fff; border-bottom: 1px solid #eee; padding: 0 24px; display: flex; gap: 0; }
      .sub-link { padding: 10px 16px; font-size: 13px; color: #666; text-decoration: none; border-bottom: 2px solid transparent; }
      .sub-link.active { color: #111; border-bottom-color: #2563eb; }
    </style></head><body>
      <div class="navbar">
        <span class="brand">AppName</span>
        <div class="nav-links">
          <a class="nav-link active" href="#">Dashboard</a>
          <a class="nav-link" href="#">Projects</a>
          <a class="nav-link" href="#">Team</a>
          <a class="nav-link" href="#">Settings</a>
        </div>
        <div class="nav-right">
          <input class="search-box" type="text" placeholder="Search..." />
          <div class="avatar"></div>
        </div>
      </div>
      <div class="sub-nav">
        <a class="sub-link active" href="#">Overview</a>
        <a class="sub-link" href="#">Analytics</a>
        <a class="sub-link" href="#">Reports</a>
        <a class="sub-link" href="#">Export</a>
      </div>
    </body></html>`;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);
      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-navbar"),
        threshold: 0.3,
        maxDiffRatio: 0.15,
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

  test("fixture: pricing cards grid", async ({ browser }) => {
    const viewport = { width: 1024, height: 600 };
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      :root { color-scheme: light; }
      body { margin: 0; background: #f8fafc; font-family: Arial, sans-serif; }
      .header { text-align: center; padding: 32px 16px 0; }
      .header h1 { font-size: 28px; color: #111; margin: 0 0 8px; }
      .header p { font-size: 15px; color: #666; margin: 0; }
      .cards { display: flex; gap: 16px; max-width: 900px; margin: 24px auto; padding: 0 16px; }
      .card { flex: 1; background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px; display: flex; flex-direction: column; }
      .card.featured { border-color: #3b82f6; box-shadow: 0 4px 24px rgba(59,130,246,0.15); }
      .plan-name { font-size: 14px; color: #64748b; text-transform: uppercase; letter-spacing: 1px; }
      .price { font-size: 36px; font-weight: bold; color: #0f172a; margin: 8px 0; }
      .price span { font-size: 16px; font-weight: normal; color: #94a3b8; }
      .features { list-style: none; padding: 0; margin: 16px 0; font-size: 14px; color: #475569; }
      .features li { padding: 6px 0; border-bottom: 1px solid #f1f5f9; }
      .cta { margin-top: auto; padding: 10px; border: none; border-radius: 8px; font-size: 14px; font-weight: 600; text-align: center; }
      .cta-outline { background: #fff; border: 1px solid #d1d5db; color: #374151; }
      .cta-primary { background: #3b82f6; color: #fff; }
    </style></head><body>
      <div class="header"><h1>Choose your plan</h1><p>Start free, upgrade anytime</p></div>
      <div class="cards">
        <div class="card">
          <div class="plan-name">Starter</div>
          <div class="price">$0<span>/mo</span></div>
          <ul class="features"><li>1 project</li><li>100 MB</li></ul>
          <button class="cta cta-outline">Get started</button>
        </div>
        <div class="card featured">
          <div class="plan-name">Pro</div>
          <div class="price">$19<span>/mo</span></div>
          <ul class="features"><li>Unlimited</li><li>10 GB</li></ul>
          <button class="cta cta-primary">Upgrade</button>
        </div>
        <div class="card">
          <div class="plan-name">Enterprise</div>
          <div class="price">$49<span>/mo</span></div>
          <ul class="features"><li>100 GB</li><li>SSO</li></ul>
          <button class="cta cta-outline">Contact</button>
        </div>
      </div>
    </body></html>`;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);
      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-pricing-cards"),
        threshold: 0.3,
        maxDiffRatio: 0.15,
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

  test("fixture: footer with multi-column links", async ({ browser }) => {
    const viewport = { width: 960, height: 400 };
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      :root { color-scheme: light; }
      body { margin: 0; font-family: Arial, sans-serif; background: #fff; }
      footer { background: #111827; color: #d1d5db; padding: 32px 24px; }
      .footer-grid { max-width: 800px; margin: 0 auto; display: grid; grid-template-columns: 2fr 1fr 1fr 1fr; gap: 24px; }
      .footer-brand { font-size: 18px; font-weight: bold; color: #fff; margin-bottom: 8px; }
      .footer-desc { font-size: 13px; color: #9ca3af; line-height: 1.5; }
      .footer-col h4 { font-size: 13px; text-transform: uppercase; color: #9ca3af; letter-spacing: 1px; margin: 0 0 12px; }
      .footer-col a { display: block; font-size: 14px; color: #d1d5db; text-decoration: none; padding: 3px 0; }
      .footer-bottom { max-width: 800px; margin: 20px auto 0; padding-top: 16px; border-top: 1px solid #374151; display: flex; justify-content: space-between; font-size: 12px; color: #6b7280; }
    </style></head><body>
      <footer>
        <div class="footer-grid">
          <div>
            <div class="footer-brand">Crater</div>
            <div class="footer-desc">A CSS layout engine written in MoonBit, targeting browser-grade rendering fidelity.</div>
          </div>
          <div class="footer-col"><h4>Product</h4><a href="#">Features</a><a href="#">Pricing</a><a href="#">Changelog</a></div>
          <div class="footer-col"><h4>Resources</h4><a href="#">Docs</a><a href="#">API</a><a href="#">Blog</a></div>
          <div class="footer-col"><h4>Company</h4><a href="#">About</a><a href="#">Careers</a><a href="#">Contact</a></div>
        </div>
        <div class="footer-bottom">
          <span>2026 Crater. All rights reserved.</span>
          <span>Privacy &middot; Terms</span>
        </div>
      </footer>
    </body></html>`;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);
      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-footer"),
        threshold: 0.3,
        maxDiffRatio: 0.15,
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

  test("fixture: login form centered page", async ({ browser }) => {
    const viewport = { width: 800, height: 600 };
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      :root { color-scheme: light; }
      body { margin: 0; background: #f1f5f9; font-family: Arial, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
      .login-card { width: 360px; background: #fff; border-radius: 12px; padding: 32px; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
      .logo { width: 48px; height: 48px; background: #6366f1; border-radius: 12px; margin: 0 auto 16px; }
      h2 { text-align: center; font-size: 22px; color: #111; margin: 0 0 4px; }
      .subtitle { text-align: center; font-size: 14px; color: #64748b; margin-bottom: 24px; }
      label { display: block; font-size: 13px; color: #374151; margin-bottom: 4px; font-weight: 600; }
      input[type="email"], input[type="password"] {
        display: block; width: 100%; padding: 10px 12px; margin-bottom: 16px;
        border: 1px solid #d1d5db; border-radius: 8px; font-size: 14px; box-sizing: border-box;
      }
      .remember-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; font-size: 13px; }
      .remember-row label { font-weight: normal; margin: 0; }
      .remember-row a { color: #6366f1; text-decoration: none; font-size: 13px; }
      .btn { display: block; width: 100%; padding: 10px; background: #6366f1; color: #fff; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; }
      .signup { text-align: center; margin-top: 16px; font-size: 13px; color: #64748b; }
      .signup a { color: #6366f1; text-decoration: none; }
    </style></head><body>
      <div class="login-card">
        <div class="logo"></div>
        <h2>Welcome back</h2>
        <div class="subtitle">Sign in to your account</div>
        <label>Email</label>
        <input type="email" placeholder="you@example.com" />
        <label>Password</label>
        <input type="password" placeholder="Enter password" />
        <div class="remember-row">
          <label><input type="checkbox" /> Remember me</label>
          <a href="#">Forgot password?</a>
        </div>
        <button class="btn">Sign in</button>
        <div class="signup">New here? <a href="#">Create account</a></div>
      </div>
    </body></html>`;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);
      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-login-form"),
        threshold: 0.3,
        maxDiffRatio: 0.15,
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

  test("fixture: hackernews-style listing page", async ({ browser }) => {
    const viewport = { width: 800, height: 600 };
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      :root { color-scheme: light; }
      body { margin: 0; background: #f6f6ef; font-family: Verdana, Geneva, sans-serif; font-size: 10pt; }
      #header { background: #ff6600; padding: 2px; display: flex; align-items: center; }
      #header .logo { font-weight: bold; font-size: 13pt; color: #000; margin: 0 5px; }
      #header nav { display: flex; gap: 6px; font-size: 10pt; }
      #header nav a { color: #000; text-decoration: none; }
      #header nav .sep { color: #000; }
      #header .login { margin-left: auto; color: #000; font-size: 10pt; padding-right: 4px; }
      .items { padding: 0; margin: 0; }
      .item { display: flex; padding: 2px 0; }
      .rank { color: #828282; min-width: 30px; text-align: right; padding-right: 6px; font-size: 10pt; }
      .vote { min-width: 14px; }
      .vote .arrow { width: 0; height: 0; border-left: 5px solid transparent; border-right: 5px solid transparent; border-bottom: 10px solid #828282; display: inline-block; }
      .title-line { font-size: 10pt; }
      .title-line a { color: #000; text-decoration: none; }
      .title-line .site { color: #828282; font-size: 8pt; margin-left: 4px; }
      .subtext { font-size: 8pt; color: #828282; padding-left: 50px; }
      .subtext a { color: #828282; text-decoration: none; }
      .spacer { height: 5px; }
      .more { padding: 10px 0 0 50px; }
      .more a { color: #000; text-decoration: none; font-size: 10pt; }
    </style></head><body>
      <div id="header">
        <span class="logo">Y</span>
        <nav>
          <a href="#"><b>Hacker News</b></a>
          <span class="sep">|</span><a href="#">new</a>
          <span class="sep">|</span><a href="#">past</a>
          <span class="sep">|</span><a href="#">ask</a>
          <span class="sep">|</span><a href="#">show</a>
        </nav>
        <span class="login">login</span>
      </div>
      <div class="items">
        <div class="item"><span class="rank">1.</span><span class="vote"><span class="arrow"></span></span><span class="title-line"><a href="#">Show HN: A CSS layout engine in MoonBit</a><span class="site">(github.com/mizchi)</span></span></div>
        <div class="subtext">342 points by user1 3 hours ago | <a href="#">187 comments</a></div>
        <div class="spacer"></div>
        <div class="item"><span class="rank">2.</span><span class="vote"><span class="arrow"></span></span><span class="title-line"><a href="#">The Browser Rendering Pipeline</a><span class="site">(developer.chrome.com)</span></span></div>
        <div class="subtext">198 points by user2 5 hours ago | <a href="#">94 comments</a></div>
        <div class="spacer"></div>
        <div class="item"><span class="rank">3.</span><span class="vote"><span class="arrow"></span></span><span class="title-line"><a href="#">WebAssembly is Now Turing Complete</a><span class="site">(arxiv.org)</span></span></div>
        <div class="subtext">156 points by user3 4 hours ago | <a href="#">72 comments</a></div>
        <div class="spacer"></div>
      </div>
      <div class="more"><a href="#">More</a></div>
    </body></html>`;

    const chromiumPage = await chromiumPageForVrt(browser, viewport);
    const craterPage = new CraterBidiPage();
    await craterPage.connect();
    try {
      await chromiumPage.setContent(html, { waitUntil: "load" });
      const chromiumPng = await chromiumPage.screenshot({ type: "png" });
      const craterImage = await renderCraterHtml(craterPage, html, viewport);
      const result = await compareChromiumPngToImage(chromiumPage, chromiumPng, craterImage, {
        outputDir: path.join(OUTPUT_ROOT, "fixture-hackernews"),
        threshold: 0.3,
        maxDiffRatio: 0.20,
        cropToContent: true,
        contentPadding: 12,
        backgroundTolerance: 18,
        maskToVisibleContent: true,
        maskPadding: 2,
      });
      console.log(`hackernews diffRatio: ${result.diffRatio.toFixed(4)} (${result.diffPixels}/${result.totalPixels} pixels)`);
      expect(result.diffRatio).toBeLessThanOrEqual(result.maxDiffRatio);
    } finally {
      await craterPage.close();
      await chromiumPage.close();
    }
  });

  // --- URL VRT snapshots: real websites captured with capture-real-world-snapshot.ts ---

  const urlSnapshots: { name: string; maxDiffRatio: number }[] = [
    { name: "info-cern-ch", maxDiffRatio: 0.10 },
    { name: "google", maxDiffRatio: 0.10 },
    { name: "hackernews", maxDiffRatio: 0.20 },
    { name: "wikipedia", maxDiffRatio: 0.25 },
    { name: "craigslist", maxDiffRatio: 0.15 },
    { name: "lobsters", maxDiffRatio: 0.20 },
    { name: "lite-cnn", maxDiffRatio: 0.25 },
    { name: "npmjs-express", maxDiffRatio: 0.25 },
  ];

  for (const { name: snapshotName, maxDiffRatio } of urlSnapshots) {
    test(`url snapshot: ${snapshotName} visual diff within budget`, async ({
      browser,
    }) => {
      test.slow();
      test.skip(
        !AVAILABLE_REAL_WORLD_SNAPSHOTS.has(snapshotName),
        `${snapshotName} snapshot is not available locally`,
      );
      await expectSnapshotWithinBudget(browser, snapshotName, {
        threshold: 0.3,
        maxDiffRatio,
      });
    });
  }
});
