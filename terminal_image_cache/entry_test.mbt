///|
test "prepare_raster_image_for_kitty_cache stores png payload directly" {
  inspect(
    prepare_raster_image_for_kitty_cache("iVBORw0KGgo="),
    content="img_png:iVBORw0KGgo=",
  )
}

///|
test "data_image_src_to_kitty_cache accepts svg and png data urls" {
  inspect(
    data_image_src_to_kitty_cache("data:image/svg+xml,%3Csvg%3E%3C/svg%3E#icon"),
    content="Some(\"svg:<svg></svg>\")",
  )
  inspect(
    data_image_src_to_kitty_cache("data:image/png;base64,iVBORw0K Ggo=#icon"),
    content="Some(\"img_png:iVBORw0KGgo=\")",
  )
}

///|
test "parse_terminal_image_cache_entry parses encoded variants" {
  match parse_terminal_image_cache_entry("svg:<svg/>") {
    Some(TerminalImageCacheEntry::Svg(svg_text)) =>
      inspect(svg_text, content="<svg/>")
    _ => fail("expected svg entry")
  }
  match parse_terminal_image_cache_entry("img_png:iVBORw0KGgo=") {
    Some(TerminalImageCacheEntry::PngBase64(b64)) =>
      inspect(b64, content="iVBORw0KGgo=")
    _ => fail("expected png entry")
  }
  match parse_terminal_image_cache_entry("img_rgba:2:3:abcd") {
    Some(TerminalImageCacheEntry::RgbaBase64(entry)) => {
      inspect(entry.width, content="2")
      inspect(entry.height, content="3")
      inspect(entry.rgba_base64, content="abcd")
    }
    _ => fail("expected rgba entry")
  }
  match parse_terminal_image_cache_entry("img:raw") {
    Some(TerminalImageCacheEntry::RawBase64(b64)) => inspect(b64, content="raw")
    _ => fail("expected raw entry")
  }
}

///|
test "parse_terminal_image_cache_entry rejects invalid rgba payloads" {
  inspect(
    parse_terminal_image_cache_entry("img_rgba:0:1:abcd") is None,
    content="true",
  )
  inspect(
    parse_terminal_image_cache_entry("img_rgba:1:1:") is None,
    content="true",
  )
  inspect(
    parse_terminal_image_cache_entry("unknown:data") is None,
    content="true",
  )
}

///|
test "RgbaCacheEntry decode_rgba_bytes decodes base64 payload" {
  match parse_terminal_image_cache_entry("img_rgba:1:1:/wAA/w==") {
    Some(TerminalImageCacheEntry::RgbaBase64(entry)) =>
      match entry.decode_rgba_bytes() {
        Some(rgba) => {
          inspect(rgba.length(), content="4")
          inspect(rgba[0], content="255")
          inspect(rgba[1], content="0")
          inspect(rgba[2], content="0")
          inspect(rgba[3], content="255")
        }
        None => fail("expected decoded rgba bytes")
      }
    _ => fail("expected rgba entry")
  }
}
