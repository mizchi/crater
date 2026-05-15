/**
 * Evaluate layout-only heuristics against AEB ground truth.
 *
 * Requires layout JSONs from scripts/aeb-layout-dump.ts.
 *
 * Usage:
 *   npx tsx scripts/aeb-layout-eval.ts
 *   npx tsx scripts/aeb-layout-eval.ts --limit 50 --top 10
 */

import fs from 'fs';
import path from 'path';

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

type LayoutNode = {
  tag: string;
  id: string;
  className: string;
  role?: string;
  ariaLabel?: string;
  text: string;
  textLen: number;
  rect: { x: number; y: number; width: number; height: number };
  area: number;
  density: number;
  linkTextLen?: number;
  linkDensity?: number;
  isNavCandidate?: boolean;
  isAdCandidate?: boolean;
};

type LayoutDoc = {
  hash: string;
  url?: string | null;
  viewport: { width: number; height: number };
  nodes: LayoutNode[];
};

function loadGroundTruth(): GroundTruth {
  const groundTruthPath = path.join(AEB_PATH, 'ground-truth.json');
  if (!fs.existsSync(groundTruthPath)) {
    throw new Error(`Ground truth not found at ${groundTruthPath}. Run: ghq get scrapinghub/article-extraction-benchmark`);
  }
  return JSON.parse(fs.readFileSync(groundTruthPath, 'utf-8'));
}

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) {
    return 0;
  }
  let inter = 0;
  for (const w of a) {
    if (b.has(w)) {
      inter++;
    }
  }
  const union = a.size + b.size - inter;
  return inter / union;
}

function scoreNode(
  n: LayoutNode,
  viewport: { width: number; height: number },
  variant: string
): number {
  const area = n.area || 0;
  const density = n.density || 0;
  const textLen = n.textLen || 0;
  const linkDensity = n.linkDensity || 0;
  const widthRatio = n.rect.width / Math.max(1, viewport.width);
  const aspect = n.rect.width / Math.max(1, n.rect.height);
  const aspectPenalty = aspect < 0.12 ? 0.2 : aspect < 0.2 ? 0.5 : 1.0;
  const widthPenalty = Math.min(1, widthRatio / 0.9);
  const navPenalty = n.isNavCandidate ? 0.2 : 1.0;
  const adPenalty = n.isAdCandidate ? 0.2 : 1.0;
  const linkPenalty = 1.0 - Math.min(0.8, linkDensity);

  if (variant === 'area') {
    return area;
  }
  if (variant === 'area_density') {
    return area * Math.min(0.02, density);
  }
  if (variant === 'area_density_width') {
    return area * Math.min(0.02, density) * widthPenalty * aspectPenalty;
  }
  // layout_weighted
  return (
    area * Math.min(0.02, density) * widthPenalty * aspectPenalty * navPenalty * adPenalty * linkPenalty +
    Math.min(2000, textLen)
  );
}

function bestNodeByScore(
  nodes: LayoutNode[],
  viewport: { width: number; height: number },
  variant: string
) {
  let best: LayoutNode | null = null;
  let bestScore = -1;
  for (const n of nodes) {
    if (n.rect.width <= 1 || n.rect.height <= 1) {
      continue;
    }
    const score = scoreNode(n, viewport, variant);
    if (score > bestScore) {
      bestScore = score;
      best = n;
    }
  }
  return best;
}

async function main() {
  const args = process.argv.slice(2);
  let limit = Infinity;
  let top = 10;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--top' && args[i + 1]) {
      top = parseInt(args[i + 1], 10);
      i++;
    }
  }

  const groundTruth = loadGroundTruth();
  const hashes = Object.keys(groundTruth).slice(0, limit);
  const layoutDir = path.join(process.cwd(), 'render-results/aeb-layout');

  const variants = ['area', 'area_density', 'area_density_width', 'layout_weighted'];
  const stats: Record<string, { total: number; sum: number; sumOracle: number; hit: number }> = {};
  for (const v of variants) {
    stats[v] = { total: 0, sum: 0, sumOracle: 0, hit: 0 };
  }

  const deltas: Array<{ hash: string; variant: string; delta: number }> = [];

  for (const hash of hashes) {
    const layoutPath = path.join(layoutDir, `${hash}.json`);
    if (!fs.existsSync(layoutPath)) {
      continue;
    }
    const layout = JSON.parse(fs.readFileSync(layoutPath, 'utf-8')) as LayoutDoc;
    const expected = groundTruth[hash].articleBody || '';
    const expectedTokens = new Set(tokenize(expected));

    // oracle: node with max Jaccard to expected
    let oracle: LayoutNode | null = null;
    let oracleScore = 0;
    for (const n of layout.nodes) {
      const score = jaccard(expectedTokens, new Set(tokenize(n.text)));
      if (score > oracleScore) {
        oracleScore = score;
        oracle = n;
      }
    }

    for (const variant of variants) {
      const candidate = bestNodeByScore(layout.nodes, layout.viewport, variant);
      if (!candidate || !oracle) {
        continue;
      }
      const candScore = jaccard(expectedTokens, new Set(tokenize(candidate.text)));
      stats[variant].total += 1;
      stats[variant].sum += candScore;
      stats[variant].sumOracle += oracleScore;
      if (candidate === oracle || candScore >= oracleScore * 0.9) {
        stats[variant].hit += 1;
      }
      const delta = candScore - oracleScore;
      deltas.push({ hash, variant, delta });
    }
  }

  console.log('=== Layout-only eval (oracle=best node vs expected) ===');
  for (const variant of variants) {
    const s = stats[variant];
    const avg = s.total > 0 ? s.sum / s.total : 0;
    const avgOracle = s.total > 0 ? s.sumOracle / s.total : 0;
    const hitRate = s.total > 0 ? (s.hit / s.total) * 100 : 0;
    console.log(
      `${variant}: avg=${(avg * 100).toFixed(2)}% oracle=${(avgOracle * 100).toFixed(2)}% hit>=90%=${hitRate.toFixed(1)}%`
    );
  }

  // show top improvements per variant vs area
  const byVariant = new Map<string, Array<{ hash: string; delta: number }>>();
  for (const variant of variants) {
    if (variant === 'area') continue;
    const list = deltas.filter(d => d.variant === variant);
    byVariant.set(
      variant,
      list.sort((a, b) => b.delta - a.delta).slice(0, top).map(d => ({ hash: d.hash, delta: d.delta }))
    );
  }
  for (const [variant, list] of byVariant.entries()) {
    console.log(`\nTop +Δ (candidate - oracle) for ${variant}:`);
    for (const item of list) {
      console.log(`  ${item.hash.slice(0, 16)}... Δ=${(item.delta * 100).toFixed(1)}%`);
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
