/**
 * Capture screenshots of selected samples for labeling reference.
 *
 * Usage:
 *   npx tsx nav-benchmark/scripts/capture-screenshots.ts
 *   npx tsx nav-benchmark/scripts/capture-screenshots.ts --limit 5
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import puppeteer from 'puppeteer';

const AEB_PATH = path.join(
  process.env.HOME || '',
  'ghq/github.com/scrapinghub/article-extraction-benchmark'
);

const SAMPLES_FILE = path.join(process.cwd(), 'nav-benchmark/samples.json');
const OUTPUT_DIR = path.join(process.cwd(), 'nav-benchmark/screenshots');

interface Sample {
  hash: string;
  url: string | null;
  domain: string;
  navCount: number;
}

function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  const gzipped = fs.readFileSync(htmlPath);
  return gunzipSync(gzipped).toString('utf-8');
}

async function main() {
  const args = process.argv.slice(2);
  let limit = Infinity;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      limit = parseInt(args[i + 1], 10);
    }
  }

  const samples: Sample[] = JSON.parse(fs.readFileSync(SAMPLES_FILE, 'utf-8'));
  const targets = samples.slice(0, limit);

  console.log(`Capturing ${targets.length} screenshots...`);

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  for (const sample of targets) {
    const outputPath = path.join(OUTPUT_DIR, `${sample.hash}.png`);

    if (fs.existsSync(outputPath)) {
      console.log(`Skip (exists): ${sample.hash.slice(0, 16)} - ${sample.domain}`);
      continue;
    }

    console.log(`Capturing: ${sample.hash.slice(0, 16)} - ${sample.domain}`);

    try {
      const html = loadHtml(sample.hash);

      // Set content with base URL for relative resources
      await page.setContent(html, {
        waitUntil: 'domcontentloaded',
        timeout: 10000,
      });

      // Wait a bit for any CSS to apply
      await page.evaluate(() => new Promise(resolve => setTimeout(resolve, 500)));

      // Take full page screenshot
      await page.screenshot({
        path: outputPath,
        fullPage: true,
      });

      console.log(`  Saved: ${outputPath}`);
    } catch (error) {
      console.error(`  Error: ${error}`);
    }
  }

  await browser.close();
  console.log('Done.');
}

main().catch(console.error);
