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
- [x] Flex layout (row/column, justify-content, align-items, flex-grow/shrink)
- [ ] Grid layout

## Implementation Roadmap

1. **Phase 1**: Flex layout ✅
2. **Phase 2**: Grid layout
3. **Phase 3**: `position: absolute/fixed`
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
- [ ] Flex wrap and grow/shrink
