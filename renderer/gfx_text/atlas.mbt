///|
/// Glyph atlas texturing for `gfx_text`.
///
/// This mirrors kagura `mizchi/text`'s atlas path: instead of filling each
/// glyph ink box with a solid color, the glyph coverage bitmaps are packed
/// into a single-channel alpha atlas and each glyph is emitted as a
/// textured quad (`src_image_ids` + uv coordinates) sampling that atlas.
/// A real GPU backend uploads `GlyphAtlas::coverage` to the image and
/// modulates the sampled alpha by the text color.
///
/// (The gfx `GraphicsDriver` contract has no texture-upload entry point, so
/// sampling is exercised by GPU backends that own that step; the solid-fill
/// `glyph_placements_to_commands` path remains for backends without
/// texture support.)

///|
/// One packed glyph: its destination ink box (pixel space) and the uv
/// rectangle locating it inside the atlas.
pub(all) struct GlyphAtlasEntry {
  x : Double
  y : Double
  w : Double
  h : Double
  u0 : Double
  v0 : Double
  u1 : Double
  v1 : Double
}

///|
/// A packed alpha atlas for one text run: `coverage` is a row-major
/// `width * height` array of 0..255 alpha values, `image` is the handle the
/// backend samples, and `entries` locates each inked glyph.
pub(all) struct GlyphAtlas {
  width : Int
  height : Int
  coverage : Array[Int]
  image : @gfx.ImageHandle
  entries : Array[GlyphAtlasEntry]
}

///|
/// Pack the inked glyphs of `placements` into a horizontal-strip alpha
/// atlas bound to `image`. Whitespace / empty glyphs are skipped.
pub fn build_glyph_atlas(
  placements : Array[@glyph.GlyphPlacement],
  image : @gfx.ImageHandle,
) -> GlyphAtlas {
  let inked : Array[@glyph.GlyphPlacement] = []
  for p in placements {
    if p.bitmap.width > 0 && p.bitmap.height > 0 {
      inked.push(p)
    }
  }
  if inked.length() == 0 {
    return { width: 0, height: 0, coverage: [], image, entries: [] }
  }
  let mut atlas_w = 0
  let mut atlas_h = 0
  for p in inked {
    atlas_w = atlas_w + p.bitmap.width
    if p.bitmap.height > atlas_h {
      atlas_h = p.bitmap.height
    }
  }
  let coverage = Array::make(atlas_w * atlas_h, 0)
  let entries : Array[GlyphAtlasEntry] = []
  let mut x_off = 0
  for p in inked {
    let b = p.bitmap
    let max_cov = if b.ss_factor * b.ss_factor <= 0 {
      1
    } else {
      b.ss_factor * b.ss_factor
    }
    let has_cov = b.coverage.length() == b.width * b.height
    for by in 0..<b.height {
      for bx in 0..<b.width {
        let bi = by * b.width + bx
        let on = bi < b.pixels.length() && b.pixels[bi]
        let alpha = if on {
          if has_cov {
            b.coverage[bi] * 255 / max_cov
          } else {
            255
          }
        } else {
          0
        }
        coverage[by * atlas_w + (x_off + bx)] = alpha
      }
    }
    entries.push({
      x: p.x + b.offset_x.to_double(),
      y: p.y + b.offset_y.to_double(),
      w: b.width.to_double(),
      h: b.height.to_double(),
      u0: x_off.to_double() / atlas_w.to_double(),
      v0: 0.0,
      u1: (x_off + b.width).to_double() / atlas_w.to_double(),
      v1: b.height.to_double() / atlas_h.to_double(),
    })
    x_off = x_off + b.width
  }
  { width: atlas_w, height: atlas_h, coverage, image, entries }
}

///|
/// Emit one textured quad per packed glyph, sampling `atlas` and modulating
/// by `color`.
pub fn atlas_to_commands(
  frame : @gfx_frame.RenderFrame2D,
  atlas : GlyphAtlas,
  color : @gfx.Color,
) -> Array[@gfx.DrawTrianglesCommand] {
  let commands : Array[@gfx.DrawTrianglesCommand] = []
  for entry in atlas.entries {
    let (vertices, indices) = @gfx_frame.ndc_rect_vertices(
      entry.x,
      entry.y,
      entry.w,
      entry.h,
      frame.screen_w.to_double(),
      frame.screen_h.to_double(),
      u0=entry.u0,
      v0=entry.v0,
      u1=entry.u1,
      v1=entry.v1,
    )
    commands.push(
      @gfx_frame.new_primitive_command(frame, vertices, indices, color, src_image_ids=[
        atlas.image.id,
      ]),
    )
  }
  commands
}

///|
/// Lay out `placements` into a glyph atlas bound to `image` and return both
/// the atlas (for the backend to upload) and the textured draw commands.
pub fn glyph_placements_to_atlas_commands(
  frame : @gfx_frame.RenderFrame2D,
  placements : Array[@glyph.GlyphPlacement],
  color : @gfx.Color,
  image : @gfx.ImageHandle,
) -> (GlyphAtlas, Array[@gfx.DrawTrianglesCommand]) {
  let atlas = build_glyph_atlas(placements, image)
  (atlas, atlas_to_commands(frame, atlas, color))
}
