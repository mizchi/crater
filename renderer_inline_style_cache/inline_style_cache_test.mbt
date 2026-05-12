///|
test "parse_inline_declarations_cached normalizes properties" {
  let declarations = parse_inline_declarations_cached(
    " COLOR : red ; display: inline-block; ;",
  )
  inspect(declarations.length(), content="2")
  inspect(declarations[0], content="(\"color\", \"red\")")
  inspect(declarations[1], content="(\"display\", \"inline-block\")")
}

///|
test "get_cached_inline_style_display only parses display declarations" {
  debug_inspect(get_cached_inline_style_display("color: red"), content="None")
  match get_cached_inline_style_display("display: inline-block") {
    Some(@types.InlineBlock) => inspect(true, content="true")
    _ => fail("expected inline-block display")
  }
}

///|
test "inline_only_style_cache stores variants per css string" {
  let key = make_inline_only_style_cache_variant_key("DIV", false, 120.0, 80.0)
  let style = @style.Style::default()
  inline_only_style_cache_put("color:red", key, style)
  match inline_only_style_cache_get("color:red", key) {
    Some(cached) => inspect(cached.display == style.display, content="true")
    None => fail("expected cached style")
  }
}
