/**
 * Real-world layout match rate - aggregate Crater-vs-Chromium accuracy.
 *
 * Renders a real-world snapshot (github-mizchi, example-com, or any local
 * snapshot under real-world/) in Chromium and in the Crater conformance WPT
 * runtime, walks the two layout trees in parallel, and reports an aggregate
 * match rate: the fraction of browser elements whose Crater box matches within
 * a position/size tolerance, plus IoU and structural-coverage stats.
 *
 * Usage:
 *   npx tsx scripts/real-world-match-rate.ts                 # all snapshots
 *   npx tsx scripts/real-world-match-rate.ts github-mizchi   # one snapshot
 *   npx tsx scripts/real-world-match-rate.ts --json
 *   npx tsx scripts/real-world-match-rate.ts --threshold 2   # px tolerance
 *
 * The pure aggregation helpers (matchTrees / iou / summarize) are exported and
 * unit-tested in real-world-match-rate.test.ts without a browser.
 */

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execSync } from 'node:child_process';
import {
  LOCAL_WPT_RUNTIME_BUILD_COMMAND,
  resolveLocalWptRuntimeCandidates,
} from './wpt-runner.ts';
import {
  listRealWorldSnapshotNames,
  loadRealWorldSnapshot,
} from './real-world-snapshot.ts';

export interface Box {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  children?: Box[];
}

export interface MatchStats {
  /** Browser elements visited via the parallel walk. */
  compared: number;
  /** Of those, how many fall within the position/size tolerance. */
  matched: number;
  /** Browser-side elements with no structural counterpart in Crater. */
  browserOnly: number;
  /** Crater-side elements with no structural counterpart in the browser. */
  craterOnly: number;
  /** Sum of IoU over compared elements (divide by `compared` for the mean). */
  iouSum: number;
  /** Largest per-element box deltas, worst first. */
  worst: Array<{ path: string; delta: number; browser: Box; crater: Box }>;
}

export interface SnapshotReport {
  name: string;
  matchRate: number;
  averageIoU: number;
  compared: number;
  matched: number;
  browserOnly: number;
  craterOnly: number;
  worst: MatchStats['worst'];
}

const DEFAULT_THRESHOLD = 1; // px
const WORST_KEEP = 10;

// --- Pure aggregation -----------------------------------------------------

function meaningful(node: Box): Box[] {
  return (node.children ?? []).filter((c) => !String(c.id).startsWith('#text'));
}

export function iou(a: Box, b: Box): number {
  const x1 = Math.max(a.x, b.x);
  const y1 = Math.max(a.y, b.y);
  const x2 = Math.min(a.x + a.width, b.x + b.width);
  const y2 = Math.min(a.y + a.height, b.y + b.height);
  const inter = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
  const union = a.width * a.height + b.width * b.height - inter;
  if (union <= 0) return a.width === b.width && a.height === b.height ? 1 : 0;
  return inter / union;
}

function boxDelta(a: Box, b: Box): number {
  return Math.max(
    Math.abs(a.x - b.x),
    Math.abs(a.y - b.y),
    Math.abs(a.width - b.width),
    Math.abs(a.height - b.height),
  );
}

/**
 * Walk two layout trees in parallel, matching children by index. Diverging
 * subtree shapes are counted as browserOnly / craterOnly rather than aborting,
 * so the match rate degrades gracefully on structural mismatches.
 */
export function matchTrees(
  browser: Box,
  crater: Box,
  threshold = DEFAULT_THRESHOLD,
): MatchStats {
  const stats: MatchStats = {
    compared: 0,
    matched: 0,
    browserOnly: 0,
    craterOnly: 0,
    iouSum: 0,
    worst: [],
  };
  const worst: MatchStats['worst'] = [];

  const countSubtree = (n: Box): number => 1 + meaningful(n).reduce((s, c) => s + countSubtree(c), 0);

  const walk = (b: Box, c: Box, path: string): void => {
    stats.compared++;
    const delta = boxDelta(b, c);
    stats.iouSum += iou(b, c);
    if (delta <= threshold) stats.matched++;
    worst.push({ path, delta, browser: b, crater: c });

    const bc = meaningful(b);
    const cc = meaningful(c);
    const n = Math.min(bc.length, cc.length);
    for (let i = 0; i < n; i++) walk(bc[i]!, cc[i]!, `${path}>${bc[i]!.id}`);
    for (let i = n; i < bc.length; i++) stats.browserOnly += countSubtree(bc[i]!);
    for (let i = n; i < cc.length; i++) stats.craterOnly += countSubtree(cc[i]!);
  };

  walk(browser, crater, browser.id);
  worst.sort((p, q) => q.delta - p.delta);
  stats.worst = worst.slice(0, WORST_KEEP);
  return stats;
}

/** Zero a tree root's own offset so the walk compares relative geometry. */
export function normalizeRoot(node: Box): Box {
  return { ...node, x: 0, y: 0 };
}

/** Tag name from a node id like "div#foo", "span.bar", or "div". */
export function tagOf(node: Box): string {
  return String(node.id).split(/[#.]/)[0] || '';
}

/**
 * Count visible (non-text) elements by tag. Alignment-free, so unlike the
 * parallel-walk browserOnly/craterOnly counts it measures content *coverage*
 * (which elements rendered at all) without being skewed by structural drift.
 */
export function tagHistogram(root: Box): Map<string, number> {
  const hist = new Map<string, number>();
  const visit = (n: Box): void => {
    if (!String(n.id).startsWith('#text') && ((n.width ?? 0) >= 1 || (n.height ?? 0) >= 1)) {
      const t = tagOf(n);
      hist.set(t, (hist.get(t) ?? 0) + 1);
    }
    for (const c of n.children ?? []) visit(c);
  };
  visit(root);
  return hist;
}

export interface Coverage {
  browserTotal: number;
  craterTotal: number;
  /** craterTotal / browserTotal, clamped to [0, 1]. */
  ratio: number;
  /** Tags where the browser rendered more elements than Crater, worst first. */
  deficits: Array<{ tag: string; browser: number; crater: number }>;
}

/** Compare visible element coverage between the two trees, tag by tag. */
export function coverage(browser: Box, crater: Box): Coverage {
  const bh = tagHistogram(browser);
  const ch = tagHistogram(crater);
  let browserTotal = 0;
  let craterTotal = 0;
  for (const n of bh.values()) browserTotal += n;
  for (const n of ch.values()) craterTotal += n;
  const deficits: Coverage['deficits'] = [];
  for (const [tag, b] of bh) {
    const c = ch.get(tag) ?? 0;
    if (b > c) deficits.push({ tag, browser: b, crater: c });
  }
  deficits.sort((p, q) => q.browser - q.crater - (p.browser - p.crater));
  return {
    browserTotal,
    craterTotal,
    ratio: browserTotal > 0 ? Math.min(1, craterTotal / browserTotal) : 1,
    deficits,
  };
}

export function summarize(name: string, stats: MatchStats): SnapshotReport {
  return {
    name,
    matchRate: stats.compared > 0 ? stats.matched / stats.compared : 0,
    averageIoU: stats.compared > 0 ? stats.iouSum / stats.compared : 0,
    compared: stats.compared,
    matched: stats.matched,
    browserOnly: stats.browserOnly,
    craterOnly: stats.craterOnly,
    worst: stats.worst,
  };
}

/** Collect `#id` -> size for every element that carries a real id. */
export function sizeById(root: Box): Map<string, { width: number; height: number }> {
  const map = new Map<string, { width: number; height: number }>();
  const visit = (n: Box): void => {
    const id = String(n.id);
    const hash = id.indexOf('#');
    if (hash >= 0) {
      map.set(id.slice(hash + 1), { width: n.width ?? 0, height: n.height ?? 0 });
    }
    for (const c of n.children ?? []) visit(c);
  };
  visit(root);
  return map;
}

export interface SizeMatch {
  shared: number;
  matched: number;
  rate: number;
  worst: Array<{ id: string; browser: { width: number; height: number }; crater: { width: number; height: number }; delta: number }>;
}

/**
 * Compare element box sizes anchored on shared ids. Unlike the parallel walk,
 * id anchoring is immune to structural drift and (being size, not position)
 * does not cascade, so this is the reliable accuracy signal for real pages.
 */
export function idAnchoredSizeMatch(browser: Box, crater: Box, threshold = DEFAULT_THRESHOLD): SizeMatch {
  const bm = sizeById(browser);
  const cm = sizeById(crater);
  const worst: SizeMatch['worst'] = [];
  let shared = 0;
  let matched = 0;
  for (const [id, b] of bm) {
    const c = cm.get(id);
    if (!c) continue;
    shared++;
    const delta = Math.max(Math.abs(b.width - c.width), Math.abs(b.height - c.height));
    if (delta <= threshold) matched++;
    else worst.push({ id, browser: b, crater: c, delta });
  }
  worst.sort((p, q) => q.delta - p.delta);
  return { shared, matched, rate: shared > 0 ? matched / shared : 1, worst: worst.slice(0, WORST_KEEP) };
}

// --- Renderers ------------------------------------------------------------

type RenderFn = (html: string, w: number, h: number) => string;

/**
 * Wire up the vendored proportional font measure (Tinos, metric-compatible with
 * Chromium's default serif), exactly as wpt-runner does. Without this Crater
 * falls back to a crude monospace estimate (0.5 * font-size per char), which
 * makes all text ~10-20% too wide and inflates every text-driven layout.
 */
async function configureFontMeasure(): Promise<void> {
  const { createTextIntrinsicFnFromMeasureText } = await import('./text-intrinsic.ts');
  const { createVendoredFontMeasure } = await import('./wpt-font-measure.ts');
  (globalThis as any).__craterMeasureTextIntrinsic = createTextIntrinsicFnFromMeasureText(
    createVendoredFontMeasure(),
  );
}

async function loadCraterRenderer(): Promise<RenderFn> {
  await configureFontMeasure();
  try {
    execSync(LOCAL_WPT_RUNTIME_BUILD_COMMAND, { stdio: 'ignore', cwd: process.cwd() });
  } catch {
    // fall through to existing artifact
  }
  const candidate = resolveLocalWptRuntimeCandidates().find((p) => fs.existsSync(p));
  if (!candidate) {
    throw new Error('Crater WPT runtime not found. Build:\n  ' + LOCAL_WPT_RUNTIME_BUILD_COMMAND);
  }
  const mod: any = await import(pathToFileURL(candidate).href);
  return mod.renderHtmlToJsonForWpt as RenderFn;
}

/**
 * Force the browser to render all text with the same vendored font (Tinos) that
 * Crater measures with — Crater's measure ignores font-family, so without this
 * a page in any other font (HN's Verdana, GitHub's sans) has systematically
 * different text widths and the size comparison reflects font availability, not
 * layout. With it the comparison isolates layout accuracy.
 */
function injectVendoredFont(html: string): string {
  const ttf = fs.readFileSync(path.join(process.cwd(), 'tests', 'wpt-fonts', 'Tinos-Regular.ttf'));
  const style =
    `<style>@font-face{font-family:CraterVendored;src:url(data:font/ttf;base64,${ttf.toString('base64')})}` +
    `*,*::before,*::after{font-family:CraterVendored !important}</style>`;
  return /<head[^>]*>/i.test(html)
    ? html.replace(/<head[^>]*>/i, (m) => m + style)
    : style + html;
}

async function browserLayout(html: string, vw: number, vh: number): Promise<Box> {
  const puppeteer = (await import('puppeteer')).default;
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: vw, height: vh });
    await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 15000 });
    return (await page.evaluate(`(() => {
      function rectOf(el, parent) {
        const r = el.getBoundingClientRect();
        const kids = [];
        for (const c of el.children) {
          if (['SCRIPT','STYLE','LINK','META','TITLE','HEAD','TEMPLATE'].includes(c.tagName)) continue;
          const cr = c.getBoundingClientRect();
          if (cr.width === 0 && cr.height === 0) continue;
          kids.push(rectOf(c, el));
        }
        let x = r.left, y = r.top;
        if (parent) { const pr = parent.getBoundingClientRect(); x = r.left - pr.left; y = r.top - pr.top; }
        const id = el.id ? el.tagName.toLowerCase()+'#'+el.id : el.tagName.toLowerCase();
        return { id, x, y, width: r.width, height: r.height, children: kids };
      }
      return { ...rectOf(document.body, null), x: 0, y: 0 };
    })()`)) as Box;
  } finally {
    await browser.close();
  }
}

// --- CLI ------------------------------------------------------------------

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const json = args.includes('--json');
  const fontFair = args.includes('--font-fair');
  const thIdx = args.indexOf('--threshold');
  const threshold = thIdx >= 0 ? Number(args[thIdx + 1]) : DEFAULT_THRESHOLD;
  const nameArg = args.find((a) => !a.startsWith('--') && a !== String(threshold));

  const names = nameArg ? [nameArg] : listRealWorldSnapshotNames();
  const render = await loadCraterRenderer();
  const reports: SnapshotReport[] = [];
  const coverages: Coverage[] = [];
  const sizeMatches: SizeMatch[] = [];

  for (const name of names) {
    const snap = loadRealWorldSnapshot(name);
    // --font-fair forces the browser to use Crater's vendored font so the size
    // comparison reflects layout rather than font availability. Crater ignores
    // font-family already, so only the browser HTML needs the override.
    const browserHtml = fontFair ? injectVendoredFont(snap.html) : snap.html;
    const browser = await browserLayout(browserHtml, snap.viewport.width, snap.viewport.height);
    const crater: Box = JSON.parse(
      render(snap.html, snap.viewport.width, snap.viewport.height),
    );
    reports.push(
      summarize(name, matchTrees(normalizeRoot(browser), normalizeRoot(crater), threshold)),
    );
    coverages.push(coverage(browser, crater));
    sizeMatches.push(idAnchoredSizeMatch(browser, crater, threshold));
  }

  if (json) {
    console.log(JSON.stringify({ threshold, reports, coverages, sizeMatches }, null, 2));
    return;
  }

  reports.forEach((r, idx) => {
    const cov = coverages[idx]!;
    const sm = sizeMatches[idx]!;
    console.log(`\n=== ${r.name} ===`);
    console.log(
      `  content coverage: ${(cov.ratio * 100).toFixed(1)}%  ` +
        `(${cov.craterTotal}/${cov.browserTotal} visible elements)`,
    );
    if (cov.deficits.length > 0) {
      const top = cov.deficits
        .slice(0, 5)
        .map((d) => `${d.tag} ${d.crater}/${d.browser}`)
        .join(', ');
      console.log(`    tag deficits: ${top}`);
    }
    console.log(
      `  id-anchored size match: ${(sm.rate * 100).toFixed(1)}%  ` +
        `(${sm.matched}/${sm.shared} elements within ${threshold}px) [reliable]`,
    );
    for (const w of sm.worst.slice(0, 4)) {
      console.log(
        `    Δ${w.delta.toFixed(0)}px  #${w.id}  ` +
          `browser=${w.browser.width.toFixed(0)}x${w.browser.height.toFixed(0)} ` +
          `crater=${w.crater.width.toFixed(0)}x${w.crater.height.toFixed(0)}`,
      );
    }
    console.log(
      `  index-aligned match rate: ${(r.matchRate * 100).toFixed(1)}%  ` +
        `(${r.matched}/${r.compared} within ${threshold}px) [noisy: structural drift]`,
    );
    console.log(`  average IoU: ${r.averageIoU.toFixed(3)}`);
    console.log(
      `  structural (index-aligned, noisy): browserOnly=${r.browserOnly} craterOnly=${r.craterOnly}`,
    );
    for (const w of r.worst.slice(0, 6)) {
      console.log(
        `    Δ${w.delta.toFixed(0)}px  ${w.path}  ` +
          `b=(${w.browser.x.toFixed(0)},${w.browser.y.toFixed(0)} ${w.browser.width.toFixed(0)}x${w.browser.height.toFixed(0)})  ` +
          `c=(${w.crater.x.toFixed(0)},${w.crater.y.toFixed(0)} ${w.crater.width.toFixed(0)}x${w.crater.height.toFixed(0)})`,
      );
    }
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
