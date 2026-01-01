# Implementation Priority

失敗テストの分析に基づく実装優先度。実際の使用頻度と修正難易度を考慮。

## 現在のテスト状況 (2026-01-01 更新)

| Module | Passed | Failed | Total | Percentage | Note |
|--------|--------|--------|-------|------------|------|
| Block  | 204    | 19     | 223   | 91.5%      | |
| Flex   | 503    | 96     | 599   | 84.0%      | +7 from align fixes |
| Grid   | 251    | 78     | 329   | 76.3%      | |
| **Total** | **970** | **193** | **1163** | **83.4%** | Native target stable |

## 失敗テスト分析

### Flex (110 failures)

| Category | Count | Priority | Note |
|----------|-------|----------|------|
| align_* | 31 | P2 | baseline tests remaining |
| flex_* | 23 | P2 | flex-basis/min-content edge cases |
| bevy_* | 13 | P2 | 特定のエッジケース |
| percentage_* | 10 | P2 | indefinite container |
| padding_* | 8 | P2 | box-sizing edge cases |
| measure_* | 8 | P2 | MeasureFunc edge cases |
| intrinsic_* | 8 | P2 | main_size 計算 |
| multiline_* | 6 | P2 | min/max with wrap |
| justify_* | 6 | P2 | space distribution edge |
| gap_* | 6 | P3 | gap + wrap combination |
| aspect_* | 6 | P3 | aspect_ratio edge |

### Block (19 failures)

| Category | Count | Priority | Note |
|----------|-------|----------|------|
| margin_y_collapse | 8 | P3 | margin collapsing edge |
| baseline | 7 | P3 | align_baseline_child |
| text_align | 2 | P3 | text-align (未対応) |
| aspect_ratio | 1 | P3 | MeasureFunc edge case |
| absolute | 1 | P3 | resolved_insets |

### Grid (81 failures)

| Category | Count | Priority | Note |
|----------|-------|----------|------|
| grid_span | 9 | P2 | span calculation |
| grid_max/min | 13 | P2 | track sizing |
| grid_percent | 5 | P2 | percentage tracks |
| grid_fit-content | 4 | P2 | fit-content sizing |
| blockgrid/gridflex | 9 | P3 | nested layout |
| absolute | 4 | P2 | absolute in grid |

## 推奨: 次に取り組むべき項目

### 優先度 High (効果大)

1. **wrap container intrinsic cross size** - bevy_*, multiline_*, intrinsic_* に影響
   - **根本原因特定済み**: `compute_intrinsic_flex_main_size` が wrap を考慮していない
   - row wrap container の cross axis (height) 計算時、max(child_cross) を返す
   - 正しくは wrap で複数行に分かれるので sum of line cross sizes が必要
   - 影響範囲: bevy_issue_8082, multiline_*, intrinsic_* など
   - 難易度: Medium

2. **align_* (35 tests)** - Flex で最も多い失敗
   - 子が親より大きい場合の処理
   - safe/unsafe alignment
   - 難易度: Medium

3. **flex_* (24 tests)** - Flex の基本機能
   - grow/shrink の frozen 処理
   - basis 計算エッジケース
   - 難易度: Medium

### 優先度 Medium

4. **percentage in indefinite (10+ tests)** - 複数パッケージに影響
5. **padding/border edge cases (8 tests)** - box-sizing 問題
6. **intrinsic_* (8 tests)** - main_size 計算

### 優先度 Low (特殊ケース)

7. **baseline alignment (7 tests)** - テキストレイアウト特有
8. **margin_y_collapse (7 tests)** - Block layout 特有
9. **text_align (3 tests)** - Block layout 特有

## 進捗履歴

| Phase | Block | Flex | Grid | 合計 |
|-------|-------|------|------|------|
| 開始時 | 147/223 (66%) | 352/607 (58%) | 241/329 (73%) | 740/1159 (64%) |
| P0完了 | 157/223 (70%) | 375/607 (62%) | 245/329 (74%) | 777/1159 (67%) |
| P1完了 | 168/223 (75%) | 409/607 (67%) | 248/329 (75%) | 825/1159 (71%) |
| P2進行中 | 198/223 (89%) | 433/599 (72%) | 248/329 (75%) | 879/1151 (76.4%) |
| wrap intrinsic fix | 198/223 (89%) | 434/599 (72.5%) | 248/329 (75%) | 880/1151 (76.5%) |
| align fixes | 198/223 (89%) | 436/599 (72.8%) | 248/329 (75%) | 882/1151 (76.6%) |
| flex intrinsic | 198/223 (89%) | 439/599 (73.3%) | 248/329 (75%) | 885/1151 (76.9%) |
| wrap percent | 198/223 (89%) | 443/599 (73.9%) | 248/329 (75%) | 889/1151 (77.2%) |
| min/max fix | 199/223 (89.2%) | 443/599 (73.9%) | 248/329 (75%) | 890/1151 (77.3%) |
| Block fixes | 204/223 (91.5%) | 445/599 (74.3%) | 248/329 (75%) | 897/1151 (77.9%) |
| compute_layout + intrinsic | 204/223 (91.5%) | 466/599 (77.8%) | 260/341 (76.2%) | 930/1163 (80.0%) |
| stretched child fix | 204/223 (91.5%) | 476/599 (79.5%) | 249/329 (75.7%) | 941/1163 (80.9%) |
| grid intrinsic fix | 204/223 (91.5%) | 476/599 (79.5%) | 250/329 (76.0%) | 942/1163 (81.0%) |
| grid aspect_ratio fix | 204/223 (91.5%) | 476/599 (79.5%) | 251/329 (76.3%) | 943/1163 (81.1%) |
| flex min/max + intrinsic | 204/223 (91.5%) | 482/599 (80.5%) | 251/329 (76.3%) | 949/1163 (81.6%) |
| baseline + inset fix | 204/223 (91.5%) | 489/599 (81.6%) | 251/329 (76.3%) | 956/1163 (82.2%) |
| baseline + absolute fix | 204/223 (91.5%) | 493/599 (82.3%) | 251/329 (76.3%) | 960/1163 (82.5%) |
| min_width final fix | 204/223 (91.5%) | 495/599 (82.6%) | 251/329 (76.3%) | 962/1163 (82.7%) |
| baseline Phase 1 | 204/223 (91.5%) | 496/599 (82.8%) | 251/329 (76.3%) | 963/1163 (82.8%) |
| wrap stretch Phase 2 | 204/223 (91.5%) | 498/599 (83.1%) | 251/329 (76.3%) | 965/1163 (83.0%) |
| align_items nowrap fix | 204/223 (91.5%) | 503/599 (84.0%) | 251/329 (76.3%) | 970/1163 (83.4%) |

### これまでの主な修正

**P1 (+48 tests)**
- intrinsic sizing cross-axis fix
- flex-shrink scaled factor
- stretch alignment constraints
- align-content single-line
- negative space handling

**P2 (+65 tests)**
- wrap container intrinsic sizing
- aspect_ratio support
- Block intrinsic sizing (MaxContent)
- MeasureFunc intrinsic sizing
- absolute shrink-to-fit
- absolute padding/border minimum

**wrap intrinsic fix (+1 test)**
- テストジェネレータに display: Flex 自動設定を追加
- compute_intrinsic_flex_main_size で wrap を考慮したライン分割処理を実装
- bevy_issue_8082 が pass

**align fixes (+3 tests)**
- 子が親より大きい場合の負のアライメントオフセット対応
- Definite sizing mode で margin 二重減算を修正
- align_items_center_child_without_margin_bigger_than_parent, align_items_flex_end_child_without_margin_bigger_than_parent が pass

**flex intrinsic fix (+3 tests)**
- MaxContent sizing mode で width:auto の Row flex に flex-grow/shrink を適用しないよう修正
- flex_grow_child が pass
- intrinsic sizing の正確性向上

**wrap percent fix (+4 tests)**
- wrap コンテナの intrinsic sizing でパーセント幅を正しく解決
- Row wrap の line breaking 計算時に親幅ではなく解決済み幅を使用

**min/max precedence fix (+1 test)**
- CSS 仕様に従い min-width/height が max より優先されるよう修正
- Block と Flex の両方で max を先に適用し、その後 min を適用

**Block fixes (+7 tests)**
- inset percentage: 相対配置の top/bottom 百分率を親の高さで解決（auto 時は 0）
- absolute margin:auto: 子が親より大きい場合、margin-left を 0 にして左位置使用
- aspect_ratio: height が max_height で制限された後、width を再計算

**compute_layout + intrinsic fixes (+33 tests)**
- Grid モジュールに `compute_layout` 汎用関数を追加
- root の display に応じて適切なモジュール (Block/Flex/Grid) に委譲
- blockflex テストが Flex layout を正しく使用するよう修正
- Block の MaxContent モードで MeasureFunc を持つ leaf node の intrinsic size を使用
- Block child の intrinsic width 計算時も MeasureFunc を考慮

**stretched child fix (+11 tests)**
- Definite sizing mode で height: auto の子に available_height を使用
  - 親から stretch されて確定した高さを content_height として使用
  - flex_grow が子コンテナで正しく機能するように
- 無限大プレースホルダー (1.0e9以上) は除外
- 単一行 wrap コンテナでも flex_items を flex_lines に同期

**grid intrinsic fix (+1 test)**
- Grid の compute_child_layout で Flex コンテナの intrinsic sizing を修正
- 1.0e10 (無限大プレースホルダー) 使用時は MaxContent モードで計算
- auto 次元には Flex layout の計算結果を使用

**grid aspect_ratio fix (+1 test)**
- compute_child_layout で min/max 制約を aspect_ratio 計算前に適用
- 制約された次元から aspect_ratio で他の次元を導出
- apply_alignment で aspect_ratio + max 制約がある場合 stretch を抑制

**flex min/max + intrinsic fix (+6 tests)**
- automatic minimum size を specified size (width/height) で clamp するよう修正
  - CSS 仕様: min-width: auto は min(content_size, specified_size, max_size)
- compute_intrinsic_main_size の結果に padding/border の二重加算を修正
- min/max の適用順序を max → min に修正 (CSS 仕様: min が max を上書き)
  - cross axis 計算 (Phase 3)
  - stretch alignment 計算
  - main axis 計算

**baseline + inset fix (+7 tests)**
- position: relative の inset (top/left) を Flex item の位置計算に適用
  - baseline alignment 後に inset offset を加算
- Column flex container の baseline 計算で first child の margin-top を含める
  - CSS 仕様: baseline は first child の margin-top + baseline

**baseline + absolute fix (+4 tests)**
- Column flex baseline 計算で container の padding-top を含める
  - CSS 仕様: baseline は padding-top + first child margin-top + baseline
- Block display コンテナの baseline 計算で first child の baseline を使用
  - 子を持つ Block コンテナは first in-flow child の baseline を返す
- Absolute positioning の inset percentage を padding box で解決
  - containing block は padding box (border の内側)

**min_width final fix (+2 tests)**
- Row flex container の最終幅計算に min/max 制約を適用
  - width:auto + child layouts から幅を再計算する場合
  - content width に min_width/max_width を適用

**baseline Phase 1 (+1 test)**
- AlignSelf に Baseline variant を追加
- flex.mbt, alignment.mbt, grid.mbt の match 文を更新
- Row flex の nested baseline 計算を追加

**wrap stretch Phase 2 (+2 tests)**
- wrap コンテナの Phase 3 で stretch を適用しないよう修正
  - wrap 時は Phase 5 で line_cross_size を使用して stretch
  - NoWrap 時のみ Phase 3 で container cross_size を使用
- align_content != Stretch の場合にアイテムが正しく line height に stretch される

**align_items nowrap fix (+5 tests)**
- nowrap 単一ライン container の align_items 計算で constrained cross size を使用
  - cross_size が definite の場合、line.cross_size ではなく container cross_size を使用
  - height:auto + max/min_height 制約がある場合、制約後のサイズを計算
- align_items: center で子が親より大きい場合に負のオフセットが正しく計算される

## 技術的な注意点

### margin: auto
- `resolve_rect` で Auto → 0.0 になる
- 位置計算時に style から直接チェックが必要

### intrinsic sizing
- 通常ブロック: `width: auto` = fill
- shrink-to-fit: absolute (left/right 未指定), flex item

### percentage の解決
- 親が definite: 親サイズの % を計算
- 親が indefinite: height は 0, width は available width

### wrap container intrinsic cross size (調査済み)

**問題**: column parent が row wrap child の height を計算するとき、wrap を考慮していない

**コード位置**: `flex/flex.mbt` の `compute_intrinsic_flex_main_size` (line 66-)

**現在の動作** (cross axis 計算、line 162-209):
```moonbit
let mut max_cross = 0.0
for child in children {
  let child_cross = ...  // 各子の cross サイズ
  if child_cross > max_cross { max_cross = child_cross }
}
```

**問題点**:
- wrap container では複数行に分かれる
- 正しい cross size = sum of (max cross size of each line)
- 現在は単一行として max を取っている

**例: bevy_issue_8082**:
- 4 items (70x70 with margin), container width=200
- 2 items per line → 2 lines
- Expected: 70 + 70 = 140px
- Current: max(70, 70, 70, 70) = 70px (then something causes 280px)

**修正方針**:
- wrap container の cross axis を計算するとき、実際にラインに分割
- 各ラインの max cross size を合計する
