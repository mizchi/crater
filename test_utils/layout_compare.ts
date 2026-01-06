/**
 * Layout Comparison Utilities
 *
 * Reusable utilities for comparing browser and Crater layouts.
 * Focuses on cumulative layout (container positions) rather than text nodes.
 */

import puppeteer from 'puppeteer';
import * as fs from 'fs';
import * as path from 'path';

// Types
export interface NodeRect {
  selector: string;
  tag: string;
  id: string;
  classes: string[];
  x: number;
  y: number;
  width: number;
  height: number;
  display: string;
  position: string;
  children: NodeRect[];
}

export interface LayoutDiff {
  path: string;
  property: string;
  browser: number | string;
  crater: number | string;
  diff?: number;
  severity: 'low' | 'medium' | 'high';
}

export interface CompareOptions {
  tolerance: number;
  skipTextNodes: boolean;
  skipHiddenNodes: boolean;
  maxDepth: number;
}

const DEFAULT_OPTIONS: CompareOptions = {
  tolerance: 10,
  skipTextNodes: true,
  skipHiddenNodes: true,
  maxDepth: 10,
};

/**
 * Extract full layout tree from browser
 */
export async function getBrowserLayoutTree(
  htmlPath: string,
  viewport: { width: number; height: number }
): Promise<NodeRect> {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport(viewport);

  const htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  await page.setContent(htmlContent, { waitUntil: 'domcontentloaded', timeout: 10000 });

  const layout = await page.evaluate(`
    (function() {
      function extractNode(el, depth) {
        depth = depth || 0;
        var skipTags = ['SCRIPT', 'STYLE', 'LINK', 'META', 'TITLE', 'HEAD', 'NOSCRIPT'];
        if (skipTags.indexOf(el.tagName) >= 0) {
          return null;
        }

        var rect = el.getBoundingClientRect();
        var style = getComputedStyle(el);

        if (style.display === 'none' || style.visibility === 'hidden') {
          return null;
        }

        var children = [];
        if (depth < 15) {
          for (var i = 0; i < el.children.length; i++) {
            var childNode = extractNode(el.children[i], depth + 1);
            if (childNode) children.push(childNode);
          }
        }

        return {
          tag: el.tagName.toLowerCase(),
          id: el.id || '',
          classes: Array.from(el.classList),
          x: Math.round(rect.left),
          y: Math.round(rect.top),
          width: Math.round(rect.width),
          height: Math.round(rect.height),
          display: style.display,
          position: style.position,
          children: children
        };
      }

      return extractNode(document.body);
    })()
  `);

  await browser.close();
  return layout;
}

/**
 * Get node identifier for logging
 */
function getNodeId(node: any): string {
  if (node.id) return `${node.tag}#${node.id}`;
  if (node.classes?.length > 0) return `${node.tag}.${node.classes[0]}`;
  return node.tag || node.id || 'unknown';
}

/**
 * Find best matching child by tag/id/class
 */
function findMatchingChild(browserChild: any, craterChildren: any[]): any | null {
  const browserId = getNodeId(browserChild);

  // First try exact match by id
  for (const craterChild of craterChildren) {
    const craterId = getNodeId(craterChild);
    if (craterId === browserId) return craterChild;
  }

  // Try match by tag + first class
  const browserTag = browserChild.tag;
  for (const craterChild of craterChildren) {
    if (craterChild.tag === browserTag || craterChild.id?.startsWith(browserTag)) {
      // Check if classes overlap
      if (browserChild.classes?.length > 0 && craterChild.id?.includes(`.${browserChild.classes[0]}`)) {
        return craterChild;
      }
    }
  }

  return null;
}

/**
 * Parse Crater node ID to extract tag and classes
 */
function parseCraterId(id: string): { tag: string; nodeId: string; classes: string[] } {
  // Format: "tag#id" or "tag.class" or "tag.class1.class2"
  const hashIdx = id.indexOf('#');
  const dotIdx = id.indexOf('.');

  let tag = id;
  let nodeId = '';
  let classes: string[] = [];

  if (hashIdx > 0) {
    tag = id.slice(0, hashIdx);
    nodeId = id.slice(hashIdx + 1);
  } else if (dotIdx > 0) {
    tag = id.slice(0, dotIdx);
    classes = id.slice(dotIdx + 1).split('.');
  }

  return { tag, nodeId, classes };
}

/**
 * Compare layout trees recursively
 */
export function compareLayoutTrees(
  browser: any,
  crater: any,
  options: CompareOptions = DEFAULT_OPTIONS,
  path: string = 'root',
  depth: number = 0
): LayoutDiff[] {
  const diffs: LayoutDiff[] = [];

  if (!browser || !crater) {
    if (browser && !crater) {
      diffs.push({
        path,
        property: 'node',
        browser: getNodeId(browser),
        crater: 'missing',
        severity: 'high',
      });
    }
    return diffs;
  }

  if (depth > options.maxDepth) return diffs;

  // Compare position and size
  const props = ['x', 'y', 'width', 'height'] as const;
  for (const prop of props) {
    const bVal = browser[prop] ?? 0;
    const cVal = crater[prop] ?? 0;
    const diff = Math.abs(bVal - cVal);

    if (diff > options.tolerance) {
      // Determine severity based on diff size
      let severity: 'low' | 'medium' | 'high' = 'low';
      if (diff > 100) severity = 'high';
      else if (diff > 50) severity = 'medium';

      diffs.push({
        path,
        property: prop,
        browser: bVal,
        crater: cVal,
        diff,
        severity,
      });
    }
  }

  // Compare children (skip text nodes)
  const browserChildren = (browser.children || []).filter((c: any) =>
    options.skipTextNodes ? c.tag !== '#text' : true
  );
  const craterChildren = (crater.children || []).filter((c: any) =>
    options.skipTextNodes ? !c.id?.startsWith('#text') : true
  );

  // Match children by id/class
  for (let i = 0; i < browserChildren.length; i++) {
    const browserChild = browserChildren[i];
    const craterChild = findMatchingChild(browserChild, craterChildren);

    const childPath = `${path}/${getNodeId(browserChild)}`;

    if (craterChild) {
      diffs.push(...compareLayoutTrees(browserChild, craterChild, options, childPath, depth + 1));
    } else if (browserChild.width > 0 && browserChild.height > 0) {
      // Only report missing nodes that have actual size
      diffs.push({
        path: childPath,
        property: 'node',
        browser: 'exists',
        crater: 'missing',
        severity: 'medium',
      });
    }
  }

  return diffs;
}

/**
 * Get Crater layout tree using WASM component
 */
export async function getCraterLayoutTree(
  htmlPath: string,
  viewport: { width: number; height: number }
): Promise<any> {
  // Import the WASM component
  const { renderer } = await import('../wasm/dist/crater.js');

  const htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  const result = renderer.renderHtmlToJson(htmlContent, viewport.width, viewport.height);
  return JSON.parse(result);
}

/**
 * Find large differences (useful for debugging)
 */
export function findLargeDiffs(diffs: LayoutDiff[], threshold: number = 50): LayoutDiff[] {
  return diffs.filter(d => d.diff && d.diff > threshold);
}

/**
 * Group diffs by path
 */
export function groupDiffsByPath(diffs: LayoutDiff[]): Map<string, LayoutDiff[]> {
  const groups = new Map<string, LayoutDiff[]>();
  for (const diff of diffs) {
    const existing = groups.get(diff.path) || [];
    existing.push(diff);
    groups.set(diff.path, existing);
  }
  return groups;
}

/**
 * Print diff report
 */
export function printDiffReport(diffs: LayoutDiff[]): void {
  const grouped = groupDiffsByPath(diffs);
  const highSeverity = diffs.filter(d => d.severity === 'high');
  const mediumSeverity = diffs.filter(d => d.severity === 'medium');

  console.log('\n=== Layout Comparison Report ===\n');

  if (highSeverity.length > 0) {
    console.log(`HIGH SEVERITY (${highSeverity.length}):`);
    for (const diff of highSeverity.slice(0, 20)) {
      console.log(`  ${diff.path}.${diff.property}: browser=${diff.browser}, crater=${diff.crater} (diff=${diff.diff})`);
    }
    if (highSeverity.length > 20) {
      console.log(`  ... and ${highSeverity.length - 20} more`);
    }
    console.log('');
  }

  if (mediumSeverity.length > 0) {
    console.log(`MEDIUM SEVERITY (${mediumSeverity.length}):`);
    for (const diff of mediumSeverity.slice(0, 10)) {
      console.log(`  ${diff.path}.${diff.property}: browser=${diff.browser}, crater=${diff.crater} (diff=${diff.diff})`);
    }
    if (mediumSeverity.length > 10) {
      console.log(`  ... and ${mediumSeverity.length - 10} more`);
    }
    console.log('');
  }

  console.log(`Summary: ${diffs.length} total diffs, ${highSeverity.length} high, ${mediumSeverity.length} medium`);
}

/**
 * Save layout trees for inspection
 */
export function saveLayoutTrees(
  browser: any,
  crater: any,
  outputDir: string
): void {
  fs.writeFileSync(
    path.join(outputDir, 'browser-layout.json'),
    JSON.stringify(browser, null, 2)
  );
  fs.writeFileSync(
    path.join(outputDir, 'crater-layout.json'),
    JSON.stringify(crater, null, 2)
  );
  console.log(`Saved layout trees to ${outputDir}/`);
}
