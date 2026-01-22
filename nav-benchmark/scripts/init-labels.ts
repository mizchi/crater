/**
 * Initialize labels from existing layout dump data.
 * Creates draft labels that need manual review.
 *
 * Usage:
 *   npx tsx nav-benchmark/scripts/init-labels.ts
 *   npx tsx nav-benchmark/scripts/init-labels.ts --hash <hash>
 */

import fs from 'fs';
import path from 'path';

const SAMPLES_FILE = path.join(process.cwd(), 'nav-benchmark/samples.json');
const LAYOUT_DIR = path.join(process.cwd(), 'render-results/aeb-layout');
const LABELS_DIR = path.join(process.cwd(), 'nav-benchmark/labels');

interface Sample {
  hash: string;
  url: string | null;
  domain: string;
  navCount: number;
}

interface LayoutNode {
  tag?: string;
  id?: string;
  className?: string;
  selector?: string;
  isNavCandidate?: boolean;
  rect?: { x: number; y: number; width: number; height: number };
  textLen?: number;
  linkDensity?: number;
}

interface LayoutDump {
  hash: string;
  url?: string | null;
  nodes: LayoutNode[];
}

type NavType =
  | 'primary_nav'
  | 'secondary_nav'
  | 'footer_nav'
  | 'sidebar_nav'
  | 'breadcrumb'
  | 'pagination'
  | 'skip_link'
  | 'social_nav'
  | 'unknown';

interface NavRegion {
  id: string;
  type: NavType;
  selector: string;
  rect: { x: number; y: number; width: number; height: number };
  confidence: 'certain' | 'probable' | 'uncertain';
}

interface Label {
  hash: string;
  url: string | null;
  viewport: { width: number; height: number };
  nav_regions: NavRegion[];
  notes: string;
  status: 'draft' | 'reviewed' | 'final';
}

function classifyNavType(node: LayoutNode, pageHeight: number): NavType {
  const selector = (node.selector || '').toLowerCase();
  const tag = (node.tag || '').toLowerCase();
  const rect = node.rect;

  // Skip link
  if (selector.includes('skip') || selector.includes('jump')) {
    return 'skip_link';
  }

  // Breadcrumb
  if (selector.includes('breadcrumb') || selector.includes('crumb')) {
    return 'breadcrumb';
  }

  // Pagination
  if (selector.includes('paging') || selector.includes('pagination') || selector.includes('page-nav')) {
    return 'pagination';
  }

  // Social
  if (selector.includes('social') || selector.includes('share')) {
    return 'social_nav';
  }

  // Footer nav (bottom 20% of page)
  if (rect && pageHeight > 0 && rect.y > pageHeight * 0.8) {
    if (tag === 'footer' || selector.includes('footer')) {
      return 'footer_nav';
    }
  }

  // Header nav (top 20% of page)
  if (rect && rect.y < pageHeight * 0.2) {
    if (tag === 'header' || tag === 'nav' || selector.includes('header') || selector.includes('navbar')) {
      return 'primary_nav';
    }
  }

  // Sidebar
  if (selector.includes('sidebar') || selector.includes('aside') || tag === 'aside') {
    return 'sidebar_nav';
  }

  // Secondary nav
  if (selector.includes('sub') || selector.includes('secondary') || selector.includes('dropdown')) {
    return 'secondary_nav';
  }

  // Default: primary if nav tag, otherwise unknown
  if (tag === 'nav') {
    return 'primary_nav';
  }

  return 'unknown';
}

function loadLayoutDump(hash: string): LayoutDump | null {
  const file = path.join(LAYOUT_DIR, `${hash}.json`);
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf-8'));
}

function initLabel(sample: Sample): Label | null {
  const dump = loadLayoutDump(sample.hash);
  if (!dump) return null;

  const navNodes = (dump.nodes || []).filter(n => n.isNavCandidate && n.rect);

  // Get page height from nodes
  let maxY = 0;
  for (const node of dump.nodes || []) {
    if (node.rect) {
      const bottom = node.rect.y + node.rect.height;
      if (bottom > maxY) maxY = bottom;
    }
  }

  const regions: NavRegion[] = [];
  let regionId = 1;

  for (const node of navNodes) {
    if (!node.rect || !node.selector) continue;

    // Skip very small regions
    if (node.rect.width < 50 || node.rect.height < 20) continue;

    const type = classifyNavType(node, maxY);

    regions.push({
      id: `nav-${regionId++}`,
      type,
      selector: node.selector,
      rect: node.rect,
      confidence: type === 'unknown' ? 'uncertain' : 'probable',
    });
  }

  // Merge overlapping regions of the same type
  const merged = mergeOverlappingRegions(regions);

  return {
    hash: sample.hash,
    url: sample.url,
    viewport: { width: 1280, height: 800 },
    nav_regions: merged,
    notes: 'Auto-generated draft. Needs manual review.',
    status: 'draft',
  };
}

function regionsOverlap(a: NavRegion, b: NavRegion): boolean {
  const aRight = a.rect.x + a.rect.width;
  const aBottom = a.rect.y + a.rect.height;
  const bRight = b.rect.x + b.rect.width;
  const bBottom = b.rect.y + b.rect.height;

  return !(aRight < b.rect.x || bRight < a.rect.x || aBottom < b.rect.y || bBottom < a.rect.y);
}

function mergeRects(
  a: { x: number; y: number; width: number; height: number },
  b: { x: number; y: number; width: number; height: number }
): { x: number; y: number; width: number; height: number } {
  const x = Math.min(a.x, b.x);
  const y = Math.min(a.y, b.y);
  const right = Math.max(a.x + a.width, b.x + b.width);
  const bottom = Math.max(a.y + a.height, b.y + b.height);
  return { x, y, width: right - x, height: bottom - y };
}

function mergeOverlappingRegions(regions: NavRegion[]): NavRegion[] {
  if (regions.length === 0) return [];

  const result: NavRegion[] = [];
  const used = new Set<number>();

  for (let i = 0; i < regions.length; i++) {
    if (used.has(i)) continue;

    let current = { ...regions[i] };
    used.add(i);

    // Find and merge overlapping regions of the same type
    let merged = true;
    while (merged) {
      merged = false;
      for (let j = 0; j < regions.length; j++) {
        if (used.has(j)) continue;
        if (regions[j].type !== current.type) continue;

        if (regionsOverlap(current, regions[j])) {
          current.rect = mergeRects(current.rect, regions[j].rect);
          current.selector = current.selector + ', ' + regions[j].selector;
          used.add(j);
          merged = true;
        }
      }
    }

    result.push(current);
  }

  return result;
}

async function main() {
  const args = process.argv.slice(2);
  let specificHash: string | null = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--hash' && args[i + 1]) {
      specificHash = args[i + 1];
    }
  }

  const samples: Sample[] = JSON.parse(fs.readFileSync(SAMPLES_FILE, 'utf-8'));
  const targets = specificHash ? samples.filter(s => s.hash.startsWith(specificHash!)) : samples;

  console.log(`Initializing labels for ${targets.length} samples...`);

  let created = 0;
  let skipped = 0;

  for (const sample of targets) {
    const outputPath = path.join(LABELS_DIR, `${sample.hash}.json`);

    if (fs.existsSync(outputPath)) {
      console.log(`Skip (exists): ${sample.hash.slice(0, 16)}`);
      skipped++;
      continue;
    }

    const label = initLabel(sample);
    if (!label) {
      console.log(`Skip (no layout): ${sample.hash.slice(0, 16)}`);
      skipped++;
      continue;
    }

    fs.writeFileSync(outputPath, JSON.stringify(label, null, 2));
    console.log(`Created: ${sample.hash.slice(0, 16)} - ${label.nav_regions.length} regions`);
    created++;
  }

  console.log(`\nDone. Created: ${created}, Skipped: ${skipped}`);
}

main().catch(console.error);
