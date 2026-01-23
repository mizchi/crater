/**
 * Layout Diff Tool - Compare layouts between Chrome and Crater
 *
 * Like pixelmatch but for layout rectangles. Compares position and size
 * of all elements recursively and outputs a detailed diff report.
 *
 * Usage:
 *   npx tsx scripts/layout-diff.ts <html-file>
 *   npx tsx scripts/layout-diff.ts <html-file> --html    # Generate HTML visual report
 *   npx tsx scripts/layout-diff.ts <html-file> --json    # Output JSON diff
 *   npx tsx scripts/layout-diff.ts <html-file> --threshold 5  # Custom tolerance (px)
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

interface RectDiff {
  id: string;
  browser: { x: number; y: number; width: number; height: number };
  crater: { x: number; y: number; width: number; height: number };
  diff: { x: number; y: number; width: number; height: number };
  match: boolean;
  iou: number; // Intersection over Union (0-1)
  children: RectDiff[];
}

interface DiffReport {
  file: string;
  totalNodes: number;
  matchedNodes: number;
  mismatchedNodes: number;
  matchRate: number;
  averageIoU: number;
  diffs: RectDiff;
}

// Config
const DEFAULT_THRESHOLD = 5; // pixels
const VIEWPORT = { width: 800, height: 600 };

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
</style>
`;

// Calculate Intersection over Union for two rectangles
function calculateIoU(
  r1: { x: number; y: number; width: number; height: number },
  r2: { x: number; y: number; width: number; height: number }
): number {
  const x1 = Math.max(r1.x, r2.x);
  const y1 = Math.max(r1.y, r2.y);
  const x2 = Math.min(r1.x + r1.width, r2.x + r2.width);
  const y2 = Math.min(r1.y + r1.height, r2.y + r2.height);

  const intersectionWidth = Math.max(0, x2 - x1);
  const intersectionHeight = Math.max(0, y2 - y1);
  const intersection = intersectionWidth * intersectionHeight;

  const area1 = r1.width * r1.height;
  const area2 = r2.width * r2.height;
  const union = area1 + area2 - intersection;

  if (union === 0) return r1.width === r2.width && r1.height === r2.height ? 1 : 0;
  return intersection / union;
}

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

async function getBrowserLayout(htmlContent: string): Promise<LayoutNode> {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);
  page.on('pageerror', () => {});

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

  await browser.close();
  return layout as LayoutNode;
}

function getCraterLayout(htmlContent: string): LayoutNode {
  const result = renderer.renderHtmlToJson(htmlContent, VIEWPORT.width, VIEWPORT.height);
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

function compareNodes(
  browser: LayoutNode,
  crater: LayoutNode,
  threshold: number
): RectDiff {
  const bRect = { x: browser.x, y: browser.y, width: browser.width, height: browser.height };
  const cRect = { x: crater.x, y: crater.y, width: crater.width, height: crater.height };

  const diff = {
    x: Math.abs(bRect.x - cRect.x),
    y: Math.abs(bRect.y - cRect.y),
    width: Math.abs(bRect.width - cRect.width),
    height: Math.abs(bRect.height - cRect.height),
  };

  const match = diff.x <= threshold && diff.y <= threshold &&
                diff.width <= threshold && diff.height <= threshold;

  const iou = calculateIoU(bRect, cRect);

  // Compare children
  const bChildren = browser.children.filter(c => !c.id.startsWith('#text'));
  const cChildren = crater.children.filter(c => !c.id.startsWith('#text'));

  const childDiffs: RectDiff[] = [];
  const maxLen = Math.max(bChildren.length, cChildren.length);

  for (let i = 0; i < maxLen; i++) {
    if (i < bChildren.length && i < cChildren.length) {
      childDiffs.push(compareNodes(bChildren[i], cChildren[i], threshold));
    } else if (i < bChildren.length) {
      // Extra browser child
      childDiffs.push({
        id: bChildren[i].id + ' (browser only)',
        browser: { x: bChildren[i].x, y: bChildren[i].y, width: bChildren[i].width, height: bChildren[i].height },
        crater: { x: 0, y: 0, width: 0, height: 0 },
        diff: { x: bChildren[i].x, y: bChildren[i].y, width: bChildren[i].width, height: bChildren[i].height },
        match: false,
        iou: 0,
        children: [],
      });
    } else {
      // Extra crater child
      childDiffs.push({
        id: cChildren[i].id + ' (crater only)',
        browser: { x: 0, y: 0, width: 0, height: 0 },
        crater: { x: cChildren[i].x, y: cChildren[i].y, width: cChildren[i].width, height: cChildren[i].height },
        diff: { x: cChildren[i].x, y: cChildren[i].y, width: cChildren[i].width, height: cChildren[i].height },
        match: false,
        iou: 0,
        children: [],
      });
    }
  }

  return {
    id: browser.id || crater.id,
    browser: bRect,
    crater: cRect,
    diff,
    match,
    iou,
    children: childDiffs,
  };
}

function collectStats(diff: RectDiff): { total: number; matched: number; ious: number[] } {
  let total = 1;
  let matched = diff.match ? 1 : 0;
  let ious = [diff.iou];

  for (const child of diff.children) {
    const childStats = collectStats(child);
    total += childStats.total;
    matched += childStats.matched;
    ious = ious.concat(childStats.ious);
  }

  return { total, matched, ious };
}

function generateReport(file: string, diff: RectDiff): DiffReport {
  const stats = collectStats(diff);
  const averageIoU = stats.ious.reduce((a, b) => a + b, 0) / stats.ious.length;

  return {
    file,
    totalNodes: stats.total,
    matchedNodes: stats.matched,
    mismatchedNodes: stats.total - stats.matched,
    matchRate: stats.matched / stats.total,
    averageIoU,
    diffs: diff,
  };
}

function formatDiffTree(diff: RectDiff, indent: number = 0): string {
  const prefix = '  '.repeat(indent);
  const icon = diff.match ? '✓' : '✗';
  const iouStr = (diff.iou * 100).toFixed(1) + '%';

  let lines: string[] = [];

  if (diff.match) {
    lines.push(`${prefix}${icon} ${diff.id} [IoU: ${iouStr}]`);
  } else {
    lines.push(`${prefix}${icon} ${diff.id} [IoU: ${iouStr}]`);
    lines.push(`${prefix}    browser: (${diff.browser.x.toFixed(1)}, ${diff.browser.y.toFixed(1)}) ${diff.browser.width.toFixed(1)}×${diff.browser.height.toFixed(1)}`);
    lines.push(`${prefix}    crater:  (${diff.crater.x.toFixed(1)}, ${diff.crater.y.toFixed(1)}) ${diff.crater.width.toFixed(1)}×${diff.crater.height.toFixed(1)}`);
    lines.push(`${prefix}    diff:    Δx=${diff.diff.x.toFixed(1)} Δy=${diff.diff.y.toFixed(1)} Δw=${diff.diff.width.toFixed(1)} Δh=${diff.diff.height.toFixed(1)}`);
  }

  for (const child of diff.children) {
    lines.push(formatDiffTree(child, indent + 1));
  }

  return lines.join('\n');
}

function generateHtmlReport(report: DiffReport, htmlContent: string): string {
  function renderDiffNode(diff: RectDiff, scale: number): string {
    const color = diff.match ? 'rgba(34, 197, 94, 0.3)' : 'rgba(239, 68, 68, 0.5)';
    const borderColor = diff.match ? '#22c55e' : '#ef4444';

    let html = `
      <div style="position: absolute; left: ${diff.browser.x * scale}px; top: ${diff.browser.y * scale}px;
                  width: ${diff.browser.width * scale}px; height: ${diff.browser.height * scale}px;
                  background: ${color}; border: 1px solid ${borderColor}; box-sizing: border-box;"
           title="${diff.id}&#10;IoU: ${(diff.iou * 100).toFixed(1)}%">
      </div>
    `;

    if (!diff.match) {
      // Show crater position as dashed outline
      html += `
        <div style="position: absolute; left: ${diff.crater.x * scale}px; top: ${diff.crater.y * scale}px;
                    width: ${diff.crater.width * scale}px; height: ${diff.crater.height * scale}px;
                    border: 2px dashed #3b82f6; box-sizing: border-box; pointer-events: none;">
        </div>
      `;
    }

    for (const child of diff.children) {
      html += renderDiffNode(child, scale);
    }

    return html;
  }

  const scale = 0.5;
  const matchColor = report.matchRate >= 0.95 ? '#22c55e' : report.matchRate >= 0.8 ? '#eab308' : '#ef4444';

  return `<!DOCTYPE html>
<html>
<head>
  <title>Layout Diff: ${report.file}</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .header { margin-bottom: 20px; }
    .stats { display: flex; gap: 20px; margin-bottom: 20px; }
    .stat { background: white; padding: 15px 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .stat-value { font-size: 24px; font-weight: bold; }
    .stat-label { font-size: 12px; color: #666; }
    .container { display: flex; gap: 20px; }
    .panel { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .panel h3 { margin-top: 0; }
    .preview { position: relative; border: 1px solid #ddd; background: white; }
    .legend { display: flex; gap: 15px; margin-top: 10px; font-size: 12px; }
    .legend-item { display: flex; align-items: center; gap: 5px; }
    .legend-box { width: 16px; height: 16px; border-radius: 2px; }
    pre { background: #f0f0f0; padding: 15px; border-radius: 4px; overflow: auto; max-height: 400px; font-size: 12px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>Layout Diff Report</h1>
    <p>File: ${report.file}</p>
  </div>

  <div class="stats">
    <div class="stat">
      <div class="stat-value" style="color: ${matchColor}">${(report.matchRate * 100).toFixed(1)}%</div>
      <div class="stat-label">Match Rate</div>
    </div>
    <div class="stat">
      <div class="stat-value">${(report.averageIoU * 100).toFixed(1)}%</div>
      <div class="stat-label">Average IoU</div>
    </div>
    <div class="stat">
      <div class="stat-value">${report.matchedNodes}/${report.totalNodes}</div>
      <div class="stat-label">Matched Nodes</div>
    </div>
    <div class="stat">
      <div class="stat-value">${report.mismatchedNodes}</div>
      <div class="stat-label">Mismatches</div>
    </div>
  </div>

  <div class="container">
    <div class="panel">
      <h3>Visual Diff</h3>
      <div class="preview" style="width: ${VIEWPORT.width * scale}px; height: ${VIEWPORT.height * scale}px;">
        ${renderDiffNode(report.diffs, scale)}
      </div>
      <div class="legend">
        <div class="legend-item">
          <div class="legend-box" style="background: rgba(34, 197, 94, 0.3); border: 1px solid #22c55e;"></div>
          <span>Match</span>
        </div>
        <div class="legend-item">
          <div class="legend-box" style="background: rgba(239, 68, 68, 0.5); border: 1px solid #ef4444;"></div>
          <span>Mismatch (Browser)</span>
        </div>
        <div class="legend-item">
          <div class="legend-box" style="border: 2px dashed #3b82f6;"></div>
          <span>Crater position</span>
        </div>
      </div>
    </div>

    <div class="panel" style="flex: 1;">
      <h3>Diff Tree</h3>
      <pre>${formatDiffTree(report.diffs)}</pre>
    </div>
  </div>
</body>
</html>`;
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help')) {
    console.log(`
Layout Diff Tool - Compare Chrome and Crater layouts

Usage:
  npx tsx scripts/layout-diff.ts <html-file> [options]

Options:
  --html              Generate HTML visual report
  --json              Output JSON diff data
  --threshold <px>    Tolerance for matching (default: 5px)
  --help              Show this help

Examples:
  npx tsx scripts/layout-diff.ts tailwind-tests/flex-basic.html
  npx tsx scripts/layout-diff.ts my-component.html --html > report.html
  npx tsx scripts/layout-diff.ts my-component.html --threshold 10
`);
    process.exit(0);
  }

  const htmlFile = args.find(a => !a.startsWith('--'));
  if (!htmlFile || !fs.existsSync(htmlFile)) {
    console.error(`Error: HTML file not found: ${htmlFile}`);
    process.exit(1);
  }

  const outputHtml = args.includes('--html');
  const outputJson = args.includes('--json');
  const thresholdIdx = args.indexOf('--threshold');
  const threshold = thresholdIdx !== -1 ? parseInt(args[thresholdIdx + 1]) : DEFAULT_THRESHOLD;

  const htmlContent = prepareHtmlContent(htmlFile);

  console.error('Rendering in browser...');
  const browserLayout = await getBrowserLayout(htmlContent);

  console.error('Rendering in Crater...');
  const craterLayout = getCraterLayout(htmlContent);
  const normalizedCrater = normalizeCraterPositions(craterLayout);

  console.error('Comparing layouts...');
  const diff = compareNodes(browserLayout, normalizedCrater, threshold);
  const report = generateReport(htmlFile, diff);

  if (outputJson) {
    console.log(JSON.stringify(report, null, 2));
  } else if (outputHtml) {
    console.log(generateHtmlReport(report, htmlContent));
  } else {
    // Console output
    const matchColor = report.matchRate >= 0.95 ? '\x1b[32m' : report.matchRate >= 0.8 ? '\x1b[33m' : '\x1b[31m';
    const reset = '\x1b[0m';

    console.log(`\n${'='.repeat(60)}`);
    console.log(`Layout Diff Report: ${report.file}`);
    console.log(`${'='.repeat(60)}\n`);

    console.log(`Match Rate:    ${matchColor}${(report.matchRate * 100).toFixed(1)}%${reset}`);
    console.log(`Average IoU:   ${(report.averageIoU * 100).toFixed(1)}%`);
    console.log(`Matched:       ${report.matchedNodes}/${report.totalNodes} nodes`);
    console.log(`Mismatches:    ${report.mismatchedNodes} nodes`);
    console.log(`Threshold:     ${threshold}px\n`);

    console.log('Diff Tree:');
    console.log('-'.repeat(60));
    console.log(formatDiffTree(report.diffs));
  }
}

main().catch(console.error);
