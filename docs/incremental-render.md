# Incremental Layout 実装計画

Double Dirty Bit + Constraint Cache による増分レイアウト実装。

## 背景

### ブラウザエンジンの実装

| Engine | Self Dirty | Children Dirty |
|--------|-----------|----------------|
| Blink  | `needsLayout` | `childNeedsLayout` |
| Gecko  | `NS_FRAME_IS_DIRTY` | `NS_FRAME_HAS_DIRTY_CHILDREN` |
| WebKit | `normalChildNeedsLayout` | `posChildNeedsLayout` |

### 動作原理

1. ノードが変更されると自身を `dirty` にマーク
2. 親チェーンを遡って `children_dirty` を伝播
3. レイアウト時は dirty なノードのみ再計算

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                    User Code                            │
├─────────────────────────────────────────────────────────┤
│  LayoutTree (mutable)                                   │
│  ├─ LayoutNode (dirty bits, cache, style ref)          │
│  └─ children: Array[LayoutNode]                         │
├─────────────────────────────────────────────────────────┤
│  Style (immutable, shared)                              │
│  └─ Node から分離して共有可能に                          │
├─────────────────────────────────────────────────────────┤
│  ConstraintSpace                                        │
│  └─ available_width, available_height, viewport, etc.   │
├─────────────────────────────────────────────────────────┤
│  LayoutResult (immutable, cacheable)                    │
│  └─ width, height, children positions                   │
└─────────────────────────────────────────────────────────┘
```

## Phase 1: Dirty Bit 基盤

### 1.1 LayoutNode 構造体

```moonbit
// node/layout_node.mbt (新規)

/// レイアウト計算用のミュータブルノード
pub struct LayoutNode {
  id : String
  uid : Int
  style : @style.Style
  children : Array[LayoutNode]
  measure : MeasureFunc?
  text : String?

  // === Dirty Bits ===
  mut dirty : Bool                    // 自身が再計算必要
  mut children_dirty : Bool           // 子孫が再計算必要

  // === Cache ===
  mut cached_layout : LayoutCache?    // キャッシュされた結果
}

/// レイアウトキャッシュ
pub struct LayoutCache {
  constraint : ConstraintKey          // キャッシュキー
  result : Layout                     // キャッシュ値
}

/// 制約のキー（比較用）
pub struct ConstraintKey {
  available_width : Double
  available_height : Double?
  sizing_mode : SizingMode
}
```

### 1.2 Dirty 伝播

```moonbit
// node/dirty.mbt (新規)

/// ノードを dirty にマークし、親チェーンに伝播
pub fn LayoutNode::mark_dirty(self : LayoutNode) -> Unit {
  if self.dirty {
    return  // 既に dirty なら何もしない
  }
  self.dirty = true
  self.cached_layout = None  // キャッシュ無効化
}

/// 子が dirty になったことを親に通知
pub fn LayoutNode::mark_children_dirty(self : LayoutNode) -> Unit {
  if self.children_dirty {
    return
  }
  self.children_dirty = true
}

/// レイアウト完了後に dirty bits をクリア
pub fn LayoutNode::clear_dirty(self : LayoutNode) -> Unit {
  self.dirty = false
  self.children_dirty = false
}
```

### 1.3 親参照の管理

Dirty 伝播には親への参照が必要。2つの選択肢:

**Option A: 親ポインタを保持**
```moonbit
pub struct LayoutNode {
  // ...
  mut parent : LayoutNode?  // 弱参照的に使用
}
```

**Option B: 外部で親マップを管理**
```moonbit
pub struct LayoutTree {
  root : LayoutNode
  parent_map : Map[Int, LayoutNode]  // uid -> parent
}
```

**推奨: Option B** - 循環参照を避けられる

## Phase 2: Constraint Space

### 2.1 ConstraintSpace 構造体

```moonbit
// types/constraint.mbt (新規)

/// レイアウト制約（親から子へ渡される）
pub struct ConstraintSpace {
  // 利用可能サイズ
  available_width : Double
  available_height : Double?

  // サイジングモード
  sizing_mode : SizingMode

  // パーセント解決用
  percentage_resolution_width : Double
  percentage_resolution_height : Double?

  // Viewport (vw/vh 解決用)
  viewport_width : Double
  viewport_height : Double
}

/// 制約が実質的に同じかを判定
pub fn ConstraintSpace::is_equivalent(
  self : ConstraintSpace,
  other : ConstraintSpace,
  node_style : @style.Style
) -> Bool {
  // 固定サイズなら available の変化は無関係
  let width_matches = match node_style.width {
    Length(_) => true
    _ => approx_eq(self.available_width, other.available_width)
  }
  let height_matches = match node_style.height {
    Length(_) => true
    _ => match (self.available_height, other.available_height) {
      (Some(a), Some(b)) => approx_eq(a, b)
      (None, None) => true
      _ => false
    }
  }
  width_matches && height_matches && self.sizing_mode == other.sizing_mode
}
```

### 2.2 依存関係の種類

```moonbit
// types/dependency.mbt (新規)

/// 値が何に依存しているか
pub enum DependencyKind {
  Static           // 固定値のみ (px)
  ParentWidth      // 親幅に依存 (%, margin/padding %)
  ParentHeight     // 親高さに依存 (height %)
  Viewport         // Viewport に依存 (vw, vh)
  Intrinsic        // 子の内容に依存 (auto, min/max-content)
}

/// Style から依存関係を解析
pub fn analyze_dependencies(style : @style.Style) -> DependencyKind {
  let mut deps = Static

  // width の依存
  match style.width {
    Percent(_) => deps = merge_deps(deps, ParentWidth)
    Auto => deps = merge_deps(deps, Intrinsic)
    _ => ()
  }

  // height の依存
  match style.height {
    Percent(_) => deps = merge_deps(deps, ParentHeight)
    Auto => deps = merge_deps(deps, Intrinsic)
    _ => ()
  }

  // margin/padding の % は常に親幅に依存
  if has_percent_box_model(style) {
    deps = merge_deps(deps, ParentWidth)
  }

  deps
}
```

## Phase 3: キャッシュ機構

### 3.1 キャッシュ判定

```moonbit
// compute/cache.mbt (新規)

/// キャッシュヒット判定
pub fn try_cache(
  node : LayoutNode,
  constraint : ConstraintSpace
) -> Layout? {
  // dirty なら必ず再計算
  if node.dirty {
    return None
  }

  // キャッシュがなければ再計算
  let cache = match node.cached_layout {
    Some(c) => c
    None => return None
  }

  // 制約が同等ならキャッシュヒット
  if cache.constraint.is_equivalent(constraint, node.style) {
    // children_dirty でなければ完全ヒット
    if not(node.children_dirty) {
      return Some(cache.result)
    }
    // children_dirty なら子のみ再計算（部分ヒット）
  }

  None
}
```

### 3.2 レイアウト関数の修正

```moonbit
// compute/dispatch/dispatch.mbt 修正案

pub fn compute_incremental(
  node : LayoutNode,
  constraint : ConstraintSpace
) -> Layout {
  // キャッシュチェック
  match try_cache(node, constraint) {
    Some(cached) => return cached
    None => ()
  }

  // 通常のレイアウト計算
  let result = match node.style.display {
    Flex | InlineFlex => @flex.compute(node, constraint)
    Grid | InlineGrid => @grid.compute(node, constraint)
    _ => @block.compute(node, constraint)
  }

  // キャッシュ更新
  node.cached_layout = Some({
    constraint: constraint.to_key(),
    result: result
  })

  // dirty bits クリア
  node.clear_dirty()

  result
}
```

## Phase 4: API 設計

### 4.1 LayoutTree API

```moonbit
// tree/layout_tree.mbt (新規)

pub struct LayoutTree {
  root : LayoutNode
  parent_map : Map[Int, LayoutNode]
  viewport : Size[Double]

  // 前回のレイアウト結果
  mut last_layout : Layout?
}

/// ツリー構築
pub fn LayoutTree::new(root : LayoutNode, viewport : Size[Double]) -> LayoutTree

/// スタイル変更をマーク
pub fn LayoutTree::set_style(self : LayoutTree, node_uid : Int, style : @style.Style) -> Unit {
  let node = self.find_node(node_uid)
  node.style = style
  node.mark_dirty()
  self.propagate_dirty_to_ancestors(node_uid)
}

/// 子の追加
pub fn LayoutTree::append_child(self : LayoutTree, parent_uid : Int, child : LayoutNode) -> Unit {
  let parent = self.find_node(parent_uid)
  parent.children.push(child)
  self.parent_map[child.uid] = parent
  parent.mark_dirty()
  self.propagate_dirty_to_ancestors(parent_uid)
}

/// 子の削除
pub fn LayoutTree::remove_child(self : LayoutTree, parent_uid : Int, child_uid : Int) -> Unit

/// Viewport リサイズ
pub fn LayoutTree::resize_viewport(self : LayoutTree, width : Double, height : Double) -> Unit {
  self.viewport = { width, height }
  // vw/vh 依存ノードのみ dirty に
  self.mark_viewport_dependents_dirty(self.root)
}

/// 増分レイアウト実行
pub fn LayoutTree::compute(self : LayoutTree) -> Layout {
  let constraint = ConstraintSpace {
    available_width: self.viewport.width,
    available_height: Some(self.viewport.height),
    sizing_mode: Definite,
    percentage_resolution_width: self.viewport.width,
    percentage_resolution_height: Some(self.viewport.height),
    viewport_width: self.viewport.width,
    viewport_height: self.viewport.height,
  }

  compute_incremental(self.root, constraint)
}
```

### 4.2 後方互換 API

既存の `Node` API との互換性を保つ:

```moonbit
// 既存 API (変更なし)
pub fn compute_layout(node : Node, ctx : LayoutContext) -> Layout

// 新 API (LayoutTree 経由)
pub fn compute_layout_incremental(tree : LayoutTree) -> Layout
```

## 実装順序

| Phase | 内容 | 状態 |
|-------|------|------|
| 1.1 | LayoutNode 構造体定義 | ✅ 完了 |
| 1.2 | Dirty bit 伝播ロジック | ✅ 完了 |
| 1.3 | LayoutTree + 親マップ | ✅ 完了 |
| 2.1 | ConstraintSpace 定義 | ✅ 完了 |
| 2.2 | ルートレベルキャッシュ判定 | ✅ 完了 |
| 2.3 | CacheStats 計測 | ✅ 完了 |
| 3.1 | 子ノードキャッシュ同期 | ✅ 完了 |
| 3.2 | compute関数のLayoutNode対応 | ✅ 完了 (dispatcher wrapper) |
| 4.1 | DependencyKind 定義 | ✅ 完了 |
| 4.2 | Style依存関係解析 | ✅ 完了 |
| 4.3 | 選択的viewport無効化 | ✅ 完了 |

### 現在の実装状況

**完了済み:**
- `LayoutNode`: dirty bits + 依存関係情報付きのミュータブルノード
- `LayoutTree`: 親マップによる dirty 伝播
- `ConstraintSpace`: 制約ベースのキャッシュキー
- `CacheStats`: キャッシュヒット率の計測
- ルートノードレベルでのキャッシュ
- 子ノードキャッシュの同期 (`sync_child_caches`)
- `DependencyKind`: Static/ParentWidth/ParentHeight/ParentBoth/Intrinsic/Viewport
- `analyze_style_dependencies()`: Styleから依存関係を解析
- 選択的viewport無効化: 固定サイズノードはresize時にdirtyにならない
- `Node::with_uid()`: uid保持付きNodeコンストラクタ
- `cached_dispatch()`: キャッシュ対応dispatcher wrapper

**動作:**
1. `compute_tree_incremental()` でグローバルマップを構築 (uid → LayoutNode)
2. キャッシュ対応dispatcherを設定
3. `compute_node()` でルートを計算
4. キャッシュがあり dirty でなければキャッシュを返す
5. キャッシュミスなら `dispatch_layout` で計算（子は cached_dispatch 経由）
6. 計算結果を全子ノードにキャッシュとして同期
7. 元のdispatcherを復元、グローバルマップをクリア
8. `resize_viewport()` は依存関係に基づいて選択的にdirtyをマーク
   - `Static` ノード: 無効化しない
   - `ParentWidth` ノード: 幅変更時のみ無効化
   - `ParentHeight` ノード: 高さ変更時のみ無効化

**キャッシュの効果:**
- ルートレベル: 完全にキャッシュ機能
- 子ノードレベル: Flex/Grid内のネストされたコンテナで `dispatch_layout` を使用することでキャッシュヒット可能
- 部分更新: dirty でない子ノードはキャッシュヒットで計算をスキップ

**ベンチマーク結果:**
- 341ノードツリー: フル計算86ops → 10回増分更新で50%以上の節約
- 156ノードツリー: 100回の変更なしクエリで100ops（1クエリ=1キャッシュヒット）
- 2047ノード深いツリー: 2回目以降のクエリは0 cache misses

**テスト:** 24件全て通過（15件の基本テスト + 9件のベンチマーク）

## ファイル構成

```
tree/
├── moon.pkg.json           # パッケージ設定
├── layout_node.mbt         # LayoutNode + Dirty bits + Dependencies
├── layout_tree.mbt         # LayoutTree API + 親マップ管理
├── incremental_compute.mbt # ConstraintSpace + キャッシュ判定 + CacheStats
├── dependency.mbt          # DependencyKind + 依存関係解析
└── layout_tree_test.mbt    # テスト (12件)
```

## テスト戦略

### ユニットテスト

```moonbit
// Dirty bit 伝播テスト
test "mark_dirty propagates to ancestors" {
  let tree = create_test_tree()
  let leaf = tree.find_node(leaf_uid)
  leaf.mark_dirty()

  assert_true!(leaf.dirty)
  assert_true!(leaf.parent.children_dirty)
  assert_true!(tree.root.children_dirty)
}

// キャッシュヒットテスト
test "cache hit when constraint unchanged" {
  let tree = create_test_tree()
  let layout1 = tree.compute()
  let layout2 = tree.compute()  // キャッシュヒット

  // 同じ結果
  assert_eq!(layout1, layout2)
}

// キャッシュ無効化テスト
test "cache invalidated on style change" {
  let tree = create_test_tree()
  tree.compute()

  tree.set_style(node_uid, new_style)
  // node.cached_layout == None を確認
}
```

### 性能テスト

```moonbit
// 増分更新の性能
test "incremental update faster than full layout" {
  let tree = create_large_tree(1000)  // 1000ノード

  let t1 = measure_time(fn() { tree.compute() })  // 初回

  tree.set_style(leaf_uid, new_style)  // 1ノード変更
  let t2 = measure_time(fn() { tree.compute() })  // 増分

  assert_true!(t2 < t1 / 10)  // 10倍以上高速
}
```

## 将来の拡張

### Reflow Root (Phase 5)

`position: absolute/fixed` のノードを独立した reflow root として扱う:

```moonbit
pub fn is_reflow_root(style : @style.Style) -> Bool {
  style.position == Absolute || style.position == Fixed
}
```

### Subtree Independence (Phase 6)

`overflow: hidden` + 固定サイズのノードは子の変更が外に影響しない:

```moonbit
pub fn is_subtree_independent(style : @style.Style) -> Bool {
  (style.overflow_x == Hidden || style.overflow_y == Hidden) &&
  match (style.width, style.height) {
    (Length(_), Length(_)) => true
    _ => false
  }
}
```

## 参考資料

- [RenderingNG deep-dive: LayoutNG](https://developer.chrome.com/docs/chromium/layoutng)
- [Layout Overview — Firefox Source Docs](https://firefox-source-docs.mozilla.org/layout/LayoutOverview.html)
- [WebCore Rendering III – Layout Basics](https://webkit.org/blog/116/webcore-rendering-iii-layout-basics/)
