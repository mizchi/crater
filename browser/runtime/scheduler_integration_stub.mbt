///|
/// Scheduler Integration - Stub for non-JS targets

///|
/// Execute a script task (not supported on this target)
pub fn execute_script_task(
  task : @scheduler.Task,
  dom : @dom.DomTree,
) -> @scheduler.TaskResult {
  let _ = task
  let _ = dom
  @scheduler.Failure(error="JavaScript execution not supported on this target")
}

///|
/// Process script tasks (not supported on this target)
pub fn process_script_tasks(
  scheduler : @scheduler.Scheduler,
  dom : @dom.DomTree,
) -> Int {
  let _ = scheduler
  let _ = dom
  0
}

///|
/// Execute a script task (not supported on this target)
pub fn ScriptExecutor::execute(
  self : ScriptExecutor,
  task : @scheduler.Task,
) -> @scheduler.TaskResult {
  let _ = self
  let _ = task
  @scheduler.Failure(error="JavaScript execution not supported on this target")
}
