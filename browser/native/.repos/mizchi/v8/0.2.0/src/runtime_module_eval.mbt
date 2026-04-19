///|
pub struct ModuleEvalHandle {
  priv module_handle_ : ModuleHandle
  priv promise_handle_ : PromiseHandle?
}

///|
fn module_eval_handle_from_runtime(
  runtime : Runtime,
  module_handle : UInt64,
  promise_handle : UInt64,
) -> ModuleEvalHandle {
  ModuleEvalHandle::{
    module_handle_: module_handle_from_runtime(runtime, module_handle),
    promise_handle_: if promise_handle == 0 {
      None
    } else {
      Some(promise_handle_from_runtime(runtime, promise_handle))
    },
  }
}

///|
fn module_evaluation_promise_handle(
  runtime : Runtime,
  module_handle : UInt64,
  fallback : String,
) -> Result[UInt64, V8Error] {
  let runtime_handle = runtime.state.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let promise_handle = runtime_module_evaluation_promise_native(
    runtime_handle, module_handle, err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(take_native_error(err_ptr, V8Error::NativeError(fallback)))
  } else {
    Ok(promise_handle)
  }
}

///|
pub fn Runtime::eval_module_handle_async_string(
  self : Runtime,
  source : String,
) -> Result[ModuleEvalHandle, V8Error] {
  let runtime_handle = self.state.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let module_handle = runtime_eval_module_handle_async_native(
    runtime_handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if module_handle == 0 {
    return Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_module_handle_async_native failed"),
      ),
    )
  }
  if not(native_ptr_is_null(err_ptr)) {
    return Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_module_handle_async_native failed"),
      ),
    )
  }
  let promise_handle = module_evaluation_promise_handle(
    self, module_handle, "runtime_module_evaluation_promise_native failed",
  )
  guard promise_handle is Ok(_) else { return Err(promise_handle.unwrap_err()) }
  Ok(
    module_eval_handle_from_runtime(
      self,
      module_handle,
      promise_handle.unwrap(),
    ),
  )
}

///|
pub fn Runtime::eval_module_handle_async_string_with_specifier(
  self : Runtime,
  specifier : String,
  source : String,
) -> Result[ModuleEvalHandle, V8Error] {
  let runtime_handle = self.state.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let specifier_bytes = @utf8.encode(specifier)
  let source_bytes = @utf8.encode(source)
  let module_handle = runtime_eval_module_handle_async_with_specifier_native(
    runtime_handle,
    specifier_bytes,
    specifier_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if module_handle == 0 {
    return Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError(
          "runtime_eval_module_handle_async_with_specifier_native failed",
        ),
      ),
    )
  }
  if not(native_ptr_is_null(err_ptr)) {
    return Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError(
          "runtime_eval_module_handle_async_with_specifier_native failed",
        ),
      ),
    )
  }
  let promise_handle = module_evaluation_promise_handle(
    self, module_handle, "runtime_module_evaluation_promise_native failed",
  )
  guard promise_handle is Ok(_) else { return Err(promise_handle.unwrap_err()) }
  Ok(
    module_eval_handle_from_runtime(
      self,
      module_handle,
      promise_handle.unwrap(),
    ),
  )
}

///|
pub async fn Runtime::eval_module_handle_string_async(
  self : Runtime,
  source : String,
) -> Result[ModuleHandle, V8Error] {
  let module_eval = self.eval_module_handle_async_string(source)
  guard module_eval is Ok(_) else { return Err(module_eval.unwrap_err()) }
  module_eval.unwrap().await_ready_async()
}

///|
pub async fn Runtime::eval_module_handle_string_async_with_specifier(
  self : Runtime,
  specifier : String,
  source : String,
) -> Result[ModuleHandle, V8Error] {
  let module_eval = self.eval_module_handle_async_string_with_specifier(
    specifier, source,
  )
  guard module_eval is Ok(_) else { return Err(module_eval.unwrap_err()) }
  module_eval.unwrap().await_ready_async()
}

///|
pub fn ModuleEvalHandle::module_handle(self : ModuleEvalHandle) -> ModuleHandle {
  self.module_handle_
}

///|
pub fn ModuleEvalHandle::promise_handle(
  self : ModuleEvalHandle,
) -> PromiseHandle? {
  self.promise_handle_
}

///|
pub fn ModuleEvalHandle::is_closed(self : ModuleEvalHandle) -> Bool {
  if self.module_handle_.is_closed() {
    true
  } else {
    match self.promise_handle_ {
      None => false
      Some(promise_handle) => promise_handle.is_closed()
    }
  }
}

///|
pub fn ModuleEvalHandle::dispose(self : ModuleEvalHandle) -> Unit {
  self.module_handle_.dispose()
  match self.promise_handle_ {
    None => ()
    Some(promise_handle) => promise_handle.dispose()
  }
}

///|
pub fn ModuleEvalHandle::await_ready(
  self : ModuleEvalHandle,
) -> Result[ModuleHandle, V8Error] {
  match self.promise_handle_ {
    None => Ok(self.module_handle_)
    Some(promise_handle) => {
      let waited = wait_for_promise_handle(promise_handle, 1024)
      guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
      Ok(self.module_handle_)
    }
  }
}

///|
pub async fn ModuleEvalHandle::await_ready_async(
  self : ModuleEvalHandle,
) -> Result[ModuleHandle, V8Error] {
  match self.promise_handle_ {
    None => Ok(self.module_handle_)
    Some(promise_handle) => {
      let waited = wait_for_promise_handle_async(promise_handle)
      guard waited is Ok(_) else { return Err(waited.unwrap_err()) }
      Ok(self.module_handle_)
    }
  }
}
