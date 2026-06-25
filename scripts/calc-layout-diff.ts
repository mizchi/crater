/**
 * Calc Layout Diff - Compare CSS math (calc/min/max/clamp) layout vs Chromium.
 *
 * Renders HTML in Chromium (Puppeteer) and in Crater (the conformance WPT
 * runtime), then compares the position and size of every element. Focused on
 * CSS math-function and percentage sizing across block / flex / grid / absolute,
 * which is where mixed-unit resolution (`px + pct * base`) bugs hide.
 *
 * Usage:
 *   npx tsx scripts/calc-layout-diff.ts                 # run the built-in matrix
 *   npx tsx scripts/calc-layout-diff.ts <file.html>     # diff one HTML file
 *   npx tsx scripts/calc-layout-diff.ts --json          # machine-readable output
 *   npx tsx scripts/calc-layout-diff.ts --threshold 1   # px tolerance (default 0.5)
 *
 * Exit code is non-zero when any field mismatches beyond the threshold, so this
 * doubles as a CI gate (see `just calc-diff`).
 *
 * The pure diff helpers (diffCase / walkLayout / findTestRoot / CALC_FIXTURES)
 * are exported and unit-tested in calc-layout-diff.test.ts without a browser.
 */

import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { execSync } from 'node:child_process';
import {
  LOCAL_WPT_RUNTIME_BUILD_COMMAND,
  resolveLocalWptRuntimeCandidates,
} from './wpt-runner.ts';

export interface LayoutRect {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  children?: LayoutRect[];
}

export type LayoutField = 'width' | 'height' | 'x' | 'y';

export interface FieldDiff {
  path: string;
  field: LayoutField;
  browser: number;
  crater: number;
  delta: number;
}

export interface CaseResult {
  name: string;
  fields: number;
  matched: number;
  mismatches: FieldDiff[];
}

const VIEWPORT = { width: 800, height: 600 };
const DEFAULT_THRESHOLD = 0.5;
const FIELDS: LayoutField[] = ['width', 'height', 'x', 'y'];

// --- Fixture matrix -------------------------------------------------------

function page(body: string): string {
  return (
    `<!DOCTYPE html><html><head><style>*{margin:0;box-sizing:border-box}</style></head>` +
    `<body><div id="test" style="width:400px;height:300px;position:relative">${body}</div></body></html>`
  );
}

/** Curated CSS math sizing cases that must match Chromium exactly. */
export const CALC_FIXTURES: ReadonlyArray<{ name: string; html: string }> = [
  { name: 'block calc width', html: page(`<div style="width:calc(50% + 20px);height:40px"></div>`) },
  { name: 'block calc height', html: page(`<div style="width:40px;height:calc(50% + 30px)"></div>`) },
  { name: 'block min-height calc', html: page(`<div style="width:40px;height:10px;min-height:calc(50% + 30px)"></div>`) },
  { name: 'block max-width calc', html: page(`<div style="width:390px;max-width:calc(25% + 30px);height:40px"></div>`) },
  { name: 'block margin-left calc', html: page(`<div style="width:40px;height:40px;margin-left:calc(10% + 15px)"></div>`) },
  { name: 'block padding-left calc', html: page(`<div style="width:200px;height:40px;padding-left:calc(10% + 12px)"></div>`) },
  { name: 'block nested calc', html: page(`<div style="width:calc(50% + 40px);height:80px"><div style="width:calc(50% + 10px);height:30px"></div></div>`) },
  { name: 'block min(100px,50%)', html: page(`<div style="width:min(100px,50%);height:40px"></div>`) },
  { name: 'block max(100px,50%)', html: page(`<div style="width:max(100px,50%);height:40px"></div>`) },
  { name: 'block clamp(50px,25%,300px)', html: page(`<div style="width:clamp(50px,25%,300px);height:40px"></div>`) },
  { name: 'flex row item calc', html: page(`<div style="display:flex"><div style="width:calc(50% + 30px);height:40px"></div></div>`) },
  { name: 'flex row basis calc', html: page(`<div style="display:flex"><div style="flex-basis:calc(50% + 25px);height:40px"></div></div>`) },
  { name: 'flex col item calc h', html: page(`<div style="display:flex;flex-direction:column;height:300px"><div style="height:calc(50% + 20px);width:40px"></div></div>`) },
  { name: 'flex item min-width calc', html: page(`<div style="display:flex"><div style="flex:1;min-width:calc(50% + 40px);height:40px"></div></div>`) },
  { name: 'flex item max-width calc', html: page(`<div style="display:flex"><div style="flex:1;max-width:calc(25% + 20px);height:40px"></div></div>`) },
  { name: 'grid min-width calc', html: page(`<div style="display:grid;width:auto;grid-template-columns:40px;min-width:calc(50% + 100px)"><div style="height:40px"></div></div>`) },
  { name: 'grid max-width fixed track', html: page(`<div style="display:grid;width:auto;grid-template-columns:700px;max-width:calc(25% + 30px)"><div style="height:40px"></div></div>`) },
  { name: 'grid item width calc', html: page(`<div style="display:grid;grid-template-columns:1fr"><div style="width:calc(50% + 20px);height:40px"></div></div>`) },
  { name: 'abs inset calc', html: page(`<div style="position:absolute;left:calc(25% + 10px);top:calc(10% + 5px);width:50px;height:50px"></div>`) },
  { name: 'abs width calc', html: page(`<div style="position:absolute;left:0;width:calc(50% + 30px);height:40px"></div>`) },
];

// --- Pure diff helpers ----------------------------------------------------

/** Children with text/anonymous nodes removed (Crater emits #text nodes). */
export function meaningfulChildren(node: LayoutRect): LayoutRect[] {
  return (node.children ?? []).filter((c) => !String(c.id).startsWith('#text'));
}

/** Locate the `#test` subtree, falling back to the node itself. */
export function findTestRoot(node: LayoutRect): LayoutRect {
  if (node.id === 'div#test' || String(node.id).endsWith('#test')) return node;
  for (const c of node.children ?? []) {
    const found = findTestRootOrNull(c);
    if (found) return found;
  }
  return node;
}

function findTestRootOrNull(node: LayoutRect): LayoutRect | null {
  if (node.id === 'div#test' || String(node.id).endsWith('#test')) return node;
  for (const c of node.children ?? []) {
    const found = findTestRootOrNull(c);
    if (found) return found;
  }
  return null;
}

/** Walk two structurally-aligned trees, recording per-field deltas. */
export function walkLayout(
  browser: LayoutRect,
  crater: LayoutRect,
  path: string,
  rows: FieldDiff[],
): void {
  for (const field of FIELDS) {
    const bv = browser[field] ?? 0;
    const cv = crater[field] ?? 0;
    rows.push({ path, field, browser: bv, crater: cv, delta: Math.abs(bv - cv) });
  }
  const bc = meaningfulChildren(browser);
  const cc = meaningfulChildren(crater);
  const n = Math.min(bc.length, cc.length);
  for (let i = 0; i < n; i++) {
    walkLayout(bc[i]!, cc[i]!, `${path}>${bc[i]!.id}`, rows);
  }
}

/** Diff a single case's browser vs Crater trees at the given px threshold. */
export function diffCase(
  name: string,
  browser: LayoutRect,
  crater: LayoutRect,
  threshold = DEFAULT_THRESHOLD,
): CaseResult {
  const rows: FieldDiff[] = [];
  walkLayout(findTestRoot(browser), findTestRoot(crater), 'test', rows);
  const mismatches = rows
    .filter((r) => r.delta > threshold)
    .sort((a, b) => b.delta - a.delta);
  return { name, fields: rows.length, matched: rows.length - mismatches.length, mismatches };
}

// --- Renderers (browser + Crater) -----------------------------------------

type RenderFn = (html: string, w: number, h: number) => string;

async function loadCraterRenderer(): Promise<RenderFn> {
  // Wire up the vendored proportional font measure (as wpt-runner does), so text
  // is measured against a real font instead of the crude monospace fallback.
  const { createTextIntrinsicFnFromMeasureText } = await import('./text-intrinsic.ts');
  const { createVendoredFontMeasure } = await import('./wpt-font-measure.ts');
  (globalThis as any).__craterMeasureTextIntrinsic = createTextIntrinsicFnFromMeasureText(
    createVendoredFontMeasure(),
  );
  // Refresh the local WPT runtime so the diff reflects current MoonBit sources.
  try {
    execSync(LOCAL_WPT_RUNTIME_BUILD_COMMAND, { stdio: 'ignore', cwd: process.cwd() });
  } catch {
    // Best-effort: fall through to whatever artifact already exists.
  }
  const candidate = resolveLocalWptRuntimeCandidates().find((p) => fs.existsSync(p));
  if (!candidate) {
    throw new Error(
      'Crater WPT runtime not found. Build it with:\n  ' + LOCAL_WPT_RUNTIME_BUILD_COMMAND,
    );
  }
  const mod: any = await import(pathToFileURL(candidate).href);
  return mod.renderHtmlToJsonForWpt as RenderFn;
}

function craterLayout(render: RenderFn, html: string): LayoutRect {
  return JSON.parse(render(html, VIEWPORT.width, VIEWPORT.height));
}

async function browserLayout(html: string): Promise<LayoutRect> {
  const puppeteer = (await import('puppeteer')).default;
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const pageObj = await browser.newPage();
    await pageObj.setViewport(VIEWPORT);
    await pageObj.setContent(html, { waitUntil: 'domcontentloaded', timeout: 5000 });
    return (await pageObj.evaluate(`(() => {
      function rectOf(el, parent) {
        const r = el.getBoundingClientRect();
        const kids = [];
        for (const c of el.children) {
          if (['SCRIPT','STYLE','LINK','META','TITLE','HEAD'].includes(c.tagName)) continue;
          kids.push(rectOf(c, el));
        }
        let x = r.left, y = r.top;
        if (parent) { const pr = parent.getBoundingClientRect(); x = r.left - pr.left; y = r.top - pr.top; }
        const id = el.id ? el.tagName.toLowerCase()+'#'+el.id : el.tagName.toLowerCase();
        return { id, x, y, width: r.width, height: r.height, children: kids };
      }
      const t = document.getElementById('test') || document.body;
      return { ...rectOf(t, null), x: 0, y: 0 };
    })()`)) as LayoutRect;
  } finally {
    await browser.close();
  }
}

// --- CLI ------------------------------------------------------------------

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const json = args.includes('--json');
  const thIdx = args.indexOf('--threshold');
  const threshold = thIdx >= 0 ? Number(args[thIdx + 1]) : DEFAULT_THRESHOLD;
  const fileArg = args.find((a) => !a.startsWith('--') && a !== String(threshold));

  const cases =
    fileArg && fs.existsSync(fileArg)
      ? [{ name: fileArg, html: fs.readFileSync(fileArg, 'utf-8') }]
      : CALC_FIXTURES;

  const render = await loadCraterRenderer();
  const results: CaseResult[] = [];
  for (const { name, html } of cases) {
    const [browser, crater] = [await browserLayout(html), craterLayout(render, html)];
    results.push(diffCase(name, browser, crater, threshold));
  }

  if (json) {
    console.log(JSON.stringify({ threshold, results }, null, 2));
  } else {
    for (const r of results) {
      const tag = r.mismatches.length === 0 ? 'OK ' : 'BAD';
      console.log(`[${tag}] ${r.name}  ${r.matched}/${r.fields} fields match (<=${threshold}px)`);
      for (const m of r.mismatches.slice(0, 8)) {
        console.log(
          `        Δ${m.delta.toFixed(1)}px  ${m.path} .${m.field}  ` +
            `browser=${m.browser.toFixed(1)} crater=${m.crater.toFixed(1)}`,
        );
      }
    }
  }

  const totalMismatches = results.reduce((s, r) => s + r.mismatches.length, 0);
  if (!json) {
    console.log(
      `\n${results.length} cases, ${totalMismatches} mismatched field(s) across ` +
        `${results.reduce((s, r) => s + r.fields, 0)} compared.`,
    );
  }
  process.exitCode = totalMismatches === 0 ? 0 : 1;
}

// Only run the browser-driven CLI when invoked directly, not when imported by tests.
if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
