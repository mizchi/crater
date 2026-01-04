#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const crater = await import(resolve(__dirname, '../../target/js/release/build/js/js.js'));

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 600;

function printUsage() {
  console.log(`crater - HTML/CSS Layout Renderer

Usage:
  crater <file.html>
  crater --json <file.html>
  crater --width 800 --height 600 <file.html>
  crater                          (example)

Options:
  -w, --width <px>   Viewport width (default: 800)
  -H, --height <px>  Viewport height (default: 600)
  -s, --styles       Use actual CSS colors
  --json             Output layout as JSON
  --paint            Output paint tree as JSON
  --sixel            Output Sixel graphics (default)
  -h, --help         Show this help message

Output Formats:
  --sixel (default)  Sixel graphics for terminal
  --json             Layout tree as JSON
  --paint            Paint tree with colors as JSON
`);
}

function getExampleHtml() {
  return `<div style="width: 400px; height: 300px; padding: 10px; background-color: #f0f0f0">
  <header style="height: 40px; margin-bottom: 10px; background-color: #3498db; color: white">
    Header
  </header>
  <div style="display: flex">
    <aside style="width: 80px; height: 200px; background-color: #2ecc71; color: white">
      Sidebar
    </aside>
    <main style="flex-grow: 1; height: 200px; padding: 5px; background-color: #ecf0f1">
      <div style="width: 100px; height: 60px; background-color: #e74c3c; color: white">Box 1</div>
      <div style="width: 100px; height: 60px; background-color: #9b59b6; color: white">Box 2</div>
    </main>
  </div>
</div>`;
}

function parseArgs(args) {
  const options = {
    input: null,
    width: DEFAULT_WIDTH,
    height: DEFAULT_HEIGHT,
    json: false,
    paint: false,
    sixel: false,
    styles: false,
    help: false,
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];

    if (arg === '-h' || arg === '--help') {
      options.help = true;
    } else if (arg === '--json') {
      options.json = true;
    } else if (arg === '--paint') {
      options.paint = true;
    } else if (arg === '--sixel') {
      options.sixel = true;
    } else if (arg === '-s' || arg === '--styles') {
      options.styles = true;
    } else if (arg === '-w' || arg === '--width') {
      options.width = parseInt(args[++i], 10) || DEFAULT_WIDTH;
    } else if (arg === '-H' || arg === '--height') {
      options.height = parseInt(args[++i], 10) || DEFAULT_HEIGHT;
    } else if (arg.startsWith('--width=')) {
      options.width = parseInt(arg.slice(8), 10) || DEFAULT_WIDTH;
    } else if (arg.startsWith('--height=')) {
      options.height = parseInt(arg.slice(9), 10) || DEFAULT_HEIGHT;
    } else if (!arg.startsWith('-') && !options.input) {
      options.input = arg;
    }
    i++;
  }

  return options;
}

function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  if (options.help) {
    printUsage();
    process.exit(0);
  }

  let html;
  if (options.input) {
    try {
      const filePath = resolve(process.cwd(), options.input);
      html = readFileSync(filePath, 'utf-8');
    } catch (e) {
      console.error(`Error: Cannot read file: ${options.input}`);
      console.error(`  ${e.message}`);
      process.exit(1);
    }
  } else {
    html = getExampleHtml();
  }

  const { width, height } = options;

  if (options.json) {
    console.log(crater.renderHtmlToJson(html, width, height));
  } else if (options.paint) {
    console.log(crater.renderHtmlToPaintTree(html, width, height));
  } else {
    // Default: Sixel output
    if (options.styles) {
      console.log(crater.renderHtmlToSixelWithStyles(html, width, height));
    } else {
      console.log(crater.renderHtmlToSixel(html, width, height));
    }
  }
}

main();
