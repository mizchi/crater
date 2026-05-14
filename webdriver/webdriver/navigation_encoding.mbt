///|
/// Compatibility facade for runtime encoding helpers.

///|
fn encode_base64_utf8(value : String) -> String {
  @runtime.encode_base64_utf8(value)
}

///|
fn encode_base64_raw(value : String) -> String {
  @runtime.encode_base64_raw(value)
}

///|
fn json_ensure_ascii(value : String) -> String {
  @runtime.json_ensure_ascii(value)
}

///|
fn extract_inline_script_blocks(html : String) -> Array[String] {
  @runtime.extract_inline_script_blocks(html)
}

///|
fn build_html_data_url(html : String) -> String {
  @runtime.build_html_data_url(html)
}
