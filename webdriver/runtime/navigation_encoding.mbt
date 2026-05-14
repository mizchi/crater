///|
extern "js" fn js_encode_base64_utf8(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return btoa(unescape(encodeURIComponent(value)));
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_encode_base64_raw(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return btoa(String(value ?? ""));
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_json_ensure_ascii(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return JSON.stringify(JSON.parse(value)).replace(/[\u007f-\uffff]/g, (ch) =>
  #|       '\\u' + ch.charCodeAt(0).toString(16).padStart(4, '0')
  #|     );
  #|   } catch (_e) {
  #|     return value;
  #|   }
  #| }

///|
extern "js" fn js_extract_inline_script_blocks(html : String) -> Array[String] =
  #| (html) => {
  #|   if (typeof html !== "string" || html === "") {
  #|     return [];
  #|   }
  #|   const result = [];
  #|   const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  #|   let match;
  #|   while ((match = pattern.exec(html)) !== null) {
  #|     const attrs = match[1] || "";
  #|     if (/\bsrc\s*=/.test(attrs)) {
  #|       continue;
  #|     }
  #|     const script = (match[2] || "").trim();
  #|     if (script !== "") {
  #|       result.push(script);
  #|     }
  #|   }
  #|   return result;
  #| }

///|
pub fn encode_base64_utf8(value : String) -> String {
  js_encode_base64_utf8(value)
}

///|
pub fn encode_base64_raw(value : String) -> String {
  js_encode_base64_raw(value)
}

///|
pub fn json_ensure_ascii(value : String) -> String {
  js_json_ensure_ascii(value)
}

///|
pub fn extract_inline_script_blocks(html : String) -> Array[String] {
  js_extract_inline_script_blocks(html)
}

///|
pub fn build_html_data_url(html : String) -> String {
  "data:text/html;charset=utf-8;base64," + encode_base64_utf8(html)
}
