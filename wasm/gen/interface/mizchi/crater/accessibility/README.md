# Accessibility Interface

Accessibility tree and ARIA snapshot generation for HTML content.

## Functions

### `get_aria_snapshot(html) -> String`

Get ARIA snapshot in YAML format (Playwright-compatible).

```javascript
const snapshot = accessibility.getAriaSnapshot('<button>Click</button>');
// - document:
//   - generic:
//     - button "Click": Click
```

### `get_aria_snapshot_json(html) -> String`

Get ARIA snapshot as JSON with role, name, and structure.

```javascript
const json = JSON.parse(accessibility.getAriaSnapshotJson('<button>Click</button>'));
// {
//   "role": "document",
//   "children": [
//     {
//       "role": "generic",
//       "children": [
//         { "role": "button", "name": "Click", ... }
//       ]
//     }
//   ]
// }
```

### `get_accessibility_tree(html) -> String`

Get full accessibility tree with all ARIA attributes.

```javascript
const tree = JSON.parse(accessibility.getAccessibilityTree('<input type="checkbox" checked>'));
// {
//   "id": "...",
//   "role": "checkbox",
//   "focusable": true,
//   "states": ["checked"],
//   ...
// }
```

## Use Cases

- **Testing**: Verify accessibility structure matches expectations
- **Screen reader simulation**: Understand how assistive technologies see the page
- **Accessibility auditing**: Analyze role and state information
- **Playwright integration**: Use ARIA snapshots for assertions

## Supported Roles

The accessibility tree supports standard ARIA roles including:
- `button`, `link`, `textbox`, `checkbox`, `radio`
- `heading`, `list`, `listitem`, `table`, `row`, `cell`
- `navigation`, `main`, `banner`, `contentinfo`
- And many more based on HTML semantics

## Example

```javascript
import { accessibility } from './crater/crater.js';

const html = `
  <nav>
    <a href="/">Home</a>
    <a href="/about">About</a>
  </nav>
  <main>
    <h1>Welcome</h1>
    <button>Get Started</button>
  </main>
`;

console.log(accessibility.getAriaSnapshot(html));
// - document:
//   - navigation:
//     - link "Home": Home
//     - link "About": About
//   - main:
//     - heading "Welcome" [level=1]
//     - button "Get Started": Get Started
```
