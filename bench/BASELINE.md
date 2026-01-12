# Benchmark Baseline (2025-01-12)

## Summary

| Category | Benchmark | Time |
|----------|-----------|------|
| **Parse** | flat_100 | 40.31 µs |
| | flat_1000 | 417.59 µs |
| | large_5k | 1.01 ms |
| | scroll_1000 | 5.18 ms |
| **Render (Full)** | flat_100 | 422.73 µs |
| | flat_1000 | 5.14 ms |
| | flex_d5 | 2.52 ms |
| | flex_d6 | 7.94 ms |
| | grid_10x10 | 508.73 µs |
| | cards_24 | 1.29 ms |
| | dashboard_med | 1.22 ms |
| | large_2k5 | 9.56 ms |
| | large_5k | 21.27 ms |
| | scroll_500 | 34.08 ms |
| | scroll_1000 | 76.58 ms |
| **Layout Only** | flex_d5 | 123.59 µs |
| | grid_10x10 | 106.31 µs |
| | dashboard | 104.32 µs |
| | large_2k5 | 1.15 ms |
| **Paint Tree** | flat_100 | 5.53 µs |
| | dashboard | 4.62 µs |
| | large_2k5 | 30.66 µs |
| **Viewport Culling** | top | 5.22 µs |
| | middle | 0.01 µs |
| **Incremental Layout** | cached | 5.87 µs |
| | single_dirty | 26.84 µs |
| | full | 21.76 µs |

## Bottleneck Analysis

### Render Pipeline Breakdown (large_2k5)
- Parse: 404 µs
- Layout only: 1.15 ms
- Full render: 9.56 ms
- **Gap: ~8 ms** = CSS cascade/selector matching/style computation

### Key Observations

1. **CSS Processing is the biggest bottleneck**
   - Parse + Layout = ~1.5 ms
   - Full render = 9.56 ms
   - ~85% of time is CSS processing

2. **Nested Flexbox scales exponentially**
   - flex_d4: 718 µs
   - flex_d5: 2.52 ms (3.5x)
   - flex_d6: 7.94 ms (3.1x)

3. **Large scrollable lists are very slow**
   - scroll_200: 13.92 ms
   - scroll_500: 34.08 ms (2.4x)
   - scroll_1000: 76.58 ms (2.2x)

4. **Viewport culling is extremely fast**
   - Most nodes culled: 0.01 µs
   - Very efficient for scroll rendering

5. **Incremental layout cache is effective**
   - Cached: 5.87 µs vs Full: 21.76 µs (3.7x faster)

## Optimization Priorities

1. **CSS Cascade/Selector Matching** - Highest impact
2. **Style Computation** - Part of CSS pipeline
3. **Nested Flexbox Layout** - Exponential scaling
4. **HTML Parser** - Large documents

## Run Command
```bash
moon bench -p bench
```

---

# Optimization Results (2025-01-12)

## Direct Property Application Optimization

### Problem
`apply_css_property_with_viewport` was creating a CSS string (`property + ": " + value`) and parsing it for each property application, causing significant overhead.

### Solution
Added `apply_property_direct` function that directly applies CSS properties to existing styles without string parsing.

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| **Render (Full)** | | | |
| flat_100 | 422.73 µs | 309.41 µs | **-27%** |
| flat_1000 | 5.14 ms | 4.38 ms | **-15%** |
| flex_d5 | 2.52 ms | 1.84 ms | **-27%** |
| flex_d6 | 7.94 ms | 5.51 ms | **-31%** |
| grid_10x10 | 508.73 µs | 386.19 µs | **-24%** |
| cards_24 | 1.29 ms | 1.01 ms | **-22%** |
| dashboard_med | 1.22 ms | 937.60 µs | **-23%** |
| large_2k5 | 9.56 ms | 7.92 ms | **-17%** |
| large_5k | 21.27 ms | 20.33 ms | **-4%** |
| scroll_500 | 34.08 ms | 22.63 ms | **-34%** |
| scroll_1000 | 76.58 ms | 45.47 ms | **-41%** |

### Pipeline Phase Analysis (100 elements)

| Phase | Before | After | Improvement |
|-------|--------|-------|-------------|
| Parse only | 35.65 µs | 36.85 µs | ~same |
| Style computation | 337 µs | 241 µs | **-28%** |
| Layout only | 37.12 µs | 38.86 µs | ~same |
| Full render | 432.00 µs | 311.07 µs | **-28%** |

### Key Findings

1. **Style computation was 78% of render time** - now reduced to ~70%
2. **Scroll rendering improved most** - 34-41% faster
3. **Nested flexbox improved significantly** - 27-31% faster
4. **Very large layouts see smaller gains** - dominated by layout computation

### Files Changed
- `css/computed/compute.mbt`: Added `StyleBuilder::from_style` and `apply_property_direct`
- `renderer/renderer.mbt`: Updated `apply_css_property` and `apply_css_property_with_viewport` to use direct application
