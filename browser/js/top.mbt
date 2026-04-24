///|
pub using @runtime_impl {
  type AsyncExecutionMode,
  type JsContext,
  type JsError,
  type JsResult,
  type ScriptExecutor,
  trait JsRuntime,
}

///|
pub fn create_dom_init_code(dom : @dom.DomTree) -> String {
  @runtime_impl.create_dom_init_code(dom)
}

///|
pub fn enqueue_script(
  scheduler : @scheduler.Scheduler,
  source : String,
  blocking : Bool,
) -> @scheduler.TaskId {
  @runtime_impl.enqueue_script(scheduler, source, blocking)
}

///|
pub fn enqueue_script_after(
  scheduler : @scheduler.Scheduler,
  source : String,
  dependencies : Array[@scheduler.TaskId],
  blocking : Bool,
) -> @scheduler.TaskId {
  @runtime_impl.enqueue_script_after(scheduler, source, dependencies, blocking)
}

///|
pub fn execute_script_task(
  task : @scheduler.Task,
  dom : @dom.DomTree,
) -> @scheduler.TaskResult {
  @runtime_impl.execute_script_task(task, dom)
}

///|
pub fn init_js_runtime() -> Unit {
  @runtime_impl.init_js_runtime()
}

///|
pub fn process_script_tasks(
  scheduler : @scheduler.Scheduler,
  dom : @dom.DomTree,
) -> Int {
  @runtime_impl.process_script_tasks(scheduler, dom)
}

///|
pub fn serialize_dom_for_mock(dom : @dom.DomTree) -> String {
  @runtime_impl.serialize_dom_for_mock(dom)
}

///|
pub fn serialize_dom_to_html(dom : @dom.DomTree) -> String {
  @runtime_impl.serialize_dom_to_html(dom)
}

///|
pub fn serialize_dom_to_snapshot_html(dom : @dom.DomTree) -> String {
  @runtime_impl.serialize_dom_to_snapshot_html(dom)
}
