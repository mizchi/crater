/**
 * Evaluate nav extraction against labeled ground truth using IoU.
 *
 * Usage:
 *   npx tsx nav-benchmark/scripts/evaluate.ts
 *   npx tsx nav-benchmark/scripts/evaluate.ts --hash <hash>
 *   npx tsx nav-benchmark/scripts/evaluate.ts --iou-threshold 0.3
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../../wasm/dist/crater.js';

const AEB_PATH = path.join(
  process.env.HOME || '',
  'ghq/github.com/scrapinghub/article-extraction-benchmark'
);

const LABELS_DIR = path.join(process.cwd(), 'nav-benchmark/labels');
const LAYOUT_DIR = path.join(process.cwd(), 'render-results/aeb-layout');

interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface NavRegion {
  id: string;
  type: string;
  selector: string;
  rect: Rect;
  confidence: string;
}

interface Label {
  hash: string;
  url: string | null;
  viewport: { width: number; height: number };
  nav_regions: NavRegion[];
  notes: string;
  status: string;
}

interface LayoutNode {
  selector?: string;
  rect?: Rect;
  isNavCandidate?: boolean;
}

interface LayoutDump {
  hash: string;
  nodes: LayoutNode[];
}

interface AomNode {
  role?: string;
  tag?: string;
  selector?: string;
  children?: AomNode[];
}

// IoU calculation
function computeIoU(a: Rect, b: Rect): number {
  const xOverlap = Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x));
  const yOverlap = Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
  const intersection = xOverlap * yOverlap;

  const areaA = a.width * a.height;
  const areaB = b.width * b.height;
  const union = areaA + areaB - intersection;

  return union > 0 ? intersection / union : 0;
}

// Load functions
function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  const gzipped = fs.readFileSync(htmlPath);
  return gunzipSync(gzipped).toString('utf-8');
}

function loadLabel(hash: string): Label | null {
  const file = path.join(LABELS_DIR, `${hash}.json`);
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf-8'));
}

function loadLayoutDump(hash: string): LayoutDump | null {
  const file = path.join(LAYOUT_DIR, `${hash}.json`);
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf-8'));
}

// NAV detection patterns (same as aeb-nav-eval.ts)
const NAV_ROLES = new Set(['navigation', 'banner', 'contentinfo', 'complementary', 'menubar', 'menu', 'toolbar']);
const NAV_TAGS = new Set(['nav', 'header', 'footer', 'aside']);
const NAV_PATTERNS = ['nav', 'menu', 'navbar', 'topbar', 'toplinks', 'footer', 'header', 'sidebar', 'breadcrumb', 'masthead', 'site-nav', 'site-navs', 'site_header', 'site-footer', 'siteheader', 'sitefooter'];
const WIDGET_PATTERNS = ['widget', 'textwidget', 'page_item', 'page-item', 'cat-item', 'syndication', 'blogroll', 'rsswidget', 'col1', 'col2', 'col3', 'col4', 'col5'];

function containsPattern(value: string | undefined, patterns: string[]) {
  if (!value) return false;
  const v = value.toLowerCase();
  return patterns.some(p => v.includes(p));
}

function isNavNode(node: AomNode): boolean {
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const selector = node.selector?.toLowerCase() || '';
  if (NAV_ROLES.has(role)) return true;
  if (NAV_TAGS.has(tag)) return true;
  if (containsPattern(selector, NAV_PATTERNS)) return true;
  return false;
}

function isWidgetNav(node: AomNode, linkCount: number): boolean {
  if (linkCount < 1) return false;
  const selector = node.selector?.toLowerCase() || '';
  return containsPattern(selector, WIDGET_PATTERNS);
}

// Collect nav selectors from AOM
function collectNavSelectors(node: AomNode, ctx: { navAncestor: boolean }): { selectors: Set<string>; linkCount: number } {
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const selector = node.selector;
  const navContainer = NAV_ROLES.has(role) || NAV_TAGS.has(tag);
  const navAncestor = ctx.navAncestor || navContainer;

  let linkCount = role === 'link' ? 1 : 0;
  const selectors = new Set<string>();
  const children = Array.isArray(node.children) ? node.children : [];

  for (const child of children) {
    const childResult = collectNavSelectors(child, { navAncestor });
    linkCount += childResult.linkCount;
    for (const sel of childResult.selectors) {
      selectors.add(sel);
    }
  }

  const navByHint = isNavNode(node);
  const navByWidget = isWidgetNav(node, linkCount);
  const linkRatio = linkCount > 0 ? linkCount / (children.length + 1) : 0;
  const navByStructure = linkCount >= 3 && linkRatio >= 0.3;

  if ((navByHint || navByStructure || navByWidget) && selector) {
    selectors.add(selector);
  }

  return { selectors, linkCount };
}

// Get predicted nav regions by matching selectors to layout
function getPredictedRegions(hash: string): Rect[] {
  const html = loadHtml(hash);
  const layout = loadLayoutDump(hash);
  if (!layout) return [];

  // Build selector -> rect map from layout
  const selectorToRect = new Map<string, Rect>();
  for (const node of layout.nodes) {
    if (node.selector && node.rect) {
      selectorToRect.set(node.selector, node.rect);
    }
  }

  // Get nav selectors from AOM
  const snapshotJson = accessibility.getAriaSnapshotJson(html);
  const snapshot: AomNode = JSON.parse(snapshotJson);
  const { selectors } = collectNavSelectors(snapshot, { navAncestor: false });

  // Map selectors to rects
  const regions: Rect[] = [];
  for (const selector of selectors) {
    const rect = selectorToRect.get(selector);
    if (rect && rect.width > 50 && rect.height > 20) {
      regions.push(rect);
    }
  }

  return regions;
}

// Match predicted regions to ground truth
function matchRegions(predicted: Rect[], groundTruth: Rect[], iouThreshold: number): {
  truePositives: number;
  falsePositives: number;
  falseNegatives: number;
  matches: Array<{ pred: Rect; gt: Rect; iou: number }>;
} {
  const matches: Array<{ pred: Rect; gt: Rect; iou: number }> = [];
  const matchedGt = new Set<number>();
  const matchedPred = new Set<number>();

  // For each predicted region, find best matching ground truth
  for (let i = 0; i < predicted.length; i++) {
    let bestIou = 0;
    let bestJ = -1;

    for (let j = 0; j < groundTruth.length; j++) {
      if (matchedGt.has(j)) continue;
      const iou = computeIoU(predicted[i], groundTruth[j]);
      if (iou > bestIou) {
        bestIou = iou;
        bestJ = j;
      }
    }

    if (bestIou >= iouThreshold && bestJ >= 0) {
      matches.push({ pred: predicted[i], gt: groundTruth[bestJ], iou: bestIou });
      matchedPred.add(i);
      matchedGt.add(bestJ);
    }
  }

  return {
    truePositives: matches.length,
    falsePositives: predicted.length - matches.length,
    falseNegatives: groundTruth.length - matches.length,
    matches,
  };
}

async function main() {
  const args = process.argv.slice(2);
  let specificHash: string | null = null;
  let iouThreshold = 0.5;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--hash' && args[i + 1]) {
      specificHash = args[i + 1];
    } else if (args[i] === '--iou-threshold' && args[i + 1]) {
      iouThreshold = parseFloat(args[i + 1]);
    }
  }

  // Load all labels
  const labelFiles = fs.readdirSync(LABELS_DIR).filter(f => f.endsWith('.json'));
  const labels = labelFiles.map(f => {
    const hash = f.replace('.json', '');
    return { hash, label: loadLabel(hash)! };
  }).filter(x => x.label);

  const targets = specificHash
    ? labels.filter(x => x.hash.startsWith(specificHash!))
    : labels;

  console.log(`Evaluating ${targets.length} samples (IoU threshold: ${iouThreshold})`);
  console.log('');

  let totalTP = 0;
  let totalFP = 0;
  let totalFN = 0;

  const results: Array<{
    hash: string;
    domain: string;
    precision: number;
    recall: number;
    f1: number;
    tp: number;
    fp: number;
    fn: number;
  }> = [];

  for (const { hash, label } of targets) {
    const groundTruth = label.nav_regions.map(r => r.rect);

    let predicted: Rect[];
    try {
      predicted = getPredictedRegions(hash);
    } catch (e) {
      console.log(`Error processing ${hash.slice(0, 16)}: ${e}`);
      continue;
    }

    const { truePositives, falsePositives, falseNegatives } = matchRegions(
      predicted,
      groundTruth,
      iouThreshold
    );

    totalTP += truePositives;
    totalFP += falsePositives;
    totalFN += falseNegatives;

    const precision = predicted.length > 0 ? truePositives / predicted.length : 0;
    const recall = groundTruth.length > 0 ? truePositives / groundTruth.length : 0;
    const f1 = precision + recall > 0 ? (2 * precision * recall) / (precision + recall) : 0;

    const domain = label.url ? new URL(label.url).hostname : 'unknown';

    results.push({
      hash,
      domain,
      precision,
      recall,
      f1,
      tp: truePositives,
      fp: falsePositives,
      fn: falseNegatives,
    });
  }

  // Sort by F1
  results.sort((a, b) => a.f1 - b.f1);

  // Print per-sample results
  console.log('=== Per-sample Results ===');
  for (const r of results) {
    const pct = (v: number) => (v * 100).toFixed(1).padStart(5) + '%';
    console.log(
      `${r.hash.slice(0, 16)} | F1=${pct(r.f1)} P=${pct(r.precision)} R=${pct(r.recall)} | TP=${r.tp} FP=${r.fp} FN=${r.fn} | ${r.domain}`
    );
  }

  // Aggregate metrics
  const totalPrecision = totalTP + totalFP > 0 ? totalTP / (totalTP + totalFP) : 0;
  const totalRecall = totalTP + totalFN > 0 ? totalTP / (totalTP + totalFN) : 0;
  const totalF1 = totalPrecision + totalRecall > 0
    ? (2 * totalPrecision * totalRecall) / (totalPrecision + totalRecall)
    : 0;

  console.log('');
  console.log('=== Aggregate Metrics ===');
  console.log(`Precision: ${(totalPrecision * 100).toFixed(2)}%`);
  console.log(`Recall:    ${(totalRecall * 100).toFixed(2)}%`);
  console.log(`F1:        ${(totalF1 * 100).toFixed(2)}%`);
  console.log(`TP: ${totalTP}, FP: ${totalFP}, FN: ${totalFN}`);
}

main().catch(console.error);
