import fs from 'fs';
import puppeteer from 'puppeteer';

const VIEWPORT = { width: 800, height: 600 };

function prepareHtmlContent(htmlPath: string): string {
  let htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  htmlContent = htmlContent.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
  const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
  p { margin: 0; }
</style>
`;
  return CSS_RESET + htmlContent;
}

async function main() {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);
  const html = prepareHtmlContent('wpt/css/css-overflow/scroll-buttons-disabled-snapping.html');
  await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 5000 });

  const out = await page.evaluate(`(() => {
    function rect(style, prop) {
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

    const root = document.querySelector('.horizontal');
    const c0 = root.children[0];
    const c1 = root.children[1];
    const rr = root.getBoundingClientRect();
    const s = getComputedStyle(root);
    const p = rect(s, 'padding');
    const b = rect(s, 'border');
    const m = rect(s, 'margin');

    function childDump(el) {
      const er = el.getBoundingClientRect();
      const es = getComputedStyle(el);
      return {
        x_relative_content: er.left - rr.left - b.left - p.left,
        y_relative_content: er.top - rr.top - b.top - p.top,
        width: er.width,
        height: er.height,
        margin: rect(es, 'margin'),
        padding: rect(es, 'padding'),
        border: rect(es, 'border'),
      };
    }

    return {
      root: {
        x: rr.left,
        y: rr.top,
        width: rr.width,
        height: rr.height,
        margin: m,
        padding: p,
        border: b,
      },
      child0: childDump(c0),
      child1: childDump(c1),
      scrollLeft: root.scrollLeft,
      scrollTop: root.scrollTop,
    };
  })()`);

  console.log(JSON.stringify(out, null, 2));
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
