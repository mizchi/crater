///|
/// Scheduler Integration - Executes ExecuteScript tasks from scheduler
///
/// Bridges the JS runtime with the browser's task scheduler.

///|
/// Script executor that runs in the scheduler event loop
pub struct ScriptExecutor {
  /// DOM tree for script execution
  dom : @dom.DomTree
  /// JS context (reused across executions)
  ctx : JsContext
}

///|
/// Create a new script executor
pub fn ScriptExecutor::new(dom : @dom.DomTree) -> ScriptExecutor {
  { dom, ctx: JsContext::new(dom) }
}

///|
/// Get accumulated logs from the JS context
pub fn ScriptExecutor::get_logs(self : ScriptExecutor) -> Array[String] {
  self.ctx.get_logs()
}

///|
/// Clear accumulated logs
pub fn ScriptExecutor::clear_logs(self : ScriptExecutor) -> Unit {
  self.ctx.clear_logs()
}

///|
/// Enqueue a script for execution
pub fn enqueue_script(
  scheduler : @scheduler.Scheduler,
  source : String,
  blocking : Bool,
) -> @scheduler.TaskId {
  let constraint = if blocking {
    // Parser-blocking script blocks DOM parsing
    @scheduler.Blocking([@scheduler.DOM])
  } else {
    @scheduler.MainThreadOnly
  }
  // Async/defer script runs on main thread but doesn't block
  scheduler.enqueue(@scheduler.ExecuteScript(source~), constraint)
}

///|
/// Enqueue a script with dependencies
pub fn enqueue_script_after(
  scheduler : @scheduler.Scheduler,
  source : String,
  dependencies : Array[@scheduler.TaskId],
  blocking : Bool,
) -> @scheduler.TaskId {
  let constraint = if blocking {
    @scheduler.Blocking([@scheduler.DOM])
  } else {
    @scheduler.MainThreadOnly
  }
  scheduler.enqueue_after(
    @scheduler.ExecuteScript(source~),
    constraint,
    dependencies,
  )
}
