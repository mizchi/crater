# Crater Public API Reference

This document describes the current public MoonBit module boundaries. Prefer
these module roots over old `mizchi/crater/...` subpackage imports.

## Module Overview

| Module | Purpose |
| --- | --- |
| `mizchi/css` | External CSS parser, selector matcher, cascade, computed values, and diagnostics |
| `mizchi/crater-core` | Layout records, layout context, intrinsic size, and shared core contracts |
| `mizchi/crater-core/node` | Layout input node model |
| `mizchi/crater-layout` | Layout entry point and block/flex/grid dispatch |
| `mizchi/crater-layout/tree` | Incremental layout tree and node helpers |
| `mizchi/crater-layout/core_subset` | TUI-oriented checked subset over the layout API |
| `mizchi/crater-dom` | DOM, HTML parser, scheduler, and AOM facade |
| `mizchi/crater-dom/html` | HTML document and fragment parser |
| `mizchi/crater-dom/dom` | Mutable DOM tree and mutation records |
| `mizchi/crater-dom/aom` | Accessibility tree, roles, and focus helpers |
| `mizchi/crater-dom/css/responsive` | Breakpoint and computed-style discovery helpers |
| `mizchi/crater-dom/layout/html_tree` | HTML document to layout tree bridge |
| `mizchi/crater-dom/layout/style_bridge` | Cascaded CSS to layout tree bridge |
| `mizchi/crater-painter` | Paint/SVG facade over the paint model and conversion helpers |
| `mizchi/crater-painter/paint/model` | Paint tree model |
| `mizchi/crater-painter/paint/build` | Compatibility wrapper for paint tree construction |
| `mizchi/crater-painter/paint/traversal` | Paint tree traversal and flattening |
| `mizchi/crater-painter/paint/scroll` | Scrollable element hit testing |
| `mizchi/crater-renderer` | HTML/CSS to paint tree rendering and VRT helpers |
| `mizchi/crater-renderer/renderer` | Narrow renderer implementation package |
| `mizchi/crater-renderer/vrt` | VRT page preparation and render variants |
| `mizchi/crater-aomx` | AOM-derived extraction, grounding, and diff helpers |
| `mizchi/crater-browser-http` | Cookie, CORS, SameSite, HTTP cache, and auth profile helpers |
| `mizchi/crater-browser-runtime` | Shared JS runtime contract and DOM serializer |
| `mizchi/crater-browser` | Browser shell integration |
| `mizchi/crater-network` | WebDriver BiDi synthetic network state and byte/query helpers |
| `mizchi/crater-webdriver-bidi` | WebDriver BiDi public facade |
| `mizchi/crater-js` | JavaScript exports for renderer/layout consumers |
| `mizchi/crater-wasm` | WASM component facade |
| `mizchi/crater` | Umbrella meta-module over the foundation/render layer |

## Layout

Use `mizchi/crater-layout` for layout computation.

```moonbit
pub fn compute_layout(@node.Node, @values.Size[Double]) -> @core.Layout
pub fn compute_layout_with_warnings(@node.Node, @values.Size[Double]) -> @core.LayoutResult
pub fn compute_layout_in_context(@node.Node, @core.LayoutContext) -> @core.Layout
pub fn layout_tree_from_node(@node.Node, Double, Double) -> LayoutTree
```

Use `mizchi/crater-layout/tree` when you need incremental tree operations, and
`mizchi/crater-layout/core_subset` when you need the checked TUI subset.

## CSS

Use `mizchi/css` as the public CSS boundary.

```moonbit
// Typical package imports:
"mizchi/css"
"mizchi/css/parser"
"mizchi/css/selector"
"mizchi/css/cascade"
"mizchi/css/media"
"mizchi/css/computed"
"mizchi/css/values"
"mizchi/css/style"
"mizchi/css/diagnostics"
```

Crater modules consume CSS through this external module. Do not add new imports
that point at old Crater-owned CSS package paths.

## DOM And AOM

Use `mizchi/crater-dom` for the combined facade, or the narrower packages when a
single subsystem is enough.

```moonbit
pub fn parse_document(String) -> @html.Document
pub fn parse_fragment(String) -> @html.Element
pub fn build_accessibility_tree(@html.Document) -> @aom.AccessibilityTree
```

Bridge packages under `mizchi/crater-dom/layout/*` connect parsed HTML and
cascaded CSS to `LayoutTree`. Keep new bridge code in the DOM module unless the
logic is purely CSS or purely layout.

## Paint And Renderer

Use `mizchi/crater-renderer` for high-level render/VRT workflows.

```moonbit
pub fn render_html_to_paint_tree(String, @values.Size[Double]) -> @model.PaintNode
pub fn render_html_to_paint_tree_json(String, @values.Size[Double]) -> String
pub fn prepare_vrt_page(String, @values.Size[Double], Array[String]) -> @vrt.PreparedVrtPage
pub fn diff_rendered_paint_trees(String, String, @values.Size[Double]) -> @diff.PaintTreeDiff
```

Use `mizchi/crater-painter` or `mizchi/crater-painter/paint/model` when you
already have layout data and only need paint tree data structures or conversion
helpers.

## Web Vitals

Use `mizchi/crater-webvitals` for metric helpers that operate over Crater layout
output.

```moonbit
pub(all) struct LayoutShift {
  impact_fraction : Double
  distance_fraction : Double
  score : Double
}

pub fn compute_element_shift(@values.BoundingRect, @values.BoundingRect, @values.Size[Double]) -> LayoutShift
pub fn compute_total(Array[@values.BoundingRect], Array[@values.BoundingRect], @values.Size[Double]) -> Double
```

LCP helpers are exposed through `LCPCandidate`, `LCPTracker`, and
`extract_lcp_candidates`.

## WebDriver BiDi

Use the root `mizchi/crater-webdriver-bidi` package for stable protocol-facing
types and server configuration.

```moonbit
pub fn parse_method(String) -> ApiMethod?
pub using @contract {type WebDriverRequest}
pub using @contract {type WebDriverResponse}
pub using @rpc {type RpcRequest}
pub using @rpc {type RpcResponse}
pub using @server {type SessionManager}
pub using @webdriver {type BidiServer}
pub using @webdriver {type BidiServerConfig}
```

The root facade intentionally does not expose CDP session handlers. Internal
handler helpers remain in `mizchi/crater-webdriver-bidi/webdriver` while
contract-only code belongs in `contract`, `rpc`, `protocol`, or `server`.

## Browser And Network

Use `mizchi/crater-browser` for the browser shell and `mizchi/crater-browser-*`
modules for narrower browser support packages.

`mizchi/crater-network` is currently scoped to WebDriver BiDi synthetic network
state and byte/query normalization shared by the adapter. It is not a general
HTTP client boundary; general browser HTTP concerns live in
`mizchi/crater-browser-http`.

## Compatibility Bridges

Compatibility bridges are documented in `docs/compatibility-bridges.md`. They
should stay thin: re-export types, forward functions, and keep implementation
state in the canonical package.
