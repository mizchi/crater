# crater - CSS Layout Engine Specification

Pure MoonBit implementation of CSS layout calculation.

## Goals

- Calculate `getBoundingClientRect()` equivalent from HTML/CSS
- Focus on coordinate calculation, not rendering
- Support Block -> Flex -> Grid layouts (in order)
- Enable CLS (Cumulative Layout Shift) calculation

## Current Status

- [x] Basic geometry types (Size, Point, Rect, BoundingRect)
- [x] Dimension (Length, Percent, Auto)
- [x] Block layout with margin, padding, border
- [x] Percentage width/height
- [x] min/max width/height
- [x] Margin collapsing (adjacent siblings)
- [x] Percentage margin/padding (relative to parent width per CSS spec)
- [x] Flex layout
  - [x] flex-direction (row, column, row-reverse, column-reverse)
  - [x] justify-content (start, end, center, space-between, space-around, space-evenly)
  - [x] align-items (start, end, center, stretch)
  - [x] align-self
  - [x] flex-grow / flex-shrink
  - [x] flex-basis
  - [x] flex-wrap (wrap, nowrap)
  - [x] align-content (stretch, start, end, center, space-between, space-around)
  - [x] gap (row-gap, column-gap)
  - [x] margin: auto
  - [x] aspect-ratio
- [x] Grid layout
  - [x] grid-template-columns / grid-template-rows
  - [x] Track sizing: Length, Percent, Fr, Auto, MinContent, MaxContent
  - [x] minmax() function
  - [x] repeat() function (Count, AutoFill, AutoFit)
  - [x] grid-auto-rows / grid-auto-columns
  - [x] grid-auto-flow (Row, Column, Dense)
  - [x] gap (row-gap, column-gap)
  - [x] justify-content / align-content
  - [x] justify-items / align-items
  - [x] align-self for grid items
  - [x] Grid item placement (line-based)
  - [x] grid-template-areas (named areas)
  - [x] Implicit track creation
  - [x] Negative line indices
  - [x] aspect-ratio for grid items
  - [x] Nested Grid/Flex containers
  - [x] Extrinsic definite sizing for stretched items
  - [ ] Baseline alignment (partial)
  - [ ] Auto margins (partial)
  - [ ] Span items intrinsic sizing
  - [ ] Percent resolution in deeply nested grids

## Grid Test Status

**Current: 254/322 tests passing (78.9%)**

### Remaining Issues (68 tests)

1. **Baseline Alignment** (~5 tests)
   - Baseline calculation with padding needs refinement
   - Multiline baseline handling

2. **Auto Margins** (~2 tests)
   - Margin distribution when both left/right are auto
   - Interaction with stretch alignment

3. **Span Items** (~20 tests)
   - Intrinsic sizing for items spanning multiple tracks
   - Min-content/max-content calculation for span items

4. **Percent Items** (~10 tests)
   - Percent resolution in nested grids with auto-sized parents
   - Containing block width for percent padding

5. **Intrinsic Sizing** (~15 tests)
   - Min-content/max-content for nested Grid/Flex containers
   - Indefinite container sizing with content constraints

6. **Placement** (~5 tests)
   - Out-of-order item placement
   - Negative line indices with auto placement

7. **Overflow/Constraints** (~5 tests)
   - Overflow behavior
   - Padding/border interaction with max-size

## Implementation Roadmap

1. **Phase 1**: Flex layout ✅
2. **Phase 2**: Grid layout ✅ (78.9% tests passing)
3. **Phase 3**: `position: absolute/fixed` (partial - relative positioning done)
4. **Phase 4**: Float (simplified, if needed)

## Unsupported Features Policy

### Float

`float` is intentionally deferred due to implementation complexity:
- Requires BFC (Block Formatting Context) handling
- Complex interaction with `clear`, `overflow`, inline elements
- Modern layouts should use Flex/Grid instead

**Current behavior**: When `float` is detected, emit a warning and treat as normal block flow.

```moonbit
// Proposed warning API
pub enum LayoutWarning {
  UnsupportedFloat(String)  // node id
  UnsupportedPosition(String)
}
```

## TODO

### Text and Image Placeholder Handling

Text element widths depend on font rendering, which is complex to implement. For CLS calculation purposes, we need a simpler approach:

- Allow users to provide placeholder dimensions for text/image elements
- Support a "pre-calculated width" that can be passed in
- Check if line wrapping would occur within a given container width
- This enables layout estimation without full font rendering

Proposed API:

```moonbit
// Placeholder for intrinsic content size
pub struct IntrinsicSize {
  width : Double?   // Pre-measured or estimated width
  height : Double?  // Pre-measured or estimated height
}

// Node with intrinsic content
pub struct Node {
  id : String
  style : Style
  intrinsic : IntrinsicSize?  // For text/image elements
  children : Array[Node]
}
```

Use cases:
1. Server-side rendering: Estimate text dimensions from character count
2. Client-side: Pass actual measured dimensions from browser
3. Testing: Use fixed placeholder dimensions

### Hit Testing

Point-based hit testing to identify which element is at a given coordinate:

```moonbit
// Find element at point (x, y) in layout tree
pub fn hit_test(layout : Layout, x : Double, y : Double) -> Layout?

// Find all elements containing point (for nested elements)
pub fn hit_test_all(layout : Layout, x : Double, y : Double) -> Array[Layout]
```

Use cases:
1. Click handling: Identify clicked element
2. Hover detection: Find element under cursor
3. Touch handling: Identify tapped element
4. Accessibility: Navigate between elements

### Future Features

- [ ] `position: absolute` layout
- [ ] `overflow` handling
- [ ] `z-index` stacking context (for hit testing order)
- [ ] CSS Grid tracks and areas

## Test Porting Plan

### Phase 1: taffy Test Suite (Current)

Port tests from [taffy](https://github.com/DioxusLabs/taffy) - a Rust flexbox/grid layout engine.

**Completed categories:**
- [x] Basic flex row/column
- [x] flex-grow / flex-shrink
- [x] justify-content (all values)
- [x] align-items / align-self
- [x] flex-wrap (single/multi-line)
- [x] gap (row-gap, column-gap)
- [x] align-content (for wrapped lines)
- [x] min/max constraints

**Pending categories:**
- [x] margin: auto (centering)
- [x] aspect-ratio
- [x] wrap-reverse
- [x] position: absolute
- [x] baseline alignment
- [x] Complex nested scenarios (explicit sizes)
- [ ] Complex nested scenarios (intrinsic sizing) - requires 2-pass layout
- [ ] Edge cases (overflow, negative space)

### Phase 2: MDN/WHATWG Spec Tests

Add tests based on CSS specification examples:

- [ ] CSS Flexible Box Layout Module Level 1 (W3C)
  - https://www.w3.org/TR/css-flexbox-1/
- [ ] CSS Box Alignment Module Level 3
  - https://www.w3.org/TR/css-align-3/
- [ ] MDN Flexbox examples
  - https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout

### Phase 3: Real-World Layout Tests

Create tests from common UI patterns:
- [ ] Navigation bars
- [ ] Card layouts
- [ ] Form layouts
- [ ] Dashboard grids
- [ ] Responsive patterns

### Test Coverage Goals

| Feature | taffy | MDN/Spec | Real-world |
|---------|-------|----------|------------|
| Flex row | ✅ | - | - |
| Flex column | ✅ | - | - |
| Flex wrap | ✅ | - | - |
| Gap | ✅ | - | - |
| Alignment | ✅ | - | - |
| Grid basic | ✅ (254/322) | - | - |
| Grid span | ⚠️ partial | - | - |
| Grid baseline | ⚠️ partial | - | - |
