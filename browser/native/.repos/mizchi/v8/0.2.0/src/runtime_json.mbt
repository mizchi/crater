///|
pub fn Runtime::eval_json(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_json_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_string_result(err_ptr, result_bytes, "runtime_eval_json_native failed")
}

///|
pub fn Runtime::eval_json_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_json_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_string_result(
    err_ptr, result_bytes, "runtime_eval_json_with_name_native failed",
  )
}

///|
pub fn Runtime::eval_async_json(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_async_json_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_string_result(
    err_ptr, result_bytes, "runtime_eval_async_json_native failed",
  )
}

///|
pub fn Runtime::eval_async_json_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_async_json_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  native_string_result(
    err_ptr, result_bytes, "runtime_eval_async_json_with_name_native failed",
  )
}

///|
pub fn Runtime::set_global_json(
  self : Runtime,
  name : String,
  json : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  let json_bytes = @utf8.encode(json)
  runtime_set_global_json_native(
    handle,
    name_bytes,
    name_bytes.length(),
    json_bytes,
    json_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_set_global_json_native failed")
}

///|
pub fn Runtime::get_global_json(
  self : Runtime,
  name : String,
) -> Result[String, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  let result_bytes = runtime_get_global_json_native(
    handle,
    name_bytes,
    name_bytes.length(),
    err_ptr,
  )
  native_string_result(
    err_ptr, result_bytes, "runtime_get_global_json_native failed",
  )
}

///|
pub fn eval_json(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_json(source) })
}

///|
pub fn eval_json_with_name(
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_json_with_name(resource_name, source)
  })
}

///|
pub fn eval_async_json(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_async_json(source) })
}

///|
pub fn eval_async_json_with_name(
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_async_json_with_name(resource_name, source)
  })
}

///|
pub fn Runtime::call_global_json(
  self : Runtime,
  name : String,
  args_json : String,
) -> Result[String, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  let args_json_bytes = @utf8.encode(args_json)
  let result_bytes = runtime_call_global_json_native(
    handle,
    name_bytes,
    name_bytes.length(),
    args_json_bytes,
    args_json_bytes.length(),
    err_ptr,
  )
  native_string_result(
    err_ptr, result_bytes, "runtime_call_global_json_native failed",
  )
}
