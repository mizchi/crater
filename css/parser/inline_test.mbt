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
    None => fail!("aspect_ratio should be Some")
  }
}

///|
test "parse grid-auto-flow" {
  let style = parse_inline_style("display: grid; grid-auto-flow: column")
  inspect(style.display, content="Grid")
  inspect(style.grid_auto_flow, content="Column")
}

test "order property" {
  let style = parse_inline_style("order: 5")
  inspect(style.order, content="5")
}

test "order negative" {
  let style = parse_inline_style("order: -1")
  inspect(style.order, content="-1")
}

test "flex shorthand" {
  let style = parse_inline_style("flex: 1")
  inspect(style.flex_grow, content="1")
  inspect(style.flex_shrink, content="1")
}

test "grid-template-columns basic" {
  let style = parse_inline_style("display: grid; grid-template-columns: 100px 200px 1fr")
  inspect(style.display, content="Grid")
  inspect(style.grid_template_columns.length(), content="3")
  inspect(style.grid_template_columns[0], content="Length(100)")
  inspect(style.grid_template_columns[1], content="Length(200)")
  inspect(style.grid_template_columns[2], content="Fr(1)")
}

test "grid-template-rows basic" {
  let style = parse_inline_style("display: grid; grid-template-rows: auto 50px 2fr")
  inspect(style.display, content="Grid")
  inspect(style.grid_template_rows.length(), content="3")
  inspect(style.grid_template_rows[0], content="Auto")
  inspect(style.grid_template_rows[1], content="Length(50)")
  inspect(style.grid_template_rows[2], content="Fr(2)")
}

test "grid-template-columns with percentage" {
  let style = parse_inline_style("grid-template-columns: 50% 50%")
  inspect(style.grid_template_columns.length(), content="2")
  inspect(style.grid_template_columns[0], content="Percent(0.5)")
  inspect(style.grid_template_columns[1], content="Percent(0.5)")
}

test "grid-template-columns none" {
  let style = parse_inline_style("grid-template-columns: none")
  inspect(style.grid_template_columns.length(), content="0")
}

test "grid-template-columns minmax" {
  let style = parse_inline_style("grid-template-columns: minmax(100px, 1fr)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="MinMax(Length(100), Fr(1))")
}

test "grid-template-columns repeat" {
  let style = parse_inline_style("grid-template-columns: repeat(3, 100px)")
  inspect(style.grid_template_columns.length(), content="1")
  inspect(style.grid_template_columns[0], content="Repeat(Count(3), [Length(100)])")
}
