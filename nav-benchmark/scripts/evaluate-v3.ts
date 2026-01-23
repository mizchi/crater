/**
 * Evaluate nav extraction - balanced approach.
 *
 * v3: Balance between precision and recall
 * - Keep semantic nav detection (good recall)
 * - Stricter structure-based detection
 * - Better exclusion patterns
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../../wasm/dist/crater.js';

const AEB_PATH = path.join(process.env.HOME || '', 'ghq/github.com/scrapinghub/article-extraction-benchmark');
const LABELS_DIR = path.join(process.cwd(), 'nav-benchmark/labels');
const LAYOUT_DIR = path.join(process.cwd(), 'render-results/aeb-layout');

interface Rect { x: number; y: number; width: number; height: number; }
interface AomNode { role?: string; tag?: string; selector?: string; children?: AomNode[]; }

function computeIoU(a: Rect, b: Rect): number {
  const xOverlap = Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x));
  const yOverlap = Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
  const intersection = xOverlap * yOverlap;
  const union = a.width * a.height + b.width * b.height - intersection;
  return union > 0 ? intersection / union : 0;
}

function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  return gunzipSync(fs.readFileSync(htmlPath)).toString('utf-8');
}

// Balanced NAV detection
const NAV_ROLES = new Set(['navigation', 'banner', 'contentinfo', 'complementary', 'menubar', 'menu', 'toolbar']);
const NAV_TAGS = new Set(['nav', 'header', 'footer', 'aside']);
const NAV_PATTERNS = ['navbar', 'nav-', '-nav', 'main-menu', 'site-menu', 'primary-menu', 'masthead', 'topbar', 'site-header', 'site-footer', 'breadcrumb'];
const WIDGET_PATTERNS = ['widget', 'page_item', 'page-item', 'cat-item'];

// Stronger exclusion (content, not nav)
const EXCLUDE_PATTERNS = [
  'social', 'share', 'related', 'recommend', 'popular', 'trending',
  'comment', 'author', 'byline', 'article-', 'story-', 'post-',
  'ad-', 'advert', 'sponsor', 'promo',
  'vertical', 'section.top', 'section.bottom', 'section.social'
];

function containsPattern(value: string | undefined, patterns: string[]) {
  if (!value) return false;
  const v = value.toLowerCase();
  return patterns.some(p => v.includes(p));
}

function shouldExclude(selector: string): boolean {
  const s = selector.toLowerCase();
  // Don't exclude if it's a semantic nav tag
  if (s.startsWith('nav') || s.startsWith('header') || s.startsWith('footer')) {
    return false;
  }
  return EXCLUDE_PATTERNS.some(p => s.includes(p));
}

function collectNavSelectorsBalanced(node: AomNode, ctx: { navAncestor: boolean }): { selectors: Set<string>; linkCount: number; totalCount: number } {
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const selector = node.selector || '';

  const isSemanticNav = NAV_ROLES.has(role) || NAV_TAGS.has(tag);
  const navAncestor = ctx.navAncestor || isSemanticNav;

  let linkCount = role === 'link' ? 1 : 0;
  let totalCount = 1;
  const selectors = new Set<string>();
  const children = Array.isArray(node.children) ? node.children : [];

  for (const child of children) {
    const childResult = collectNavSelectorsBalanced(child, { navAncestor });
    linkCount += childResult.linkCount;
    totalCount += childResult.totalCount;
    for (const sel of childResult.selectors) {
      selectors.add(sel);
    }
  }

  // Skip excluded patterns (unless semantic nav)
  if (selector && shouldExclude(selector) && !isSemanticNav) {
    return { selectors, linkCount, totalCount };
  }

  const linkRatio = totalCount > 0 ? linkCount / totalCount : 0;
  let isNav = false;

  // Rule 1: Semantic nav element (always include)
  if (isSemanticNav) {
    isNav = true;
  }

  // Rule 2: Strong nav pattern match
  if (!isNav && containsPattern(selector, NAV_PATTERNS)) {
    isNav = true;
  }

  // Rule 3: Widget pattern with links
  if (!isNav && containsPattern(selector, WIDGET_PATTERNS) && linkCount >= 2) {
    isNav = true;
  }

  // Rule 4: Structure-based (stricter than v1)
  // Require more links AND within nav ancestor OR list element
  if (!isNav && linkCount >= 4 && linkRatio >= 0.35) {
    if (navAncestor || tag === 'ul' || tag === 'ol' || role === 'list') {
      isNav = true;
    }
  }

  if (isNav && selector) {
    selectors.add(selector);
  }

  return { selectors, linkCount, totalCount };
}

function getPredictedRegions(hash: string): Rect[] {
  const html = loadHtml(hash);
  const layoutFile = path.join(LAYOUT_DIR, `${hash}.json`);
  if (!fs.existsSync(layoutFile)) return [];
  const layout = JSON.parse(fs.readFileSync(layoutFile, 'utf-8'));

  const selectorToRect = new Map<string, Rect>();
  for (const node of layout.nodes) {
    if (node.selector && node.rect) {
      selectorToRect.set(node.selector, node.rect);
    }
  }

  const snapshot = JSON.parse(accessibility.getAriaSnapshotJson(html));
  const { selectors } = collectNavSelectorsBalanced(snapshot, { navAncestor: false });

  const regions: Rect[] = [];
  for (const selector of selectors) {
    const rect = selectorToRect.get(selector);
    if (rect && rect.width > 50 && rect.height > 20) {
      regions.push(rect);
    }
  }

  return regions;
}

function matchRegions(predicted: Rect[], groundTruth: Rect[], iouThreshold: number) {
  let truePositives = 0;
  const matchedGt = new Set<number>();

  for (const pred of predicted) {
    let bestIou = 0;
    let bestJ = -1;

    for (let j = 0; j < groundTruth.length; j++) {
      if (matchedGt.has(j)) continue;
      const iou = computeIoU(pred, groundTruth[j]);
      if (iou > bestIou) {
        bestIou = iou;
        bestJ = j;
      }
    }

    if (bestIou >= iouThreshold && bestJ >= 0) {
      truePositives++;
      matchedGt.add(bestJ);
    }
  }

  return {
    truePositives,
    falsePositives: predicted.length - truePositives,
    falseNegatives: groundTruth.length - truePositives,
  };
}

async function main() {
  const iouThreshold = 0.5;
  const labelFiles = fs.readdirSync(LABELS_DIR).filter(f => f.endsWith('.json'));

  console.log(`Evaluating ${labelFiles.length} samples (balanced rules, IoU=${iouThreshold})`);
  console.log('');

  let totalTP = 0, totalFP = 0, totalFN = 0;
  const results: Array<{ hash: string; f1: number; p: number; r: number; tp: number; fp: number; fn: number }> = [];

  for (const file of labelFiles) {
    const hash = file.replace('.json', '');
    const label = JSON.parse(fs.readFileSync(path.join(LABELS_DIR, file), 'utf-8'));
    const gtRects = label.nav_regions.map((r: any) => r.rect);

    let predicted: Rect[];
    try {
      predicted = getPredictedRegions(hash);
    } catch (e) {
      continue;
    }

    const { truePositives, falsePositives, falseNegatives } = matchRegions(predicted, gtRects, iouThreshold);
    totalTP += truePositives;
    totalFP += falsePositives;
    totalFN += falseNegatives;

    const p = predicted.length > 0 ? truePositives / predicted.length : 0;
    const r = gtRects.length > 0 ? truePositives / gtRects.length : 0;
    const f1 = p + r > 0 ? (2 * p * r) / (p + r) : 0;

    results.push({ hash: hash.slice(0, 16), f1, p, r, tp: truePositives, fp: falsePositives, fn: falseNegatives });
  }

  results.sort((a, b) => a.f1 - b.f1);

  console.log('=== Per-sample Results ===');
  for (const r of results) {
    const pct = (v: number) => (v * 100).toFixed(1).padStart(5) + '%';
    console.log(`${r.hash} | F1=${pct(r.f1)} P=${pct(r.p)} R=${pct(r.r)} | TP=${r.tp} FP=${r.fp} FN=${r.fn}`);
  }

  const totalP = totalTP + totalFP > 0 ? totalTP / (totalTP + totalFP) : 0;
  const totalR = totalTP + totalFN > 0 ? totalTP / (totalTP + totalFN) : 0;
  const totalF1 = totalP + totalR > 0 ? (2 * totalP * totalR) / (totalP + totalR) : 0;

  console.log('');
  console.log('=== Aggregate (Balanced) ===');
  console.log(`Precision: ${(totalP * 100).toFixed(2)}%`);
  console.log(`Recall:    ${(totalR * 100).toFixed(2)}%`);
  console.log(`F1:        ${(totalF1 * 100).toFixed(2)}%`);
  console.log(`TP: ${totalTP}, FP: ${totalFP}, FN: ${totalFN}`);
}

main().catch(console.error);
