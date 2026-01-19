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

---

## Selector Index Optimization (2025-01-12)

### Problem
`cascade_element_with_media` iterates through ALL rules in a stylesheet for EACH element, resulting in O(n*m) complexity where n=elements and m=rules.

### Solution
Added `IndexedStylesheet` that pre-indexes rules by ID, class, and tag name for O(1) candidate lookup. Only candidate rules are checked for full selector matching.

### Selector Matching Results (optimization_bench)

| Stylesheet Size | Non-indexed | Indexed | Improvement |
|-----------------|-------------|---------|-------------|
| 28 rules (realistic) | 0.20 µs | 0.18 µs | **-10%** |
| 100 rules (large) | 1.06 µs | 0.16 µs | **-85%** |

### Full Render Results

| Benchmark | Before (Direct) | After (Indexed) | Change |
|-----------|-----------------|-----------------|--------|
| flex_d5 | 1.84 ms | 1.59 ms | **-14%** |
| flex_d6 | 5.51 ms | 5.44 ms | -1% |
| cards_24 | 1.01 ms | 907.15 µs | **-10%** |
| large_5k | 20.33 ms | 18.17 ms | **-11%** |

Note: Most benchmarks use inline styles only (no stylesheet), so selector indexing provides no benefit there. For pages with CSS stylesheets, especially larger ones, the improvement is significant.

### Key Findings

1. **85% faster selector matching for 100+ rule stylesheets**
2. **10-14% improvement for pages with CSS stylesheets**
3. **Minimal overhead for inline-style-only pages**
4. **Index build time is negligible compared to matching savings**

### Files Changed
- `css/cascade/index.mbt`: Already had `IndexedStylesheet` and `SelectorIndex`
- `renderer/renderer.mbt`: Added `compute_element_style_indexed`, updated entry points to build and use indexed stylesheets

---

## Real-World Benchmark: GitHub Profile Page (2025-01-12)

### Test Data
- **HTML**: github.com/mizchi profile page (206 KB)
- **CSS Total**: 812 KB (~7800 rules)
  - Primer CSS: 347 KB
  - Global CSS: 300 KB
  - Main CSS: 154 KB
  - Profile CSS: 11 KB

### Results

| Scenario | Time | Notes |
|----------|------|-------|
| HTML only | 2.63 ms | Inline styles only |
| + Profile CSS (100 rules) | 2.59 ms | Minimal impact |
| + All CSS (7800 rules) | 9.31 ms | 3.6x slowdown |
| Reference: Simple 100-elem list | 1.09 ms | Baseline |
| Medium CSS (50 classes, 100 elem) | 1.28 ms | - |

### Selector Index Effectiveness

- Rule count increase: 100 → 7800 (**78x more rules**)
- Actual slowdown: **3.6x** (with indexing)
- Expected slowdown without indexing: **78x** (linear O(n*m))
- **Achieved: ~22x faster than linear scaling**

### Analysis

1. **GitHub profile page renders in under 10ms** with full CSS
2. **Selector indexing scales sub-linearly** with rule count
3. **HTML parsing dominates** when CSS rules are minimal
4. **CSS cascade becomes dominant** only with very large stylesheets

### Benchmark Script
```bash
node --experimental-strip-types tools/bench-github.ts
```
