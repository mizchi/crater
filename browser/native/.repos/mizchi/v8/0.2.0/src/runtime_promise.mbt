///|
pub enum PromiseState {
  Pending
  Fulfilled
  Rejected
} derive(Eq, Show)

///|
struct PromiseHandleState {
  runtime : Ref[RuntimeState]
  mut handle : UInt64
}

///|
pub struct PromiseHandle {
  priv state : Ref[PromiseHandleState]
}

///|
fn promise_handle_from_runtime(
  runtime : Runtime,
  handle : UInt64,
) -> PromiseHandle {
  PromiseHandle::{
    state: Ref::new(PromiseHandleState::{ runtime: runtime.state, handle }),
  }
}

///|
fn promise_state_from_code(code : Int) -> Result[PromiseState, V8Error] {
  match code {
    0 => Ok(PromiseState::Pending)
    1 => Ok(PromiseState::Fulfilled)
    2 => Ok(PromiseState::Rejected)
    _ => Err(V8Error::NativeError("unknown promise state code"))
  }
}

///|
fn promise_runtime(handle : PromiseHandle) -> Runtime {
  Runtime::{ state: handle.state.val.runtime }
}

///|
fn wait_for_promise_handle(
  handle : PromiseHandle,
  remaining : Int,
) -> Result[Unit, V8Error] {
  let state = handle.state()
  guard state is Ok(_) else { return Err(state.unwrap_err()) }
  match state.unwrap() {
    PromiseState::Pending =>
      if remaining <= 0 {
        Err(
          V8Error::NativeError(
            "promise is still pending after 1024 microtask checkpoints",
          ),
        )
      } else {
        let flushed = promise_runtime(handle).perform_microtask_checkpoint()
        guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
        wait_for_promise_handle(handle, remaining - 1)
      }
    _ => Ok(())
  }
}

///|
pub fn Runtime::eval_promise_string(
  self : Runtime,
  source : String,
) -> Result[PromiseHandle, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let promise_handle = runtime_eval_promise_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if promise_handle == 0 {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_promise_native failed"),
      ),
    )
  } else if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_promise_native failed"),
      ),
    )
  } else {
    Ok(promise_handle_from_runtime(self, promise_handle))
  }
}

///|
pub fn Runtime::eval_promise_string_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[PromiseHandle, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let promise_handle = runtime_eval_promise_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if promise_handle == 0 {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_promise_with_name_native failed"),
      ),
    )
  } else if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_promise_with_name_native failed"),
      ),
    )
  } else {
    Ok(promise_handle_from_runtime(self, promise_handle))
  }
}

///|
pub async fn Runtime::eval_promise_string_async(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let promise = self.eval_promise_string(source)
  guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
  promise.unwrap().await_string_async()
}

///|
pub async fn Runtime::eval_promise_string_async_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  let promise = self.eval_promise_string_with_name(resource_name, source)
  guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
  promise.unwrap().await_string_async()
}

///|
pub async fn Runtime::eval_promise_json_async(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let promise = self.eval_promise_string(source)
  guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
  promise.unwrap().await_json_async()
}

///|
pub async fn Runtime::eval_promise_json_async_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  let promise = self.eval_promise_string_with_name(resource_name, source)
  guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
  promise.unwrap().await_json_async()
}

///|
pub async fn Runtime::eval_promise_bytes_async(
  self : Runtime,
  source : String,
) -> Result[Bytes, V8Error] {
  let promise = self.eval_promise_string(source)
  guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
  promise.unwrap().await_bytes_async()
}

///|
pub async fn Runtime::eval_promise_bytes_async_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[Bytes, V8Error] {
  let promise = self.eval_promise_string_with_name(resource_name, source)
  guard promise is Ok(_) else { return Err(promise.unwrap_err()) }
  promise.unwrap().await_bytes_async()
}

///|
pub fn PromiseHandle::is_closed(self : PromiseHandle) -> Bool {
  self.state.val.handle == 0 || self.state.val.runtime.val.handle == 0
}

///|
pub fn PromiseHandle::dispose(self : PromiseHandle) -> Unit {
  let runtime_handle = self.state.val.runtime.val.handle
  let promise_handle = self.state.val.handle
  if runtime_handle != 0 && promise_handle != 0 {
    runtime_promise_delete_native(runtime_handle, promise_handle)
  }
  self.state.val.handle = 0
}

///|
pub fn PromiseHandle::state(
  self : PromiseHandle,
) -> Result[PromiseState, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let promise_handle = self.state.val.handle
  if promise_handle == 0 {
    return Err(V8Error::PromiseClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let state_code = runtime_promise_state_native(
    runtime_handle, promise_handle, err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_promise_state_native failed"),
      ),
    )
  } else {
    promise_state_from_code(state_code)
  }
}

///|
pub fn PromiseHandle::result_string(
  self : PromiseHandle,
) -> Result[String, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let promise_handle = self.state.val.handle
  if promise_handle == 0 {
    return Err(V8Error::PromiseClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let result_bytes = runtime_promise_result_native(
    runtime_handle, promise_handle, err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_promise_result_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn PromiseHandle::result_json(
  self : PromiseHandle,
) -> Result[String, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let promise_handle = self.state.val.handle
  if promise_handle == 0 {
    return Err(V8Error::PromiseClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let result_bytes = runtime_promise_result_json_native(
    runtime_handle, promise_handle, err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_promise_result_json_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn PromiseHandle::result_bytes(
  self : PromiseHandle,
) -> Result[Bytes, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let promise_handle = self.state.val.handle
  if promise_handle == 0 {
    return Err(V8Error::PromiseClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let result_bytes = runtime_promise_result_bytes_native(
    runtime_handle, promise_handle, err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_promise_result_bytes_native failed"),
      ),
    )
  } else {
    Ok(result_bytes)
  }
}

///|
pub fn PromiseHandle::await_string(
  self : PromiseHandle,
) -> Result[String, V8Error] {
  let waited = wait_for_promise_handle(self, 1024)
  guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
  self.result_string()
}

///|
pub async fn PromiseHandle::await_string_async(
  self : PromiseHandle,
) -> Result[String, V8Error] {
  let waited = wait_for_promise_handle_async(self)
  guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
  self.result_string()
}

///|
pub fn PromiseHandle::await_json(
  self : PromiseHandle,
) -> Result[String, V8Error] {
  let waited = wait_for_promise_handle(self, 1024)
  guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
  self.result_json()
}

///|
pub async fn PromiseHandle::await_json_async(
  self : PromiseHandle,
) -> Result[String, V8Error] {
  let waited = wait_for_promise_handle_async(self)
  guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
  self.result_json()
}

///|
pub fn PromiseHandle::await_bytes(
  self : PromiseHandle,
) -> Result[Bytes, V8Error] {
  let waited = wait_for_promise_handle(self, 1024)
  guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
  self.result_bytes()
}

///|
pub async fn PromiseHandle::await_bytes_async(
  self : PromiseHandle,
) -> Result[Bytes, V8Error] {
  let waited = wait_for_promise_handle_async(self)
  guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
  self.result_bytes()
}

///|
pub async fn eval_promise_string_async(
  source : String,
) -> Result[String, V8Error] {
  with_runtime_async(runtime => runtime.eval_promise_string_async(source))
}

///|
pub async fn eval_promise_string_async_with_name(
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime_async(runtime => {
    runtime.eval_promise_string_async_with_name(resource_name, source)
  })
}

///|
pub async fn eval_promise_json_async(
  source : String,
) -> Result[String, V8Error] {
  with_runtime_async(runtime => runtime.eval_promise_json_async(source))
}

///|
pub async fn eval_promise_json_async_with_name(
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime_async(runtime => {
    runtime.eval_promise_json_async_with_name(resource_name, source)
  })
}

///|
pub async fn eval_promise_bytes_async(
  source : String,
) -> Result[Bytes, V8Error] {
  with_runtime_async(runtime => runtime.eval_promise_bytes_async(source))
}

///|
pub async fn eval_promise_bytes_async_with_name(
  resource_name : String,
  source : String,
) -> Result[Bytes, V8Error] {
  with_runtime_async(runtime => {
    runtime.eval_promise_bytes_async_with_name(resource_name, source)
  })
}
