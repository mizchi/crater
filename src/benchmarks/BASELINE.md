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

---

## Large Layout Split And Grid Block Height Fast Path (2026-03-10)

### Problem
`layout_only_large` を shell / section header / cards に分解すると、grid shell 自体は軽く、card subtree の intrinsic height 計算が支配的だった。`grid.calculate_item_intrinsic_sizes()` は `display:block` item の auto height で `@block.compute()` を 2 回呼んでおり、skeleton card のような単純 block flow でも full block layout を踏んでいた。

### Benchmark Split

| Benchmark | Time |
|-----------|------|
| `layout_only_large_shell` | 69.16 µs |
| `layout_only_large_headers` | 205.07 µs |
| `layout_only_large_simple_cards` | 834.75 µs |
| `layout_only_large` | 67.20 ms |

`simple_cards` が 1ms 未満なので、重いのは grid placement ではなく card subtree の中身。

### Solution
- `benchmarks/render_bench.mbt`
  - `layout_only_large_shell`
  - `layout_only_large_headers`
  - `layout_only_large_simple_cards`
  - `layout_only_scroll_1k`
- `layout/grid/grid.mbt`
  - 単純な static block flow に限定して intrinsic height fast path を追加
  - inline / replaced / `%height` / non-static / non-block-or-flex descendants は対象外にして full block layout へ fallback
- `layout/grid/grid_test.mbt`
  - card-like grid item の intrinsic height 回帰 test を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `layout_only_large` | 67.20 ms | 34.21 ms | **-49.1%** |
| `layout_only_large_simple_cards` | 834.75 µs | 727.87 µs | **-12.8%** |
| `layout_only_large_headers` | 205.07 µs | 187.70 µs | -8.5% |
| `layout_only_large_shell` | 69.16 µs | 68.00 µs | ~same |

### Notes

- `css-grid` のうち `grid-in-table-cell-with-img.html`, `grid-item-percentage-quirk-001.html`, `grid-item-percentage-quirk-002.html` は、`b7c3908` の clean worktree でも同じ失敗を再現したので今回の変更による regression ではない。
- `layout_only_scroll_1k` は今回の最適化対象外で run-to-run variance もあるため、比較指標には使わず現値 `29.87 ms` を baseline として記録する。

---

## Large Layout Card Body Width Fast Path (2026-03-10)

### Problem
height 側を落とした後も、`layout_only_large_card_body` が `33.27 ms` と重く、残りの大半が block item の intrinsic width 計算に残っていた。`grid.calculate_item_intrinsic_sizes()` の block width 分岐は、単純な static block flow でも `@block.compute()` を min/max の 2 回呼んでいた。

### Solution
- `benchmarks/render_bench.mbt`
  - `layout_only_large_card_body` を追加
- `layout/grid/grid.mbt`
  - 単純な static block flow に限定した intrinsic width fast path を追加
  - descendant は `block` / `flex` のみ許可
  - replaced / abspos / float / vertical writing-mode は full block layout に fallback
- `layout/grid/grid_test.mbt`
  - `grid_fit_content_block_item_with_flex_child_uses_intrinsic_width`

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `layout_only_large` | 35.39 ms | 7.64 ms | **-78.4%** |
| `layout_only_large_card_body` | 33.27 ms | 6.89 ms | **-79.3%** |
| `layout_only_large_simple_cards` | 910.27 µs | 638.93 µs | **-29.8%** |
| `layout_only_large_shell` | 68.23 µs | 57.89 µs | -15.2% |

### Notes

- `layout_only_large` と `layout_only_large_card_body` がほぼ同じ水準まで落ちたので、large layout の支配コストだった card body intrinsic width は大きく削れた。
- `css-grid` の結果は引き続き `30 / 33` で、既知の 3 failure は変化なし。

---

## Flex Footer Intrinsic Height Fast Path (2026-03-10)

### Problem
width 側を落とした後も、`layout_only_large_card_footer_body` が `9.96 ms` と依然重かった。`grid` の block fast path から辿る flex child 高さ計算で、単純な row footer に対して `@flex.compute()` を min/max の 2 回呼んでいた。

### Solution
- `benchmarks/render_bench.mbt`
  - `layout_only_large_card_text_body`
  - `layout_only_large_card_footer_body`
- `layout/grid/grid.mbt`
  - 単純な `nowrap` row flex に限定した intrinsic height fast path を追加
  - baseline alignment / non-static / float / vertical writing-mode は fallback
- `layout/grid/grid_test.mbt`
  - `grid_auto_row_block_item_with_simple_flex_child_keeps_intrinsic_height`

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `render_large_2k5` | 40.45 ms | 23.19 ms | **-42.7%** |
| `layout_only_large` | 15.13 ms | 5.65 ms | **-62.7%** |
| `layout_only_large_card_body` | 10.27 ms | 4.61 ms | **-55.1%** |
| `layout_only_large_card_text_body` | 4.25 ms | 2.78 ms | **-34.6%** |
| `layout_only_large_card_footer_body` | 9.96 ms | 3.41 ms | **-65.8%** |
| `pipeline_current` | 1.05 ms | 470.67 µs | **-55.2%** |

### Notes

- `card_footer_body` が `9.96 ms -> 3.41 ms` まで落ちたので、footer flex intrinsic 高さは大きく削れた。
- 現在は `card_text_body 2.78 ms` と `card_footer_body 3.41 ms` が近く、残りの card body コストは text/block 側と footer 側に大きく偏っていない。
- `css-grid` は引き続き `30 / 33` で既知の 3 failure のみ。

---

## Renderer Inline Style Cache For Repeated Trees (2026-03-10)

### Problem
`layout_only_large` はかなり落ちた一方で、full render の large case では node tree 構築と inline style 適用のコストがまだ残っていた。`large_website(...)` は同じ inline style を大量に繰り返すので、stylesheet なし・既定継承だけのケースでは毎回同じ computed style を作り直していた。

### Solution
- `renderer/renderer.mbt`
  - stylesheet cascade が無い
  - CSS variable が空
  - 継承コンテキストが既定値
  - root/viewport/tag/inline css が同じ
  という保守的な条件に限って inline-only computed style cache を追加
- `renderer/renderer_test.mbt`
  - 継承 `font-size` が異なる場合に cache を誤再利用しない回帰 test を追加
- `benchmarks/render_bench.mbt`
  - `node_only_large_2k5` benchmark を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `render_large_2k5` | 23.19 ms | 15.39 ms | **-33.6%** |
| `node_only_large_2k5` | - | 7.03 ms | new |
| `render_large_1k` | - | 5.21 ms | snapshot |
| `render_large_5k` | - | 42.29 ms | snapshot |

### Notes

- `render_large_2k5` は variance が大きく、別 run では `13.30 ms .. 52.27 ms` まで振れた。large full-render の継続監視は `node_only_large_2k5` を主指標にする。
- `pipeline_current` は今回の変更で安定して改善したとは言い切れず、large repeated tree 専用の最適化として扱う。
- 回帰確認:
  - `repeated inline styles do not reuse default cache across inherited font sizes` は pass
  - `css-flexbox` は `289 / 289`
  - `css-grid` は `30 / 33` で既知の 3 failure のまま

---

## No-Stylesheet Selector Fast Path (2026-03-10)

### Problem
large inline-only tree では stylesheet が 0 件でも、renderer は各 element について selector metadata をフル構築し、`style` 属性まで selector 側に積んでいた。さらに pseudo / counter 解決も毎回空振りで呼んでいたため、`node_only_large_2k5` に無駄な前処理が残っていた。

### Solution
- `renderer/renderer.mbt`
  - stylesheet が空のときは minimal selector を使う
  - id / class / attribute の selector metadata を構築しない
  - pseudo / counter 解決を丸ごと skip する
  - `collect_inline_content()` の generated pseudo 判定でも selector 構築を避ける
- `benchmarks/render_bench.mbt`
  - `node_build_large_2k5` を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `render_large_2k5` | 15.39 ms | 12.60 ms | **-18.1%** |
| `node_only_large_2k5` | 7.03 ms | 5.21 ms | **-25.9%** |
| `parse_large_2k5` | - | 1.17 ms | snapshot |
| `node_build_large_2k5` | - | 6.44 ms | new |

### Notes

- `node_build_large_2k5` は cache warm-up 影響で variance が大きく、`3.95 ms .. 11.29 ms` に振れた。継続監視は引き続き `node_only_large_2k5` を主指標にする。
- `parse_large_2k5` が `1.17 ms` なので、`node_only_large_2k5` の残りは主に style/node build 側にある。
- 回帰確認:
  - `render_to_node applies margin-trim from stylesheet` は pass
  - `repeated inline styles do not reuse default cache across inherited font sizes` は pass
  - `css-flexbox` は `289 / 289`
  - `css-grid` は `30 / 33` で既知の 3 failure のまま

---

## No-Stylesheet Counter And Owner Bookkeeping Elision (2026-03-10)

### Problem
minimal selector fast path を入れた後も、no-stylesheet tree では child traversal ごとに counter map copy、`owner_id` 文字列連結、sibling count 集計が残っていた。inline-only tree では counters/pseudo を使わないので、この bookkeeping はほぼ無意味だった。

### Solution
- `renderer/renderer.mbt`
  - stylesheet が空のときは counter state copy をしない
  - `owner_id + "/n"` の連結をしない
  - child sibling count 集計を skip
  - child selector は parent だけ持つ minimal form に寄せる
  - `has_display_contents()` でも cached display 判定を使う

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `node_build_large_2k5` | 6.44 ms | 3.01 ms | **-53.3%** |
| `node_only_large_2k5` | 5.21 ms | 5.16 ms | ~same (variance large) |
| `render_large_2k5` | 12.60 ms | 14.89 ms | variance |

### Notes

- `node_build_large_2k5` は `2.64 ms .. 3.50 ms` と比較的安定して改善した。
- `node_only_large_2k5` と `render_large_2k5` は cache warm-up と run variance が大きく、今回の評価主指標には使っていない。
- 回帰確認:
  - `repeated inline styles do not reuse default cache across inherited font sizes` は pass
  - `render_to_node applies margin-trim from stylesheet` は pass
  - `css-flexbox` は `289 / 289`
  - `css-grid` は `30 / 33` で既知の 3 failure のまま

---

## Simple Block Stack Layout Fast Path (2026-03-10)

### Problem
`layout_only_large_card_text_body` は card 内の `padding:12px` wrapper と単一 child wrapper が大量に並ぶ構造なのに、毎回 general block-flow path を通っていた。float, abs, multicol, inline run, `layout_map` などの bookkeeping が不要なケースでも同じ処理を踏むため、text/body 側の layout cost が残っていた。

### Solution
- `layout/block/block.mbt`
  - horizontal + definite sizing
  - in-flow static block/flow-root child のみ
  - auto margin / special `justify-self` / float / abs/fixed / multicol / mixed inline なし
  - parent が `padding` or `border` を持つ、または single-child wrapper
  の場合だけ simple block-stack path を追加
  - margin collapse の挙動は維持しつつ、`layout_map` と out-of-flow bookkeeping を通さずに child を直列配置する
- `layout/block/block_test.mbt`
  - `block_card_like_nested_body_stacks_simple_block_children` を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `layout_only_large_card_text_body` | 1.69 ms | 1.17 ms | **-30.8%** |
| `layout_only_large` | 5.65 ms | 2.40 ms | **-57.5%** |
| `render_large_2k5` | - | 6.25 ms | snapshot |

### Notes

- full render は renderer 側 cache の warm/cold で振れやすいので、今回の主指標は `layout_only_large_card_text_body` と `layout_only_large` に置く。
- `moon test src/layout/block/block_test.mbt --target js` の 7 failure は今回の回帰ではなく、`71eefab` の clean worktree でも同じ結果を確認済み。
- 回帰確認:
  - `block_card_like_nested_body_stacks_simple_block_children` は pass
  - `css-flexbox` は `289 / 289`
  - `css-grid` は `30 / 33` で既知の 3 failure のまま

---

## Simple Row Space-Between Fixed-Leaf Flex Fast Path (2026-03-10)

### Problem
`layout_only_large_card_footer_body` の footer は `display:flex; justify-content:space-between` で、direct child は固定サイズの leaf 2 個だけだった。それでも通常の flex item 構築、line 計算、space distribution を毎回フルで通るため、footer 側の cost がまだ残っていた。

### Solution
- `/Users/mz/ghq/github.com/mizchi/crater/src/layout/flex/flex.mbt`
  - `row + nowrap + space-between + direct fixed-size leaf children + zero margin/padding/border`
    に限定した narrow fast path を追加
  - `display: contents` 展開、flex-grow、order、auto margin、baseline などが入る場合は従来 path に fallback
- `/Users/mz/ghq/github.com/mizchi/crater/src/layout/flex/flex_test.mbt`
  - `flex_row_space_between_fixed_leaf_children_fast_path_shape` を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `layout_only_large_card_footer_body` | 1.53 ms | 1.28 ms | **-16.3%** |
| `layout_only_large` | 2.40 ms | 2.39 ms | ~same |
| `render_large_2k5` | 6.25 ms | 5.53 ms | **-11.5%** |

### Notes

- footer 単体には明確に効いたが、`layout_only_large` 全体では text/body 側がまだ支配的なので改善幅は小さい。
- 回帰確認:
  - `flex_row_space_between_fixed_leaf_children_fast_path_shape` は pass
  - `flex_justify_space_between` は pass
  - `css-flexbox` は `289 / 289`
  - `css-grid` は `30 / 33` で既知の 3 failure のまま

---

## Empty Block Leaf Fixed-Height Fast Path (2026-03-10)

### Problem
`layout_only_large_card_text_body` の card body には、`children: []` で `height` が確定している block leaf が大量に並ぶ。`compute_nested()` には leaf fast path がある一方、通常の block layout 本体では measure 付き leaf しか早期 return しておらず、空の block leaf でも一般の block-flow 処理まで入っていた。

### Solution
- `/Users/mz/ghq/github.com/mizchi/crater/src/layout/block/block.mbt`
  - `empty static block/flow-root + definite height + no min/max + no auto margin`
    に限定した narrow fast path を追加
  - `width` は `auto | length | percent` のみ許可し、`padding` / `border` / `box-sizing` を反映
  - `aspect-ratio`、containment、vertical writing、measure/text leaf、複雑な constraint は従来 path に fallback
- `/Users/mz/ghq/github.com/mizchi/crater/src/layout/block/block_test.mbt`
  - `block_leaf_fixed_height_percent_width_keeps_box_model` を追加

### Results Comparison

| Benchmark | Before | After | Improvement |
|-----------|--------|-------|-------------|
| `layout_only_large_card_text_body` | 1.33 ms | 957.15 µs | **-28.0%** |
| `layout_only_large_card_body` | 1.93 ms | 1.56 ms | **-19.2%** |
| `layout_only_large_card_footer_body` | 1.23 ms | 1.22 ms | ~same |
| `layout_only_large` | 2.15 ms | 2.15 ms | variance |

### Notes

- `text_body` には明確に効いたが、`layout_only_large` 全体では grid shell や他 subtree の揺れに埋もれて横ばいに見える。
- 一度試した broad leaf fast path は `footer_body` を悪化させたため不採用にし、この narrow 版だけを残した。
- 回帰確認:
  - `block_leaf_fixed_height_percent_width_keeps_box_model` は pass
  - `block_card_like_nested_body_stacks_simple_block_children` は pass
  - `css-flexbox` は `289 / 289`
  - `css-grid` は `30 / 33` で既知の 3 failure のまま
