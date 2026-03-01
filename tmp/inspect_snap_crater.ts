import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'url';

async function main() {
  const htmlPath = 'wpt/css/css-overflow/scroll-buttons-disabled-snapping.html';
  let html = fs.readFileSync(htmlPath, 'utf-8');
  html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
  const CSS_RESET = `
<style>
  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
  p { margin: 0; }
</style>
`;
  html = CSS_RESET + html;

  const mod = await import(
    pathToFileURL(path.join(process.cwd(), '_build/js/release/build/wpt_runtime/wpt_runtime.js')).href,
  );
  const tree = JSON.parse(mod.renderHtmlToJsonForWpt(html, 800, 600));
  const root = tree.children.find((c: any) => c.id.startsWith('div.horizontal'));
  console.log(JSON.stringify({
    root: {
      id: root.id,
      x: root.x,
      y: root.y,
      width: root.width,
      height: root.height,
      padding: root.padding,
      border: root.border,
      margin: root.margin,
    },
    child0: root.children[0],
    child1: root.children[1],
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
