///|
/// Scheduler - Task scheduling and dependency management
/// ブラウザの Event Loop / Task Scheduler に相当

// =============================================================================
// Blocked Sources Tracking
// =============================================================================

///|
/// ブロック中のソースを追跡
struct BlockedSources {
  sources : @hashset.HashSet[TaskSource]
}

///|
fn BlockedSources::new() -> BlockedSources {
  { sources: @hashset.new() }
}

///|
fn BlockedSources::block(self : BlockedSources, source : TaskSource) -> Unit {
  self.sources.add(source)
}

///|
fn BlockedSources::unblock(self : BlockedSources, source : TaskSource) -> Unit {
  self.sources.remove(source)
}

///|
fn BlockedSources::is_blocked(
  self : BlockedSources,
  source : TaskSource,
) -> Bool {
  self.sources.contains(source)
}

// =============================================================================
// Scheduler
// =============================================================================

///|
/// スケジューラ本体
pub struct Scheduler {
  /// 全タスクのマップ（高速検索用）
  tasks : Map[Int, Task]
  /// 実行可能なタスクキュー
  ready_queue : TaskQueue
  /// ソース別キュー管理
  source_queues : SourceQueueManager
  /// ブロック中のソース
  blocked : BlockedSources
  /// 完了したタスクのID（依存解決用）
  completed_ids : @hashset.HashSet[Int]
}

///|
pub fn Scheduler::new() -> Scheduler {
  {
    tasks: {},
    ready_queue: TaskQueue::new(),
    source_queues: SourceQueueManager::new(),
    blocked: BlockedSources::new(),
    completed_ids: @hashset.new(),
  }
}

// =============================================================================
// Task Enqueueing
// =============================================================================

///|
/// タスクを追加
pub fn Scheduler::enqueue(
  self : Scheduler,
  action : TaskAction,
  constraint : TaskConstraint,
) -> TaskId {
  let task = Task::new(action, constraint)
  self.add_task(task)
}

///|
/// 依存関係付きでタスクを追加
pub fn Scheduler::enqueue_after(
  self : Scheduler,
  action : TaskAction,
  constraint : TaskConstraint,
  dependencies : Array[TaskId],
) -> TaskId {
  let task = Task::new(action, constraint, dependencies~)
  self.add_task(task)
}

///|
/// 優先度付きでタスクを追加
pub fn Scheduler::enqueue_with_priority(
  self : Scheduler,
  action : TaskAction,
  constraint : TaskConstraint,
  priority : Int,
) -> TaskId {
  let task = Task::new(action, constraint, priority~)
  self.add_task(task)
}

///|
/// 内部: タスクを追加して管理構造に登録
fn Scheduler::add_task(self : Scheduler, task : Task) -> TaskId {
  let TaskId(id) = task.id

  // タスクマップに追加
  self.tasks[id] = task

  // ソース別キューに追加
  self.source_queues.push(task)

  // 依存関係をチェックして Ready なら ready_queue にも追加
  if task.is_ready() {
    self.ready_queue.push(task)
  }
  task.id
}

// =============================================================================
// Dependency Resolution
// =============================================================================

///|
/// 依存関係を解決して Ready 状態に昇格
pub fn Scheduler::resolve_dependencies(self : Scheduler) -> Int {
  let mut promoted = 0

  // 全タスクをチェック
  self.tasks.each(fn(_id, task) {
    // Pending 状態のタスクのみ処理
    match task.state {
      Pending => {
        // 全ての依存タスクが完了しているかチェック
        let mut all_deps_completed = true
        for dep_id in task.dependencies {
          let TaskId(dep_int) = dep_id
          if not(self.completed_ids.contains(dep_int)) {
            all_deps_completed = false
            break
          }
        }
        if all_deps_completed {
          // Ready に昇格
          task.state = Ready
          self.ready_queue.push(task)
          promoted += 1
        }
      }
      _ => ()
    }
  })
  promoted
}

// =============================================================================
// Task Polling (外部ランタイムが呼ぶ)
// =============================================================================

///|
/// 実行可能なタスクをすべて取得（状態を Running に変更）
pub fn Scheduler::poll_ready(self : Scheduler) -> Array[Task] {
  let ready = self.ready_queue.get_ready()

  // ブロックされているソースのタスクを除外
  let unblocked : Array[Task] = ready.filter(fn(task) {
    not(self.blocked.is_blocked(task.source))
  })

  // 優先度でソート（高い順）
  unblocked.sort_by(fn(a, b) { b.priority - a.priority })

  // 状態を Running に変更
  for task in unblocked {
    task.mark_running()
  }
  unblocked
}

///|
/// 並列実行可能なタスクのみ取得
pub fn Scheduler::poll_parallel(self : Scheduler) -> Array[Task] {
  let parallel = self.ready_queue.get_parallel_ready()

  // ブロックされているソースのタスクを除外
  let unblocked : Array[Task] = parallel.filter(fn(task) {
    not(self.blocked.is_blocked(task.source))
  })

  // 優先度でソート（高い順）
  unblocked.sort_by(fn(a, b) { b.priority - a.priority })

  // 状態を Running に変更
  for task in unblocked {
    task.mark_running()
  }
  unblocked
}

///|
/// メインスレッド専用タスクのみ取得（1つずつ）
pub fn Scheduler::poll_main_thread(self : Scheduler) -> Task? {
  let main_tasks = self.ready_queue.get_main_thread_ready()

  // ブロックされているソースのタスクを除外して、最初の1つを返す
  for task in main_tasks {
    if not(self.blocked.is_blocked(task.source)) {
      task.mark_running()
      return Some(task)
    }
  }
  None
}

// =============================================================================
// Task Completion
// =============================================================================

///|
/// タスク完了を通知（成功）
pub fn Scheduler::complete(
  self : Scheduler,
  task_id : TaskId,
  result : TaskResult,
) -> Array[TaskId] {
  let TaskId(id) = task_id
  match self.tasks.get(id) {
    Some(task) =>
      match result {
        Success(new_tasks~) => {
          task.mark_completed()
          self.completed_ids.add(id)

          // Blocking 制約を解除
          self.release_blocks(task)

          // 新しいタスクを追加
          let new_ids : Array[TaskId] = []
          for action in new_tasks {
            let new_id = self.enqueue(action, MainThreadOnly)
            new_ids.push(new_id)
          }

          // 依存関係を解決
          let _ = self.resolve_dependencies()
          new_ids
        }
        Failure(error~) => {
          task.mark_failed(error)
          self.release_blocks(task)
          []
        }
        Cancelled => {
          task.mark_cancelled()
          self.release_blocks(task)
          []
        }
      }
    None => []
  }
}

///|
/// タスク失敗を通知（ショートカット）
pub fn Scheduler::fail(
  self : Scheduler,
  task_id : TaskId,
  error : String,
) -> Unit {
  let _ = self.complete(task_id, Failure(error~))

}

///|
/// タスクキャンセルを通知（ショートカット）
pub fn Scheduler::cancel(self : Scheduler, task_id : TaskId) -> Unit {
  let _ = self.complete(task_id, Cancelled)

}

///|
/// Blocking 制約を解除
fn Scheduler::release_blocks(self : Scheduler, task : Task) -> Unit {
  match task.constraint {
    Blocking(sources) =>
      for source in sources {
        self.blocked.unblock(source)
      }
    _ => ()
  }
}

// =============================================================================
// Blocking Management
// =============================================================================

///|
/// タスクの Blocking 制約を適用
pub fn Scheduler::apply_blocks(self : Scheduler, task : Task) -> Unit {
  match task.constraint {
    Blocking(sources) =>
      for source in sources {
        self.blocked.block(source)
      }
    _ => ()
  }
}

///|
/// 特定のソースがブロックされているか確認
pub fn Scheduler::is_source_blocked(
  self : Scheduler,
  source : TaskSource,
) -> Bool {
  self.blocked.is_blocked(source)
}

// =============================================================================
// Status and Queries
// =============================================================================

///|
/// 全タスク数を取得
pub fn Scheduler::task_count(self : Scheduler) -> Int {
  self.tasks.length()
}

///|
/// Ready 状態のタスク数を取得
pub fn Scheduler::ready_count(self : Scheduler) -> Int {
  self.ready_queue.get_ready().length()
}

///|
/// Pending 状態のタスク数を取得
pub fn Scheduler::pending_count(self : Scheduler) -> Int {
  let mut count = 0
  self.tasks.each(fn(_id, task) {
    match task.state {
      Pending => count += 1
      _ => ()
    }
  })
  count
}

///|
/// Running 状態のタスク数を取得
pub fn Scheduler::running_count(self : Scheduler) -> Int {
  let mut count = 0
  self.tasks.each(fn(_id, task) {
    match task.state {
      Running => count += 1
      _ => ()
    }
  })
  count
}

///|
/// タスクを検索
pub fn Scheduler::find_task(self : Scheduler, task_id : TaskId) -> Task? {
  let TaskId(id) = task_id
  self.tasks.get(id)
}

///|
/// すべての処理が完了したか確認
pub fn Scheduler::is_idle(self : Scheduler) -> Bool {
  self.pending_count() == 0 &&
  self.running_count() == 0 &&
  self.ready_count() == 0
}

///|
/// 完了したタスクをクリーンアップ
pub fn Scheduler::cleanup(self : Scheduler) -> Int {
  let mut removed = 0

  // 終了状態のタスクを削除
  let to_remove : Array[Int] = []
  self.tasks.each(fn(id, task) { if task.is_terminal() { to_remove.push(id) } })
  for id in to_remove {
    self.tasks.remove(id)
    removed += 1
  }

  // キューもクリーンアップ
  let _ = self.ready_queue.cleanup()
  let _ = self.source_queues.cleanup()
  removed
}
