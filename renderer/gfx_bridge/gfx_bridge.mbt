///|
/// Paint-tree assembler for crater's gfx-backed renderer.
///
/// This is crater's analogue of kagura's `mizchi/renderer2d`: the single
/// "assembler" layer that composes the wiring units into a stream of
/// `@gfx.DrawTrianglesCommand`s for any `GraphicsDriver` backend (null /
/// WebGL / WebGPU / native). It walks a `@paint_model.PaintNode` tree and
/// dispatches each node to the matching unit:
///
/// - box background / borders -> `gfx_frame` rect primitives
/// - text runs                -> `gfx_text` (glyph layout + quads)
/// - replaced images (`src`)  -> `gfx_image` (textured quads)
///
/// The shared 2D primitives, frame context and color helpers live in
/// `gfx_frame` and are re-exported here so consumers only import the
/// assembler.

///|
pub using @gfx_frame {type RenderFrame2D, type RectFill2D, type RectOutline2D}

// ---------------------------------------------------------------------------
// Per-node lowering
// ---------------------------------------------------------------------------

///|
/// Append the node's non-inset box shadows as hard-edged offset + spread
/// fills, painted before the box so the element sits on top. Blur is not
/// modeled (a deterministic hard shadow); the shadow follows the offset and
/// spread but stays rectangular.
pub fn append_paint_node_shadows(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  if node.width <= 0.0 || node.height <= 0.0 {
    return
  }
  for shadow in node.paint.box_shadows {
    if shadow.inset || shadow.color.is_transparent() {
      continue
    }
    let spread = shadow.spread_radius
    let sx = node.x + shadow.offset_x - spread
    let sy = node.y + shadow.offset_y - spread
    let sw = node.width + spread * 2.0
    let sh = node.height + spread * 2.0
    if sw <= 0.0 || sh <= 0.0 {
      continue
    }
    @gfx_frame.append_rect_fill(
      commands,
      frame,
      @gfx_frame.RectFill2D::new(
        x=sx,
        y=sy,
        w=sw,
        h=sh,
        color=@gfx_frame.to_gfx_color(shadow.color),
      ),
    )
  }
}

///|
/// Append the node's background fill, if it has a visible one. When any
/// border radius is set, the fill is emitted as a rounded rectangle.
pub fn append_paint_node_background(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  let bg = node.paint.background_color
  if bg.is_transparent() || node.width <= 0.0 || node.height <= 0.0 {
    return
  }
  let p = node.paint
  let rect = @gfx_frame.RectFill2D::new(
    x=node.x,
    y=node.y,
    w=node.width,
    h=node.height,
    color=@gfx_frame.to_gfx_color(bg),
  )
  if p.border_top_left_radius > 0.0 ||
    p.border_top_right_radius > 0.0 ||
    p.border_bottom_right_radius > 0.0 ||
    p.border_bottom_left_radius > 0.0 {
    @gfx_frame.append_rounded_rect_fill(
      commands,
      frame,
      rect,
      radius_tl=p.border_top_left_radius,
      radius_tr=p.border_top_right_radius,
      radius_br=p.border_bottom_right_radius,
      radius_bl=p.border_bottom_left_radius,
    )
  } else {
    @gfx_frame.append_rect_fill(commands, frame, rect)
  }
}

///|
/// Append the node's borders as up to four edge fills. Each side carries
/// its own width and color (the CSS box model), so they are emitted as
/// individual edge fills rather than a single uniform outline.
pub fn append_paint_node_borders(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  let p = node.paint
  let x = node.x
  let y = node.y
  let w = node.width
  let h = node.height
  fn edge(
    width : Double,
    color : @types.Color,
    ex : Double,
    ey : Double,
    ew : Double,
    eh : Double,
  ) -> Unit {
    if width > 0.0 && !color.is_transparent() && ew > 0.0 && eh > 0.0 {
      @gfx_frame.append_rect_fill(
        commands,
        frame,
        @gfx_frame.RectFill2D::new(
          x=ex,
          y=ey,
          w=ew,
          h=eh,
          color=@gfx_frame.to_gfx_color(color),
        ),
      )
    }
  }

  edge(p.border_top_width, p.border_top_color, x, y, w, p.border_top_width)
  edge(
    p.border_bottom_width,
    p.border_bottom_color,
    x,
    y + h - p.border_bottom_width,
    w,
    p.border_bottom_width,
  )
  edge(p.border_left_width, p.border_left_color, x, y, p.border_left_width, h)
  edge(
    p.border_right_width,
    p.border_right_color,
    x + w - p.border_right_width,
    y,
    p.border_right_width,
    h,
  )
}

///|
/// Append the node's replaced image (`src`) as a textured quad, resolving
/// the source string to an `@gfx.ImageHandle` via `resolve_image`.
pub fn append_paint_node_image(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
  resolve_image : (String) -> @gfx.ImageHandle?,
) -> Unit {
  match node.src {
    Some(src) =>
      match resolve_image(src) {
        Some(image) =>
          @gfx_image.append_image_quad(
            commands,
            frame,
            @gfx_image.ImageQuad2D::new(
              x=node.x,
              y=node.y,
              w=node.width,
              h=node.height,
              image~,
            ),
          )
        None => ()
      }
    None => ()
  }
}

///|
/// Append the node's text run, laying it out with `provider` and filling
/// each glyph ink box with the node's text color.
pub fn append_paint_node_text(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
  provider : @glyph.GlyphProvider,
) -> Unit {
  match node.text {
    Some(text) => {
      if text.length() == 0 {
        return
      }
      let p = node.paint
      let cmds = @gfx_text.text_run_coverage_commands(
        frame,
        provider,
        text,
        node.x.to_int(),
        node.y.to_int(),
        p.font_size,
        @gfx_frame.to_gfx_color(p.color),
        max_width=node.width.to_int(),
        line_height=p.line_height,
        is_bold=p.is_bold,
        font_family=p.font_family,
        letter_spacing=p.letter_spacing,
        word_spacing=p.word_spacing,
        font_weight=p.font_weight,
      )
      for cmd in cmds {
        commands.push(cmd)
      }
    }
    None => ()
  }
}

///|
/// Append a single node's box paint (background then borders). Text and
/// images need extra inputs (a glyph provider / image resolver) and are
/// lowered by the tree walk.
pub fn append_paint_node(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  append_paint_node_shadows(commands, frame, node)
  append_paint_node_background(commands, frame, node)
  append_paint_node_borders(commands, frame, node)
}

// ---------------------------------------------------------------------------
// Tree walk
// ---------------------------------------------------------------------------

///|
/// Walk the paint tree in paint order (a node's box before its children)
/// and collect all draw commands.
///
/// Text is lowered when `glyph_provider` is supplied; replaced images are
/// lowered when `resolve_image` is supplied. Background and borders are
/// always lowered.
pub fn collect_paint_commands(
  frame : RenderFrame2D,
  root : @paint_model.PaintNode,
  glyph_provider? : @glyph.GlyphProvider,
  resolve_image? : (String) -> @gfx.ImageHandle?,
) -> Array[@gfx.DrawTrianglesCommand] {
  let commands : Array[@gfx.DrawTrianglesCommand] = []
  // `frame` carries the active clip (scissor) and opacity. A node's
  // CSS opacity multiplies its own box/borders *and* its descendants (group
  // opacity), so it is folded into the frame before painting the node and
  // inherited by children. A node that clips its content
  // (overflow: hidden/clip/scroll) additionally intersects the clip onto
  // its children.
  fn visit(node : @paint_model.PaintNode, frame : RenderFrame2D) -> Unit {
    let node_frame = frame.with_opacity(node.paint.opacity)
    append_paint_node_shadows(commands, node_frame, node)
    append_paint_node_background(commands, node_frame, node)
    append_paint_node_borders(commands, node_frame, node)
    match resolve_image {
      Some(resolve) =>
        append_paint_node_image(commands, node_frame, node, resolve)
      None => ()
    }
    match glyph_provider {
      Some(provider) =>
        append_paint_node_text(commands, node_frame, node, provider)
      None => ()
    }
    let child_frame = if node.clips_content() {
      match node.get_clip_rect() {
        Some((cx, cy, cw, ch)) =>
          node_frame.with_clip(
            cx.to_int(),
            cy.to_int(),
            cw.to_int(),
            ch.to_int(),
          )
        None => node_frame
      }
    } else {
      node_frame
    }
    for child in node.children {
      visit(child, child_frame)
    }
  }

  visit(root, frame)
  commands
}

///|
/// Enqueue every command for the paint tree into a command queue, letting
/// the queue merge compatible draws.
pub fn[Q : @gfx.CommandQueue] enqueue_paint_tree(
  queue : Q,
  frame : RenderFrame2D,
  root : @paint_model.PaintNode,
  glyph_provider? : @glyph.GlyphProvider,
  resolve_image? : (String) -> @gfx.ImageHandle?,
) -> Unit {
  for
    cmd in collect_paint_commands(frame, root, glyph_provider?, resolve_image?) {
    queue.enqueue_draw_triangles(cmd)
  }
}

// ---------------------------------------------------------------------------
// End-to-end driver entry point
// ---------------------------------------------------------------------------

///|
/// Placeholder fill shader source handed to the driver. Real backends
/// substitute their own builtin solid-color / textured program; the null
/// driver only needs a stable, non-empty source string.
pub fn default_fill_shader_source() -> String {
  "// crater gfx_bridge: solid color / textured fill\n" +
  "// frag = uniform color (rgba u8x4) * sampled texel"
}

///|
/// Drive a `GraphicsDriver` backend end-to-end from a paint tree:
/// initialize, allocate the destination image and fill shader, build a
/// `RenderFrame2D` sized from the root box, lower the tree into a queue,
/// then flush a single render pass.
///
/// Text is lowered automatically when a glyph provider has been configured
/// globally (`@glyph.get_glyph_provider()`).
pub fn[D : @gfx.GraphicsDriver] render_paint_tree(
  driver : D,
  root : @paint_model.PaintNode,
  clear_color? : @gfx.Color = @gfx.new_color(1.0, 1.0, 1.0, 1.0),
  present? : Bool = false,
) -> Unit raise {
  driver.initialize()
  let width = if root.width > 0.0 { root.width.to_int() } else { 1 }
  let height = if root.height > 0.0 { root.height.to_int() } else { 1 }
  let dst = driver.new_image(width, height)
  let shader = driver.new_shader(default_fill_shader_source())
  let frame = @gfx_frame.RenderFrame2D::new(
    dst~,
    shader~,
    screen_w=width,
    screen_h=height,
  )
  let queue = @gfx.new_simple_command_queue()
  match @glyph.get_glyph_provider() {
    Some(provider) =>
      enqueue_paint_tree(queue, frame, root, glyph_provider=provider)
    None => enqueue_paint_tree(queue, frame, root)
  }
  @gfx.flush_commands(driver, queue, present, clear_color~)
}
