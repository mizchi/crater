///|
fn prepare_runtime_call(runtime : Runtime) -> Result[(UInt64, Bytes), V8Error] {
  match runtime.state.val.handle {
    0 => Err(V8Error::RuntimeClosed)
    handle => {
      let err_ptr = make_ptr_buffer()
      native_ptr_clear(err_ptr)
      Ok((handle, err_ptr))
    }
  }
}

///|
fn native_unit_result(
  err_ptr : Bytes,
  fallback : String,
) -> Result[Unit, V8Error] {
  if native_ptr_is_null(err_ptr) {
    Ok(())
  } else {
    Err(take_native_error(err_ptr, V8Error::NativeError(fallback)))
  }
}

///|
fn native_string_result(
  err_ptr : Bytes,
  result_bytes : Bytes,
  fallback : String,
) -> Result[String, V8Error] {
  if native_ptr_is_null(err_ptr) {
    Ok(@utf8.decode_lossy(result_bytes))
  } else {
    Err(take_native_error(err_ptr, V8Error::NativeError(fallback)))
  }
}

///|
fn native_bytes_result(
  err_ptr : Bytes,
  result_bytes : Bytes,
  fallback : String,
) -> Result[Bytes, V8Error] {
  if native_ptr_is_null(err_ptr) {
    Ok(result_bytes)
  } else {
    Err(take_native_error(err_ptr, V8Error::NativeError(fallback)))
  }
}

///|
fn native_optional_id_result(
  err_ptr : Bytes,
  value : UInt64,
  fallback : String,
) -> Result[UInt64?, V8Error] {
  if not(native_ptr_is_null(err_ptr)) {
    Err(take_native_error(err_ptr, V8Error::NativeError(fallback)))
  } else if value == 0 {
    Ok(None)
  } else {
    Ok(Some(value))
  }
}
