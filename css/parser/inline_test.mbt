///|
test "parse negative top left" {
  let style = parse_inline_style("top: -20px; left: -40px")
  inspect(style.inset.top, content="Length(-20)")
  inspect(style.inset.left, content="Length(-40)")
}

///|
test "parse basic width and height" {
  let style = parse_inline_style("width: 100px; height: 50px")
  inspect(style.width, content="Length(100)")
  inspect(style.height, content="Length(50)")
}

///|
test "parse display flex" {
  let style = parse_inline_style("display: flex")
  inspect(style.display, content="Flex")
}

///|
test "parse flex properties" {
  let style = parse_inline_style(
    "display: flex; flex-direction: column; justify-content: center",
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Column")
  inspect(style.justify_content, content="Center")
}

///|
test "parse margin and padding" {
  let style = parse_inline_style("margin: 10px; padding: 20px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.left, content="Length(10)")
  inspect(style.padding.top, content="Length(20)")
  inspect(style.padding.right, content="Length(20)")
}

///|
test "parse percentage values" {
  let style = parse_inline_style("width: 50%; height: 100%")
  inspect(style.width, content="Percent(0.5)")
  inspect(style.height, content="Percent(1)")
}

///|
test "parse flex-grow and flex-shrink" {
  let style = parse_inline_style("flex-grow: 1; flex-shrink: 0")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="0")
}

///|
test "parse gap" {
  let style = parse_inline_style("gap: 10px")
  inspect(style.row_gap, content="Length(10)")
  inspect(style.column_gap, content="Length(10)")
}

///|
test "parse complex flex layout" {
  let style = parse_inline_style(
    "display: flex; flex-direction: row; flex-wrap: wrap; align-items: center; gap: 16px",
  )
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Row")
  inspect(style.flex_wrap, content="Wrap")
  inspect(style.align_items, content="Center")
  inspect(style.row_gap, content="Length(16)")
}

///|
test "parse border-width" {
  let style = parse_inline_style("border-width: 2px")
  inspect(style.border.top, content="Length(2)")
  inspect(style.border.left, content="Length(2)")
}

///|
test "parse inset properties" {
  let style = parse_inline_style("position: absolute; top: 10px; left: 20px")
  inspect(style.position, content="Absolute")
  inspect(style.inset.top, content="Length(10)")
  inspect(style.inset.left, content="Length(20)")
}

///|
test "parse aspect-ratio simple" {
  let style = parse_inline_style("aspect-ratio: 1.5")
  inspect(style.aspect_ratio, content="Some(1.5)")
}

///|
test "parse aspect-ratio fraction" {
  let style = parse_inline_style("aspect-ratio: 16 / 9")
  // 16/9 ≈ 1.777...
  match style.aspect_ratio {
    Some(v) => assert_true(v > 1.77 && v < 1.78)
    None => fail("aspect_ratio should be Some")
  }
}

///|
test "parse grid-auto-flow" {
  let style = parse_inline_style("display: grid; grid-auto-flow: column")
  inspect(style.display, content="Grid")
  inspect(style.grid_auto_flow, content="Column")
}

///|
test "order property" {
  let style = parse_inline_style("order: 5")
  inspect(style.order, content="5")
}

///|
test "order negative" {
  let style = parse_inline_style("order: -1")
  inspect(style.order, content="-1")
}

///|
test "flex shorthand" {
  let style = parse_inline_style("flex: 1")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="1")
}

///|
test "grid-template-columns basic" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: 100px 200px 1fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[1], content="Length(200)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

///|
test "grid-template-columns fractional fr" {
  let style = parse_inline_style(
    "display: grid; grid-template-columns: 1.01fr 0.99fr 1fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Fr(1.01)")
  inspect(style.grid_template_columns[1], content="Fr(0.99)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

///|
test "grid-template-rows basic" {
  let style = parse_inline_style(
    "display: grid; grid-template-rows: auto 50px 2fr",
  )
  inspect(style.display, content="Grid")
  inspect(style.grid_template_rows.length(), content="3")
  inspect(style.grid_template_rows[0], content="Auto")
  inspect(style.grid_template_rows[1], content="Length(50)")
  inspect(style.grid_template_rows[2], content="Fr(2)")
}

///|
test "grid-template-columns with percentage" {
  let style = parse_inline_style("grid-template-columns: 50% 50%")
  inspect(style.grid_template_columns.length(), content="2")
  inspect(style.grid_template_columns[0], content="Percent(0.5)")
  inspect(style.grid_template_columns[1], content="Percent(0.5)")
}

///|
test "grid-template-columns none" {
  let style = parse_inline_style("grid-template-columns: none")
  inspect(style.grid_template_columns.length(), content="0")
}

///|
test "grid-template-columns minmax" {
  let style = parse_inline_style("grid-template-columns: minmax(100px, 1fr)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="MinMax(Length(100), Fr(1))")
}

///|
test "grid-template-columns minmax min-content auto" {
  let style = parse_inline_style(
    "grid-template-columns: minmax(min-content, 100px) auto",
  )
  inspect(style.grid_template_columns.length(), content="2")
  inspect(
    style.grid_template_columns[0],
    content="MinMax(MinContent, Length(100))",
  )
  inspect(style.grid_template_columns[1], content="Auto")
}

///|
test "grid-template-columns repeat" {
  let style = parse_inline_style("grid-template-columns: repeat(3, 100px)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [Length(100)])",
  )
}

///|
test "flex-flow row wrap" {
  let style = parse_inline_style("flex-flow: row wrap")
  inspect(style.flex_direction, content="Row")
  inspect(style.flex_wrap, content="Wrap")
}

///|
test "flex-flow column nowrap" {
  let style = parse_inline_style("flex-flow: column nowrap")
  inspect(style.flex_direction, content="Column")
  inspect(style.flex_wrap, content="NoWrap")
}

///|
test "flex-flow wrap-reverse only" {
  let style = parse_inline_style("flex-flow: wrap-reverse")
  inspect(style.flex_direction, content="Row") // default
  inspect(style.flex_wrap, content="WrapReverse")
}

///|
test "flex: 1 0% 1 (basis in middle - invalid)" {
  // CSS spec: flex shorthand must be <grow> [<shrink>] [<basis>]
  // Basis in middle like "1 0% 1" is invalid, so defaults are used
  let style = parse_inline_style("flex: 1 0% 1")
  inspect(style.flex_grow, content="0")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Auto")
}

///|
test "flex: 1 auto 1 (basis in middle - invalid)" {
  // CSS spec: flex shorthand must be <grow> [<shrink>] [<basis>]
  // Basis in middle like "1 auto 1" is invalid, so defaults are used
  let style = parse_inline_style("flex: 1 auto 1")
  inspect(style.flex_grow, content="0")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Auto")
}

///|
test "contain: none" {
  let style = parse_inline_style("contain: none")
  inspect(style.contain.size, content="false")
  inspect(style.contain.layout, content="false")
  inspect(style.contain.paint, content="false")
  inspect(style.contain.style, content="false")
}

///|
test "contain: strict" {
  let style = parse_inline_style("contain: strict")
  inspect(style.contain.size, content="true")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain: content" {
  let style = parse_inline_style("contain: content")
  inspect(style.contain.size, content="false")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain: layout" {
  let style = parse_inline_style("contain: layout")
  inspect(style.contain.size, content="false")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="false")
}

///|
test "contain: layout paint" {
  let style = parse_inline_style("contain: layout paint")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.size, content="false")
}

///|
test "contain: size layout paint style" {
  let style = parse_inline_style("contain: size layout paint style")
  inspect(style.contain.size, content="true")
  inspect(style.contain.layout, content="true")
  inspect(style.contain.paint, content="true")
  inspect(style.contain.style, content="true")
}

///|
test "contain: inline-size" {
  let style = parse_inline_style("contain: inline-size")
  inspect(style.contain.inline_size, content="true")
  inspect(style.contain.size, content="false")
}

///|
test "parse width fit-content" {
  let style = parse_inline_style("width: fit-content")
  inspect(style.width, content="FitContent(10000000000)")
}

///|
test "parse width min-content" {
  let style = parse_inline_style("width: min-content")
  inspect(style.width, content="MinContent")
}

///|
test "parse width max-content" {
  let style = parse_inline_style("width: max-content")
  inspect(style.width, content="MaxContent")
}

///|
test "parse calc addition" {
  let style = parse_inline_style("width: calc(100px + 50px)")
  inspect(style.width, content="Length(150)")
}

///|
test "parse calc subtraction" {
  let style = parse_inline_style("width: calc(200px - 50px)")
  inspect(style.width, content="Length(150)")
}

///|
test "parse calc percentage" {
  let style = parse_inline_style("width: calc(50% + 50%)")
  inspect(style.width, content="Percent(1)")
}

///|
test "parse display none" {
  let style = parse_inline_style("display: none")
  inspect(style.display, content="None")
}

///|
test "parse display inline-flex" {
  let style = parse_inline_style("display: inline-flex")
  inspect(style.display, content="InlineFlex")
}

///|
test "parse display inline-grid" {
  let style = parse_inline_style("display: inline-grid")
  inspect(style.display, content="InlineGrid")
}

///|
test "parse position relative" {
  let style = parse_inline_style("position: relative")
  inspect(style.position, content="Relative")
}

///|
test "parse position fixed" {
  let style = parse_inline_style("position: fixed")
  inspect(style.position, content="Fixed")
}

///|
test "parse float left" {
  let style = parse_inline_style("float: left")
  inspect(style.float, content="Left")
}

///|
test "parse float right" {
  let style = parse_inline_style("float: right")
  inspect(style.float, content="Right")
}

///|
test "parse clear both" {
  let style = parse_inline_style("clear: both")
  inspect(style.clear, content="Both")
}

///|
test "parse clear left" {
  let style = parse_inline_style("clear: left")
  inspect(style.clear, content="Left")
}

///|
test "parse align-items stretch" {
  let style = parse_inline_style("align-items: stretch")
  inspect(style.align_items, content="Stretch")
}

///|
test "parse align-items baseline" {
  let style = parse_inline_style("align-items: baseline")
  inspect(style.align_items, content="Baseline")
}

///|
test "parse justify-content space-evenly" {
  let style = parse_inline_style("justify-content: space-evenly")
  inspect(style.justify_content, content="SpaceEvenly")
}

///|
test "parse justify-content space-around" {
  let style = parse_inline_style("justify-content: space-around")
  inspect(style.justify_content, content="SpaceAround")
}

///|
test "parse overflow visible" {
  let style = parse_inline_style("overflow: visible")
  inspect(style.overflow_x, content="Visible")
  inspect(style.overflow_y, content="Visible")
}

///|
test "parse overflow hidden" {
  let style = parse_inline_style("overflow: hidden")
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Hidden")
}

///|
test "parse overflow scroll" {
  let style = parse_inline_style("overflow: scroll")
  inspect(style.overflow_x, content="Scroll")
  inspect(style.overflow_y, content="Scroll")
}

///|
test "parse overflow-x and overflow-y separately" {
  let style = parse_inline_style("overflow-x: hidden; overflow-y: scroll")
  inspect(style.overflow_x, content="Hidden")
  inspect(style.overflow_y, content="Scroll")
}

///|
test "parse row-gap and column-gap separately" {
  let style = parse_inline_style("row-gap: 10px; column-gap: 20px")
  inspect(style.row_gap, content="Length(10)")
  inspect(style.column_gap, content="Length(20)")
}

///|
test "parse min-width and max-width" {
  let style = parse_inline_style("min-width: 100px; max-width: 500px")
  inspect(style.min_width, content="Length(100)")
  inspect(style.max_width, content="Length(500)")
}

///|
test "parse min-height and max-height" {
  let style = parse_inline_style("min-height: 50px; max-height: 300px")
  inspect(style.min_height, content="Length(50)")
  inspect(style.max_height, content="Length(300)")
}

///|
test "parse inset shorthand" {
  let style = parse_inline_style("position: absolute; inset: 10px")
  inspect(style.inset.top, content="Length(10)")
  inspect(style.inset.right, content="Length(10)")
  inspect(style.inset.bottom, content="Length(10)")
  inspect(style.inset.left, content="Length(10)")
}

///|
test "parse margin with 2 values" {
  let style = parse_inline_style("margin: 10px 20px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(10)")
  inspect(style.margin.left, content="Length(20)")
}

///|
test "parse margin with 3 values" {
  let style = parse_inline_style("margin: 10px 20px 30px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(20)")
}

///|
test "parse margin with 4 values" {
  let style = parse_inline_style("margin: 10px 20px 30px 40px")
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(40)")
}

///|
test "parse padding with 2 values" {
  let style = parse_inline_style("padding: 5px 15px")
  inspect(style.padding.top, content="Length(5)")
  inspect(style.padding.right, content="Length(15)")
  inspect(style.padding.bottom, content="Length(5)")
  inspect(style.padding.left, content="Length(15)")
}

///|
test "parse individual margin properties" {
  let style = parse_inline_style(
    "margin-top: 10px; margin-right: 20px; margin-bottom: 30px; margin-left: 40px",
  )
  inspect(style.margin.top, content="Length(10)")
  inspect(style.margin.right, content="Length(20)")
  inspect(style.margin.bottom, content="Length(30)")
  inspect(style.margin.left, content="Length(40)")
}

///|
test "parse individual padding properties" {
  let style = parse_inline_style(
    "padding-top: 5px; padding-right: 10px; padding-bottom: 15px; padding-left: 20px",
  )
  inspect(style.padding.top, content="Length(5)")
  inspect(style.padding.right, content="Length(10)")
  inspect(style.padding.bottom, content="Length(15)")
  inspect(style.padding.left, content="Length(20)")
}

///|
test "parse border individual widths" {
  let style = parse_inline_style(
    "border-top-width: 1px; border-right-width: 2px; border-bottom-width: 3px; border-left-width: 4px",
  )
  inspect(style.border.top, content="Length(1)")
  inspect(style.border.right, content="Length(2)")
  inspect(style.border.bottom, content="Length(3)")
  inspect(style.border.left, content="Length(4)")
}

///|
test "parse flex-direction row-reverse" {
  let style = parse_inline_style("flex-direction: row-reverse")
  inspect(style.flex_direction, content="RowReverse")
}

///|
test "parse flex-direction column-reverse" {
  let style = parse_inline_style("flex-direction: column-reverse")
  inspect(style.flex_direction, content="ColumnReverse")
}

///|
test "parse flex: none" {
  let style = parse_inline_style("flex: none")
  inspect(style.flex_grow, content="0")
  inspect(style.flex_shrink, content="0")
  inspect(style.flex_basis, content="Auto")
}

///|
test "parse flex: auto" {
  let style = parse_inline_style("flex: auto")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Auto")
}

///|
test "parse flex: 2 1 100px" {
  let style = parse_inline_style("flex: 2 1 100px")
  inspect(style.flex_grow, content="2")
  inspect(style.flex_shrink, content="1")
  inspect(style.flex_basis, content="Length(100)")
}

///|
test "parse grid-auto-flow row" {
  let style = parse_inline_style("grid-auto-flow: row")
  inspect(style.grid_auto_flow, content="Row")
}

///|
test "parse vh and vw units" {
  let style = parse_inline_style("width: 50vw; height: 100vh")
  // 50vw = 50% of 1000px = 500px
  inspect(style.width, content="Length(500)")
  // 100vh = 100% of 1000px = 1000px
  inspect(style.height, content="Length(1000)")
}

///|
test "parse em and rem units" {
  let style = parse_inline_style("width: 2em; height: 1.5rem")
  // 2em = 2 * 16px = 32px
  inspect(style.width, content="Length(32)")
  // 1.5rem = 1.5 * 16px = 24px
  inspect(style.height, content="Length(24)")
}

///|
test "parse unitless zero" {
  let style = parse_inline_style("margin: 0; padding: 0")
  inspect(style.margin.top, content="Length(0)")
  inspect(style.padding.top, content="Length(0)")
}

///|
test "parse box-sizing content-box" {
  let style = parse_inline_style(
    "box-sizing: content-box; width: 100px; padding: 10px",
  )
  // content-box should adjust width to include padding
  // 100px content + 10px left + 10px right = 120px
  inspect(style.width, content="Length(120)")
}

///|
test "parse box-sizing border-box" {
  let style = parse_inline_style(
    "box-sizing: border-box; width: 100px; padding: 10px",
  )
  // border-box keeps width as-is
  inspect(style.width, content="Length(100)")
}

///|
test "parse align-content center" {
  let style = parse_inline_style("align-content: center")
  inspect(style.align_content, content="Center")
}

///|
test "parse align-content space-between" {
  let style = parse_inline_style("align-content: space-between")
  inspect(style.align_content, content="SpaceBetween")
}

///|
test "parse logical property padding-block" {
  let style = parse_inline_style("padding-block: 20px")
  inspect(style.padding.top, content="Length(20)")
  inspect(style.padding.bottom, content="Length(20)")
}

///|
test "parse logical property padding-inline" {
  let style = parse_inline_style("padding-inline: 15px")
  inspect(style.padding.left, content="Length(15)")
  inspect(style.padding.right, content="Length(15)")
}

///|
test "parse logical property border-block" {
  let style = parse_inline_style("border-block: 2px")
  inspect(style.border.top, content="Length(2)")
  inspect(style.border.bottom, content="Length(2)")
}

///|
test "parse logical property border-inline" {
  let style = parse_inline_style("border-inline: 3px")
  inspect(style.border.left, content="Length(3)")
  inspect(style.border.right, content="Length(3)")
}

///|
test "parse grid-template-columns with auto-fill" {
  let style = parse_inline_style(
    "grid-template-columns: repeat(auto-fill, 100px)",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(AutoFill, [Length(100)])",
  )
}

///|
test "parse grid-template-columns with minmax in repeat" {
  let style = parse_inline_style(
    "grid-template-columns: repeat(3, minmax(100px, 1fr))",
  )
  inspect(style.grid_template_columns.length(), content="1")
  inspect(
    style.grid_template_columns[0],
    content="Repeat(Count(3), [MinMax(Length(100), Fr(1))])",
  )
}

///|
test "parse alignment start and end" {
  let style = parse_inline_style("justify-content: start; align-items: end")
  inspect(style.justify_content, content="Start")
  inspect(style.align_items, content="End")
}

///|
test "parse alignment flex-start and flex-end" {
  let style = parse_inline_style(
    "justify-content: flex-start; align-items: flex-end",
  )
  inspect(style.justify_content, content="FlexStart")
  inspect(style.align_items, content="FlexEnd")
}

///|
test "parse transform translate" {
  let style = parse_inline_style("transform: translate(10px, 20px)")
  inspect(style.transform.translate_x, content="Length(10)")
  inspect(style.transform.translate_y, content="Length(20)")
}

///|
test "parse transform translateX" {
  let style = parse_inline_style("transform: translateX(50%)")
  inspect(style.transform.translate_x, content="Percent(0.5)")
  inspect(style.transform.translate_y, content="Length(0)")
}

///|
test "parse transform translateY" {
  let style = parse_inline_style("transform: translateY(-100px)")
  inspect(style.transform.translate_x, content="Length(0)")
  inspect(style.transform.translate_y, content="Length(-100)")
}

///|
test "parse transform translate with percentage" {
  let style = parse_inline_style("transform: translate(-50%, -50%)")
  inspect(style.transform.translate_x, content="Percent(-0.5)")
  inspect(style.transform.translate_y, content="Percent(-0.5)")
}
