#!/usr/bin/env npx tsx
/**
 * Layout Comparison CLI
 *
 * Usage:
 *   npx tsx test_utils/compare-layout.ts <html-file> [--save] [--tolerance=N]
 *
 * Examples:
 *   npx tsx test_utils/compare-layout.ts real-world/wikipedia/index.html
 *   npx tsx test_utils/compare-layout.ts real-world/wikipedia/index.html --save --tolerance=20
 */

import * as fs from 'fs';
import * as path from 'path';
import {
  getBrowserLayoutTree,
  getCraterLayoutTree,
  compareLayoutTrees,
  printDiffReport,
  saveLayoutTrees,
  findLargeDiffs,
  CompareOptions,
} from './layout_compare';

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help') {
    console.log('Layout Comparison CLI');
    console.log('');
    console.log('Usage:');
    console.log('  npx tsx test_utils/compare-layout.ts <html-file> [options]');
    console.log('');
    console.log('Options:');
    console.log('  --save           Save layout trees to JSON files');
    console.log('  --tolerance=N    Set tolerance for comparison (default: 10)');
    console.log('  --high-only      Show only high severity diffs');
    console.log('');
    return;
  }

  const htmlFile = args.find(a => !a.startsWith('--'));
  if (!htmlFile || !fs.existsSync(htmlFile)) {
    console.error(`Error: HTML file not found: ${htmlFile}`);
    process.exit(1);
  }

  // Parse options
  const saveOutput = args.includes('--save');
  const highOnly = args.includes('--high-only');
  let tolerance = 10;
  for (const arg of args) {
    if (arg.startsWith('--tolerance=')) {
      tolerance = parseInt(arg.slice(12), 10);
    }
  }

  // Read viewport from metadata
  const htmlDir = path.dirname(htmlFile);
  const metadataPath = path.join(htmlDir, 'metadata.json');
  let viewport = { width: 800, height: 600 };
  if (fs.existsSync(metadataPath)) {
    const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf-8'));
    if (metadata.viewport) {
      viewport = metadata.viewport;
    }
  }

  console.log(`Comparing layouts for: ${htmlFile}`);
  console.log(`Viewport: ${viewport.width}x${viewport.height}`);
  console.log(`Tolerance: ${tolerance}px`);
  console.log('');

  // Get browser layout
  console.log('Getting browser layout...');
  const browserLayout = await getBrowserLayoutTree(htmlFile, viewport);

  // Get Crater layout
  console.log('Getting Crater layout...');
  const craterLayout = await getCraterLayoutTree(htmlFile, viewport);

  // Save if requested
  if (saveOutput) {
    saveLayoutTrees(browserLayout, craterLayout, htmlDir);
  }

  // Compare
  const options: CompareOptions = {
    tolerance,
    skipTextNodes: true,
    skipHiddenNodes: true,
    maxDepth: 10,
  };

  console.log('Comparing layouts...');
  const diffs = compareLayoutTrees(browserLayout, craterLayout, options);

  // Filter if high-only
  const filteredDiffs = highOnly
    ? diffs.filter(d => d.severity === 'high')
    : diffs;

  // Print report
  printDiffReport(filteredDiffs);

  // Find the largest diffs for debugging
  const largeDiffs = findLargeDiffs(diffs, 100);
  if (largeDiffs.length > 0) {
    console.log('\n=== Largest Differences (for debugging) ===\n');
    for (const diff of largeDiffs.slice(0, 5)) {
      console.log(`${diff.path}`);
      console.log(`  ${diff.property}: browser=${diff.browser}, crater=${diff.crater}`);
      console.log(`  diff: ${diff.diff}px`);
      console.log('');
    }
  }

  // Exit with error if there are high severity diffs
  const highCount = diffs.filter(d => d.severity === 'high').length;
  if (highCount > 0) {
    console.log(`\nFailed: ${highCount} high severity differences found`);
    process.exit(1);
  }

  console.log('\nPassed!');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
