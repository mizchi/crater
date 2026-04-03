# VRT Enhancements: CSS Rule Viewport Map (#33) & Batch Variant Rendering (#28)

## Issue #33: Breakpoint-aware CSS rule mapping

### Problem

`discover_responsive_breakpoints` returns breakpoint values but not which CSS rules are active at which viewport width. VRT benchmarks testing at fixed viewports (1440/1280/375px) miss media-scoped rules that only apply at unlisted widths.

### MoonBit API

New file: `src/css/responsive/viewport_map.mbt`

```moonbit
pub struct CssRuleViewportEntry {
  selector : String
  properties : Array[String]
  media_condition : String
  active_at_widths : Array[Int]
  inactive_at_widths : Array[Int]
}

pub struct CssRuleViewportMap {
  rules : Array[CssRuleViewportEntry]
}

pub struct RequiredTestViewport {
  width : Int
  reason : String
}

pub struct RequiredTestViewportsResult {
  viewports : Array[RequiredTestViewport]
}

pub fn discover_css_rule_viewport_map(
  html : String,
  viewport_widths : Array[Int],
) -> CssRuleViewportMap

pub fn discover_required_test_viewports(
  html : String,
) -> RequiredTestViewportsResult
```

**Implementation approach:**
1. Parse HTML, extract inline `<style>` tags (reuse `@html.parse_document`)
2. Parse each stylesheet (reuse `@parser.parse_stylesheet`)
3. For each `CSSRule` with a `media_query`:
   - Extract selector_text and property names from declarations
   - For each requested viewport width, evaluate media query via `MediaQueryList::evaluate` with `MediaEnvironment::new(width, 900.0)`
   - Classify width as active/inactive
4. `discover_required_test_viewports`: extract breakpoint values from media queries (reuse existing `discover_responsive_breakpoints` logic), then generate "test just below and at each breakpoint" recommendations

### BiDi Commands

- `browsingContext.getCssRuleViewportMap` -> dispatches to `discover_css_rule_viewport_map`
- `browsingContext.getRequiredTestViewports` -> dispatches to `discover_required_test_viewports`

Both use the HTML content already loaded in the browsing context.

---

## Issue #28: Batch multi-variant rendering

### Problem

VRT benchmarks re-parse the same HTML for each CSS mutation variant. 30+ variants per fixture means redundant HTML parsing, DOM construction, and non-affected style computation.

### MoonBit API

New file: `src/vrt_batch.mbt`

```moonbit
pub struct CssMutation {
  selector : String
  property : String
  action : CssMutationAction
}

pub enum CssMutationAction {
  Remove
  Override(String)  // new value
}

pub struct RenderVariant {
  id : String
  mutations : Array[CssMutation]
}

pub struct RenderVariantResult {
  id : String
  paint_tree : @paint.PaintNode
}

pub fn render_html_batch_variants(
  html : String,
  viewport : @types.Size[Double],
  variants : Array[RenderVariant],
) -> Array[RenderVariantResult]
```

**Implementation approach (Phase 1: DOM clone):**
1. Parse HTML once: `@html.parse_document(html)` -> `Document`
2. Parse stylesheets once from the document
3. For each variant:
   a. Clone the stylesheet, apply CSS mutations (remove/override declarations matching selector+property)
   b. Run full render pipeline: `render_to_node_and_layout_with_document(doc, ctx, mutated_css)`
   c. Build paint tree
4. Return results array

**Key insight:** The existing `render_to_node_and_layout_with_document` already accepts a parsed `Document`, so HTML parsing is naturally shared. The main optimization is avoiding re-parsing CSS by cloning and mutating the stylesheet.

### BiDi Command

- `browsingContext.batchRender` -> dispatches to `render_html_batch_variants`

Input: `{ context, baseHtml, viewport: {width, height}, variants: [{id, mutations: [{selector, property, action}]}] }`
Output: `{ results: [{id, paintData, width, height}] }`

---

## Implementation Order

1. #33 MoonBit API + tests (independent of #28)
2. #28 MoonBit API + tests (independent of #33)
3. BiDi commands for both (depends on 1 & 2)
4. `moon info && moon fmt` finalization
