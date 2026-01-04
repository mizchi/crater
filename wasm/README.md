# Crater WASM Component

This directory contains the WASM component build of Crater for distribution via [wa.dev](https://wa.dev).

## Installation via wa.dev

### For MoonBit projects

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "mizchi/crater": "*"
  }
}
```

Then run:

```bash
moon update
```

### For JavaScript/TypeScript projects

Install the component and jco:

```bash
npm install @aspect-build/jco
```

Download and transpile:

```bash
# Download from wa.dev
curl -O https://wa.dev/mizchi/crater/crater.wasm

# Transpile to JavaScript
npx jco transpile crater.wasm -o ./crater --name crater
```

## Usage

### JavaScript/TypeScript

```javascript
import { renderer, incremental, yoga } from './crater/crater.js';

// Render HTML to layout JSON
const html = '<div style="width: 100px; display: flex;"><div style="flex: 1;"></div></div>';
const layoutJson = renderer.renderHtmlToJson(html, 800, 600);
const layout = JSON.parse(layoutJson);
console.log(layout);
// { id: 'body', x: 0, y: 0, width: 800, height: 0, children: [...] }

// Incremental layout with caching
incremental.createTree(html, 800, 600);
const result = incremental.computeIncremental();
console.log(JSON.parse(result));

// Update style and recompute
incremental.updateStyle('div#root', 'width: 200px;');
incremental.markDirty('div#root');
const updated = incremental.computeIncremental();

// Check cache statistics
const stats = JSON.parse(incremental.getCacheStats());
console.log(`Cache hit rate: ${stats.hitRate * 100}%`);

incremental.destroyTree();
```

### Yoga-compatible API

```javascript
import { yoga, incremental } from './crater/crater.js';

// Create layout tree first
incremental.createTree('<div id="root"></div>', 800, 600);

// Programmatic layout using Yoga-style API
yoga.setWidth('div#root', 400);
yoga.setHeight('div#root', 300);
yoga.setFlexDirection('div#root', 'column');
yoga.setJustifyContent('div#root', 'center');
yoga.setAlignItems('div#root', 'center');

// Calculate and get layout
const layoutJson = yoga.calculateLayout(800, 600);
const layout = JSON.parse(layoutJson);

// Get computed values
const width = yoga.getComputedWidth('div#root');
const height = yoga.getComputedHeight('div#root');
console.log(`Computed size: ${width}x${height}`);

incremental.destroyTree();
```

## Build from Source

```bash
npm run build:wasm-component
```

This generates:
- `wasm/target/crater.wasm` - The final WASM component

To generate JavaScript bindings:

```bash
npm run jco:transpile
```

## WIT Interface

The component exports three interfaces:

### `mizchi:crater/renderer@0.1.0`
- `render-html(html, width, height) -> string` - Render HTML to text layout tree
- `render-html-to-json(html, width, height) -> string` - Render HTML to JSON
- `render-html-to-paint-tree(html, width, height) -> string` - Render HTML to paint tree JSON

### `mizchi:crater/incremental@0.1.0`
- `create-tree(html, width, height) -> u32` - Create layout tree from HTML
- `compute-incremental() -> string` - Compute layout incrementally (with cache)
- `compute-full() -> string` - Compute full layout (no cache)
- `mark-dirty(node-id) -> bool` - Mark node as dirty
- `update-style(node-id, css) -> bool` - Update node style
- `resize-viewport(width, height)` - Resize viewport
- `get-cache-stats() -> string` - Get cache statistics as JSON
- `reset-cache-stats()` - Reset cache statistics
- `needs-layout() -> bool` - Check if layout is needed
- `destroy-tree()` - Destroy current tree

### `mizchi:crater/yoga@0.1.0`
Yoga-compatible style API for programmatic layout:
- Node management: `create-node`, `add-child`, `insert-child`, `remove-child`, `get-child-count`
- Size: `set-width`, `set-width-percent`, `set-width-auto`, `set-height`, `set-height-percent`, `set-height-auto`
- Flex: `set-flex-grow`, `set-flex-shrink`, `set-flex-basis`, `set-flex-direction`, `set-flex-wrap`
- Alignment: `set-justify-content`, `set-align-items`
- Display: `set-display`
- Spacing: `set-margin`, `set-padding`, `set-gap`
- Computed values: `get-computed-left`, `get-computed-top`, `get-computed-width`, `get-computed-height`
- Layout: `calculate-layout`, `has-new-layout`, `mark-layout-seen`

## Publishing to wa.dev

```bash
# Login to wa.dev
wa login

# Publish
cd wasm
wa publish
```

## Requirements

- [MoonBit](https://www.moonbitlang.com/) toolchain
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools)
- [jco](https://github.com/bytecodealliance/jco) (for JavaScript bindings)
