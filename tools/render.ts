#!/usr/bin/env node --experimental-strip-types
/**
 * Render all SVG examples with HTML comparison
 *
 * Usage:
 *   npm run render
 */

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

const OUTPUT_DIR = 'render-results';

// HTML templates for each example (matching the MoonBit examples)
const HTML_TEMPLATES: Record<string, string> = {
  '01_basic': `
    <div id="root" style="width: 200px; box-sizing: border-box;">
      <div style="height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="height: 60px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '02_nested': `
    <div id="root" style="width: 200px; padding: 15px; box-sizing: border-box;">
      <div style="padding: 10px; background: rgba(52, 168, 83, 0.3);">
        <div style="height: 30px; background: rgba(251, 188, 4, 0.3);"></div>
      </div>
    </div>`,

  '03_padding': `
    <div id="root" style="width: 200px; padding: 10px 30px 40px 20px; box-sizing: border-box;">
      <div style="height: 50px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '04_border': `
    <div id="root" style="width: 200px; height: 100px; border-width: 10px 5px 10px 5px; border-style: solid; border-color: #999; box-sizing: border-box;">
      <div style="height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '05_margin': `
    <div id="root" style="width: 200px; box-sizing: border-box;">
      <div style="height: 30px; margin: 10px 20px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="height: 30px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '06_margin_collapse': `
    <div id="root" style="width: 200px; box-sizing: border-box;">
      <div style="height: 30px; margin-bottom: 30px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="height: 30px; margin-top: 20px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="height: 30px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '07_percentage_width': `
    <div id="root" style="width: 300px; box-sizing: border-box;">
      <div style="width: 50%; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 75%; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 100%; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '08_percentage_height': `
    <div id="root" style="width: 200px; height: 200px; box-sizing: border-box;">
      <div style="height: 25%; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="height: 50%; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '09_min_max': `
    <div id="root" style="width: 300px; box-sizing: border-box;">
      <div style="width: 50px; min-width: 100px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="max-width: 150px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="height: 60px; max-height: 30px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '11_flex_row': `
    <div id="root" style="display: flex; flex-direction: row; width: 300px; height: 80px; box-sizing: border-box;">
      <div style="width: 60px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 80px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 60px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '12_flex_column': `
    <div id="root" style="display: flex; flex-direction: column; width: 150px; box-sizing: border-box;">
      <div style="width: 100px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 100px; height: 60px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 100px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '13_flex_grow': `
    <div id="root" style="display: flex; flex-direction: row; width: 400px; height: 80px; box-sizing: border-box;">
      <div style="flex-grow: 1; height: 50px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="flex-grow: 2; height: 50px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="flex-grow: 1; height: 50px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '14_flex_justify': `
    <div id="root" style="display: flex; flex-direction: row; justify-content: space-between; width: 300px; height: 80px; box-sizing: border-box;">
      <div style="width: 50px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 50px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 50px; height: 40px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '15_flex_align': `
    <div id="root" style="display: flex; flex-direction: row; align-items: center; width: 250px; height: 120px; box-sizing: border-box;">
      <div style="width: 60px; height: 30px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 60px; height: 60px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="width: 60px; height: 90px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,

  '16_flex_sidebar': `
    <div id="root" style="display: flex; flex-direction: row; width: 350px; height: 220px; padding: 10px; box-sizing: border-box;">
      <div style="width: 80px; height: 200px; background: rgba(52, 168, 83, 0.3);"></div>
      <div style="flex-grow: 1; height: 200px; background: rgba(52, 168, 83, 0.3);"></div>
    </div>`,
};

function main() {
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  console.log('Running moon run cmd/render...');

  const output = execSync('moon run cmd/render', {
    encoding: 'utf-8',
    cwd: process.cwd(),
  });

  // Split by file markers
  const filePattern = /===FILE:(.+?)===\n/g;
  const parts = output.split(filePattern);

  let savedCount = 0;
  const files: string[] = [];

  for (let i = 1; i < parts.length; i += 2) {
    const filename = parts[i];
    const content = parts[i + 1]?.trim();

    if (filename && content) {
      const filepath = path.join(OUTPUT_DIR, filename);
      fs.writeFileSync(filepath, content + '\n');
      console.log(`  Saved: ${filepath}`);
      savedCount++;
      files.push(filename.replace('.svg', ''));
    }
  }

  console.log(`\nGenerated ${savedCount} SVG files in ${OUTPUT_DIR}/`);

  generateIndex(files);
}

function generateIndex(files: string[]) {
  const cards = files.map(name => {
    const htmlTemplate = HTML_TEMPLATES[name] || '<div style="color: #999;">No HTML template</div>';

    return `
    <div class="card">
      <h3>${name}</h3>
      <div class="comparison">
        <div class="pane">
          <div class="label">Crater (SVG)</div>
          <div class="render crater">
            <object data="${name}.svg" type="image/svg+xml"></object>
          </div>
        </div>
        <div class="pane">
          <div class="label">Browser (HTML/CSS)</div>
          <div class="render browser">
            ${htmlTemplate}
          </div>
        </div>
      </div>
    </div>`;
  }).join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Crater Layout Comparison</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: system-ui, sans-serif;
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
      background: #f5f5f5;
    }
    h1 { color: #333; margin-bottom: 8px; }
    .subtitle { color: #666; margin-bottom: 20px; }
    .card {
      background: white;
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .card h3 {
      margin: 0 0 12px 0;
      color: #333;
      font-size: 16px;
    }
    .comparison {
      display: flex;
      gap: 24px;
    }
    .pane {
      flex: 1;
    }
    .label {
      font-size: 12px;
      color: #666;
      margin-bottom: 8px;
      font-weight: 500;
    }
    .render {
      border: 1px solid #ddd;
      background: #fff;
      min-height: 100px;
      position: relative;
      padding: 0;
    }
    .render object {
      display: block;
    }
    .crater { background: #fff; }
    .browser { background: #fff; }
    .browser > div {
      background: rgba(66, 133, 244, 0.3);
    }
    .browser > div > div {
      background: rgba(52, 168, 83, 0.3);
      border: 1px solid #333;
    }
  </style>
</head>
<body>
  <h1>Crater Layout Comparison</h1>
  <p class="subtitle">Left: crater layout engine (SVG) / Right: browser rendering (HTML/CSS)</p>

${cards}

</body>
</html>`;

  const indexPath = path.join(OUTPUT_DIR, 'index.html');
  fs.writeFileSync(indexPath, html);
  console.log(`Generated: ${indexPath}`);
}

main();
