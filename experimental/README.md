# Experimental Modules

crater-browser のレイアウトエンジンとAOMを活用した実験的機能群。

## Arc90 Content Extraction (`arc90/`)

Arc90 Readability アルゴリズムの拡張版。テキスト密度に加えて座標情報を使用してメインコンテンツを抽出。

### 特徴
- テキスト密度 + 視覚的スコアリング
- 広告・ナビゲーション要素の検出
- 座標ベースのコンテンツ位置分析

### 使用例
```bash
npx @mizchi/crater-browser https://example.com --arc90
```

### API
```moonbit
// コンテンツ抽出
let result = @arc90.extract_content(tree, config)

// 結果のサマリー
result.to_summary()
```

## Visual Grounding (`grounding/`)

空間クエリによる要素検索。AIエージェントが「右上のボタン」「フォームの下」などの自然言語的な位置指定で要素を特定可能。

### 特徴
- 9領域ベースの空間検索 (TopLeft, TopCenter, TopRight, MiddleLeft, Center, MiddleRight, BottomLeft, BottomCenter, BottomRight)
- 相対位置検索 (Above, Below, LeftOf, RightOf, Inside, Near)
- ロール+領域の複合検索
- クリック座標の取得

### 使用例
```bash
npx @mizchi/crater-browser https://example.com --grounding
```

### API
```moonbit
// 領域内の要素を検索
let results = @grounding.find_by_spatial(tree, InRegion(TopRight), viewport)

// 特定ロールを領域内で検索
let links = @grounding.find_by_spatial(tree, RoleInRegion(Link, TopRight), viewport)

// 要素からの相対位置で検索
let below = @grounding.find_by_spatial(tree, RelativeTo(Below, "form-id"), viewport)

// クリック座標を取得
let coords = @grounding.get_click_coords(tree, "ref_1")
```

### 検出可能なインタラクティブ要素
- Button, Link, Textbox, Checkbox, Radio
- Combobox, Listbox, Slider, Switch, Tab
- MenuItem, MenuItemCheckbox, MenuItemRadio
- SpinButton, SearchBox

## Structural Diff (`diff/`)

2つのAccessibilityTreeを比較し、構造的な差分を検出。スクリーンショット不要のビジュアルリグレッションテスト。

### 特徴
- 追加・削除・移動の検出
- リサイズ検出（閾値設定可能）
- ロール/名前/状態の変更検出
- 類似ノードのマッチング

### API
```moonbit
// ツリーの差分を計算
let result = @diff.diff_trees(before, after, config)

// 差分の種類
match diff.kind {
  Added => "新規追加"
  Removed => "削除"
  Moved => "位置移動"
  Resized => "サイズ変更"
  RoleChanged => "ロール変更"
  NameChanged => "名前変更"
  StateChanged => "状態変更"
}
```

### 設定オプション
```moonbit
let config = DiffConfig::{
  ignore_position: false,      // 位置変更を無視
  ignore_size: false,          // サイズ変更を無視
  size_threshold: 5.0,         // サイズ変更の閾値(px)
  match_by_role: true,         // ロールでマッチング
  match_by_name: true,         // 名前でマッチング
}
```

## 依存関係

これらのモジュールは以下に依存:
- `mizchi/crater/aom` - Accessibility Object Model
- `mizchi/crater/html` - HTML Parser
- `mizchi/crater/renderer` - Layout Engine (bounds計算)

## 技術的な背景

### Bounds統合の仕組み

1. `@html.assign_synthetic_ids()` で全要素にユニークID付与
2. `@renderer.render_document_with_external_css()` でCSS適用済みレイアウト計算
3. `@aom.build_accessibility_tree_with_node_layout()` でAOMにbounds付与

これにより、各AccessibilityNodeが正確な座標情報を持ち、空間クエリが可能になる。
