import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import { accessibility } from '../../wasm/dist/crater.js';

const AEB_PATH = path.join(process.env.HOME || '', 'ghq/github.com/scrapinghub/article-extraction-benchmark');
const LAYOUT_DIR = path.join(process.cwd(), 'render-results/aeb-layout');

const hash = process.argv[2] || '0ec95c7261d122f304728e90c983450ef1ce1e0b423546835c397d50aaf0d0f2';

const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
const html = gunzipSync(fs.readFileSync(htmlPath)).toString('utf-8');

const layoutFile = path.join(LAYOUT_DIR, `${hash}.json`);
const layout = JSON.parse(fs.readFileSync(layoutFile, 'utf-8'));

console.log('Layout nodes (all):');
let count = 0;
for (const node of layout.nodes) {
  if (node.selector && node.rect) {
    if (count < 30) {
      console.log('  ' + node.selector + ' @ y=' + Math.round(node.rect.y) + ' (' + Math.round(node.rect.width) + 'x' + Math.round(node.rect.height) + ')');
    }
    count++;
  }
}
if (count > 30) {
  console.log('  ... and ' + (count - 30) + ' more nodes');
}

const snapshot = JSON.parse(accessibility.getAriaSnapshotJson(html));

function findNavSelectors(node: any, depth: number = 0): string[] {
  const role = node.role?.toLowerCase() || '';
  const tag = node.tag?.toLowerCase() || '';
  const selector = node.selector || '';

  const results: string[] = [];
  if (['navigation', 'banner', 'contentinfo'].includes(role) || ['nav', 'header', 'footer'].includes(tag)) {
    results.push('[depth=' + depth + '] ' + selector + ' (role=' + role + ', tag=' + tag + ')');
  }

  for (const child of node.children || []) {
    results.push(...findNavSelectors(child, depth + 1));
  }
  return results;
}

console.log('\nAOM nav-related nodes:');
const navNodes = findNavSelectors(snapshot);
if (navNodes.length === 0) {
  console.log('  (none found)');
} else {
  for (const s of navNodes) {
    console.log('  ' + s);
  }
}
