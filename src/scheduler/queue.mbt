///|
/// Task Queue Management
/// タスクキューの管理と優先度付きソート

// =============================================================================
// Task Queue
// =============================================================================

///|
/// 基本的なタスクキュー
pub struct TaskQueue {
  /// キュー内のタスク
  tasks : Array[Task]
}

///|
pub fn TaskQueue::new() -> TaskQueue {
  { tasks: [] }
}

///|
/// Add a task to the queue
pub fn TaskQueue::push(self : TaskQueue, task : Task) -> Unit {
  self.tasks.push(task)
}

///|
/// Get the number of tasks in the queue
pub fn TaskQueue::length(self : TaskQueue) -> Int {
  self.tasks.length()
}

///|
/// Check if the queue is empty
pub fn TaskQueue::is_empty(self : TaskQueue) -> Bool {
  self.tasks.is_empty()
}

///|
/// Get all ready tasks (does not remove them)
pub fn TaskQueue::get_ready(self : TaskQueue) -> Array[Task] {
  self.tasks.filter(fn(t) { t.is_ready() })
}

///|
/// Get all parallel-capable ready tasks
pub fn TaskQueue::get_parallel_ready(self : TaskQueue) -> Array[Task] {
  self.tasks.filter(fn(t) { t.is_ready() && t.is_parallel() })
}

///|
/// Get all main-thread-only ready tasks
pub fn TaskQueue::get_main_thread_ready(self : TaskQueue) -> Array[Task] {
  self.tasks.filter(fn(t) { t.is_ready() && not(t.is_parallel()) })
}

///|
/// Remove a task by ID
pub fn TaskQueue::remove(self : TaskQueue, task_id : TaskId) -> Task? {
  let mut found_idx : Int? = None
  for i, task in self.tasks {
    if task.id == task_id {
      found_idx = Some(i)
      break
    }
  }
  match found_idx {
    Some(idx) => Some(self.tasks.remove(idx))
    None => None
  }
}

///|
/// Find a task by ID
pub fn TaskQueue::find(self : TaskQueue, task_id : TaskId) -> Task? {
  for task in self.tasks {
    if task.id == task_id {
      return Some(task)
    }
  }
  None
}

///|
/// Get all tasks (for iteration)
pub fn TaskQueue::iter(self : TaskQueue) -> Iter[Task] {
  self.tasks.iter()
}

///|
/// Remove all completed/cancelled/failed tasks
pub fn TaskQueue::cleanup(self : TaskQueue) -> Int {
  let initial_len = self.tasks.length()
  let remaining : Array[Task] = self.tasks.filter(fn(t) { not(t.is_terminal()) })
  // Swap contents
  self.tasks.clear()
  for task in remaining {
    self.tasks.push(task)
  }
  initial_len - self.tasks.length()
}

///|
/// Sort by priority (higher priority first)
pub fn TaskQueue::sort_by_priority(self : TaskQueue) -> Unit {
  self.tasks.sort_by(fn(a, b) { b.priority - a.priority })
}

// =============================================================================
// Source Queue Manager (ソース別キュー管理)
// =============================================================================

///|
/// ソース別にキューを管理
pub struct SourceQueueManager {
  queues : Map[TaskSource, TaskQueue]
}

///|
pub fn SourceQueueManager::new() -> SourceQueueManager {
  let queues : Map[TaskSource, TaskQueue] = {}
  // Initialize queues for each source
  queues[DOM] = TaskQueue::new()
  queues[Styling] = TaskQueue::new()
  queues[Layout] = TaskQueue::new()
  queues[Networking] = TaskQueue::new()
  queues[Scripting] = TaskQueue::new()
  queues[ImageDecode] = TaskQueue::new()
  { queues, }
}

///|
/// Get queue for a specific source
pub fn SourceQueueManager::get_queue(
  self : SourceQueueManager,
  source : TaskSource,
) -> TaskQueue {
  match self.queues.get(source) {
    Some(q) => q
    None => {
      // Should not happen, but create if missing
      let q = TaskQueue::new()
      self.queues[source] = q
      q
    }
  }
}

///|
/// Add task to appropriate source queue
pub fn SourceQueueManager::push(self : SourceQueueManager, task : Task) -> Unit {
  self.get_queue(task.source).push(task)
}

///|
/// Get total task count across all queues
pub fn SourceQueueManager::total_count(self : SourceQueueManager) -> Int {
  let mut count = 0
  self.queues.each(fn(_source, queue) { count += queue.length() })
  count
}

///|
/// Get all ready tasks from all queues
pub fn SourceQueueManager::get_all_ready(
  self : SourceQueueManager,
) -> Array[Task] {
  let result : Array[Task] = []
  self.queues.each(fn(_source, queue) {
    for task in queue.get_ready() {
      result.push(task)
    }
  })
  result
}

///|
/// Get ready tasks from a specific source
pub fn SourceQueueManager::get_ready_by_source(
  self : SourceQueueManager,
  source : TaskSource,
) -> Array[Task] {
  self.get_queue(source).get_ready()
}

///|
/// Find task by ID across all queues
pub fn SourceQueueManager::find(
  self : SourceQueueManager,
  task_id : TaskId,
) -> Task? {
  let mut result : Task? = None
  self.queues.each(fn(_source, queue) {
    match queue.find(task_id) {
      Some(t) => result = Some(t)
      None => ()
    }
  })
  result
}

///|
/// Remove task by ID from appropriate queue
pub fn SourceQueueManager::remove(
  self : SourceQueueManager,
  task_id : TaskId,
) -> Task? {
  let mut result : Task? = None
  self.queues.each(fn(_source, queue) {
    match queue.remove(task_id) {
      Some(t) => result = Some(t)
      None => ()
    }
  })
  result
}

///|
/// Cleanup all queues
pub fn SourceQueueManager::cleanup(self : SourceQueueManager) -> Int {
  let mut total = 0
  self.queues.each(fn(_source, queue) { total += queue.cleanup() })
  total
}
