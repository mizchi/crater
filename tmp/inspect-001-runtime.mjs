import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'url';
const runtimePath = path.join(process.cwd(), '_build/js/release/build/wpt_runtime/wpt_runtime.js');
const mod = await import(pathToFileURL(runtimePath).href);
const render = mod.renderHtmlToJsonForWpt;
let html = fs.readFileSync('wpt/css/css-contain/contain-size-001.html','utf8');
const CSS_RESET = `\n<style>\n  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }\n  p { margin: 0; }\n</style>\n`;
if (/<head\b[^>]*>/i.test(html)) html = html.replace(/<head\b[^>]*>/i, m => m + CSS_RESET);
else if (/<body\b[^>]*>/i.test(html)) html = html.replace(/<body\b[^>]*>/i, m => CSS_RESET + m);
else html = CSS_RESET + html;
const layout = JSON.parse(render(html,800,600));
function dump(n,d=0){console.log(`${'  '.repeat(d)}${n.id} w=${n.width} h=${n.height} c=${n.children.length}`);for(const c of n.children)dump(c,d+1)}
dump(layout);
