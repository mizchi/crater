# TODO

## Completed ✅

- [x] `position: fixed` viewport-based positioning
- [x] `overflow-x`, `overflow-y` in Layout struct
- [x] Inline layout (display: inline, inline-block)
- [x] Inline Formatting Context (IFC)

## High Priority (WPT Test Failures)

### Wikipedia layout issues
- [x] `position: static` handling (fixed - added Static to Position enum)
  - Note: Some Taffy tests fail because they expect `position: relative` as default
  - Taffy fixtures with `inset` but no explicit `position` now behave differently
- [x] **Flex container height with auto sizing** (fixed in compute/block/block.mbt)
  - Block layout now passes `available_height: None` for auto-height Flex/Grid children
  - This prevents flex containers from inheriting parent's available height
  - Flex items stretched by their parent still receive correct `available_height`
  - Reproduction: `test_utils/fixtures/flex-height.html`
  - Verified: `.header-container` now correctly sizes to ~50px instead of 800px
- [ ] Check flex container alignment defaults for complex nested layouts

### Baseline Alignment (~25 WPT tests)
- [ ] Implement baseline calculation for flex items
- [ ] Handle baseline with padding/margin
- [ ] Multiline baseline in flex and grid

### Writing Modes (~20 WPT tests)
- [ ] vertical-lr, vertical-rl support
- [ ] Direction-aware layout calculations

### flex-wrap: wrap-reverse
- [ ] Fix alignment in wrap-reverse mode
- [ ] Cross-axis positioning for reversed lines

### position: relative with negative offsets
- [ ] Handle negative top/left values
- [ ] Proper offset from normal flow position

## Medium Priority (Taffy Test Failures)

### display: none (~7 tests)
- [ ] Skip hidden elements in layout calculation
- [ ] Ensure size is 0 and position doesn't affect siblings

### Intrinsic Sizing (~20 tests)
- [ ] Fix min-content/max-content for nested containers
- [ ] Implement proper measure functions for leaf nodes
- [ ] Handle `Infinity` values correctly in sizing

### Span Items in Grid (~15 tests)
- [ ] Fix intrinsic sizing for items spanning multiple tracks
- [ ] Correct gap calculation for span items

### Percent in Nested Layouts (~15 tests)
- [ ] Handle percent resolution in nested grids with auto-sized parents
- [ ] Fix cyclic percentage dependencies

### Aspect Ratio (~10 tests)
- [ ] Fix interaction with max-width/max-height constraints
- [ ] Correct fill mode with constraints

## Low Priority (Future Features)

- [ ] Table layout (thead, tbody, caption)
- [ ] Overflow clipping during rendering
  - [ ] Proper `clip: rect()` implementation in rendering pipeline
  - [ ] Pass clip/overflow from Style → Layout → PaintNode correctly
  - [ ] Current workarounds (renderer/renderer.mbt, renderer/sixel/sixel.mbt):
    - Skip elements with a11y hiding classes (mw-jump-link, sr-only, visually-hidden, etc.)
    - Skip 1x1 or smaller elements in Sixel rendering
    - Skip text nodes with width <= 1 in Sixel rendering
  - [ ] Proper fix: compute styles before inline content collection (architectural change)
- [ ] z-index stacking context
- [ ] Renderer improvements (Sixel, SVG)
- [ ] CLS => Web Vitals metrics
- [ ] ShadowRoot support
- [ ] CSS Variables (completed basic implementation, needs var() fallback)

## Documentation

- [ ] Add more usage examples to README
- [ ] Document API for intrinsic content sizing
- [ ] Add troubleshooting guide
