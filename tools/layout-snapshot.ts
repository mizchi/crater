/**
 * Layout Snapshot Tool for Real-World Site Testing
 *
 * Extracts browser layout information for specific nodes and saves as snapshot.
 * Used to compare Crater's layout with actual browser rendering.
 *
 * Usage:
 *   # Generate snapshot from browser
 *   npx tsx tools/layout-snapshot.ts snapshot <html-file> [--selectors="selector1,selector2"]
 *
 *   # Compare Crater with snapshot
 *   npx tsx tools/layout-snapshot.ts compare <html-file>
 *
 *   # Run both and show diff
 *   npx tsx tools/layout-snapshot.ts diff <html-file>
 *
 * Examples:
 *   npx tsx tools/layout-snapshot.ts snapshot real-world/wikipedia/index.html
 *   npx tsx tools/layout-snapshot.ts compare real-world/wikipedia/index.html
 *   npx tsx tools/layout-snapshot.ts diff real-world/wikipedia/index.html --selectors="#content,#mw-content-text"
 */

import puppeteer from 'puppeteer';
import * as fs from 'fs';
import * as path from 'path';

// Types
interface NodeLayout {
  selector: string;
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  display: string;
  position: string;
}

interface LayoutSnapshot {
  source: string;
  htmlFile: string;
  viewport: { width: number; height: number };
  timestamp: string;
  nodes: NodeLayout[];
}

interface LayoutDiff {
  selector: string;
  property: string;
  browser: number | string;
  crater: number | string;
  diff?: number;
}

// Default selectors for Wikipedia
const DEFAULT_WIKIPEDIA_SELECTORS = [
  'body',
  '#mw-page-base',
  '#mw-head-base',
  '#content',
  '#left-navigation',
  '#right-navigation',
  '#mw-head',
  '#mw-panel',
  '#p-logo',
  '#mw-content-text',
  '#firstHeading',
  '#siteSub',
  '#contentSub',
  '.mw-body',
  '.mw-body-content',
  '.mw-parser-output',
  '.vector-body',
];

// Read viewport from metadata.json if exists
function getViewportFromMetadata(htmlDir: string): { width: number; height: number } {
  const metadataPath = path.join(htmlDir, 'metadata.json');
  if (fs.existsSync(metadataPath)) {
    try {
      const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf-8'));
      if (metadata.viewport) {
        return metadata.viewport;
      }
    } catch (e) {
      // ignore
    }
  }
  return { width: 800, height: 600 };
}

/**
 * Extract layout from browser using Puppeteer
 */
async function getBrowserLayout(
  htmlPath: string,
  selectors: string[],
  viewport: { width: number; height: number }
): Promise<NodeLayout[]> {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport(viewport);

  // Load HTML file
  const htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  await page.setContent(htmlContent, { waitUntil: 'domcontentloaded', timeout: 10000 });

  // Extract layout for each selector
  const layouts = await page.evaluate((sels: string[]) => {
    const results: NodeLayout[] = [];

    for (const selector of sels) {
      const el = document.querySelector(selector);
      if (!el) continue;

      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);

      results.push({
        selector,
        id: el.id || el.className?.toString().split(' ')[0] || el.tagName.toLowerCase(),
        x: Math.round(rect.left),
        y: Math.round(rect.top),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
        display: style.display,
        position: style.position,
      });
    }

    return results;
  }, selectors);

  await browser.close();
  return layouts;
}

/**
 * Extract layout from Crater using WASM component
 */
async function getCraterLayout(
  htmlPath: string,
  viewport: { width: number; height: number }
): Promise<any> {
  const { renderer } = await import('../wasm/dist/crater.js');
  const htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  const result = renderer.renderHtmlToJson(htmlContent, viewport.width, viewport.height);
  return JSON.parse(result);
}

/**
 * Find node in Crater layout tree by selector
 */
function findNodeBySelector(node: any, selector: string): any | null {
  // Parse selector
  const idMatch = selector.match(/^#(.+)$/);
  const classMatch = selector.match(/^\.(.+)$/);
  const tagIdMatch = selector.match(/^(\w+)#(.+)$/);
  const tagClassMatch = selector.match(/^(\w+)\.(.+)$/);

  // Check current node
  const nodeId = node.id || '';
  let matches = false;

  if (selector === 'body' && nodeId === 'body') {
    matches = true;
  } else if (idMatch) {
    // #id selector
    matches = nodeId.includes(`#${idMatch[1]}`);
  } else if (classMatch) {
    // .class selector
    matches = nodeId.includes(`.${classMatch[1]}`);
  } else if (tagIdMatch) {
    // tag#id selector
    matches = nodeId === `${tagIdMatch[1]}#${tagIdMatch[2]}`;
  } else if (tagClassMatch) {
    // tag.class selector
    matches = nodeId === `${tagClassMatch[1]}.${tagClassMatch[2]}` ||
              nodeId.startsWith(`${tagClassMatch[1]}.${tagClassMatch[2]}`);
  }

  if (matches) {
    return node;
  }

  // Search children
  if (node.children) {
    for (const child of node.children) {
      const found = findNodeBySelector(child, selector);
      if (found) return found;
    }
  }

  return null;
}

/**
 * Extract Crater layouts for selectors
 */
function extractCraterLayouts(
  craterTree: any,
  selectors: string[]
): NodeLayout[] {
  const results: NodeLayout[] = [];

  for (const selector of selectors) {
    const node = findNodeBySelector(craterTree, selector);
    if (!node) continue;

    results.push({
      selector,
      id: node.id || '',
      x: Math.round(node.x || 0),
      y: Math.round(node.y || 0),
      width: Math.round(node.width || 0),
      height: Math.round(node.height || 0),
      display: node.style?.display || 'unknown',
      position: node.style?.position || 'unknown',
    });
  }

  return results;
}

/**
 * Compare two layout snapshots
 */
function compareLayouts(
  browser: NodeLayout[],
  crater: NodeLayout[],
  tolerance: number = 5
): LayoutDiff[] {
  const diffs: LayoutDiff[] = [];

  for (const browserNode of browser) {
    const craterNode = crater.find(n => n.selector === browserNode.selector);

    if (!craterNode) {
      diffs.push({
        selector: browserNode.selector,
        property: 'missing',
        browser: 'exists',
        crater: 'not found',
      });
      continue;
    }

    // Compare numeric properties
    for (const prop of ['x', 'y', 'width', 'height'] as const) {
      const bVal = browserNode[prop];
      const cVal = craterNode[prop];
      const diff = Math.abs(bVal - cVal);
      if (diff > tolerance) {
        diffs.push({
          selector: browserNode.selector,
          property: prop,
          browser: bVal,
          crater: cVal,
          diff,
        });
      }
    }

    // Compare string properties
    if (browserNode.display !== craterNode.display && craterNode.display !== 'unknown') {
      diffs.push({
        selector: browserNode.selector,
        property: 'display',
        browser: browserNode.display,
        crater: craterNode.display,
      });
    }
  }

  return diffs;
}

/**
 * Generate snapshot from browser
 */
async function generateSnapshot(
  htmlPath: string,
  selectors: string[]
): Promise<LayoutSnapshot> {
  const htmlDir = path.dirname(htmlPath);
  const viewport = getViewportFromMetadata(htmlDir);

  console.log(`Generating browser snapshot...`);
  console.log(`  HTML: ${htmlPath}`);
  console.log(`  Viewport: ${viewport.width}x${viewport.height}`);
  console.log(`  Selectors: ${selectors.length}`);

  const nodes = await getBrowserLayout(htmlPath, selectors, viewport);

  console.log(`  Found: ${nodes.length} nodes`);

  return {
    source: 'browser',
    htmlFile: path.basename(htmlPath),
    viewport,
    timestamp: new Date().toISOString(),
    nodes,
  };
}

/**
 * Save snapshot to JSON file
 */
function saveSnapshot(snapshot: LayoutSnapshot, outputPath: string): void {
  fs.writeFileSync(outputPath, JSON.stringify(snapshot, null, 2));
  console.log(`Saved: ${outputPath}`);
}

/**
 * Load snapshot from JSON file
 */
function loadSnapshot(snapshotPath: string): LayoutSnapshot {
  return JSON.parse(fs.readFileSync(snapshotPath, 'utf-8'));
}

/**
 * Generate Crater layout and compare with snapshot
 */
async function compareWithSnapshot(
  htmlPath: string,
  selectors: string[]
): Promise<{ diffs: LayoutDiff[]; browser: NodeLayout[]; crater: NodeLayout[] }> {
  const htmlDir = path.dirname(htmlPath);
  const viewport = getViewportFromMetadata(htmlDir);
  const snapshotPath = path.join(htmlDir, 'layout-snapshot.json');

  // Load or generate browser snapshot
  let browserSnapshot: LayoutSnapshot;
  if (fs.existsSync(snapshotPath)) {
    console.log(`Loading snapshot: ${snapshotPath}`);
    browserSnapshot = loadSnapshot(snapshotPath);
  } else {
    console.log(`No snapshot found, generating from browser...`);
    browserSnapshot = await generateSnapshot(htmlPath, selectors);
    saveSnapshot(browserSnapshot, snapshotPath);
  }

  // Generate Crater layout
  console.log(`Running Crater...`);
  const craterTree = await getCraterLayout(htmlPath, viewport);
  const craterLayouts = extractCraterLayouts(craterTree, selectors);

  console.log(`  Found: ${craterLayouts.length} nodes`);

  // Compare
  const diffs = compareLayouts(browserSnapshot.nodes, craterLayouts);

  return {
    diffs,
    browser: browserSnapshot.nodes,
    crater: craterLayouts,
  };
}

/**
 * Print comparison results
 */
function printComparison(
  browser: NodeLayout[],
  crater: NodeLayout[],
  diffs: LayoutDiff[]
): void {
  console.log('\n=== Layout Comparison ===\n');

  // Print side-by-side table
  console.log('Selector                          | Browser (x,y,w,h)       | Crater (x,y,w,h)        | Match');
  console.log('----------------------------------|-------------------------|-------------------------|------');

  for (const browserNode of browser) {
    const craterNode = crater.find(n => n.selector === browserNode.selector);
    const nodeDiffs = diffs.filter(d => d.selector === browserNode.selector);

    const bStr = `(${browserNode.x},${browserNode.y},${browserNode.width},${browserNode.height})`;
    const cStr = craterNode
      ? `(${craterNode.x},${craterNode.y},${craterNode.width},${craterNode.height})`
      : '(not found)';
    const match = nodeDiffs.length === 0 ? '  OK' : `  NG (${nodeDiffs.length})`;

    const selector = browserNode.selector.padEnd(33);
    console.log(`${selector} | ${bStr.padEnd(23)} | ${cStr.padEnd(23)} | ${match}`);
  }

  // Print diffs
  if (diffs.length > 0) {
    console.log('\n=== Differences ===\n');
    for (const diff of diffs) {
      if (diff.diff !== undefined) {
        console.log(`${diff.selector}.${diff.property}: browser=${diff.browser}, crater=${diff.crater} (diff=${diff.diff})`);
      } else {
        console.log(`${diff.selector}.${diff.property}: browser=${diff.browser}, crater=${diff.crater}`);
      }
    }
  }

  console.log(`\n=== Summary ===`);
  console.log(`Total nodes: ${browser.length}`);
  console.log(`Matching: ${browser.length - new Set(diffs.map(d => d.selector)).size}`);
  console.log(`Mismatched: ${new Set(diffs.map(d => d.selector)).size}`);
  console.log(`Total diffs: ${diffs.length}`);
}

/**
 * Generate MoonBit test code from snapshot
 */
function generateMoonBitTest(
  snapshot: LayoutSnapshot,
  htmlPath: string
): string {
  const testName = path.basename(path.dirname(htmlPath));
  const relativePath = path.relative(process.cwd(), htmlPath);

  let code = `///|\n`;
  code += `test "real-world/${testName} layout" {\n`;
  code += `  // Generated from browser snapshot\n`;
  code += `  // Viewport: ${snapshot.viewport.width}x${snapshot.viewport.height}\n`;
  code += `  // HTML: ${relativePath}\n`;
  code += `  let expected : Array[(String, Int, Int, Int, Int)] = [\n`;

  for (const node of snapshot.nodes) {
    code += `    ("${node.selector}", ${node.x}, ${node.y}, ${node.width}, ${node.height}),\n`;
  }

  code += `  ]\n`;
  code += `  // TODO: Add Crater layout comparison\n`;
  code += `}\n`;

  return code;
}

// Main
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('Layout Snapshot Tool');
    console.log('');
    console.log('Usage:');
    console.log('  npx tsx tools/layout-snapshot.ts snapshot <html-file> [--selectors="sel1,sel2"]');
    console.log('  npx tsx tools/layout-snapshot.ts compare <html-file> [--selectors="sel1,sel2"]');
    console.log('  npx tsx tools/layout-snapshot.ts diff <html-file> [--selectors="sel1,sel2"]');
    console.log('  npx tsx tools/layout-snapshot.ts moonbit <html-file>');
    console.log('');
    console.log('Examples:');
    console.log('  npx tsx tools/layout-snapshot.ts snapshot real-world/wikipedia/index.html');
    console.log('  npx tsx tools/layout-snapshot.ts diff real-world/wikipedia/index.html');
    return;
  }

  const command = args[0];
  const htmlFile = args[1];

  if (!htmlFile || !fs.existsSync(htmlFile)) {
    console.error(`Error: HTML file not found: ${htmlFile}`);
    process.exit(1);
  }

  // Parse selectors from args
  let selectors = DEFAULT_WIKIPEDIA_SELECTORS;
  for (const arg of args) {
    if (arg.startsWith('--selectors=')) {
      selectors = arg.slice(12).split(',').map(s => s.trim());
    }
  }

  switch (command) {
    case 'snapshot': {
      const snapshot = await generateSnapshot(htmlFile, selectors);
      const outputPath = path.join(path.dirname(htmlFile), 'layout-snapshot.json');
      saveSnapshot(snapshot, outputPath);
      break;
    }

    case 'compare':
    case 'diff': {
      const { diffs, browser, crater } = await compareWithSnapshot(htmlFile, selectors);
      printComparison(browser, crater, diffs);
      process.exit(diffs.length > 0 ? 1 : 0);
      break;
    }

    case 'moonbit': {
      const snapshotPath = path.join(path.dirname(htmlFile), 'layout-snapshot.json');
      if (!fs.existsSync(snapshotPath)) {
        console.log('Generating snapshot first...');
        const snapshot = await generateSnapshot(htmlFile, selectors);
        saveSnapshot(snapshot, snapshotPath);
      }
      const snapshot = loadSnapshot(snapshotPath);
      const code = generateMoonBitTest(snapshot, htmlFile);
      console.log(code);
      break;
    }

    default:
      console.error(`Unknown command: ${command}`);
      process.exit(1);
  }
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
