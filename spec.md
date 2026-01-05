# crater - CSS Layout Engine Specification

Pure MoonBit implementation of CSS layout calculation.

## Goals

- Calculate `getBoundingClientRect()` equivalent from HTML/CSS
- Focus on coordinate calculation, not rendering
- Support Block -> Flex -> Grid layouts (in order)
- Enable CLS (Cumulative Layout Shift) calculation

## Current Status

**Taffy Tests: 1185/1436 tests passing (82.5%)**

- [x] Basic geometry types (Size, Point, Rect, BoundingRect)
- [x] Dimension (Length, Percent, Auto)
- [x] Block layout with margin, padding, border
- [x] Percentage width/height
- [x] min/max width/height
- [x] Margin collapsing (adjacent siblings)
- [x] Percentage margin/padding (relative to parent width per CSS spec)
- [x] Flex layout
  - [x] flex-direction (row, column, row-reverse, column-reverse)
  - [x] justify-content (start, end, center, space-between, space-around, space-evenly)
  - [x] align-items (start, end, center, stretch)
  - [x] align-self
  - [x] flex-grow / flex-shrink
  - [x] flex-basis
  - [x] flex-wrap (wrap, nowrap, wrap-reverse)
  - [x] align-content (stretch, start, end, center, space-between, space-around)
  - [x] gap (row-gap, column-gap)
  - [x] margin: auto
  - [x] aspect-ratio (basic)
  - [ ] display: none (partial)
  - [ ] Intrinsic sizing with measure functions
- [x] Grid layout
  - [x] grid-template-columns / grid-template-rows
  - [x] Track sizing: Length, Percent, Fr, Auto, MinContent, MaxContent
  - [x] minmax() function
  - [x] repeat() function (Count, AutoFill, AutoFit)
  - [x] grid-auto-rows / grid-auto-columns
  - [x] grid-auto-flow (Row, Column, Dense)
  - [x] gap (row-gap, column-gap)
  - [x] justify-content / align-content
  - [x] justify-items / align-items
  - [x] align-self for grid items
  - [x] Grid item placement (line-based)
  - [x] grid-template-areas (named areas)
  - [x] Implicit track creation
  - [x] Negative line indices
  - [x] aspect-ratio for grid items (basic)
  - [x] Nested Grid/Flex containers
  - [x] Extrinsic definite sizing for stretched items
  - [ ] Baseline alignment (partial)
  - [ ] Auto margins (partial)
  - [ ] Span items intrinsic sizing
  - [ ] Percent resolution in deeply nested grids
  - [ ] fit-content with indefinite percentages

## Test Status by Category

### Block Layout
- ~21 failing tests
- Issues: baseline alignment, aspect-ratio with max constraints, margin collapsing edge cases

### Flex Layout
- ~79 failing tests
- Issues: display:none, intrinsic sizing, absolute positioning, baseline multiline, percentage gaps

### Grid Layout
- ~50 failing tests
- Issues: absolute positioning, baseline, span items, nested percent resolution, fit-content

### Mixed Layouts
- ~15 failing tests
- Issues: block-in-flex, block-in-grid, grid-in-flex, leaf content sizing

### Remaining Issues

1. **display: none** (~7 tests)
   - Hidden elements should not affect layout
   - Size should be 0, position should not affect siblings

2. **Baseline Alignment** (~10 tests)
   - Baseline calculation with padding/margin
   - Multiline baseline handling in flex and grid

3. **Absolute Positioning** (~10 tests)
   - Inset resolution with percentages
   - Interaction with border/padding

4. **Intrinsic Sizing** (~20 tests)
   - Min-content/max-content for nested containers
   - Measure functions for leaf nodes

5. **Span Items** (~15 tests)
   - Grid items spanning multiple tracks
   - Gap calculation for span items

6. **Percent in Nested Layouts** (~15 tests)
   - Percent resolution in nested grids/flex with auto-sized parents
   - Cyclic percentage dependencies

7. **Aspect Ratio** (~10 tests)
   - Interaction with max-width/max-height constraints
   - Fill mode with constraints

## Implementation Roadmap

1. **Phase 1**: Flex layout ✅
2. **Phase 2**: Grid layout ✅ (78.9% tests passing)
3. **Phase 3**: `position: absolute/fixed` ✅ (relative, absolute, fixed positioning)
4. **Phase 4**: Inline layout ✅ (inline, inline-block, IFC)
5. **Phase 5**: Float (simplified, if needed)

## Scheduler Module ✅

Browser の Event Loop / Task Scheduler に相当するモジュール。HTML/CSS/Layout の評価タスクをキュー管理し、依存関係を解決する。

### 実装状況

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: 基本型定義 | ✅ | TaskId, TaskSource, TaskConstraint, TaskState, TaskAction, Task, TaskResult |
| Phase 2: キュー管理 | ✅ | TaskQueue, SourceQueueManager, 優先度ソート |
| Phase 3: スケジューラ本体 | ✅ | enqueue, poll_ready, complete, 依存解決, ブロック管理 |
| Phase 4: 統合 | ✅ | HTML Parser, CSS Cascade, LayoutTree, ResourceId |

### ファイル構成

```
scheduler/
├── task.mbt               # Task型定義
├── queue.mbt              # TaskQueue管理
├── scheduler.mbt          # Scheduler本体
├── html_integration.mbt   # HTML Parser統合
├── css_integration.mbt    # CSS Cascade統合
├── layout_integration.mbt # LayoutTree統合
└── task_wbtest.mbt        # テスト (48テスト)
```

### 主要コンポーネント

| Component | Description |
|-----------|-------------|
| `Scheduler` | タスクキュー管理、依存解決、ポーリング |
| `DocumentParser` | HTML パースとリソース発見 |
| `StyleManager` | スタイルシート管理、カスケード計算 |
| `LayoutManager` | LayoutTree 管理、レイアウトスケジューリング |
| `DocumentRenderCoordinator` | HTML/CSS/Layout 統合パイプライン |

### 設計方針

1. **外部委譲**: ネットワーク、非同期ランタイム、スクリプト実行は外部に委譲
2. **内部実行**: スタイル計算、レイアウト計算は同期的に内部実行可能
3. **依存グラフ**: タスク間の依存関係を明示的に管理
4. **並列性判定**: 各タスクに並列実行可能かのフラグを付与

### 統合パイプライン

```
HTML Parser → CSS Parser → Style Cascade → Layout Tree
     ↓            ↓              ↓              ↓
  タスク生成    タスク生成    スタイル計算    レイアウト計算
     ↓            ↓              ↓              ↓
  Scheduler が全てのタスクを管理・依存解決・実行順序決定
```

## Web Vitals Module ✅

Core Web Vitals の計測モジュール。LCP (Largest Contentful Paint) と CLS (Cumulative Layout Shift) を実装。

### ファイル構成

```
webvitals/
├── lcp.mbt       # LCP検出・追跡
├── lcp_test.mbt  # LCPテスト (9テスト)
├── cls.mbt       # CLS計算
└── cls_test.mbt  # CLSテスト (3テスト)
```

### LCP (Largest Contentful Paint)

ページの最大コンテンツ要素がレンダリングされるタイミングを検出。AI TUI Browser で「操作可能タイミング」を判定するために使用。

```moonbit
/// LCP候補のタイプ
pub(all) enum LCPElementType {
  Image(src~ : String)
  BackgroundImage(url~ : String)
  Video(poster~ : String?)
  TextBlock
}

/// LCPトラッカー
let tracker = LCPTracker::new(viewport_width, viewport_height)

// 候補を追加
tracker.add_candidate(candidate)

// リソースロード完了
tracker.on_resource_loaded(element_id, load_time)

// レンダリング完了
tracker.on_element_rendered(element_id, render_time)

// ユーザー入力でLCPを確定
tracker.finalize()

// LCP準備完了を確認
if tracker.is_lcp_ready() {
  // 操作可能
}
```

### CLS (Cumulative Layout Shift)

レイアウトシフトのスコアを計算。

```moonbit
/// 単一要素のシフトを計算
let shift = compute_element_shift(before, after, viewport)
// shift.score = impact_fraction × distance_fraction

/// 複数要素のCLS合計
let cls = compute_total(before_rects, after_rects, viewport)
```

### ContentReadiness

LCP と アクセシビリティの準備状態を統合。

```moonbit
pub(all) struct ContentReadiness {
  lcp_ready : Bool
  lcp_time : Double?
  critical_resources_loaded : Bool
  a11y_ready : Bool
}

/// 操作可能判定
if readiness.is_interaction_ready() {
  // LCP完了 && a11y準備完了
}
```

## AOM (Accessibility Object Model) Module ✅

HTML からアクセシビリティツリーを構築するモジュール。WAI-ARIA 1.2 と HTML-AAM 1.0 仕様に基づく。

### ファイル構成

```
aom/
├── types.mbt          # Role, State, Bounds, AccessibilityNode, AccessibilityTree
├── role.mbt           # HTML→Role推論
├── name.mbt           # Accessible Name計算 (accname spec)
├── tree.mbt           # ツリー構築 + Layout統合
├── snapshot.mbt       # YAML/JSON出力 (Playwright互換)
├── layout_test.mbt    # Layout統合テスト (7テスト)
└── *_test.mbt         # テスト群
```

### 主要機能

| 機能 | 説明 |
|------|------|
| `build_accessibility_tree()` | HTML Document → AccessibilityTree |
| `build_accessibility_tree_with_layout()` | HTML + LayoutTree → bounds付きAccessibilityTree |
| `compute_role()` | 要素の暗黙的/明示的Role推論 |
| `compute_accessible_name()` | aria-label, alt, title等からの名前計算 |
| `to_aria_snapshot()` | Playwright互換YAML出力 |
| `to_aria_json()` | JSON形式出力 |
| `find_interactive()` | インタラクティブ要素の検索 |
| `find_landmarks()` | ランドマーク要素の検索 |
| `find_headings()` | 見出し要素の検索 |
| `extract_bounds_from_layout()` | LayoutTree から Bounds を抽出 |
| `attach_bounds()` | Bounds を AccessibilityTree にアタッチ |

### 使用例

```moonbit
// HTML → AccessibilityTree
let tree = build_accessibility_tree(doc)

// ARIA Snapshot (Playwright互換)
let yaml = tree.to_aria_snapshot()
// Output:
// - navigation "Main Nav":
//   - link "Home"
//   - link "Products"
// - main:
//   - heading "Welcome" [level=1]
//   - button "Login"

// インタラクティブ要素を取得
let interactive = find_interactive(tree)
for node in interactive {
  // node.role, node.name, node.bounds
}
```

### Layout 統合

LayoutTree と AccessibilityTree を統合して、各アクセシビリティノードに座標情報を付与。

```moonbit
// HTML と LayoutTree から bounds 付きツリーを構築
let layout_tree = @tree.LayoutTree::from_html_document(doc, 800.0, 600.0)
let _ = layout_tree.calculate_layout(800.0, 600.0)
let a11y_tree = build_accessibility_tree_with_layout(doc, layout_tree)

// 各ノードは bounds を持つ
match a11y_tree.find_by_source_id("login-btn") {
  Some(node) => {
    // node.role = Button
    // node.name = Some("ログイン")
    // node.bounds = Some(Bounds { x: 300, y: 100, width: 100, height: 40 })
  }
  None => ()
}

// または手動で bounds を抽出してアタッチ
let bounds_map = extract_bounds_from_layout(layout_tree)
let tree_with_bounds = attach_bounds(a11y_tree, bounds_map)
```

#### 用途

| 機能 | 説明 |
|------|------|
| Hit Testing | 座標からクリック対象を特定 |
| キーボードナビゲーション | Y座標順にフォーカス移動 |
| スクリーンリーダー | 要素位置の読み上げ |
| AI TUI Browser | セマンティクス+座標でUI操作 |

### AI TUI Browser との統合

```
┌──────────────────────────────────────────────────────────────┐
│                      AI Agent                                │
│   Input: 「ログインボタンをクリック」                          │
└──────────────────────────────────────┬───────────────────────┘
                                       │
                                       ▼
┌──────────────────────────────────────────────────────────────┐
│              AccessibilityTree (AOM)                          │
│   → role="button" name="ログイン" を検索                      │
│   → bounds: (300, 100, 400, 140) を取得                      │
└──────────────────────────────────────┬───────────────────────┘
                                       │
                                       ▼
┌──────────────────────────────────────────────────────────────┐
│              ContentReadiness (webvitals)                     │
│   → is_interaction_ready() で操作可能か判定                   │
└──────────────────────────────────────────────────────────────┘
```

## Unsupported Features Policy

### Float

`float` is intentionally deferred due to implementation complexity:
- Requires BFC (Block Formatting Context) handling
- Complex interaction with `clear`, `overflow`, inline elements
- Modern layouts should use Flex/Grid instead

**Current behavior**: When `float` is detected, emit a warning and treat as normal block flow.

```moonbit
// Proposed warning API
pub enum LayoutWarning {
  UnsupportedFloat(String)  // node id
  UnsupportedPosition(String)
}
```

## TODO

### Text and Image Placeholder Handling

Text element widths depend on font rendering, which is complex to implement. For CLS calculation purposes, we need a simpler approach:

- Allow users to provide placeholder dimensions for text/image elements
- Support a "pre-calculated width" that can be passed in
- Check if line wrapping would occur within a given container width
- This enables layout estimation without full font rendering

Proposed API:

```moonbit
// Placeholder for intrinsic content size
pub struct IntrinsicSize {
  width : Double?   // Pre-measured or estimated width
  height : Double?  // Pre-measured or estimated height
}

// Node with intrinsic content
pub struct Node {
  id : String
  style : Style
  intrinsic : IntrinsicSize?  // For text/image elements
  children : Array[Node]
}
```

Use cases:
1. Server-side rendering: Estimate text dimensions from character count
2. Client-side: Pass actual measured dimensions from browser
3. Testing: Use fixed placeholder dimensions

### Hit Testing

Point-based hit testing to identify which element is at a given coordinate:

```moonbit
// Find element at point (x, y) in layout tree
pub fn hit_test(layout : Layout, x : Double, y : Double) -> Layout?

// Find all elements containing point (for nested elements)
pub fn hit_test_all(layout : Layout, x : Double, y : Double) -> Array[Layout]
```

Use cases:
1. Click handling: Identify clicked element
2. Hover detection: Find element under cursor
3. Touch handling: Identify tapped element
4. Accessibility: Navigate between elements

### Image Resource Lifecycle and Paint Integration

画像リソースのライフサイクル管理と Paint 層との連携設計。

#### Resource States

```
┌─────────────┐     headers     ┌─────────────┐     complete     ┌──────────┐
│  Pending    │ ───────────────>│  Sizing     │ ────────────────>│ Complete │
│ (placeholder)│                 │ (confirmed) │                  │ (render) │
└─────────────┘                 └─────────────┘                  └──────────┘
       │                              │                                │
       │          error               │           error                │
       └──────────────────────────────┴────────────────────────────────┘
                                      │
                                      v
                               ┌──────────┐
                               │  Error   │
                               │ (24x24)  │
                               └──────────┘
```

#### State Definitions

```moonbit
/// Extended resource state for paint layer integration
pub(all) enum ImageResourceState {
  /// Initial: No size info, using HTML default placeholder (300x150)
  /// Or using width/height attributes if specified
  Pending(placeholder_width~ : Double, placeholder_height~ : Double)

  /// Headers received: Actual dimensions known from response headers
  /// Layout can use accurate size, but no pixel data yet
  Sizing(width~ : Double, height~ : Double)

  /// Partial download: Progressive data available
  /// Contains decode progress (0.0-1.0) for progressive rendering
  Streaming(width~ : Double, height~ : Double, progress~ : Double)

  /// Complete: Full image data available
  Complete(width~ : Double, height~ : Double)

  /// Error: Load failed, use error placeholder (24x24)
  Error
}
```

#### Paint Layer Interface

```moonbit
/// Callback from LayoutTree to Paint layer
pub(all) struct PaintCallbacks {
  /// Called when resource state changes and repaint may be needed
  on_resource_state_change : (ResourceId, ImageResourceState) -> Unit

  /// Called when layout shift occurs (for CLS calculation)
  on_layout_shift : (node_id : String, old_rect : BoundingRect, new_rect : BoundingRect) -> Unit
}

/// Paint layer queries
pub trait PaintQuery {
  /// Get current paint data for a resource (texture ID, decode state, etc.)
  get_paint_data(ResourceId) -> PaintData?

  /// Check if resource has renderable content
  is_renderable(ResourceId) -> Bool
}

/// Abstract paint data (implementation-specific)
pub(all) struct PaintData {
  /// Texture/surface reference for rendering
  texture_id : Int?

  /// Current decode/render progress (0.0-1.0)
  progress : Double

  /// Whether progressive rendering is available
  supports_progressive : Bool
}
```

#### LayoutTree Extensions for Paint Integration

```moonbit
impl LayoutTree {
  /// Register paint callbacks for state change notifications
  fn set_paint_callbacks(self, callbacks : PaintCallbacks) -> Unit

  /// Update resource state from network layer
  /// Triggers paint callback if state changes
  fn update_resource_state(
    self,
    rid : ResourceId,
    state : ImageResourceState,
  ) -> Unit

  /// Calculate layout shift score (CLS metric)
  /// Returns shift score for nodes that moved after resource resolution
  fn calculate_layout_shift(self) -> Double
}
```

#### Typical Flow

```
External System          LayoutTree              Paint Layer
      │                       │                       │
      │  register_resource()  │                       │
      │──────────────────────>│                       │
      │  ResourceId           │                       │
      │<──────────────────────│                       │
      │                       │                       │
      │  [HTTP request...]    │                       │
      │                       │                       │
      │  update_resource_state│                       │
      │  (Sizing)             │                       │
      │──────────────────────>│ on_resource_state_change
      │                       │──────────────────────>│
      │                       │ [invalidate region]   │
      │                       │                       │
      │  compute_incremental()│                       │
      │──────────────────────>│                       │
      │  Layout (with shift)  │                       │
      │<──────────────────────│ on_layout_shift       │
      │                       │──────────────────────>│
      │                       │ [record CLS]          │
      │                       │                       │
      │  [Download progress]  │                       │
      │  update_resource_state│                       │
      │  (Streaming 0.5)      │                       │
      │──────────────────────>│ on_resource_state_change
      │                       │──────────────────────>│
      │                       │ [progressive repaint] │
      │                       │                       │
      │  update_resource_state│                       │
      │  (Complete)           │                       │
      │──────────────────────>│ on_resource_state_change
      │                       │──────────────────────>│
      │                       │ [final render]        │
```

#### CLS (Cumulative Layout Shift) Calculation

```moonbit
/// Track layout shifts for CLS metric
pub struct LayoutShiftEntry {
  node_id : String
  old_rect : BoundingRect
  new_rect : BoundingRect
  shift_score : Double  // viewport_fraction * distance_fraction
}

impl LayoutTree {
  /// Compute layout and track shifts from previous layout
  fn compute_with_shift_tracking(self) -> (Layout, Array[LayoutShiftEntry])

  /// Calculate CLS score from shift entries
  fn calculate_cls(shifts : Array[LayoutShiftEntry], viewport : Size) -> Double
}
```

#### Progressive Rendering Support

For formats that support progressive decoding (JPEG, interlaced PNG):

```moonbit
/// Progressive image data
pub(all) enum ProgressiveData {
  /// JPEG: DC coefficients only (very blurry preview)
  JpegDC

  /// JPEG: First few AC coefficients (blurry)
  JpegPartial(scans~ : Int)

  /// PNG: Interlace pass (1-7)
  PngInterlace(pass~ : Int)

  /// Full resolution
  Complete
}

/// Paint layer can query decode state for rendering decisions
impl PaintQuery {
  fn get_progressive_state(ResourceId) -> ProgressiveData?
}
```

#### Implementation Notes

1. **Decoupling**: LayoutTree only manages dimensions and state; actual image data lives in Paint layer
2. **Lazy Evaluation**: Paint callbacks are optional; layout works standalone for testing
3. **Batching**: Multiple state changes can be batched before triggering repaint
4. **Memory**: Only track ResourceId → state mapping; pixel data handled externally

### Future Features

- [x] `position: absolute/fixed` layout ✅
- [x] `overflow-x/overflow-y` in Layout ✅
- [ ] `z-index` stacking context (for hit testing order)
- [ ] Overflow clipping during rendering

## Web Platform Tests (WPT) Status

Tests from [web-platform-tests](https://github.com/web-platform-tests/wpt), compared against Chromium:

| Module | Passed | Total | Rate |
|--------|--------|-------|------|
| css-flexbox | 151 | 234 | 65% |
| css-grid | 16 | 30 | 53% |
| css-sizing | 18 | 50 | 36% |
| css-overflow | 5 | 20 | 25% |
| css-position | 4 | 30 | 13% |

### WPT Failure Categories

1. **Baseline alignment** - Not yet implemented
2. **Writing modes** (vertical-lr, vertical-rl) - Not implemented
3. **flex-wrap: wrap-reverse** - Alignment issues
4. **position: relative** with negative offsets - Not handled
5. **Table elements** (thead, tbody, caption) - Not implemented

## Test Porting Plan

### Phase 1: taffy Test Suite (Current)

Port tests from [taffy](https://github.com/DioxusLabs/taffy) - a Rust flexbox/grid layout engine.

**Completed categories:**
- [x] Basic flex row/column
- [x] flex-grow / flex-shrink
- [x] justify-content (all values)
- [x] align-items / align-self
- [x] flex-wrap (single/multi-line)
- [x] gap (row-gap, column-gap)
- [x] align-content (for wrapped lines)
- [x] min/max constraints

**Pending categories:**
- [x] margin: auto (centering)
- [x] aspect-ratio
- [x] wrap-reverse
- [x] position: absolute
- [x] baseline alignment
- [x] Complex nested scenarios (explicit sizes)
- [ ] Complex nested scenarios (intrinsic sizing) - requires 2-pass layout
- [ ] Edge cases (overflow, negative space)

### Phase 2: MDN/WHATWG Spec Tests

Add tests based on CSS specification examples:

- [ ] CSS Flexible Box Layout Module Level 1 (W3C)
  - https://www.w3.org/TR/css-flexbox-1/
- [ ] CSS Box Alignment Module Level 3
  - https://www.w3.org/TR/css-align-3/
- [ ] MDN Flexbox examples
  - https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout

### Phase 3: Real-World Layout Tests

Create tests from common UI patterns:
- [ ] Navigation bars
- [ ] Card layouts
- [ ] Form layouts
- [ ] Dashboard grids
- [ ] Responsive patterns

### Test Coverage Goals

| Feature | taffy | MDN/Spec | Real-world |
|---------|-------|----------|------------|
| Block layout | ✅ (~95%) | - | - |
| Flex row | ✅ (~90%) | - | - |
| Flex column | ✅ (~90%) | - | - |
| Flex wrap | ✅ | - | - |
| Gap | ✅ | - | - |
| Alignment | ✅ (~85%) | - | - |
| Grid basic | ✅ (~85%) | - | - |
| Grid span | ⚠️ partial | - | - |
| Grid baseline | ⚠️ partial | - | - |
| display: none | ❌ | - | - |
| Intrinsic sizing | ⚠️ partial | - | - |
