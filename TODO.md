# TODO

## Completed ✅

- [x] `position: static/relative/absolute/fixed`
- [x] `overflow-x`, `overflow-y` in Layout struct
- [x] Inline layout (display: inline, inline-block)
- [x] Inline Formatting Context (IFC)
- [x] CSS Variables (basic `--var` and `var()` support)
- [x] `visibility: hidden` with child override capability
- [x] CSS diagnostics system
- [x] `aria-owns` support in accessibility tree

## High Priority (Remaining Issues)

### Baseline Alignment (~25 WPT tests)
- [ ] Implement baseline calculation for flex items
- [ ] Handle baseline with padding/margin
- [ ] Multiline baseline in flex and grid

### Writing Modes (~20 WPT tests)
- [ ] vertical-lr, vertical-rl support
- [ ] Direction-aware layout calculations

### Intrinsic Sizing (~20 tests)
- [ ] Fix min-content/max-content for nested containers
- [ ] Implement proper measure functions for leaf nodes

### Margin Collapsing Edge Cases
- [ ] Negative margin collapsing
- [ ] Margin collapse blocked by flex/grid containers

## Medium Priority

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
- [ ] z-index stacking context
- [ ] Float layout (intentionally deferred)
- [ ] ShadowRoot support

## Documentation

- [ ] Add more usage examples to README
- [ ] Document API for intrinsic content sizing
