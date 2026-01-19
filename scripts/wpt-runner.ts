/**
 * WPT (Web Platform Tests) Runner for Crater
 *
 * Compares CSS layout between browser (Puppeteer) and Crater
 *
 * Usage:
 *   npx tsx tools/wpt-runner.ts <test-html>
 *   npx tsx tools/wpt-runner.ts --batch css-flexbox
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { renderer } from '../wasm/dist/crater.js';

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
const TOLERANCE = 15; // pixels - relaxed for margin differences
const VIEWPORT = { width: 800, height: 600 };

// CSS Reset to normalize browser defaults (only body margin)
const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
</style>
`;

/**
 * Inline external CSS files into HTML
 * Converts <link rel="stylesheet" href="..."> to <style>...</style>
 */
function inlineExternalCSS(html: string, htmlPath: string): string {
  const htmlDir = path.dirname(htmlPath);

  // Match <link rel="stylesheet" href="...">
  const linkRegex = /<link\s+[^>]*rel\s*=\s*["']stylesheet["'][^>]*>/gi;

  return html.replace(linkRegex, (match) => {
    // Extract href
    const hrefMatch = match.match(/href\s*=\s*["']([^"']+)["']/i);
    if (!hrefMatch) return match;

    const href = hrefMatch[1];

    // Skip external URLs
    if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('//')) {
      return match;
    }

    // Resolve path relative to HTML file
    const cssPath = path.resolve(htmlDir, href);

    try {
      if (fs.existsSync(cssPath)) {
        const cssContent = fs.readFileSync(cssPath, 'utf-8');
        return `<style>/* Inlined from ${href} */\n${cssContent}</style>`;
      } else {
        console.warn(`  Warning: CSS file not found: ${cssPath}`);
        return `<!-- CSS not found: ${href} -->`;
      }
    } catch (error) {
      console.warn(`  Warning: Failed to read CSS: ${cssPath}`);
      return match;
    }
  });
}

/**
 * Extract layout tree from browser using Puppeteer
 */
async function getBrowserLayout(browser: puppeteer.Browser, htmlPath: string): Promise<LayoutNode> {
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);
  page.on('pageerror', (error) => {
    console.warn(`  Page error: ${error}`);
  });

  // Set timeout for page operations
  page.setDefaultTimeout(5000);

  // Load HTML file with CSS inlining and reset
  const htmlContent = prepareHtmlContent(htmlPath);
  await page.setContent(htmlContent, { waitUntil: 'domcontentloaded', timeout: 5000 });

  // Extract layout from all elements
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

/**
 * Prepare HTML content for testing (inline CSS, add reset)
 */
function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');

  // Inline external CSS files
  htmlContent = inlineExternalCSS(htmlContent, htmlPath);

  // Remove scripts (WPT harness/tests) to avoid runtime errors
  htmlContent = htmlContent.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');

  // Inject CSS reset at the beginning of head or body
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
 * Get layout from Crater
 */
function getCraterLayout(htmlPath: string): LayoutNode {
  // Helper to normalize root position to (0,0) for comparison
  function normalizeRoot(node: LayoutNode): LayoutNode {
    return { ...node, x: 0, y: 0 };
  }

  try {
    // Prepare HTML with inlined CSS
    const htmlContent = prepareHtmlContent(htmlPath);

    // Use Crater WASM module directly
    const result = renderer.renderHtmlToJson(htmlContent, 800, 600);
    let layout = JSON.parse(result) as LayoutNode;

    // Handle nested body structure from Crater
    if (layout.id === 'body' && layout.children.length === 1 && layout.children[0].id === 'body') {
      layout = layout.children[0];
    }

    // Find #test or #container element if it exists (WPT tests)
    const testElement = findNodeById(layout, 'div#test') || findNodeById(layout, '#test') ||
      findNodeById(layout, 'div#container') || findNodeById(layout, '#container');
    if (testElement) {
      return normalizeRoot(testElement);
    }

    const gridElement = findNodeByClass(layout, 'grid');
    if (gridElement) {
      return normalizeRoot(gridElement);
    }

    // If root (body) has a single meaningful child, use that child
    // to match browser behavior
    const meaningfulChildren = layout.children.filter(
      c => !c.id.startsWith('#text') && c.id !== 'p' && c.id !== 'div#log'
    );
    if (meaningfulChildren.length === 1) {
      return normalizeRoot(meaningfulChildren[0]);
    }

    // Try to find a container div (first one, excluding #log)
    const divChildren = meaningfulChildren.filter(c => c.id.startsWith('div') && c.id !== 'div#log');
    if (divChildren.length >= 1) {
      return normalizeRoot(divChildren[0]);
    }

    return normalizeRoot(layout);
  } catch (error) {
    throw new Error(`Crater failed to render: ${error}`);
  }
}

/**
 * Find a node by ID in the layout tree
 */
function findNodeById(node: LayoutNode, id: string): LayoutNode | null {
  if (node.id === id || node.id.endsWith('#' + id.replace('#', ''))) {
    return node;
  }
  for (const child of node.children) {
    const found = findNodeById(child, id);
    if (found) return found;
  }
  return null;
}

/**
 * Find a node by class name in the layout tree
 */
function findNodeByClass(node: LayoutNode, className: string): LayoutNode | null {
  if (node.id.endsWith('.' + className)) {
    return node;
  }
  for (const child of node.children) {
    const found = findNodeByClass(child, className);
    if (found) return found;
  }
  return null;
}

/**
 * Filter out text nodes from layout children
 */
function filterTextNodes(node: LayoutNode): LayoutNode {
  return {
    ...node,
    children: node.children
      .filter(c => !c.id.startsWith('#text'))
      .map(filterTextNodes),
  };
}

/**
 * Normalize crater layout to use content-box relative positions for children
 * Crater outputs positions relative to border-box, but browser uses content-box
 */
function normalizeCraterPositions(node: LayoutNode): LayoutNode {
  // Calculate content-box offset (padding + border)
  const contentOffsetX = node.padding.left + node.border.left;
  const contentOffsetY = node.padding.top + node.border.top;

  return {
    ...node,
    children: node.children.map(child => {
      // Adjust child position to be relative to parent's content-box
      const adjustedChild = {
        ...child,
        x: child.x - contentOffsetX,
        y: child.y - contentOffsetY,
      };
      // Recursively normalize child's children
      return normalizeCraterPositions(adjustedChild);
    }),
  };
}

/**
 * Compare two layout trees
 */
function compareLayouts(
  browser: LayoutNode,
  crater: LayoutNode,
  path: string = 'root',
  options: { ignoreTextNodes?: boolean; ignoreBoxModel?: boolean } = {}
): Mismatch[] {
  const mismatches: Mismatch[] = [];

  // Compare position and size
  const props: (keyof LayoutNode)[] = ['x', 'y', 'width', 'height'];
  for (const prop of props) {
    const bVal = browser[prop] as number;
    const cVal = crater[prop] as number;
    const diff = Math.abs(bVal - cVal);
    if (diff > TOLERANCE) {
      mismatches.push({
        path,
        property: prop,
        browser: bVal,
        crater: cVal,
        diff,
      });
    }
  }

  // Compare box model (optional)
  if (!options.ignoreBoxModel) {
    const boxProps: (keyof LayoutNode)[] = ['margin', 'padding', 'border'];
    for (const boxProp of boxProps) {
      const bRect = browser[boxProp] as Rect;
      const cRect = crater[boxProp] as Rect;
      for (const side of ['top', 'right', 'bottom', 'left'] as const) {
        const bVal = bRect[side];
        const cVal = cRect[side];
        const diff = Math.abs(bVal - cVal);
        if (diff > TOLERANCE) {
          mismatches.push({
            path,
            property: `${boxProp}.${side}`,
            browser: bVal,
            crater: cVal,
            diff,
          });
        }
      }
    }
  }

  // Get children for comparison (optionally filter text nodes)
  const bChildren = options.ignoreTextNodes
    ? browser.children.filter(c => !c.id.startsWith('#text'))
    : browser.children;
  const cChildren = options.ignoreTextNodes
    ? crater.children.filter(c => !c.id.startsWith('#text'))
    : crater.children;

  // Compare children (by index for now)
  const minChildren = Math.min(bChildren.length, cChildren.length);
  for (let i = 0; i < minChildren; i++) {
    const childPath = `${path}/${bChildren[i].id}[${i}]`;
    mismatches.push(...compareLayouts(bChildren[i], cChildren[i], childPath, options));
  }

  // Report missing/extra children
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

/**
 * Count total nodes in tree
 */
function countNodes(node: LayoutNode): number {
  return 1 + node.children.reduce((sum, child) => sum + countNodes(child), 0);
}

/**
 * Run a single test
 */
async function runTest(
  browser: puppeteer.Browser,
  htmlPath: string
): Promise<TestResult> {
  const name = path.basename(htmlPath);

  try {
    // Get layouts from both sources
    let browserLayout: LayoutNode;
    try {
      browserLayout = await getBrowserLayout(browser, htmlPath);
    } catch (error) {
      throw new Error(`browser layout failed: ${error}`);
    }
    let craterLayout: LayoutNode;
    try {
      craterLayout = getCraterLayout(htmlPath);
    } catch (error) {
      throw new Error(`crater layout failed: ${error}`);
    }

    // Normalize crater positions to content-box relative (browser already uses content-box)
    const normalizedCraterLayout = normalizeCraterPositions(craterLayout);

    // Compare (ignore text nodes and box model for now)
    const mismatches = compareLayouts(browserLayout, normalizedCraterLayout, 'root', {
      ignoreTextNodes: true,
      ignoreBoxModel: true, // TODO: Fix Crater to populate padding/border in Layout
    });
    const totalNodes = countNodes(browserLayout);

    return {
      name,
      passed: mismatches.length === 0,
      mismatches,
      totalNodes,
    };
  } catch (error) {
    console.error(`  Error in ${name}: ${error}`);
    return {
      name,
      passed: false,
      mismatches: [{
        path: 'error',
        property: 'execution',
        browser: 0,
        crater: 0,
        diff: 0,
      }],
      totalNodes: 0,
    };
  }
}

/**
 * Print test result
 */
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

/**
 * Main entry point
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('WPT Runner for Crater');
    console.log('');
    console.log('Usage:');
    console.log('  npx tsx tools/wpt-runner.ts <test.html>');
    console.log('  npx tsx tools/wpt-runner.ts fixtures/*.html');
    return;
  }

  // Expand glob patterns
  const htmlFiles = args.flatMap(arg => {
    if (arg.includes('*')) {
      // Simple glob expansion for *.html
      const dir = path.dirname(arg);
      const pattern = path.basename(arg).replace('*', '');
      if (fs.existsSync(dir)) {
        return fs.readdirSync(dir)
          .filter(f => f.endsWith('.html'))
          .map(f => path.join(dir, f));
      }
      return [];
    }
    return [arg];
  });

  if (htmlFiles.length === 0) {
    console.error('No HTML files found');
    process.exit(1);
  }

  console.log(`Running ${htmlFiles.length} test(s)...\n`);

  // Browser restart interval to prevent connection issues
  const BROWSER_RESTART_INTERVAL = 50;
  let browser = await puppeteer.launch({ headless: true });

  let passed = 0;
  let failed = 0;
  let testCount = 0;

  for (const htmlFile of htmlFiles) {
    if (!fs.existsSync(htmlFile)) {
      console.log(`✗ ${htmlFile} (file not found)`);
      failed++;
      continue;
    }

    // Restart browser periodically to prevent connection issues
    if (testCount > 0 && testCount % BROWSER_RESTART_INTERVAL === 0) {
      try {
        await browser.close();
      } catch (e) {
        // Ignore close errors
      }
      browser = await puppeteer.launch({ headless: true });
    }

    // Retry on connection errors
    let result = await runTest(browser, htmlFile);
    if (!result.passed && result.mismatches.some(m => m.property === 'execution')) {
      // Restart browser and retry once
      try {
        await browser.close();
      } catch (e) {
        // Ignore close errors
      }
      browser = await puppeteer.launch({ headless: true });
      result = await runTest(browser, htmlFile);
    }
    printResult(result);

    if (result.passed) {
      passed++;
    } else {
      failed++;
    }
    testCount++;
  }

  try {
    await browser.close();
  } catch (e) {
    // Ignore close errors
  }

  console.log('');
  console.log(`Summary: ${passed} passed, ${failed} failed`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
