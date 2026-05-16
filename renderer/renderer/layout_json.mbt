///|
/// Layout JSON serialization helpers.

///|
/// Sanitize a number for JSON output (handle Infinity and NaN)
fn safe_number(n : Double) -> Double {
  // Check for Infinity or very large numbers (>= 1e10 is likely a placeholder infinity)
  if n >= 1.0e10 || n <= -1.0e10 {
    return 0.0
  }
  // Check for NaN (NaN != NaN)
  if n != n {
    return 0.0
  }
  n
}

///|
/// Convert a number to JSON string safely
fn number_to_json(n : Double) -> String {
  safe_number(n).to_string()
}

///|
/// Write a number to the JSON buffer safely.
fn write_number_json(buf : StringBuilder, n : Double) -> Unit {
  buf.write_string(number_to_json(n))
}

///|
/// Write Rect JSON directly to the output buffer to avoid temporary strings.
fn write_rect_json(buf : StringBuilder, rect : @types.Rect[Double]) -> Unit {
  buf.write_string("{\"top\":")
  write_number_json(buf, rect.top)
  buf.write_string(",\"right\":")
  write_number_json(buf, rect.right)
  buf.write_string(",\"bottom\":")
  write_number_json(buf, rect.bottom)
  buf.write_string(",\"left\":")
  write_number_json(buf, rect.left)
  buf.write_string("}")
}

///|
/// Convert layout to JSON string (with Box Model)
pub fn layout_to_json(layout : @layout_types.Layout) -> String {
  let buf = StringBuilder::new(size_hint=estimate_layout_json_size(layout))
  layout_to_json_impl(layout, buf)
  buf.to_string()
}

///|
fn estimate_layout_json_size(layout : @layout_types.Layout) -> Int {
  let mut estimated = 120 + layout.id.length() * 2
  for child in layout.children {
    estimated = estimated + estimate_layout_json_size(child) + 2
  }
  estimated
}

///|
fn layout_to_json_impl(
  layout : @layout_types.Layout,
  buf : StringBuilder,
) -> Unit {
  buf.write_string("{\"id\":\"")
  buf.write_string(escape_json_string(layout.id))
  buf.write_string("\",\"x\":")
  write_number_json(buf, layout.x)
  buf.write_string(",\"y\":")
  write_number_json(buf, layout.y)
  buf.write_string(",\"width\":")
  write_number_json(buf, layout.width)
  buf.write_string(",\"height\":")
  write_number_json(buf, layout.height)
  buf.write_string(",\"margin\":")
  write_rect_json(buf, layout.margin)
  buf.write_string(",\"padding\":")
  write_rect_json(buf, layout.padding)
  buf.write_string(",\"border\":")
  write_rect_json(buf, layout.border)
  buf.write_string(",\"children\":[")
  for i, child in layout.children {
    if i > 0 {
      buf.write_string(",")
    }
    layout_to_json_impl(child, buf)
  }
  buf.write_string("]}")
}

///|
/// Escape special characters in JSON string
fn escape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
