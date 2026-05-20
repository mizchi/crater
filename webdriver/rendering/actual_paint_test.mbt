///|
test "font aware text provider is used for generic and named families" {
  assert_true(should_use_font_aware_text_provider("serif"))
  assert_true(should_use_font_aware_text_provider("sans-serif"))
  assert_true(should_use_font_aware_text_provider("monospace"))
  assert_true(should_use_font_aware_text_provider("Times New Roman"))
  assert_true(should_use_font_aware_text_provider("\"Georgia\", serif"))
}

///|
test "font aware text provider skips empty and inherited keywords" {
  assert_false(should_use_font_aware_text_provider(""))
  assert_false(should_use_font_aware_text_provider("   "))
  assert_false(should_use_font_aware_text_provider("inherit"))
  assert_false(should_use_font_aware_text_provider("initial"))
  assert_false(should_use_font_aware_text_provider("unset"))
  assert_false(should_use_font_aware_text_provider("revert"))
  assert_false(should_use_font_aware_text_provider("revert-layer"))
}

///|
test "actual paint screenshot predicate accepts default and document png" {
  assert_true(can_use_actual_paint_for_screenshot_data({}))
  assert_true(
    can_use_actual_paint_for_screenshot_data({
      "origin": Json::string("document"),
      "format": Json::object({ "type": Json::string("image/png") }),
    }),
  )
}

///|
test "actual paint screenshot predicate rejects synthetic clip and jpeg" {
  assert_false(
    can_use_actual_paint_for_screenshot_data({
      "backend": Json::string("synthetic"),
    }),
  )
  assert_false(
    can_use_actual_paint_for_screenshot_data({
      "clip": Json::object({ "type": Json::string("box") }),
    }),
  )
  assert_false(
    can_use_actual_paint_for_screenshot_data({
      "format": Json::object({ "type": Json::string("image/jpeg") }),
    }),
  )
}

///|
test "capture paint data options validate viewport only origin" {
  match normalize_capture_paint_data_options({}) {
    Ok(origin) => inspect(origin, content="viewport")
    Err(error) => fail("unexpected paint data option error: " + error.message())
  }
  match
    normalize_capture_paint_data_options({ "origin": Json::string("document") }) {
    Ok(_) => fail("expected unsupported document origin")
    Err(error) => {
      inspect(error.name(), content="unsupported operation")
      inspect(
        error.message(),
        content="capturePaintData currently supports only origin='viewport'",
      )
    }
  }
  match normalize_capture_paint_data_options({ "origin": Json::number(1.0) }) {
    Ok(_) => fail("expected invalid origin")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(error.message(), content="origin must be 'viewport'")
    }
  }
  match
    normalize_capture_paint_data_options({
      "origin": Json::string("viewport"),
      "html": Json::string("<p>static</p>"),
    }) {
    Ok(origin) => inspect(origin, content="viewport")
    Err(error) => fail("unexpected html option error: " + error.message())
  }
  match normalize_capture_paint_data_options({ "html": Json::number(1.0) }) {
    Ok(_) => fail("expected invalid html")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(error.message(), content="html must be a string")
    }
  }
}

///|
test "capture paint tree options validate viewport and document origins" {
  match
    normalize_capture_paint_tree_options({ "origin": Json::string("document") }) {
    Ok(origin) => inspect(origin, content="document")
    Err(error) => fail("unexpected paint tree option error: " + error.message())
  }
  match
    normalize_capture_paint_tree_options({ "origin": Json::string("bad") }) {
    Ok(_) => fail("expected invalid origin")
    Err(error) => {
      inspect(error.name(), content="invalid argument")
      inspect(
        error.message(),
        content="origin must be 'viewport' or 'document'",
      )
    }
  }
  match normalize_capture_paint_tree_options({ "origin": Json::number(1.0) }) {
    Ok(_) => fail("expected invalid origin type")
    Err(error) => inspect(error.message(), content="origin must be a string")
  }
}

///|
test "text metrics quad parser accepts provider csv" {
  match parse_text_metrics_quad("1.5,2.5,3.5,4.5") {
    Some((min_w, max_w, min_h, max_h)) => {
      inspect(min_w, content="1.5")
      inspect(max_w, content="2.5")
      inspect(min_h, content="3.5")
      inspect(max_h, content="4.5")
    }
    None => fail("expected parsed metrics")
  }
}

///|
test "text metrics quad parser rejects incomplete or invalid csv" {
  assert_true(parse_text_metrics_quad("1,2,3") is None)
  assert_true(parse_text_metrics_quad("1,2,nope,4") is None)
}

///|
test "text intrinsic size prefers provider payload" {
  let size = resolve_text_intrinsic_size_from_provider_payload(
    "1,2,3,4", "abc", 10.0, 12.0,
  )
  inspect(size.min_width, content="1")
  inspect(size.max_width, content="2")
  inspect(size.min_height, content="3")
  inspect(size.max_height, content="4")
}

///|
test "text intrinsic size falls back to character count and line metrics" {
  let size = resolve_text_intrinsic_size_from_provider_payload(
    "", "abcd", 10.0, 0.0,
  )
  inspect(size.min_width, content="20")
  inspect(size.max_width, content="20")
  inspect(size.min_height, content="10")
  inspect(size.max_height, content="10")
}

///|
test "glyph outline command parser accepts move line curve and close" {
  let json =
    #|[["M",1,2],["L",3,4],["Q",5,6,7,8],["C",9,10,11,12,13,14],["Z"]]
  let commands = parse_glyph_outline_commands_json(json)
  inspect(commands.length(), content="5")
  match commands[0] {
    @svg.MoveTo(x, y) => {
      inspect(x, content="1")
      inspect(y, content="2")
    }
    _ => fail("expected MoveTo")
  }
  match commands[2] {
    @svg.QuadraticCurveTo(cx, cy, x, y) => {
      inspect(cx, content="5")
      inspect(cy, content="6")
      inspect(x, content="7")
      inspect(y, content="8")
    }
    _ => fail("expected QuadraticCurveTo")
  }
  match commands[4] {
    @svg.ClosePath => ()
    _ => fail("expected ClosePath")
  }
}

///|
test "glyph outline command parser skips malformed entries" {
  let json =
    #|[["M",1],["unknown",1,2],["L",3,4],42]
  let commands = parse_glyph_outline_commands_json(json)
  inspect(commands.length(), content="1")
  match commands[0] {
    @svg.LineTo(x, y) => {
      inspect(x, content="3")
      inspect(y, content="4")
    }
    _ => fail("expected LineTo")
  }
}

///|
fn actual_paint_test_layout(
  id : String,
  x? : Double = 0.0,
  y? : Double = 0.0,
  width~ : Double,
  height~ : Double,
  overflow_x? : @types.Overflow = @types.Visible,
  overflow_y? : @types.Overflow = @types.Visible,
  scroll_width? : Double = 0.0,
  scroll_height? : Double = 0.0,
  children? : Array[@layout_types.Layout] = [],
) -> @layout_types.Layout {
  {
    id,
    x,
    y,
    width,
    height,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    overflow_x,
    overflow_y,
    scroll_width,
    scroll_height,
    children,
    text: None,
  }
}

///|
fn actual_paint_test_document_dimensions_from_layout(
  layout : @layout_types.Layout,
  viewport_width : Int,
  viewport_height : Int,
) -> (Int, Int) {
  let width = actual_paint_layout_content_right(layout).ceil().to_int()
  let height = actual_paint_layout_content_bottom(layout).ceil().to_int()
  (width.max(viewport_width).max(1), height.max(viewport_height).max(1))
}

///|
test "actual paint document width keeps visible horizontal overflow" {
  let root = actual_paint_test_layout(
    "body",
    width=320.0,
    height=180.0,
    scroll_width=320.0,
    scroll_height=180.0,
    children=[
      actual_paint_test_layout(
        "div.wide",
        width=800.0,
        height=20.0,
        scroll_width=800.0,
        scroll_height=20.0,
      ),
    ],
  )
  let (width, height) = actual_paint_test_document_dimensions_from_layout(
    root, 320, 180,
  )
  assert_eq(width, 800)
  ignore(height)
}

///|
test "actual paint document width ignores clipped descendant overflow" {
  let root = actual_paint_test_layout(
    "body",
    width=320.0,
    height=180.0,
    scroll_width=320.0,
    scroll_height=180.0,
    children=[
      actual_paint_test_layout(
        "div.announcer",
        x=-1.0,
        y=-1.0,
        width=1.0,
        height=1.0,
        overflow_x=@types.Hidden,
        overflow_y=@types.Hidden,
        scroll_width=6320.0,
        scroll_height=64.0,
        children=[
          actual_paint_test_layout(
            "#text",
            width=6320.0,
            height=16.0,
            scroll_width=6320.0,
            scroll_height=16.0,
          ),
        ],
      ),
    ],
  )
  let (width, height) = actual_paint_test_document_dimensions_from_layout(
    root, 320, 180,
  )
  assert_eq(width, 320)
  ignore(height)
}
