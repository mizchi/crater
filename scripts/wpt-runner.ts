/**
 * WPT (Web Platform Tests) Runner for Crater
 *
 * Compares CSS layout between browser (Puppeteer) and Crater
 * Uses wpt/ submodule directly
 *
 * Usage:
 *   npx tsx scripts/wpt-runner.ts css-flexbox
 *   npx tsx scripts/wpt-runner.ts wpt/css/css-flexbox/flex-001.html
 *   npx tsx scripts/wpt-runner.ts --all
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
  name: string;
  passed: boolean;
  mismatches: Mismatch[];
  totalNodes: number;
}

interface Mismatch {
  path: string;
  property: string;
  browser: number;
  crater: number;
  diff: number;
}

// Configuration
const TOLERANCE = 15;
const VIEWPORT = { width: 800, height: 600 };

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
  p { margin: 0; }
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

function findNodeById(node: LayoutNode, id: string): LayoutNode | null {
  if (node.id === id || node.id.endsWith('#' + id.replace('#', ''))) return node;
  for (const child of node.children) {
    const found = findNodeById(child, id);
    if (found) return found;
  }
  return null;
}

function findNodeByClass(node: LayoutNode, className: string): LayoutNode | null {
  if (node.id.endsWith('.' + className)) return node;
  for (const child of node.children) {
    const found = findNodeByClass(child, className);
    if (found) return found;
  }
  return null;
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

function compareLayouts(
  browser: LayoutNode,
  crater: LayoutNode,
  path: string = 'root',
  options: { ignoreTextNodes?: boolean; ignoreBoxModel?: boolean } = {}
): Mismatch[] {
  const mismatches: Mismatch[] = [];
  const bothZeroSized =
    Math.abs(browser.width) < 0.5 &&
    Math.abs(browser.height) < 0.5 &&
    Math.abs(crater.width) < 0.5 &&
    Math.abs(crater.height) < 0.5;

  const props: (keyof LayoutNode)[] = ['x', 'y', 'width', 'height'];
  for (const prop of props) {
    // display:none descendants are zero-sized; browser getBoundingClientRect() can
    // report viewport-origin coordinates for them, so x/y are not comparable.
    if (bothZeroSized && (prop === 'x' || prop === 'y')) {
      continue;
    }
    const bVal = browser[prop] as number;
    const cVal = crater[prop] as number;
    const diff = Math.abs(bVal - cVal);
    if (diff > TOLERANCE) {
      mismatches.push({ path, property: prop, browser: bVal, crater: cVal, diff });
    }
  }

  if (!options.ignoreBoxModel) {
    const boxProps: (keyof LayoutNode)[] = ['margin', 'padding', 'border'];
    for (const boxProp of boxProps) {
      const bRect = browser[boxProp] as Rect;
      const cRect = crater[boxProp] as Rect;
      for (const side of ['top', 'right', 'bottom', 'left'] as const) {
        const diff = Math.abs(bRect[side] - cRect[side]);
        if (diff > TOLERANCE) {
          mismatches.push({ path, property: `${boxProp}.${side}`, browser: bRect[side], crater: cRect[side], diff });
        }
      }
    }
  }

  const bChildren = options.ignoreTextNodes ? browser.children.filter(c => !c.id.startsWith('#text')) : browser.children;
  const cChildren = options.ignoreTextNodes ? crater.children.filter(c => !c.id.startsWith('#text')) : crater.children;

  const minChildren = Math.min(bChildren.length, cChildren.length);
  for (let i = 0; i < minChildren; i++) {
    const childPath = `${path}/${bChildren[i].id}[${i}]`;
    mismatches.push(...compareLayouts(bChildren[i], cChildren[i], childPath, options));
  }

  if (bChildren.length !== cChildren.length) {
    mismatches.push({
      path,
      property: 'children.length',
      browser: bChildren.length,
      crater: cChildren.length,
      diff: Math.abs(bChildren.length - cChildren.length),
    });
  }

  return mismatches;
}

function countNodes(node: LayoutNode): number {
  return 1 + node.children.reduce((sum, child) => sum + countNodes(child), 0);
}

async function runTest(browser: puppeteer.Browser, htmlPath: string): Promise<TestResult> {
  const name = path.basename(htmlPath);

  try {
    const browserLayout = await getBrowserLayout(browser, htmlPath);
    const craterLayout = getCraterLayout(htmlPath);
    const normalizedCraterLayout = normalizeCraterPositions(craterLayout);

    const mismatches = compareLayouts(browserLayout, normalizedCraterLayout, 'root', {
      ignoreTextNodes: true,
      ignoreBoxModel: true,
    });

    return { name, passed: mismatches.length === 0, mismatches, totalNodes: countNodes(browserLayout) };
  } catch (error) {
    return {
      name,
      passed: false,
      mismatches: [{ path: 'error', property: 'execution', browser: 0, crater: 0, diff: 0 }],
      totalNodes: 0,
    };
  }
}

function printResult(result: TestResult): void {
  const icon = result.passed ? '✓' : '✗';
  console.log(`${icon} ${result.name}`);

  if (!result.passed) {
    for (const m of result.mismatches.slice(0, 10)) {
      console.log(`    ${m.path}.${m.property}: browser=${m.browser.toFixed(1)}, crater=${m.crater.toFixed(1)} (diff=${m.diff.toFixed(1)})`);
    }
    if (result.mismatches.length > 10) {
      console.log(`    ... and ${result.mismatches.length - 10} more mismatches`);
    }
  }
}

const CONCURRENCY = 6;

async function runTestsParallel(htmlFiles: string[]): Promise<{ passed: number; failed: number; results: TestResult[] }> {
  const results: TestResult[] = [];
  let passed = 0;
  let failed = 0;
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
      if (!result.passed && result.mismatches.some(m => m.property === 'execution')) {
        try { await browser.close(); } catch {}
        browser = await puppeteer.launch({ headless: true });
        result = await runTest(browser, htmlFile);
      }

      results[index] = result;
      if (result.passed) passed++;
      else failed++;
      localCount++;

      const icon = result.passed ? '✓' : '✗';
      process.stdout.write(`\r[${results.filter(Boolean).length}/${htmlFiles.length}] ${icon} ${result.name.padEnd(50)}`);
    }

    try { await browser.close(); } catch {}
  }

  const browsers = await Promise.all(
    Array.from({ length: CONCURRENCY }, () => puppeteer.launch({ headless: true }))
  );

  await Promise.all(browsers.map(browser => worker(browser)));

  console.log('\n');

  return { passed, failed, results };
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('WPT Runner for Crater\n');
    console.log('Usage:');
    console.log('  npx tsx scripts/wpt-runner.ts <module-name>     # Run tests for a CSS module');
    console.log('  npx tsx scripts/wpt-runner.ts <path/to/test.html>');
    console.log('  npx tsx scripts/wpt-runner.ts --all             # Run all modules');
    console.log('  npx tsx scripts/wpt-runner.ts --list            # List available modules');
    console.log('\nModules:', CSS_MODULES.join(', '));
    return;
  }

  if (args[0] === '--list') {
    console.log('Available CSS modules:\n');
    for (const mod of CSS_MODULES) {
      const files = getTestFiles(mod);
      console.log(`  ${mod}: ${files.length} tests`);
    }
    return;
  }

  // Collect test files
  let htmlFiles: string[] = [];

  if (args[0] === '--all') {
    for (const mod of CSS_MODULES) {
      htmlFiles.push(...getTestFiles(mod));
    }
  } else {
    for (const arg of args) {
      if (CSS_MODULES.includes(arg)) {
        // Module name
        htmlFiles.push(...getTestFiles(arg));
      } else if (arg.includes('*')) {
        // Glob pattern
        const dir = path.dirname(arg);
        if (fs.existsSync(dir)) {
          const files = fs.readdirSync(dir)
            .filter(f => f.endsWith('.html'))
            .map(f => path.join(dir, f));
          htmlFiles.push(...files);
        }
      } else if (fs.existsSync(arg)) {
        // Direct file path
        htmlFiles.push(arg);
      }
    }
  }

  if (htmlFiles.length === 0) {
    console.error('No test files found');
    process.exit(1);
  }

  console.log(`Running ${htmlFiles.length} test(s) with ${CONCURRENCY} workers...\n`);

  const { passed, failed, results } = await runTestsParallel(htmlFiles);

  // Print failed tests details
  const failedResults = results.filter(r => r && !r.passed);
  if (failedResults.length > 0) {
    console.log('Failed tests:\n');
    for (const result of failedResults.slice(0, 20)) {
      printResult(result);
    }
    if (failedResults.length > 20) {
      console.log(`... and ${failedResults.length - 20} more failed tests\n`);
    }
  }

  console.log(`Summary: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
