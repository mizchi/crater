# crater/browser — JS 実行可能ブラウザ実装計画

## ゴール

crater の HTML/CSS パーサ + レイアウトエンジン + V8 JS ランタイムを組み合わせて、
native で動作する JS 実行可能なブラウザを構築する。

## アーキテクチャ

```
HTML + <script> 入力
    ↓
HTML パーサ (crater/html)
    ↓
DOM ツリー (crater/dom)  ←→  V8 JS Runtime (js_v8/)
    ↓                           ↑ mock DOM ops
CSS 解決 (crater/css)            ↓ domOps round-trip
    ↓
レイアウト (crater/layout)
    ↓
Paint ツリー (crater/paint)
    ↓
GPU レンダリング (kagura wgpu) or 画像出力
```

## 完了済み

### Phase 1: V8 基本統合
- [x] `js_v8/` パッケージに `V8JsRuntime` を作成（`JsRuntime` trait 実装）
- [x] basic eval + console.log/warn/error capture
- [x] エラーハンドリング（try-catch → JsResult）
- [x] `JsContext::new_with_runtime()` で V8 を注入可能に
- [x] `AsyncExecutionMode` を `pub(all)` 化（外部パッケージから利用可能に）
- [x] `JsError::execution_error()` factory（外部 suberror 生成用）
- [x] V8 consumer prebuild 設定（cc-link-flags）

### Phase 2: mock DOM + 非同期モデル
- [x] quickjs の 388KB inline JS から mock DOM JS を外部ファイル `mock_dom.js` に抽出
- [x] `V8JsRuntime::new_with_mock_dom(js_source)` で mock DOM を V8 に注入
- [x] execute フロー: eval → `perform_microtask_checkpoint()` → `_runOneTimeout()` loop → 結果収集
- [x] DOM 操作の round-trip（createElement, appendChild, setAttribute 等 → domOps JSON → MoonBit DomTree 更新）
- [x] Promise/setTimeout 実行順序が WPT 準拠（sync → microtask → task）
- [x] minimal mock DOM（テスト用軽量版: Element, Node, Event, document, setTimeout, querySelector）
- [x] native テスト 14/14 PASS

## 現在のオープンタスク

### P0: mock DOM 完全化

- [ ] `mock_dom.js`（7608行フル版）を V8 で実行確認
  minimal 版（213行）は通っている。フル版には以下が含まれる:
  - 60+ HTML 要素タイプ（HTMLDivElement, HTMLInputElement 等）
  - CSS セレクタマッチング（querySelector/querySelectorAll の完全版）
  - MutationObserver の実動作
  - Fetch API mock
  - 完全な Event システム（bubbling, capturing, stopPropagation）
  - classList, NamedNodeMap, attributes collection
  - innerHTML/outerHTML パーサ

- [x] JS runtime テストの native 移植
  34 テスト PASS: basic eval (7) + minimal mock DOM (7) + full mock DOM (7) + DOM ops (13)

### P1: WPT テスト対応

- [x] `task_microtask_ordering.html` Test 1: Basic task and microtask ordering
  V8 native で PASS: script start → script end → promise1 → promise2 → setTimeout
- [ ] `task_microtask_ordering.html` Test 2: Level 1 bossfight (synthetic click)
  **ブロッカー**: フル mock DOM の `HTMLElement.click()` が空 stub。
  `dispatchEvent(new MouseEvent('click', { bubbles: true }))` を呼ぶように修正が必要。
  修正後の期待値: click → click → promise → mutate → promise → timeout → timeout

- [ ] WPT DOM テストの V8 native ランナー作成
  `scripts/wpt-dom-runner.ts` は Node.js vm + mock DOM で 9296 テスト通過済み。
  V8 native で同じテストを実行するランナーを MoonBit で書く。

- [ ] `microtask_after_script.html` — スクリプト実行後の microtask スケジューリング
- [ ] `microtask_after_raf.html` — requestAnimationFrame と microtask の相互作用

### P2: `<script>` タグ実行パイプライン

- [ ] HTML パーサの `<script>` タグ処理と V8 実行を接続
  `browser/src/shell/browser.mbt` の `execute_inline_js()` が起点。
  現在は JS target で quickjs を使っている。native では V8JsRuntime を使う。

- [ ] script 実行順序の保証
  - parser-blocking script（同期実行）
  - async script（パース完了後に実行）
  - defer script（DOMContentLoaded 前に実行）
  - `ScriptExecutor` (`scheduler_integration.mbt`) との統合

- [ ] DOM 変更の再レイアウトトリガー
  JS が DOM を変更した後、レイアウトを再計算してレンダリングに反映する仕組み。

### P3: レンダリングパイプライン統合

- [ ] crater_renderer の PaintNode → GPU コマンド変換を crater/browser に統合
  `kagura/examples/crater_renderer/src/main.mbt` のパターン:
  1. `@renderer.render_to_node()` → Node ツリー
  2. `@renderer.render()` → Layout ツリー
  3. `@paint.from_node_and_layout()` → PaintNode ツリー
  4. 再帰的に GPU コマンド生成

- [ ] headless wgpu + crater layout → BMP 出力
  kagura の `init_headless_context()` + `save_screenshot()` を使って、
  HTML/CSS をレンダリングした結果を画像ファイルに書き出す。

- [ ] テキストレンダリング
  native では TTF フォント（mizchi/font）またはドットマトリクスフォールバック。
  TextMetricsProvider を実装して crater のレイアウトエンジンに接続。

### P4: end-to-end デモ

- [ ] HTML + `<script>` → パース → JS 実行 → DOM 更新 → レイアウト → レンダリング → 画面/BMP
  最小の動作デモ:
  ```html
  <div id="app"></div>
  <script>
    document.getElementById('app').textContent = 'Hello from V8!';
  </script>
  ```
  これが native wgpu でレンダリングされ、BMP に書き出せることを検証。

- [ ] native VRT snapshot テスト
  kagura の native_vrt パターンを使い、HTML/JS レンダリング結果の regression testing。

## JsRuntime trait 設計

他の JS エンジン実装（quickjs-native, mquickjs, SpiderMonkey 等）も差し替え可能:

```moonbit
pub(open) trait JsRuntime {
  init(Self) -> Unit
  execute(Self, Int, DomTree, String, AsyncExecutionMode) -> JsResult raise JsError
  tick(Self, Int, DomTree) -> JsResult raise JsError
}

// 使用例
let rt = V8JsRuntime::new_with_mock_dom(mock_js)
let ctx = JsContext::new_with_runtime(dom, rt.as_js_runtime())
ctx.execute("document.title = 'Hello'")
```

## 参照

- V8 バインディング: `mizchi/v8` (mooncakes, rusty_v8 ベース)
- レンダリング: `kagura/examples/crater_renderer/`
- レイアウトエンジン: `mizchi/crater` (Taffy ポート)
- WPT テスト: `wpt/dom/nodes/`, `wpt/html/webappapis/scripting/event-loops/`
- 既存 JS テスト: `browser/src/js/js_runtime_js_test.mbt` (166 テスト)
