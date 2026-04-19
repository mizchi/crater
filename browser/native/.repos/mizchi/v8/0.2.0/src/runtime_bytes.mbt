///|
pub fn Runtime::eval_bytes(
  self : Runtime,
  source : String,
) -> Result[Bytes, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_bytes_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_bytes_result(err_ptr, result_bytes, "runtime_eval_bytes_native failed")
}

///|
pub fn Runtime::eval_bytes_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[Bytes, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_bytes_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_bytes_result(
    err_ptr, result_bytes, "runtime_eval_bytes_with_name_native failed",
  )
}

///|
pub fn Runtime::eval_async_bytes(
  self : Runtime,
  source : String,
) -> Result[Bytes, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_async_bytes_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_bytes_result(
    err_ptr, result_bytes, "runtime_eval_async_bytes_native failed",
  )
}

///|
pub fn Runtime::eval_async_bytes_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[Bytes, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_async_bytes_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_bytes_result(
    err_ptr, result_bytes, "runtime_eval_async_bytes_with_name_native failed",
  )
}

///|
pub fn Runtime::set_global_bytes(
  self : Runtime,
  name : String,
  bytes : Bytes,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_set_global_bytes_native(
    handle,
    name_bytes,
    name_bytes.length(),
    bytes,
    bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_set_global_bytes_native failed")
}

///|
pub fn Runtime::get_global_bytes(
  self : Runtime,
  name : String,
) -> Result[Bytes, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  let result_bytes = runtime_get_global_bytes_native(
    handle,
    name_bytes,
    name_bytes.length(),
    err_ptr,
  )
  native_bytes_result(
    err_ptr, result_bytes, "runtime_get_global_bytes_native failed",
  )
}

///|
pub fn eval_bytes(source : String) -> Result[Bytes, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_bytes(source) })
}

///|
pub fn eval_bytes_with_name(
  resource_name : String,
  source : String,
) -> Result[Bytes, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_bytes_with_name(resource_name, source)
  })
}

///|
pub fn eval_async_bytes(source : String) -> Result[Bytes, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_async_bytes(source) })
}

///|
pub fn eval_async_bytes_with_name(
  resource_name : String,
  source : String,
) -> Result[Bytes, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_async_bytes_with_name(resource_name, source)
  })
}

///|
pub fn Runtime::call_global_bytes(
  self : Runtime,
  name : String,
  bytes : Bytes,
) -> Result[Bytes, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  let result_bytes = runtime_call_global_bytes_native(
    handle,
    name_bytes,
    name_bytes.length(),
    bytes,
    bytes.length(),
    err_ptr,
  )
  native_bytes_result(
    err_ptr, result_bytes, "runtime_call_global_bytes_native failed",
  )
}
