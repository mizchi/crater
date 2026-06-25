///|
/// Whether `css[i..]` begins with the at-rule `@layer` followed by a boundary.
fn at_layer_keyword_at(css : String, i : Int) -> Bool {
  let kw = "@layer"
  if i + kw.length() > css.length() {
    return false
  }
  let mut k = 0
  while k < kw.length() {
    let c = css[i + k].to_int().unsafe_to_char()
    let lc = if c >= 'A' && c <= 'Z' {
      (c.to_int() + 32).unsafe_to_char()
    } else {
      c
    }
    if lc != kw[k].to_int().unsafe_to_char() {
      return false
    }
    k += 1
  }
  if i + kw.length() >= css.length() {
    return true
  }
  let nc = css[i + kw.length()].to_int().unsafe_to_char()
  nc == ' ' || nc == '\t' || nc == '\n' || nc == '\r' || nc == '{' || nc == ';'
}

///|
/// Flatten CSS cascade layers so their rules are not dropped before parsing.
/// The current parser does not understand `@layer`, so `@layer name { rules }`
/// is rewritten to just `rules` (layer precedence is approximated by source
/// order), and bare `@layer a, b;` declarations are removed. Modern CSS
/// frameworks (Primer, Tailwind, Bootstrap) place their base/reset rules — body
/// margin, `* { box-sizing: border-box }`, normalize — inside `@layer`, so
/// dropping those badly distorts layout.
pub fn flatten_css_cascade_layers(css : String) -> String {
  // Fast path: avoid the rewrite when there is no @layer at all.
  if !css.contains("@layer") {
    return css
  }
  let out = StringBuilder::new()
  let len = css.length()
  let mut i = 0
  let mut depth = 0
  let layer_depths : Array[Int] = []
  while i < len {
    let c = css[i].to_int().unsafe_to_char()
    // Pass comments and strings through untouched so braces / "@layer" inside
    // them cannot corrupt brace counting.
    if c == '/' && i + 1 < len && css[i + 1].to_int().unsafe_to_char() == '*' {
      out.write_char(c)
      out.write_char('*')
      i += 2
      while i < len {
        let d = css[i].to_int().unsafe_to_char()
        out.write_char(d)
        i += 1
        if d == '*' && i < len && css[i].to_int().unsafe_to_char() == '/' {
          out.write_char('/')
          i += 1
          break
        }
      }
      continue
    }
    if c == '"' || c == '\'' {
      let quote = c
      out.write_char(c)
      i += 1
      while i < len {
        let d = css[i].to_int().unsafe_to_char()
        out.write_char(d)
        i += 1
        if d == '\\' && i < len {
          out.write_char(css[i].to_int().unsafe_to_char())
          i += 1
        } else if d == quote {
          break
        }
      }
      continue
    }
    if c == '@' && at_layer_keyword_at(css, i) {
      // Find the next '{' or ';'.
      let mut j = i + 6
      while j < len {
        let nc = css[j].to_int().unsafe_to_char()
        if nc == '{' || nc == ';' {
          break
        }
        j += 1
      }
      if j < len && css[j].to_int().unsafe_to_char() == '{' {
        // `@layer name { ... }`: drop the prefix; the matching close brace at
        // this depth is dropped when reached.
        depth += 1
        layer_depths.push(depth)
        i = j + 1
      } else {
        // `@layer name;` or unterminated: drop the whole statement.
        i = if j < len { j + 1 } else { len }
      }
      continue
    }
    if c == '{' {
      depth += 1
      out.write_char(c)
    } else if c == '}' {
      if layer_depths.length() > 0 &&
        layer_depths[layer_depths.length() - 1] == depth {
        layer_depths.pop() |> ignore
        depth -= 1
        // drop this layer's closing brace
      } else {
        depth -= 1
        out.write_char(c)
      }
    } else {
      out.write_char(c)
    }
    i += 1
  }
  out.to_string()
}
