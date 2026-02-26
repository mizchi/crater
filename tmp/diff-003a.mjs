import fs from 'fs';
import path from 'path';
import puppeteer from 'puppeteer';
import { pathToFileURL } from 'url';

const runtimePath = path.join(process.cwd(), '_build/js/release/build/wpt_runtime/wpt_runtime.js');
const mod = await import(pathToFileURL(runtimePath).href);
const render = mod.renderHtmlToJsonForWpt;

const htmlPath = 'wpt/css/css-contain/contain-size-replaced-003a.html';
let html = fs.readFileSync(htmlPath, 'utf-8');
const CSS_RESET = `\n<style>\n  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }\n  p { margin: 0; }\n</style>\n`;
if (/<head\b[^>]*>/i.test(html)) html = html.replace(/<head\b[^>]*>/i, m => m + CSS_RESET);
else if (/<body\b[^>]*>/i.test(html)) html = html.replace(/<body\b[^>]*>/i, m => CSS_RESET + m);
else html = CSS_RESET + html;

const craterLayout = JSON.parse(render(html, 800, 600));

const browser = await puppeteer.launch({headless:true});
const page = await browser.newPage();
await page.setViewport({width:800,height:600});
await page.setContent(html, {waitUntil:'domcontentloaded'});
const browserLayout = await page.evaluate(`(() => {
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
      id: getNodeId(el), x, y, width: rect.width, height: rect.height,
      children,
    };
  }
  const body = document.body;
  return extractLayout(body);
})()`);
await browser.close();

function list(node) {
  return node.children.map((c, i) => ({i, id:c.id, x:c.x, y:c.y, w:c.width, h:c.height}));
}

console.log('BROWSER');
for (const e of list(browserLayout)) console.log(e);
console.log('CRATER');
for (const e of list(craterLayout)) console.log(e);
