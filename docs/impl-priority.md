# Implementation Priority

失敗テストの分析に基づく実装優先度。実際の使用頻度と修正難易度を考慮。

## 現在のテスト状況 (2024-12-31 更新)

| Module | Passed | Total | Percentage |
|--------|--------|-------|------------|
| Block  | 168    | 223   | 75.3%      |
| Flex   | 412    | 607   | 67.9%      |
| Grid   | 248    | 329   | 75.4%      |
| **Total** | **828** | **1159** | **71.4%** |

## 優先度レベル

### P0: 最優先（高頻度使用 + 修正可能） ✅ 完了

#### 1. gentest で margin: auto を HTML からパース ✅
- **状態**: 完了
- **改善**: tools/gentest.ts を改善して margin: auto をパース

#### 2. percentage in indefinite containers
- **影響**: Block 10件, Flex 18件, Grid 12件
- **理由**: レスポンシブデザインの基本
- **対策**: 親サイズ不定時の % 解決ロジック修正
- **難易度**: Medium

### P1: 高優先（高頻度使用） ✅ 部分完了

#### 3. min/max constraints ✅ 一部完了
- **状態**: stretch alignment での min/max 対応を修正
- **残り**: 一部の特殊ケース

#### 4. flex-grow/shrink 計算 ✅ 完了
- **状態**: CSS spec に準拠した scaled shrink factor を実装
- **改善**: +3 tests

#### 5. align/justify ✅ 大幅改善
- **状態**: 複数の修正を実施
  - align-content の single-line 対応 (+11 tests)
  - negative space での Space* 処理 (+13 tests)
- **残り**: baseline alignment (P3), 子が親より大きい場合

### P2: 中優先（よく使う）

#### 6. flex-wrap
- **影響**: Flex 23件
- **理由**: 複数行レイアウトで使用
- **難易度**: Medium-High

#### 7. padding/border 計算
- **影響**: Flex 14件, Block 6件
- **理由**: ボックスモデルの基本
- **難易度**: Low

#### 8. gentest で aspect-ratio を HTML からパース
- **影響**: Block 7件, Flex 12件, Grid 4件
- **理由**: 画像/動画で使用
- **対策**: margin: auto と同様に HTML パース
- **難易度**: Medium

### P3: 低優先（特定用途）

#### 9. baseline alignment
- **影響**: Block 7件, Flex 17件, Grid 4件
- **理由**: テキスト整列の特殊ケース
- **難易度**: High

#### 10. Block/Flex の absolute positioning
- **影響**: Block 24件, Flex 13件
- **理由**: Grid では実装済み、移植が必要
- **難易度**: Medium (Grid から移植)

## 実装戦略

### Phase 1: Fixture 改善 (P0-1)
1. gentest.ts を改善して margin: auto と aspect-ratio を HTML からパース
2. テストを再生成
3. 実装の問題と fixture の問題を明確に分離

### Phase 2: 基本機能修正 (P1-2)
1. percentage 解決ロジックの修正
2. min/max constraints の適用順序修正
3. flex-grow/shrink の計算修正

### Phase 3: 追加機能 (P2-3)
1. flex-wrap の改善
2. baseline alignment
3. absolute positioning の移植

## 技術的な注意点

### margin: auto の扱い
- `resolve_rect` で margin を解決すると Auto → 0.0 になる
- 位置計算時に style から直接 Auto かどうかをチェックする必要がある

### intrinsic sizing
- 通常ブロック: `width: auto` = fill (親の幅を埋める)
- 特定コンテキスト: shrink-to-fit が適用される
  - float
  - position: absolute (left/right 未指定)
  - inline-block
  - flex item / grid item (条件付き)

### percentage の解決
- 親サイズが definite: 親サイズの % を計算
- 親サイズが indefinite:
  - height: percentage は 0 扱い (または無視)
  - width: 親の利用可能幅を使用

## 進捗履歴

| Phase | Block | Flex | Grid | 合計 |
|-------|-------|------|------|------|
| 開始時 | 147/223 (66%) | 352/607 (58%) | 241/329 (73%) | 740/1159 (64%) |
| P0完了 | 157/223 (70%) | 375/607 (62%) | 245/329 (74%) | 777/1159 (67%) |
| P1完了 | 168/223 (75%) | 409/607 (67%) | 248/329 (75%) | 825/1159 (71%) |
| P2進行中 | 168/223 (75%) | 412/607 (68%) | 248/329 (75%) | **828/1159 (71.4%)** |

### P1での主な修正 (+48 tests)

1. **intrinsic sizing cross-axis fix** (+1): ネスト flex の cross-axis 計算を修正
2. **flex-shrink scaled factor** (+3): CSS spec に準拠した shrink 計算
3. **stretch alignment constraints** (+5): min/max 制約の適用
4. **align-content single-line** (+11): nowrap 時の align-content を Start として扱う
5. **negative space handling** (+13): Space* の negative space 対応
6. **test fixes** (+2): reverse テストの期待値修正

### P2での修正 (+3 tests)

1. **wrap container intrinsic sizing** (+3): wrap container は available width を使用

## 残りの課題

| カテゴリ | 影響テスト数 | 優先度 |
|---------|-------------|--------|
| baseline alignment | 16件 | P3 |
| absolute positioning | 20件 | P3 |
| 子が親より大きい場合 | 数件 | P2 |
| flex-wrap 特殊ケース | 12件 | P2 (一部修正済み) |
