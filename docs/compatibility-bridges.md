# Compatibility Bridges

This repository keeps a small set of compatibility bridge packages so older
imports keep working while the implementation moves toward narrower modules.
New code should depend on the canonical package listed below.

| Compatibility package | Canonical package |
| --- | --- |
| `mizchi/crater-browser/js` | `mizchi/crater-browser-runtime` |
| `mizchi/crater-dom/layout/html_bridge` | `mizchi/crater-dom/layout/html_tree` and `mizchi/crater-dom/layout/style_bridge` |
| `mizchi/crater-painter/paint/layout_bridge` | `mizchi/crater-painter/paint/node_bridge`, `layout_tree_bridge`, and `viewport_bridge` |
| `mizchi/crater-painter/paint/render_bridge` | `mizchi/crater-painter/paint/node_bridge` and `viewport_bridge` |
| `mizchi/crater-painter/paint/raster` glyph facade | `mizchi/crater-painter/paint/glyph` |
| `mizchi/crater-webdriver-bidi/webdriver` contract types | `mizchi/crater-webdriver-bidi/contract` |
| `mizchi/crater-webdriver-bidi/webdriver` JSON-RPC facade | `mizchi/crater-webdriver-bidi/rpc` |
| `mizchi/crater-webdriver-bidi/webdriver` QuickJS runtime facade | `mizchi/crater-webdriver-bidi/runtime` |
| `mizchi/crater-webdriver-bidi/webdriver` pure BiDi protocol helpers | `mizchi/crater-webdriver-bidi/protocol` |
| `mizchi/crater-webdriver-bidi/webdriver` BiDi wire parser/serializer | `mizchi/crater-webdriver-bidi/protocol/wire` |
| `mizchi/crater-webdriver-bidi/network` | `mizchi/crater-network` |

The old root facades `mizchi/crater` and `mizchi/crater/css` have been retired
from the workspace. Use the dedicated modules directly, especially
`mizchi/crater-css`, `mizchi/crater-layout`, `mizchi/crater-renderer`, and
`mizchi/crater-painter`.

Compatibility bridge packages should stay thin:

- Re-export types and forward functions only.
- Keep implementation state in the canonical package.
- Add a boundary test before moving a helper behind a bridge.
- Update this table when a new bridge is introduced or retired.
