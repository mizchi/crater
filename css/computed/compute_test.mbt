///|
/// Tests for CSS computed values
test "parse_dimension basic" {
  let auto = @computed.parse_dimension("auto")
  inspect(auto, content="Auto")
  let px = @computed.parse_dimension("100px")
  inspect(px, content="Length(100)")
  let percent = @computed.parse_dimension("50%")
  inspect(percent, content="Percent(0.5)")
  let plain = @computed.parse_dimension("200")
  inspect(plain, content="Length(200)")
}

///|
test "parse_display" {
  inspect(@computed.parse_display("block"), content="Block")
  inspect(@computed.parse_display("flex"), content="Flex")
  inspect(@computed.parse_display("grid"), content="Grid")
  inspect(@computed.parse_display("none"), content="None")
  inspect(@computed.parse_display("FLEX"), content="Flex") // case insensitive
}

///|
test "parse_position" {
  inspect(@computed.parse_position("relative"), content="Relative")
  inspect(@computed.parse_position("absolute"), content="Absolute")
  inspect(@computed.parse_position("static"), content="Relative") // treated as relative
}

///|
test "parse_flex_direction" {
  inspect(@computed.parse_flex_direction("row"), content="Row")
  inspect(@computed.parse_flex_direction("row-reverse"), content="RowReverse")
  inspect(@computed.parse_flex_direction("column"), content="Column")
  inspect(
    @computed.parse_flex_direction("column-reverse"),
    content="ColumnReverse",
  )
}

///|
test "parse_alignment" {
  inspect(@computed.parse_alignment("flex-start"), content="FlexStart")
  inspect(@computed.parse_alignment("start"), content="Start")
  inspect(@computed.parse_alignment("flex-end"), content="FlexEnd")
  inspect(@computed.parse_alignment("end"), content="End")
  inspect(@computed.parse_alignment("center"), content="Center")
  inspect(@computed.parse_alignment("space-between"), content="SpaceBetween")
  inspect(@computed.parse_alignment("stretch"), content="Stretch")
}

///|
test "parse_aspect_ratio" {
  inspect(@computed.parse_aspect_ratio("auto"), content="None")
  inspect(
    @computed.parse_aspect_ratio("16 / 9"),
    content="Some(1.7777777777777777)",
  )
  inspect(
    @computed.parse_aspect_ratio("16/9"),
    content="Some(1.7777777777777777)",
  )
  inspect(@computed.parse_aspect_ratio("1.5"), content="Some(1.5)")
}

///|
test "compute_inline basic" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("width: 100px; height: 200px", ctx)
  inspect(style.width, content="Length(100)")
  inspect(style.height, content="Length(200)")
}

///|
test "compute_inline flex properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: flex; flex-direction: column; justify-content: center", ctx,
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Column")
  inspect(style.justify_content, content="Center")
}

///|
test "compute_inline relative units em" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0, // 20px font
    viewport_width: 1920.0,
    viewport_height: 1080.0,
  }
  let style = @computed.compute_inline("width: 2em", ctx)
  // 2em * 20px = 40px
  inspect(style.width, content="Length(40)")
}

///|
test "compute_inline relative units rem" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
  }
  let style = @computed.compute_inline("width: 2rem", ctx)
  // 2rem * 16px = 32px
  inspect(style.width, content="Length(32)")
}

///|
test "compute_inline viewport units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1000.0,
    viewport_height: 800.0,
  }
  let style = @computed.compute_inline("width: 50vw; height: 25vh", ctx)
  // 50vw = 50% of 1000px = 500px
  inspect(style.width, content="Length(500)")
  // 25vh = 25% of 800px = 200px
  inspect(style.height, content="Length(200)")
}

///|
test "compute_inline box model" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "margin-top: 10px; margin-bottom: 20px; padding-left: 5px", ctx,
  )
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.bottom, content="Length(20)")
  inspect(style.padding.left, content="Length(5)")
}

///|
test "is_inherited" {
  // Inherited properties
  inspect(@computed.is_inherited("color"), content="true")
  inspect(@computed.is_inherited("font-size"), content="true")
  inspect(@computed.is_inherited("line-height"), content="true")
  // Non-inherited properties
  inspect(@computed.is_inherited("width"), content="false")
  inspect(@computed.is_inherited("display"), content="false")
  inspect(@computed.is_inherited("margin"), content="false")
}

///|
test "initial_value" {
  inspect(@computed.initial_value("display"), content="block")
  inspect(@computed.initial_value("position"), content="relative")
  inspect(@computed.initial_value("flex-direction"), content="row")
  inspect(@computed.initial_value("flex-grow"), content="0")
  inspect(@computed.initial_value("flex-shrink"), content="1")
  inspect(@computed.initial_value("width"), content="auto")
}

///|
test "parse_grid_template_tracks" {
  let tracks = @computed.parse_grid_template_tracks("100px 200px 1fr")
  inspect(tracks.length(), content="3")
  inspect(tracks[0], content="Length(100)")
  inspect(tracks[1], content="Length(200)")
  inspect(tracks[2], content="Fr(1)")
}

///|
test "parse_grid_template_tracks with auto" {
  let tracks = @computed.parse_grid_template_tracks("auto 50px 2fr")
  inspect(tracks.length(), content="3")
  inspect(tracks[0], content="Auto")
  inspect(tracks[1], content="Length(50)")
  inspect(tracks[2], content="Fr(2)")
}

///|
test "parse_grid_template_tracks none" {
  let tracks = @computed.parse_grid_template_tracks("none")
  inspect(tracks.length(), content="0")
}

///|
test "compute_inline grid-template" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: grid; grid-template-columns: 100px 1fr 100px", ctx,
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[1], content="Fr(1)")
  inspect(style.grid_template_columns[2], content="Length(100)")
}
