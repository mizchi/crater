# Core Interface

Stateless, pure layout computation with flat output format.

## Functions

### `compute_layout(html, width, height) -> String`

Compute layout from HTML and return a flat node array as JSON.

**Parameters:**
- `html: String` - HTML content to render
- `width: UInt` - Viewport width in pixels
- `height: UInt` - Viewport height in pixels

**Returns:** JSON string with format:
```json
{
  "rootId": "body",
  "nodes": [
    {
      "id": "body",
      "parentId": "",
      "index": 0,
      "x": 0,
      "y": 0,
      "width": 800,
      "height": 50,
      "contentX": 0,
      "contentY": 0,
      "contentWidth": 800,
      "contentHeight": 50
    },
    {
      "id": "div",
      "parentId": "body",
      "index": 0,
      "x": 0,
      "y": 0,
      "width": 100,
      "height": 50,
      "contentX": 0,
      "contentY": 0,
      "contentWidth": 100,
      "contentHeight": 50,
      "text": "Hello"
    }
  ]
}
```

## Node Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique node identifier |
| `parentId` | string | Parent node ID (empty for root) |
| `index` | number | Child index in parent |
| `x` | number | X position (border box) |
| `y` | number | Y position (border box) |
| `width` | number | Width (border box) |
| `height` | number | Height (border box) |
| `contentX` | number | Content box X position |
| `contentY` | number | Content box Y position |
| `contentWidth` | number | Content box width |
| `contentHeight` | number | Content box height |
| `text` | string? | Text content (if text node) |

## Usage

```javascript
import { core } from './crater/crater.js';

const result = JSON.parse(core.computeLayout('<div>Hello</div>', 800, 600));

// Flat array - easy to iterate
for (const node of result.nodes) {
  console.log(`${node.id}: ${node.width}x${node.height} at (${node.x}, ${node.y})`);
}

// Build tree if needed
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
