/**
 * WPT HTML preprocessing utilities
 *
 * Shared between wpt-runner.ts (layout comparison) and VRT tests (visual comparison).
 * This module is intentionally lightweight — no heavy dependencies like puppeteer.
 */

import fs from 'fs';
import path from 'path';
import { loadWptConfig } from './wpt-config.ts';

const wptConfig = loadWptConfig();
const INCLUDE_PREFIXES: string[] = wptConfig.includePrefixes;
const MODULE_PREFIXES: Record<string, string[]> = wptConfig.modulePrefixes ?? {};
const RECURSIVE_MODULES: string[] = wptConfig.recursiveModules ?? [];

const WPT_DIR = 'wpt/css';
const WPT_ROOT = path.join(process.cwd(), 'wpt');

const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
  p { margin: 0; }
</style>
`;

export function isLayoutTest(filename: string, prefixes: string[] = INCLUDE_PREFIXES): boolean {
  if (!filename.endsWith('.html')) return false;
  if (filename.endsWith('-ref.html')) return false;
  if (filename.includes('support')) return false;
  if (filename.startsWith('reference')) return false;
  return prefixes.some(prefix => filename.startsWith(prefix));
}

export function isScriptHarnessTest(htmlPath: string): boolean {
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

export function getTestFiles(moduleName: string): string[] {
  const moduleDir = path.join(WPT_DIR, moduleName);
  if (!fs.existsSync(moduleDir)) {
    return [];
  }
  const includePrefixes = MODULE_PREFIXES[moduleName] ?? INCLUDE_PREFIXES;
  const recursive = RECURSIVE_MODULES.includes(moduleName);
  if (recursive) {
    return collectHtmlFilesRecursive(moduleDir)
      .filter(fullPath => isLayoutTest(path.basename(fullPath), includePrefixes))
      .filter(fullPath => !isScriptHarnessTest(fullPath))
      .map(fullPath => path.relative(process.cwd(), fullPath));
  }
  return fs.readdirSync(moduleDir)
    .filter(filename => isLayoutTest(filename, includePrefixes))
    .map(f => path.join(moduleDir, f))
    .filter(fullPath => !isScriptHarnessTest(fullPath));
}

// --- CSS inlining ---

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

function inlineCssImports(
  cssContent: string,
  basePath: string,
  seenPaths: Set<string>,
): string {
  const baseDir = path.dirname(basePath);
  const importRegex =
    /@import\s+(?:url\(\s*(?:"([^"]+)"|'([^']+)'|([^'")\s]+))\s*\)|"([^"]+)"|'([^']+)')\s*;/gi;
  return cssContent.replace(importRegex, (match, g1, g2, g3, g4, g5) => {
    const importRef = (g1 || g2 || g3 || g4 || g5 || '').trim();
    if (!importRef || isExternalResourceUrl(importRef)) return match;

    const importPath = resolveLocalResourcePath(baseDir, importRef);
    if (!importPath || !fs.existsSync(importPath)) return match;
    const normalizedImportPath = path.resolve(importPath);
    if (seenPaths.has(normalizedImportPath)) {
      return match;
    }

    try {
      const importedCss = fs.readFileSync(importPath, 'utf-8');
      return `/* Inlined import from ${importRef} */\n${inlineCssDependencies(
        importedCss,
        importPath,
        new Set([...seenPaths, normalizedImportPath]),
      )}`;
    } catch {
      return match;
    }
  });
}

function inlineCssDependencies(
  cssContent: string,
  basePath: string,
  seenPaths: Set<string> = new Set([path.resolve(basePath)]),
): string {
  const baseDir = path.dirname(basePath);
  const cssUrlRegex = /url\(\s*(?:"([^"]+)"|'([^']+)'|([^'")\s]+))\s*\)/gi;
  const cssWithImportsInlined = inlineCssImports(cssContent, basePath, seenPaths);
  return cssWithImportsInlined.replace(cssUrlRegex, (match, g1, g2, g3) => {
    const assetRef = (g1 || g2 || g3 || '').trim();
    if (!assetRef || isExternalResourceUrl(assetRef)) return match;

    const assetPath = resolveLocalResourcePath(baseDir, assetRef);
    if (!assetPath || !fs.existsSync(assetPath)) return match;

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
        const inlinedCss = inlineCssDependencies(cssContent, cssPath);
        return `<style>/* Inlined from ${href} */\n${inlinedCss}</style>`;
      }
    } catch {}
    return `<!-- CSS not found: ${href} -->`;
  });
}

function inlineStyleTagCss(html: string, htmlPath: string): string {
  const styleRegex = /<style(\b[^>]*)>([\s\S]*?)<\/style>/gi;
  return html.replace(styleRegex, (_match, attrs, cssContent) => (
    `<style${attrs}>${inlineCssDependencies(cssContent, htmlPath)}</style>`
  ));
}

// --- Script-driven class mutations ---

interface ClassListMutation {
  targetId: string;
  action: 'add' | 'remove';
  className: string;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function applyClassListMutationToTag(
  tagHtml: string,
  action: 'add' | 'remove',
  className: string,
): string {
  const classAttrRegex = /\bclass\s*=\s*(["'])(.*?)\1/i;
  const classAttrMatch = tagHtml.match(classAttrRegex);
  if (!classAttrMatch) {
    if (action === 'remove') return tagHtml;
    return tagHtml.replace(/>$/, ` class="${className}">`);
  }

  const quote = classAttrMatch[1];
  const currentRaw = classAttrMatch[2];
  const classes = currentRaw.split(/\s+/).filter(Boolean);
  const nextSet = new Set(classes);
  if (action === 'add') {
    nextSet.add(className);
  } else {
    nextSet.delete(className);
  }
  const nextClasses = [...nextSet];
  if (nextClasses.length === 0) {
    return tagHtml
      .replace(classAttrRegex, '')
      .replace(/\s+>/g, '>');
  }
  return tagHtml.replace(
    classAttrRegex,
    `class=${quote}${nextClasses.join(' ')}${quote}`,
  );
}

function applyClassListMutationById(
  html: string,
  mutation: ClassListMutation,
): string {
  const idPattern = escapeRegExp(mutation.targetId);
  const openTagRegex = new RegExp(
    `<[^>]*\\bid\\s*=\\s*["']${idPattern}["'][^>]*>`,
    'i',
  );
  return html.replace(openTagRegex, (tagHtml) => (
    applyClassListMutationToTag(tagHtml, mutation.action, mutation.className)
  ));
}

function collectScriptDrivenClassListMutations(scriptContent: string): ClassListMutation[] {
  const mutations: ClassListMutation[] = [];
  const byElementIdRegex =
    /document\.getElementById\(\s*["']([^"']+)["']\s*\)\.classList\.(add|remove)\(\s*["']([^"']+)["']\s*\)/g;
  const byGlobalIdRegex =
    /\b([A-Za-z_$][\w$]*)\.classList\.(add|remove)\(\s*["']([^"']+)["']\s*\)/g;

  let match: RegExpExecArray | null;
  while ((match = byElementIdRegex.exec(scriptContent)) !== null) {
    const [, targetId, action, className] = match;
    mutations.push({
      targetId,
      action: action as 'add' | 'remove',
      className,
    });
  }
  while ((match = byGlobalIdRegex.exec(scriptContent)) !== null) {
    const [, targetId, action, className] = match;
    if (targetId === 'document' || targetId === 'window') continue;
    mutations.push({
      targetId,
      action: action as 'add' | 'remove',
      className,
    });
  }
  return mutations;
}

export function applySimpleScriptDrivenClassMutations(html: string): string {
  const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let transformed = html;
  let match: RegExpExecArray | null;

  while ((match = scriptRegex.exec(html)) !== null) {
    const scriptContent = match[1];
    if (
      !scriptContent.includes('takeScreenshot') &&
      !scriptContent.includes('waitForAtLeastOneFrame')
    ) {
      continue;
    }
    const mutations = collectScriptDrivenClassListMutations(scriptContent);
    for (const mutation of mutations) {
      transformed = applyClassListMutationById(transformed, mutation);
    }
  }
  return transformed;
}

function injectMarkupIntoBody(html: string, markup: string): string {
  if (markup.length === 0) return html;
  if (/<\/body>/i.test(html)) {
    return html.replace(/<\/body>/i, `${markup}</body>`);
  }
  return `${html}${markup}`;
}

export function applyKnownScriptDrivenFixtureTransforms(
  html: string,
  htmlPath: string,
): string {
  const filename = path.basename(htmlPath).toLowerCase();
  if (filename === 'logical-values-float-clear-reftest.html') {
    const sides = ['inline-start', 'inline-end'];
    const directions = ['ltr', 'rtl'];
    const chunks: string[] = [];
    for (const floatSide of sides) {
      for (const clearSide of sides) {
        for (const containerDirection of directions) {
          for (const inlineParentDirection of [null, ...directions]) {
            for (const floatDirection of directions) {
              for (const clearDirection of directions) {
                const floatMarkup =
                  `<div class="float" style="direction:${floatDirection};float:${floatSide};"></div>`;
                const clearMarkup =
                  `<div class="clear" style="direction:${clearDirection};clear:${clearSide};"></div>`;
                const inner = inlineParentDirection
                  ? `<div class="inline" style="direction:${inlineParentDirection};">${floatMarkup}${clearMarkup}</div>`
                  : `${floatMarkup}${clearMarkup}`;
                chunks.push(
                  `<div class="test" style="direction:${containerDirection};">${inner}</div>`,
                );
              }
            }
          }
        }
      }
    }
    return injectMarkupIntoBody(html, chunks.join(''));
  }
  if (filename === 'content-none-select-1.html') {
    const display = [
      'display:block',
      'display:inline',
      'display:ruby',
      'display:none',
      'display:grid',
      'display:flex',
      'display:table',
      'display:list-item',
      'display:contents',
      'columns:2',
    ];
    const overflow = ['', 'overflow:scroll', 'overflow:clip'];
    const position = ['', 'position:absolute'];
    const classes = ['', 'after', 'before'];
    const chunks: string[] = [];
    for (const d of display) {
      for (const o of overflow) {
        for (const p of position) {
          for (const c of classes) {
            const classAttr = c ? ` class="${c}"` : '';
            const styleAttr = [d, o, p].filter(Boolean).join(';');
            chunks.push(
              `<div class="wrapper"><select${classAttr} style="${styleAttr}"><option>X</option></select></div>`,
            );
          }
        }
      }
    }
    return injectMarkupIntoBody(html, chunks.join(''));
  }
  return html;
}

// --- Main HTML preparation ---

function removeReftestWaitClass(html: string): string {
  // Remove "reftest-wait" from any element's class attribute
  // This class is used by WPT to delay screenshot until JS runs,
  // but since we strip scripts, we need to remove it to show final state
  return html.replace(
    /\bclass\s*=\s*"([^"]*\breftest-wait\b[^"]*)"/gi,
    (_match, classes) => {
      const cleaned = classes
        .split(/\s+/)
        .filter((c: string) => c !== 'reftest-wait')
        .join(' ')
        .trim();
      return cleaned ? `class="${cleaned}"` : '';
    },
  );
}

export function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  htmlContent = inlineExternalCSS(htmlContent, htmlPath);
  htmlContent = inlineStyleTagCss(htmlContent, htmlPath);
  htmlContent = applySimpleScriptDrivenClassMutations(htmlContent);
  htmlContent = applyKnownScriptDrivenFixtureTransforms(htmlContent, htmlPath);
  htmlContent = removeReftestWaitClass(htmlContent);
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
