///|
extern "C" fn version_bytes_native() -> Bytes = "moonbit_v8_version_bytes"

///|
#borrow(source, error_out)
extern "C" fn snapshot_create_native(
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_snapshot_create"

///|
#borrow(snapshot, source, error_out)
extern "C" fn snapshot_extend_native(
  snapshot : Bytes,
  snapshot_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_snapshot_extend"

///|
#borrow(error_out)
extern "C" fn runtime_new_native(error_out : Bytes) -> UInt64 = "moonbit_v8_runtime_new"

///|

///|
#borrow(snapshot, error_out)
extern "C" fn runtime_new_with_snapshot_native(
  snapshot : Bytes,
  snapshot_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_new_with_snapshot"

///|
extern "C" fn runtime_delete_native(handle : UInt64) -> Unit = "moonbit_v8_runtime_delete"

///|
#borrow(specifier, source, error_out)
extern "C" fn runtime_load_module_native(
  handle : UInt64,
  specifier : Bytes,
  specifier_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_load_module"

///|
#borrow(name, error_out)
extern "C" fn runtime_register_sync_json_op_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_sync_json_op"

///|
#borrow(name, payload_json, result_json, error_out)
extern "C" fn runtime_push_sync_json_op_response_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  payload_json : Bytes,
  payload_json_len : Int,
  result_json : Bytes,
  result_json_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_push_sync_json_op_response"

///|
#borrow(name, error_out)
#owned(callback)
extern "C" fn runtime_register_sync_json_callback_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  call_closure : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  callback : (Bytes) -> Bytes,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_sync_json_callback"

///|
#borrow(error_out)
extern "C" fn runtime_take_sync_json_op_native(
  handle : UInt64,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_take_sync_json_op"

///|
#borrow(error_out)
extern "C" fn runtime_sync_json_op_name_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_sync_json_op_name"

///|
#borrow(error_out)
extern "C" fn runtime_sync_json_op_payload_json_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_sync_json_op_payload_json"

///|
extern "C" fn runtime_sync_json_op_delete_native(
  handle : UInt64,
  op_id : UInt64,
) -> Unit = "moonbit_v8_runtime_sync_json_op_delete"

///|
#borrow(name, error_out)
extern "C" fn runtime_register_sync_bytes_op_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_sync_bytes_op"

///|
#borrow(name, payload, result_bytes, error_out)
extern "C" fn runtime_push_sync_bytes_op_response_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  payload : Bytes,
  payload_len : Int,
  result_bytes : Bytes,
  result_bytes_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_push_sync_bytes_op_response"

///|
#borrow(name, error_out)
#owned(callback)
extern "C" fn runtime_register_sync_bytes_callback_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  call_closure : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  callback : (Bytes) -> Bytes,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_sync_bytes_callback"

///|
#borrow(error_out)
extern "C" fn runtime_take_sync_bytes_op_native(
  handle : UInt64,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_take_sync_bytes_op"

///|
#borrow(error_out)
extern "C" fn runtime_sync_bytes_op_name_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_sync_bytes_op_name"

///|
#borrow(error_out)
extern "C" fn runtime_sync_bytes_op_payload_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_sync_bytes_op_payload"

///|
extern "C" fn runtime_sync_bytes_op_delete_native(
  handle : UInt64,
  op_id : UInt64,
) -> Unit = "moonbit_v8_runtime_sync_bytes_op_delete"

///|
#borrow(name, error_out)
extern "C" fn runtime_register_async_json_op_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_async_json_op"

///|
#borrow(name, error_out)
#owned(callback)
extern "C" fn runtime_register_async_json_callback_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  call_closure : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  callback : (Bytes) -> Bytes,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_async_json_callback"

///|
#borrow(error_out)
extern "C" fn runtime_take_async_json_op_native(
  handle : UInt64,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_take_async_json_op"

///|
#borrow(error_out)
extern "C" fn runtime_async_json_op_name_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_async_json_op_name"

///|
#borrow(error_out)
extern "C" fn runtime_async_json_op_payload_json_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_async_json_op_payload_json"

///|
#borrow(result_json, error_out)
extern "C" fn runtime_resolve_async_json_op_native(
  handle : UInt64,
  op_id : UInt64,
  result_json : Bytes,
  result_json_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_resolve_async_json_op"

///|
#borrow(message, error_out)
extern "C" fn runtime_reject_async_json_op_native(
  handle : UInt64,
  op_id : UInt64,
  message : Bytes,
  message_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_reject_async_json_op"

///|
#borrow(error_json, error_out)
extern "C" fn runtime_reject_async_json_op_with_json_native(
  handle : UInt64,
  op_id : UInt64,
  error_json : Bytes,
  error_json_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_reject_async_json_op_with_json"

///|
#borrow(name, error_out)
extern "C" fn runtime_register_async_bytes_op_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_async_bytes_op"

///|
#borrow(name, error_out)
#owned(callback)
extern "C" fn runtime_register_async_bytes_callback_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  call_closure : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  callback : (Bytes) -> Bytes,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_register_async_bytes_callback"

///|
#borrow(error_out)
extern "C" fn runtime_take_async_bytes_op_native(
  handle : UInt64,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_take_async_bytes_op"

///|
#borrow(error_out)
extern "C" fn runtime_async_bytes_op_name_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_async_bytes_op_name"

///|
#borrow(error_out)
extern "C" fn runtime_async_bytes_op_payload_native(
  handle : UInt64,
  op_id : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_async_bytes_op_payload"

///|
#borrow(result_bytes, error_out)
extern "C" fn runtime_resolve_async_bytes_op_native(
  handle : UInt64,
  op_id : UInt64,
  result_bytes : Bytes,
  result_bytes_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_resolve_async_bytes_op"

///|
#borrow(message, error_out)
extern "C" fn runtime_reject_async_bytes_op_native(
  handle : UInt64,
  op_id : UInt64,
  message : Bytes,
  message_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_reject_async_bytes_op"

///|
#borrow(error_json, error_out)
extern "C" fn runtime_reject_async_bytes_op_with_json_native(
  handle : UInt64,
  op_id : UInt64,
  error_json : Bytes,
  error_json_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_reject_async_bytes_op_with_json"

///|
#borrow(name, json, error_out)
extern "C" fn runtime_set_global_json_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  json : Bytes,
  json_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_set_global_json"

///|
#borrow(name, error_out)
extern "C" fn runtime_get_global_json_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_get_global_json"

///|
#borrow(name, bytes, error_out)
extern "C" fn runtime_set_global_bytes_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  bytes : Bytes,
  bytes_len : Int,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_set_global_bytes"

///|
#borrow(name, error_out)
extern "C" fn runtime_get_global_bytes_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_get_global_bytes"

///|
#borrow(name, bytes, error_out)
extern "C" fn runtime_call_global_bytes_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  bytes : Bytes,
  bytes_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_call_global_bytes"

///|
#borrow(name, args_json, error_out)
extern "C" fn runtime_call_global_json_native(
  handle : UInt64,
  name : Bytes,
  name_len : Int,
  args_json : Bytes,
  args_json_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_call_global_json"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_json_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_json"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_bytes_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_bytes"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_promise_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_eval_promise"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_with_name"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_json_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_json_with_name"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_bytes_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_bytes_with_name"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_promise_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_eval_promise_with_name"

///|
#borrow(error_out)
extern "C" fn runtime_perform_microtask_checkpoint_native(
  handle : UInt64,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_perform_microtask_checkpoint"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_async_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_async_json_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async_json"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_async_bytes_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async_bytes"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_async_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async_with_name"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_async_json_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async_json_with_name"

///|
#borrow(resource_name, source, error_out)
extern "C" fn runtime_eval_async_bytes_with_name_native(
  handle : UInt64,
  resource_name : Bytes,
  resource_name_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async_bytes_with_name"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_module_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_module"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_module_handle_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_eval_module_handle"

///|
#borrow(specifier, source, error_out)
extern "C" fn runtime_eval_module_with_specifier_native(
  handle : UInt64,
  specifier : Bytes,
  specifier_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_module_with_specifier"

///|
#borrow(specifier, source, error_out)
extern "C" fn runtime_eval_module_handle_with_specifier_native(
  handle : UInt64,
  specifier : Bytes,
  specifier_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_eval_module_handle_with_specifier"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_module_handle_async_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_eval_module_handle_async"

///|
#borrow(specifier, source, error_out)
extern "C" fn runtime_eval_module_handle_async_with_specifier_native(
  handle : UInt64,
  specifier : Bytes,
  specifier_len : Int,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_eval_module_handle_async_with_specifier"

///|
#borrow(error_out)
extern "C" fn runtime_module_evaluation_promise_native(
  handle : UInt64,
  module_handle : UInt64,
  error_out : Bytes,
) -> UInt64 = "moonbit_v8_runtime_module_evaluation_promise"

///|
#borrow(export_name, error_out)
extern "C" fn runtime_module_get_export_json_native(
  handle : UInt64,
  module_handle : UInt64,
  export_name : Bytes,
  export_name_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_module_get_export_json"

///|
#borrow(error_out)
extern "C" fn runtime_module_export_names_native(
  handle : UInt64,
  module_handle : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_module_export_names"

///|
#borrow(export_name, error_out)
extern "C" fn runtime_module_get_export_bytes_native(
  handle : UInt64,
  module_handle : UInt64,
  export_name : Bytes,
  export_name_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_module_get_export_bytes"

///|
#borrow(export_name, args_json, error_out)
extern "C" fn runtime_module_call_export_json_native(
  handle : UInt64,
  module_handle : UInt64,
  export_name : Bytes,
  export_name_len : Int,
  args_json : Bytes,
  args_json_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_module_call_export_json"

///|
#borrow(export_name, bytes, error_out)
extern "C" fn runtime_module_call_export_bytes_native(
  handle : UInt64,
  module_handle : UInt64,
  export_name : Bytes,
  export_name_len : Int,
  bytes : Bytes,
  bytes_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_module_call_export_bytes"

///|
extern "C" fn runtime_module_delete_native(
  handle : UInt64,
  module_handle : UInt64,
) -> Unit = "moonbit_v8_runtime_module_delete"

///|
#borrow(error_out)
extern "C" fn runtime_promise_state_native(
  handle : UInt64,
  promise_handle : UInt64,
  error_out : Bytes,
) -> Int = "moonbit_v8_runtime_promise_state"

///|
#borrow(error_out)
extern "C" fn runtime_promise_result_native(
  handle : UInt64,
  promise_handle : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_promise_result"

///|
#borrow(error_out)
extern "C" fn runtime_promise_result_json_native(
  handle : UInt64,
  promise_handle : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_promise_result_json"

///|
#borrow(error_out)
extern "C" fn runtime_promise_result_bytes_native(
  handle : UInt64,
  promise_handle : UInt64,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_promise_result_bytes"

///|
extern "C" fn runtime_promise_delete_native(
  handle : UInt64,
  promise_handle : UInt64,
) -> Unit = "moonbit_v8_runtime_promise_delete"
