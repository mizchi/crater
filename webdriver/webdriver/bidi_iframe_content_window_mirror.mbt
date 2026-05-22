///|
/// Cross-frame DOM mirror generalization (#182 slice 5).
///
/// The synthetic iframe handler at try_handle_synthetic_iframe_creation
/// previously hardcoded ONE shape for cross-frame property access:
///
///   window.baz = iframe.contentWindow.foo
///
/// Real pages assign to arbitrary LHS targets and read property chains
/// through any iframe variable. This module extracts the (lhs, chain)
/// tuple from the expression so the handler can mirror read-only
/// property/index access.
///
/// Scope and limits:
///
/// - Only assignments of the literal form
///   `<lhs> = <var>.contentWindow.<chain>` are recognized. Compound
///   expressions (function calls, arithmetic on the RHS) fall through
///   to the broader synthetic flow without mirror.
/// - The read source is always `window.<chain>` in the child realm.
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
fn read_iframe_mirror_identifier_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() && is_iframe_mirror_identifier_char(chars[end]) {
    end += 1
  }
  end
}

///|
fn read_iframe_mirror_bracket_end(chars : Array[Char], start : Int) -> Int? {
  let mut cursor = start + 1
  let mut quote : Char? = None
  let mut escaped = false
  while cursor < chars.length() {
    let c = chars[cursor]
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == q {
          quote = None
        }
      None =>
        if c == '"' || c == '\'' {
          quote = Some(c)
        } else if c == ']' {
          return Some(cursor + 1)
        } else if c == '(' || c == ')' || c == ';' {
          return None
        }
    }
    cursor += 1
  }
  None
}

///|
fn skip_iframe_mirror_whitespace(chars : Array[Char], start : Int) -> Int {
  let mut cursor = start
  while cursor < chars.length() && is_iframe_mirror_whitespace(chars[cursor]) {
    cursor += 1
  }
  cursor
}

///|
fn is_iframe_mirror_rhs_terminator(c : Char) -> Bool {
  c == ';' || c == '}'
}

///|
/// Extract the (lhs, chain) tuple from a cross-frame mirror expression
/// like `<lhs> = <iframeVar>.contentWindow.<chain>`. Returns None if no
/// matching pattern is present.
///
/// Examples:
///
/// - `window.baz = iframe.contentWindow.foo` → Some(("window.baz", "foo"))
/// - `globalThis.captured = f.contentWindow.theProp;` → Some(("globalThis.captured", "theProp"))
/// - `window.key = iframe.contentWindow.config.apiKey` → Some(("window.key", "config.apiKey"))
/// - `iframe.src = '/x'` (no .contentWindow.) → None
fn extract_iframe_content_window_mirror(source : String) -> (String, String)? {
  let marker = ".contentWindow."
  let marker_idx = match find_substring(source, marker, 0) {
    Some(idx) => idx
    None => return None
  }
  let chars = source.to_array()
  let len = chars.length()
  // Extract chain: identifier after the marker, followed by zero or
  // more `.identifier` or `[index]` / `["key"]` accesses.
  let chain_start = marker_idx + marker.length()
  let mut chain_end = read_iframe_mirror_identifier_end(chars, chain_start)
  if chain_end == chain_start {
    return None
  }
  let mut done = false
  while !done && chain_end < len {
    if chars[chain_end] == '.' {
      let next_start = chain_end + 1
      let next_end = read_iframe_mirror_identifier_end(chars, next_start)
      if next_end == next_start {
        return None
      }
      chain_end = next_end
    } else if chars[chain_end] == '[' {
      match read_iframe_mirror_bracket_end(chars, chain_end) {
        Some(next_end) => chain_end = next_end
        None => return None
      }
    } else {
      done = true
    }
  }
  let rhs_tail = skip_iframe_mirror_whitespace(chars, chain_end)
  if rhs_tail < len && !is_iframe_mirror_rhs_terminator(chars[rhs_tail]) {
    return None
  }
  let chain = source.unsafe_substring(start=chain_start, end=chain_end)
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
  Some((lhs, chain))
}
