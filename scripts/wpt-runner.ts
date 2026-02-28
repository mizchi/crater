/**
 * WPT (Web Platform Tests) Runner for Crater
 *
 * Compares CSS layout between browser (Puppeteer) and Crater
 * Uses wpt/ submodule directly
 *
 * Usage:
 *   npx tsx scripts/wpt-runner.ts css-flexbox
 *   npx tsx scripts/wpt-runner.ts wpt/css/css-flexbox/flex-001.html
 *   npx tsx scripts/wpt-runner.ts --all
 */

import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { pathToFileURL } from 'url';

// Load config from wpt.json
const wptConfig = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'wpt.json'), 'utf-8'));
const CSS_MODULES: string[] = wptConfig.modules;
const INCLUDE_PREFIXES: string[] = wptConfig.includePrefixes;
const RECURSIVE_MODULES: string[] = wptConfig.recursiveModules ?? [];

const WPT_DIR = 'wpt/css';
const WPT_ROOT = path.join(process.cwd(), 'wpt');

// Types
interface Rect {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

interface LayoutNode {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  margin: Rect;
  padding: Rect;
  border: Rect;
  children: LayoutNode[];
}

interface TestResult {
  name: string;
  passed: boolean;
  mismatches: Mismatch[];
  totalNodes: number;
}

interface Mismatch {
  path: string;
  property: string;
  browser: number;
  crater: number;
  diff: number;
}

interface CliOptions {
  args: string[];
  workers: number;
  jsonOutput?: string;
}

interface WptCompatShardReport {
  schemaVersion: 1;
  suite: 'wpt-css';
  target: string;
  passed: number;
  failed: number;
  errors: number;
  total: number;
  passRate: number;
  generatedAt: string;
  workers: number;
}

type RenderHtmlToJsonFn = (html: string, width: number, height: number) => string;

type ExternalTextIntrinsicResult =
  | { minWidth?: number; maxWidth?: number; minHeight?: number; maxHeight?: number; min_width?: number; max_width?: number; min_height?: number; max_height?: number }
  | [number, number, number, number]
  | null
  | undefined;
type ExternalImageIntrinsicResult =
  | { width?: number; height?: number; w?: number; h?: number }
  | [number, number]
  | null
  | undefined;
type ExternalTextIntrinsicFn = (
  text: string,
  fontSize: number,
  lineHeight: number,
  whiteSpace: string,
  writingMode: string,
  availableWidth: number,
  availableHeight: number,
) => ExternalTextIntrinsicResult;
type ExternalImageIntrinsicFn = (src: string) => ExternalImageIntrinsicResult;

declare global {
  var __craterMeasureTextIntrinsic: ExternalTextIntrinsicFn | undefined;
  var __craterResolveImageIntrinsicSize: ExternalImageIntrinsicFn | undefined;
}

let renderHtmlToJsonImpl: RenderHtmlToJsonFn | null = null;
let currentCraterHtmlPath: string | null = null;
const LOCAL_WPT_RUNTIME = pathToFileURL(
  path.join(process.cwd(), '_build/js/release/build/wpt_runtime/wpt_runtime.js')
).href;
const LOCAL_WASM_DIST = pathToFileURL(
  path.join(process.cwd(), 'wasm/dist/crater.js')
).href;

function hasFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function resolveFontFixturePath(): string | null {
  const candidates = [
    process.env.CRATER_TEXT_FONT_PATH,
    path.join(process.env.HOME ?? '', 'ghq/github.com/mizchi/font/fixtures/NotoSansMono-Regular.ttf'),
  ].filter((v): v is string => Boolean(v));
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

function createTextIntrinsicFnFromMeasureText(
  measureText: (text: string, fontSize: number) => number,
): ExternalTextIntrinsicFn {
  let loadedFont = false;
  return (
    text: string,
    fontSize: number,
    lineHeight: number,
    whiteSpace: string,
    writingMode: string,
    availableWidth: number,
    _availableHeight: number,
  ) => {
    const effectiveLineHeight = lineHeight > 0 ? lineHeight : (fontSize > 0 ? fontSize : 16);
    const measure = (s: string): number => {
      const measured = measureText(s, fontSize);
      if (hasFiniteNumber(measured) && measured >= 0) return measured;
      return s.length * (fontSize > 0 ? fontSize * 0.5 : 8);
    };
    const explicitLines = text.split('\n');
    const maxWidth = explicitLines.reduce((acc, line) => Math.max(acc, measure(line)), 0);
    const minWordWidth = explicitLines.reduce((acc, line) => {
      const words = line.split(/\s+/).filter(Boolean);
      if (words.length === 0) return acc;
      return Math.max(acc, ...words.map(word => measure(word)));
    }, 0);
    const noWrap = whiteSpace.toLowerCase().includes('nowrap');
    const spaceWidth = measure(' ');
    let wrappedLines = 0;
    for (const line of explicitLines) {
      if (noWrap || availableWidth <= 0) {
        wrappedLines += 1;
        continue;
      }
      const words = line.trim().split(/\s+/).filter(Boolean);
      if (words.length === 0) {
        wrappedLines += 1;
        continue;
      }
      let current = 0;
      for (const word of words) {
        const width = measure(word);
        if (current === 0) {
          current = width;
          continue;
        }
        const next = current + spaceWidth + width;
        if (next <= availableWidth) {
          current = next;
        } else {
          wrappedLines += 1;
          current = width;
        }
      }
      wrappedLines += 1;
    }
    const minHeight = Math.max(explicitLines.length, 1) * effectiveLineHeight;
    const maxHeight = Math.max(wrappedLines, 1) * effectiveLineHeight;
    const isVertical = writingMode.toLowerCase().includes('vertical');
    if (isVertical) {
      return {
        minWidth: minHeight,
        maxWidth: maxHeight,
        minHeight: minWordWidth,
        maxHeight: maxWidth,
      };
    }
    return {
      minWidth: minWordWidth,
      maxWidth,
      minHeight,
      maxHeight,
    };
  };
}

function maybeLoadFontIntoModule(mod: Record<string, unknown>): void {
  if (typeof mod.loadFont !== 'function') return;
  const fontPath = resolveFontFixturePath();
  if (!fontPath) return;
  try {
    const bytes = new Uint8Array(fs.readFileSync(fontPath));
    (mod.loadFont as (bytes: Uint8Array) => unknown)(bytes);
  } catch (err) {
    console.warn(`[wpt-runner] failed to load font fixture: ${fontPath}`, err);
  }
}

function parsePngSize(bytes: Uint8Array): [number, number] | null {
  if (bytes.length < 24) return null;
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (let i = 0; i < signature.length; i++) {
    if (bytes[i] !== signature[i]) return null;
  }
  const width =
    ((bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19]) >>> 0;
  const height =
    ((bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23]) >>> 0;
  if (width === 0 || height === 0) return null;
  return [width, height];
}

function parseGifSize(bytes: Uint8Array): [number, number] | null {
  if (bytes.length < 10) return null;
  if (bytes[0] !== 0x47 || bytes[1] !== 0x49 || bytes[2] !== 0x46) return null;
  const width = bytes[6] | (bytes[7] << 8);
  const height = bytes[8] | (bytes[9] << 8);
  if (width === 0 || height === 0) return null;
  return [width, height];
}

function parseJpegSize(bytes: Uint8Array): [number, number] | null {
  if (bytes.length < 4 || bytes[0] !== 0xFF || bytes[1] !== 0xD8) return null;
  let i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] !== 0xFF) {
      i += 1;
      continue;
    }
    const marker = bytes[i + 1];
    if (marker === 0xD8 || marker === 0xD9) {
      i += 2;
      continue;
    }
    if (marker === 0xDA) break;
    const len = (bytes[i + 2] << 8) | bytes[i + 3];
    if (len < 2 || i + 1 + len >= bytes.length) break;
    const isSofMarker =
      (marker >= 0xC0 && marker <= 0xC3) ||
      (marker >= 0xC5 && marker <= 0xC7) ||
      (marker >= 0xC9 && marker <= 0xCB) ||
      (marker >= 0xCD && marker <= 0xCF);
    if (isSofMarker) {
      const height = (bytes[i + 5] << 8) | bytes[i + 6];
      const width = (bytes[i + 7] << 8) | bytes[i + 8];
      if (width > 0 && height > 0) return [width, height];
      return null;
    }
    i += 2 + len;
  }
  return null;
}

function parseSvgLength(value: string | undefined): number | null {
  if (!value) return null;
  const trimmed = value.trim();
  const match = /^([0-9]*\.?[0-9]+)/.exec(trimmed);
  if (!match) return null;
  const n = Number(match[1]);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

function parseSvgSize(source: string): [number, number] | null {
  const widthMatch = /(?:^|\s)width\s*=\s*["']([^"']+)["']/i.exec(source);
  const heightMatch = /(?:^|\s)height\s*=\s*["']([^"']+)["']/i.exec(source);
  const width = parseSvgLength(widthMatch?.[1]);
  const height = parseSvgLength(heightMatch?.[1]);
  if (width && height) return [width, height];

  const viewBoxMatch = /(?:^|\s)viewBox\s*=\s*["']([^"']+)["']/i.exec(source);
  if (viewBoxMatch) {
    const parts = viewBoxMatch[1].trim().split(/[\s,]+/);
    if (parts.length >= 4) {
      const vbWidth = Number(parts[2]);
      const vbHeight = Number(parts[3]);
      if (Number.isFinite(vbWidth) && vbWidth > 0 && Number.isFinite(vbHeight) && vbHeight > 0) {
        if (width) return [width, width * (vbHeight / vbWidth)];
        if (height) return [height * (vbWidth / vbHeight), height];
        return [vbWidth, vbHeight];
      }
    }
  }
  if (width && !height) return [width, width];
  if (height && !width) return [height, height];
  return null;
}

function createFileBackedImageIntrinsicResolver(): ExternalImageIntrinsicFn {
  return (src: string) => {
    if (!src || isExternalResourceUrl(src)) return null;
    const htmlPath = currentCraterHtmlPath;
    if (!htmlPath) return null;
    const resolved = resolveLocalResourcePath(path.dirname(htmlPath), src);
    if (!resolved || !fs.existsSync(resolved)) return null;

    try {
      const bytes = new Uint8Array(fs.readFileSync(resolved));
      const ext = path.extname(stripQueryAndHash(src)).toLowerCase();
      let size: [number, number] | null = null;
      if (ext === '.png') {
        size = parsePngSize(bytes);
      } else if (ext === '.gif') {
        size = parseGifSize(bytes);
      } else if (ext === '.jpg' || ext === '.jpeg') {
        size = parseJpegSize(bytes);
      } else if (ext === '.svg') {
        size = parseSvgSize(Buffer.from(bytes).toString('utf-8'));
      } else {
        size = parsePngSize(bytes) ?? parseGifSize(bytes) ?? parseJpegSize(bytes);
      }
      if (!size) return null;
      return { width: size[0], height: size[1] };
    } catch {
      return null;
    }
  };
}

function isModuleNotFoundError(err: unknown): boolean {
  if (!err || typeof err !== 'object') return false;
  const code = 'code' in err ? String((err as { code?: unknown }).code ?? '') : '';
  if (code === 'ERR_MODULE_NOT_FOUND') return true;
  const message = 'message' in err ? String((err as { message?: unknown }).message ?? '') : '';
  return message.includes('Cannot find package') || message.includes('Cannot find module');
}

async function importFirstAvailable(specifiers: string[]): Promise<unknown | null> {
  for (const specifier of specifiers) {
    try {
      const moduleId =
        fs.existsSync(specifier)
          ? pathToFileURL(path.resolve(specifier)).href
          : specifier;
      return await import(moduleId);
    } catch (err) {
      if (!isModuleNotFoundError(err)) {
        console.warn(`[wpt-runner] failed to import "${specifier}":`, err);
      }
    }
  }
  return null;
}

function resolveTextIntrinsicFn(mod: unknown): ExternalTextIntrinsicFn | null {
  if (!mod || typeof mod !== 'object') return null;
  const rec = mod as Record<string, unknown>;
  const direct = rec.measureTextIntrinsic ?? rec.measureText ?? rec.default;
  if (typeof direct === 'function') return direct as ExternalTextIntrinsicFn;
  if (typeof rec.measureText === 'function') {
    maybeLoadFontIntoModule(rec);
    return createTextIntrinsicFnFromMeasureText(
      rec.measureText as (text: string, fontSize: number) => number,
    );
  }
  if (rec.default && typeof rec.default === 'object') {
    const nested = rec.default as Record<string, unknown>;
    if (typeof nested.measureText === 'function') {
      maybeLoadFontIntoModule(nested);
      return createTextIntrinsicFnFromMeasureText(
        nested.measureText as (text: string, fontSize: number) => number,
      );
    }
  }
  const factory = rec.createTextMeasurer;
  if (typeof factory === 'function') {
    try {
      const built = (factory as () => unknown)();
      if (typeof built === 'function') {
        return built as ExternalTextIntrinsicFn;
      }
    } catch {
      return null;
    }
  }
  return null;
}

function resolveImageIntrinsicFn(mod: unknown): ExternalImageIntrinsicFn | null {
  if (!mod || typeof mod !== 'object') return null;
  const rec = mod as Record<string, unknown>;
  const direct =
    rec.resolveImageIntrinsicSize ??
    rec.resolveIntrinsicSize ??
    rec.imageIntrinsicSize ??
    rec.default;
  if (typeof direct === 'function') return direct as ExternalImageIntrinsicFn;
  const factory = rec.createImageIntrinsicResolver;
  if (typeof factory === 'function') {
    try {
      const built = (factory as () => unknown)();
      if (typeof built === 'function') {
        return built as ExternalImageIntrinsicFn;
      }
    } catch {
      return null;
    }
  }
  return null;
}

async function configureExternalIntrinsicProviders(): Promise<void> {
  const localFontSpecifiers = [
    path.join(process.env.HOME ?? '', 'ghq/github.com/mizchi/font/_build/js/release/build/js/js.js'),
    path.join(process.env.HOME ?? '', 'ghq/github.com/mizchi/font/_build/js/debug/build/js/js.js'),
    path.join(process.env.HOME ?? '', 'ghq/github.com/mizchi/font/target/js/release/build/js/js.js'),
  ];
  const textSpecifiers = [
    process.env.CRATER_TEXT_MODULE,
    'mizchi/text',
    '@mizchi/text',
    ...localFontSpecifiers,
  ].filter((v): v is string => Boolean(v));
  const imageSpecifiers = [
    process.env.CRATER_IMAGE_MODULE,
    'mizchi/image',
    '@mizchi/image',
  ].filter((v): v is string => Boolean(v));
  const enableFileImageResolver = ['1', 'true', 'yes'].includes(
    String(process.env.CRATER_IMAGE_FILE_RESOLVE ?? '').toLowerCase(),
  );

  const textModule = await importFirstAvailable(textSpecifiers);
  const textFn = resolveTextIntrinsicFn(textModule);
  if (textFn) {
    globalThis.__craterMeasureTextIntrinsic = textFn;
  } else {
    delete globalThis.__craterMeasureTextIntrinsic;
  }

  const imageModule = await importFirstAvailable(imageSpecifiers);
  const imageFn = resolveImageIntrinsicFn(imageModule);
  const fallbackImageFn = createFileBackedImageIntrinsicResolver();
  if (imageFn) {
    if (enableFileImageResolver) {
      globalThis.__craterResolveImageIntrinsicSize = (src: string) => {
        const fromModule = imageFn(src);
        if (fromModule) return fromModule;
        return fallbackImageFn(src);
      };
    } else {
      globalThis.__craterResolveImageIntrinsicSize = imageFn;
    }
  } else if (enableFileImageResolver) {
    globalThis.__craterResolveImageIntrinsicSize = fallbackImageFn;
  } else {
    delete globalThis.__craterResolveImageIntrinsicSize;
  }
}

async function initCraterRenderer(): Promise<void> {
  if (renderHtmlToJsonImpl) return;
  await configureExternalIntrinsicProviders();

  // Always refresh local runtime first so WPT reflects latest MoonBit changes.
  try {
    execSync('moon build src/wpt_runtime --target js --release --warn-list -27-29', {
      stdio: 'ignore',
      cwd: process.cwd(),
    });
    const mod = await import(LOCAL_WPT_RUNTIME);
    renderHtmlToJsonImpl = mod.renderHtmlToJsonForWpt as RenderHtmlToJsonFn;
    return;
  } catch {
    // Fallback to committed wasm/dist runtime for environments where local build is unavailable.
  }

  const mod = await import(LOCAL_WASM_DIST);
  renderHtmlToJsonImpl = (html: string, width: number, height: number) => (
    mod.renderer.renderHtmlToJson(html, width, height)
  );
}

// Configuration
const TOLERANCE = 15;
const VIEWPORT = { width: 800, height: 600 };
const DEFAULT_CONCURRENCY = 6;
const CI_PUPPETEER_ARGS = ['--no-sandbox', '--disable-setuid-sandbox'];

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
  p { margin: 0; }
</style>
`;

/**
 * Check if a file is a layout test
 */
function isLayoutTest(filename: string): boolean {
  if (!filename.endsWith('.html')) return false;
  if (filename.endsWith('-ref.html')) return false;
  if (filename.includes('support')) return false;
  if (filename.startsWith('reference')) return false;
  return INCLUDE_PREFIXES.some(prefix => filename.startsWith(prefix));
}

function isScriptHarnessTest(htmlPath: string): boolean {
  try {
    const source = fs.readFileSync(htmlPath, 'utf-8').toLowerCase();
    return source.includes('/resources/testharness.js') ||
      source.includes('/resources/testharnessreport.js') ||
      source.includes('/resources/check-layout-th.js') ||
      source.includes('/css/support/interpolation-testcommon.js');
  } catch {
    return false;
  }
}

function collectHtmlFilesRecursive(dir: string): string[] {
  if (!fs.existsSync(dir)) return [];

  const files: string[] = [];
  const stack = [dir];

  while (stack.length > 0) {
    const current = stack.pop()!;
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (entry.isFile() && entry.name.endsWith('.html')) {
        files.push(fullPath);
      }
    }
  }

  return files;
}

/**
 * Get test files for a module
 */
function getTestFiles(moduleName: string): string[] {
  const moduleDir = path.join(WPT_DIR, moduleName);
  if (!fs.existsSync(moduleDir)) {
    return [];
  }

  const recursive = RECURSIVE_MODULES.includes(moduleName);
  if (recursive) {
    return collectHtmlFilesRecursive(moduleDir)
      .filter(fullPath => isLayoutTest(path.basename(fullPath)))
      .filter(fullPath => !isScriptHarnessTest(fullPath))
      .map(fullPath => path.relative(process.cwd(), fullPath));
  }

  return fs.readdirSync(moduleDir)
    .filter(isLayoutTest)
    .map(f => path.join(moduleDir, f))
    .filter(fullPath => !isScriptHarnessTest(fullPath));
}

/**
 * Inline external CSS files into HTML
 */
function isExternalResourceUrl(url: string): boolean {
  return url.startsWith('http://') ||
    url.startsWith('https://') ||
    url.startsWith('//') ||
    url.startsWith('data:') ||
    url.startsWith('blob:');
}

function stripQueryAndHash(url: string): string {
  return url.split('#')[0].split('?')[0];
}

function resolveLocalResourcePath(baseDir: string, rawRef: string): string | null {
  if (isExternalResourceUrl(rawRef)) return null;
  const ref = stripQueryAndHash(rawRef.trim());
  if (!ref) return null;
  if (ref.startsWith('/')) {
    return path.join(WPT_ROOT, ref.slice(1));
  }
  return path.resolve(baseDir, ref);
}

function mimeTypeFromPath(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
  case '.css': return 'text/css';
  case '.ttf': return 'font/ttf';
  case '.otf': return 'font/otf';
  case '.woff': return 'font/woff';
  case '.woff2': return 'font/woff2';
  case '.png': return 'image/png';
  case '.jpg':
  case '.jpeg': return 'image/jpeg';
  case '.gif': return 'image/gif';
  case '.svg': return 'image/svg+xml';
  default: return 'application/octet-stream';
  }
}

function inlineCssAssetUrls(cssContent: string, cssPath: string): string {
  const cssDir = path.dirname(cssPath);
  const cssUrlRegex = /url\(\s*(?:"([^"]+)"|'([^']+)'|([^'")\s]+))\s*\)/gi;
  return cssContent.replace(cssUrlRegex, (match, g1, g2, g3) => {
    const assetRef = (g1 || g2 || g3 || '').trim();
    if (!assetRef || isExternalResourceUrl(assetRef)) return match;

    const assetPath = resolveLocalResourcePath(cssDir, assetRef);
    if (!assetPath || !fs.existsSync(assetPath)) return match;
    const ext = path.extname(assetPath).toLowerCase();
    // Keep font loading behavior unchanged from previous runner
    // to avoid introducing font-metric drift versus Crater.
    if (ext === '.ttf' || ext === '.otf' || ext === '.woff' || ext === '.woff2') {
      return match;
    }

    try {
      const bytes = fs.readFileSync(assetPath);
      const mime = mimeTypeFromPath(assetPath);
      const encoded = bytes.toString('base64');
      return `url("data:${mime};base64,${encoded}")`;
    } catch {
      return match;
    }
  });
}

function inlineExternalCSS(html: string, htmlPath: string): string {
  const htmlDir = path.dirname(htmlPath);
  const linkRegex = /<link\s+[^>]*rel\s*=\s*["']stylesheet["'][^>]*>/gi;

  return html.replace(linkRegex, (match) => {
    const hrefMatch = match.match(/href\s*=\s*["']([^"']+)["']/i);
    if (!hrefMatch) return match;

    const href = hrefMatch[1];
    if (isExternalResourceUrl(href)) {
      return match;
    }

    const cssPath = resolveLocalResourcePath(htmlDir, href);
    if (!cssPath) return match;
    try {
      if (fs.existsSync(cssPath)) {
        const cssContent = fs.readFileSync(cssPath, 'utf-8');
        const inlinedCss = inlineCssAssetUrls(cssContent, cssPath);
        return `<style>/* Inlined from ${href} */\n${inlinedCss}</style>`;
      }
    } catch {}
    return `<!-- CSS not found: ${href} -->`;
  });
}

/**
 * Extract layout tree from browser using Puppeteer
 */
async function getBrowserLayout(browser: puppeteer.Browser, htmlPath: string): Promise<LayoutNode> {
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);
  page.on('pageerror', () => {});
  page.setDefaultTimeout(5000);

  const htmlContent = prepareHtmlContent(htmlPath);
  await page.setContent(htmlContent, { waitUntil: 'domcontentloaded', timeout: 5000 });

  const layout = await page.evaluate(`(() => {
    function getComputedRect(el, prop) {
      const style = getComputedStyle(el);
      if (prop === 'border') {
        return {
          top: parseFloat(style.borderTopWidth) || 0,
          right: parseFloat(style.borderRightWidth) || 0,
          bottom: parseFloat(style.borderBottomWidth) || 0,
          left: parseFloat(style.borderLeftWidth) || 0,
        };
      }
      return {
        top: parseFloat(style[prop + 'Top']) || 0,
        right: parseFloat(style[prop + 'Right']) || 0,
        bottom: parseFloat(style[prop + 'Bottom']) || 0,
        left: parseFloat(style[prop + 'Left']) || 0,
      };
    }

    function getNodeId(el) {
      if (el.id) return el.tagName.toLowerCase() + '#' + el.id;
      if (el.className && typeof el.className === 'string') {
        const firstClass = el.className.split(' ')[0];
        if (firstClass) return el.tagName.toLowerCase() + '.' + firstClass;
      }
      return el.tagName.toLowerCase();
    }

    function extractLayout(el, parentRect) {
      const rect = el.getBoundingClientRect();
      const padding = getComputedRect(el, 'padding');
      const border = getComputedRect(el, 'border');
      const children = [];

      for (const child of el.children) {
        if (['SCRIPT', 'STYLE', 'LINK', 'META', 'TITLE', 'HEAD'].includes(child.tagName)) continue;
        children.push(extractLayout(child, rect));
      }

      let x = rect.left;
      let y = rect.top;
      if (parentRect) {
        const parentPadding = el.parentElement ? getComputedRect(el.parentElement, 'padding') : { top: 0, left: 0, right: 0, bottom: 0 };
        const parentBorder = el.parentElement ? getComputedRect(el.parentElement, 'border') : { top: 0, left: 0, right: 0, bottom: 0 };
        x = rect.left - parentRect.left - parentBorder.left - parentPadding.left;
        y = rect.top - parentRect.top - parentBorder.top - parentPadding.top;
      }

      return {
        id: getNodeId(el),
        x: x,
        y: y,
        width: rect.width,
        height: rect.height,
        margin: getComputedRect(el, 'margin'),
        padding: padding,
        border: border,
        children: children,
        top: 0, right: 0, bottom: 0, left: 0
      };
    }

    const body = document.body;
    function normalizeRoot(layout) {
      return Object.assign({}, layout, { x: 0, y: 0 });
    }

    const testElement = document.getElementById('test') ||
      document.getElementById('container') ||
      document.getElementById('target');
    if (testElement) {
      return normalizeRoot(extractLayout(testElement));
    }

    const gridElement = document.querySelector('.grid');
    if (gridElement) {
      return normalizeRoot(extractLayout(gridElement));
    }

    const children = Array.from(body.children).filter(
      el => !['SCRIPT', 'STYLE', 'LINK', 'META', 'TITLE', 'HEAD', 'P'].includes(el.tagName) && el.id !== 'log'
    );
    if (children.length === 1) {
      return normalizeRoot(extractLayout(children[0]));
    }
    if (children.length === 0) {
      const allTables = Array.from(document.querySelectorAll('table'));
      if (allTables.length === 1) {
        return normalizeRoot(extractLayout(allTables[0]));
      }
    }

    const divChildren = children.filter(el => el.tagName === 'DIV');
    if (divChildren.length >= 1) {
      return normalizeRoot(extractLayout(divChildren[0]));
    }

    return normalizeRoot(extractLayout(body));
  })()`);

  await page.close();
  return normalizeZeroSizedRootChildren(layout as LayoutNode);
}

function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  htmlContent = inlineExternalCSS(htmlContent, htmlPath);
  htmlContent = htmlContent.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');

  const headOpenTag = /<head\b[^>]*>/i;
  const bodyOpenTag = /<body\b[^>]*>/i;
  if (headOpenTag.test(htmlContent)) {
    htmlContent = htmlContent.replace(headOpenTag, (m) => m + CSS_RESET);
  } else if (bodyOpenTag.test(htmlContent)) {
    htmlContent = htmlContent.replace(bodyOpenTag, (m) => CSS_RESET + m);
  } else {
    htmlContent = CSS_RESET + htmlContent;
  }
  return htmlContent;
}

function normalizeZeroSizedRootChildren(node: LayoutNode): LayoutNode {
  const isZeroSizedRoot =
    Math.abs(node.width) <= 0.5 &&
    Math.abs(node.height) <= 0.5;
  if (!isZeroSizedRoot || node.children.length === 0) {
    return node;
  }

  const meaningfulChildren = node.children.filter(c => !c.id.startsWith('#text'));
  if (meaningfulChildren.length === 0) {
    return node;
  }

  let minX = Number.POSITIVE_INFINITY;
  let minY = Number.POSITIVE_INFINITY;
  for (const child of meaningfulChildren) {
    if (child.x < minX) minX = child.x;
    if (child.y < minY) minY = child.y;
  }
  if (!Number.isFinite(minX) || !Number.isFinite(minY)) {
    return node;
  }
  if (Math.abs(minX) <= 0.5 && Math.abs(minY) <= 0.5) {
    return node;
  }

  return {
    ...node,
    children: node.children.map(child => ({
      ...child,
      x: child.x - minX,
      y: child.y - minY,
    })),
  };
}

function getCraterLayout(htmlPath: string): LayoutNode {
  if (!renderHtmlToJsonImpl) {
    throw new Error('Crater renderer is not initialized');
  }

  function normalizeRoot(node: LayoutNode): LayoutNode {
    return { ...node, x: 0, y: 0 };
  }
  function finalizeRoot(node: LayoutNode): LayoutNode {
    return normalizeZeroSizedRootChildren(normalizeRoot(node));
  }

  const htmlContent = prepareHtmlContent(htmlPath);
  const resolvedHtmlPath = path.resolve(htmlPath);
  currentCraterHtmlPath = resolvedHtmlPath;
  let result = '';
  try {
    result = renderHtmlToJsonImpl(htmlContent, 800, 600);
  } finally {
    currentCraterHtmlPath = null;
  }
  let layout = JSON.parse(result) as LayoutNode;

  if (layout.id === 'body' && layout.children.length === 1 && layout.children[0].id === 'body') {
    layout = layout.children[0];
  }

  const testElement = findNodeById(layout, 'div#test') || findNodeById(layout, '#test') ||
    findNodeById(layout, 'div#container') || findNodeById(layout, '#container') ||
    findNodeById(layout, 'div#target') || findNodeById(layout, '#target');
  if (testElement) return finalizeRoot(testElement);

  const gridElement = findNodeByClass(layout, 'grid');
  if (gridElement) return finalizeRoot(gridElement);

  const meaningfulChildren = layout.children.filter(
    c =>
      !c.id.startsWith('#text') &&
      c.id !== 'p' &&
      c.id !== 'title' &&
      c.id !== 'head' &&
      c.id !== 'style' &&
      c.id !== 'link' &&
      c.id !== 'meta' &&
      c.id !== 'div#log'
  );
  if (meaningfulChildren.length === 1) return finalizeRoot(meaningfulChildren[0]);

  const divChildren = meaningfulChildren.filter(c => c.id.startsWith('div') && c.id !== 'div#log');
  if (divChildren.length >= 1) return finalizeRoot(divChildren[0]);

  return finalizeRoot(layout);
}

function findNodeById(node: LayoutNode, id: string): LayoutNode | null {
  if (node.id === id || node.id.endsWith('#' + id.replace('#', ''))) return node;
  for (const child of node.children) {
    const found = findNodeById(child, id);
    if (found) return found;
  }
  return null;
}

function findNodeByClass(node: LayoutNode, className: string): LayoutNode | null {
  if (node.id.endsWith('.' + className)) return node;
  for (const child of node.children) {
    const found = findNodeByClass(child, className);
    if (found) return found;
  }
  return null;
}

function normalizeCraterPositions(node: LayoutNode): LayoutNode {
  const contentOffsetX = node.padding.left + node.border.left;
  const contentOffsetY = node.padding.top + node.border.top;

  return {
    ...node,
    children: node.children.map(child => {
      const adjustedChild = {
        ...child,
        x: child.x - contentOffsetX,
        y: child.y - contentOffsetY,
      };
      return normalizeCraterPositions(adjustedChild);
    }),
  };
}

function isIgnorableInlineWrapper(node: LayoutNode): boolean {
  return node.id === 'span' && node.children.length === 0;
}

function compareLayouts(
  browser: LayoutNode,
  crater: LayoutNode,
  path: string = 'root',
  options: { ignoreTextNodes?: boolean; ignoreBoxModel?: boolean } = {},
  browserParentContentPos: { x: number; y: number } = { x: 0, y: 0 },
  craterParentContentPos: { x: number; y: number } = { x: 0, y: 0 }
): Mismatch[] {
  const mismatches: Mismatch[] = [];
  const browserAbsX = browserParentContentPos.x + browser.x;
  const browserAbsY = browserParentContentPos.y + browser.y;
  const craterAbsX = craterParentContentPos.x + crater.x;
  const craterAbsY = craterParentContentPos.y + crater.y;
  const ignoreRootBodyViewportHeight =
    path === 'root' &&
    browser.id === 'body' &&
    crater.id === 'body' &&
    browser.children.length > 0 &&
    crater.children.length > 0 &&
    Math.abs(browser.height - VIEWPORT.height) <= TOLERANCE;
  const bothZeroSized =
    Math.abs(browser.width) < 0.5 &&
    Math.abs(browser.height) < 0.5 &&
    Math.abs(crater.width) < 0.5 &&
    Math.abs(crater.height) < 0.5;

  const props: (keyof LayoutNode)[] = ['x', 'y', 'width', 'height'];
  for (const prop of props) {
    // display:none descendants are zero-sized; browser getBoundingClientRect() can
    // report viewport-origin coordinates for them, so x/y are not comparable.
    if (bothZeroSized && (prop === 'x' || prop === 'y')) {
      continue;
    }
    // Browser body rect can be pinned to viewport height even when content is shorter.
    // Compare descendants instead of treating this as a layout mismatch.
    if (ignoreRootBodyViewportHeight && prop === 'height') {
      continue;
    }
    const bVal = prop === 'x' ? browserAbsX :
      prop === 'y' ? browserAbsY :
      (browser[prop] as number);
    const cVal = prop === 'x' ? craterAbsX :
      prop === 'y' ? craterAbsY :
      (crater[prop] as number);
    const diff = Math.abs(bVal - cVal);
    if (diff > TOLERANCE) {
      mismatches.push({ path, property: prop, browser: bVal, crater: cVal, diff });
    }
  }

  if (!options.ignoreBoxModel) {
    const boxProps: (keyof LayoutNode)[] = ['margin', 'padding', 'border'];
    for (const boxProp of boxProps) {
      const bRect = browser[boxProp] as Rect;
      const cRect = crater[boxProp] as Rect;
      for (const side of ['top', 'right', 'bottom', 'left'] as const) {
        const diff = Math.abs(bRect[side] - cRect[side]);
        if (diff > TOLERANCE) {
          mismatches.push({ path, property: `${boxProp}.${side}`, browser: bRect[side], crater: cRect[side], diff });
        }
      }
    }
  }

  const bChildren = options.ignoreTextNodes ? browser.children.filter(c => !c.id.startsWith('#text')) : browser.children;
  const cChildren = options.ignoreTextNodes ? crater.children.filter(c => !c.id.startsWith('#text')) : crater.children;

  const minChildren = Math.min(bChildren.length, cChildren.length);
  const nextBrowserParentContentPos = {
    x: browserAbsX + browser.border.left + browser.padding.left,
    y: browserAbsY + browser.border.top + browser.padding.top,
  };
  const nextCraterParentContentPos = {
    x: craterAbsX + crater.border.left + crater.padding.left,
    y: craterAbsY + crater.border.top + crater.padding.top,
  };
  for (let i = 0; i < minChildren; i++) {
    const childPath = `${path}/${bChildren[i].id}[${i}]`;
    mismatches.push(
      ...compareLayouts(
        bChildren[i],
        cChildren[i],
        childPath,
        options,
        nextBrowserParentContentPos,
        nextCraterParentContentPos
      )
    );
  }

  if (bChildren.length !== cChildren.length) {
    const parentBoxClose =
      Math.abs(browser.width - crater.width) <= TOLERANCE &&
      Math.abs(browser.height - crater.height) <= TOLERANCE;
    const normalizedBChildren = bChildren.filter(c => !isIgnorableInlineWrapper(c));
    const normalizedCChildren = cChildren.filter(c => !isIgnorableInlineWrapper(c));
    const wrapperOnlyMismatch =
      parentBoxClose &&
      (
        normalizedBChildren.length === normalizedCChildren.length &&
        (normalizedBChildren.length !== bChildren.length || normalizedCChildren.length !== cChildren.length)
      );
    if (wrapperOnlyMismatch) {
      return mismatches;
    }
    mismatches.push({
      path,
      property: 'children.length',
      browser: bChildren.length,
      crater: cChildren.length,
      diff: Math.abs(bChildren.length - cChildren.length),
    });
  }

  return mismatches;
}

function countNodes(node: LayoutNode): number {
  return 1 + node.children.reduce((sum, child) => sum + countNodes(child), 0);
}

function isCrashOnlyTest(htmlPath: string): boolean {
  const name = path.basename(htmlPath).toLowerCase();
  if (name.includes('crash')) return true;

  try {
    const source = fs.readFileSync(htmlPath, 'utf-8').toLowerCase();
    return source.includes('test passes by not crashing') ||
      source.includes('not crash');
  } catch {
    return false;
  }
}

async function runTest(browser: puppeteer.Browser, htmlPath: string): Promise<TestResult> {
  const name = path.basename(htmlPath);

  try {
    if (isCrashOnlyTest(htmlPath)) {
      // Crash-only WPTs assert stability, not geometry parity.
      // We still execute both paths to ensure they don't throw.
      await getBrowserLayout(browser, htmlPath);
      getCraterLayout(htmlPath);
      return { name, passed: true, mismatches: [], totalNodes: 0 };
    }

    const browserLayout = await getBrowserLayout(browser, htmlPath);
    const craterLayout = getCraterLayout(htmlPath);
    const normalizedCraterLayout = normalizeCraterPositions(craterLayout);

    const mismatches = compareLayouts(browserLayout, normalizedCraterLayout, 'root', {
      ignoreTextNodes: true,
      ignoreBoxModel: true,
    });

    return { name, passed: mismatches.length === 0, mismatches, totalNodes: countNodes(browserLayout) };
  } catch (error) {
    return {
      name,
      passed: false,
      mismatches: [{ path: 'error', property: 'execution', browser: 0, crater: 0, diff: 0 }],
      totalNodes: 0,
    };
  }
}

function printResult(result: TestResult): void {
  const icon = result.passed ? '✓' : '✗';
  console.log(`${icon} ${result.name}`);

  if (!result.passed) {
    for (const m of result.mismatches.slice(0, 10)) {
      console.log(`    ${m.path}.${m.property}: browser=${m.browser.toFixed(1)}, crater=${m.crater.toFixed(1)} (diff=${m.diff.toFixed(1)})`);
    }
    if (result.mismatches.length > 10) {
      console.log(`    ... and ${result.mismatches.length - 10} more mismatches`);
    }
  }
}

function launchBrowser(): Promise<puppeteer.Browser> {
  const args = process.env.CI ? CI_PUPPETEER_ARGS : [];
  return puppeteer.launch({ headless: true, args });
}

function parseCliArgs(rawArgs: string[]): CliOptions {
  const options: CliOptions = {
    args: [],
    workers: DEFAULT_CONCURRENCY,
  };

  for (let i = 0; i < rawArgs.length; i++) {
    const arg = rawArgs[i];
    if (arg === '--json') {
      options.jsonOutput = rawArgs[++i];
      continue;
    }
    if (arg.startsWith('--json=')) {
      options.jsonOutput = arg.slice('--json='.length);
      continue;
    }
    if (arg === '--workers') {
      const raw = rawArgs[++i];
      const workers = Number.parseInt(raw ?? '', 10);
      if (!Number.isFinite(workers) || workers <= 0) {
        throw new Error(`Invalid workers value: ${raw}`);
      }
      options.workers = workers;
      continue;
    }
    if (arg.startsWith('--workers=')) {
      const raw = arg.slice('--workers='.length);
      const workers = Number.parseInt(raw, 10);
      if (!Number.isFinite(workers) || workers <= 0) {
        throw new Error(`Invalid workers value: ${raw}`);
      }
      options.workers = workers;
      continue;
    }
    options.args.push(arg);
  }

  return options;
}

function writeShardReport(
  jsonOutput: string | undefined,
  args: string[],
  workers: number,
  passed: number,
  failed: number
): void {
  if (!jsonOutput) return;
  const total = passed + failed;
  const target = args.length === 0 ? 'all' : args.join(' ');

  const report: WptCompatShardReport = {
    schemaVersion: 1,
    suite: 'wpt-css',
    target,
    passed,
    failed,
    errors: 0,
    total,
    passRate: total > 0 ? passed / total : 0,
    generatedAt: new Date().toISOString(),
    workers,
  };

  fs.mkdirSync(path.dirname(jsonOutput), { recursive: true });
  fs.writeFileSync(jsonOutput, JSON.stringify(report, null, 2), 'utf-8');
}

async function runTestsParallel(
  htmlFiles: string[],
  workers: number
): Promise<{ passed: number; failed: number; results: TestResult[] }> {
  const results: TestResult[] = [];
  let passed = 0;
  let failed = 0;
  let nextIndex = 0;

  async function worker(browser: puppeteer.Browser): Promise<void> {
    let localCount = 0;
    const RESTART_INTERVAL = 30;

    while (true) {
      const index = nextIndex++;
      if (index >= htmlFiles.length) break;

      const htmlFile = htmlFiles[index];

      if (localCount > 0 && localCount % RESTART_INTERVAL === 0) {
        try { await browser.close(); } catch {}
        browser = await launchBrowser();
      }

      let result = await runTest(browser, htmlFile);
      if (!result.passed && result.mismatches.some(m => m.property === 'execution')) {
        try { await browser.close(); } catch {}
        browser = await launchBrowser();
        result = await runTest(browser, htmlFile);
      }

      results[index] = result;
      if (result.passed) passed++;
      else failed++;
      localCount++;

      const icon = result.passed ? '✓' : '✗';
      process.stdout.write(`\r[${results.filter(Boolean).length}/${htmlFiles.length}] ${icon} ${result.name.padEnd(50)}`);
    }

    try { await browser.close(); } catch {}
  }

  const browsers = await Promise.all(
    Array.from({ length: workers }, () => launchBrowser())
  );

  await Promise.all(browsers.map(browser => worker(browser)));

  console.log('\n');

  return { passed, failed, results };
}

async function main(): Promise<void> {
  const cliOptions = parseCliArgs(process.argv.slice(2));
  const args = cliOptions.args;

  await initCraterRenderer();

  if (args.length === 0) {
    console.log('WPT Runner for Crater\n');
    console.log('Usage:');
    console.log('  npx tsx scripts/wpt-runner.ts <module-name>     # Run tests for a CSS module');
    console.log('  npx tsx scripts/wpt-runner.ts <path/to/test.html>');
    console.log('  npx tsx scripts/wpt-runner.ts --all             # Run all modules');
    console.log('  npx tsx scripts/wpt-runner.ts --list            # List available modules');
    console.log('  npx tsx scripts/wpt-runner.ts css-flexbox --json .wpt-reports/css-flexbox.json');
    console.log(`  npx tsx scripts/wpt-runner.ts --all --workers ${DEFAULT_CONCURRENCY}`);
    console.log('\nModules:', CSS_MODULES.join(', '));
    return;
  }

  if (args[0] === '--list') {
    console.log('Available CSS modules:\n');
    for (const mod of CSS_MODULES) {
      const files = getTestFiles(mod);
      console.log(`  ${mod}: ${files.length} tests`);
    }
    return;
  }

  // Collect test files
  let htmlFiles: string[] = [];

  if (args[0] === '--all') {
    for (const mod of CSS_MODULES) {
      htmlFiles.push(...getTestFiles(mod));
    }
  } else {
    for (const arg of args) {
      if (CSS_MODULES.includes(arg)) {
        // Module name
        htmlFiles.push(...getTestFiles(arg));
      } else if (arg.includes('*')) {
        // Glob pattern
        const dir = path.dirname(arg);
        if (fs.existsSync(dir)) {
          const files = fs.readdirSync(dir)
            .filter(f => f.endsWith('.html'))
            .map(f => path.join(dir, f));
          htmlFiles.push(...files);
        }
      } else if (fs.existsSync(arg)) {
        // Direct file path
        htmlFiles.push(arg);
      }
    }
  }

  if (htmlFiles.length === 0) {
    console.error('No test files found');
    writeShardReport(cliOptions.jsonOutput, args, cliOptions.workers, 0, 0);
    process.exit(1);
  }

  console.log(`Running ${htmlFiles.length} test(s) with ${cliOptions.workers} workers...\n`);

  let passed = 0;
  let failed = 0;
  let results: TestResult[] = [];
  try {
    const runResult = await runTestsParallel(htmlFiles, cliOptions.workers);
    passed = runResult.passed;
    failed = runResult.failed;
    results = runResult.results;
  } catch (error) {
    console.error(error);
    writeShardReport(cliOptions.jsonOutput, args, cliOptions.workers, 0, 1);
    process.exit(1);
  }

  // Print failed tests details
  const failedResults = results.filter(r => r && !r.passed);
  if (failedResults.length > 0) {
    console.log('Failed tests:\n');
    for (const result of failedResults.slice(0, 20)) {
      printResult(result);
    }
    if (failedResults.length > 20) {
      console.log(`... and ${failedResults.length - 20} more failed tests\n`);
    }
  }

  writeShardReport(cliOptions.jsonOutput, args, cliOptions.workers, passed, failed);
  console.log(`Summary: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
