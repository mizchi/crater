# Taffy Grid Implementation Analysis

## 概要

Taffy (Rust) の Grid 実装を分析し、crater の実装との差異を特定した。

## 現在のテスト状況

**199/259 passed (76.8%)**

(注: gen_test.mbt 再生成により総テスト数が 368 → 259 に変更された)

### 最新の改善 (2024-12):
- negative_space_gap テスト4件修正
  - apply_content_alignment で free_space <= 0 時の早期リターンを削除
  - Center/End アライメントは負のオフセットを許可
- Fix percent tracks in indefinite containers (minmax cases) テスト3件修正
  - size_is_definite パラメータを追加し、indefinite 時に percent を auto として扱う
- Fix total track count for negative placements
  - 負の配置がある場合の total_column/row_count 計算を修正

### 前回までの改善:
- IntrinsicSize::default() を {0, 0, 0, 0} に変更
- テキストコンテンツの measure 抽出を gentest.ts に実装
- fit-content サポート追加
- spanning item の分配ロジック改善 (MaxContent > Auto > Fr)
- Fr トラックの比率計算改善 (hypothetical fr unit)
- 0fr トラックの処理修正
- justify_items/justify_self サポート追加
- overflow プロパティ追加 (overflow:hidden で minimum contribution = 0)

## 残り60件の失敗テスト分類

### 1. 完了済み

| カテゴリ | 件数 | 説明 | 状態 |
|---------|------|------|------|
| negative_space_gap | 4 | トラックがコンテナに収まらない時の gap 処理 | ✅ 修正済 |
| percent in indefinite (minmax) | 3 | indefinite container での minmax percent | ✅ 修正済 |

### 2. 根本的な変更が必要なもの (High Complexity)

| カテゴリ | 件数 | 説明 | 必要な対応 |
|---------|------|------|----------|
| placement_negative | 5+ | 負のライン番号での配置 (grid_placement_auto_negative, grid_auto_rows, grid_auto_columns など) | **2パス auto-placement アルゴリズム**: 明示的配置を先に処理してグリッド境界を決定し、次に auto-placement を暗黙トラックも含めた座標系で実行する必要がある |
| percent_tracks_indefinite_overflow | 2 | indefinite container での percent + overflow 相互作用 | 2パス計算: container サイズ確定後に percent トラックを再計算 |

### 3. 単純に対応すれば良いもの (Low Priority)

以下は影響範囲が限定的で、単独で修正可能:

| カテゴリ | 件数 | 説明 | 対応方法 |
|---------|------|------|----------|
| grid_repeat_mixed | 1 | repeat() の混合パターン | repeat 展開ロジック確認 |

### 4. 中程度の複雑さ (Medium Priority)

他のテストに影響する可能性があるが、比較的isolated:

| カテゴリ | 件数 | 説明 | 対応方法 |
|---------|------|------|----------|
| auto_margins | 3 | auto margin と alignment の相互作用 | apply_alignment でのマージン処理改善 |
| placement_negative | 3 | 負のライン番号での配置 | resolve_line_placement の負の値処理確認 |
| fit_content edge cases | 4 | fit-content(percent) in indefinite | percent 値の解決ロジック |
| grid_auto_* | 2 | 暗黙的トラック関連 | auto track sizing 確認 |

### 3. 依存関係があるもの (High Priority - 先に実装すべき)

これらを先に修正すると、他のテストも改善される可能性が高い:

#### 3.1 overflow + spanning items の相互作用 (7テストに影響)

overflow 基本処理は実装済みだが、spanning items との相互作用が複雑:

```
grid_span_2_*_hidden (4件)
grid_span_6_*_hidden (1件)
grid_span_13_*_hidden (1件)
grid_fit_content_*_hidden (1件)
```

**問題点:**
- 複数トラックをspan するアイテムのoverflow:hidden処理
- min-content トラックと auto トラックへの分配方法

#### 3.2 入れ子グリッドの intrinsic sizing (8テストに影響)

```
grid_max_width_* (3件)
grid_percent_items_nested_* (4件)
grid_percent_items_width_and_margin (1件)
```

**対応方法:**
1. 入れ子グリッドの max-width/min-width 制約を正しく適用
2. 再帰的な intrinsic sizing 計算の修正

#### 3.3 percent in indefinite containers (5テストに影響)

```
grid_minmax_*_percent_indefinite (3件)
grid_percent_tracks_indefinite_* (2件)
```

**対応方法:**
1. indefinite container での percent 解決を 0 として扱う
2. CSS spec に従った処理

### 4. 複雑で後回しにすべきもの (Low Priority)

影響範囲が大きいか、特殊なユースケース:

| カテゴリ | 件数 | 説明 | 理由 |
|---------|------|------|------|
| baseline alignment | 4 | baseline + margin/padding | 複雑で使用頻度低 |
| aspect_ratio in grid | 4 | グリッドでの aspect ratio | 相互作用が複雑 |
| min_content_flex | 6 | flex 子要素の min-content | flex レイアウト依存 |
| available_space | 2 | 利用可能スペースの制約 | 根本的な設計見直し必要 |
| fr edge cases | 2 | fr トラックのエッジケース | 調査必要 |
| span distribution | 3 | spanning の複雑なケース | 調査必要 |
| overflow_* | 2 | overflow の追加ケース | 調査必要 |

## 推奨する実装順序

### Phase 1: 依存関係の解決 (高優先度)

1. **percent in indefinite の修正**
   - compute_track_sizes で indefinite + percent の処理

2. **入れ子グリッドの intrinsic sizing 改善**
   - 再帰計算での max-width/min-width 制約適用

### Phase 2: 中程度の修正

3. **auto margins の改善**
   - apply_alignment でのマージン計算修正

4. **fit-content edge cases**
   - fit-content(percent) in indefinite

### Phase 3: 単純な修正

5. **negative_space_gap**
6. **placement 修正** (負のライン番号)
7. **repeat_mixed** ロジック修正

### Phase 4: 後回し

8. baseline alignment
9. aspect_ratio
10. min_content_flex
11. spanning + overflow 相互作用の完全対応

## ファイル構成 (参考)

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

## 核心的な差異 (詳細)

### 1. Automatic Minimum Size

**Taffy (grid_item.rs:459-528):**
```rust
pub fn minimum_contribution(...) -> f32 {
    // overflow が visible でない場合は 0
    if overflow != Overflow::Visible {
        return 0.0;
    }

    // spans_auto_min_track かつ flexible track がなければ min-content
    let use_content_based_minimum =
        spans_auto_min_track && (only_span_one_track || !spans_a_flexible_track);

    if use_content_based_minimum {
        self.min_content_contribution_cached(...)
    } else {
        0.0
    }
}
```

### 2. Intrinsic Size Contribution

**Taffy:**
- `min_content_contribution`: AvailableSpace::MinContent で measure
- `max_content_contribution`: AvailableSpace::MaxContent で measure
- キャッシュ機構あり

**Crater:**
- calculate_item_intrinsic_sizes で計算
- AvailableSpace の概念がない (将来的に追加検討)

## 現在の実装状況

- [x] 基本的な Grid レイアウト
- [x] トラックサイズ計算
- [x] Fr トラック (definite/indefinite)
- [x] Span アイテムの intrinsic sizing
- [x] Min/max 制約の適用
- [x] テキストコンテンツの measure
- [x] fit-content サポート
- [x] justify_items/justify_self
- [x] overflow 処理 (基本)
- [ ] overflow + spanning items 相互作用
- [ ] Automatic minimum size (CSS Grid spec完全対応)
- [ ] AvailableSpace (MinContent/MaxContent)
- [ ] Baseline alignment (部分的)

## 参考リンク

- CSS Grid spec: https://www.w3.org/TR/css-grid-1/
- Automatic minimum size: https://www.w3.org/TR/css-grid-1/#min-size-auto
- Taffy source: ./taffy/src/compute/grid/
