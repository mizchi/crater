/**
 * Safe Subset Analyzer for Crater
 *
 * Analyzes WPT test results to determine which CSS properties
 * are safely implemented (matching browser behavior).
 *
 * Usage:
 *   npx tsx scripts/analyze-safe-subset.ts           # Run tests and analyze
 *   npx tsx scripts/analyze-safe-subset.ts --cached  # Use cached results
 *   npx tsx scripts/analyze-safe-subset.ts --failed  # List failed tests from cache
 *   npx tsx scripts/analyze-safe-subset.ts --failed --cache results.json  # Use specific cache file
 *   npx tsx scripts/analyze-safe-subset.ts --diff <old.json> <new.json>   # Compare two results
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { renderer } from '../wasm/dist/crater.js';

// Load config from wpt.json
const wptConfig = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'wpt.json'), 'utf-8'));
const CSS_MODULES: string[] = wptConfig.modules;
const INCLUDE_PREFIXES: string[] = wptConfig.includePrefixes;

const WPT_DIR = 'wpt/css';
const CACHE_FILE = '.wpt-safe-subset-cache.json';

// Types
interface Rect {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

interface LayoutNode {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  margin: Rect;
  padding: Rect;
  border: Rect;
  children: LayoutNode[];
}

interface TestResult {
  file: string;
  passed: boolean;
  cssProperties: Record<string, string[]>; // property -> values used
}

interface PropertyStats {
  property: string;
  totalTests: number;
  passedTests: number;
  passRate: number;
  values: Record<string, { total: number; passed: number; rate: number }>;
}

// Configuration
const TOLERANCE = 15;
const VIEWPORT = { width: 800, height: 600 };
const CONCURRENCY = 6;

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
</style>
`;

/**
 * Check if a file is a layout test
 */
function isLayoutTest(filename: string): boolean {
  if (!filename.endsWith('.html')) return false;
  if (filename.endsWith('-ref.html')) return false;
  if (filename.includes('support')) return false;
  if (filename.startsWith('reference')) return false;
  return INCLUDE_PREFIXES.some(prefix => filename.startsWith(prefix));
}

/**
 * Get test files for a module
 */
function getTestFiles(moduleName: string): string[] {
  const moduleDir = path.join(WPT_DIR, moduleName);
  if (!fs.existsSync(moduleDir)) {
    return [];
  }
  return fs.readdirSync(moduleDir)
    .filter(isLayoutTest)
    .map(f => path.join(moduleDir, f));
}

/**
 * Inline external CSS files into HTML
 */
function inlineExternalCSS(html: string, htmlPath: string): string {
  const htmlDir = path.dirname(htmlPath);
  const linkRegex = /<link\s+[^>]*rel\s*=\s*["']stylesheet["'][^>]*>/gi;

  return html.replace(linkRegex, (match) => {
    const hrefMatch = match.match(/href\s*=\s*["']([^"']+)["']/i);
    if (!hrefMatch) return match;

    const href = hrefMatch[1];
    if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('//')) {
      return match;
    }

    const cssPath = path.resolve(htmlDir, href);
    try {
      if (fs.existsSync(cssPath)) {
        const cssContent = fs.readFileSync(cssPath, 'utf-8');
        return `<style>/* Inlined from ${href} */\n${cssContent}</style>`;
      }
    } catch {}
    return `<!-- CSS not found: ${href} -->`;
  });
}

/**
 * Remove CSS comments from a string
 */
function removeCssComments(css: string): string {
  return css.replace(/\/\*[\s\S]*?\*\//g, '');
}

/**
 * Extract CSS properties from HTML content
 */
function extractCssProperties(html: string): Record<string, string[]> {
  const properties: Record<string, string[]> = {};

  // Extract from style attributes
  const styleAttrRegex = /style\s*=\s*["']([^"']+)["']/gi;
  let match;
  while ((match = styleAttrRegex.exec(html)) !== null) {
    const cleaned = removeCssComments(match[1]);
    parseStyleDeclarations(cleaned, properties);
  }

  // Extract from <style> tags
  const styleTagRegex = /<style[^>]*>([\s\S]*?)<\/style>/gi;
  while ((match = styleTagRegex.exec(html)) !== null) {
    // Remove comments first
    const cssContent = removeCssComments(match[1]);
    const declRegex = /\{([^}]+)\}/g;
    let declMatch;
    while ((declMatch = declRegex.exec(cssContent)) !== null) {
      parseStyleDeclarations(declMatch[1], properties);
    }
  }

  return properties;
}

/**
 * Check if a string is a valid CSS property name
 */
function isValidCssProperty(property: string): boolean {
  // CSS property names: start with letter or hyphen, contain only letters, numbers, hyphens
  // Also allow CSS custom properties (--*)
  return /^-?[a-z][a-z0-9-]*$/i.test(property) || /^--[a-z][a-z0-9-]*$/i.test(property);
}

/**
 * Parse CSS declarations string into property -> values map
 */
function parseStyleDeclarations(declarations: string, properties: Record<string, string[]>): void {
  const declPairs = declarations.split(';');
  for (const pair of declPairs) {
    const colonIndex = pair.indexOf(':');
    if (colonIndex === -1) continue;

    const property = pair.slice(0, colonIndex).trim().toLowerCase();
    const value = pair.slice(colonIndex + 1).trim().toLowerCase();

    if (!property || !value) continue;

    // Skip invalid property names (might contain leftover comment fragments)
    if (!isValidCssProperty(property)) continue;

    // Skip CSS custom properties for cleaner analysis
    if (property.startsWith('--')) continue;

    if (!properties[property]) {
      properties[property] = [];
    }
    if (!properties[property].includes(value)) {
      properties[property].push(value);
    }
  }
}

function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  htmlContent = inlineExternalCSS(htmlContent, htmlPath);
  htmlContent = htmlContent.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');

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
 * Extract layout tree from browser using Puppeteer
 */
async function getBrowserLayout(browser: puppeteer.Browser, htmlPath: string): Promise<LayoutNode> {
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);
  page.on('pageerror', () => {});
  page.setDefaultTimeout(5000);

  const htmlContent = prepareHtmlContent(htmlPath);
  await page.setContent(htmlContent, { waitUntil: 'domcontentloaded', timeout: 5000 });

  const layout = await page.evaluate(`(() => {
    function getComputedRect(el, prop) {
      const style = getComputedStyle(el);
      if (prop === 'border') {
        return {
          top: parseFloat(style.borderTopWidth) || 0,
          right: parseFloat(style.borderRightWidth) || 0,
          bottom: parseFloat(style.borderBottomWidth) || 0,
          left: parseFloat(style.borderLeftWidth) || 0,
        };
      }
      return {
        top: parseFloat(style[prop + 'Top']) || 0,
        right: parseFloat(style[prop + 'Right']) || 0,
        bottom: parseFloat(style[prop + 'Bottom']) || 0,
        left: parseFloat(style[prop + 'Left']) || 0,
      };
    }

    function getNodeId(el) {
      if (el.id) return el.tagName.toLowerCase() + '#' + el.id;
      if (el.className && typeof el.className === 'string') {
        const firstClass = el.className.split(' ')[0];
        if (firstClass) return el.tagName.toLowerCase() + '.' + firstClass;
      }
      return el.tagName.toLowerCase();
    }

    function extractLayout(el, parentRect) {
      const rect = el.getBoundingClientRect();
      const padding = getComputedRect(el, 'padding');
      const border = getComputedRect(el, 'border');
      const children = [];

      for (const child of el.children) {
        if (['SCRIPT', 'STYLE', 'LINK', 'META', 'TITLE', 'HEAD'].includes(child.tagName)) continue;
        children.push(extractLayout(child, rect));
      }

      let x = rect.left;
      let y = rect.top;
      if (parentRect) {
        const parentPadding = el.parentElement ? getComputedRect(el.parentElement, 'padding') : { top: 0, left: 0, right: 0, bottom: 0 };
        const parentBorder = el.parentElement ? getComputedRect(el.parentElement, 'border') : { top: 0, left: 0, right: 0, bottom: 0 };
        x = rect.left - parentRect.left - parentBorder.left - parentPadding.left;
        y = rect.top - parentRect.top - parentBorder.top - parentPadding.top;
      }

      return {
        id: getNodeId(el),
        x: x,
        y: y,
        width: rect.width,
        height: rect.height,
        margin: getComputedRect(el, 'margin'),
        padding: padding,
        border: border,
        children: children,
        top: 0, right: 0, bottom: 0, left: 0
      };
    }

    const body = document.body;
    function normalizeRoot(layout) {
      return Object.assign({}, layout, { x: 0, y: 0 });
    }

    const testElement = document.getElementById('test') || document.getElementById('container');
    if (testElement) {
      return normalizeRoot(extractLayout(testElement));
    }

    const gridElement = document.querySelector('.grid');
    if (gridElement) {
      return normalizeRoot(extractLayout(gridElement));
    }

    const children = Array.from(body.children).filter(
      el => !['SCRIPT', 'STYLE', 'LINK', 'META', 'P'].includes(el.tagName) && el.id !== 'log'
    );
    if (children.length === 1) {
      return normalizeRoot(extractLayout(children[0]));
    }

    const divChildren = children.filter(el => el.tagName === 'DIV');
    if (divChildren.length >= 1) {
      return normalizeRoot(extractLayout(divChildren[0]));
    }

    return normalizeRoot(extractLayout(body));
  })()`);

  await page.close();
  return layout as LayoutNode;
}

function getCraterLayout(htmlPath: string): LayoutNode {
  function normalizeRoot(node: LayoutNode): LayoutNode {
    return { ...node, x: 0, y: 0 };
  }

  const htmlContent = prepareHtmlContent(htmlPath);
  const result = renderer.renderHtmlToJson(htmlContent, 800, 600);
  let layout = JSON.parse(result) as LayoutNode;

  if (layout.id === 'body' && layout.children.length === 1 && layout.children[0].id === 'body') {
    layout = layout.children[0];
  }

  const findNodeById = (node: LayoutNode, id: string): LayoutNode | null => {
    if (node.id === id || node.id.endsWith('#' + id.replace('#', ''))) return node;
    for (const child of node.children) {
      const found = findNodeById(child, id);
      if (found) return found;
    }
    return null;
  };

  const findNodeByClass = (node: LayoutNode, className: string): LayoutNode | null => {
    if (node.id.endsWith('.' + className)) return node;
    for (const child of node.children) {
      const found = findNodeByClass(child, className);
      if (found) return found;
    }
    return null;
  };

  const testElement = findNodeById(layout, 'div#test') || findNodeById(layout, '#test') ||
    findNodeById(layout, 'div#container') || findNodeById(layout, '#container');
  if (testElement) return normalizeRoot(testElement);

  const gridElement = findNodeByClass(layout, 'grid');
  if (gridElement) return normalizeRoot(gridElement);

  const meaningfulChildren = layout.children.filter(
    c => !c.id.startsWith('#text') && c.id !== 'p' && c.id !== 'div#log'
  );
  if (meaningfulChildren.length === 1) return normalizeRoot(meaningfulChildren[0]);

  const divChildren = meaningfulChildren.filter(c => c.id.startsWith('div') && c.id !== 'div#log');
  if (divChildren.length >= 1) return normalizeRoot(divChildren[0]);

  return normalizeRoot(layout);
}

function normalizeCraterPositions(node: LayoutNode): LayoutNode {
  const contentOffsetX = node.padding.left + node.border.left;
  const contentOffsetY = node.padding.top + node.border.top;

  return {
    ...node,
    children: node.children.map(child => {
      const adjustedChild = {
        ...child,
        x: child.x - contentOffsetX,
        y: child.y - contentOffsetY,
      };
      return normalizeCraterPositions(adjustedChild);
    }),
  };
}

function compareLayouts(browser: LayoutNode, crater: LayoutNode): boolean {
  const props: (keyof LayoutNode)[] = ['x', 'y', 'width', 'height'];
  for (const prop of props) {
    const bVal = browser[prop] as number;
    const cVal = crater[prop] as number;
    const diff = Math.abs(bVal - cVal);
    if (diff > TOLERANCE) return false;
  }

  const bChildren = browser.children.filter(c => !c.id.startsWith('#text'));
  const cChildren = crater.children.filter(c => !c.id.startsWith('#text'));

  if (bChildren.length !== cChildren.length) return false;

  for (let i = 0; i < bChildren.length; i++) {
    if (!compareLayouts(bChildren[i], cChildren[i])) return false;
  }

  return true;
}

async function runTest(browser: puppeteer.Browser, htmlPath: string): Promise<TestResult> {
  const rawHtml = fs.readFileSync(htmlPath, 'utf-8');
  const cssProperties = extractCssProperties(rawHtml);

  try {
    const browserLayout = await getBrowserLayout(browser, htmlPath);
    const craterLayout = getCraterLayout(htmlPath);
    const normalizedCraterLayout = normalizeCraterPositions(craterLayout);

    const passed = compareLayouts(browserLayout, normalizedCraterLayout);

    return { file: htmlPath, passed, cssProperties };
  } catch {
    return { file: htmlPath, passed: false, cssProperties };
  }
}

async function runTestsParallel(htmlFiles: string[]): Promise<TestResult[]> {
  const results: TestResult[] = [];
  let nextIndex = 0;

  async function worker(browser: puppeteer.Browser): Promise<void> {
    let localCount = 0;
    const RESTART_INTERVAL = 30;

    while (true) {
      const index = nextIndex++;
      if (index >= htmlFiles.length) break;

      const htmlFile = htmlFiles[index];

      if (localCount > 0 && localCount % RESTART_INTERVAL === 0) {
        try { await browser.close(); } catch {}
        browser = await puppeteer.launch({ headless: true });
      }

      let result = await runTest(browser, htmlFile);
      if (!result.passed) {
        // Retry once on failure
        try { await browser.close(); } catch {}
        browser = await puppeteer.launch({ headless: true });
        result = await runTest(browser, htmlFile);
      }

      results[index] = result;
      localCount++;

      const icon = result.passed ? '✓' : '✗';
      const count = results.filter(Boolean).length;
      process.stdout.write(`\r[${count}/${htmlFiles.length}] ${icon} ${path.basename(htmlFile).padEnd(50)}`);
    }

    try { await browser.close(); } catch {}
  }

  const browsers = await Promise.all(
    Array.from({ length: CONCURRENCY }, () => puppeteer.launch({ headless: true }))
  );

  await Promise.all(browsers.map(browser => worker(browser)));

  console.log('\n');

  return results;
}

/**
 * Aggregate results into property statistics
 */
function aggregateStats(results: TestResult[]): PropertyStats[] {
  const propertyData: Record<string, {
    total: number;
    passed: number;
    values: Record<string, { total: number; passed: number }>;
  }> = {};

  for (const result of results) {
    for (const [property, values] of Object.entries(result.cssProperties)) {
      if (!propertyData[property]) {
        propertyData[property] = { total: 0, passed: 0, values: {} };
      }

      propertyData[property].total++;
      if (result.passed) {
        propertyData[property].passed++;
      }

      for (const value of values) {
        // Normalize value (remove units for length values)
        const normalizedValue = normalizeValue(property, value);

        if (!propertyData[property].values[normalizedValue]) {
          propertyData[property].values[normalizedValue] = { total: 0, passed: 0 };
        }
        propertyData[property].values[normalizedValue].total++;
        if (result.passed) {
          propertyData[property].values[normalizedValue].passed++;
        }
      }
    }
  }

  // Convert to stats array
  const stats: PropertyStats[] = [];
  for (const [property, data] of Object.entries(propertyData)) {
    const values: Record<string, { total: number; passed: number; rate: number }> = {};
    for (const [value, vdata] of Object.entries(data.values)) {
      values[value] = {
        total: vdata.total,
        passed: vdata.passed,
        rate: vdata.passed / vdata.total,
      };
    }

    stats.push({
      property,
      totalTests: data.total,
      passedTests: data.passed,
      passRate: data.passed / data.total,
      values,
    });
  }

  // Sort by pass rate descending
  stats.sort((a, b) => b.passRate - a.passRate);

  return stats;
}

/**
 * Normalize CSS values for aggregation
 */
function normalizeValue(property: string, value: string): string {
  // For length values, categorize as <length>, <percentage>, etc.
  if (/^-?\d+(\.\d+)?(px|em|rem|%|vh|vw)?$/.test(value)) {
    if (value.endsWith('%')) return '<percentage>';
    if (/^-?\d+(\.\d+)?px$/.test(value)) return '<length>';
    if (/^-?\d+(\.\d+)?$/.test(value)) return '<number>';
    return '<dimension>';
  }

  // Keep keywords as-is
  return value;
}

/**
 * Generate Safe Subset report
 */
function generateReport(stats: PropertyStats[]): string {
  const lines: string[] = [];

  lines.push('# CSS Safe Subset Report');
  lines.push('');
  lines.push('Properties with high browser compatibility (>= 70% pass rate).');
  lines.push('');
  lines.push('## Tier 1: Safe (>= 80% pass rate)');
  lines.push('');

  const tier1 = stats.filter(s => s.passRate >= 0.8 && s.totalTests >= 3);
  for (const stat of tier1) {
    lines.push(`### ${stat.property}`);
    lines.push(`Pass rate: ${(stat.passRate * 100).toFixed(1)}% (${stat.passedTests}/${stat.totalTests})`);
    lines.push('');
    lines.push('Safe values:');
    const safeValues = Object.entries(stat.values)
      .filter(([_, v]) => v.rate >= 0.8 && v.total >= 2)
      .sort((a, b) => b[1].rate - a[1].rate);
    for (const [value, vdata] of safeValues) {
      lines.push(`  - \`${value}\`: ${(vdata.rate * 100).toFixed(0)}% (${vdata.passed}/${vdata.total})`);
    }
    lines.push('');
  }

  lines.push('## Tier 2: Caution (60-80% pass rate)');
  lines.push('');

  const tier2 = stats.filter(s => s.passRate >= 0.6 && s.passRate < 0.8 && s.totalTests >= 3);
  for (const stat of tier2) {
    lines.push(`### ${stat.property}`);
    lines.push(`Pass rate: ${(stat.passRate * 100).toFixed(1)}% (${stat.passedTests}/${stat.totalTests})`);
    lines.push('');
  }

  lines.push('## Tier 3: Experimental (< 60% pass rate)');
  lines.push('');

  const tier3 = stats.filter(s => s.passRate < 0.6 && s.totalTests >= 3);
  for (const stat of tier3.slice(0, 20)) {
    lines.push(`- ${stat.property}: ${(stat.passRate * 100).toFixed(1)}% (${stat.passedTests}/${stat.totalTests})`);
  }
  if (tier3.length > 20) {
    lines.push(`- ... and ${tier3.length - 20} more`);
  }

  lines.push('');
  lines.push('## Summary');
  lines.push('');
  lines.push(`Total properties analyzed: ${stats.length}`);
  lines.push(`Tier 1 (Safe): ${tier1.length} properties`);
  lines.push(`Tier 2 (Caution): ${tier2.length} properties`);
  lines.push(`Tier 3 (Experimental): ${tier3.length} properties`);

  return lines.join('\n');
}

/**
 * Generate JSON schema for Safe Subset
 */
function generateSchema(stats: PropertyStats[]): object {
  const safeProperties: Record<string, { values: string[]; passRate: number }> = {};

  for (const stat of stats) {
    if (stat.passRate >= 0.7 && stat.totalTests >= 3) {
      const safeValues = Object.entries(stat.values)
        .filter(([_, v]) => v.rate >= 0.7 && v.total >= 2)
        .map(([value]) => value);

      if (safeValues.length > 0) {
        safeProperties[stat.property] = {
          values: safeValues,
          passRate: stat.passRate,
        };
      }
    }
  }

  return {
    version: '1.0.0',
    generated: new Date().toISOString(),
    threshold: 0.7,
    properties: safeProperties,
  };
}

/**
 * Print failed tests list
 */
function printFailedTests(results: TestResult[]): void {
  const failed = results.filter(r => !r.passed);

  console.log(`\n=== Failed Tests (${failed.length}/${results.length}) ===\n`);

  // Group by module
  const byModule: Record<string, string[]> = {};
  for (const result of failed) {
    const parts = result.file.split('/');
    const module = parts[2] || 'unknown'; // wpt/css/<module>/...
    if (!byModule[module]) {
      byModule[module] = [];
    }
    byModule[module].push(path.basename(result.file));
  }

  // Print by module
  for (const [module, files] of Object.entries(byModule).sort()) {
    console.log(`[${module}] (${files.length} failures)`);
    for (const file of files.sort()) {
      console.log(`  - ${file}`);
    }
    console.log('');
  }

  console.log(`Total: ${failed.length} failed tests`);
}

/**
 * Compare two result files and show improvements/regressions
 */
function compareDiffs(oldFile: string, newFile: string): void {
  if (!fs.existsSync(oldFile)) {
    console.error(`Old file not found: ${oldFile}`);
    process.exit(1);
  }
  if (!fs.existsSync(newFile)) {
    console.error(`New file not found: ${newFile}`);
    process.exit(1);
  }

  const oldResults: TestResult[] = JSON.parse(fs.readFileSync(oldFile, 'utf-8'));
  const newResults: TestResult[] = JSON.parse(fs.readFileSync(newFile, 'utf-8'));

  // Create maps for quick lookup
  const oldMap = new Map<string, boolean>();
  for (const r of oldResults) {
    oldMap.set(r.file, r.passed);
  }
  const newMap = new Map<string, boolean>();
  for (const r of newResults) {
    newMap.set(r.file, r.passed);
  }

  // Find improvements (was fail, now pass)
  const improvements: string[] = [];
  // Find regressions (was pass, now fail)
  const regressions: string[] = [];
  // Find new tests
  const newTests: string[] = [];
  // Find removed tests
  const removedTests: string[] = [];

  for (const r of newResults) {
    const oldPassed = oldMap.get(r.file);
    if (oldPassed === undefined) {
      newTests.push(r.file);
    } else if (!oldPassed && r.passed) {
      improvements.push(r.file);
    } else if (oldPassed && !r.passed) {
      regressions.push(r.file);
    }
  }

  for (const r of oldResults) {
    if (!newMap.has(r.file)) {
      removedTests.push(r.file);
    }
  }

  // Stats
  const oldPassed = oldResults.filter(r => r.passed).length;
  const newPassed = newResults.filter(r => r.passed).length;

  console.log('\n=== Diff Comparison ===\n');
  console.log(`Old: ${oldPassed}/${oldResults.length} passed (${(oldPassed / oldResults.length * 100).toFixed(1)}%)`);
  console.log(`New: ${newPassed}/${newResults.length} passed (${(newPassed / newResults.length * 100).toFixed(1)}%)`);

  const delta = newPassed - oldPassed;
  const deltaStr = delta >= 0 ? `+${delta}` : `${delta}`;
  console.log(`Delta: ${deltaStr} tests\n`);

  if (improvements.length > 0) {
    console.log(`✓ Improvements (${improvements.length}):`);
    for (const file of improvements.sort()) {
      console.log(`  + ${path.basename(file)}`);
    }
    console.log('');
  }

  if (regressions.length > 0) {
    console.log(`✗ Regressions (${regressions.length}):`);
    for (const file of regressions.sort()) {
      console.log(`  - ${path.basename(file)}`);
    }
    console.log('');
  }

  if (newTests.length > 0) {
    console.log(`? New tests (${newTests.length}):`);
    for (const file of newTests.sort().slice(0, 10)) {
      console.log(`  + ${path.basename(file)}`);
    }
    if (newTests.length > 10) {
      console.log(`  ... and ${newTests.length - 10} more`);
    }
    console.log('');
  }

  if (removedTests.length > 0) {
    console.log(`- Removed tests (${removedTests.length}):`);
    for (const file of removedTests.sort().slice(0, 10)) {
      console.log(`  - ${path.basename(file)}`);
    }
    if (removedTests.length > 10) {
      console.log(`  ... and ${removedTests.length - 10} more`);
    }
    console.log('');
  }

  // Summary
  if (regressions.length === 0 && improvements.length > 0) {
    console.log('🎉 No regressions! Pure improvement.');
  } else if (regressions.length > 0 && improvements.length === 0) {
    console.log('⚠️  Regressions detected with no improvements.');
  } else if (regressions.length === 0 && improvements.length === 0) {
    console.log('→ No changes in test results.');
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  // Handle --diff mode
  const diffIndex = args.indexOf('--diff');
  if (diffIndex !== -1) {
    const oldFile = args[diffIndex + 1];
    const newFile = args[diffIndex + 2];
    if (!oldFile || !newFile) {
      console.error('Usage: --diff <old.json> <new.json>');
      process.exit(1);
    }
    compareDiffs(oldFile, newFile);
    return;
  }

  // Handle --failed mode (cache only, quick list)
  if (args.includes('--failed')) {
    const cacheFile = args.includes('--cache') ?
      args[args.indexOf('--cache') + 1] : CACHE_FILE;
    if (!fs.existsSync(cacheFile)) {
      console.error(`Cache file not found: ${cacheFile}`);
      console.error('Run without --failed first to generate cache.');
      process.exit(1);
    }
    const results: TestResult[] = JSON.parse(fs.readFileSync(cacheFile, 'utf-8'));
    printFailedTests(results);
    return;
  }

  const useCached = args.includes('--cached');

  let results: TestResult[];

  if (useCached && fs.existsSync(CACHE_FILE)) {
    console.log('Loading cached results...');
    results = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf-8'));
  } else {
    // Collect all test files
    let htmlFiles: string[] = [];
    for (const mod of CSS_MODULES) {
      htmlFiles.push(...getTestFiles(mod));
    }

    console.log(`Running ${htmlFiles.length} tests with ${CONCURRENCY} workers...\n`);

    results = await runTestsParallel(htmlFiles);

    // Cache results
    fs.writeFileSync(CACHE_FILE, JSON.stringify(results, null, 2));
    console.log(`Cached results to ${CACHE_FILE}`);
  }

  // Aggregate statistics
  const stats = aggregateStats(results);

  // Generate report
  const report = generateReport(stats);
  fs.writeFileSync('docs/safe-subset-report.md', report);
  console.log('Generated docs/safe-subset-report.md');

  // Generate JSON schema
  const schema = generateSchema(stats);
  fs.writeFileSync('safe-subset.json', JSON.stringify(schema, null, 2));
  console.log('Generated safe-subset.json');

  // Print summary
  const passed = results.filter(r => r.passed).length;
  const total = results.length;
  console.log(`\nSummary: ${passed}/${total} tests passed (${(passed / total * 100).toFixed(1)}%)`);
}

main().catch(console.error);
