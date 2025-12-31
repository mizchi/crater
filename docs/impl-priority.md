# Implementation Priority

失敗テストの分析に基づく実装優先度。実際の使用頻度と修正難易度を考慮。

## 優先度レベル

### P0: 最優先（高頻度使用 + 修正可能）

#### 1. gentest で margin: auto を HTML からパース
- **影響**: Block 14件, Flex 18件, Grid 2件
- **理由**: センタリングは最も基本的な機能
- **対策**: tools/gentest.ts で HTML の style 属性から直接パース
- **難易度**: Medium

```
例: <div style="margin-left: auto;"> から margin: { left: Auto, ... } を生成
```

#### 2. percentage in indefinite containers
- **影響**: Block 10件, Flex 18件, Grid 12件
- **理由**: レスポンシブデザインの基本
- **対策**: 親サイズ不定時の % 解決ロジック修正
- **難易度**: Medium

### P1: 高優先（高頻度使用）

#### 3. min/max constraints
- **影響**: Flex 34件
- **理由**: レスポンシブデザインで必須
- **対策**: 制約の適用順序を CSS 仕様通りに修正
- **難易度**: Low-Medium

#### 4. flex-grow/shrink 計算
- **影響**: Flex 24件 (grow+shrink)
- **理由**: `flex: 1` の基本動作
- **対策**: taffy の実装を参考に修正
- **難易度**: Medium

#### 5. align/justify
- **影響**: Flex 24件, Block 2件
- **理由**: 配置の基本機能
- **対策**: alignment 計算の見直し
- **難易度**: Medium

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

## 期待される改善

| Phase | Block | Flex | Grid | 合計 |
|-------|-------|------|------|------|
| 現在 | 147/222 (66%) | 352/607 (58%) | 241/329 (73%) | 740/1158 (64%) |
| Phase 1 | +14 | +18 | +2 | +34 |
| Phase 2 | +10 | +76 | +12 | +98 |
| Phase 3 | +31 | +40 | +15 | +86 |
| 目標 | 202/222 (91%) | 486/607 (80%) | 270/329 (82%) | 958/1158 (83%) |

※ 数値は推定。実際には重複や依存関係あり。
