/**
 * Compare AEB results with/without layout and surface cases
 * where layout helps or hurts.
 *
 * Usage:
 *   npx tsx scripts/aeb-compare-layout.ts
 *   npx tsx scripts/aeb-compare-layout.ts --limit 50
 *   npx tsx scripts/aeb-compare-layout.ts --top 10 --min-delta 0.02
 *   npx tsx scripts/aeb-compare-layout.ts --only-css
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../wasm/dist/crater.js';

const AEB_PATH = path.join(
  process.env.HOME || '',
  'ghq/github.com/scrapinghub/article-extraction-benchmark'
);

interface GroundTruth {
  [key: string]: {
    articleBody: string;
    url?: string;
  };
}

interface Metrics {
  precision: number;
  recall: number;
  f1: number;
}

interface CaseResult {
  hash: string;
  url?: string;
  css: { styleTag: boolean; linkCss: boolean; inlineStyle: boolean };
  without: Metrics;
  withLayout: Metrics;
  delta: number;
}

function calculateMetrics(expected: string, extracted: string): Metrics {
  const normalize = (text: string) =>
    text
      .toLowerCase()
      .replace(/\s+/g, ' ')
      .trim();

  const expectedNorm = normalize(expected);
  const extractedNorm = normalize(extracted);

  if (!expectedNorm || !extractedNorm) {
    return { precision: 0, recall: 0, f1: 0 };
  }

  const expectedWords = new Set(expectedNorm.split(' '));
  const extractedWords = new Set(extractedNorm.split(' '));

  let matchCount = 0;
  for (const word of extractedWords) {
    if (expectedWords.has(word)) {
      matchCount++;
    }
  }

  const precision = extractedWords.size > 0 ? matchCount / extractedWords.size : 0;
  const recall = expectedWords.size > 0 ? matchCount / expectedWords.size : 0;
  const f1 = precision + recall > 0 ? (2 * precision * recall) / (precision + recall) : 0;
  return { precision, recall, f1 };
}

function loadGroundTruth(): GroundTruth {
  const groundTruthPath = path.join(AEB_PATH, 'ground-truth.json');
  if (!fs.existsSync(groundTruthPath)) {
    throw new Error(`Ground truth not found at ${groundTruthPath}. Run: ghq get scrapinghub/article-extraction-benchmark`);
  }
  return JSON.parse(fs.readFileSync(groundTruthPath, 'utf-8'));
}

function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`HTML file not found: ${htmlPath}`);
  }
  const gzipped = fs.readFileSync(htmlPath);
  return gunzipSync(gzipped).toString('utf-8');
}

function detectCss(html: string) {
  return {
    styleTag: /<style\b/i.test(html),
    linkCss: /<link\b[^>]*rel=["']?stylesheet/i.test(html),
    inlineStyle: /\sstyle=["']/.test(html),
  };
}

function runOne(html: string, expected: string, useLayout: boolean): Metrics {
  const resultJson = useLayout
    ? accessibility.extractMainContentWithLayout(html, 1280, 800)
    : accessibility.extractMainContent(html);
  const result = JSON.parse(resultJson) as { mainContent: string | null };
  const extracted = result.mainContent || '';
  return calculateMetrics(expected, extracted);
}

function format(m: Metrics) {
  return `P=${(m.precision * 100).toFixed(1)} R=${(m.recall * 100).toFixed(1)} F1=${(m.f1 * 100).toFixed(1)}`;
}

async function main() {
  const args = process.argv.slice(2);
  let limit = Infinity;
  let top = 10;
  let minDelta = 0.01;
  let onlyCss = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--top' && args[i + 1]) {
      top = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--min-delta' && args[i + 1]) {
      minDelta = parseFloat(args[i + 1]);
      i++;
    } else if (args[i] === '--only-css') {
      onlyCss = true;
    }
  }

  const groundTruth = loadGroundTruth();
  const hashes = Object.keys(groundTruth).slice(0, limit);
  const results: CaseResult[] = [];

  for (const hash of hashes) {
    const expected = groundTruth[hash].articleBody;
    const html = loadHtml(hash);
    const css = detectCss(html);
    if (onlyCss && !(css.styleTag || css.linkCss || css.inlineStyle)) {
      continue;
    }
    const without = runOne(html, expected, false);
    const withLayout = runOne(html, expected, true);
    const delta = withLayout.f1 - without.f1;
    results.push({
      hash,
      url: groundTruth[hash].url,
      css,
      without,
      withLayout,
      delta,
    });
  }

  const improved = results
    .filter(r => r.delta >= minDelta)
    .sort((a, b) => b.delta - a.delta)
    .slice(0, top);
  const regressed = results
    .filter(r => r.delta <= -minDelta)
    .sort((a, b) => a.delta - b.delta)
    .slice(0, top);

  console.log(`Total compared: ${results.length}`);
  console.log(`Min delta: ${minDelta.toFixed(2)}`);
  console.log('');
  console.log('=== Improvements (layout helps) ===');
  for (const r of improved) {
    const cssFlags = [
      r.css.styleTag ? 'style' : null,
      r.css.linkCss ? 'link' : null,
      r.css.inlineStyle ? 'inline' : null,
    ]
      .filter(Boolean)
      .join(',');
    console.log(
      `${r.hash.slice(0, 16)}... ΔF1=${(r.delta * 100).toFixed(1)}% ` +
        `[${cssFlags || 'no-css'}] ` +
        `${format(r.without)} -> ${format(r.withLayout)}`
    );
  }
  console.log('');
  console.log('=== Regressions (layout hurts) ===');
  for (const r of regressed) {
    const cssFlags = [
      r.css.styleTag ? 'style' : null,
      r.css.linkCss ? 'link' : null,
      r.css.inlineStyle ? 'inline' : null,
    ]
      .filter(Boolean)
      .join(',');
    console.log(
      `${r.hash.slice(0, 16)}... ΔF1=${(r.delta * 100).toFixed(1)}% ` +
        `[${cssFlags || 'no-css'}] ` +
        `${format(r.without)} -> ${format(r.withLayout)}`
    );
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
