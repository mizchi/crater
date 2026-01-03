# Title
Question: Block-level containers with `width: auto` - should they shrink to content or fill available space?

---

## What problem does this solve or what need does it fill?

I'm implementing a CSS-compatible layout engine using Taffy's test fixtures for validation. I've encountered a semantic difference between CSS specification behavior and Taffy's current behavior regarding block-level container sizing.

**CSS Specification Behavior:**
According to CSS 2.1 §10.3.3, block-level elements in normal flow with `width: auto` should expand to fill their containing block's width (minus margins). This applies to Grid and Flex containers as they are block-level by default.

**Current Taffy Behavior:**
When calling `compute_layout(root, available_space)` with a Grid or Flex container that has `size.width = auto()`, the container shrinks to fit its content rather than expanding to fill the available space.

**Example:**
```rust
let root_style = Style {
    display: Display::Grid,
    grid_template_columns: vec![TrackSizingFunction::Auto],
    ..Default::default()
};
// Child with intrinsic max_width: 40 via MeasureFunc

let layout = taffy.compute_layout(root, Size {
    width: AvailableSpace::Definite(800.0),
    height: AvailableSpace::Definite(600.0),
});

// Current Taffy: layout.size.width == 40 (shrink to content)
// CSS/Browser:   layout.size.width == 800 (fill available)
```

## What solution would you like?

Clarification on whether the current "shrink to fit" behavior is intentional for Taffy's use case (native UI layouts), or if it should follow CSS semantics where block-level containers fill available space.

If intentional, it would be helpful to:
1. Document this difference from CSS specification
2. Potentially provide an option to opt-in to CSS-compliant behavior

## What alternative(s) have you considered?

1. **Add a sizing mode parameter** - Allow callers to specify whether root should "fill available" or "shrink to fit"
2. **Follow CSS semantics by default** - Block-level containers (`display: grid/flex`) fill available space, inline-level (`display: inline-grid/inline-flex`) shrink to fit
3. **Keep current behavior** - Document that Taffy intentionally differs from CSS for native UI use cases

## Additional context

This difference affects many test fixtures when following CSS specification:
- `blockgrid_block_in_grid_auto`: expected width=40, CSS-compliant width=800
- `gridflex_column_integration`: expected width=40, CSS-compliant width=800
- Various `*_indefinite` tests

**Related issues:**
- #530 - Implement "root" layout mode (discusses root node sizing)
- #351 - Implement "§9.9 Intrinsic Sizes" (mentions "always shrink to fit" strategy)

**Reference:**
- CSS 2.1 §10.3.3: https://www.w3.org/TR/CSS21/visudet.html#blockwidth
- CSS Grid §7.1 (Grid Container Sizing): https://www.w3.org/TR/css-grid-1/#grid-container-sizing
