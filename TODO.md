# TODO

## Completed ✅

- [x] `position: fixed` viewport-based positioning
- [x] `overflow-x`, `overflow-y` in Layout struct
- [x] Inline layout (display: inline, inline-block)
- [x] Inline Formatting Context (IFC)

## High Priority (WPT Test Failures)

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
- [ ] z-index stacking context
- [ ] Renderer improvements (Sixel, SVG)
- [ ] CLS => Web Vitals metrics
- [ ] ShadowRoot support
- [ ] CSS Variables

## Documentation

- [ ] Add more usage examples to README
- [ ] Document API for intrinsic content sizing
- [ ] Add troubleshooting guide
