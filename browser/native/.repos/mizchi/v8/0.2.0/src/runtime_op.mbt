///|
pub struct AsyncJsonOpRequest {
  id : UInt64
  name : String
  payload_json : String
}

///|
pub struct SyncJsonOpRequest {
  id : UInt64
  name : String
  payload_json : String
}

///|
pub struct SyncBytesOpRequest {
  id : UInt64
  name : String
  payload : Bytes
}

///|
pub struct AsyncBytesOpRequest {
  id : UInt64
  name : String
  payload : Bytes
}

///|
fn encode_callback_ok(payload : Bytes) -> Bytes {
  Bytes::from_array([0]) + payload
}

///|
fn encode_callback_err(message : String) -> Bytes {
  Bytes::from_array([1]) + @utf8.encode(message)
}

///|
fn encode_callback_json_err(error_json : String) -> Bytes {
  Bytes::from_array([2]) + @utf8.encode(error_json)
}

///|
fn encode_json_callback_result(result : Result[String, String]) -> Bytes {
  match result {
    Ok(json) => encode_callback_ok(@utf8.encode(json))
    Err(message) => encode_callback_err(message)
  }
}

///|
fn encode_json_callback_result_with_json_error(
  result : Result[String, String],
) -> Bytes {
  match result {
    Ok(json) => encode_callback_ok(@utf8.encode(json))
    Err(error_json) => encode_callback_json_err(error_json)
  }
}

///|
fn encode_bytes_callback_result(result : Result[Bytes, String]) -> Bytes {
  match result {
    Ok(bytes) => encode_callback_ok(bytes)
    Err(message) => encode_callback_err(message)
  }
}

///|
fn encode_bytes_callback_result_with_json_error(
  result : Result[Bytes, String],
) -> Bytes {
  match result {
    Ok(bytes) => encode_callback_ok(bytes)
    Err(error_json) => encode_callback_json_err(error_json)
  }
}

///|
pub fn Runtime::register_sync_json_op(
  self : Runtime,
  name : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_json_op_native(
    handle,
    name_bytes,
    name_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_register_sync_json_op_native failed")
}

///|
pub fn Runtime::push_sync_json_op_response(
  self : Runtime,
  name : String,
  payload_json : String,
  result_json : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  let payload_json_bytes = @utf8.encode(payload_json)
  let result_json_bytes = @utf8.encode(result_json)
  runtime_push_sync_json_op_response_native(
    handle,
    name_bytes,
    name_bytes.length(),
    payload_json_bytes,
    payload_json_bytes.length(),
    result_json_bytes,
    result_json_bytes.length(),
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_push_sync_json_op_response_native failed",
  )
}

///|
pub fn Runtime::register_sync_json_callback(
  self : Runtime,
  name : String,
  callback : (String) -> String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_json_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_json_callback_result(Ok(callback(@utf8.decode_lossy(payload))))
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_sync_json_callback_native failed",
  )
}

///|
pub fn Runtime::register_sync_json_result_callback(
  self : Runtime,
  name : String,
  callback : (String) -> Result[String, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_json_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_json_callback_result(callback(@utf8.decode_lossy(payload)))
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_sync_json_callback_native failed",
  )
}

///|
pub fn Runtime::register_sync_json_result_callback_with_json_error(
  self : Runtime,
  name : String,
  callback : (String) -> Result[String, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_json_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_json_callback_result_with_json_error(
        callback(@utf8.decode_lossy(payload)),
      )
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_sync_json_callback_native failed",
  )
}

///|
pub fn Runtime::register_sync_bytes_op(
  self : Runtime,
  name : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_bytes_op_native(
    handle,
    name_bytes,
    name_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_register_sync_bytes_op_native failed")
}

///|
pub fn Runtime::register_sync_bytes_callback(
  self : Runtime,
  name : String,
  callback : (Bytes) -> Bytes,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_bytes_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) { encode_bytes_callback_result(Ok(callback(payload))) },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_sync_bytes_callback_native failed",
  )
}

///|
pub fn Runtime::register_sync_bytes_result_callback(
  self : Runtime,
  name : String,
  callback : (Bytes) -> Result[Bytes, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_bytes_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) { encode_bytes_callback_result(callback(payload)) },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_sync_bytes_callback_native failed",
  )
}

///|
pub fn Runtime::register_sync_bytes_result_callback_with_json_error(
  self : Runtime,
  name : String,
  callback : (Bytes) -> Result[Bytes, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_sync_bytes_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_bytes_callback_result_with_json_error(callback(payload))
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_sync_bytes_callback_native failed",
  )
}

///|
pub fn Runtime::push_sync_bytes_op_response(
  self : Runtime,
  name : String,
  payload : Bytes,
  result_bytes : Bytes,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_push_sync_bytes_op_response_native(
    handle,
    name_bytes,
    name_bytes.length(),
    payload,
    payload.length(),
    result_bytes,
    result_bytes.length(),
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_push_sync_bytes_op_response_native failed",
  )
}

///|
pub fn Runtime::register_async_json_op(
  self : Runtime,
  name : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_json_op_native(
    handle,
    name_bytes,
    name_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_register_async_json_op_native failed")
}

///|
pub fn Runtime::register_async_json_callback(
  self : Runtime,
  name : String,
  callback : (String) -> String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_json_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_json_callback_result(Ok(callback(@utf8.decode_lossy(payload))))
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_async_json_callback_native failed",
  )
}

///|
pub fn Runtime::register_async_json_result_callback(
  self : Runtime,
  name : String,
  callback : (String) -> Result[String, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_json_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_json_callback_result(callback(@utf8.decode_lossy(payload)))
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_async_json_callback_native failed",
  )
}

///|
pub fn Runtime::register_async_json_result_callback_with_json_error(
  self : Runtime,
  name : String,
  callback : (String) -> Result[String, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_json_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_json_callback_result_with_json_error(
        callback(@utf8.decode_lossy(payload)),
      )
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_async_json_callback_native failed",
  )
}

///|
pub fn Runtime::register_async_bytes_op(
  self : Runtime,
  name : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_bytes_op_native(
    handle,
    name_bytes,
    name_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_register_async_bytes_op_native failed")
}

///|
pub fn Runtime::register_async_bytes_callback(
  self : Runtime,
  name : String,
  callback : (Bytes) -> Bytes,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_bytes_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) { encode_bytes_callback_result(Ok(callback(payload))) },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_async_bytes_callback_native failed",
  )
}

///|
pub fn Runtime::register_async_bytes_result_callback(
  self : Runtime,
  name : String,
  callback : (Bytes) -> Result[Bytes, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_bytes_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) { encode_bytes_callback_result(callback(payload)) },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_async_bytes_callback_native failed",
  )
}

///|
pub fn Runtime::register_async_bytes_result_callback_with_json_error(
  self : Runtime,
  name : String,
  callback : (Bytes) -> Result[Bytes, String],
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let name_bytes = @utf8.encode(name)
  runtime_register_async_bytes_callback_native(
    handle,
    name_bytes,
    name_bytes.length(),
    fn(call, payload) { call(payload) },
    fn(payload) {
      encode_bytes_callback_result_with_json_error(callback(payload))
    },
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_register_async_bytes_callback_native failed",
  )
}

///|
pub fn Runtime::take_sync_json_op(
  self : Runtime,
) -> Result[SyncJsonOpRequest?, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let op_id = runtime_take_sync_json_op_native(handle, err_ptr)
  let op_id_result = native_optional_id_result(
    err_ptr, op_id, "runtime_take_sync_json_op_native failed",
  )
  guard op_id_result is Ok(_) else { return Err(op_id_result.unwrap_err()) }
  let op_id = match op_id_result.unwrap() {
    Some(op_id) => op_id
    None => return Ok(None)
  }

  native_ptr_clear(err_ptr)
  let name_bytes = runtime_sync_json_op_name_native(handle, op_id, err_ptr)
  let name_result = native_string_result(
    err_ptr, name_bytes, "runtime_sync_json_op_name_native failed",
  )
  guard name_result is Ok(_) else { return Err(name_result.unwrap_err()) }

  native_ptr_clear(err_ptr)
  let payload_json_bytes = runtime_sync_json_op_payload_json_native(
    handle, op_id, err_ptr,
  )
  let payload_json_result = native_string_result(
    err_ptr, payload_json_bytes, "runtime_sync_json_op_payload_json_native failed",
  )
  guard payload_json_result is Ok(_) else {
    return Err(payload_json_result.unwrap_err())
  }

  runtime_sync_json_op_delete_native(handle, op_id)

  Ok(
    Some(SyncJsonOpRequest::{
      id: op_id,
      name: name_result.unwrap(),
      payload_json: payload_json_result.unwrap(),
    }),
  )
}

///|
pub fn Runtime::take_sync_bytes_op(
  self : Runtime,
) -> Result[SyncBytesOpRequest?, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let op_id = runtime_take_sync_bytes_op_native(handle, err_ptr)
  let op_id_result = native_optional_id_result(
    err_ptr, op_id, "runtime_take_sync_bytes_op_native failed",
  )
  guard op_id_result is Ok(_) else { return Err(op_id_result.unwrap_err()) }
  let op_id = match op_id_result.unwrap() {
    Some(op_id) => op_id
    None => return Ok(None)
  }

  native_ptr_clear(err_ptr)
  let name_bytes = runtime_sync_bytes_op_name_native(handle, op_id, err_ptr)
  let name_result = native_string_result(
    err_ptr, name_bytes, "runtime_sync_bytes_op_name_native failed",
  )
  guard name_result is Ok(_) else { return Err(name_result.unwrap_err()) }

  native_ptr_clear(err_ptr)
  let payload = runtime_sync_bytes_op_payload_native(handle, op_id, err_ptr)
  let payload_result = native_bytes_result(
    err_ptr, payload, "runtime_sync_bytes_op_payload_native failed",
  )
  guard payload_result is Ok(_) else { return Err(payload_result.unwrap_err()) }

  runtime_sync_bytes_op_delete_native(handle, op_id)

  Ok(
    Some(SyncBytesOpRequest::{
      id: op_id,
      name: name_result.unwrap(),
      payload: payload_result.unwrap(),
    }),
  )
}

///|
pub fn Runtime::take_async_json_op(
  self : Runtime,
) -> Result[AsyncJsonOpRequest?, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let op_id = runtime_take_async_json_op_native(handle, err_ptr)
  let op_id_result = native_optional_id_result(
    err_ptr, op_id, "runtime_take_async_json_op_native failed",
  )
  guard op_id_result is Ok(_) else { return Err(op_id_result.unwrap_err()) }
  let op_id = match op_id_result.unwrap() {
    Some(op_id) => op_id
    None => return Ok(None)
  }

  native_ptr_clear(err_ptr)
  let name_bytes = runtime_async_json_op_name_native(handle, op_id, err_ptr)
  let name_result = native_string_result(
    err_ptr, name_bytes, "runtime_async_json_op_name_native failed",
  )
  guard name_result is Ok(_) else { return Err(name_result.unwrap_err()) }

  native_ptr_clear(err_ptr)
  let payload_json_bytes = runtime_async_json_op_payload_json_native(
    handle, op_id, err_ptr,
  )
  let payload_json_result = native_string_result(
    err_ptr, payload_json_bytes, "runtime_async_json_op_payload_json_native failed",
  )
  guard payload_json_result is Ok(_) else {
    return Err(payload_json_result.unwrap_err())
  }

  Ok(
    Some(AsyncJsonOpRequest::{
      id: op_id,
      name: name_result.unwrap(),
      payload_json: payload_json_result.unwrap(),
    }),
  )
}

///|
pub fn Runtime::take_async_bytes_op(
  self : Runtime,
) -> Result[AsyncBytesOpRequest?, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let op_id = runtime_take_async_bytes_op_native(handle, err_ptr)
  let op_id_result = native_optional_id_result(
    err_ptr, op_id, "runtime_take_async_bytes_op_native failed",
  )
  guard op_id_result is Ok(_) else { return Err(op_id_result.unwrap_err()) }
  let op_id = match op_id_result.unwrap() {
    Some(op_id) => op_id
    None => return Ok(None)
  }

  native_ptr_clear(err_ptr)
  let name_bytes = runtime_async_bytes_op_name_native(handle, op_id, err_ptr)
  let name_result = native_string_result(
    err_ptr, name_bytes, "runtime_async_bytes_op_name_native failed",
  )
  guard name_result is Ok(_) else { return Err(name_result.unwrap_err()) }

  native_ptr_clear(err_ptr)
  let payload = runtime_async_bytes_op_payload_native(handle, op_id, err_ptr)
  let payload_result = native_bytes_result(
    err_ptr, payload, "runtime_async_bytes_op_payload_native failed",
  )
  guard payload_result is Ok(_) else { return Err(payload_result.unwrap_err()) }

  Ok(
    Some(AsyncBytesOpRequest::{
      id: op_id,
      name: name_result.unwrap(),
      payload: payload_result.unwrap(),
    }),
  )
}

///|
pub fn Runtime::resolve_async_json_op(
  self : Runtime,
  op_id : UInt64,
  result_json : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let result_json_bytes = @utf8.encode(result_json)
  runtime_resolve_async_json_op_native(
    handle,
    op_id,
    result_json_bytes,
    result_json_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_resolve_async_json_op_native failed")
}

///|
pub fn Runtime::resolve_async_bytes_op(
  self : Runtime,
  op_id : UInt64,
  result_bytes : Bytes,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  runtime_resolve_async_bytes_op_native(
    handle,
    op_id,
    result_bytes,
    result_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_resolve_async_bytes_op_native failed")
}

///|
pub fn Runtime::reject_async_json_op(
  self : Runtime,
  op_id : UInt64,
  message : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let message_bytes = @utf8.encode(message)
  runtime_reject_async_json_op_native(
    handle,
    op_id,
    message_bytes,
    message_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_reject_async_json_op_native failed")
}

///|
pub fn Runtime::reject_async_json_op_with_json(
  self : Runtime,
  op_id : UInt64,
  error_json : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let error_json_bytes = @utf8.encode(error_json)
  runtime_reject_async_json_op_with_json_native(
    handle,
    op_id,
    error_json_bytes,
    error_json_bytes.length(),
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_reject_async_json_op_with_json_native failed",
  )
}

///|
pub fn Runtime::reject_async_bytes_op(
  self : Runtime,
  op_id : UInt64,
  message : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let message_bytes = @utf8.encode(message)
  runtime_reject_async_bytes_op_native(
    handle,
    op_id,
    message_bytes,
    message_bytes.length(),
    err_ptr,
  )
  native_unit_result(err_ptr, "runtime_reject_async_bytes_op_native failed")
}

///|
pub fn Runtime::reject_async_bytes_op_with_json(
  self : Runtime,
  op_id : UInt64,
  error_json : String,
) -> Result[Unit, V8Error] {
  let prepared = prepare_runtime_call(self)
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  let (handle, err_ptr) = prepared.unwrap()
  let error_json_bytes = @utf8.encode(error_json)
  runtime_reject_async_bytes_op_with_json_native(
    handle,
    op_id,
    error_json_bytes,
    error_json_bytes.length(),
    err_ptr,
  )
  native_unit_result(
    err_ptr, "runtime_reject_async_bytes_op_with_json_native failed",
  )
}
