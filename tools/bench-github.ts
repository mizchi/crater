#!/usr/bin/env node --experimental-strip-types
/**
 * Benchmark rendering of real GitHub profile page
 *
 * Usage:
 *   npx tsx tools/bench-github.ts
 */

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { performance } from 'node:perf_hooks';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Import crater module
let crater: any;
try {
  crater = await import(resolve(__dirname, '../js/dist/crater.js'));
} catch {
  crater = await import(resolve(__dirname, '../target/js/release/build/js/js.js'));
}

// Load fixture files
const fixturesDir = resolve(__dirname, '../bench/fixtures');

function loadFixture(name: string): string {
  return readFileSync(resolve(fixturesDir, name), 'utf-8');
}

interface BenchResult {
  name: string;
  mean: number;
  stddev: number;
  min: number;
  max: number;
  runs: number;
}

function bench(name: string, fn: () => void, warmup = 3, iterations = 10): BenchResult {
  // Warmup
  for (let i = 0; i < warmup; i++) {
    fn();
  }

  // Measure
  const times: number[] = [];
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    fn();
    const end = performance.now();
    times.push(end - start);
  }

  const mean = times.reduce((a, b) => a + b, 0) / times.length;
  const variance = times.reduce((sum, t) => sum + (t - mean) ** 2, 0) / times.length;
  const stddev = Math.sqrt(variance);

  return {
    name,
    mean,
    stddev,
    min: Math.min(...times),
    max: Math.max(...times),
    runs: iterations,
  };
}

function formatTime(ms: number): string {
  if (ms < 1) {
    return `${(ms * 1000).toFixed(2)} µs`;
  } else if (ms < 1000) {
    return `${ms.toFixed(2)} ms`;
  } else {
    return `${(ms / 1000).toFixed(2)} s`;
  }
}

function printResult(result: BenchResult) {
  console.log(`${result.name.padEnd(40)} ${formatTime(result.mean).padStart(12)} ± ${formatTime(result.stddev).padStart(10)} (${result.runs} runs)`);
}

async function main() {
  console.log('Loading fixtures...');

  // Load HTML
  const html = loadFixture('github_mizchi.html');
  console.log(`  HTML: ${(html.length / 1024).toFixed(1)} KB`);

  // Load CSS files
  const cssPrimer = loadFixture('github_primer.css');
  const cssGlobal = loadFixture('github_global.css');
  const cssMain = loadFixture('github_main.css');
  const cssProfile = loadFixture('github_profile.css');

  console.log(`  CSS Primer: ${(cssPrimer.length / 1024).toFixed(1)} KB`);
  console.log(`  CSS Global: ${(cssGlobal.length / 1024).toFixed(1)} KB`);
  console.log(`  CSS Main: ${(cssMain.length / 1024).toFixed(1)} KB`);
  console.log(`  CSS Profile: ${(cssProfile.length / 1024).toFixed(1)} KB`);

  const totalCss = cssPrimer + cssGlobal + cssMain + cssProfile;
  console.log(`  CSS Total: ${(totalCss.length / 1024).toFixed(1)} KB`);

  // Create HTML with embedded CSS for realistic test
  const htmlWithCss = `<!DOCTYPE html>
<html>
<head>
<style>${cssProfile}</style>
</head>
${html.substring(html.indexOf('<body'))}`;

  const htmlWithAllCss = `<!DOCTYPE html>
<html>
<head>
<style>${cssPrimer}</style>
<style>${cssGlobal}</style>
<style>${cssMain}</style>
<style>${cssProfile}</style>
</head>
${html.substring(html.indexOf('<body'))}`;

  console.log('\n' + '='.repeat(80));
  console.log('Benchmarks');
  console.log('='.repeat(80));

  const WIDTH = 1200;
  const HEIGHT = 800;

  // Benchmark 1: HTML only (no external CSS)
  console.log('\n1. HTML Only (inline styles only):');
  const r1 = bench('render_github_html_only', () => {
    crater.renderHtmlToJson(html, WIDTH, HEIGHT);
  }, 2, 5);
  printResult(r1);

  // Benchmark 2: HTML + Profile CSS only (12KB, ~100 rules)
  console.log('\n2. HTML + Profile CSS (~12KB, ~100 rules):');
  const r2 = bench('render_github_profile_css', () => {
    crater.renderHtmlToJson(htmlWithCss, WIDTH, HEIGHT);
  }, 2, 5);
  printResult(r2);

  // Benchmark 3: HTML + All CSS (~830KB, ~7800 rules) - if parsable
  console.log('\n3. HTML + All CSS (~830KB, ~7800 rules):');
  let r3: BenchResult | null = null;
  try {
    r3 = bench('render_github_all_css', () => {
      crater.renderHtmlToJson(htmlWithAllCss, WIDTH, HEIGHT);
    }, 1, 3);
    printResult(r3);
  } catch (e) {
    console.log('  Skipped (CSS too large or parse error):', (e as Error).message?.substring(0, 100));
  }

  // Benchmark 4: Compare with simple benchmark pattern
  console.log('\n4. Reference: Simple 100-element flat list (inline styles):');
  const simpleHtml = generateSimpleFlat(100);
  const r4 = bench('render_simple_flat_100', () => {
    crater.renderHtmlToJson(simpleHtml, WIDTH, HEIGHT);
  }, 3, 10);
  printResult(r4);

  // Benchmark 5: Medium CSS (50-100 rules)
  console.log('\n5. Medium CSS test (50 classes, repeated):');
  const mediumCss = generateMediumCss(50);
  const mediumHtml = generateHtmlWithClasses(100, 50);
  const r5 = bench('render_medium_css_100elem', () => {
    crater.renderHtmlToJson(mediumCss + mediumHtml, WIDTH, HEIGHT);
  }, 3, 5);
  printResult(r5);

  // Summary
  console.log('\n' + '='.repeat(80));
  console.log('Summary');
  console.log('='.repeat(80));
  console.log(`\nGitHub profile rendering:`);
  console.log(`  - HTML only: ${formatTime(r1.mean)}`);
  console.log(`  - + Profile CSS (100 rules): ${formatTime(r2.mean)}`);
  console.log(`  - + All CSS (7800 rules): ${r3 ? formatTime((r3 as any)?.mean || 0) : 'N/A'}`);
  console.log(`\nComparison to simple 100-element list: ${(r2.mean / r4.mean).toFixed(1)}x slower`);

  if ((r3 as any)?.mean) {
    console.log(`\nCSS scaling:`);
    console.log(`  - 100 rules → 7800 rules: ${((r3 as any).mean / r2.mean).toFixed(1)}x slowdown`);
    console.log(`  - Without indexing, this would be ~78x slowdown (linear scaling)`);
    console.log(`  - Selector index optimization: ~${(78 / ((r3 as any).mean / r2.mean)).toFixed(0)}x faster`);
  }
}

function generateMediumCss(numClasses: number): string {
  let css = '<!DOCTYPE html><html><head><style>';
  for (let i = 0; i < numClasses; i++) {
    css += `.class-${i} { padding: ${i % 20}px; margin: ${i % 10}px; background: #${(i * 1000 + 100000).toString(16).slice(0, 6)}; }\n`;
  }
  css += '</style></head>';
  return css;
}

function generateHtmlWithClasses(numElements: number, numClasses: number): string {
  let html = '<body>';
  for (let i = 0; i < numElements; i++) {
    const classes = `class-${i % numClasses} class-${(i + 10) % numClasses}`;
    html += `<div class="${classes}">Item ${i}</div>`;
  }
  html += '</body></html>';
  return html;
}

function generateSimpleFlat(n: number): string {
  let html = '<!DOCTYPE html><html><body style="margin:0">';
  for (let i = 0; i < n; i++) {
    html += `<div style="height:20px;background:#${i % 2 === 0 ? 'eee' : 'ddd'}">Item ${i}</div>`;
  }
  html += '</body></html>';
  return html;
}

main().catch(console.error);
