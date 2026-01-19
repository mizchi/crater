///|
/// Layout Tree Integration with Scheduler
/// LayoutTree とスケジューラの統合

// =============================================================================
// Layout Manager
// =============================================================================

///|
/// レイアウト管理 - LayoutTree とスケジューラを統合
pub struct LayoutManager {
  scheduler : Scheduler
  /// レイアウトツリー (初期化後に設定)
  mut layout_tree : @tree.LayoutTree?
  /// 最後のレイアウト結果
  mut last_layout : @types.Layout?
  /// レイアウトパス統計
  mut full_layout_count : Int
  mut incremental_layout_count : Int
  /// 画像リソースID -> スケジューラタスクID のマッピング
  image_tasks : Map[Int, TaskId]
}

///|
pub fn LayoutManager::new(scheduler : Scheduler) -> LayoutManager {
  {
    scheduler,
    layout_tree: None,
    last_layout: None,
    full_layout_count: 0,
    incremental_layout_count: 0,
    image_tasks: {},
  }
}

// =============================================================================
// Tree Initialization
// =============================================================================

///|
/// LayoutTree を設定
pub fn LayoutManager::set_tree(
  self : LayoutManager,
  tree : @tree.LayoutTree,
) -> Unit {
  self.layout_tree = Some(tree)
  self.last_layout = None
}

///|
/// Node から LayoutTree を構築して設定
pub fn LayoutManager::build_tree(
  self : LayoutManager,
  root : @node.Node,
  viewport_width : Double,
  viewport_height : Double,
) -> Unit {
  let tree = @tree.LayoutTree::from_node(root, viewport_width, viewport_height)
  self.set_tree(tree)
}

///|
/// HTML Document から LayoutTree を構築
pub fn LayoutManager::build_tree_from_html(
  self : LayoutManager,
  doc : @html.Document,
  viewport_width : Double,
  viewport_height : Double,
) -> Unit {
  let tree = @tree.LayoutTree::from_html_document(
    doc, viewport_width, viewport_height,
  )
  self.set_tree(tree)
}

///|
/// LayoutTree への参照を取得
pub fn LayoutManager::get_tree(self : LayoutManager) -> @tree.LayoutTree? {
  self.layout_tree
}

// =============================================================================
// Layout Scheduling
// =============================================================================

///|
/// レイアウト計算タスクをスケジュール
pub fn LayoutManager::schedule_layout(self : LayoutManager) -> TaskId {
  self.scheduler.enqueue(ComputeLayout, MainThreadOnly)
}

///|
/// 依存タスク完了後にレイアウトをスケジュール
pub fn LayoutManager::schedule_layout_after(
  self : LayoutManager,
  dependencies : Array[TaskId],
) -> TaskId {
  self.scheduler.enqueue_after(ComputeLayout, MainThreadOnly, dependencies)
}

///|
/// 高優先度でレイアウトをスケジュール（ユーザーインタラクション時など）
pub fn LayoutManager::schedule_layout_urgent(self : LayoutManager) -> TaskId {
  self.scheduler.enqueue_with_priority(ComputeLayout, MainThreadOnly, 100)
}

// =============================================================================
// Layout Execution
// =============================================================================

///|
/// レイアウト計算を実行 (タスク完了時に呼ばれる)
pub fn LayoutManager::execute_layout(
  self : LayoutManager,
  incremental? : Bool = true,
) -> LayoutComputeResult {
  match self.layout_tree {
    Some(tree) => {
      let layout = if incremental && tree.needs_layout() {
        self.incremental_layout_count += 1
        tree.compute_incremental()
      } else {
        self.full_layout_count += 1
        tree.compute_full()
      }
      self.last_layout = Some(layout)
      {
        layout,
        was_incremental: incremental,
        pending_images: tree.get_pending_resources().length(),
      }
    }
    None => {
      // ツリーがない場合はダミーレイアウトを返す
      let empty_layout : @types.Layout = {
        id: "",
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: @types.Rect::all(0.0),
        padding: @types.Rect::all(0.0),
        border: @types.Rect::all(0.0),
        overflow_x: @types.Overflow::Visible,
        overflow_y: @types.Overflow::Visible,
        children: [],
        text: None,
      }
      { layout: empty_layout, was_incremental: false, pending_images: 0 }
    }
  }
}

///|
/// レイアウト計算結果
pub(all) struct LayoutComputeResult {
  layout : @types.Layout
  was_incremental : Bool
  pending_images : Int
}

// =============================================================================
// Viewport Management
// =============================================================================

///|
/// ビューポートサイズ変更タスクをスケジュール
pub fn LayoutManager::schedule_resize(
  self : LayoutManager,
  width : Double,
  height : Double,
) -> ResizeResult {
  match self.layout_tree {
    Some(tree) => {
      // ビューポートをリサイズ (dirty フラグが設定される)
      tree.resize_viewport(width, height)
      // レイアウト再計算をスケジュール
      let layout_task = self.schedule_layout()
      { resized: true, layout_task: Some(layout_task) }
    }
    None => { resized: false, layout_task: None }
  }
}

///|
/// ビューポートリサイズ結果
pub(all) struct ResizeResult {
  resized : Bool
  layout_task : TaskId?
}

// =============================================================================
// Node Dirty Management
// =============================================================================

///|
/// ノードを dirty としてマーク
pub fn LayoutManager::mark_node_dirty(
  self : LayoutManager,
  node_uid : Int,
) -> Unit {
  match self.layout_tree {
    Some(tree) => tree.mark_node_dirty(node_uid)
    None => ()
  }
}

///|
/// ノードのスタイルを更新
pub fn LayoutManager::update_node_style(
  self : LayoutManager,
  node_id : String,
  values : @cascade.CascadedValues,
) -> Bool {
  match self.layout_tree {
    Some(tree) => tree.update_node_style(node_id, values)
    None => false
  }
}

///|
/// 複数ノードのスタイルを一括更新
pub fn LayoutManager::batch_update_styles(
  self : LayoutManager,
  updates : Array[(String, @cascade.CascadedValues)],
) -> Int {
  match self.layout_tree {
    Some(tree) => tree.batch_update_styles(updates)
    None => 0
  }
}

// =============================================================================
// Image Resource Integration
// =============================================================================

///|
/// 画像デコードタスクをスケジュール
pub fn LayoutManager::schedule_image_decode(
  self : LayoutManager,
  resource_id : @tree.ResourceId,
) -> TaskId {
  let @tree.ResourceId(rid) = resource_id
  let task_id = self.scheduler.enqueue(DecodeImage(resource_id=rid), Parallel)
  self.image_tasks[rid] = task_id
  task_id
}

///|
/// 画像リソースを登録してデコードタスクをスケジュール
pub fn LayoutManager::register_and_decode_image(
  self : LayoutManager,
  node_uid : Int,
  placeholder_width? : Double = 300.0,
  placeholder_height? : Double = 150.0,
) -> ImageRegistration {
  match self.layout_tree {
    Some(tree) => {
      let resource_id = tree.register_resource(
        node_uid,
        placeholder_width~,
        placeholder_height~,
      )
      let decode_task = self.schedule_image_decode(resource_id)
      { resource_id, decode_task, registered: true }
    }
    None =>
      {
        resource_id: @tree.ResourceId(0),
        decode_task: TaskId(0),
        registered: false,
      }
  }
}

///|
/// 画像登録結果
pub(all) struct ImageRegistration {
  resource_id : @tree.ResourceId
  decode_task : TaskId
  registered : Bool
}

///|
/// 画像デコード完了時の処理
pub fn LayoutManager::on_image_decoded(
  self : LayoutManager,
  resource_id : @tree.ResourceId,
  width : Double,
  height : Double,
) -> TaskId? {
  match self.layout_tree {
    Some(tree) => {
      tree.resolve_resource(resource_id, width, height)
      // レイアウト再計算をスケジュール
      Some(self.schedule_layout())
    }
    None => None
  }
}

///|
/// 画像ロード失敗時の処理
pub fn LayoutManager::on_image_failed(
  self : LayoutManager,
  resource_id : @tree.ResourceId,
) -> TaskId? {
  match self.layout_tree {
    Some(tree) => {
      tree.fail_resource(resource_id)
      Some(self.schedule_layout())
    }
    None => None
  }
}

///|
/// 保留中の画像リソースを取得
pub fn LayoutManager::get_pending_images(
  self : LayoutManager,
) -> Array[@tree.ResourceId] {
  match self.layout_tree {
    Some(tree) => tree.get_pending_resources()
    None => []
  }
}

// =============================================================================
// Statistics
// =============================================================================

///|
/// レイアウト統計を取得
pub fn LayoutManager::get_stats(self : LayoutManager) -> LayoutStats {
  {
    full_layout_count: self.full_layout_count,
    incremental_layout_count: self.incremental_layout_count,
    pending_images: match self.layout_tree {
      Some(tree) => tree.get_pending_resources().length()
      None => 0
    },
  }
}

///|
/// レイアウト統計
pub(all) struct LayoutStats {
  full_layout_count : Int
  incremental_layout_count : Int
  pending_images : Int
}

// =============================================================================
// Document Render Coordinator
// =============================================================================

///|
/// ドキュメントレンダリング調整 - HTML/CSS/Layout を統合
pub struct DocumentRenderCoordinator {
  scheduler : Scheduler
  style_coordinator : DocumentStyleCoordinator
  layout_manager : LayoutManager
  /// レンダリング準備完了フラグ
  mut ready_for_render : Bool
}

///|
pub fn DocumentRenderCoordinator::new(
  scheduler : Scheduler,
) -> DocumentRenderCoordinator {
  {
    scheduler,
    style_coordinator: DocumentStyleCoordinator::new(scheduler),
    layout_manager: LayoutManager::new(scheduler),
    ready_for_render: false,
  }
}

///|
/// HTMLパース結果を処理して初期レンダリングパイプラインを開始
pub fn DocumentRenderCoordinator::process_html(
  self : DocumentRenderCoordinator,
  parse_result : ParseCompleteResult,
  discovered : ResourceDiscoveryResult,
  viewport_width : Double,
  viewport_height : Double,
) -> RenderPipelineResult {
  // スタイルシートを登録
  self.style_coordinator.register_stylesheets(parse_result, discovered)

  // LayoutTree を構築
  let doc : @html.Document = {
    root: parse_result.root,
    stylesheets: [],
    stylesheet_links: [],
  }
  self.layout_manager.build_tree_from_html(doc, viewport_width, viewport_height)

  // 画像リソースを登録
  let image_tasks = register_html_images(
    self.layout_manager,
    parse_result.root,
    discovered,
  )

  // スタイル計算準備ができていればレイアウトをスケジュール
  let layout_task : TaskId? = if self.style_coordinator.is_ready_for_style() {
    Some(self.layout_manager.schedule_layout())
  } else {
    None
  }
  {
    style_ready: self.style_coordinator.is_ready_for_style(),
    layout_task,
    image_decode_tasks: image_tasks,
  }
}

///|
/// レンダリングパイプライン結果
pub(all) struct RenderPipelineResult {
  style_ready : Bool
  layout_task : TaskId?
  image_decode_tasks : Array[TaskId]
}

///|
/// HTML から画像を発見してデコードタスクを登録
fn register_html_images(
  _layout_manager : LayoutManager,
  _root : @html.Element,
  discovered : ResourceDiscoveryResult,
) -> Array[TaskId] {
  let tasks : Array[TaskId] = []

  // 発見されたイメージリソースに対してデコードタスクを生成
  for resource in discovered.resources {
    if resource.resource_type == Image {
      // ノードUIDは HTML -> LayoutTree マッピングが必要
      // 簡略化: ここでは URL をキーにした処理は外部に委譲
      ()
    }
  }
  tasks
}

///|
/// スタイルシートフェッチ完了時
pub fn DocumentRenderCoordinator::on_stylesheet_fetched(
  self : DocumentRenderCoordinator,
  css_source : String,
) -> CSSParseResult {
  let result = self.style_coordinator.on_stylesheet_fetched(css_source)

  // スタイル準備完了ならレイアウトをスケジュール
  if self.style_coordinator.is_ready_for_style() && not(self.ready_for_render) {
    let _ = self.layout_manager.schedule_layout()
    self.ready_for_render = true
  }
  result
}

///|
/// レイアウトマネージャへのアクセス
pub fn DocumentRenderCoordinator::get_layout_manager(
  self : DocumentRenderCoordinator,
) -> LayoutManager {
  self.layout_manager
}

///|
/// スタイルコーディネータへのアクセス
pub fn DocumentRenderCoordinator::get_style_coordinator(
  self : DocumentRenderCoordinator,
) -> DocumentStyleCoordinator {
  self.style_coordinator
}

///|
/// レンダリング準備完了か
pub fn DocumentRenderCoordinator::is_ready_for_render(
  self : DocumentRenderCoordinator,
) -> Bool {
  self.ready_for_render
}
