///|
fn fill_node(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  color : @types.Color,
  children : Array[@paint_model.PaintNode],
) -> @paint_model.PaintNode {
  let paint = {
    ..@paint_model.PaintProperties::default(),
    background_color: color,
  }
  @paint_model.PaintNode::new(id, "div", x, y, w, h, paint, children)
}

///|
test "to_gfx_color normalizes 0..255 channels into 0..1" {
  inspect(
    to_gfx_color(@types.Color::rgb(255, 128, 0)),
    content=(
      #|{ r: 1, g: 0.5019607843137255, b: 0, a: 1 }
    ),
  )
}

///|
test "collect_fill_commands lowers each visible node in paint order" {
  let tree = fill_node(
    "root",
    0.0,
    0.0,
    100.0,
    100.0,
    @types.Color::rgb(255, 255, 255),
    [
      fill_node(
        "opaque",
        10.0,
        10.0,
        20.0,
        20.0,
        @types.Color::rgb(255, 0, 0),
        [],
      ),
      fill_node(
        "transparent",
        0.0,
        0.0,
        5.0,
        5.0,
        @types.Color::transparent(),
        [],
      ),
      fill_node("zero-area", 0.0, 0.0, 0.0, 0.0, @types.Color::rgb(0, 0, 255), []),
    ],
  )
  let dst = @gfx.new_image_handle(1, 100, 100)
  let shader = @gfx.new_shader_handle(2, default_fill_shader_source())
  let commands = collect_fill_commands(tree, dst, shader)
  // root + opaque child only; transparent and zero-area nodes are skipped.
  inspect(commands.length(), content="2")
  inspect(
    commands.map(fn(c) { c.dst_regions[0] }),
    content=(
      #|[{ x: 0, y: 0, width: 100, height: 100, index_count: 6 }, { x: 10, y: 10, width: 20, height: 20, index_count: 6 }]
    ),
  )
  inspect(commands.map(fn(c) { c.blend }), content="[Copy, Copy]")
}

///|
test "translucent background selects alpha blending" {
  let tree = fill_node(
    "root",
    0.0,
    0.0,
    10.0,
    10.0,
    @types.Color::rgba(0, 0, 0, 0.5),
    [],
  )
  let dst = @gfx.new_image_handle(1, 10, 10)
  let shader = @gfx.new_shader_handle(2, "s")
  let commands = collect_fill_commands(tree, dst, shader)
  inspect(commands.map(fn(c) { c.blend }), content="[Alpha]")
}

///|
test "render_paint_tree drives a null graphics backend end-to-end" {
  let tree = fill_node(
    "root",
    0.0,
    0.0,
    64.0,
    48.0,
    @types.Color::rgb(255, 255, 255),
    [fill_node("box", 4.0, 4.0, 8.0, 8.0, @types.Color::rgb(0, 128, 255), [])],
  )
  let driver = @gfx.create_null_graphics(64, 48)
  // Should initialize, allocate resources and flush one render pass
  // without raising.
  render_paint_tree(driver, tree)
}
