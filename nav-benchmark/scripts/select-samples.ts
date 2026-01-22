/**
 * Select diverse samples from AEB for nav labeling.
 *
 * Criteria:
 * - Has layout dump
 * - Diverse nav structure (varied nav candidates count)
 * - Different site types
 */

import fs from 'fs';
import path from 'path';

const AEB_PATH = path.join(
  process.env.HOME || '',
  'ghq/github.com/scrapinghub/article-extraction-benchmark'
);

const LAYOUT_DIR = path.join(process.cwd(), 'render-results/aeb-layout');

interface LayoutDump {
  hash: string;
  url?: string | null;
  nodes: Array<{
    tag?: string;
    selector?: string;
    isNavCandidate?: boolean;
    rect?: { x: number; y: number; width: number; height: number };
  }>;
}

interface GroundTruth {
  [key: string]: {
    articleBody: string;
    url?: string;
  };
}

function loadGroundTruth(): GroundTruth {
  const groundTruthPath = path.join(AEB_PATH, 'ground-truth.json');
  return JSON.parse(fs.readFileSync(groundTruthPath, 'utf-8'));
}

function analyzeLayoutDump(hash: string): {
  navCount: number;
  totalNodes: number;
  hasHeader: boolean;
  hasFooter: boolean;
  hasSidebar: boolean;
  url: string | null;
} | null {
  const file = path.join(LAYOUT_DIR, `${hash}.json`);
  if (!fs.existsSync(file)) return null;

  const dump: LayoutDump = JSON.parse(fs.readFileSync(file, 'utf-8'));
  const nodes = dump.nodes || [];

  let navCount = 0;
  let hasHeader = false;
  let hasFooter = false;
  let hasSidebar = false;

  for (const node of nodes) {
    if (node.isNavCandidate) navCount++;

    const selector = (node.selector || '').toLowerCase();
    const tag = (node.tag || '').toLowerCase();

    if (tag === 'header' || selector.includes('header')) hasHeader = true;
    if (tag === 'footer' || selector.includes('footer')) hasFooter = true;
    if (selector.includes('sidebar') || selector.includes('aside')) hasSidebar = true;
  }

  return {
    navCount,
    totalNodes: nodes.length,
    hasHeader,
    hasFooter,
    hasSidebar,
    url: dump.url || null,
  };
}

function getDomain(url: string | null): string {
  if (!url) return 'unknown';
  try {
    return new URL(url).hostname;
  } catch {
    return 'unknown';
  }
}

async function main() {
  const groundTruth = loadGroundTruth();
  const hashes = Object.keys(groundTruth);

  console.log(`Total AEB pages: ${hashes.length}`);

  // Analyze all pages
  const analyzed: Array<{
    hash: string;
    url: string | null;
    domain: string;
    navCount: number;
    totalNodes: number;
    hasHeader: boolean;
    hasFooter: boolean;
    hasSidebar: boolean;
  }> = [];

  for (const hash of hashes) {
    const info = analyzeLayoutDump(hash);
    if (!info) continue;

    analyzed.push({
      hash,
      ...info,
      domain: getDomain(info.url),
    });
  }

  console.log(`Pages with layout dumps: ${analyzed.length}`);

  // Group by nav complexity
  const lowNav = analyzed.filter(p => p.navCount < 20);
  const medNav = analyzed.filter(p => p.navCount >= 20 && p.navCount < 50);
  const highNav = analyzed.filter(p => p.navCount >= 50);

  console.log(`\nBy nav complexity:`);
  console.log(`  Low (<20): ${lowNav.length}`);
  console.log(`  Medium (20-50): ${medNav.length}`);
  console.log(`  High (>50): ${highNav.length}`);

  // Select diverse samples
  const selected: typeof analyzed = [];
  const usedDomains = new Set<string>();

  function selectFrom(pool: typeof analyzed, count: number, label: string) {
    // Shuffle
    const shuffled = [...pool].sort(() => Math.random() - 0.5);
    let added = 0;

    for (const page of shuffled) {
      if (added >= count) break;
      // Prefer unique domains
      if (usedDomains.has(page.domain) && shuffled.length > count * 2) continue;

      selected.push(page);
      usedDomains.add(page.domain);
      added++;
    }
    console.log(`Selected ${added} from ${label}`);
  }

  // Select ~30 samples with diversity
  selectFrom(lowNav, 8, 'low nav');
  selectFrom(medNav, 12, 'medium nav');
  selectFrom(highNav, 10, 'high nav');

  console.log(`\nTotal selected: ${selected.length}`);
  console.log(`Unique domains: ${usedDomains.size}`);

  // Output selected samples
  console.log('\n=== Selected Samples ===\n');

  const output = selected.map(s => ({
    hash: s.hash,
    url: s.url,
    domain: s.domain,
    navCount: s.navCount,
    hasHeader: s.hasHeader,
    hasFooter: s.hasFooter,
    hasSidebar: s.hasSidebar,
  }));

  // Sort by domain for readability
  output.sort((a, b) => a.domain.localeCompare(b.domain));

  for (const s of output) {
    console.log(`${s.hash.slice(0, 16)} | nav=${s.navCount.toString().padStart(3)} | ${s.domain}`);
  }

  // Save selection
  const selectionFile = path.join(process.cwd(), 'nav-benchmark/samples.json');
  fs.writeFileSync(selectionFile, JSON.stringify(output, null, 2));
  console.log(`\nSaved to: ${selectionFile}`);
}

main().catch(console.error);
