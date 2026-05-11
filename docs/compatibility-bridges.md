# Compatibility Bridges

This repository keeps a small set of compatibility bridge packages so older
imports keep working while the implementation moves toward narrower modules.
New code should depend on the canonical package listed below.

| Compatibility package | Canonical package |
| --- | --- |
| `mizchi/crater` | Direct workspace modules such as `mizchi/crater-css`, `mizchi/crater-dom`, `mizchi/crater-renderer`, and `mizchi/crater-painter` |
| `mizchi/crater/css` | `mizchi/crater-css/*` packages |
| `mizchi/crater-browser/js` | `mizchi/crater-browser-runtime` |
| `mizchi/crater-browser-shell` | `mizchi/crater-browser-shell/html_assets` and `mizchi/crater-terminal-image-cache` |
| `mizchi/crater-dom/layout/html_bridge` | `mizchi/crater-dom/layout/html_tree` and `mizchi/crater-dom/layout/style_bridge` |
| `mizchi/crater-painter/paint/layout_bridge` | `mizchi/crater-painter/paint/node_bridge`, `layout_tree_bridge`, and `viewport_bridge` |
| `mizchi/crater-painter/paint/render_bridge` | `mizchi/crater-painter/paint/node_bridge` and `viewport_bridge` |
| `mizchi/crater-painter/paint/raster` glyph facade | `mizchi/crater-painter/paint/glyph` |

Compatibility bridge packages should stay thin:

- Re-export types and forward functions only.
- Keep implementation state in the canonical package.
- Add a boundary test before moving a helper behind a bridge.
- Update this table when a new bridge is introduced or retired.
