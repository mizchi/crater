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

## Regression Check (2026-02-28)

Compared current HEAD (`a14526d`) with pre-`display:contents` table fix commit (`1d6d0c1`)
using repeated `--release` runs and median values.

Command examples:
```bash
moon bench -p bench -f render_bench.mbt --release -i 4-8
moon bench -p bench -f render_bench.mbt --release -i 9-11
moon bench -p bench -f render_bench.mbt --release -i 22-24
```

| Benchmark | base median | current median | delta |
|-----------|-------------|----------------|-------|
| render_nest_50 | 400.51 µs | 398.87 µs | -0.4% |
| render_flex_row_50 | 510.71 µs | 511.79 µs | +0.2% |
| render_flex_col_100 | 1.25 ms | 1.27 ms | +1.6% |
| render_flex_wrap | 1.18 ms | 1.26 ms | +6.8% |
| render_flex_d5 | 4.57 ms | 4.84 ms | +5.9% |
| render_flex_d6 | 14.51 ms | 14.79 ms | +1.9% |
| render_table_30x6 | 2.30 ms | 2.20 ms | -4.3% |
| render_table_50x8 | 5.17 ms | 4.91 ms | -5.0% |

Conclusion: no high-confidence performance regression found in the current changes.

## Font Cascade Ordering Refactor (2026-03-10)

Measured on the same machine with immediate before/after `--release` runs.

Command:
```bash
moon bench -p benchmarks -f optimization_bench.mbt --target js --release
```

Context:
- `font` / `font-size` / `line-height` は source order を守る必要がある
- 直前の実装では各要素ごとに 3 要素配列を作って `sort_by` していた
- 今回は固定 3 スロットの手動選択に置き換えて、割り当てと sort を除去した

| Benchmark | before | after | delta |
|-----------|--------|-------|-------|
| apply_single | 1.51 µs | 1.36 µs | -9.9% |
| apply_multi_reuse | 4.80 µs | 4.05 µs | -15.6% |
| apply_multi_new | 5.52 µs | 5.12 µs | -7.2% |
| pipeline_current | 1.16 ms | 1.02 ms | -12.1% |

Notes:
- `pipeline_current` は stylesheet を含む end-to-end の小さい render benchmark で、今回の変更経路に近い
- `render_bench.mbt` の full render 系は run-to-run variance が大きく、この 1 回の比較では高信頼な差分を断言しにくい
- よって今回の改善確認は `optimization_bench.mbt` を主指標にする

## Direct Cascade Winner Update (2026-03-10)

Command:
```bash
moon bench -p benchmarks -f optimization_bench.mbt --target js --release
```

Context:
- 直前の `cascade()` は property ごとに `Array[Declaration]` を作ってから winner を再走査していた
- 今回は `result.values` に対して declaration を 1 回ずつ流し、既存 winner と直接比較して更新する形に変更した
- 目的は property grouping 用の中間配列を消すこと

| Benchmark | before | after | delta |
|-----------|--------|-------|-------|
| cascade_decl_200 | 14.34 µs | 12.74 µs | -11.2% |

Notes:
- `css-flexbox` WPT 全件はこの変更後も `289 / 289 passed`
- `pipeline_current` は run-to-run variance が大きく、この変更単体の影響判定には使っていない

## CascadedValues Direct Iteration (2026-03-10)

Command:
```bash
moon bench -p benchmarks -f optimization_bench.mbt --target js --release
```

Context:
- `compute()` / `compute_with_vars()` / renderer の残り property 適用で、`properties()` によるキー配列生成と `get()` / `get_value()` の二度引きが入っていた
- `CascadedValues::each()` を追加して declaration を直接流す形に変更した
- custom properties の収集と通常 property 適用の両方でこの経路を使う

| Benchmark | before | after | delta |
|-----------|--------|-------|-------|
| compute_with_vars_mixed | 16.28 µs | 11.47 µs | -29.5% |
| pipeline_current | 608.44 µs | 521.48 µs | -14.3% |

Notes:
- `css-flexbox` WPT 全件はこの変更後も `289 / 289 passed`
- `cascade_decl_200` は run-to-run variance が大きかったため、この改善の主指標には使っていない

## Direct Cascade Path (2026-03-10)

Commands:
```bash
moon bench -p benchmarks -f cascade_index_bench.mbt --target js --release
moon bench -p benchmarks -f optimization_bench.mbt --target js --release
```

Context:
- `cascade_element_with_media()` / `cascade_element_indexed()` が
  `match -> RuleMatch -> adjusted decl arrays -> cascade`
  の多段 alloc になっていた
- match した declaration をその場で winner 更新する経路に変えて、中間 `RuleMatch` / declaration 配列を外した

| Benchmark | before | after | delta |
|-----------|--------|-------|-------|
| cascade_non_idx | 1.09 ms | 766.59 µs | -29.7% |
| cascade_indexed | 1.50 ms | 1.23 ms | -18.0% |
| compute_with_vars_mixed | 13.24 µs | 11.34 µs | -14.4% |

Notes:
- `css-flexbox` WPT 全件はこの変更後も `289 / 289 passed`
- selector matching 単体よりも、cascade の中間配列削減に効いた

## Single-Key Selector Index (2026-03-10)

Commands:
```bash
moon bench -p benchmarks -f cascade_index_bench.mbt --target js --release
moon bench -p benchmarks -f optimization_bench.mbt --target js --release
```

Context:
- 直前の `SelectorIndex` は 1 rule を複数 bucket に入れていて、
  `get_candidates()` 側で `seen` map による dedupe が必要だった
- これを `ID > class > tag > universal` の single-key index に変更して、
  candidate 収集時の hash-based dedupe を削除した
- compound selector は最初の class 1 つを key にして recall を維持する

| Benchmark | before | after | delta |
|-----------|--------|-------|-------|
| match_indexed_100 | 6.82 µs | 3.77 µs | -44.7% |
| match_indexed_500 | 34.39 µs | 22.63 µs | -34.2% |
| match_indexed_1000 | 74.36 µs | 49.98 µs | -32.8% |
| cascade_indexed | 1.23 ms | 762.63 µs | -38.0% |
| match_idx_real | 0.64 µs | 0.38 µs | -40.6% |
| match_idx_100 | 0.69 µs | 0.35 µs | -49.3% |

Notes:
- `css-flexbox` WPT 全件はこの変更後も `289 / 289 passed`
- synthetic bench では indexed path が non-indexed にかなり近づき、1000-rule ではほぼ同等まで縮んだ

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

---

## Flex Layout Hot Path (2026-03-10)

### Problem
`scrollable_list()` の各行は `nowrap` な row flex だが、simple leaf の intrinsic 計算と baseline 計算が常に full path を通っていた。`align-items: center` の行でも baseline を前計算し、空 leaf box でも毎回詳細な intrinsic 分岐を踏んでいた。

### Solution
- `layout/flex/flex.mbt`
  - simple leaf box の max-content 計算を fast path 化
  - `make_flex_intrinsic_probe()` で style が変わらない場合は元の node を再利用
  - baseline は `align-items` / `align-self` が `baseline` の item にだけ計算
- `benchmarks/render_bench.mbt`
  - `layout_only_scroll_500` を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `layout_only_scroll_500` | 10.51 ms | 8.32 ms | **-20.8%** |
| `layout_only_large` | 52.19 ms | 40.63 ms | **-22.1%** |
| `render_scroll_500` | 141.79 ms | 103.24 ms | **-27.2%** |

Note: `render_scroll_500` は run-to-run variance が大きいので、評価の主指標は `layout_only_scroll_500` を使う。
