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

### Core API (Recommended for simple layout computation)

```javascript
import { core } from './crater/crater.js';

// Compute layout from HTML - returns flat node array
const html = '<div style="width: 100px; height: 50px"><span>Hello</span></div>';
const result = JSON.parse(core.computeLayout(html, 800, 600));

console.log(result.rootId); // "body"
console.log(result.nodes);
// [
//   { id: "body", parentId: "", index: 0, x: 0, y: 0, width: 800, height: 50, ... },
//   { id: "div", parentId: "body", index: 0, x: 0, y: 0, width: 100, height: 50, ... },
//   { id: "span", parentId: "div", index: 0, x: 0, y: 0, width: 100, height: 50, text: "Hello", ... }
// ]

// Build tree from flat array if needed
function buildTree(nodes, rootId) {
  const nodeMap = new Map(nodes.map(n => [n.id, { ...n, children: [] }]));
  for (const node of nodes) {
    if (node.parentId) {
      nodeMap.get(node.parentId)?.children.push(nodeMap.get(node.id));
    }
  }
  return nodeMap.get(rootId);
}
```

### Renderer API (Legacy hierarchical output)

```javascript
import { renderer } from './crater/crater.js';

// Render HTML to layout JSON (hierarchical tree)
const html = '<div style="width: 100px; display: flex;"><div style="flex: 1;"></div></div>';
const layoutJson = renderer.renderHtmlToJson(html, 800, 600);
const layout = JSON.parse(layoutJson);
console.log(layout);
// { id: 'body', x: 0, y: 0, width: 800, height: 0, children: [...] }

// Render to paint tree with colors
const paintTree = renderer.renderHtmlToPaintTree(html, 800, 600);
```

### Incremental API (For apps with dynamic updates)

```javascript
import { incremental } from './crater/crater.js';

// Create layout tree
incremental.createTree(html, 800, 600);

// Initial layout
const result = incremental.computeIncremental();
console.log(JSON.parse(result));

// Update style and recompute (only affected nodes)
incremental.updateStyle('div#root', 'width: 200px;');
incremental.markDirty('div#root');
const updated = incremental.computeIncremental();

// Check cache statistics
const stats = JSON.parse(incremental.getCacheStats());
console.log(`Cache hit rate: ${stats.hitRate * 100}%`);

// Resize viewport
incremental.resizeViewport(1024, 768);
const resized = incremental.computeIncremental();

// Cleanup
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

### Accessibility API

```javascript
import { accessibility } from './crater/crater.js';

const html = '<button>Click me</button><input type="text" placeholder="Name">';

// Get ARIA snapshot (Playwright-compatible YAML format)
console.log(accessibility.getAriaSnapshot(html));
// - document:
//   - generic:
//     - button "Click me": Click me
//     - textbox

// Get ARIA snapshot as JSON
const ariaJson = JSON.parse(accessibility.getAriaSnapshotJson(html));
console.log(ariaJson);

// Get full accessibility tree
const tree = JSON.parse(accessibility.getAccessibilityTree(html));
console.log(tree);
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

The component exports five interfaces:

### `mizchi:crater/core@0.1.0` (Recommended)
Stateless, pure layout computation with flat output format.
- `compute-layout(html, width, height) -> string` - Compute layout, returns JSON with `{ rootId, nodes[] }`

Output node format:
```typescript
interface LayoutNode {
  id: string;
  parentId: string;  // empty for root
  index: number;     // child index in parent
  x: number;
  y: number;
  width: number;
  height: number;
  contentX: number;
  contentY: number;
  contentWidth: number;
  contentHeight: number;
  text?: string;     // for text nodes
}
```

### `mizchi:crater/renderer@0.1.0`
Legacy rendering with hierarchical output.
- `render-html(html, width, height) -> string` - Render HTML to text layout tree
- `render-html-to-json(html, width, height) -> string` - Render HTML to JSON (hierarchical)
- `render-html-to-paint-tree(html, width, height) -> string` - Render HTML to paint tree JSON

### `mizchi:crater/incremental@0.1.0`
Stateful layout with caching and diff updates.
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

### `mizchi:crater/accessibility@0.1.0`
Accessibility tree and ARIA snapshot generation.
- `get-aria-snapshot(html) -> string` - Get ARIA snapshot in YAML format (Playwright-compatible)
- `get-aria-snapshot-json(html) -> string` - Get ARIA snapshot as JSON
- `get-accessibility-tree(html) -> string` - Get full accessibility tree as JSON

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
