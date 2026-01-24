/**
 * DOM benchmark for Crater mock DOM (Node/Selector focused).
 *
 * Usage:
 *   npx tsx scripts/dom-bench.ts
 */
import fs from 'fs';
import path from 'path';
import vm from 'vm';

function buildMockDomCode(): string {
  const mbtPath = path.join(process.cwd(), 'browser/src/js/js_runtime_quickjs.mbt');
  const content = fs.readFileSync(mbtPath, 'utf-8');
  const lines = content.split('\n');
  const setupLines: string[] = [];
  let inSetupCode = false;

  for (const line of lines) {
    if (line.includes('const setupCode = `')) {
      inSetupCode = true;
      continue;
    }
    if (inSetupCode) {
      if (line.trim() === '#|   `;' || line.trim() === '#|  `;') break;
      if (line.trim().startsWith('#|')) {
        setupLines.push(line.replace(/^\s*#\|\s?/, ''));
      }
    }
  }

  return setupLines.join('\n');
}

const benchCode = `
  function buildTree(rows, cols) {
    const root = document.createElement('div');
    root.id = 'bench-root';
    document.body.appendChild(root);
    for (let r = 0; r < rows; r++) {
      const row = document.createElement('div');
      row.className = 'row';
      row.setAttribute('data-row', String(r));
      root.appendChild(row);
      for (let c = 0; c < cols; c++) {
        const cell = document.createElement('div');
        cell.className = 'cell item';
        cell.setAttribute('data-col', String(c));
        cell.textContent = 'cell-' + r + '-' + c;
        row.appendChild(cell);
      }
    }
    return root;
  }

  function buildTextBlock(count) {
    const el = document.createElement('div');
    for (let i = 0; i < count; i++) {
      el.appendChild(document.createTextNode('x'));
    }
    return el;
  }

  function bench(name, iters, fn) {
    const start = Date.now();
    for (let i = 0; i < iters; i++) fn();
    const ms = Date.now() - start;
    return { name, iters, ms, perOpMs: ms / iters };
  }

  const results = [];
  const root = buildTree(40, 40); // 1,600 cells
  const sampleCell = root.querySelector('.cell');
  const deepNode = root.querySelector('.row .cell');

  results.push(bench('querySelectorAll(.cell)', 200, () => root.querySelectorAll('.cell').length));
  results.push(bench('querySelectorAll(.row .cell)', 100, () => root.querySelectorAll('.row .cell').length));
  results.push(bench('getElementsByClassName(cell)', 200, () => root.getElementsByClassName('cell').length));
  results.push(bench('matches(.cell.item)', 5000, () => sampleCell.matches('.cell.item')));
  results.push(bench('closest(.row)', 5000, () => sampleCell.closest('.row')));

  const textBlock = buildTextBlock(2000);
  results.push(bench('normalize(text x2000)', 100, () => textBlock.normalize()));

  results.push(bench('cloneNode(deep)', 50, () => root.cloneNode(true)));
  results.push(bench('compareDocumentPosition', 5000, () => root.compareDocumentPosition(deepNode)));

  results;
`;

const mockDomCode = buildMockDomCode();
const sandbox = {
  console: {
    log: (..._args: unknown[]) => {},
    error: (..._args: unknown[]) => {},
    warn: (..._args: unknown[]) => {},
  },
};

const context = vm.createContext(sandbox);
vm.runInContext(mockDomCode, context);
const results = vm.runInContext(benchCode, context) as Array<{
  name: string;
  iters: number;
  ms: number;
  perOpMs: number;
}>;

results.sort((a, b) => b.ms - a.ms);
console.log('DOM bench results (sorted by total ms):');
for (const r of results) {
  console.log(
    `${r.name.padEnd(32)}  total=${r.ms.toFixed(1)}ms  per=${r.perOpMs.toFixed(4)}ms`
  );
}
