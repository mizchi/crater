# TODO

## High Priority (Test Failures)

### display: none (~7 tests)
- [ ] Skip hidden elements in layout calculation
- [ ] Ensure size is 0 and position doesn't affect siblings

### Intrinsic Sizing (~20 tests)
- [ ] Fix min-content/max-content for nested containers
- [ ] Implement proper measure functions for leaf nodes
- [ ] Handle `Infinity` values correctly in sizing

### Absolute Positioning (~10 tests)
- [ ] Fix inset resolution with percentages
- [ ] Correct border/padding interaction with absolute items

### Baseline Alignment (~10 tests)
- [ ] Fix baseline calculation with padding/margin
- [ ] Handle multiline baseline in flex and grid

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

### Margin Collapsing Edge Cases
- [ ] Fix complex margin collapse scenarios
- [ ] Handle line-box blocking correctly

## Low Priority (Future Features)

- [ ] Renderer improvements
- [ ] Sixel renderer
- [ ] SVG renderer
- [ ] CLS => Web Vitals metrics
- [ ] ShadowRoot support
- [ ] CSS Variables
- [ ] User Agent default CSS

## Documentation

- [ ] Add more usage examples to README
- [ ] Document API for intrinsic content sizing
- [ ] Add troubleshooting guide
