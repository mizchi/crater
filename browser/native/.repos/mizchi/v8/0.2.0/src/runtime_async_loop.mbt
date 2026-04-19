///|
fn runtime_begin_async_loop(runtime : Runtime) -> Result[Unit, V8Error] {
  if runtime.state.val.async_loop.is_running {
    Err(V8Error::NativeError("runtime async event loop is already running"))
  } else {
    runtime.state.val.async_loop.is_running = true
    Ok(())
  }
}

///|
fn runtime_end_async_loop(runtime : Runtime) -> Unit {
  runtime.state.val.async_loop.is_running = false
}

///|
async fn run_async_json_task(
  runtime : Runtime,
  op : AsyncJsonOpRequest,
  handler : AsyncJsonTaskHandler,
) -> Unit {
  let result = (handler.callback)(op.payload_json)
  let settled = match result {
    Ok(payload_json) => runtime.resolve_async_json_op(op.id, payload_json)
    Err(error_json) if handler.use_json_error =>
      runtime.reject_async_json_op_with_json(op.id, error_json)
    Err(message) => runtime.reject_async_json_op(op.id, message)
  }
  guard settled is Ok(_) else { raise settled.unwrap_err() }
}

///|
async fn run_async_bytes_task(
  runtime : Runtime,
  op : AsyncBytesOpRequest,
  handler : AsyncBytesTaskHandler,
) -> Unit {
  let result = (handler.callback)(op.payload)
  let settled = match result {
    Ok(payload) => runtime.resolve_async_bytes_op(op.id, payload)
    Err(error_json) if handler.use_json_error =>
      runtime.reject_async_bytes_op_with_json(op.id, error_json)
    Err(message) => runtime.reject_async_bytes_op(op.id, message)
  }
  guard settled is Ok(_) else { raise settled.unwrap_err() }
}

///|
fn spawn_async_json_task(
  runtime : Runtime,
  group : @async.TaskGroup[Result[Unit, V8Error]],
  op : AsyncJsonOpRequest,
  handler : AsyncJsonTaskHandler,
) -> Unit {
  runtime.state.val.async_loop.pending_tasks += 1
  group.spawn_bg(no_wait=true, () => {
    defer {
      runtime.state.val.async_loop.pending_tasks = runtime.state.val.async_loop.pending_tasks -
        1
    }
    run_async_json_task(runtime, op, handler)
  })
}

///|
fn spawn_async_bytes_task(
  runtime : Runtime,
  group : @async.TaskGroup[Result[Unit, V8Error]],
  op : AsyncBytesOpRequest,
  handler : AsyncBytesTaskHandler,
) -> Unit {
  runtime.state.val.async_loop.pending_tasks += 1
  group.spawn_bg(no_wait=true, () => {
    defer {
      runtime.state.val.async_loop.pending_tasks = runtime.state.val.async_loop.pending_tasks -
        1
    }
    run_async_bytes_task(runtime, op, handler)
  })
}

///|
fn drain_async_json_tasks(
  runtime : Runtime,
  group : @async.TaskGroup[Result[Unit, V8Error]],
) -> Result[Bool, V8Error] {
  if runtime.state.val.async_loop.json_handlers.is_empty() {
    return Ok(false)
  }
  let mut progressed = false
  for ;; {
    let next = runtime.take_async_json_op()
    guard next is Ok(_) else { return Err(next.unwrap_err()) }
    match next.unwrap() {
      None => break
      Some(op) =>
        match runtime.state.val.async_loop.json_handlers.get(op.name) {
          Some(handler) => {
            progressed = true
            spawn_async_json_task(runtime, group, op, handler)
          }
          None =>
            return Err(
              V8Error::NativeError(
                "MoonBit async event loop encountered unhandled async json op: " +
                op.name,
              ),
            )
        }
    }
  }
  Ok(progressed)
}

///|
fn drain_async_bytes_tasks(
  runtime : Runtime,
  group : @async.TaskGroup[Result[Unit, V8Error]],
) -> Result[Bool, V8Error] {
  if runtime.state.val.async_loop.bytes_handlers.is_empty() {
    return Ok(false)
  }
  let mut progressed = false
  for ;; {
    let next = runtime.take_async_bytes_op()
    guard next is Ok(_) else { return Err(next.unwrap_err()) }
    match next.unwrap() {
      None => break
      Some(op) =>
        match runtime.state.val.async_loop.bytes_handlers.get(op.name) {
          Some(handler) => {
            progressed = true
            spawn_async_bytes_task(runtime, group, op, handler)
          }
          None =>
            return Err(
              V8Error::NativeError(
                "MoonBit async event loop encountered unhandled async bytes op: " +
                op.name,
              ),
            )
        }
    }
  }
  Ok(progressed)
}

///|
fn pump_async_tasks_once(
  runtime : Runtime,
  group : @async.TaskGroup[Result[Unit, V8Error]],
) -> Result[Bool, V8Error] {
  let drained_json = drain_async_json_tasks(runtime, group)
  guard drained_json is Ok(_) else { return Err(drained_json.unwrap_err()) }
  let drained_bytes = drain_async_bytes_tasks(runtime, group)
  guard drained_bytes is Ok(_) else { return Err(drained_bytes.unwrap_err()) }
  Ok(drained_json.unwrap() || drained_bytes.unwrap())
}

///|
fn runtime_has_ref_resources(runtime : Runtime) -> Result[Bool, V8Error] {
  let listed = runtime.list_resources()
  guard listed is Ok(_) else { return Err(listed.unwrap_err()) }
  for i in 0..<listed.unwrap().length() {
    if listed.unwrap()[i].is_ref {
      return Ok(true)
    }
  }
  Ok(false)
}

///|
async fn wait_for_promise_handle_async(
  handle : PromiseHandle,
) -> Result[Unit, V8Error] {
  let runtime = promise_runtime(handle)
  let begun = runtime_begin_async_loop(runtime)
  guard begun is Ok(_) else { return Err(begun.unwrap_err()) }
  defer runtime_end_async_loop(runtime)
  @async.with_task_group(group => {
    for ;; {
      let state = handle.state()
      guard state is Ok(_) else { return Err(state.unwrap_err()) }
      if not(state.unwrap() is PromiseState::Pending) {
        break
      }
      let progressed = pump_async_tasks_once(runtime, group)
      guard progressed is Ok(_) else { return Err(progressed.unwrap_err()) }
      let flushed = runtime.perform_microtask_checkpoint()
      guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
      let state = handle.state()
      guard state is Ok(_) else { return Err(state.unwrap_err()) }
      if not(state.unwrap() is PromiseState::Pending) {
        break
      }
      if progressed.unwrap() {
        @async.pause()
      } else {
        @async.sleep(1)
      }
    }
    Ok(())
  })
}

///|
pub async fn Runtime::run_event_loop_until_idle_async(
  self : Runtime,
) -> Result[Unit, V8Error] {
  let begun = runtime_begin_async_loop(self)
  guard begun is Ok(_) else { return Err(begun.unwrap_err()) }
  defer runtime_end_async_loop(self)
  @async.with_task_group(group => {
    for ;; {
      let progressed = pump_async_tasks_once(self, group)
      guard progressed is Ok(_) else { return Err(progressed.unwrap_err()) }
      let flushed = self.perform_microtask_checkpoint()
      guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
      let has_ref_resources = runtime_has_ref_resources(self)
      guard has_ref_resources is Ok(_) else {
        return Err(has_ref_resources.unwrap_err())
      }
      if !progressed.unwrap() &&
        self.state.val.async_loop.pending_tasks == 0 &&
        !has_ref_resources.unwrap() {
        break
      }
      if progressed.unwrap() || self.state.val.async_loop.pending_tasks > 0 {
        @async.pause()
      } else {
        @async.sleep(1)
      }
    }
    Ok(())
  })
}

///|
pub fn Runtime::register_async_json_task_callback(
  self : Runtime,
  name : String,
  callback : async (String) -> String,
) -> Result[Unit, V8Error] {
  self.register_async_json_task_result_callback(name, payload => {
    Ok(callback(payload))
  })
}

///|
pub fn Runtime::register_async_json_task_result_callback(
  self : Runtime,
  name : String,
  callback : async (String) -> Result[String, String],
) -> Result[Unit, V8Error] {
  let registered = self.register_async_json_op(name)
  guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
  self.state.val.async_loop.json_handlers.set(name, AsyncJsonTaskHandler::{
    callback,
    use_json_error: false,
  })
  Ok(())
}

///|
pub fn Runtime::register_async_json_task_result_callback_with_json_error(
  self : Runtime,
  name : String,
  callback : async (String) -> Result[String, String],
) -> Result[Unit, V8Error] {
  let registered = self.register_async_json_op(name)
  guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
  self.state.val.async_loop.json_handlers.set(name, AsyncJsonTaskHandler::{
    callback,
    use_json_error: true,
  })
  Ok(())
}

///|
pub fn Runtime::register_async_bytes_task_callback(
  self : Runtime,
  name : String,
  callback : async (Bytes) -> Bytes,
) -> Result[Unit, V8Error] {
  self.register_async_bytes_task_result_callback(name, payload => {
    Ok(callback(payload))
  })
}

///|
pub fn Runtime::register_async_bytes_task_result_callback(
  self : Runtime,
  name : String,
  callback : async (Bytes) -> Result[Bytes, String],
) -> Result[Unit, V8Error] {
  let registered = self.register_async_bytes_op(name)
  guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
  self.state.val.async_loop.bytes_handlers.set(name, AsyncBytesTaskHandler::{
    callback,
    use_json_error: false,
  })
  Ok(())
}

///|
pub fn Runtime::register_async_bytes_task_result_callback_with_json_error(
  self : Runtime,
  name : String,
  callback : async (Bytes) -> Result[Bytes, String],
) -> Result[Unit, V8Error] {
  let registered = self.register_async_bytes_op(name)
  guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
  self.state.val.async_loop.bytes_handlers.set(name, AsyncBytesTaskHandler::{
    callback,
    use_json_error: true,
  })
  Ok(())
}
