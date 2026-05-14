///|
extern "js" fn js_utf8_byte_length(value : String) -> Int =
  #| (value) => new TextEncoder().encode(String(value ?? "")).length

///|
extern "js" fn js_base64_byte_length(value : String) -> Int =
  #| (value) => {
  #|   try {
  #|     return Uint8Array.from(atob(String(value ?? "")), (c) => c.charCodeAt(0)).length;
  #|   } catch (_) {
  #|     return 0;
  #|   }
  #| }

///|
extern "js" fn js_decode_query_component(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     const text = value === null || value === undefined ? "" : String(value);
  #|     return decodeURIComponent(text.replace(/\+/g, " "));
  #|   } catch (_) {
  #|     return value === null || value === undefined ? "" : String(value);
  #|   }
  #| }

///|
pub fn utf8_byte_length(value : String) -> Int {
  js_utf8_byte_length(value)
}

///|
pub fn base64_byte_length(value : String) -> Int {
  js_base64_byte_length(value)
}

///|
pub fn decode_query_component(value : String) -> String {
  js_decode_query_component(value)
}
