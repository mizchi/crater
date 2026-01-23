/**
 * Article Extraction Benchmark (AEB) Runner for Crater
 *
 * Compares content extraction between crater's arc90 algorithm and ground truth
 * Uses https://github.com/scrapinghub/article-extraction-benchmark
 *
 * Usage:
 *   npx tsx scripts/aeb-runner.ts                    # Run all tests
 *   npx tsx scripts/aeb-runner.ts --limit 10         # Run first 10 tests
 *   npx tsx scripts/aeb-runner.ts <hash>             # Run specific test
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../wasm/dist/crater.js';

// Path to Article Extraction Benchmark repository (cloned via ghq)
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

interface ExtractionResult {
  mainContent: string | null;
  contentBlocksCount: number;
  detectedAdsCount: number;
  detectedNavigationCount: number;
  topScores: number[];
}

interface TestResult {
  hash: string;
  precision: number;
  recall: number;
  f1: number;
  expectedLength: number;
  extractedLength: number;
  error?: string;
  extractedText?: string;
  expectedText?: string;
  extraction?: ExtractionResult;
}

function dumpResult(
  dumpDir: string,
  hash: string,
  expected: string,
  extracted: string,
  metrics: { precision: number; recall: number; f1: number },
  useLayout: boolean,
  extraction: ExtractionResult
): void {
  const dir = path.join(dumpDir, hash);
  fs.mkdirSync(dir, { recursive: true });
  const suffix = useLayout ? '-with-layout' : '';
  fs.writeFileSync(path.join(dir, `expected${suffix}.txt`), expected);
  fs.writeFileSync(path.join(dir, `extracted${suffix}.txt`), extracted);
  const meta = {
    hash,
    mode: useLayout ? 'with-layout' : 'without-layout',
    precision: metrics.precision,
    recall: metrics.recall,
    f1: metrics.f1,
    expectedLength: expected.length,
    extractedLength: extracted.length,
    contentBlocksCount: extraction.contentBlocksCount,
    detectedAdsCount: extraction.detectedAdsCount,
    detectedNavigationCount: extraction.detectedNavigationCount,
    topScores: extraction.topScores,
  };
  fs.writeFileSync(path.join(dir, 'meta.json'), JSON.stringify(meta, null, 2));
}

function dumpError(
  dumpDir: string,
  hash: string,
  expected: string,
  error: string,
  useLayout: boolean
): void {
  const dir = path.join(dumpDir, hash);
  fs.mkdirSync(dir, { recursive: true });
  const suffix = useLayout ? '-with-layout' : '';
  fs.writeFileSync(path.join(dir, `expected${suffix}.txt`), expected);
  fs.writeFileSync(path.join(dir, `error${suffix}.txt`), error);
  const meta = {
    hash,
    mode: useLayout ? 'with-layout' : 'without-layout',
    error,
    expectedLength: expected.length,
  };
  fs.writeFileSync(path.join(dir, 'meta.json'), JSON.stringify(meta, null, 2));
}

/**
 * Calculate text similarity metrics
 */
function calculateMetrics(expected: string, extracted: string): { precision: number; recall: number; f1: number } {
  // Normalize texts
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

  // Word-based comparison
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

/**
 * Load ground truth from AEB repository
 */
function loadGroundTruth(): GroundTruth {
  const groundTruthPath = path.join(AEB_PATH, 'ground-truth.json');
  if (!fs.existsSync(groundTruthPath)) {
    throw new Error(`Ground truth not found at ${groundTruthPath}. Run: ghq get scrapinghub/article-extraction-benchmark`);
  }
  return JSON.parse(fs.readFileSync(groundTruthPath, 'utf-8'));
}

/**
 * Load HTML file for a given hash
 */
function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`HTML file not found: ${htmlPath}`);
  }
  const gzipped = fs.readFileSync(htmlPath);
  return gunzipSync(gzipped).toString('utf-8');
}

/**
 * Run extraction test for a single document
 */
function runTest(
  hash: string,
  expectedBody: string,
  useLayout: boolean = false,
  dumpDir: string | null = null
): TestResult {
  try {
    const html = loadHtml(hash);
    const resultJson = useLayout
      ? accessibility.extractMainContentWithLayout(html, 1280, 800)
      : accessibility.extractMainContent(html);
    const result: ExtractionResult = JSON.parse(resultJson);

    const extracted = result.mainContent || '';
    const metrics = calculateMetrics(expectedBody, extracted);
    if (dumpDir) {
      dumpResult(dumpDir, hash, expectedBody, extracted, metrics, useLayout, result);
    }

    return {
      hash,
      ...metrics,
      expectedLength: expectedBody.length,
      extractedLength: extracted.length,
      ...(dumpDir
        ? { extractedText: extracted, expectedText: expectedBody, extraction: result }
        : {}),
    };
  } catch (error) {
    if (dumpDir) {
      dumpError(
        dumpDir,
        hash,
        expectedBody,
        error instanceof Error ? error.message : String(error),
        useLayout
      );
    }
    return {
      hash,
      precision: 0,
      recall: 0,
      f1: 0,
      expectedLength: expectedBody.length,
      extractedLength: 0,
      error: error instanceof Error ? error.message : String(error),
      ...(dumpDir ? { expectedText: expectedBody } : {}),
    };
  }
}

/**
 * Main entry point
 */
async function main() {
  const args = process.argv.slice(2);

  // Parse arguments
  let limit = Infinity;
  let specificHash: string | null = null;
  let useLayout = false;
  let dumpDir: string | null = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--with-layout') {
      useLayout = true;
    } else if (args[i] === '--dump') {
      dumpDir = path.join(process.cwd(), 'render-results/aeb-dump');
    } else if (args[i] === '--help' || args[i] === '-h') {
      console.log('AEB Runner for Crater\n');
      console.log('Usage:');
      console.log('  npx tsx scripts/aeb-runner.ts                  # Run all tests');
      console.log('  npx tsx scripts/aeb-runner.ts --limit 10       # Run first 10 tests');
      console.log('  npx tsx scripts/aeb-runner.ts --with-layout    # Use layout-based extraction');
      console.log('  npx tsx scripts/aeb-runner.ts --dump           # Dump expected/extracted texts');
      console.log('  npx tsx scripts/aeb-runner.ts <hash>           # Run specific test');
      return;
    } else if (!args[i].startsWith('-')) {
      specificHash = args[i];
    }
  }

  // Load ground truth
  console.log('Loading ground truth...');
  const groundTruth = loadGroundTruth();
  const hashes = Object.keys(groundTruth);
  console.log(`Found ${hashes.length} test cases\n`);

  // Filter tests
  let testHashes: string[];
  if (specificHash) {
    if (!groundTruth[specificHash]) {
      console.error(`Hash not found: ${specificHash}`);
      process.exit(1);
    }
    testHashes = [specificHash];
  } else {
    testHashes = hashes.slice(0, limit);
  }

  // Run tests
  const mode = useLayout ? 'with layout' : 'without layout';
  console.log(`Running ${testHashes.length} tests (${mode})...\n`);
  const results: TestResult[] = [];
  let completed = 0;

  for (const hash of testHashes) {
    const expected = groundTruth[hash].articleBody;
    const result = runTest(hash, expected, useLayout, dumpDir);
    results.push(result);
    completed++;

    // Progress indicator
    const icon = result.f1 >= 0.5 ? '.' : (result.error ? 'E' : 'x');
    process.stdout.write(icon);
    if (completed % 50 === 0) {
      process.stdout.write(` ${completed}/${testHashes.length}\n`);
    }
  }
  console.log('\n');

  // Calculate summary statistics
  const successResults = results.filter(r => !r.error);
  const avgPrecision = successResults.reduce((sum, r) => sum + r.precision, 0) / successResults.length;
  const avgRecall = successResults.reduce((sum, r) => sum + r.recall, 0) / successResults.length;
  const avgF1 = successResults.reduce((sum, r) => sum + r.f1, 0) / successResults.length;

  // Print summary
  console.log('=== Summary ===');
  console.log(`Total tests: ${results.length}`);
  console.log(`Successful: ${successResults.length}`);
  console.log(`Errors: ${results.filter(r => r.error).length}`);
  console.log('');
  console.log(`Mean Precision: ${(avgPrecision * 100).toFixed(2)}%`);
  console.log(`Mean Recall: ${(avgRecall * 100).toFixed(2)}%`);
  console.log(`Mean F1: ${(avgF1 * 100).toFixed(2)}%`);

  // Print worst results
  const worstResults = [...results]
    .filter(r => !r.error)
    .sort((a, b) => a.f1 - b.f1)
    .slice(0, 5);

  if (worstResults.length > 0) {
    console.log('\n=== Worst Results ===');
    for (const r of worstResults) {
      console.log(`  ${r.hash.slice(0, 16)}... F1=${(r.f1 * 100).toFixed(1)}% (P=${(r.precision * 100).toFixed(1)}%, R=${(r.recall * 100).toFixed(1)}%)`);
    }
  }

  // Print errors
  const errorResults = results.filter(r => r.error);
  if (errorResults.length > 0) {
    console.log('\n=== Errors ===');
    for (const r of errorResults.slice(0, 5)) {
      console.log(`  ${r.hash.slice(0, 16)}... ${r.error}`);
    }
    if (errorResults.length > 5) {
      console.log(`  ... and ${errorResults.length - 5} more errors`);
    }
  }

  // Exit with error if average F1 is too low
  if (avgF1 < 0.3) {
    process.exit(1);
  }
}

main().catch(console.error);
