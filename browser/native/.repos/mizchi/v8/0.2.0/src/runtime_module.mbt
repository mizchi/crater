///|
struct ModuleHandleState {
  runtime : Ref[RuntimeState]
  mut handle : UInt64
}

///|
pub struct ModuleHandle {
  priv state : Ref[ModuleHandleState]
}

///|
fn module_handle_from_runtime(
  runtime : Runtime,
  handle : UInt64,
) -> ModuleHandle {
  ModuleHandle::{
    state: Ref::new(ModuleHandleState::{ runtime: runtime.state, handle }),
  }
}

///|
pub fn Runtime::eval_module_handle_string(
  self : Runtime,
  source : String,
) -> Result[ModuleHandle, V8Error] {
  let runtime_handle = self.state.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let module_handle = runtime_eval_module_handle_native(
    runtime_handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if module_handle == 0 {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_module_handle_native failed"),
      ),
    )
  } else if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_module_handle_native failed"),
      ),
    )
  } else {
    Ok(module_handle_from_runtime(self, module_handle))
  }
}

///|
pub fn Runtime::eval_module_handle_string_with_specifier(
  self : Runtime,
  specifier : String,
  source : String,
) -> Result[ModuleHandle, V8Error] {
  let runtime_handle = self.state.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let specifier_bytes = @utf8.encode(specifier)
  let source_bytes = @utf8.encode(source)
  let module_handle = runtime_eval_module_handle_with_specifier_native(
    runtime_handle,
    specifier_bytes,
    specifier_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if module_handle == 0 {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError(
          "runtime_eval_module_handle_with_specifier_native failed",
        ),
      ),
    )
  } else if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError(
          "runtime_eval_module_handle_with_specifier_native failed",
        ),
      ),
    )
  } else {
    Ok(module_handle_from_runtime(self, module_handle))
  }
}

///|
pub fn ModuleHandle::is_closed(self : ModuleHandle) -> Bool {
  self.state.val.handle == 0 || self.state.val.runtime.val.handle == 0
}

///|
pub fn ModuleHandle::dispose(self : ModuleHandle) -> Unit {
  let runtime_handle = self.state.val.runtime.val.handle
  let module_handle = self.state.val.handle
  if runtime_handle != 0 && module_handle != 0 {
    runtime_module_delete_native(runtime_handle, module_handle)
  }
  self.state.val.handle = 0
}

///|
pub fn ModuleHandle::get_export_json(
  self : ModuleHandle,
  export_name : String,
) -> Result[String, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let module_handle = self.state.val.handle
  if module_handle == 0 {
    return Err(V8Error::ModuleClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let export_name_bytes = @utf8.encode(export_name)
  let result_bytes = runtime_module_get_export_json_native(
    runtime_handle,
    module_handle,
    export_name_bytes,
    export_name_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_module_get_export_json_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn ModuleHandle::export_names(
  self : ModuleHandle,
) -> Result[Array[String], V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let module_handle = self.state.val.handle
  if module_handle == 0 {
    return Err(V8Error::ModuleClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let result_bytes = runtime_module_export_names_native(
    runtime_handle, module_handle, err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_module_export_names_native failed"),
      ),
    )
  } else {
    let text = @utf8.decode_lossy(result_bytes)
    if text == "" {
      Ok([])
    } else {
      Ok(text.split("\n").map(StringView::to_string).collect())
    }
  }
}

///|
pub fn ModuleHandle::get_export_bytes(
  self : ModuleHandle,
  export_name : String,
) -> Result[Bytes, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let module_handle = self.state.val.handle
  if module_handle == 0 {
    return Err(V8Error::ModuleClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let export_name_bytes = @utf8.encode(export_name)
  let result_bytes = runtime_module_get_export_bytes_native(
    runtime_handle,
    module_handle,
    export_name_bytes,
    export_name_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_module_get_export_bytes_native failed"),
      ),
    )
  } else {
    Ok(result_bytes)
  }
}

///|
pub fn ModuleHandle::call_export_json(
  self : ModuleHandle,
  export_name : String,
  args_json : String,
) -> Result[String, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let module_handle = self.state.val.handle
  if module_handle == 0 {
    return Err(V8Error::ModuleClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let export_name_bytes = @utf8.encode(export_name)
  let args_json_bytes = @utf8.encode(args_json)
  let result_bytes = runtime_module_call_export_json_native(
    runtime_handle,
    module_handle,
    export_name_bytes,
    export_name_bytes.length(),
    args_json_bytes,
    args_json_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_module_call_export_json_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn ModuleHandle::call_export_bytes(
  self : ModuleHandle,
  export_name : String,
  bytes : Bytes,
) -> Result[Bytes, V8Error] {
  let runtime_handle = self.state.val.runtime.val.handle
  if runtime_handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let module_handle = self.state.val.handle
  if module_handle == 0 {
    return Err(V8Error::ModuleClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let export_name_bytes = @utf8.encode(export_name)
  let result_bytes = runtime_module_call_export_bytes_native(
    runtime_handle,
    module_handle,
    export_name_bytes,
    export_name_bytes.length(),
    bytes,
    bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_module_call_export_bytes_native failed"),
      ),
    )
  } else {
    Ok(result_bytes)
  }
}
