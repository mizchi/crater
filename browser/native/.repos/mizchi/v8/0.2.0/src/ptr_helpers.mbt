///|
extern "C" fn native_ptr_sizeof() -> Int = "moonbit_ptr_sizeof"

///|
#borrow(bytes)
extern "C" fn native_ptr_is_null(bytes : Bytes) -> Bool = "moonbit_ptr_is_null"

///|
#borrow(bytes)
extern "C" fn native_ptr_clear(bytes : Bytes) -> Unit = "moonbit_ptr_clear"

///|
#borrow(bytes)
extern "C" fn native_error_delete_ptr(bytes : Bytes) -> Unit = "moonbit_v8_error_delete_ptr"

///|
#borrow(bytes)
extern "C" fn native_error_message_bytes(bytes : Bytes) -> Bytes = "moonbit_v8_error_message_bytes"

///|
fn make_ptr_buffer() -> Bytes {
  Bytes::make(native_ptr_sizeof(), 0)
}

///|
fn take_native_error(err_ptr : Bytes, fallback : V8Error) -> V8Error {
  if native_ptr_is_null(err_ptr) {
    fallback
  } else {
    let msg = @utf8.decode_lossy(native_error_message_bytes(err_ptr))
    native_error_delete_ptr(err_ptr)
    if msg == "" {
      fallback
    } else {
      V8Error::NativeError(msg)
    }
  }
}
