///|
fn inked_glyph(
  x : Double,
  w : Int,
  h : Int,
  ss : Int,
  coverage : Array[Int],
) -> @glyph.GlyphPlacement {
  let pixels = []
  for c in coverage {
    pixels.push(c > 0)
  }
  let bitmap : @glyph.GlyphBitmap = {
    width: w,
    height: h,
    pixels,
    advance: w.to_double(),
    offset_x: 0,
    offset_y: 0,
    coverage,
    ss_factor: ss,
  }
  { bitmap, x, y: 0.0, line_height: 16.0 }
}

///|
test "build_glyph_atlas packs inked glyphs into an alpha strip" {
  // two 2x2 glyphs, ss_factor 2 -> max coverage 4. Second glyph has a
  // half-covered top-left texel (cov 2 -> alpha 127).
  let g0 = inked_glyph(0.0, 2, 2, 2, [4, 4, 4, 4])
  let g1 = inked_glyph(2.0, 2, 2, 2, [2, 4, 0, 4])
  let atlas = build_glyph_atlas([g0, g1], @gfx.new_image_handle(9, 4, 2))
  inspect(atlas.width, content="4")
  inspect(atlas.height, content="2")
  // row-major alpha: g0 occupies columns 0..1, g1 columns 2..3.
  // row 0: [255,255, 127,255]; row 1: [255,255, 0,255]
  debug_inspect(
    atlas.coverage,
    content="[255, 255, 127, 255, 255, 255, 0, 255]",
  )
  // g1's uv rect starts halfway across the atlas
  inspect(atlas.entries[1].u0, content="0.5")
  inspect(atlas.entries[1].u1, content="1")
}

///|
test "atlas_to_commands emits textured quads sampling the atlas" {
  let frame = @gfx_frame.RenderFrame2D::new(
    dst=@gfx.new_image_handle(1, 100, 100),
    shader=@gfx.new_shader_handle(2, "s"),
    screen_w=100,
    screen_h=100,
  )
  let g0 = inked_glyph(0.0, 2, 2, 1, [1, 1, 1, 1])
  let (atlas, commands) = glyph_placements_to_atlas_commands(
    frame,
    [g0],
    @gfx.new_color(0.0, 0.0, 0.0, 1.0),
    @gfx.new_image_handle(9, 2, 2),
  )
  inspect(commands.length(), content="1")
  // textured: references the atlas image id
  debug_inspect(commands[0].src_image_ids, content="[9]")
  // uv of the single glyph spans the whole atlas
  inspect(atlas.entries[0].u0, content="0")
  inspect(atlas.entries[0].u1, content="1")
  inspect(atlas.entries[0].v1, content="1")
}
