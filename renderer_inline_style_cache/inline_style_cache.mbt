///|
let inline_style_display_cache : Ref[Map[String, @types.Display?]] = { val: {} }

///|
let inline_declaration_cache : Ref[Map[String, Array[(String, String)]]] = {
  val: {},
}

///|
let inline_only_style_cache : Ref[Map[String, Map[String, @style.Style]]] = {
  val: {},
}

///|
fn view_to_string(v : StringView) -> String {
  let sb = StringBuilder::new()
  sb.write_stringview(v)
  sb.to_string()
}

///|
pub fn make_inline_only_style_cache_variant_key(
  tag : String,
  is_root : Bool,
  viewport_width : Double,
  viewport_height : Double,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(tag.to_lower())
  buf.write_string("|")
  buf.write_string(if is_root { "1" } else { "0" })
  buf.write_string("|")
  buf.write_string((viewport_width * 10.0).to_int().to_string())
  buf.write_string("|")
  buf.write_string((viewport_height * 10.0).to_int().to_string())
  buf.to_string()
}

///|
pub fn parse_inline_declarations_cached(
  inline_css : String,
) -> Array[(String, String)] {
  let cache = inline_declaration_cache.val
  match cache.get(inline_css) {
    Some(cached) => cached
    None => {
      let parsed : Array[(String, String)] = []
      let decls = inline_css.split(";")
      for decl in decls {
        let decl_str = decl.trim()
        if decl_str.length() == 0 {
          continue
        }
        let mut colon_idx = -1
        for i = 0; i < decl_str.length(); i = i + 1 {
          if decl_str[i] == ':' {
            colon_idx = i
            break
          }
        }
        if colon_idx > 0 {
          let prop = view_to_string(decl_str.view(end_offset=colon_idx))
            .trim()
            .to_string()
            .to_lower()
          let value = view_to_string(decl_str.view(start_offset=colon_idx + 1))
            .trim()
            .to_string()
          if prop.length() > 0 && value.length() > 0 {
            parsed.push((prop, value))
          }
        }
      }
      cache[inline_css] = parsed
      parsed
    }
  }
}

///|
pub fn get_cached_inline_style_display(style_str : String) -> @types.Display? {
  let cache = inline_style_display_cache.val
  match cache.get(style_str) {
    Some(cached) => cached
    None => {
      let style_lower = style_str.to_lower()
      let parsed_display = if style_lower.contains("display:") ||
        style_lower.contains("display :") {
        let parsed = @css.parse_inline_style(style_str)
        Some(parsed.display)
      } else {
        None
      }
      cache[style_str] = parsed_display
      parsed_display
    }
  }
}

///|
pub fn inline_only_style_cache_get(
  inline_css : String,
  variant_key : String,
) -> @style.Style? {
  match inline_only_style_cache.val.get(inline_css) {
    Some(variants) => variants.get(variant_key)
    None => None
  }
}

///|
pub fn inline_only_style_cache_put(
  inline_css : String,
  variant_key : String,
  style : @style.Style,
) -> Unit {
  let cache = inline_only_style_cache.val
  let variants = match cache.get(inline_css) {
    Some(existing) => existing
    None => {}
  }
  variants[variant_key] = style
  cache[inline_css] = variants
}
