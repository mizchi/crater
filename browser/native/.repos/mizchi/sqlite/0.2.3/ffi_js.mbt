// Minimal JS FFI helpers for Node.js SQLite bindings

///|
pub(all) type JsAny

///|
pub extern "js" fn js_null() -> JsAny =
  #| () => null

///|
pub extern "js" fn js_undefined() -> JsAny =
  #| () => undefined

///|
#borrow(v)
pub extern "js" fn is_nullish(v : JsAny) -> Bool =
  #| (v) => v == null

///|
#borrow(v)
pub extern "js" fn typeof_(v : JsAny) -> String =
  #| (v) => typeof v

///|
#borrow(v)
pub extern "js" fn is_integer(v : JsAny) -> Bool =
  #| (v) => Number.isInteger(v)

///|
pub extern "js" fn to_any_int(v : Int) -> JsAny =
  #| (v) => v

///|
pub extern "js" fn to_any_int64(v : Int64) -> JsAny =
  #| (v) => v

///|
pub extern "js" fn to_any_double(v : Double) -> JsAny =
  #| (v) => v

///|
pub extern "js" fn to_any_string(v : String) -> JsAny =
  #| (v) => v

///|
pub extern "js" fn to_any_bool(v : Bool) -> JsAny =
  #| (v) => v

///|
pub extern "js" fn to_any_bytes(v : Bytes) -> JsAny =
  #| (v) => v

///|
#borrow(v)
pub extern "js" fn from_any_int(v : JsAny) -> Int =
  #| (v) => v

///|
#borrow(v)
pub extern "js" fn from_any_int64(v : JsAny) -> Int64 =
  #| (v) => v

///|
#borrow(v)
pub extern "js" fn from_any_double(v : JsAny) -> Double =
  #| (v) => v

///|
#borrow(v)
pub extern "js" fn from_any_string(v : JsAny) -> String =
  #| (v) => v

///|
#borrow(v)
pub extern "js" fn from_any_bytes(v : JsAny) -> Bytes =
  #| (v) => v

///|
#borrow(obj, key)
pub extern "js" fn js_get(obj : JsAny, key : String) -> JsAny =
  #| (obj, key) => obj[key]

///|
#borrow(obj)
pub extern "js" fn js_get_index(obj : JsAny, idx : Int) -> JsAny =
  #| (obj, idx) => obj[idx]

///|
#borrow(obj, key, value)
pub extern "js" fn js_set(obj : JsAny, key : String, value : JsAny) -> Unit =
  #| (obj, key, value) => { obj[key] = value }

///|
#borrow(obj, method)
pub extern "js" fn js_call0(obj : JsAny, method : String) -> JsAny =
  #| (obj, method) => obj[method]()

///|
#borrow(obj, method, arg)
pub extern "js" fn js_call1(obj : JsAny, method : String, arg : JsAny) -> JsAny =
  #| (obj, method, arg) => obj[method](arg)

///|
#borrow(obj, method, a1, a2)
pub extern "js" fn js_call2(
  obj : JsAny,
  method : String,
  a1 : JsAny,
  a2 : JsAny,
) -> JsAny =
  #| (obj, method, a1, a2) => obj[method](a1, a2)

///|
pub extern "js" fn js_new_object() -> JsAny =
  #| () => ({})

///|
pub extern "js" fn js_new_array() -> JsAny =
  #| () => []

///|
#borrow(arr, v)
pub extern "js" fn js_array_push(arr : JsAny, v : JsAny) -> Unit =
  #| (arr, v) => arr.push(v)

///|
#borrow(arr)
pub extern "js" fn js_array_length(arr : JsAny) -> Int =
  #| (arr) => arr.length

// Text encoding helpers

///|
pub extern "js" fn string_to_bytes(s : String) -> Bytes =
  #| (s) => new TextEncoder().encode(s)

///|
pub extern "js" fn bytes_to_string(b : Bytes) -> String =
  #| (b) => new TextDecoder().decode(b)

///|
#borrow(v)
pub extern "js" fn is_uint8array(v : JsAny) -> Bool =
  #| (v) => v instanceof Uint8Array

///|
#borrow(v)
pub extern "js" fn bigint_to_number(v : JsAny) -> Int =
  #| (v) => Number(v)

///|
pub extern "js" fn int64_to_number(v : Int64) -> JsAny =
  #| (v) => Number(v)

///|
#borrow(obj, func_name, args)
pub extern "js" fn js_apply(
  obj : JsAny,
  func_name : String,
  args : JsAny,
) -> JsAny =
  #| (obj, func_name, args) => obj[func_name].apply(obj, args)
