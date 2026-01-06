///|
/// Tests for CSS computed values

///|
test "compute_inline background-color hex" {
  let css = "background-color: #ff0000"
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(css, ctx)
  // Should be red
  inspect(style.background_color.r, content="255")
  inspect(style.background_color.g, content="0")
  inspect(style.background_color.b, content="0")
}

///|
test "compute_inline background-color named" {
  let css = "background-color: red"
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(css, ctx)
  // Should be red
  inspect(style.background_color.r, content="255")
  inspect(style.background_color.g, content="0")
  inspect(style.background_color.b, content="0")
}

///|
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
  inspect(@computed.parse_position("static"), content="Static") // treated as relative
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
test "extract_border_width" {
  inspect(@computed.extract_border_width("3px"), content="Length(3)")
  inspect(@computed.extract_border_width("solid 3px"), content="Length(3)")
  inspect(@computed.extract_border_width("1px solid red"), content="Length(1)")
  inspect(@computed.extract_border_width("none"), content="Length(0)")
}

///|
test "compute_inline border shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border: 3px solid red", ctx)
  inspect(style.border.top, content="Length(3)")
  inspect(style.border.right, content="Length(3)")
  inspect(style.border.bottom, content="Length(3)")
  inspect(style.border.left, content="Length(3)")
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
    custom_properties: {},
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
    custom_properties: {},
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
    custom_properties: {},
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

///|
test "font-size parsing" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("font-size: 20px", ctx)
  inspect(style.font_size, content="20")
}

///|
test "font shorthand parsing" {
  let ctx = @computed.ComputeContext::new()

  // font: size/line-height family
  let style1 = @computed.compute_inline("font: 100px/1 Ahem", ctx)
  inspect(style1.font_size, content="100")
  inspect(style1.line_height, content="100") // 100 * 1 = 100

  // font: size/line-height family (with ratio)
  let style2 = @computed.compute_inline("font: 20px/1.5 sans-serif", ctx)
  inspect(style2.font_size, content="20")
  inspect(style2.line_height, content="30") // 20 * 1.5 = 30

  // font: size family (no line-height)
  let style3 = @computed.compute_inline("font: 16px Arial", ctx)
  inspect(style3.font_size, content="16")
  inspect(style3.line_height, content="16") // default 1:1 ratio
}

///|
test "logical properties inline-size and block-size" {
  let ctx = @computed.ComputeContext::new()

  // inline-size -> width (in horizontal-tb writing mode)
  let style1 = @computed.compute_inline("inline-size: 200px", ctx)
  inspect(style1.width, content="Length(200)")

  // block-size -> height (in horizontal-tb writing mode)
  let style2 = @computed.compute_inline("block-size: 100px", ctx)
  inspect(style2.height, content="Length(100)")

  // Both together
  let style3 = @computed.compute_inline(
    "inline-size: 300px; block-size: 150px", ctx,
  )
  inspect(style3.width, content="Length(300)")
  inspect(style3.height, content="Length(150)")
}

///|
test "compute_inline vmin and vmax units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1000.0,
    viewport_height: 800.0,
    custom_properties: {},
  }

  // vmin = min(1000, 800) = 800, so 50vmin = 400px
  let style1 = @computed.compute_inline("width: 50vmin", ctx)
  inspect(style1.width, content="Length(400)")

  // vmax = max(1000, 800) = 1000, so 50vmax = 500px
  let style2 = @computed.compute_inline("width: 50vmax", ctx)
  inspect(style2.width, content="Length(500)")
}

///|
test "compute_inline ch and ex units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0, // 20px font
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {},
  }

  // ch ≈ 0.5em, so 4ch with 20px font = 4 * 20 * 0.5 = 40px
  let style1 = @computed.compute_inline("width: 4ch", ctx)
  inspect(style1.width, content="Length(40)")

  // ex ≈ 0.5em, so 2ex with 20px font = 2 * 20 * 0.5 = 20px
  let style2 = @computed.compute_inline("height: 2ex", ctx)
  inspect(style2.height, content="Length(20)")
}

///|
test "compute_inline absolute units pt, pc, in, cm, mm" {
  let ctx = @computed.ComputeContext::new()

  // pt: 1pt = 96/72 px = 1.333...px, so 72pt = 96px
  let style_pt = @computed.compute_inline("width: 72pt", ctx)
  assert_true(style_pt.width.eq_length(96.0))

  // pc: 1pc = 16px, so 6pc = 96px
  let style_pc = @computed.compute_inline("width: 6pc", ctx)
  assert_true(style_pc.width.eq_length(96.0))

  // in: 1in = 96px
  let style_in = @computed.compute_inline("width: 1in", ctx)
  assert_true(style_in.width.eq_length(96.0))

  // cm: 1cm = 96/2.54 px ≈ 37.795px, so 2.54cm = 96px
  let style_cm = @computed.compute_inline("width: 2.54cm", ctx)
  assert_true(style_cm.width.eq_length(96.0))

  // mm: 1mm = 96/25.4 px, so 25.4mm = 96px
  let style_mm = @computed.compute_inline("width: 25.4mm", ctx)
  assert_true(style_mm.width.eq_length(96.0))
}

///|
test "compute_inline min() function" {
  let ctx = @computed.ComputeContext::new()

  // min(100px, 200px) = 100px
  let style1 = @computed.compute_inline("width: min(100px, 200px)", ctx)
  assert_true(style1.width.eq_length(100.0))

  // min(300px, 50px, 150px) = 50px
  let style2 = @computed.compute_inline("width: min(300px, 50px, 150px)", ctx)
  assert_true(style2.width.eq_length(50.0))
}

///|
test "compute_inline max() function" {
  let ctx = @computed.ComputeContext::new()

  // max(100px, 200px) = 200px
  let style1 = @computed.compute_inline("width: max(100px, 200px)", ctx)
  assert_true(style1.width.eq_length(200.0))

  // max(50px, 300px, 150px) = 300px
  let style2 = @computed.compute_inline("width: max(50px, 300px, 150px)", ctx)
  assert_true(style2.width.eq_length(300.0))
}

///|
test "compute_inline clamp() function" {
  let ctx = @computed.ComputeContext::new()

  // clamp(100px, 150px, 200px) = 150px (value is within bounds)
  let style1 = @computed.compute_inline(
    "width: clamp(100px, 150px, 200px)", ctx,
  )
  assert_true(style1.width.eq_length(150.0))

  // clamp(100px, 50px, 200px) = 100px (value below min)
  let style2 = @computed.compute_inline("width: clamp(100px, 50px, 200px)", ctx)
  assert_true(style2.width.eq_length(100.0))

  // clamp(100px, 250px, 200px) = 200px (value above max)
  let style3 = @computed.compute_inline(
    "width: clamp(100px, 250px, 200px)", ctx,
  )
  assert_true(style3.width.eq_length(200.0))
}

///|
test "compute_inline nested math functions" {
  let ctx = @computed.ComputeContext::new()

  // max(min(100px, 200px), 50px) = max(100px, 50px) = 100px
  let style1 = @computed.compute_inline(
    "width: max(min(100px, 200px), 50px)", ctx,
  )
  assert_true(style1.width.eq_length(100.0))

  // min(max(50px, 100px), 80px) = min(100px, 80px) = 80px
  let style2 = @computed.compute_inline(
    "width: min(max(50px, 100px), 80px)", ctx,
  )
  assert_true(style2.width.eq_length(80.0))
}

// =============================================================================
// CSS Custom Properties (Variables) Tests
// =============================================================================

///|
test "css variables - basic resolution" {
  // Create context with pre-defined custom properties
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--my-width": "100px", "--my-margin": "20px" },
  }
  // Use var() to reference custom property
  let style = @computed.compute_inline("width: var(--my-width)", ctx)
  inspect(style.width, content="Length(100)")
  let style2 = @computed.compute_inline("margin-left: var(--my-margin)", ctx)
  inspect(style2.margin.left, content="Length(20)")
}

///|
test "css variables - fallback value" {
  // Create context without the referenced variable
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {},
  }
  // Use var() with fallback
  let style = @computed.compute_inline("width: var(--undefined, 50px)", ctx)
  inspect(style.width, content="Length(50)")
}

///|
test "css variables - defined variable takes precedence over fallback" {
  // Variable is defined, fallback should be ignored
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--my-size": "200px" },
  }
  let style = @computed.compute_inline("width: var(--my-size, 50px)", ctx)
  inspect(style.width, content="Length(200)")
}

///|
test "css variables - nested var() in fallback" {
  // Fallback can contain another var()
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--fallback-size": "75px" },
  }
  // --undefined is not set, so fallback to var(--fallback-size)
  let style = @computed.compute_inline(
    "width: var(--undefined, var(--fallback-size))", ctx,
  )
  inspect(style.width, content="Length(75)")
}

///|
test "css variables - chained variable references" {
  // One variable references another
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {
      "--base-size": "50px",
      "--derived-size": "var(--base-size)",
    },
  }
  // Resolving --derived-size should resolve to --base-size value
  let style = @computed.compute_inline("width: var(--derived-size)", ctx)
  inspect(style.width, content="Length(50)")
}

///|
test "css variables - color values" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: { "--primary-color": "#ff0000", "--bg-color": "blue" },
  }
  let style = @computed.compute_inline("color: var(--primary-color)", ctx)
  inspect(style.color.to_hex(), content="#ff0000")
  let style2 = @computed.compute_inline(
    "background-color: var(--bg-color)", ctx,
  )
  inspect(style2.background_color.to_hex(), content="#0000ff")
}

///|
test "parse_clip - auto" {
  let clip = @computed.parse_clip("auto")
  inspect(clip, content="auto")
}

///|
test "parse_clip - rect with px values" {
  let clip = @computed.parse_clip("rect(1px, 1px, 1px, 1px)")
  inspect(clip, content="rect(1, 1, 1, 1)")
}

///|
test "parse_clip - rect with comma separated values" {
  let clip = @computed.parse_clip("rect(10px, 100px, 50px, 5px)")
  inspect(clip, content="rect(10, 100, 50, 5)")
}

///|
test "parse_clip - rect with space separated values" {
  let clip = @computed.parse_clip("rect(10px 100px 50px 5px)")
  inspect(clip, content="rect(10, 100, 50, 5)")
}

///|
test "compute_inline clip property" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip: rect(1px, 1px, 1px, 1px)", ctx)
  inspect(style.clip, content="rect(1, 1, 1, 1)")
}

///|
test "compute_inline clip auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip: auto", ctx)
  inspect(style.clip, content="auto")
}
