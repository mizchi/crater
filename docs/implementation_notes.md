# Implementation Notes

実装時に発見した知見と、再実装時の注意点をまとめる。

## 現在のテスト状況 (2024-12-31)

| モジュール | 合格 | 失敗 | 合格率 |
|----------|------|------|--------|
| Block    | 147  | 75   | 66.2%  |
| Flex     | 352  | 255  | 58.0%  |
| Grid     | 241  | 88   | 73.3%  |

## テスト Fixture の問題

### 問題の概要

taffy のテスト fixture (JSON) には、一部の CSS プロパティが欠落している：

1. **margin: auto** - `margin_auto_*` テストでも margin が定義されていない
2. **aspectRatio** - `aspect_ratio_*` テストでも aspect_ratio が定義されていない

### 原因

taffy の gentest ツールが、ブラウザの computed style から fixture を生成している。
一部のプロパティは computed style に現れない、または別の形式で出力される。

### 対策案

1. **Fixture 再生成**: taffy のソースコードから正確なスタイル定義を抽出
2. **テスト名からの推論**: 複雑で不正確になりがち（非推奨）
3. **手動テスト追加**: 重要なケースは手動で block_test.mbt 等に追加

## Intrinsic Sizing の複雑さ

### CSS の仕様

通常のブロック要素で `width: auto` は **親の幅を埋める（fill）** 動作。
**コンテンツに縮む（shrink-to-fit）** は特定コンテキストでのみ適用：

| コンテキスト | shrink-to-fit が適用される |
|-------------|--------------------------|
| float 要素 | ✅ |
| position: absolute (left/right 未指定) | ✅ |
| inline-block | ✅ |
| flex item | ✅ (条件付き) |
| grid item | ✅ (条件付き) |
| table cell | ✅ |
| 通常のブロック要素 | ❌ (fill) |

### プロトタイプの結果

```moonbit
// NG: 全ての width: Auto を shrink-to-fit として扱う
let mut box_width = if width_is_auto {
  // Intrinsic sizing: find max child width
  let mut max_child_width = 0.0
  for child in flow_children {
    max_child_width = max(max_child_width, child.width)
  }
  max_child_width + padding + border
} else {
  // explicit width
}
```

この実装では:
- 147 → 58 にテストが激減
- 子要素も width: Auto の場合、連鎖的に 0 になる

### 正しいアプローチ

1. レイアウトコンテキストを追跡
2. コンテキストに応じて fill/shrink-to-fit を切り替え
3. AvailableSpace 概念の導入 (MinContent/MaxContent/Definite)

## Margin Auto の実装

### 実装済み (block/block.mbt)

#### 通常ブロック要素

```moonbit
// Calculate x position considering margin auto
let child_x = {
  let margin_left_auto = match child_style.margin.left {
    @types.Auto => true
    _ => false
  }
  let margin_right_auto = match child_style.margin.right {
    @types.Auto => true
    _ => false
  }
  let available = child_available_width - child_layout.width -
    child_layout.margin.left - child_layout.margin.right

  if margin_left_auto && margin_right_auto {
    // Both auto: center
    (available / 2.0) + padding.left + border.left
  } else if margin_left_auto {
    // Only left auto: push to right
    available + padding.left + border.left
  } else {
    // No auto or only right auto: use left margin
    child_layout.margin.left + padding.left + border.left
  }
}
```

#### 絶対配置要素

両方の inset (left + right) が指定された場合のみ margin auto が機能：

```moonbit
let child_x = match (inset_left, inset_right) {
  (Some(l), Some(r)) => {
    if margin_left_is_auto && margin_right_is_auto {
      // Center
      let available = container_width - l - r - child_width
      l + available / 2.0 + parent_border.left
    } else if margin_left_is_auto {
      // Push to right
      container_width - child_width - r - margin_right + parent_border.left
    } else if margin_right_is_auto {
      // Push to left
      l + margin_left + parent_border.left
    } else {
      // Over-constrained: use left
      l + margin_left + parent_border.left
    }
  }
  // ... other cases
}
```

### 注意点

- `resolve_rect` で margin を解決すると Auto → 0.0 になる
- margin が Auto かどうかは style から直接チェックする必要がある

## Display: none の処理

### 問題

display: none の要素を子配列から完全に除外すると、テストの期待値とインデックスがずれる。

### 解決策

```moonbit
// Map to store layouts by original index
let layout_map : Map[Int, @node.Layout] = {}

for i = 0; i < node.children.length(); i = i + 1 {
  let child = node.children[i]
  if child.style.display == @style.None {
    // Add zero-sized layout at original index
    layout_map[i] = create_zero_layout(child)
    continue
  }
  // ... normal processing
  layout_map[i] = positioned_layout
}

// Assemble in original order
let child_layouts : Array[@node.Layout] = []
for i = 0; i < node.children.length(); i = i + 1 {
  match layout_map.get(i) {
    Some(layout) => child_layouts.push(layout)
    None => ()
  }
}
```

## Margin Collapse の実装

### 基本ルール

```moonbit
fn collapse_margins(m1 : Double, m2 : Double) -> Double {
  if m1 >= 0.0 && m2 >= 0.0 {
    max(m1, m2)  // 両方正: 大きい方
  } else if m1 <= 0.0 && m2 <= 0.0 {
    min(m1, m2)  // 両方負: 絶対値の大きい方
  } else {
    m1 + m2      // 混合: 足し算
  }
}
```

### Collapse-through 条件

```moonbit
fn can_collapse_through(
  height : Double,
  border : Rect[Double],
  padding : Rect[Double],
) -> Bool {
  height == 0.0 &&
  border.top == 0.0 && border.bottom == 0.0 &&
  padding.top == 0.0 && padding.bottom == 0.0
}
```

ブロッカー:
- height > 0
- border-top/bottom > 0
- padding-top/bottom > 0
- overflow != visible
- aspect-ratio が指定されている

## 今後の優先実装項目

### 高優先度

1. **テスト Fixture の改善**
   - margin: auto を含む fixture の手動追加
   - aspect_ratio を含む fixture の手動追加

2. **Intrinsic Sizing のコンテキスト認識**
   - LayoutContext に sizing_mode を追加
   - float/inline-block/absolute で shrink-to-fit を有効化

### 中優先度

3. **Baseline Alignment**
   - 各要素の baseline offset を計算
   - 親が align-items: baseline の場合に適用

4. **Aspect Ratio**
   - width/height のどちらかが auto の場合に適用
   - min/max 制約との相互作用

### 低優先度

5. **AvailableSpace の導入**
   - MinContent/MaxContent/Definite の3状態
   - 各コンポーネントの intrinsic size 計算を統一
