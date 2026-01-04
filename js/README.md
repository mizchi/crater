# @aspect-io/crater

CSS Layout Engine - Box/Flex/Grid layout computation, compiled from MoonBit.

## Installation

```bash
npm install @aspect-io/crater
```

## Usage

```typescript
import {
  renderHtml,
  renderHtmlToJson,
  renderHtmlToPaintTree,
  Crater
} from '@aspect-io/crater';

const html = '<div style="width: 200px; display: flex">...</div>';

// Get layout tree as JSON string
const layoutJson = renderHtmlToJson(html, 800, 600);
const layout = Crater.parseLayout(layoutJson);

// Get paint tree with colors
const paintJson = renderHtmlToPaintTree(html, 800, 600);
const paintTree = Crater.parsePaintTree(paintJson);
```

## API

### `renderHtml(html, width, height): string`
Render HTML to text layout tree representation.

### `renderHtmlToJson(html, width, height): string`
Render HTML to JSON layout tree.

### `renderHtmlToPaintTree(html, width, height): string`
Render HTML to paint tree JSON with colors and visual properties.

### `renderHtmlToSixel(html, width, height): string`
Render HTML to Sixel graphics for terminal display.

### `renderHtmlToSixelWithStyles(html, width, height): string`
Render HTML to Sixel graphics with actual CSS colors.

### `Crater.parseLayout(json): LayoutNode`
Parse layout JSON to typed object.

### `Crater.parsePaintTree(json): PaintNode`
Parse paint tree JSON to typed object.

## CLI

```bash
# Via npx
npx @aspect-io/crater input.html
npx @aspect-io/crater --json input.html
npx @aspect-io/crater --styles input.html

# Or install globally
npm install -g @aspect-io/crater
crater input.html
```

## WASM-GC (Experimental)

For browsers with WASM-GC support (Chrome 119+, Firefox 120+):

```typescript
import loadCrater from '@aspect-io/crater/wasm';

const crater = await loadCrater();
const layoutJson = crater.renderHtmlToJson(html, 800, 600);
```

Benefits:
- Smaller bundle size (326KB vs 1.4MB)
- Potentially faster execution
- Requires WASM-GC support

## TypeScript

Full TypeScript support with type definitions:

```typescript
import type { LayoutNode, PaintNode, BoxEdges } from '@aspect-io/crater';
import type { CraterWasm } from '@aspect-io/crater/wasm';
```

## Development

```bash
# Build from MoonBit source
cd js && npm run build

# Run playground
cd js/playground && npm run dev
```

## License

Apache-2.0
