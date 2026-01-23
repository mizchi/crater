/**
 * Tailwind CSS Compatibility Test Suite for Crater
 *
 * Tests common Tailwind patterns and generates a compatibility report.
 *
 * Usage:
 *   npx tsx scripts/tailwind-compat.ts           # Run tests
 *   npx tsx scripts/tailwind-compat.ts --report  # Generate detailed report
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { renderer } from '../wasm/dist/crater.js';

const TAILWIND_TESTS_DIR = 'tailwind-tests';
const TOLERANCE = 15;
const VIEWPORT = { width: 800, height: 600 };
const CONCURRENCY = 6;

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
</style>
`;

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
  file: string;
  passed: boolean;
  category: string;
  utilities: string[];
  error?: string;
}

interface CategoryResult {
  name: string;
  passed: number;
  total: number;
  tests: TestResult[];
}

// Map test files to categories and utilities
const TEST_METADATA: Record<string, { category: string; utilities: string[] }> = {
  'flex-basic.html': {
    category: 'Flexbox',
    utilities: ['flex', 'flex-row', 'gap-*', 'w-*', 'h-*'],
  },
  'flex-col.html': {
    category: 'Flexbox',
    utilities: ['flex', 'flex-col', 'gap-*'],
  },
  'flex-justify.html': {
    category: 'Flexbox',
    utilities: ['flex', 'justify-center', 'justify-between'],
  },
  'flex-grow.html': {
    category: 'Flexbox',
    utilities: ['flex', 'flex-1', 'flex-none'],
  },
  'flex-wrap.html': {
    category: 'Flexbox',
    utilities: ['flex', 'flex-wrap', 'gap-*'],
  },
  'grid-basic.html': {
    category: 'Grid',
    utilities: ['grid', 'grid-cols-*', 'gap-*'],
  },
  'grid-responsive.html': {
    category: 'Grid',
    utilities: ['grid', 'grid-cols-*', 'gap-*', 'p-*'],
  },
  'spacing.html': {
    category: 'Spacing',
    utilities: ['p-*', 'm-*', 'px-*', 'py-*', 'mt-*', 'mb-*'],
  },
  'sizing.html': {
    category: 'Sizing',
    utilities: ['w-*', 'w-full', 'w-1/2', 'h-*'],
  },
  'position.html': {
    category: 'Position',
    utilities: ['relative', 'absolute', 'top-*', 'right-*', 'inset-*'],
  },
  'border.html': {
    category: 'Borders',
    utilities: ['border', 'border-*', 'rounded', 'rounded-*'],
  },
  'card-layout.html': {
    category: 'Layouts',
    utilities: ['flex', 'flex-col', 'gap-*', 'p-*', 'rounded-*', 'shadow'],
  },
  'nav-layout.html': {
    category: 'Layouts',
    utilities: ['flex', 'items-center', 'justify-between', 'px-*', 'py-*'],
  },
  'sidebar-layout.html': {
    category: 'Layouts',
    utilities: ['flex', 'flex-col', 'flex-1', 'gap-*', 'p-*', 'w-*'],
  },
  'centered-content.html': {
    category: 'Layouts',
    utilities: ['flex', 'items-center', 'justify-center', 'flex-col', 'gap-*'],
  },
  'align-items.html': {
    category: 'Flexbox',
    utilities: ['flex', 'items-start', 'items-end', 'items-center', 'items-baseline', 'items-stretch'],
  },
  'text-basic.html': {
    category: 'Typography',
    utilities: ['text-left', 'text-center', 'text-right'],
  },
  'overflow.html': {
    category: 'Layout',
    utilities: ['overflow-hidden', 'overflow-auto', 'overflow-scroll'],
  },
  'min-max-size.html': {
    category: 'Sizing',
    utilities: ['min-w-*', 'max-w-*', 'min-h-*', 'max-h-*'],
  },
  'aspect-ratio.html': {
    category: 'Sizing',
    utilities: ['aspect-square', 'aspect-video'],
  },
  'flex-order.html': {
    category: 'Flexbox',
    utilities: ['order-*', 'order-first', 'order-last', 'order-none'],
  },
  'flex-basis.html': {
    category: 'Flexbox',
    utilities: ['basis-*', 'basis-1/4', 'basis-1/2', 'basis-full', 'basis-auto'],
  },
  'grid-span.html': {
    category: 'Grid',
    utilities: ['col-span-*', 'row-span-*'],
  },
  'grid-start-end.html': {
    category: 'Grid',
    utilities: ['col-start-*', 'col-end-*', 'row-start-*', 'row-end-*'],
  },
  'grid-auto-flow.html': {
    category: 'Grid',
    utilities: ['grid-flow-row', 'grid-flow-col', 'grid-rows-*'],
  },
  'place-items.html': {
    category: 'Grid',
    utilities: ['place-items-start', 'place-items-center', 'place-items-end', 'place-items-stretch'],
  },
  'self-align.html': {
    category: 'Flexbox',
    utilities: ['self-start', 'self-center', 'self-end', 'self-stretch'],
  },
  'justify-self.html': {
    category: 'Grid',
    utilities: ['justify-self-start', 'justify-self-center', 'justify-self-end', 'justify-self-stretch'],
  },
  'display.html': {
    category: 'Layout',
    utilities: ['block', 'inline-block', 'inline', 'hidden'],
  },
  'box-sizing.html': {
    category: 'Layout',
    utilities: ['box-border', 'box-content'],
  },
  'z-index.html': {
    category: 'Layout',
    utilities: ['z-*', 'z-0', 'z-10', 'z-20', 'z-50'],
  },
  'table-layout.html': {
    category: 'Tables',
    utilities: ['table', 'table-auto', 'table-fixed', 'table-row', 'table-cell'],
  },
  'whitespace.html': {
    category: 'Typography',
    utilities: ['whitespace-normal', 'whitespace-nowrap', 'whitespace-pre', 'whitespace-pre-wrap'],
  },
  'inset.html': {
    category: 'Position',
    utilities: ['inset-0', 'inset-*', 'inset-x-*', 'inset-y-*'],
  },
  'gap-variants.html': {
    category: 'Spacing',
    utilities: ['gap-x-*', 'gap-y-*'],
  },
  'auto-margins.html': {
    category: 'Spacing',
    utilities: ['mx-auto', 'ml-auto', 'mr-auto'],
  },
  'negative-margin.html': {
    category: 'Spacing',
    utilities: ['-mt-*', '-ml-*', '-mr-*', '-mb-*'],
  },
  'content-align.html': {
    category: 'Flexbox',
    utilities: ['content-start', 'content-center', 'content-end', 'content-between'],
  },
};

function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');
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
        const parentPadding = el.parentElement ? getComputedRect(el.parentElement, 'padding') : { top: 0, left: 0 };
        const parentBorder = el.parentElement ? getComputedRect(el.parentElement, 'border') : { top: 0, left: 0 };
        x = rect.left - parentRect.left - parentBorder.left - parentPadding.left;
        y = rect.top - parentRect.top - parentBorder.top - parentPadding.top;
      }

      return {
        id: getNodeId(el),
        x, y,
        width: rect.width,
        height: rect.height,
        margin: getComputedRect(el, 'margin'),
        padding,
        border,
        children,
      };
    }

    const testElement = document.getElementById('test');
    if (testElement) {
      const layout = extractLayout(testElement);
      return { ...layout, x: 0, y: 0 };
    }
    return extractLayout(document.body);
  })()`);

  await page.close();
  return layout as LayoutNode;
}

function getCraterLayout(htmlPath: string): LayoutNode {
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

  const testElement = findNodeById(layout, 'div#test') || findNodeById(layout, '#test');
  if (testElement) return { ...testElement, x: 0, y: 0 };

  const meaningfulChildren = layout.children.filter(c => !c.id.startsWith('#text'));
  if (meaningfulChildren.length === 1) return { ...meaningfulChildren[0], x: 0, y: 0 };

  return { ...layout, x: 0, y: 0 };
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

function compareLayouts(browser: LayoutNode, crater: LayoutNode): { match: boolean; error?: string } {
  const props: (keyof LayoutNode)[] = ['x', 'y', 'width', 'height'];
  for (const prop of props) {
    const bVal = browser[prop] as number;
    const cVal = crater[prop] as number;
    const diff = Math.abs(bVal - cVal);
    if (diff > TOLERANCE) {
      return { match: false, error: `${browser.id}.${prop}: browser=${bVal}, crater=${cVal}` };
    }
  }

  const bChildren = browser.children.filter(c => !c.id.startsWith('#text'));
  const cChildren = crater.children.filter(c => !c.id.startsWith('#text'));

  if (bChildren.length !== cChildren.length) {
    return { match: false, error: `Child count mismatch: browser=${bChildren.length}, crater=${cChildren.length}` };
  }

  for (let i = 0; i < bChildren.length; i++) {
    const result = compareLayouts(bChildren[i], cChildren[i]);
    if (!result.match) return result;
  }

  return { match: true };
}

async function runTest(browser: puppeteer.Browser, htmlPath: string): Promise<TestResult> {
  const filename = path.basename(htmlPath);
  const metadata = TEST_METADATA[filename] || { category: 'Other', utilities: [] };

  try {
    const browserLayout = await getBrowserLayout(browser, htmlPath);
    const craterLayout = getCraterLayout(htmlPath);
    const normalizedCraterLayout = normalizeCraterPositions(craterLayout);

    const result = compareLayouts(browserLayout, normalizedCraterLayout);

    return {
      name: filename.replace('.html', ''),
      file: htmlPath,
      passed: result.match,
      category: metadata.category,
      utilities: metadata.utilities,
      error: result.error,
    };
  } catch (e) {
    return {
      name: filename.replace('.html', ''),
      file: htmlPath,
      passed: false,
      category: metadata.category,
      utilities: metadata.utilities,
      error: String(e),
    };
  }
}

async function runAllTests(): Promise<TestResult[]> {
  const htmlFiles = fs.readdirSync(TAILWIND_TESTS_DIR)
    .filter(f => f.endsWith('.html'))
    .map(f => path.join(TAILWIND_TESTS_DIR, f));

  const results: TestResult[] = [];
  let nextIndex = 0;

  async function worker(browser: puppeteer.Browser): Promise<void> {
    while (true) {
      const index = nextIndex++;
      if (index >= htmlFiles.length) break;

      const htmlFile = htmlFiles[index];
      const result = await runTest(browser, htmlFile);
      results[index] = result;

      const icon = result.passed ? '✓' : '✗';
      const count = results.filter(Boolean).length;
      process.stdout.write(`\r[${count}/${htmlFiles.length}] ${icon} ${path.basename(htmlFile).padEnd(30)}`);
    }
    await browser.close();
  }

  const browsers = await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, htmlFiles.length) }, () =>
      puppeteer.launch({ headless: true })
    )
  );

  await Promise.all(browsers.map(browser => worker(browser)));
  console.log('\n');

  return results;
}

function generateReport(results: TestResult[]): string {
  const categories: Record<string, CategoryResult> = {};

  for (const result of results) {
    if (!categories[result.category]) {
      categories[result.category] = { name: result.category, passed: 0, total: 0, tests: [] };
    }
    categories[result.category].total++;
    if (result.passed) categories[result.category].passed++;
    categories[result.category].tests.push(result);
  }

  const lines: string[] = [];
  lines.push('# Crater Tailwind CSS Compatibility Report');
  lines.push('');

  const totalPassed = results.filter(r => r.passed).length;
  const total = results.length;
  const passRate = (totalPassed / total * 100).toFixed(1);

  lines.push(`## Summary: ${totalPassed}/${total} tests passed (${passRate}%)`);
  lines.push('');

  // Overall badge
  if (totalPassed === total) {
    lines.push('**Status: ✅ FULLY COMPATIBLE**');
  } else if (totalPassed / total >= 0.9) {
    lines.push('**Status: ⚠️ MOSTLY COMPATIBLE**');
  } else {
    lines.push('**Status: ❌ PARTIAL SUPPORT**');
  }
  lines.push('');

  // By category
  lines.push('## Results by Category');
  lines.push('');

  for (const [_, cat] of Object.entries(categories).sort((a, b) => a[0].localeCompare(b[0]))) {
    const catRate = (cat.passed / cat.total * 100).toFixed(0);
    const catIcon = cat.passed === cat.total ? '✅' : '⚠️';
    lines.push(`### ${catIcon} ${cat.name} (${catRate}%)`);
    lines.push('');

    for (const test of cat.tests) {
      const icon = test.passed ? '✓' : '✗';
      lines.push(`- ${icon} **${test.name}**`);
      lines.push(`  - Utilities: \`${test.utilities.join('`, `')}\``);
      if (!test.passed && test.error) {
        lines.push(`  - Error: ${test.error}`);
      }
    }
    lines.push('');
  }

  // Safe utilities list
  lines.push('## Verified Tailwind Utilities');
  lines.push('');
  lines.push('The following Tailwind utility patterns are verified to work correctly:');
  lines.push('');

  const safeUtilities = new Set<string>();
  for (const result of results) {
    if (result.passed) {
      for (const util of result.utilities) {
        safeUtilities.add(util);
      }
    }
  }

  for (const util of [...safeUtilities].sort()) {
    lines.push(`- \`${util}\``);
  }
  lines.push('');

  // Known limitations
  lines.push('## Known Limitations');
  lines.push('');
  lines.push('### Layout Limitations');
  lines.push('- `h-full` inside flex items requires explicit parent height');
  lines.push('- `justify-self-center/end` in Grid may have position calculation issues');
  lines.push('- CSS `display: table` layout height calculation differs from browser');
  lines.push('');
  lines.push('### Typography Limitations');
  lines.push('- `whitespace-nowrap` height calculation may differ');
  lines.push('- Font rendering is simplified for TUI (monospace assumed)');
  lines.push('');
  lines.push('### Not Applicable in TUI');
  lines.push('- Responsive breakpoints (sm:, md:, lg:) - TUI has fixed dimensions');
  lines.push('- Pseudo-classes (:hover, :focus, etc.) - no mouse interaction');
  lines.push('- Animations and transitions - static rendering');
  lines.push('- Colors are simplified to ANSI palette');
  lines.push('');

  return lines.join('\n');
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const generateReportFlag = args.includes('--report');

  console.log('Running Tailwind CSS compatibility tests...\n');

  const results = await runAllTests();

  const passed = results.filter(r => r.passed).length;
  const total = results.length;

  console.log(`Summary: ${passed}/${total} passed (${(passed / total * 100).toFixed(1)}%)\n`);

  if (!results.every(r => r.passed)) {
    console.log('Failed tests:');
    for (const r of results.filter(r => !r.passed)) {
      console.log(`  ✗ ${r.name}: ${r.error}`);
    }
    console.log('');
  }

  if (generateReportFlag) {
    const report = generateReport(results);
    fs.writeFileSync('docs/tailwind-compat.md', report);
    console.log('Generated docs/tailwind-compat.md');

    // Also generate JSON
    const json = {
      generated: new Date().toISOString(),
      passed,
      total,
      passRate: passed / total,
      results: results.map(r => ({
        name: r.name,
        passed: r.passed,
        category: r.category,
        utilities: r.utilities,
      })),
    };
    fs.writeFileSync('tailwind-compat.json', JSON.stringify(json, null, 2));
    console.log('Generated tailwind-compat.json');
  }
}

main().catch(console.error);
