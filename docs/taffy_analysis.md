# Taffy Implementation Analysis

## 概要

Taffy (Rust) のレイアウトエンジン実装を分析し、crater への移植状況を追跡する。

## 現在のテスト状況 (2024-12-31)

### パッケージ別テスト結果

| パッケージ | 生成 | 手動 | 合計 | パス | パス率 |
|-----------|------|------|------|------|--------|
| Grid | 297 | 32 | 329 | 241 | **73.3%** |
| Flex | 479 | 70 | 549 | 158 | 28.8% |
| Block | 132 | 27 | 159 | 74 | 46.5% |
| **合計** | **908** | **129** | **1037** | **473** | **45.6%** |

### Taffy フィクスチャ移植状況

| ディレクトリ | HTML | 生成済み | スキップ | 理由 |
|-------------|------|---------|---------|------|
| grid | 259 | 256 | 0 | ✅ absolute 実装済み |
| blockgrid | 14 | 14 | 0 | - |
| blockflex | 7 | 7 | 0 | - |
| gridflex | 6 | 6 | 0 | - |
| leaf | 14 | 14 | 0 | - |
| flex | 537 | 479 | 58 | absolute positioning |
| block | 196 | 132 | 64 | absolute positioning |
| **合計** | **1033** | **908** | **122** | - |

## 未移植・未実装機能

### 1. Absolute Positioning (Grid 実装済み、Flex/Block 未実装)

Grid では `position: absolute` を実装済み。Flex と Block は未対応。

**Grid での実装内容:**
- [x] `position: absolute` のレイアウト計算
- [x] `inset` (top/right/bottom/left) の解決
- [x] containing block の決定（padding box）
- [x] grid-column/grid-row による grid area の指定
- [x] margin の適用
- [ ] align-self/justify-self（absolute アイテム）
- [ ] aspect ratio（absolute アイテム）

**未実装パッケージ:**
- flex: 58 テスト
- block: 64 テスト

### 2. Flex レイアウト改善 (パス率 28.8%)

Flex のパス率が低い。主な失敗カテゴリ:
- flex-grow/flex-shrink の計算
- flex-basis の解決
- align-items/align-self の処理
- flex-wrap の処理

### 3. Block レイアウト改善 (パス率 46.5%)

Block の失敗カテゴリ:
- margin collapsing (マージン折りたたみ)
- intrinsic sizing
- min/max 制約

## Grid 実装の詳細

### 最新の改善 (2024-12)

- **3-pass auto-placement アルゴリズム実装**
  - Pass 1: 明示的な Line 配置からグリッド境界を決定
  - Pass 2: 完全に明示的なアイテム (row/column 両方が Line) を配置
  - Pass 3: 残りのアイテムを auto-placement (semi-explicit 含む)
- negative_space_gap テスト修正
- percent tracks in indefinite containers 修正
- total track count for negative placements 修正

### 実装済み機能

- [x] 基本的な Grid レイアウト
- [x] トラックサイズ計算
- [x] Fr トラック (definite/indefinite)
- [x] Span アイテムの intrinsic sizing
- [x] Min/max 制約の適用
- [x] テキストコンテンツの measure
- [x] fit-content サポート
- [x] justify_items/justify_self
- [x] overflow 処理 (基本)
- [x] 3-pass auto-placement (negative placement 対応)
- [x] **Absolute positioning** (inset, margin, grid-column/row)

### 未実装機能

- [ ] Absolute + align-self/justify-self
- [ ] Absolute + aspect ratio
- [ ] overflow + spanning items 相互作用
- [ ] Automatic minimum size (CSS Grid spec 完全対応)
- [ ] AvailableSpace (MinContent/MaxContent)
- [ ] Baseline alignment

### Grid 失敗テスト分類

| カテゴリ | 件数 | 説明 | 優先度 |
|---------|------|------|--------|
| overflow + spanning | 7 | span アイテムの overflow:hidden | Medium |
| nested grid intrinsic | 8 | 入れ子グリッドの intrinsic sizing | High |
| percent in indefinite | 5 | indefinite での percent 解決 | High |
| auto_margins | 3 | auto margin と alignment | Medium |
| fit_content edge cases | 4 | fit-content(percent) | Low |
| baseline alignment | 4 | baseline + margin/padding | Low |
| aspect_ratio | 4 | グリッドでの aspect ratio | Low |

## テスト生成ツール

### 使用方法

```bash
# HTML → JSON フィクスチャ生成
npm run gentest -- --batch taffy/test_fixtures/grid fixtures/grid

# JSON → MoonBit テスト生成
npm run gen-moonbit-tests -- fixtures/grid grid/gen_test.mbt

# オプション
--flex       # flex/block 用の compute 関数を使用
--no-header  # 追加テストファイル用 (assert_approx をスキップ)
```

### 生成されるファイル

```
grid/gen_test.mbt          # メイン grid テスト (227)
grid/gen_blockgrid_test.mbt # block + grid (14)
grid/gen_blockflex_test.mbt # block + flex (7)
grid/gen_gridflex_test.mbt  # grid + flex (6)
grid/gen_leaf_test.mbt      # leaf ノード (14)
flex/gen_test.mbt          # flex テスト (479)
block/gen_test.mbt         # block テスト (132)
```

## 推奨する実装順序

### Phase 1: 高優先度

1. **Absolute positioning サポート**
   - 151 テストがアンブロックされる
   - 全パッケージに影響

2. **Flex レイアウト改善**
   - flex-grow/shrink の計算修正
   - パス率向上の余地が大きい

### Phase 2: 中優先度

3. **Block margin collapsing**
   - CSS 仕様に準拠したマージン折りたたみ

4. **Grid overflow + spanning**
   - spanning items と overflow の相互作用

### Phase 3: 低優先度

5. Baseline alignment
6. Aspect ratio in grid
7. AvailableSpace 概念の導入

## ファイル構成 (Taffy 参考)

```
taffy/src/compute/
├── grid/
│   ├── mod.rs              - Grid レイアウトのエントリポイント
│   ├── track_sizing.rs     - トラックサイズ計算 (最重要)
│   ├── alignment.rs        - アライメント処理
│   ├── explicit_grid.rs    - 明示的グリッド
│   ├── implicit_grid.rs    - 暗黙的グリッド
│   ├── placement.rs        - アイテム配置
│   └── types/grid_item.rs  - GridItem と intrinsic size
├── flexbox/
│   └── mod.rs              - Flexbox レイアウト
└── block/
    └── mod.rs              - Block レイアウト
```

## 参考リンク

- CSS Grid spec: https://www.w3.org/TR/css-grid-1/
- CSS Flexbox spec: https://www.w3.org/TR/css-flexbox-1/
- Automatic minimum size: https://www.w3.org/TR/css-grid-1/#min-size-auto
- Taffy source: ./taffy/src/compute/
