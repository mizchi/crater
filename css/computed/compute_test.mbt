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
  inspect(@computed.parse_display("math"), content="Inline")
  inspect(@computed.parse_display("block math"), content="Block")
  inspect(@computed.parse_display("flow-root list-item"), content="FlowRoot")
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
  inspect(@computed.parse_alignment("left"), content="Left")
  inspect(@computed.parse_alignment("right"), content="Right")
  inspect(@computed.parse_alignment("center"), content="Center")
  inspect(@computed.parse_alignment("space-between"), content="SpaceBetween")
  inspect(@computed.parse_alignment("stretch"), content="Stretch")
  inspect(@computed.parse_alignment("safe center"), content="Start")
  inspect(@computed.parse_alignment("safe end"), content="Start")
  inspect(@computed.parse_alignment("unsafe center"), content="Center")
  inspect(@computed.parse_alignment("unsafe end"), content="End")
}

///|
test "compute_inline place-content shorthand" {
  let ctx = @computed.ComputeContext::new()

  let safe_center = @computed.compute_inline("place-content: safe center", ctx)
  inspect(safe_center.align_content, content="Start")
  inspect(safe_center.justify_content, content="Start")
  inspect(safe_center.align_content_unsafe, content="false")
  inspect(safe_center.justify_content_unsafe, content="false")

  let unsafe_end = @computed.compute_inline("place-content: unsafe end", ctx)
  inspect(unsafe_end.align_content, content="End")
  inspect(unsafe_end.justify_content, content="End")
  inspect(unsafe_end.align_content_unsafe, content="true")
  inspect(unsafe_end.justify_content_unsafe, content="true")

  let mixed = @computed.compute_inline("place-content: end center", ctx)
  inspect(mixed.align_content, content="End")
  inspect(mixed.justify_content, content="Center")
  inspect(mixed.align_content_unsafe, content="false")
  inspect(mixed.justify_content_unsafe, content="false")

  let left_right = @computed.compute_inline("place-content: start left", ctx)
  inspect(left_right.align_content, content="Start")
  inspect(left_right.justify_content, content="Left")
  inspect(left_right.align_content_unsafe, content="false")
  inspect(left_right.justify_content_unsafe, content="false")
}

///|
test "compute_inline align-content normal maps to stretch" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("align-content: normal", ctx)
  inspect(style.align_content, content="Stretch")
  inspect(style.align_content_unsafe, content="false")
}

///|
test "compute_inline align-content last baseline falls back to baseline packing" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("align-content: last baseline", ctx)
  inspect(style.align_content, content="Baseline")
  inspect(style.align_content_unsafe, content="false")
}

///|
test "parse_align_self baseline variants" {
  inspect(@computed.parse_align_self("baseline"), content="Baseline")
  inspect(@computed.parse_align_self("first baseline"), content="Baseline")
  inspect(@computed.parse_align_self("last baseline"), content="End")
}

///|
test "parse_scroll_snap_type_and_align" {
  let snap_type = @computed.parse_scroll_snap_type("x mandatory")
  inspect(snap_type.axis, content="X")
  inspect(snap_type.strictness, content="Mandatory")
  let (inline_align, block_align) = @computed.parse_scroll_snap_align("center")
  inspect(inline_align, content="Center")
  inspect(block_align, content="Center")
}

///|
test "compute_inline scroll_snap properties" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "scroll-snap-type: y mandatory; scroll-snap-align: center", ctx,
  )
  inspect(style.scroll_snap_type.axis, content="Y")
  inspect(style.scroll_snap_type.strictness, content="Mandatory")
  inspect(style.scroll_snap_align_x, content="Center")
  inspect(style.scroll_snap_align_y, content="Center")
}

///|
test "compute_inline container-type size implies contain size and style" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("container-type: size", ctx)
  inspect(style.contain.size, content="true")
  inspect(style.contain.inline_size, content="false")
  inspect(style.contain.style, content="true")
}

///|
test "compute_inline container-type merges with contain" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "contain: paint; container-type: inline-size", ctx,
  )
  inspect(style.contain.paint, content="true")
  inspect(style.contain.inline_size, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "compute_inline contain-intrinsic-inline-size parses length" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "contain-intrinsic-inline-size: 120px", ctx,
  )
  inspect(style.contain_intrinsic_inline_size, content="Some(120)")
}

///|
test "compute_inline contain-intrinsic-size shorthand sets both axes" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("contain-intrinsic-size: 90px 45px", ctx)
  inspect(style.contain_intrinsic_inline_size, content="Some(90)")
  inspect(style.contain_intrinsic_block_size, content="Some(45)")
}

///|
test "compute_inline columns shorthand parses count and width" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("columns: 2 40px; column-gap: 20px", ctx)
  inspect(style.column_count, content="Some(2)")
  inspect(style.column_width, content="Length(40)")
  inspect(style.column_gap, content="Length(20)")
}

///|
test "compute_inline break-before and column-span parse values" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "break-before: column; column-span: all", ctx,
  )
  inspect(style.break_before, content="Column")
  inspect(style.column_span, content="All")
}

///|
test "compute_inline break-after parses column value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("break-after: column", ctx)
  inspect(style.break_after, content="Column")
}

///|
test "compute_inline break-before and break-after parse avoid value" {
  let ctx = @computed.ComputeContext::new()
  let before = @computed.compute_inline("break-before: avoid", ctx)
  inspect(before.break_before, content="Avoid")
  let after = @computed.compute_inline("break-after: avoid", ctx)
  inspect(after.break_after, content="Avoid")
}

///|
test "compute_inline break-inside parses avoid value" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("break-inside: avoid", ctx)
  inspect(style.break_inside, content="Avoid")
}

///|
test "compute_inline page-break-inside aliases break-inside" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("page-break-inside: avoid", ctx)
  inspect(style.break_inside, content="Avoid")
}

///|
test "compute_inline font-size rem resolves against root font size" {
  let ctx = {
    ..@computed.ComputeContext::new(),
    root_font_size: 16.0,
    font_size: 8.0,
  }
  let style = @computed.compute_inline("font-size: 1rem", ctx)
  inspect(style.font_size, content="16")
}

///|
test "parse_grid_placement custom ident defaults to second line" {
  inspect(@computed.parse_grid_placement("foo"), content="Line(2)")
  inspect(@computed.parse_grid_placement("bar-baz"), content="Line(2)")
}

///|
test "compute_inline grid-area shorthand sets row and column lines" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: 1 / 2 / 3 / 4", ctx)
  inspect(style.grid_row.start, content="Line(1)")
  inspect(style.grid_column.start, content="Line(2)")
  inspect(style.grid_row.end, content="Line(3)")
  inspect(style.grid_column.end, content="Line(4)")
}

///|
test "compute_inline grid-area custom idents place to implicit second track" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: a / a / b / b", ctx)
  inspect(style.grid_row.start, content="Line(2)")
  inspect(style.grid_column.start, content="Line(2)")
  inspect(style.grid_row.end, content="Line(2)")
  inspect(style.grid_column.end, content="Line(2)")
}

///|
test "compute_inline grid-area named area sets grid_area field" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: header", ctx)
  inspect(style.grid_area, content="Some(\"header\")")
  // Named area should not set grid line placements
  inspect(style.grid_row.start, content="Auto")
  inspect(style.grid_column.start, content="Auto")
}

///|
test "compute_inline grid-template-areas parsed correctly" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: grid; grid-template-areas: \"header header\" \"sidebar main\" \"footer footer\"",
    ctx,
  )
  inspect(style.grid_template_areas.length(), content="3")
  inspect(style.grid_template_areas[0], content="header header")
  inspect(style.grid_template_areas[1], content="sidebar main")
  inspect(style.grid_template_areas[2], content="footer footer")
}

///|
test "compute_inline grid-area with slashes still parses as line numbers" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("grid-area: 2 / 1 / 3 / 4", ctx)
  inspect(style.grid_area, content="None")
  inspect(style.grid_row.start, content="Line(2)")
  inspect(style.grid_column.start, content="Line(1)")
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
  inspect(@computed.extract_border_width("solid"), content="Length(1.5)")
  inspect(@computed.extract_border_width("medium"), content="Length(3)")
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
test "compute_inline border shorthand em uses context font-size" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 20.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {},
  }
  let style = @computed.compute_inline("border: 1em solid red", ctx)
  inspect(style.border.top, content="Length(20)")
  inspect(style.border.right, content="Length(20)")
  inspect(style.border.bottom, content="Length(20)")
  inspect(style.border.left, content="Length(20)")
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
test "compute_inline resolves logical float and clear with final direction" {
  let ctx = @computed.ComputeContext::new()
  let rtl_first = @computed.compute_inline(
    "direction: rtl; float: inline-start; clear: inline-end", ctx,
  )
  inspect(rtl_first.float, content="Right")
  inspect(rtl_first.clear, content="Left")

  let rtl_last = @computed.compute_inline(
    "float: inline-start; clear: inline-end; direction: rtl", ctx,
  )
  inspect(rtl_last.float, content="Right")
  inspect(rtl_last.clear, content="Left")
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
test "compute_inline calc viewport units" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: {},
  }
  let style = @computed.compute_inline("width: calc(100vw + 100px)", ctx)
  inspect(style.width, content="Length(900)")
}

///|
test "compute_inline calc mixed width resolves with fallback basis" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: {},
  }
  let style = @computed.compute_inline("width: calc(50% - 10px)", ctx)
  inspect(style.width, content="Length(390)")
}

///|
test "compute_inline gap shorthand two values" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("gap: 40px 20px", ctx)
  inspect(style.row_gap, content="Length(40)")
  inspect(style.column_gap, content="Length(20)")
}

///|
test "compute_inline mixed calc gap resolves with fallback basis" {
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 800.0,
    viewport_height: 600.0,
    custom_properties: {},
  }
  let style = @computed.compute_inline("gap: calc(10% - 1rem / 2)", ctx)
  inspect(style.row_gap, content="Length(72)")
  inspect(style.column_gap, content="Length(72)")
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
test "compute_inline margin auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin: auto", ctx)
  inspect(style.margin.top, content="Auto")
  inspect(style.margin.right, content="Auto")
  inspect(style.margin.bottom, content="Auto")
  inspect(style.margin.left, content="Auto")
}

///|
test "compute_inline inset shorthand with 4 values including auto" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("inset: 50px auto 50px 50px", ctx)
  inspect(style.inset.top, content="Length(50)")
  inspect(style.inset.right, content="Auto")
  inspect(style.inset.bottom, content="Length(50)")
  inspect(style.inset.left, content="Length(50)")
}

///|
test "is_inherited" {
  // Inherited properties
  inspect(@computed.is_inherited("color"), content="true")
  inspect(@computed.is_inherited("font-size"), content="true")
  inspect(@computed.is_inherited("line-height"), content="true")
  inspect(@computed.is_inherited("white-space"), content="true")
  inspect(@computed.is_inherited("pointer-events"), content="true")
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
test "compute_inline grid-template shorthand" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "display: grid; grid-template: 100px / 200px", ctx,
  )
  inspect(style.grid_template_rows.length(), content="1")
  inspect(style.grid_template_rows[0], content="Length(100)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Length(200)")
}

///|
test "font-size parsing" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("font-size: 20px", ctx)
  inspect(style.font_size, content="20")
  let zero_style = @computed.compute_inline("font-size: 0", ctx)
  inspect(zero_style.font_size, content="0")
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
test "em_dimensions_use_seeded_element_font_metrics" {
  let ctx = @computed.ComputeContext::new()
  let style1 = @computed.compute_inline("font: 25px/1 Ahem; width: 15em", ctx)
  inspect(style1.width, content="Length(375)")
  let style2 = @computed.compute_inline("width: 15em; font: 25px/1 Ahem", ctx)
  inspect(style2.width, content="Length(375)")
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
test "intrinsic sizing keywords are preserved on physical and logical sizes" {
  let ctx = @computed.ComputeContext::new()

  // Physical properties keep intrinsic keywords as-is.
  let horizontal = @computed.compute_inline(
    "height: min-content; min-height: min-content; max-height: max-content", ctx,
  )
  inspect(horizontal.height, content="MinContent")
  inspect(horizontal.min_height, content="MinContent")
  inspect(horizontal.max_height, content="MaxContent")

  // Writing mode does not normalize intrinsic keywords on physical width/height.
  let vertical_width = @computed.compute_inline(
    "writing-mode: vertical-lr; width: min-content; min-width: min-content; max-width: max-content",
    ctx,
  )
  inspect(vertical_width.width, content="MinContent")
  inspect(vertical_width.min_width, content="MinContent")
  inspect(vertical_width.max_width, content="MaxContent")

  // Logical properties map to the target axis while preserving intrinsic keywords.
  let vertical_height = @computed.compute_inline(
    "writing-mode: vertical-lr; height: min-content; min-height: min-content; max-height: max-content",
    ctx,
  )
  inspect(vertical_height.height, content="MinContent")
  inspect(vertical_height.min_height, content="MinContent")
  inspect(vertical_height.max_height, content="MaxContent")

  // In vertical writing mode, block-size maps to width.
  let vertical_block = @computed.compute_inline(
    "writing-mode: vertical-lr; min-block-size: max-content; max-block-size: min-content",
    ctx,
  )
  inspect(vertical_block.min_width, content="MaxContent")
  inspect(vertical_block.max_width, content="MinContent")
}

///|
test "intrinsic keywords remain preserved with inherited writing-mode" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("writing-mode: vertical-lr", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline(
    "width: 150px; max-width: min-content", child_ctx,
  )
  inspect(child.max_width, content="MinContent")
}

///|
test "white-space inherits from parent style" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("white-space: nowrap", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("", child_ctx)
  inspect(child.white_space, content="Nowrap")
}

///|
test "text-overflow computes to ellipsis and is not inherited" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("text-overflow: ellipsis", root_ctx)
  inspect(parent.text_overflow, content="Ellipsis")
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("", child_ctx)
  inspect(child.text_overflow, content="Clip")
}

///|
test "pointer-events inherits from parent style" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("pointer-events: none", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("", child_ctx)
  inspect(child.pointer_events, content="None")
}

///|
test "pointer-events auto overrides inherited none" {
  let root_ctx = @computed.ComputeContext::new()
  let parent = @computed.compute_inline("pointer-events: none", root_ctx)
  let child_ctx = @computed.ComputeContext::with_parent(parent)
  let child = @computed.compute_inline("pointer-events: auto", child_ctx)
  inspect(child.pointer_events, content="Auto")
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
test "compute_inline ch units use square advance for inherited Ahem" {
  let ctx : @computed.ComputeContext = {
    parent_style: Some({ ..@style.Style::default(), font_family: "Ahem" }),
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {},
  }
  let style = @computed.compute_inline("width: 4ch", ctx)
  inspect(style.width, content="Length(64)")
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

///|
test "compute_inline transform scale" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("transform: scaleX(2)", ctx)
  inspect(style.transform.scale_x, content="2")
  inspect(style.transform.scale_y, content="1")
}

///|
test "compute_inline transform rotate quarter turn" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("transform: rotate(90deg)", ctx)
  inspect(style.transform.rotate_degrees, content="90")
  inspect(style.transform.quarter_turns(), content="1")
}

///|
test "compute_inline transform skew" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: skewX(45deg) skewY(-15deg)", ctx,
  )
  inspect(style.transform.skew_x_degrees, content="45")
  inspect(style.transform.skew_y_degrees, content="-15")
}

///|
test "compute_inline transform matrix" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: matrix(1, 0, -1, 1, 64, 0)", ctx,
  )
  inspect(style.transform.has_matrix, content="true")
  inspect(
    [
      style.transform.matrix_a,
      style.transform.matrix_b,
      style.transform.matrix_c,
      style.transform.matrix_d,
      style.transform.matrix_e,
      style.transform.matrix_f,
    ],
    content="[1, 0, -1, 1, 64, 0]",
  )
}

///|
test "compute_inline transform matrix3d as 2D affine matrix" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1)", ctx,
  )
  inspect(style.transform.has_matrix, content="true")
  inspect(
    [
      style.transform.matrix_a,
      style.transform.matrix_b,
      style.transform.matrix_c,
      style.transform.matrix_d,
      style.transform.matrix_e,
      style.transform.matrix_f,
    ],
    content="[1, 0, -1, 1, 64, 0]",
  )
}

///|
test "parse_clip_path - inset" {
  let clip_path = @computed.parse_clip_path("inset(16px 0 25% 4px)")
  match clip_path {
    @style.ClipPath::Inset(top, right, bottom, left) =>
      inspect([top, right, bottom, left], content="[16, 0, -0.25, 4]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "parse_clip_path - rect" {
  let clip_path = @computed.parse_clip_path("rect(16px 128px 64px 16px)")
  match clip_path {
    @style.ClipPath::Rect(top, right, bottom, left) =>
      inspect([top, right, bottom, left], content="[16, 128, 64, 16]")
    _ => fail("expected rect clip-path")
  }
}

///|
test "parse_clip_path - xywh" {
  let clip_path = @computed.parse_clip_path("xywh(16px 16px 112px 48px)")
  match clip_path {
    @style.ClipPath::Xywh(x, y, width, height) =>
      inspect([x, y, width, height], content="[16, 16, 112, 48]")
    _ => fail("expected xywh clip-path")
  }
}

///|
test "parse_clip_path - circle" {
  let clip_path = @computed.parse_clip_path("circle(24px at 24px 24px)")
  match clip_path {
    @style.ClipPath::Circle(radius, center_x, center_y) =>
      inspect([radius, center_x, center_y], content="[24, 24, 24]")
    _ => fail("expected circle clip-path")
  }
}

///|
test "parse_clip_path - ellipse" {
  let clip_path = @computed.parse_clip_path("ellipse(24px 16px at 32px 32px)")
  match clip_path {
    @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) =>
      inspect(
        [radius_x, radius_y, center_x, center_y],
        content="[24, 16, 32, 32]",
      )
    _ => fail("expected ellipse clip-path")
  }
}

///|
test "parse_clip_path - polygon" {
  let clip_path = @computed.parse_clip_path(
    "polygon(32px 0, 64px 64px, 0 64px)",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="3")
      let (x0, y0) = points[0]
      let (x1, y1) = points[1]
      let (x2, y2) = points[2]
      inspect([x0, y0, x1, y1, x2, y2], content="[32, 0, 64, 64, 0, 64]")
    }
    _ => fail("expected polygon clip-path")
  }
}

///|
test "parse_clip_path - path as polygon" {
  let clip_path = @computed.parse_clip_path("path(\"M 32 0 L 64 64 L 0 64 Z\")")
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="3")
      let (x0, y0) = points[0]
      let (x1, y1) = points[1]
      let (x2, y2) = points[2]
      inspect([x0, y0, x1, y1, x2, y2], content="[32, 0, 64, 64, 0, 64]")
    }
    _ => fail("expected path clip-path polygon")
  }
}

///|
test "parse_clip_path - quadratic path as polygon" {
  let clip_path = @computed.parse_clip_path("path(\"M 0 64 Q 32 0 64 64 Z\")")
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      inspect([x0, y0, x4, y4, x8, y8], content="[0, 64, 32, 32, 64, 64]")
    }
    _ => fail("expected quadratic path clip-path polygon")
  }
}

///|
test "parse_clip_path - cubic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 C 0 0 64 0 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      inspect([x0, y0, x4, y4, x8, y8], content="[0, 64, 32, 16, 64, 64]")
    }
    _ => fail("expected cubic path clip-path polygon")
  }
}

///|
test "parse_clip_path - smooth quadratic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 Q 16 0 32 64 T 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="17")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      let (x12, y12) = points[12]
      let (x16, y16) = points[16]
      inspect(
        [x0, y0, x4, y4, x8, y8, x12, y12, x16, y16],
        content="[0, 64, 16, 32, 32, 64, 48, 96, 64, 64]",
      )
    }
    _ => fail("expected smooth quadratic path clip-path polygon")
  }
}

///|
test "parse_clip_path - smooth cubic path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 C 0 0 32 0 32 64 S 64 128 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="17")
      let (x0, y0) = points[0]
      let (x8, y8) = points[8]
      let (x12, y12) = points[12]
      let (x16, y16) = points[16]
      inspect(
        [x0, y0, x8, y8, x12, y12, x16, y16],
        content="[0, 64, 32, 64, 48, 112, 64, 64]",
      )
    }
    _ => fail("expected smooth cubic path clip-path polygon")
  }
}

///|
test "parse_clip_path - arc path as polygon" {
  let clip_path = @computed.parse_clip_path(
    "path(\"M 0 64 A 32 32 0 0 1 64 64 Z\")",
  )
  match clip_path {
    @style.ClipPath::Polygon(points) => {
      inspect(points.length(), content="9")
      let (x0, y0) = points[0]
      let (x4, y4) = points[4]
      let (x8, y8) = points[8]
      assert_true((x0 - 0.0).abs() < 0.001)
      assert_true((y0 - 64.0).abs() < 0.001)
      assert_true((x4 - 32.0).abs() < 0.001)
      assert_true((y4 - 32.0).abs() < 0.001)
      assert_true((x8 - 64.0).abs() < 0.001)
      assert_true((y8 - 64.0).abs() < 0.001)
    }
    _ => fail("expected arc path clip-path polygon")
  }
}

///|
test "compute_inline clip-path property" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("clip-path: inset(16px 0 0 16px)", ctx)
  match style.clip_path {
    @style.ClipPath::Inset(top, right, bottom, left) =>
      inspect([top, right, bottom, left], content="[16, 0, 0, 16]")
    _ => fail("expected inset clip-path")
  }
}

///|
test "compute_inline border-collapse" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-collapse: collapse", ctx)
  inspect(style.border_collapse, content="Collapse")
}

///|
test "compute_inline border-collapse separate" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-collapse: separate", ctx)
  inspect(style.border_collapse, content="Separate")
}

///|
test "compute_inline border-spacing single value sets both axes" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-spacing: 8px", ctx)
  inspect(style.border_spacing, content="8")
  inspect(style.border_spacing_vertical, content="8")
}

///|
test "compute_inline border-spacing two values sets vertical axis" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-spacing: 50px 100px", ctx)
  inspect(style.border_spacing, content="50")
  inspect(style.border_spacing_vertical, content="100")
}

///|
test "compute_inline margin-trim block" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin-trim: block", ctx)
  inspect(style.margin_trim, content="Block")
}

///|
test "compute_inline margin-trim block-start" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("margin-trim: block-start", ctx)
  inspect(style.margin_trim, content="BlockStart")
}

///|
test "compute_inline caption-side top" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("caption-side: top", ctx)
  inspect(style.caption_side, content="Top")
}

///|
test "compute_inline caption-side bottom" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("caption-side: bottom", ctx)
  inspect(style.caption_side, content="Bottom")
}

///|
test "compute_inline background linear-gradient" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "background: linear-gradient(to right, #ff0000, #0000ff)", ctx,
  )
  inspect(
    style.background_image,
    content=(
      #|Gradient({angle_deg: 90, stops: [{color: rgb(255, 0, 0), position: 0}, {color: rgb(0, 0, 255), position: 1}]})
    ),
  )
}

///|
test "compute_inline border-radius percentage" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline("border-radius: 50%", ctx)
  // Negative encodes percentage for render-time resolution
  inspect(
    style.border_top_left_radius,
    content=(
      #|-0.5
    ),
  )
  inspect(
    style.border_top_right_radius,
    content=(
      #|-0.5
    ),
  )
}

///|
test "parse_linear_gradient basic" {
  let result = @computed.parse_linear_gradient(
    "linear-gradient(135deg, #667eea, #764ba2)",
  )
  inspect(
    result,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(102, 126, 234), position: 0}, {color: rgb(118, 75, 162), position: 1}]})
    ),
  )
}

///|
test "compute_inline box-shadow parses multiple and inset shadows" {
  let ctx = @computed.ComputeContext::new()
  let style = @computed.compute_inline(
    "box-shadow: 2px 4px 8px rgba(0,0,0,0.25), inset 0 2px 6px #112233", ctx,
  )

  inspect(style.box_shadows.length(), content="2")

  let first = style.box_shadows[0]
  inspect(first.inset, content="false")
  inspect(first.offset_x, content="2")
  inspect(first.offset_y, content="4")
  inspect(first.blur_radius, content="8")
  inspect(first.spread_radius, content="0")
  inspect(first.color.r, content="0")
  inspect(first.color.g, content="0")
  inspect(first.color.b, content="0")
  inspect(first.color.a, content="0.25")

  let second = style.box_shadows[1]
  inspect(second.inset, content="true")
  inspect(second.offset_x, content="0")
  inspect(second.offset_y, content="2")
  inspect(second.blur_radius, content="6")
  inspect(second.spread_radius, content="0")
  inspect(second.color.r, content="17")
  inspect(second.color.g, content="34")
  inspect(second.color.b, content="51")
}
