///|
/// Linear-gradient background lowering.
///
/// The gfx draw path only carries a single solid color per command, so a
/// gradient is approximated by tiling the box with 1px-wide solid strips
/// sampled along the gradient axis. For axis-aligned gradients (`to right` /
/// `to left` / `to top` / `to bottom`, i.e. 0/90/180/270deg) the strip color
/// is constant across the perpendicular axis, so this reproduces the per-pixel
/// raster fill exactly. Diagonal gradients fall back to strips along the
/// dominant axis (the tilt is dropped) -- still far closer to the browser than
/// painting nothing.

///|
fn clamp_byte(v : Int) -> Int {
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
/// Interpolate two colors at position t in [0,1].
fn lerp_gradient_color(
  a : @types.Color,
  b : @types.Color,
  t : Double,
) -> @types.Color {
  let r = (a.r.to_double() * (1.0 - t) + b.r.to_double() * t).to_int()
  let g = (a.g.to_double() * (1.0 - t) + b.g.to_double() * t).to_int()
  let bl = (a.b.to_double() * (1.0 - t) + b.b.to_double() * t).to_int()
  let alpha = a.a * (1.0 - t) + b.a * t
  @types.Color::rgba(clamp_byte(r), clamp_byte(g), clamp_byte(bl), alpha)
}

///|
/// Sample a gradient's color ramp at position t in [0,1].
fn sample_linear_gradient(
  grad : @types.LinearGradient,
  t : Double,
) -> @types.Color {
  let stops = grad.stops
  if stops.length() == 0 {
    return @types.Color::transparent()
  }
  if t <= stops[0].position {
    return stops[0].color
  }
  let last = stops.length() - 1
  if t >= stops[last].position {
    return stops[last].color
  }
  for i = 0; i < last; i = i + 1 {
    if t >= stops[i].position && t <= stops[i + 1].position {
      let range = stops[i + 1].position - stops[i].position
      let local_t = if range > 0.0 {
        (t - stops[i].position) / range
      } else {
        0.0
      }
      return lerp_gradient_color(stops[i].color, stops[i + 1].color, local_t)
    }
  }
  stops[last].color
}

///|
/// Append a node's `background-image: linear-gradient(...)` as solid strips.
/// Paints over the solid `background-color` (which is lowered separately),
/// matching CSS background layering.
pub fn append_paint_node_gradient(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  match node.paint.background_image {
    @types.Gradient(grad) => {
      if node.width <= 0.0 || node.height <= 0.0 || grad.stops.length() == 0 {
        return
      }
      let w = node.width
      let h = node.height
      // CSS gradient angle: 0deg = to top, 90deg = to right. The gradient line
      // direction is the angle rotated so that increasing t runs along it.
      let pi = 3.14159265358979
      let rad = (grad.angle_deg - 90.0) * pi / 180.0
      let dx = @math.cos(rad)
      let dy = @math.sin(rad)
      let cx = w / 2.0
      let cy = h / 2.0
      let half_len = (cx * dx.abs() + cy * dy.abs()).abs()
      let inv_len = if half_len > 0.001 { 1.0 / (2.0 * half_len) } else { 0.0 }
      fn clamp01(v : Double) -> Double {
        if v < 0.0 {
          0.0
        } else if v > 1.0 {
          1.0
        } else {
          v
        }
      }

      fn axis_strip(
        t_raw : Double,
        sx : Double,
        sy : Double,
        sw : Double,
        sh : Double,
      ) -> Unit {
        let color = sample_linear_gradient(grad, clamp01(t_raw))
        if color.a <= 0.0 {
          return
        }
        @gfx_frame.append_rect_fill(
          commands,
          frame,
          @gfx_frame.RectFill2D::new(
            x=sx,
            y=sy,
            w=sw,
            h=sh,
            color=@gfx_frame.to_gfx_color(color),
          ),
        )
      }

      // Axis-aligned gradients (the common `to right` / `to bottom` / Ndeg
      // cases): tile with 1px solid strips perpendicular to the axis. The
      // color is constant across each strip, so this reproduces the per-pixel
      // raster fill exactly.
      let near = 0.01
      if dy.abs() < near {
        // horizontal gradient -> vertical strips (vary x)
        let cols = w.to_int()
        for i = 0; i < cols; i = i + 1 {
          let proj = (i.to_double() - cx) * dx
          axis_strip(
            (proj + half_len) * inv_len,
            node.x + i.to_double(),
            node.y,
            1.0,
            h,
          )
        }
      } else if dx.abs() < near {
        // vertical gradient -> horizontal strips (vary y)
        let rows = h.to_int()
        for j = 0; j < rows; j = j + 1 {
          let proj = (j.to_double() - cy) * dy
          axis_strip(
            (proj + half_len) * inv_len,
            node.x,
            node.y + j.to_double(),
            w,
            1.0,
          )
        }
      } else {
        // Diagonal gradient: tile the box with bands perpendicular to the
        // gradient axis, emitted as rotated quads and scissored to the box.
        // draw_triangles takes arbitrary NDC vertices, so the band can be
        // tilted; the box AABB clip removes the overhang.
        let clip = frame.with_clip(
          node.x.to_int(),
          node.y.to_int(),
          (node.x + w).to_int() - node.x.to_int() + 1,
          (node.y + h).to_int() - node.y.to_int() + 1,
        )
        // perpendicular half-extent of the box projected off the axis
        let perp = cx * dy.abs() + cy * dx.abs()
        let bands = {
          let n = (2.0 * half_len).to_int()
          if n < 1 {
            1
          } else if n > 256 {
            256
          } else {
            n
          }
        }
        let center_x = node.x + cx
        let center_y = node.y + cy
        let nb = bands.to_double()
        for i = 0; i < bands; i = i + 1 {
          let tc = (i.to_double() + 0.5) / nb
          let color = sample_linear_gradient(grad, clamp01(tc))
          if color.a <= 0.0 {
            continue
          }
          // axis offsets for the band's two edges
          let s0 = (2.0 * (i.to_double() / nb) - 1.0) * half_len
          let s1 = (2.0 * ((i.to_double() + 1.0) / nb) - 1.0) * half_len
          // corner = center + axis*s + perp*(±P); perp = (-dy, dx)
          fn corner(s : Double, sign : Double) -> (Double, Double) {
            (
              center_x + dx * s + -dy * perp * sign,
              center_y + dy * s + dx * perp * sign,
            )
          }

          let (ax, ay) = corner(s0, -1.0)
          let (bx, by) = corner(s1, -1.0)
          let (cxp, cyp) = corner(s1, 1.0)
          let (dxp, dyp) = corner(s0, 1.0)
          let verts = @gfx_frame.pixel_to_ndc_vertices(
            [
              ax, ay, 0.0, 0.0, bx, by, 0.0, 0.0, cxp, cyp, 0.0, 0.0, dxp, dyp, 0.0,
              0.0,
            ],
            clip.screen_w.to_double(),
            clip.screen_h.to_double(),
          )
          commands.push(
            @gfx_frame.new_primitive_command(
              clip,
              verts,
              @gfx_frame.quad_fill_indices(),
              @gfx_frame.to_gfx_color(color),
            ),
          )
        }
      }
    }
    @types.None => ()
  }
}
