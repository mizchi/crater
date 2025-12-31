# Taffy Grid Implementation Analysis

## 概要

Taffy (Rust) の Grid 実装を分析し、crater の実装との差異を特定した。

## ファイル構成

```
taffy/src/compute/grid/
├── mod.rs              - Grid レイアウトのメインエントリポイント
├── track_sizing.rs     - トラックサイズ計算 (68KB) - 最も重要
├── alignment.rs        - アライメント処理
├── explicit_grid.rs    - 明示的グリッドの処理
├── implicit_grid.rs    - 暗黙的グリッドの処理
├── placement.rs        - アイテム配置
└── types/
    └── grid_item.rs    - GridItem 構造体と intrinsic size 計算
```

## 核心的な差異

### 1. Measure Function のデフォルト値

**Taffy:**
```rust
// taffy/src/tree/taffy_tree.rs:923
self.compute_layout_with_measure(node, available_space, |_, _, _, _, _| Size::ZERO)
```

measure function がない場合、`Size::ZERO` を返す。

**Crater:**
```moonbit
// node/node.mbt
pub fn IntrinsicSize::default() -> IntrinsicSize {
  { min_width: 20.0, max_width: 40.0, min_height: 20.0, max_height: 40.0 }
}
```

これが多くのテスト不一致の原因。

### 2. テキストコンテンツの measure

Taffy テストフィクスチャでは、テキストを含む div がある:
```html
<!-- taffy/test_fixtures/grid/grid_span_2_max_content_auto_indefinite.html -->
<div style="grid-row: 1; grid-column: 1 / span 2;">HHHH&ZeroWidthSpace;HHHH</div>
```

Taffy はこのテキストを measure function で計測するが、crater の gentest.ts はテキストコンテンツを無視している。

### 3. minimum_contribution の計算

**Taffy (grid_item.rs:459-528):**
```rust
pub fn minimum_contribution(...) -> f32 {
    // 1. size/min_size を確認
    let size = self.size.get(axis).or_else(|| self.min_size.get(axis));

    // 2. Automatic minimum size の計算
    if size.is_none() {
        // - spans auto min track があるか
        // - flexible track がないか
        // - 条件に応じて content-based minimum か 0 を使う
        let use_content_based_minimum =
            spans_auto_min_track && (only_span_one_track || !spans_a_flexible_track);

        if use_content_based_minimum {
            self.min_content_contribution_cached(...)
        } else {
            0.0  // これが重要！
        }
    }
}
```

CSS Grid の「automatic minimum size」仕様に基づく複雑なロジック。crater にはこの実装がない。

### 4. Intrinsic Size Contribution

**Taffy:**
- `min_content_contribution`: AvailableSpace::MinContent で measure
- `max_content_contribution`: AvailableSpace::MaxContent で measure
- キャッシュ機構あり

**Crater:**
- calculate_item_intrinsic_sizes で計算
- AvailableSpace の概念がない
- キャッシュなし

## テスト失敗の分類

### IntrinsicSize::default() = {0, 0, 0, 0} の場合

241/322 passed (81 failed)

失敗の主な原因：
- テキストコンテンツを含む div の measure がない
- gentest.ts がテキストを無視している

### IntrinsicSize::default() = {20, 40, 20, 40} の場合

254/322 passed (68 failed)

失敗の主な原因：
- Taffy とのデフォルト値の差異
- 一部のテストが偶然通る（期待値が近い）

## 推奨する修正方針

### Phase 1: gentest.ts の改善

1. テキストコンテンツを検出
2. ブラウザで測定した intrinsic size を MeasureFunc として生成

```typescript
// 疑似コード
if (element.textContent.trim()) {
  const range = document.createRange();
  range.selectNodeContents(element);
  const rect = range.getBoundingClientRect();
  node.measure = { min_width: ..., max_width: rect.width, ... };
}
```

### Phase 2: minimum_contribution の実装

CSS Grid spec の automatic minimum size を実装:
1. overflow プロパティの確認
2. トラックタイプの確認 (auto, flexible)
3. 条件分岐による min-content または 0 の選択

### Phase 3: AvailableSpace の導入

```moonbit
enum AvailableSpace {
  Definite(Double)
  MinContent
  MaxContent
}
```

measure function にこの情報を渡し、min-content/max-content の計算を正確に行う。

## 現在の実装状況

- [x] 基本的な Grid レイアウト
- [x] トラックサイズ計算
- [x] Fr トラック (indefinite での処理)
- [x] Span アイテムの intrinsic sizing
- [x] Min/max 制約の適用
- [ ] Automatic minimum size (CSS Grid spec)
- [ ] テキストコンテンツの measure
- [ ] AvailableSpace (MinContent/MaxContent)
- [ ] Baseline alignment (部分的)

## 参考リンク

- CSS Grid spec: https://www.w3.org/TR/css-grid-1/
- Automatic minimum size: https://www.w3.org/TR/css-grid-1/#min-size-auto
- Taffy source: ./taffy/src/compute/grid/
