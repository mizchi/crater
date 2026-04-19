///|
/// Task Scheduler Types
/// Browser Event Loop / Task Queue に相当する型定義

// =============================================================================
// Task Identifier
// =============================================================================

///|
/// Unique task identifier
pub(all) struct TaskId(Int) derive(Eq, Hash, Debug)

///|
/// ID generator (mutable state in struct)
priv struct TaskIdGenerator {
  mut next_id : Int
}

///|
let task_id_gen : TaskIdGenerator = { next_id: 0 }

///|
fn TaskId::next() -> TaskId {
  let id = task_id_gen.next_id
  task_id_gen.next_id += 1
  TaskId(id)
}

///|
/// Reset task ID counter (for testing)
pub fn reset_task_id_counter() -> Unit {
  task_id_gen.next_id = 0
}

// =============================================================================
// Task Source (Browser Task Source に相当)
// =============================================================================

///|
/// タスクの発生源
pub(all) enum TaskSource {
  /// DOM操作（パース、ツリー構築）
  DOM
  /// スタイル計算
  Styling
  /// レイアウト計算
  Layout
  /// リソースフェッチ（外部委譲）
  Networking
  /// スクリプト実行（外部委譲）
  Scripting
  /// 画像デコード（外部委譲）
  ImageDecode
} derive(Eq, Hash, Debug)

// =============================================================================
// Task Constraint (実行制約)
// =============================================================================

///|
/// タスクの実行制約
pub(all) enum TaskConstraint {
  /// メインスレッド必須（DOM操作など）
  MainThreadOnly
  /// 並列実行可能（画像デコード、一部のスタイル計算）
  Parallel
  /// 他のタスクソースをブロック（parser-blocking script）
  Blocking(Array[TaskSource])
} derive(Debug)

///|
/// Check if a task can run in parallel
pub fn TaskConstraint::is_parallel(self : TaskConstraint) -> Bool {
  match self {
    Parallel => true
    _ => false
  }
}

///|
/// Check if a task blocks a specific source
pub fn TaskConstraint::blocks(
  self : TaskConstraint,
  source : TaskSource,
) -> Bool {
  match self {
    Blocking(sources) => sources.contains(source)
    _ => false
  }
}

// =============================================================================
// Resource Type
// =============================================================================

///|
/// リソースの種類
pub(all) enum ResourceType {
  /// HTML ドキュメント
  Document
  /// スタイルシート
  Stylesheet
  /// JavaScript
  Script
  /// 画像
  Image
  /// フォント
  Font
  /// その他
  Other
} derive(Eq, Debug)

// =============================================================================
// Task State
// =============================================================================

///|
/// タスクの状態
pub(all) enum TaskState {
  /// 依存タスク待ち
  Pending
  /// 実行可能（依存解決済み）
  Ready
  /// 実行中（外部で実行中）
  Running
  /// 完了
  Completed
  /// キャンセル
  Cancelled
  /// 失敗
  Failed(String)
} derive(Debug)

///|
pub fn TaskState::is_terminal(self : TaskState) -> Bool {
  match self {
    Completed | Cancelled | Failed(_) => true
    _ => false
  }
}

///|
pub fn TaskState::is_runnable(self : TaskState) -> Bool {
  match self {
    Ready => true
    _ => false
  }
}

// =============================================================================
// Task Action (実行内容)
// =============================================================================

///|
/// タスクの実行内容
pub(all) enum TaskAction {
  // -------------------------------------------------------------------------
  // 内部実行可能（同期的に実行可能）
  // -------------------------------------------------------------------------
  /// HTMLチャンクをパース
  ParseHTMLChunk(html~ : String)
  /// CSSをパース
  ParseCSS(source~ : String)
  /// スタイル計算（指定ノードまたは全体）
  ComputeStyle(node_ids~ : Array[String])
  /// レイアウト計算
  ComputeLayout

  // -------------------------------------------------------------------------
  // 外部委譲（非同期実行が必要）
  // -------------------------------------------------------------------------
  /// リソースフェッチ
  FetchResource(url~ : String, resource_type~ : ResourceType)
  /// 画像デコード
  DecodeImage(resource_id~ : Int)
  /// スクリプト実行
  ExecuteScript(source~ : String)
} derive(Debug)

///|
pub impl Show for TaskId with output(self, logger) {
  logger.write_string("TaskId(\{self.0})")
}

///|
pub impl Show for TaskSource with output(self, logger) {
  let name = match self {
    DOM => "DOM"
    Styling => "Styling"
    Layout => "Layout"
    Networking => "Networking"
    Scripting => "Scripting"
    ImageDecode => "ImageDecode"
  }
  logger.write_string(name)
}

///|
pub impl Show for TaskConstraint with output(self, logger) {
  match self {
    MainThreadOnly => logger.write_string("MainThreadOnly")
    Parallel => logger.write_string("Parallel")
    Blocking(sources) => logger.write_string("Blocking(\{sources})")
  }
}

///|
pub impl Show for ResourceType with output(self, logger) {
  let name = match self {
    Document => "Document"
    Stylesheet => "Stylesheet"
    Script => "Script"
    Image => "Image"
    Font => "Font"
    Other => "Other"
  }
  logger.write_string(name)
}

///|
pub impl Show for TaskState with output(self, logger) {
  match self {
    Pending => logger.write_string("Pending")
    Ready => logger.write_string("Ready")
    Running => logger.write_string("Running")
    Completed => logger.write_string("Completed")
    Cancelled => logger.write_string("Cancelled")
    Failed(error) => {
      logger.write_string("Failed(")
      logger.write_string("\"")
      logger.write_string(error)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for TaskAction with output(self, logger) {
  match self {
    ParseHTMLChunk(html~) => {
      logger.write_string("ParseHTMLChunk(html=")
      logger.write_string("\"")
      logger.write_string(html)
      logger.write_string("\"")
      logger.write_string(")")
    }
    ParseCSS(source~) => {
      logger.write_string("ParseCSS(source=")
      logger.write_string("\"")
      logger.write_string(source)
      logger.write_string("\"")
      logger.write_string(")")
    }
    ComputeStyle(node_ids~) =>
      logger.write_string("ComputeStyle(node_ids=\{node_ids})")
    ComputeLayout => logger.write_string("ComputeLayout")
    FetchResource(url~, resource_type~) => {
      logger.write_string("FetchResource(url=")
      logger.write_string("\"")
      logger.write_string(url)
      logger.write_string("\"")
      logger.write_string(", resource_type=\{resource_type})")
    }
    DecodeImage(resource_id~) =>
      logger.write_string("DecodeImage(resource_id=\{resource_id})")
    ExecuteScript(source~) => {
      logger.write_string("ExecuteScript(source=")
      logger.write_string("\"")
      logger.write_string(source)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for TaskResult with output(self, logger) {
  match self {
    Success(new_tasks~) =>
      logger.write_string("Success(new_tasks=\{new_tasks})")
    Failure(error~) => {
      logger.write_string("Failure(error=")
      logger.write_string("\"")
      logger.write_string(error)
      logger.write_string("\"")
      logger.write_string(")")
    }
    Cancelled => logger.write_string("Cancelled")
  }
}

///|
/// Check if action can be executed internally (synchronously)
pub fn TaskAction::is_internal(self : TaskAction) -> Bool {
  match self {
    ParseHTMLChunk(_) | ParseCSS(_) | ComputeStyle(_) | ComputeLayout => true
    FetchResource(_) | DecodeImage(_) | ExecuteScript(_) => false
  }
}

///|
/// Get the task source for this action
pub fn TaskAction::source(self : TaskAction) -> TaskSource {
  match self {
    ParseHTMLChunk(_) => DOM
    ParseCSS(_) => Styling
    ComputeStyle(_) => Styling
    ComputeLayout => Layout
    FetchResource(_) => Networking
    DecodeImage(_) => ImageDecode
    ExecuteScript(_) => Scripting
  }
}

// =============================================================================
// Task Result
// =============================================================================

///|
/// タスクの実行結果
pub(all) enum TaskResult {
  /// 成功（追加タスクを生成する場合がある）
  Success(new_tasks~ : Array[TaskAction])
  /// 失敗
  Failure(error~ : String)
  /// キャンセル
  Cancelled
} derive(Debug)

// =============================================================================
// Task
// =============================================================================

///|
/// タスク本体
pub(all) struct Task {
  /// 一意な識別子
  id : TaskId
  /// タスクの種類
  source : TaskSource
  /// 実行制約
  constraint : TaskConstraint
  /// 依存するタスク（これらが完了するまで実行不可）
  dependencies : Array[TaskId]
  /// 実行内容
  action : TaskAction
  /// 現在の状態
  mut state : TaskState
  /// 優先度（高いほど優先）
  priority : Int
}

///|
pub fn Task::new(
  action : TaskAction,
  constraint : TaskConstraint,
  dependencies? : Array[TaskId] = [],
  priority? : Int = 0,
) -> Task {
  {
    id: TaskId::next(),
    source: action.source(),
    constraint,
    dependencies,
    action,
    state: if dependencies.is_empty() {
      Ready
    } else {
      Pending
    },
    priority,
  }
}

///|
pub fn Task::is_ready(self : Task) -> Bool {
  self.state.is_runnable()
}

///|
pub fn Task::is_parallel(self : Task) -> Bool {
  self.constraint.is_parallel()
}

///|
pub fn Task::is_completed(self : Task) -> Bool {
  match self.state {
    Completed => true
    _ => false
  }
}

///|
pub fn Task::is_terminal(self : Task) -> Bool {
  self.state.is_terminal()
}

///|
pub fn Task::mark_running(self : Task) -> Unit {
  self.state = Running
}

///|
pub fn Task::mark_completed(self : Task) -> Unit {
  self.state = Completed
}

///|
pub fn Task::mark_failed(self : Task, error : String) -> Unit {
  self.state = Failed(error)
}

///|
pub fn Task::mark_cancelled(self : Task) -> Unit {
  self.state = Cancelled
}
