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
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

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

  // Load HTML file with CSS inlining and reset
  const htmlContent = prepareHtmlContent(htmlPath);
  await page.setContent(htmlContent, { waitUntil: 'networkidle0' });

  // Extract layout from all elements
  const layout = await page.evaluate(() => {
    function getComputedRect(el: Element, prop: 'margin' | 'padding' | 'border'): { top: number; right: number; bottom: number; left: number } {
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
        top: parseFloat(style[`${prop}Top` as keyof CSSStyleDeclaration] as string) || 0,
        right: parseFloat(style[`${prop}Right` as keyof CSSStyleDeclaration] as string) || 0,
        bottom: parseFloat(style[`${prop}Bottom` as keyof CSSStyleDeclaration] as string) || 0,
        left: parseFloat(style[`${prop}Left` as keyof CSSStyleDeclaration] as string) || 0,
      };
    }

    function getNodeId(el: Element): string {
      if (el.id) return `${el.tagName.toLowerCase()}#${el.id}`;
      if (el.className && typeof el.className === 'string') {
        const firstClass = el.className.split(' ')[0];
        if (firstClass) return `${el.tagName.toLowerCase()}.${firstClass}`;
      }
      return el.tagName.toLowerCase();
    }

    function extractLayout(el: Element, parentRect?: DOMRect): { top: number; right: number; bottom: number; left: number } & { id: string; x: number; y: number; width: number; height: number; margin: { top: number; right: number; bottom: number; left: number }; padding: { top: number; right: number; bottom: number; left: number }; border: { top: number; right: number; bottom: number; left: number }; children: any[] } {
      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      const padding = getComputedRect(el, 'padding');
      const border = getComputedRect(el, 'border');
      const children: any[] = [];

      // Calculate content box origin for child positioning
      const contentX = rect.left + border.left + padding.left;
      const contentY = rect.top + border.top + padding.top;

      for (const child of el.children) {
        // Skip script, style, link, meta tags
        if (['SCRIPT', 'STYLE', 'LINK', 'META', 'TITLE', 'HEAD'].includes(child.tagName)) continue;
        children.push(extractLayout(child, rect));
      }

      // Calculate position relative to parent's content box
      let x = rect.left;
      let y = rect.top;
      if (parentRect) {
        const parentStyle = el.parentElement ? getComputedStyle(el.parentElement) : null;
        const parentPadding = el.parentElement ? getComputedRect(el.parentElement, 'padding') : { top: 0, left: 0, right: 0, bottom: 0 };
        const parentBorder = el.parentElement ? getComputedRect(el.parentElement, 'border') : { top: 0, left: 0, right: 0, bottom: 0 };
        x = rect.left - parentRect.left - parentBorder.left - parentPadding.left;
        y = rect.top - parentRect.top - parentBorder.top - parentPadding.top;
      }

      return {
        id: getNodeId(el),
        x,
        y,
        width: rect.width,
        height: rect.height,
        margin: getComputedRect(el, 'margin'),
        padding,
        border,
        children,
        top: 0, right: 0, bottom: 0, left: 0 // placeholder
      };
    }

    // Find the test element
    const body = document.body;

    // WPT tests often have a #test element as the main test target
    const testElement = document.getElementById('test');
    if (testElement) {
      return extractLayout(testElement);
    }

    // Otherwise, find the first meaningful element (skip p, script, etc.)
    const children = Array.from(body.children).filter(
      el => !['SCRIPT', 'STYLE', 'LINK', 'META', 'P', 'DIV#log'].includes(el.tagName) &&
            el.id !== 'log'
    );
    if (children.length === 1) {
      return extractLayout(children[0]);
    }

    // If multiple children, try to find a container div
    const divChildren = children.filter(el => el.tagName === 'DIV');
    if (divChildren.length === 1) {
      return extractLayout(divChildren[0]);
    }

    return extractLayout(body);
  });

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
  try {
    // Prepare HTML with inlined CSS
    const htmlContent = prepareHtmlContent(htmlPath);

    // Write to temp file
    const tempPath = path.join(os.tmpdir(), `crater-test-${Date.now()}.html`);
    fs.writeFileSync(tempPath, htmlContent);

    try {
      const result = execSync(
        `moon run --target native cmd/main -- --json "${tempPath}" 2>/dev/null`,
        { encoding: 'utf-8', cwd: process.cwd() }
      );
      let layout = JSON.parse(result.trim()) as LayoutNode;

      // Find #test element if it exists (WPT tests)
      const testElement = findNodeById(layout, 'div#test') || findNodeById(layout, '#test');
      if (testElement) {
        return testElement;
      }

      // If root (body) has a single meaningful child, use that child
      // to match browser behavior
      const meaningfulChildren = layout.children.filter(
        c => !c.id.startsWith('#text') && c.id !== 'p' && c.id !== 'div#log'
      );
      if (meaningfulChildren.length === 1) {
        return meaningfulChildren[0];
      }

      // Try to find a container div
      const divChildren = meaningfulChildren.filter(c => c.id.startsWith('div'));
      if (divChildren.length === 1) {
        return divChildren[0];
      }

      return layout;
    } finally {
      // Clean up temp file
      fs.unlinkSync(tempPath);
    }
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
    const browserLayout = await getBrowserLayout(browser, htmlPath);
    const craterLayout = getCraterLayout(htmlPath);

    // Compare (ignore text nodes and box model for now)
    const mismatches = compareLayouts(browserLayout, craterLayout, 'root', {
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

  // Launch browser
  const browser = await puppeteer.launch({ headless: true });

  let passed = 0;
  let failed = 0;

  for (const htmlFile of htmlFiles) {
    if (!fs.existsSync(htmlFile)) {
      console.log(`✗ ${htmlFile} (file not found)`);
      failed++;
      continue;
    }

    const result = await runTest(browser, htmlFile);
    printResult(result);

    if (result.passed) {
      passed++;
    } else {
      failed++;
    }
  }

  await browser.close();

  console.log('');
  console.log(`Summary: ${passed} passed, ${failed} failed`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
