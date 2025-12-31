# Issue: multiline_min_max Tests

## Summary

5 tests failing related to `multiline_min_max` with CSS box-sizing behavior.

## Test Pattern

All 5 tests have similar structure:
- Root: `width: 600`, `height: 20`, `border: 5` on all sides, `flex_wrap: Wrap`
- Expected: `layout.width = 610` (600 + 10 border), `layout.height = 30` (20 + 10 border)
- Actual: `layout.width = 600`, `layout.height = 20`

## Root Cause

CSS box model: `width: 600px` is the content-box width. Total box width = content + padding + border = 600 + 0 + 10 = 610.

Current implementation:
1. `container_width = 600` (from style.width)
2. `content_width = container_width - padding - border = 590`
3. Returns `container_width` (600) as layout width - **missing border**

## Attempted Fix

```moonbit
// Add padding+border to output for explicit widths
let final_width = if not(width_is_auto) {
  container_width + padding.horizontal_sum() + border.horizontal_sum()
} else {
  container_width
}
```

## Problem with Fix

Applying width+height fix causes regression (874 -> 827 tests).

Specifically, `children[0].width` becomes 600 instead of expected 300.

### Analysis

The issue is complex because:

1. **Semantic inconsistency in `container_width`**:
   - For explicit width: `container_width = CSS width value` (content-box)
   - For auto width: `container_width = parent_width - margin` (full box)

2. **Child calculations depend on container_width**:
   - Line 1701: `available_width: container_width` passed to nested children
   - Line 1750: `container_width - child_width - ...` used for positioning

3. **Height affects width calculations**:
   - When height fix is applied, child width calculations break
   - Suggests interdependency between height and child layout

## Key Code Locations

- `flex/flex.mbt:367-371`: `container_width` initialization
- `flex/flex.mbt:396-398`: `content_width` calculation
- `flex/flex.mbt:1581-1615`: `container_height` initialization
- `flex/flex.mbt:1865-1877`: `final_width` calculation
- `flex/flex.mbt:1701,1709`: `container_width` passed to children

## Potential Solutions

### Option 1: Fix at output only (tried, failed)
Add padding+border only at the final output. Failed due to child layout corruption.

### Option 2: Fix `container_width` semantics
Make `container_width` always represent the full box width:
```moonbit
let mut container_width = match style.width {
  @types.Length(w) => w + padding.horizontal_sum() + border.horizontal_sum()
  @types.Percent(p) => parent_width * p + padding.horizontal_sum() + border.horizontal_sum()
  @types.Auto => parent_width - margin.horizontal_sum()
}
```
Then adjust all places where `container_width` is passed to children.

### Option 3: Introduce separate variables
Keep `container_width` as CSS width, introduce `box_width` for output.
More surgical changes but adds complexity.

## Priority

P2 (Medium) - 5 tests affected, but fix is complex and may introduce regressions.

## Related Tests

- `taffy/multiline_min_max_5`
- `taffy/multiline_min_max_8`
- `taffy/multiline_min_max_12`
- `taffy/multiline_min_max_13`
- `taffy/multiline_min_max_14`
