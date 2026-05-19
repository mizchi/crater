///|
/// Cross-frame DOM mirror generalization (#182 slice 5).
///
/// The synthetic iframe handler at try_handle_synthetic_iframe_creation
/// previously hardcoded ONE shape for cross-frame property access:
///
///   window.baz = iframe.contentWindow.foo
///
/// Real pages assign to arbitrary LHS targets and read arbitrary
/// properties through any iframe variable. This module extracts the
/// (lhs, prop) tuple from the expression so the handler can mirror
/// any single property assignment.
///
/// Scope and limits:
///
/// - Only assignments of the literal form `<lhs> = <var>.contentWindow.<prop>`
///   are recognized. Compound expressions (function calls, arithmetic on
///   the RHS) fall through to the broader synthetic flow without mirror.
/// - The read source is always `window.<prop>` in the child realm.
///   We don't attempt to honor nested property access like
///   `iframe.contentWindow.foo.bar` — pages that want that should use
///   a real cross-frame channel (postMessage) once it's wired.
/// - Single mirror per expression (the first match is used). The
///   hardcoded one-liner this replaces had the same constraint.

///|
/// Return true if `c` is a valid JavaScript identifier character.
fn is_iframe_mirror_identifier_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '$'
}

///|
fn is_iframe_mirror_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Extract the (lhs, prop) tuple from a cross-frame mirror expression
/// like `<lhs> = <iframeVar>.contentWindow.<prop>`. Returns None if no
/// matching pattern is present.
///
/// Examples:
///
/// - `window.baz = iframe.contentWindow.foo` → Some(("window.baz", "foo"))
/// - `globalThis.captured = f.contentWindow.theProp;` → Some(("globalThis.captured", "theProp"))
/// - `iframe.src = '/x'` (no .contentWindow.) → None
fn extract_iframe_content_window_mirror(source : String) -> (String, String)? {
  let marker = ".contentWindow."
  let marker_idx = match find_substring(source, marker, 0) {
    Some(idx) => idx
    None => return None
  }
  let chars = source.to_array()
  let len = chars.length()
  // Extract prop: identifier chars after the marker.
  let prop_start = marker_idx + marker.length()
  let mut prop_end = prop_start
  while prop_end < len && is_iframe_mirror_identifier_char(chars[prop_end]) {
    prop_end += 1
  }
  if prop_end == prop_start {
    return None
  }
  let prop = source.unsafe_substring(start=prop_start, end=prop_end)
  // Walk backward past the iframe var name.
  let mut var_start = marker_idx
  while var_start > 0 && is_iframe_mirror_identifier_char(chars[var_start - 1]) {
    var_start -= 1
  }
  if var_start == marker_idx {
    return None
  }
  // Walk backward past whitespace, expect `=`.
  let mut eq_pos = var_start
  while eq_pos > 0 && is_iframe_mirror_whitespace(chars[eq_pos - 1]) {
    eq_pos -= 1
  }
  if eq_pos == 0 || chars[eq_pos - 1] != '=' {
    return None
  }
  eq_pos -= 1
  // Walk backward past whitespace before the `=`.
  let mut lhs_end = eq_pos
  while lhs_end > 0 && is_iframe_mirror_whitespace(chars[lhs_end - 1]) {
    lhs_end -= 1
  }
  // LHS chars: identifiers + dots. Stop at any other char.
  let mut lhs_start = lhs_end
  while lhs_start > 0 {
    let c = chars[lhs_start - 1]
    if is_iframe_mirror_identifier_char(c) || c == '.' {
      lhs_start -= 1
    } else {
      break
    }
  }
  if lhs_start == lhs_end {
    return None
  }
  let lhs = source.unsafe_substring(start=lhs_start, end=lhs_end)
  // Sanity: LHS must contain at least one identifier char; not just dots.
  let lhs_chars = lhs.to_array()
  let mut has_ident = false
  for i = 0; i < lhs_chars.length(); i = i + 1 {
    if is_iframe_mirror_identifier_char(lhs_chars[i]) {
      has_ident = true
      break
    }
  }
  if !has_ident {
    return None
  }
  Some((lhs, prop))
}
