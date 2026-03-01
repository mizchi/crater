import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'url';
import puppeteer from 'puppeteer';

type Rect = { top: number; right: number; bottom: number; left: number };
type LayoutNode = {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  margin: Rect;
  padding: Rect;
  border: Rect;
  children: LayoutNode[];
};

const VIEWPORT = { width: 800, height: 600 };
const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
  p { margin: 0; }
</style>
`;

function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  htmlContent = htmlContent.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
  const headOpenTag = /<head\b[^>]*>/i;
  const bodyOpenTag = /<body\b[^>]*>/i;
  if (headOpenTag.test(htmlContent)) {
    htmlContent = htmlContent.replace(headOpenTag, m => m + CSS_RESET);
  } else if (bodyOpenTag.test(htmlContent)) {
    htmlContent = htmlContent.replace(bodyOpenTag, m => CSS_RESET + m);
  } else {
    htmlContent = CSS_RESET + htmlContent;
  }
  return htmlContent;
}

function normalizeZeroSizedRootChildren(node: LayoutNode): LayoutNode {
  const isZeroSizedRoot = Math.abs(node.width) <= 0.5 && Math.abs(node.height) <= 0.5;
  if (!isZeroSizedRoot || node.children.length === 0) return node;
  const meaningfulChildren = node.children.filter(c => !c.id.startsWith('#text'));
  if (meaningfulChildren.length === 0) return node;
  let minX = Number.POSITIVE_INFINITY;
  let minY = Number.POSITIVE_INFINITY;
  for (const child of meaningfulChildren) {
    if (child.x < minX) minX = child.x;
    if (child.y < minY) minY = child.y;
  }
  if (!Number.isFinite(minX) || !Number.isFinite(minY)) return node;
  if (Math.abs(minX) <= 0.5 && Math.abs(minY) <= 0.5) return node;
  return {
    ...node,
    children: node.children.map(child => ({ ...child, x: child.x - minX, y: child.y - minY })),
  };
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

function pickRoot(layout: LayoutNode): LayoutNode {
  function normalizeRoot(node: LayoutNode): LayoutNode {
    return { ...node, x: 0, y: 0 };
  }
  function finalizeRoot(node: LayoutNode): LayoutNode {
    return normalizeZeroSizedRootChildren(normalizeRoot(node));
  }

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
    c => !c.id.startsWith('#text') && c.id !== 'p' && c.id !== 'title' && c.id !== 'head' && c.id !== 'style' && c.id !== 'link' && c.id !== 'meta' && c.id !== 'div#log'
  );
  if (meaningfulChildren.length === 1) return finalizeRoot(meaningfulChildren[0]);

  const divChildren = meaningfulChildren.filter(c => c.id.startsWith('div') && c.id !== 'div#log');
  if (divChildren.length >= 1) return finalizeRoot(divChildren[0]);

  return finalizeRoot(layout);
}

function printTree(node: LayoutNode, depth = 0) {
  if (depth > 4) return;
  const pad = '  '.repeat(depth);
  console.log(`${pad}${node.id} x=${node.x.toFixed(1)} y=${node.y.toFixed(1)} w=${node.width.toFixed(1)} h=${node.height.toFixed(1)}`);
  for (const c of node.children) printTree(c, depth + 1);
}

async function getBrowserLayout(htmlPath: string): Promise<LayoutNode> {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);
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
      return { id: getNodeId(el), x, y, width: rect.width, height: rect.height, margin: getComputedRect(el, 'margin'), padding, border, children, top: 0, right: 0, bottom: 0, left: 0 };
    }

    const body = document.body;
    return extractLayout(body);
  })()`);
  await browser.close();
  return pickRoot(layout as LayoutNode);
}

async function getCraterLayout(htmlPath: string): Promise<LayoutNode> {
  const mod = await import(pathToFileURL(path.join(process.cwd(), '_build/js/release/build/wpt_runtime/wpt_runtime.js')).href);
  const htmlContent = prepareHtmlContent(htmlPath);
  const result = mod.renderHtmlToJsonForWpt(htmlContent, 800, 600);
  const layout = JSON.parse(result) as LayoutNode;
  return pickRoot(layout);
}

(async () => {
  const htmlPath = process.argv[2] || 'wpt/css/css-overflow/scroll-buttons-disabled-snapping.html';
  const browser = await getBrowserLayout(htmlPath);
  const crater = await getCraterLayout(htmlPath);
  console.log('=== browser ===');
  printTree(browser);
  console.log('=== crater ===');
  printTree(crater);
})();
