///|
/// Browser-like Scenario Tests
/// ブラウザのようにリソースを段階的に解決してレンダリングを確定するシナリオテスト

// =============================================================================
// Mock Async Runtime
// =============================================================================

// Note: MockTaskState は将来の拡張用に定義。現在は使用していない。

///|
/// モック非同期ランタイム - 外部の非同期処理をシミュレート
struct MockAsyncRuntime {
  /// 保留中のネットワークリクエスト (task_id -> url)
  pending_fetches : Map[Int, String]
  /// 保留中の画像デコード (task_id -> resource_id)
  pending_decodes : Map[Int, Int]
  /// 完了したレスポンス (url -> response)
  responses : Map[String, String]
  /// 画像サイズ (resource_id -> (width, height))
  image_sizes : Map[Int, (Double, Double)]
  /// 処理ログ
  logs : Array[String]
}

///|
fn MockAsyncRuntime::new() -> MockAsyncRuntime {
  {
    pending_fetches: {},
    pending_decodes: {},
    responses: {},
    image_sizes: {},
    logs: [],
  }
}

///|
/// レスポンスを事前に設定
fn MockAsyncRuntime::set_response(
  self : MockAsyncRuntime,
  url : String,
  response : String,
) -> Unit {
  self.responses[url] = response
}

///|
/// 画像サイズを事前に設定
fn MockAsyncRuntime::set_image_size(
  self : MockAsyncRuntime,
  resource_id : Int,
  width : Double,
  height : Double,
) -> Unit {
  self.image_sizes[resource_id] = (width, height)
}

///|
/// フェッチタスクを登録
fn MockAsyncRuntime::register_fetch(
  self : MockAsyncRuntime,
  task_id : TaskId,
  url : String,
) -> Unit {
  let TaskId(id) = task_id
  self.pending_fetches[id] = url
  self.logs.push("FETCH: \{url}")
}

///|
/// デコードタスクを登録
fn MockAsyncRuntime::register_decode(
  self : MockAsyncRuntime,
  task_id : TaskId,
  resource_id : Int,
) -> Unit {
  let TaskId(id) = task_id
  self.pending_decodes[id] = resource_id
  self.logs.push("DECODE: resource_\{resource_id}")
}

///|
/// 特定のフェッチを完了させる
fn MockAsyncRuntime::complete_fetch(
  self : MockAsyncRuntime,
  scheduler : Scheduler,
  url : String,
) -> Bool {
  let mut found_id : Int? = None
  self.pending_fetches.each(fn(id, u) { if u == url { found_id = Some(id) } })
  match found_id {
    Some(id) => {
      self.pending_fetches.remove(id)
      match self.responses.get(url) {
        Some(_response) => {
          self.logs.push("COMPLETE: \{url}")
          let _ = scheduler.complete(TaskId(id), Success(new_tasks=[]))
          true
        }
        None => {
          self.logs.push("FAILED: \{url} (no response)")
          scheduler.fail(TaskId(id), "No response configured")
          false
        }
      }
    }
    None => false
  }
}

///|
/// 特定のデコードを完了させる
fn MockAsyncRuntime::complete_decode(
  self : MockAsyncRuntime,
  scheduler : Scheduler,
  resource_id : Int,
) -> Bool {
  let mut found_id : Int? = None
  self.pending_decodes.each(fn(id, rid) {
    if rid == resource_id {
      found_id = Some(id)
    }
  })
  match found_id {
    Some(id) => {
      self.pending_decodes.remove(id)
      self.logs.push("DECODED: resource_\{resource_id}")
      let _ = scheduler.complete(TaskId(id), Success(new_tasks=[]))
      true
    }
    None => false
  }
}

///|
/// 保留中のタスク数
fn MockAsyncRuntime::pending_count(self : MockAsyncRuntime) -> Int {
  self.pending_fetches.length() + self.pending_decodes.length()
}

// =============================================================================
// Rendering Pipeline Simulator
// =============================================================================

// Note: RenderingState は将来のレンダリング状態追跡用に定義予定

// =============================================================================
// Scenario: Basic HTML with External CSS
// =============================================================================

///|
test "scenario: HTML with external CSS loading" {
  reset_task_id_counter()
  @dispatch.setup()

  // === Setup ===
  let scheduler = Scheduler::new()
  let runtime = MockAsyncRuntime::new()

  // 外部CSSのレスポンスを設定
  runtime.set_response(
    "styles.css", ".container { display: flex; width: 400px; } .item { width: 100px; height: 50px; }",
  )

  // === Phase 1: HTML Parse ===
  let html =
    #|<html>
    #|<head><link rel="stylesheet" href="styles.css"></head>
    #|<body>
    #|  <div class="container">
    #|    <div class="item">A</div>
    #|    <div class="item">B</div>
    #|  </div>
    #|</body>
    #|</html>
  let coordinator = DocumentRenderCoordinator::new(scheduler)

  // HTMLをパース
  let root = @html.parse_fragment_v2(html)
  let discovered = discover_resources(root)

  // スタイルシートリンクを発見
  inspect(discovered.resources.length(), content="1")
  inspect(discovered.resources[0].url, content="styles.css")
  inspect(discovered.resources[0].blocking, content="true")

  // === Phase 2: スタイルシートフェッチをスケジュール ===
  // フェッチタスクを手動でスケジュール
  let _fetch_task = scheduler.enqueue(
    FetchResource(url="styles.css", resource_type=Stylesheet),
    Blocking([Styling]),
  )

  // 実行可能タスクを取得してモックランタイムに登録
  let ready_tasks = scheduler.poll_ready()
  inspect(ready_tasks.length(), content="1")
  for task in ready_tasks {
    match task.action {
      FetchResource(url~, resource_type=_) => {
        runtime.register_fetch(task.id, url)
        task.mark_running()
      }
      _ => ()
    }
  }

  // この時点ではスタイルはまだ未解決
  inspect(runtime.pending_count(), content="1")

  // === Phase 3: CSSフェッチ完了 ===
  let completed = runtime.complete_fetch(scheduler, "styles.css")
  inspect(completed, content="true")

  // スタイルシートを適用
  let css_source = runtime.responses.get("styles.css").unwrap()
  let result = coordinator.on_stylesheet_fetched(css_source)
  inspect(result.rule_count, content="2")

  // === Phase 4: レイアウト計算 ===
  // CSS取得完了でレンダリング準備完了
  inspect(coordinator.is_ready_for_render(), content="true")

  // ログを確認
  inspect(runtime.logs.length(), content="2")
  inspect(runtime.logs[0], content="FETCH: styles.css")
  inspect(runtime.logs[1], content="COMPLETE: styles.css")
}

// =============================================================================
// Scenario: HTML with Images
// =============================================================================

///|
test "scenario: HTML with images - progressive loading" {
  reset_task_id_counter()
  @dispatch.setup()

  // === Setup ===
  let scheduler = Scheduler::new()
  let runtime = MockAsyncRuntime::new()

  // 画像サイズを設定 (実際の解像度)
  runtime.set_image_size(0, 640.0, 480.0)
  runtime.set_image_size(1, 800.0, 600.0)

  // === HTML with images ===
  let html =
    #|<div style="display: flex; width: 1000px;">
    #|  <img id="img1" src="photo1.jpg">
    #|  <img id="img2" src="photo2.jpg" width="200" height="150">
    #|</div>
  let root = @html.parse_fragment_v2(html)
  let discovered = discover_resources(root)

  // 画像リソースを発見
  inspect(discovered.resources.length(), content="2")

  // === Phase 1: 初期レイアウト (プレースホルダーサイズ) ===
  let layout_manager = LayoutManager::new(scheduler)

  // LayoutTree を構築 (実際にはここで LayoutNode を作成する必要がある)
  // 簡略化: 手動でレイアウトタスクをスケジュール
  let _layout_task = layout_manager.schedule_layout()
  inspect(scheduler.task_count(), content="1")

  // === Phase 2: 画像デコードをスケジュール ===
  // 画像デコードタスクを追加
  let _decode_task1 = scheduler.enqueue(DecodeImage(resource_id=0), Parallel)
  let _decode_task2 = scheduler.enqueue(DecodeImage(resource_id=1), Parallel)

  // 並列タスクを取得
  let parallel_tasks = scheduler.poll_parallel()
  inspect(parallel_tasks.length(), content="2")

  // モックランタイムに登録
  for task in parallel_tasks {
    match task.action {
      DecodeImage(resource_id~) => {
        runtime.register_decode(task.id, resource_id)
        task.mark_running()
      }
      _ => ()
    }
  }

  // === Phase 3: 画像1のデコード完了 ===
  let decoded1 = runtime.complete_decode(scheduler, 0)
  inspect(decoded1, content="true")

  // この時点で部分的なレイアウト更新が可能
  // (画像1は確定サイズ、画像2はまだプレースホルダー)

  // === Phase 4: 画像2のデコード完了 ===
  let decoded2 = runtime.complete_decode(scheduler, 1)
  inspect(decoded2, content="true")

  // 全画像のデコード完了
  inspect(runtime.pending_count(), content="0")

  // ログを確認
  inspect(runtime.logs.length(), content="4")
}

// =============================================================================
// Scenario: Complete Page Load Lifecycle
// =============================================================================

///|
test "scenario: complete page load lifecycle" {
  reset_task_id_counter()
  @dispatch.setup()

  // === Setup ===
  let scheduler = Scheduler::new()
  let runtime = MockAsyncRuntime::new()

  // レスポンスを設定
  runtime.set_response(
    "main.css", ".header { height: 60px; } .content { display: flex; }",
  )
  runtime.set_response("analytics.js", "console.log('loaded');")
  runtime.set_image_size(0, 200.0, 100.0) // logo

  // === HTML ===
  let html =
    #|<html>
    #|<head>
    #|  <link rel="stylesheet" href="main.css">
    #|</head>
    #|<body>
    #|  <header class="header">
    #|    <img id="logo" src="logo.png">
    #|  </header>
    #|  <main class="content">
    #|    <p>Hello World</p>
    #|  </main>
    #|  <script src="analytics.js" async></script>
    #|</body>
    #|</html>

  // === Phase 1: HTML Parse & Resource Discovery ===
  let root = @html.parse_fragment_v2(html)
  let discovered = discover_resources(root)

  // 発見されたリソース
  let stylesheets = discovered.filter_by_type(Stylesheet)
  let images = discovered.filter_by_type(Image)
  let scripts = discovered.filter_by_type(Script)
  inspect(stylesheets.length(), content="1")
  inspect(images.length(), content="1")
  inspect(scripts.length(), content="1")

  // async script は blocking ではない
  inspect(scripts[0].is_async, content="true")
  inspect(scripts[0].blocking, content="false")

  // === Phase 2: Critical Path - CSS First ===
  // CSSはレンダリングブロッキング
  let _css_fetch = scheduler.enqueue(
    FetchResource(url="main.css", resource_type=Stylesheet),
    Blocking([Styling, Layout]),
  )

  // 画像とスクリプトは並列で取得可能
  let _img_fetch = scheduler.enqueue(
    FetchResource(url="logo.png", resource_type=Image),
    Parallel,
  )
  let _script_fetch = scheduler.enqueue(
    FetchResource(url="analytics.js", resource_type=Script),
    Parallel,
  )

  // タスク状態を確認
  inspect(scheduler.task_count(), content="3")

  // ready タスクを取得
  // Blocking制約は「実行中に他のソースをブロックする」という意味で、
  // タスク自体のReady状態には影響しない
  // poll_ready() は全タスク（Parallel含む）を返し、Runningにマーク
  let ready = scheduler.poll_ready()
  inspect(ready.length(), content="3")

  // poll_ready()で既にRunningになっているため、poll_parallelは空
  let parallel = scheduler.poll_parallel()
  inspect(parallel.length(), content="0")

  // モックランタイムに登録 (poll_ready()で既にRunning状態)
  for task in ready {
    match task.action {
      FetchResource(url~, resource_type=_) =>
        runtime.register_fetch(task.id, url)
      // poll_ready()で既にRunningなのでmark_running()不要
      _ => ()
    }
  }

  // === Phase 3: CSS完了 → First Paint ===
  let _ = runtime.complete_fetch(scheduler, "main.css")

  // CSSが完了したので Styling/Layout はブロック解除
  inspect(scheduler.is_source_blocked(Styling), content="false")

  // === Phase 4: 画像完了 → Layout Shift ===
  let _ = runtime.complete_fetch(scheduler, "logo.png")

  // 画像の実サイズでレイアウト再計算が必要
  // (CLSが発生する可能性あり)

  // === Phase 5: Script完了 ===
  let _ = runtime.complete_fetch(scheduler, "analytics.js")

  // 全リソース完了
  inspect(runtime.pending_count(), content="0")

  // イベントログ
  inspect(runtime.logs.length(), content="6") // 3 fetch + 3 complete
}

// =============================================================================
// Scenario: Dependency Chain
// =============================================================================

///|
test "scenario: task dependency chain" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()

  // HTML Parse → CSS Parse → Style Compute → Layout の依存チェーン
  let html_task = scheduler.enqueue(
    ParseHTMLChunk(html="<div></div>"),
    MainThreadOnly,
  )
  let css_task = scheduler.enqueue_after(
    ParseCSS(source=".foo {}"),
    MainThreadOnly,
    [html_task],
  )
  let style_task = scheduler.enqueue_after(
    ComputeStyle(node_ids=["root"]),
    MainThreadOnly,
    [css_task],
  )
  let layout_task = scheduler.enqueue_after(ComputeLayout, MainThreadOnly, [
    style_task,
  ])

  // 初期状態: html_task のみ Ready
  inspect(scheduler.find_task(html_task).unwrap().state, content="Ready")
  inspect(scheduler.find_task(css_task).unwrap().state, content="Pending")
  inspect(scheduler.find_task(style_task).unwrap().state, content="Pending")
  inspect(scheduler.find_task(layout_task).unwrap().state, content="Pending")

  // HTML完了
  let _ = scheduler.complete(html_task, Success(new_tasks=[]))
  inspect(scheduler.find_task(css_task).unwrap().state, content="Ready")

  // CSS完了
  let _ = scheduler.complete(css_task, Success(new_tasks=[]))
  inspect(scheduler.find_task(style_task).unwrap().state, content="Ready")

  // Style完了
  let _ = scheduler.complete(style_task, Success(new_tasks=[]))
  inspect(scheduler.find_task(layout_task).unwrap().state, content="Ready")

  // Layout完了
  let _ = scheduler.complete(layout_task, Success(new_tasks=[]))
  inspect(scheduler.find_task(layout_task).unwrap().state, content="Completed")
}

// =============================================================================
// Scenario: Blocking Script
// =============================================================================

///|
test "scenario: parser-blocking script" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let runtime = MockAsyncRuntime::new()
  runtime.set_response("blocking.js", "document.write('hello');")

  // parser-blocking script はDOMをブロック
  let script_fetch_task = scheduler.enqueue(
    FetchResource(url="blocking.js", resource_type=Script),
    Blocking([DOM]),
  )

  // DOMタスク
  let _dom_task = scheduler.enqueue(
    ParseHTMLChunk(html="<p>after script</p>"),
    MainThreadOnly,
  )

  // まだブロックは適用されていない（タスク実行開始前）
  inspect(scheduler.is_source_blocked(DOM), content="false")

  // スクリプトタスクを実行開始 → ブロック適用
  match scheduler.find_task(script_fetch_task) {
    Some(task) => {
      task.mark_running()
      scheduler.apply_blocks(task)
    }
    None => panic()
  }

  // 今度はDOMがブロック
  inspect(scheduler.is_source_blocked(DOM), content="true")

  // DOM タスクは Ready にならない (ブロックされている)
  // script は既に Running なので poll_ready には出てこない
  let ready = scheduler.poll_ready()
  inspect(ready.length(), content="0")

  // モックランタイムにスクリプトタスクを登録
  runtime.register_fetch(script_fetch_task, "blocking.js")

  // スクリプト完了 (complete内でrelease_blocksが呼ばれる)
  let _ = runtime.complete_fetch(scheduler, "blocking.js")

  // ブロックが解除されている
  inspect(scheduler.is_source_blocked(DOM), content="false")

  // DOM タスクが Ready になる
  let ready2 = scheduler.poll_ready()
  inspect(ready2.length(), content="1")
  inspect(ready2[0].id, content="TaskId(1)")
}

// =============================================================================
// Scenario: Incremental Layout Updates
// =============================================================================

///|
test "scenario: incremental layout as resources load" {
  reset_task_id_counter()
  @dispatch.setup()
  let scheduler = Scheduler::new()
  let layout_manager = LayoutManager::new(scheduler)

  // === Initial Layout (no tree yet) ===
  let stats1 = layout_manager.get_stats()
  inspect(stats1.full_layout_count, content="0")
  inspect(stats1.incremental_layout_count, content="0")

  // === First Layout ===
  let _ = layout_manager.schedule_layout()
  let result1 = layout_manager.execute_layout()
  inspect(result1.was_incremental, content="false") // tree がないので false

  // === Simulate Resource Resolution ===
  // 画像リソースのモック解決
  let rid = @tree.ResourceId(42)
  let decode_task = layout_manager.schedule_image_decode(rid)

  // デコードタスクが並列実行可能
  match scheduler.find_task(decode_task) {
    Some(task) => inspect(task.constraint.is_parallel(), content="true")
    None => panic()
  }

  // stats を確認
  let stats2 = layout_manager.get_stats()
  inspect(stats2.pending_images, content="0") // tree がないので 0
}

// =============================================================================
// Scenario: Priority Handling
// =============================================================================

///|
test "scenario: urgent layout during interaction" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let layout_manager = LayoutManager::new(scheduler)

  // 通常のレイアウトタスク
  let normal_task = layout_manager.schedule_layout()

  // ユーザーインタラクション時の緊急レイアウト
  let urgent_task = layout_manager.schedule_layout_urgent()

  // 優先度を確認
  match scheduler.find_task(normal_task) {
    Some(task) => inspect(task.priority, content="0")
    None => panic()
  }
  match scheduler.find_task(urgent_task) {
    Some(task) => inspect(task.priority, content="100")
    None => panic()
  }

  // poll_ready は優先度順に返す
  let ready = scheduler.poll_ready()
  inspect(ready.length(), content="2")
  // urgent が先に来る
  inspect(ready[0].priority, content="100")
  inspect(ready[1].priority, content="0")
}
