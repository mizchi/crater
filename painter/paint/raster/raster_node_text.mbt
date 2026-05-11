///|
/// Text rendering helpers for PaintNode rasterization.

///|
fn render_node_text_content(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Unit {
  match node.text {
    Some(text_content) => {
      let (text_x, text_y, text_w) = resolve_text_render_box(node, x, y, w, h)
      match glyph_provider_override.val {
        Some(provider) => {
          let svg_color = @svg.Color::rgb(
            node.paint.color.r,
            node.paint.color.g,
            node.paint.color.b,
          )
          let font_size = node.paint.font_size
          let wrap_width = resolve_glyph_text_wrap_width(
            text_w, h, font_size, text_content,
          )
          let _ = draw_text_with_glyphs_clipped(
            fb,
            palette,
            provider,
            text_x,
            text_y,
            text_content,
            wrap_width,
            svg_color,
            font_size,
            node.paint.line_height,
            node.paint.is_bold,
            clip,
            font_family=node.paint.font_family,
            opacity=node.paint.opacity,
            letter_spacing=node.paint.letter_spacing,
            word_spacing=node.paint.word_spacing,
            font_weight=node.paint.font_weight,
          )
        }
        None => {
          let text_idx = palette.get_or_add(
            types_color_to_image(node.paint.color),
          )
          let scale = 1
          let _ = draw_text_clipped(
            fb, text_x, text_y, text_content, text_w, text_idx, scale, clip,
          )
        }
      }
    }
    None => ()
  }
}

///|
fn render_node_text_decorations(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  clip : ClipRect?,
) -> Unit {
  match node.text {
    Some(_) => {
      let font_size = node.paint.font_size
      if node.paint.text_decoration_overline {
        draw_text_decoration_line(
          fb,
          palette,
          x,
          y + (font_size * 0.15).to_int(),
          w,
          node.paint.color,
          node.paint.opacity,
          clip,
        )
      }
      if node.paint.text_decoration_line_through {
        draw_text_decoration_line(
          fb,
          palette,
          x,
          y + (font_size * 0.6).to_int(),
          w,
          node.paint.color,
          node.paint.opacity,
          clip,
        )
      }
      if node.paint.text_decoration_underline {
        draw_text_decoration_line(
          fb,
          palette,
          x,
          y + (font_size * 1.1).to_int(),
          w,
          node.paint.color,
          node.paint.opacity,
          clip,
        )
      }
    }
    None => ()
  }
}
