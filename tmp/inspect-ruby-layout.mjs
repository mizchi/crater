import path from 'path';
import { pathToFileURL } from 'url';
const mod = await import(pathToFileURL(path.join(process.cwd(),'wasm/dist/crater.js')).href);
const html = `<!DOCTYPE html>
<style>
body { margin: 0; }
div { overflow: hidden; position: absolute; }
rb { contain: size; display: ruby-base; }
</style>
<div><ruby><rb>PASS</rb></ruby></div>`;
const json = mod.renderer.renderHtmlToJson(html, 800, 600);
const layout = JSON.parse(json);
function dump(n,d=0){
  console.log(`${'  '.repeat(d)}${n.id} x=${n.x} y=${n.y} w=${n.width} h=${n.height} c=${n.children?.length??0}`);
  for(const c of n.children??[]) dump(c,d+1);
}
dump(layout);
