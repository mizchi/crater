# Crater JavaScript API

MoonBit compiled layout engine for browser use.

## API Functions

### `renderHtml(html: string, width: number, height: number): string`
Render HTML to text layout tree representation.

### `renderHtmlToJson(html: string, width: number, height: number): string`
Render HTML to JSON layout tree.

### `renderHtmlToPaintTree(html: string, width: number, height: number): string`
Render HTML to paint tree JSON with colors and visual properties.

## Build

```bash
# Build MoonBit to JS
moon build --target js

# Output: target/js/release/build/js/js.js
```

## Usage in Browser (with bundler)

```javascript
import { renderHtml, renderHtmlToJson, renderHtmlToPaintTree } from './target/js/release/build/js/js.js';

const html = '<div style="width: 200px; display: flex">...</div>';
const layoutJson = renderHtmlToJson(html, 800, 600);
const layout = JSON.parse(layoutJson);
```

## Playground

Interactive preview with canvas rendering:

```bash
cd js/playground
npm install
npm run dev
```

Open http://localhost:5173/ to see the layout preview.

## File Structure

```
js/
├── js.mbt              # MoonBit JS API implementation
├── moon.pkg.json       # Package config with JS exports
├── README.md
└── playground/
    ├── package.json    # Vite project
    ├── vite.config.js  # Vite config with alias
    ├── index.html      # Preview page
    └── main.js         # Canvas rendering logic
```
