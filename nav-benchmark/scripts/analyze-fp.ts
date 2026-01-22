/**
 * Analyze false positives to understand over-prediction.
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../../wasm/dist/crater.js';

const AEB_PATH = path.join(process.env.HOME || '', 'ghq/github.com/scrapinghub/article-extraction-benchmark');
const LABELS_DIR = path.join(process.cwd(), 'nav-benchmark/labels');
const LAYOUT_DIR = path.join(process.cwd(), 'render-results/aeb-layout');

interface Rect { x: number; y: number; width: number; height: number; }

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

// NAV detection (same as evaluate.ts)
const NAV_ROLES = new Set(['navigation', 'banner', 'contentinfo', 'complementary', 'menubar', 'menu', 'toolbar']);
const NAV_TAGS = new Set(['nav', 'header', 'footer', 'aside']);
const NAV_PATTERNS = ['nav', 'menu', 'navbar', 'topbar', 'toplinks', 'footer', 'header', 'sidebar', 'breadcrumb', 'masthead', 'site-nav', 'site-navs', 'site_header', 'site-footer', 'siteheader', 'sitefooter'];
const WIDGET_PATTERNS = ['widget', 'textwidget', 'page_item', 'page-item', 'cat-item', 'syndication', 'blogroll', 'rsswidget', 'col1', 'col2', 'col3', 'col4', 'col5'];

function containsPattern(value: string | undefined, patterns: string[]) {
  if (!value) return false;
  const v = value.toLowerCase();
  return patterns.some(p => v.includes(p));
}

interface AomNode {
  role?: string;
  tag?: string;
  selector?: string;
  children?: AomNode[];
}

interface PredictedNav {
  selector: string;
  reason: string;
  linkCount: number;
  linkRatio: number;
}

function collectNavSelectorsWithReason(node: AomNode, ctx: { navAncestor: boolean }): { navs: PredictedNav[]; linkCount: number; totalCount: number } {
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const selector = node.selector;
  const navContainer = NAV_ROLES.has(role) || NAV_TAGS.has(tag);
  const navAncestor = ctx.navAncestor || navContainer;

  let linkCount = role === 'link' ? 1 : 0;
  let totalCount = 1;
  const navs: PredictedNav[] = [];
  const children = Array.isArray(node.children) ? node.children : [];

  for (const child of children) {
    const childResult = collectNavSelectorsWithReason(child, { navAncestor });
    linkCount += childResult.linkCount;
    totalCount += childResult.totalCount;
    navs.push(...childResult.navs);
  }

  const linkRatio = totalCount > 0 ? linkCount / totalCount : 0;

  // Check reasons
  let reason = '';
  if (NAV_ROLES.has(role)) reason = `role:${role}`;
  else if (NAV_TAGS.has(tag)) reason = `tag:${tag}`;
  else if (containsPattern(selector, NAV_PATTERNS)) reason = `pattern:nav`;
  else if (containsPattern(selector, WIDGET_PATTERNS) && linkCount >= 1) reason = `pattern:widget`;
  else if (linkCount >= 3 && linkRatio >= 0.3) reason = `structure:links(${linkCount},${(linkRatio*100).toFixed(0)}%)`;

  if (reason && selector) {
    navs.push({ selector, reason, linkCount, linkRatio });
  }

  return { navs, linkCount, totalCount };
}

async function main() {
  // Pick a high-FP case
  const hash = 'fde930b01859de8311c6a14f8aa8c72be0659b551367803deb6736cf3526cf2e'; // businessinsider - F1=22.7%, FP=32

  const label = JSON.parse(fs.readFileSync(path.join(LABELS_DIR, `${hash}.json`), 'utf-8'));
  const layout = JSON.parse(fs.readFileSync(path.join(LAYOUT_DIR, `${hash}.json`), 'utf-8'));
  const html = loadHtml(hash);

  // Build selector -> rect map
  const selectorToRect = new Map<string, Rect>();
  for (const node of layout.nodes) {
    if (node.selector && node.rect) {
      selectorToRect.set(node.selector, node.rect);
    }
  }

  // Get predictions with reasons
  const snapshot = JSON.parse(accessibility.getAriaSnapshotJson(html));
  const { navs } = collectNavSelectorsWithReason(snapshot, { navAncestor: false });

  // Ground truth rects
  const gtRects = label.nav_regions.map((r: any) => r.rect);

  console.log(`=== Analysis: ${hash.slice(0, 16)} (${label.url}) ===`);
  console.log(`Ground truth regions: ${gtRects.length}`);
  console.log(`Predicted nav selectors: ${navs.length}`);
  console.log('');

  // Categorize predictions
  const truePositives: PredictedNav[] = [];
  const falsePositives: PredictedNav[] = [];

  for (const nav of navs) {
    const rect = selectorToRect.get(nav.selector);
    if (!rect || rect.width < 50 || rect.height < 20) continue;

    let matched = false;
    for (const gt of gtRects) {
      if (computeIoU(rect, gt) >= 0.5) {
        matched = true;
        break;
      }
    }

    if (matched) {
      truePositives.push(nav);
    } else {
      falsePositives.push(nav);
    }
  }

  console.log(`True Positives: ${truePositives.length}`);
  for (const nav of truePositives.slice(0, 5)) {
    console.log(`  ✓ ${nav.selector.slice(0, 60)} | ${nav.reason}`);
  }

  console.log('');
  console.log(`False Positives: ${falsePositives.length}`);

  // Group FPs by reason
  const fpByReason = new Map<string, PredictedNav[]>();
  for (const nav of falsePositives) {
    const key = nav.reason.split(':')[0];
    if (!fpByReason.has(key)) fpByReason.set(key, []);
    fpByReason.get(key)!.push(nav);
  }

  for (const [reason, navs] of fpByReason) {
    console.log(`\n  [${reason}] ${navs.length} FPs:`);
    for (const nav of navs.slice(0, 5)) {
      const rect = selectorToRect.get(nav.selector);
      const size = rect ? `${rect.width}x${rect.height}` : 'no-rect';
      console.log(`    ✗ ${nav.selector.slice(0, 50)} | ${nav.reason} | ${size}`);
    }
    if (navs.length > 5) {
      console.log(`    ... and ${navs.length - 5} more`);
    }
  }
}

main().catch(console.error);
