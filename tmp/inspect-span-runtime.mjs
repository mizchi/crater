import path from 'path';
import { pathToFileURL } from 'url';
const mod = await import(pathToFileURL(path.join(process.cwd(),'_build/js/release/build/wpt_runtime/wpt_runtime.js')).href);
const html = `<!DOCTYPE html>
<style>
body { margin: 0; }
div { overflow: hidden; }
span { contain: size; }
</style>
<div><span>PASS</span></div>`;
const layout = JSON.parse(mod.renderHtmlToJsonForWpt(html,800,600));
function dump(n,d=0){console.log(`${'  '.repeat(d)}${n.id} w=${n.width} h=${n.height} c=${n.children.length}`);for(const c of n.children)dump(c,d+1)}
dump(layout);
