///|
/// Scheduler Integration - JS target implementation

///|
/// Execute a script task and return the result for scheduler
pub fn execute_script_task(
  task : @scheduler.Task,
  dom : @dom.DomTree,
) -> @scheduler.TaskResult {
  match task.action {
    @scheduler.ExecuteScript(source~) => {
      let ctx = JsContext::new(dom)
      try {
        let _ = ctx.execute(source)
        @scheduler.Success(new_tasks=[])
      } catch {
        err => @scheduler.Failure(error=err.to_string())
      }
    }
    _ => @scheduler.Failure(error="Not an ExecuteScript task")
  }
}

///|
/// Process script tasks from scheduler
pub fn process_script_tasks(
  scheduler : @scheduler.Scheduler,
  dom : @dom.DomTree,
) -> Int {
  let mut processed = 0
  let ready_tasks = scheduler.poll_ready()
  for task in ready_tasks {
    match task.action {
      @scheduler.ExecuteScript(_) => {
        let result = execute_script_task(task, dom)
        let _ = scheduler.complete(task.id, result)
        processed = processed + 1
      }
      _ => ()
    }
  }
  processed
}

///|
/// Execute a script task using ScriptExecutor
pub fn ScriptExecutor::execute(
  self : ScriptExecutor,
  task : @scheduler.Task,
) -> @scheduler.TaskResult {
  match task.action {
    @scheduler.ExecuteScript(source~) =>
      try {
        let result = self.ctx.execute(source)
        for log in result.logs {
          println("[JS] " + log)
        }
        @scheduler.Success(new_tasks=[])
      } catch {
        err => @scheduler.Failure(error=err.to_string())
      }
    _ => @scheduler.Failure(error="Not an ExecuteScript task")
  }
}
