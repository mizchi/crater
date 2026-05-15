/**
 * Evaluate navigation extraction with weak labels from layout dump.
 *
 * Usage:
 *   npx tsx scripts/aeb-nav-eval.ts
 *   npx tsx scripts/aeb-nav-eval.ts --limit 50
 *   npx tsx scripts/aeb-nav-eval.ts --hash <hash>
 *   npx tsx scripts/aeb-nav-eval.ts --layout-dir render-results/aeb-layout
 *   npx tsx scripts/aeb-nav-eval.ts --show 10
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../wasm/dist/crater.js';

const AEB_PATH = path.join(
  process.env.HOME || '',
  'ghq/github.com/scrapinghub/article-extraction-benchmark'
);

interface GroundTruth {
  [key: string]: {
    articleBody: string;
    url?: string;
  };
}

interface LayoutNode {
  tag?: string;
  id?: string;
  className?: string;
  role?: string;
  ariaLabel?: string;
  textLen?: number;
  linkDensity?: number;
  selector?: string | null;
  isNavCandidate?: boolean;
  isAdCandidate?: boolean;
}

interface LayoutDump {
  hash: string;
  url?: string | null;
  nodes: LayoutNode[];
}

interface AomNode {
  role?: string;
  tag?: string;
  selector?: string;
  name?: string;
  visible?: boolean;
  children?: AomNode[];
}

const NAV_ROLES = new Set([
  'navigation',
  'banner',
  'contentinfo',
  'complementary',
  'menubar',
  'menu',
  'toolbar',
]);
const NAV_TAGS = new Set(['nav', 'header', 'footer', 'aside']);
const NAV_PATTERNS = [
  'nav',
  'menu',
  'navbar',
  'topbar',
  'toplinks',
  'footer',
  'header',
  'sidebar',
  'breadcrumb',
  'masthead',
  'site-nav',
  'site-navs',
  'site_header',
  'site-footer',
  'siteheader',
  'sitefooter',
];
const META_PATTERNS = [
  'share',
  'social',
  'subscribe',
  'newsletter',
  'author',
  'byline',
  'contrib',
  'comment',
  'comments',
  'related',
  'promo',
  'sponsor',
  'advert',
  'ad-',
  'cookie',
  'privacy',
  'terms',
  'copyright',
  'legal',
  'affiliate',
  'signup',
  'print',
  'correction',
];

interface AomNavInfo {
  role?: string;
  tag?: string;
  name?: string;
  linkCount: number;
  totalCount: number;
  linkRatio: number;
  navByHint: boolean;
  navByStructure: boolean;
  navContainer: boolean;
  navAncestor: boolean;
}

function loadGroundTruth(): GroundTruth {
  const groundTruthPath = path.join(AEB_PATH, 'ground-truth.json');
  if (!fs.existsSync(groundTruthPath)) {
    throw new Error(`Ground truth not found at ${groundTruthPath}. Run: ghq get scrapinghub/article-extraction-benchmark`);
  }
  return JSON.parse(fs.readFileSync(groundTruthPath, 'utf-8'));
}

function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`HTML file not found: ${htmlPath}`);
  }
  const gzipped = fs.readFileSync(htmlPath);
  return gunzipSync(gzipped).toString('utf-8');
}

function buildSelector(tag?: string, id?: string, className?: string): string | null {
  if (!tag) return null;
  const base = tag.toLowerCase();
  if (id) {
    return `${base}#${id}`;
  }
  const classes = String(className || '')
    .split(/\s+/)
    .map(s => s.trim())
    .filter(Boolean);
  if (classes.length === 0) {
    return base;
  }
  return `${base}.${classes.join('.')}`;
}

function containsPattern(value: string | undefined, patterns: string[]) {
  if (!value) return false;
  const v = value.toLowerCase();
  return patterns.some(p => v.includes(p));
}

function isListTag(tag?: string) {
  if (!tag) return false;
  const t = tag.toLowerCase();
  return t === 'ul' || t === 'ol' || t === 'menu';
}

// Widget patterns that indicate nav-like content when combined with links
const WIDGET_PATTERNS = [
  'widget',
  'textwidget',
  'page_item',
  'page-item',
  'cat-item',
  'syndication',
  'blogroll',
  'rsswidget',
  // Column-based navigation patterns (e.g., li.col1-10, li.col2-10)
  'col1',
  'col2',
  'col3',
  'col4',
  'col5',
];

function isNavNode(node: AomNode): boolean {
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const name = node.name?.toLowerCase() || '';
  const selector = node.selector?.toLowerCase() || '';
  if (NAV_ROLES.has(role)) return true;
  if (NAV_TAGS.has(tag)) return true;
  if (containsPattern(name, NAV_PATTERNS)) return true;
  if (containsPattern(selector, NAV_PATTERNS)) return true;
  return false;
}

function isWidgetNav(node: AomNode, linkCount: number): boolean {
  if (linkCount < 1) return false;
  const selector = node.selector?.toLowerCase() || '';
  return containsPattern(selector, WIDGET_PATTERNS);
}

function collectNavSelectors(
  node: AomNode,
  out: Set<string>,
  listOut: Set<string>,
  infoMap: Map<string, AomNavInfo>,
  stats: { noSelector: number },
  ctx: { navAncestor: boolean }
): { linkCount: number; totalCount: number } {
  if (node.visible === false) {
    return { linkCount: 0, totalCount: 0 };
  }
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const name = node.name;
  const selector = node.selector;
  const navContainer = NAV_ROLES.has(role) || NAV_TAGS.has(tag);
  const navAncestor = ctx.navAncestor || navContainer;
  let linkCount = role === 'link' ? 1 : 0;
  let totalCount = 1;
  const children = Array.isArray(node.children) ? node.children : [];
  for (const child of children) {
    const childStats = collectNavSelectors(child, out, listOut, infoMap, stats, { navAncestor });
    linkCount += childStats.linkCount;
    totalCount += childStats.totalCount;
  }
  const navByHint = isNavNode(node);
  const navByWidget = isWidgetNav(node, linkCount);
  const linkRatio = totalCount > 0 ? linkCount / totalCount : 0;
  const navByStructure = linkCount >= 3 && linkRatio >= 0.3;
  if (navByHint || navByStructure || navByWidget) {
    if (selector) {
      out.add(selector);
      infoMap.set(selector, {
        role,
        tag,
        name,
        linkCount,
        totalCount,
        linkRatio,
        navByHint,
        navByStructure,
        navContainer,
        navAncestor,
      });
    } else {
      stats.noSelector += 1;
    }
  }
  // Collect list elements and widget elements for hierarchical nav detection
  const isListElement = isListTag(tag) || role === 'list' || role === 'listitem';
  if (selector && (navAncestor && isListElement) || navByWidget) {
    listOut.add(selector);
    if (!infoMap.has(selector)) {
      infoMap.set(selector, {
        role,
        tag,
        name,
        linkCount,
        totalCount,
        linkRatio,
        navByHint: false,
        navByStructure: navByStructure || navByWidget,
        navContainer,
        navAncestor,
      });
    }
  }
  return { linkCount, totalCount };
}

function loadLayoutDump(layoutDir: string, hash: string): LayoutDump | null {
  const file = path.join(layoutDir, `${hash}.json`);
  if (!fs.existsSync(file)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(file, 'utf-8')) as LayoutDump;
}

function intersectionSize(a: Set<string>, b: Set<string>) {
  let count = 0;
  for (const v of a) {
    if (b.has(v)) count += 1;
  }
  return count;
}

function diffSet(a: Set<string>, b: Set<string>) {
  const out: string[] = [];
  for (const v of a) {
    if (!b.has(v)) out.push(v);
  }
  return out;
}

function formatPct(value: number) {
  return `${(value * 100).toFixed(2)}%`;
}

function computeMetrics(matched: number, predicted: number, expected: number) {
  const precision = predicted > 0 ? matched / predicted : 0;
  const recall = expected > 0 ? matched / expected : 0;
  const f1 = precision + recall > 0 ? (2 * precision * recall) / (precision + recall) : 0;
  return { precision, recall, f1 };
}

function buildLayoutMap(nodes: LayoutNode[]) {
  const map = new Map<string, LayoutNode>();
  for (const node of nodes) {
    const selector = node.selector || buildSelector(node.tag, node.id, node.className);
    if (!selector) continue;
    if (!map.has(selector)) {
      map.set(selector, node);
    }
  }
  return map;
}

function refinePredictedNav(
  predicted: Set<string>,
  layoutMap: Map<string, LayoutNode>,
  infoMap: Map<string, AomNavInfo>,
  options: { allowMeta: boolean }
): Set<string> {
  const refined = new Set<string>();
  for (const selector of predicted) {
    const layout = layoutMap.get(selector);
    const info = infoMap.get(selector);
    const layoutTag = layout?.tag?.toLowerCase() || '';
    const layoutRole = layout?.role?.toLowerCase() || '';
    const aomRole = info?.role?.toLowerCase() || '';
    const aomTag = info?.tag?.toLowerCase() || '';
    const layoutHint =
      NAV_TAGS.has(layoutTag) ||
      containsPattern(layout?.id, NAV_PATTERNS) ||
      containsPattern(layout?.className, NAV_PATTERNS) ||
      containsPattern(layout?.ariaLabel, NAV_PATTERNS);
    const aomHint = NAV_ROLES.has(aomRole) || NAV_TAGS.has(aomTag) || containsPattern(info?.name, NAV_PATTERNS);
    const linkDensity = layout?.linkDensity ?? 0;
    const textLen = layout?.textLen ?? 0;
    const linkRatio = info?.linkRatio ?? 0;
    const linkCount = info?.linkCount ?? 0;
    const menuByLinks = linkDensity >= 0.25 && textLen <= 2000;
    const listByLinks = isListTag(layoutTag) || isListTag(aomTag) || aomRole === 'list';
    const widgetNav = containsPattern(selector, WIDGET_PATTERNS) && linkCount >= 1;
    const navByStructure =
      info?.navByStructure ?? (linkCount >= 2 && linkRatio >= (listByLinks ? 0.15 : 0.2));
    const strongNav = layoutHint || aomHint || menuByLinks || navByStructure || (listByLinks && linkRatio >= 0.2) || widgetNav;

    if (!strongNav) {
      continue;
    }
    if (layout?.isAdCandidate) {
      continue;
    }

    const metaHit =
      containsPattern(selector, META_PATTERNS) ||
      containsPattern(layout?.id, META_PATTERNS) ||
      containsPattern(layout?.className, META_PATTERNS) ||
      containsPattern(layout?.ariaLabel, META_PATTERNS) ||
      containsPattern(info?.name, META_PATTERNS);
    const hasSemanticNav =
      NAV_ROLES.has(aomRole) || NAV_ROLES.has(layoutRole) || NAV_TAGS.has(layoutTag) || NAV_TAGS.has(aomTag);
    if (!options.allowMeta && metaHit && !hasSemanticNav && !navByStructure) {
      continue;
    }

    refined.add(selector);
  }
  return refined;
}

async function main() {
  const args = process.argv.slice(2);
  let limit = Infinity;
  let layoutDir = path.join(process.cwd(), 'render-results/aeb-layout');
  let specificHash: string | null = null;
  let show = 0;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--layout-dir' && args[i + 1]) {
      layoutDir = path.resolve(args[i + 1]);
      i++;
    } else if (args[i] === '--hash' && args[i + 1]) {
      specificHash = args[i + 1];
      i++;
    } else if (args[i] === '--show' && args[i + 1]) {
      show = parseInt(args[i + 1], 10);
      i++;
    } else if (!args[i].startsWith('-')) {
      specificHash = args[i];
    }
  }

  const groundTruth = loadGroundTruth();
  const hashes = Object.keys(groundTruth);
  const targets = specificHash ? [specificHash] : hashes.slice(0, limit);

  let totalExpected = 0;
  let totalExpectedStrict = 0;
  let totalExpectedMeta = 0;
  let totalNoSelector = 0;
  let missingLayout = 0;

  const aggregate = new Map<
    string,
    { predicted: number; matchedLoose: number; matchedStrict: number; matchedMeta: number; adOverlap: number }
  >();

  const caseDetails: Array<{
    hash: string;
    precision: number;
    recall: number;
    f1: number;
    missingExpected: string[];
    extraPredicted: string[];
  }> = [];

  for (const hash of targets) {
    const layout = loadLayoutDump(layoutDir, hash);
    if (!layout) {
      missingLayout += 1;
      continue;
    }

    const expectedNav = new Set<string>();
    const expectedMeta = new Set<string>();
    const adSelectors = new Set<string>();
    const layoutMap = buildLayoutMap(layout.nodes || []);
    for (const node of layout.nodes || []) {
      const selector = node.selector || buildSelector(node.tag, node.id, node.className);
      if (!selector) continue;
      if (node.isAdCandidate) {
        adSelectors.add(selector);
      }
      const metaHit =
        containsPattern(selector, META_PATTERNS) ||
        containsPattern(node.id, META_PATTERNS) ||
        containsPattern(node.className, META_PATTERNS) ||
        containsPattern(node.ariaLabel, META_PATTERNS);
      if (metaHit) {
        expectedMeta.add(selector);
      }
      if (node.isNavCandidate && !node.isAdCandidate) {
        expectedNav.add(selector);
      }
    }
    const expectedNavStrict = new Set([...expectedNav].filter(sel => !expectedMeta.has(sel)));

    const html = loadHtml(hash);
    const snapshotJson = accessibility.getAriaSnapshotJson(html);
    const snapshot = JSON.parse(snapshotJson) as AomNode;
    const predictedNav = new Set<string>();
    const predictedListInNav = new Set<string>();
    const infoMap = new Map<string, AomNavInfo>();
    const stats = { noSelector: 0 };
    collectNavSelectors(snapshot, predictedNav, predictedListInNav, infoMap, stats, { navAncestor: false });

    const predictedBase = predictedNav;
    const predictedWithList = new Set([...predictedNav, ...predictedListInNav]);
    const predictedRefined = refinePredictedNav(predictedBase, layoutMap, infoMap, { allowMeta: false });
    const predictedRefinedLoose = refinePredictedNav(predictedBase, layoutMap, infoMap, { allowMeta: true });
    const predictedHier = refinePredictedNav(predictedWithList, layoutMap, infoMap, { allowMeta: false });
    const predictedHierLoose = refinePredictedNav(predictedWithList, layoutMap, infoMap, { allowMeta: true });

    const variants: Array<{ key: string; label: string; set: Set<string> }> = [
      { key: 'base', label: 'Base', set: predictedBase },
      { key: 'baseLoose', label: 'Base+meta', set: predictedBase },
      { key: 'refined', label: 'Refined', set: predictedRefined },
      { key: 'refinedLoose', label: 'Refined+meta', set: predictedRefinedLoose },
      { key: 'hier', label: 'Refined+hier', set: predictedHier },
      { key: 'hierLoose', label: 'Refined+hier+meta', set: predictedHierLoose },
    ];

    for (const variant of variants) {
      if (!aggregate.has(variant.key)) {
        aggregate.set(variant.key, { predicted: 0, matchedLoose: 0, matchedStrict: 0, matchedMeta: 0, adOverlap: 0 });
      }
      const agg = aggregate.get(variant.key)!;
      const matchedLoose = intersectionSize(variant.set, expectedNav);
      const matchedStrict = intersectionSize(variant.set, expectedNavStrict);
      const matchedMeta = intersectionSize(variant.set, expectedMeta);
      const adOverlap = intersectionSize(variant.set, adSelectors);
      agg.predicted += variant.set.size;
      agg.matchedLoose += matchedLoose;
      agg.matchedStrict += matchedStrict;
      agg.matchedMeta += matchedMeta;
      agg.adOverlap += adOverlap;
    }

    totalExpected += expectedNav.size;
    totalExpectedStrict += expectedNavStrict.size;
    totalExpectedMeta += expectedMeta.size;
    totalNoSelector += stats.noSelector;

    if (show > 0) {
      const matchedShow = intersectionSize(predictedHierLoose, expectedNav);
      const precision = predictedHierLoose.size > 0 ? matchedShow / predictedHierLoose.size : 0;
      const recall = expectedNav.size > 0 ? matchedShow / expectedNav.size : 0;
      const f1 = precision + recall > 0 ? (2 * precision * recall) / (precision + recall) : 0;
      caseDetails.push({
        hash,
        precision,
        recall,
        f1,
        missingExpected: diffSet(expectedNav, predictedHierLoose).slice(0, show),
        extraPredicted: diffSet(predictedHierLoose, expectedNav).slice(0, show),
      });
    }
  }

  console.log(`Targets: ${targets.length}`);
  if (missingLayout > 0) {
    console.log(`Missing layout dumps: ${missingLayout}`);
  }
  console.log(`Expected nav selectors: ${totalExpected}`);
  console.log(`Expected nav selectors (strict): ${totalExpectedStrict}`);
  console.log(`Expected meta selectors: ${totalExpectedMeta}`);
  console.log(`Predicted nav nodes missing selector: ${totalNoSelector}`);
  console.log('');
  console.log('=== Variant metrics (loose/strict/meta) ===');
  const variantOrder: Array<{ key: string; label: string }> = [
    { key: 'base', label: 'Base' },
    { key: 'refined', label: 'Refined' },
    { key: 'refinedLoose', label: 'Refined+meta' },
    { key: 'hier', label: 'Refined+hier' },
    { key: 'hierLoose', label: 'Refined+hier+meta' },
  ];
  let bestStrictLabel = '';
  let bestStrictF1 = -1;
  for (const variant of variantOrder) {
    const agg = aggregate.get(variant.key);
    if (!agg) continue;
    const loose = computeMetrics(agg.matchedLoose, agg.predicted, totalExpected);
    const strict = computeMetrics(agg.matchedStrict, agg.predicted, totalExpectedStrict);
    const meta = computeMetrics(agg.matchedMeta, agg.predicted, totalExpectedMeta);
    if (strict.f1 > bestStrictF1) {
      bestStrictF1 = strict.f1;
      bestStrictLabel = variant.label;
    }
    console.log(
      `${variant.label}: ` +
        `loose P=${formatPct(loose.precision)} R=${formatPct(loose.recall)} F1=${formatPct(loose.f1)} ` +
        `| strict P=${formatPct(strict.precision)} R=${formatPct(strict.recall)} F1=${formatPct(strict.f1)} ` +
        `| meta R=${formatPct(meta.recall)} ` +
        `| adOverlap=${agg.adOverlap}`
    );
  }
  if (bestStrictLabel) {
    console.log(`Best (strict F1): ${bestStrictLabel} ${formatPct(bestStrictF1)}`);
  }

  if (show > 0 && caseDetails.length > 0) {
    const worst = [...caseDetails].sort((a, b) => a.f1 - b.f1).slice(0, show);
    console.log('');
    console.log('=== Worst cases ===');
    for (const c of worst) {
      console.log(`${c.hash.slice(0, 16)}... F1=${formatPct(c.f1)} P=${formatPct(c.precision)} R=${formatPct(c.recall)}`);
      if (c.missingExpected.length > 0) {
        console.log(`  missing: ${c.missingExpected.join(', ')}`);
      }
      if (c.extraPredicted.length > 0) {
        console.log(`  extra: ${c.extraPredicted.join(', ')}`);
      }
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
