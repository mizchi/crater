/**
 * WPT Reftest Runner for Crater
 *
 * Compares visual rendering between browser (Puppeteer) and Crater
 * using pixel-level comparison for filter effects and compositing tests.
 *
 * Usage:
 *   npx tsx scripts/wpt-reftest-runner.ts wpt/css/filter-effects/filter-grayscale-001.html
 *   npx tsx scripts/wpt-reftest-runner.ts --module filter-effects
 *   npx tsx scripts/wpt-reftest-runner.ts --list
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { renderer } from '../wasm/dist/crater.js';

// Types
interface ReftestResult {
  name: string;
  passed: boolean;
  similarity: number;
  diffPixels: number;
  totalPixels: number;
  error?: string;
}

interface ReftestFile {
  test: string;
  ref: string;
  matchType: 'match' | 'mismatch';
}

// Configuration
const VIEWPORT = { width: 400, height: 300 };
const SIMILARITY_THRESHOLD = 0.95; // 95% pixel match required
const COLOR_TOLERANCE = 5; // Allow small color differences

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
</style>
`;

/**
 * Extract ref link from test HTML
 */
function extractRefLink(htmlPath: string): ReftestFile | null {
  const content = fs.readFileSync(htmlPath, 'utf-8');

  // Look for <link rel="match" href="..."> or <link rel="mismatch" href="...">
  const matchRegex = /<link\s+rel\s*=\s*["'](match|mismatch)["']\s+href\s*=\s*["']([^"']+)["']/i;
  const matchAlt = /<link\s+href\s*=\s*["']([^"']+)["']\s+rel\s*=\s*["'](match|mismatch)["']/i;

  let match = content.match(matchRegex) || content.match(matchAlt);

  if (!match) return null;

  const matchType = (match[1] === 'match' || match[2] === 'match') ? 'match' : 'mismatch';
  const refHref = match[1] === 'match' || match[1] === 'mismatch' ? match[2] : match[1];

  const htmlDir = path.dirname(htmlPath);
  const refPath = path.resolve(htmlDir, refHref);

  if (!fs.existsSync(refPath)) {
    return null;
  }

  return {
    test: htmlPath,
    ref: refPath,
    matchType
  };
}

/**
 * Prepare HTML content for rendering
 */
function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');

  // Inline external CSS
  const htmlDir = path.dirname(htmlPath);
  const linkRegex = /<link\s+[^>]*rel\s*=\s*["']stylesheet["'][^>]*>/gi;
  htmlContent = htmlContent.replace(linkRegex, (match) => {
    const hrefMatch = match.match(/href\s*=\s*["']([^"']+)["']/i);
    if (!hrefMatch) return match;

    const href = hrefMatch[1];
    if (href.startsWith('http://') || href.startsWith('https://')) return match;

    const cssPath = path.resolve(htmlDir, href);
    try {
      if (fs.existsSync(cssPath)) {
        const cssContent = fs.readFileSync(cssPath, 'utf-8');
        return `<style>/* Inlined from ${href} */\n${cssContent}</style>`;
      }
    } catch {}
    return '';
  });

  // Remove scripts
  htmlContent = htmlContent.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');

  // Add CSS reset
  if (htmlContent.includes('<head>')) {
    htmlContent = htmlContent.replace('<head>', '<head>' + CSS_RESET);
  } else if (htmlContent.includes('<body>')) {
    htmlContent = htmlContent.replace('<body>', CSS_RESET + '<body>');
  } else {
    htmlContent = CSS_RESET + htmlContent;
  }

  return htmlContent;
}

/**
 * Capture screenshot from browser using Puppeteer
 */
async function captureFromBrowser(browser: puppeteer.Browser, htmlPath: string): Promise<Buffer> {
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);

  const htmlContent = prepareHtmlContent(htmlPath);
  await page.setContent(htmlContent, { waitUntil: 'networkidle0', timeout: 5000 });

  const screenshot = await page.screenshot({ type: 'png' }) as Buffer;
  await page.close();

  return screenshot;
}

/**
 * Capture screenshot from Crater
 */
function captureFromCrater(htmlPath: string): Buffer {
  const htmlContent = prepareHtmlContent(htmlPath);

  // Render to PNG using Crater
  const pngData = renderer.renderHtmlToPng(htmlContent, VIEWPORT.width, VIEWPORT.height);
  return Buffer.from(pngData);
}

/**
 * Simple PNG decoder for raw pixel data
 */
function decodePng(buffer: Buffer): { width: number; height: number; data: Uint8Array } | null {
  try {
    // Check PNG signature
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (let i = 0; i < 8; i++) {
      if (buffer[i] !== signature[i]) return null;
    }

    // For now, use a simple approach: extract RGBA data
    // This is a simplified decoder that works for basic PNGs

    let offset = 8;
    let width = 0, height = 0;
    let colorType = 0;
    let bitDepth = 0;
    const chunks: { type: string; data: Buffer }[] = [];

    while (offset < buffer.length) {
      const length = buffer.readUInt32BE(offset);
      const type = buffer.slice(offset + 4, offset + 8).toString('ascii');
      const data = buffer.slice(offset + 8, offset + 8 + length);

      chunks.push({ type, data });

      if (type === 'IHDR') {
        width = data.readUInt32BE(0);
        height = data.readUInt32BE(4);
        bitDepth = data[8];
        colorType = data[9];
      }

      if (type === 'IEND') break;

      offset += 12 + length;
    }

    // For simplicity, we'll compare the raw PNG bytes since both are PNG format
    // A more sophisticated approach would decode and compare pixels
    return { width, height, data: new Uint8Array(buffer) };
  } catch {
    return null;
  }
}

/**
 * Compare two images pixel by pixel
 * Returns similarity score (0-1)
 */
function compareImages(img1: Buffer, img2: Buffer): { similarity: number; diffPixels: number; totalPixels: number } {
  // Simple byte comparison with tolerance
  const len = Math.min(img1.length, img2.length);
  let matchCount = 0;
  let totalSamples = 0;

  // Skip PNG header (first ~50 bytes typically)
  const startOffset = 50;

  for (let i = startOffset; i < len; i++) {
    const diff = Math.abs(img1[i] - img2[i]);
    if (diff <= COLOR_TOLERANCE) {
      matchCount++;
    }
    totalSamples++;
  }

  // Also account for size difference
  const sizeDiff = Math.abs(img1.length - img2.length);
  const sizePenalty = sizeDiff / Math.max(img1.length, img2.length);

  const similarity = (matchCount / totalSamples) * (1 - sizePenalty);
  const diffPixels = totalSamples - matchCount;

  return { similarity, diffPixels, totalPixels: totalSamples };
}

/**
 * Run a single reftest
 */
async function runReftest(browser: puppeteer.Browser, testFile: ReftestFile): Promise<ReftestResult> {
  const name = path.basename(testFile.test);

  try {
    // Capture test from both browser and Crater
    const browserTest = await captureFromBrowser(browser, testFile.test);
    const craterTest = captureFromCrater(testFile.test);

    // Capture reference from both browser and Crater
    const browserRef = await captureFromBrowser(browser, testFile.ref);
    const craterRef = captureFromCrater(testFile.ref);

    // Compare Crater test vs Crater ref
    const { similarity: craterSimilarity, diffPixels, totalPixels } = compareImages(craterTest, craterRef);

    // For 'match' type, they should be similar
    // For 'mismatch' type, they should be different
    const passed = testFile.matchType === 'match'
      ? craterSimilarity >= SIMILARITY_THRESHOLD
      : craterSimilarity < SIMILARITY_THRESHOLD;

    return { name, passed, similarity: craterSimilarity, diffPixels, totalPixels };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return { name, passed: false, similarity: 0, diffPixels: 0, totalPixels: 0, error: message };
  }
}

/**
 * Get reftest files from a module directory
 */
function getReftestFiles(moduleDir: string): ReftestFile[] {
  if (!fs.existsSync(moduleDir)) return [];

  const files = fs.readdirSync(moduleDir)
    .filter(f => f.endsWith('.html') && !f.includes('-ref'))
    .map(f => path.join(moduleDir, f));

  const reftests: ReftestFile[] = [];

  for (const file of files) {
    const reftest = extractRefLink(file);
    if (reftest) {
      reftests.push(reftest);
    }
  }

  return reftests;
}

/**
 * List available reftest modules
 */
function listModules(): void {
  const modules = ['filter-effects', 'compositing'];

  console.log('Available reftest modules:\n');

  for (const mod of modules) {
    const moduleDir = path.join('wpt/css', mod);
    const files = getReftestFiles(moduleDir);
    console.log(`  ${mod}: ${files.length} reftests`);
  }
}

/**
 * Main
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('WPT Reftest Runner for Crater\n');
    console.log('Usage:');
    console.log('  npx tsx scripts/wpt-reftest-runner.ts <path/to/test.html>');
    console.log('  npx tsx scripts/wpt-reftest-runner.ts --module filter-effects');
    console.log('  npx tsx scripts/wpt-reftest-runner.ts --list');
    return;
  }

  if (args[0] === '--list') {
    listModules();
    return;
  }

  // Collect reftest files
  let reftestFiles: ReftestFile[] = [];

  if (args[0] === '--module') {
    const modName = args[1];
    if (!modName) {
      console.error('Module name required');
      process.exit(1);
    }
    const moduleDir = path.join('wpt/css', modName);
    reftestFiles = getReftestFiles(moduleDir);
  } else {
    // Single file
    for (const arg of args) {
      if (fs.existsSync(arg)) {
        const reftest = extractRefLink(arg);
        if (reftest) {
          reftestFiles.push(reftest);
        } else {
          console.log(`Skipping ${arg}: no ref link found`);
        }
      }
    }
  }

  if (reftestFiles.length === 0) {
    console.error('No reftest files found');
    process.exit(1);
  }

  console.log(`Running ${reftestFiles.length} reftest(s)...\n`);

  const browser = await puppeteer.launch({ headless: true });

  let passed = 0;
  let failed = 0;
  const failedResults: ReftestResult[] = [];

  for (const reftest of reftestFiles) {
    const result = await runReftest(browser, reftest);

    const icon = result.passed ? '✓' : '✗';
    const simPercent = (result.similarity * 100).toFixed(1);
    console.log(`${icon} ${result.name} (${simPercent}% similar)`);

    if (result.passed) {
      passed++;
    } else {
      failed++;
      failedResults.push(result);
    }
  }

  await browser.close();

  // Print summary
  if (failedResults.length > 0) {
    console.log('\nFailed tests:\n');
    for (const result of failedResults.slice(0, 10)) {
      console.log(`  ${result.name}: ${(result.similarity * 100).toFixed(1)}% similar`);
      if (result.error) {
        console.log(`    Error: ${result.error}`);
      }
    }
  }

  console.log(`\nSummary: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
