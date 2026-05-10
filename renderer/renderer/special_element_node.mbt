///|
// Final node construction for replaced elements, form controls, and br.

///|
fn finalize_special_element_node(
  elem : @html.Element,
  tag_lower : String,
  style : @style.Style,
  children : Array[@node.Node],
) -> @node.Node {
  let node_id = make_node_id(elem)

  // Handle replaced elements (img, input, etc.) with intrinsic sizing
  if tag_lower == "input" && children.is_empty() {
    // Get input type (default is "text")
    let input_type = match elem.attributes.get("type") {
      Some(t) => t.to_lower()
      None => "text"
    }
    let control_font_size = if style.font_size > 0.0 {
      style.font_size
    } else {
      16.0
    }
    let control_line_height = if style.line_height > 0.0 {
      style.line_height
    } else {
      control_font_size * 1.15
    }
    let char_width = resolve_control_char_width(
      control_font_size,
      control_line_height,
      style.writing_mode,
    )
    // Get intrinsic dimensions based on input type
    // These are approximate browser defaults
    let (intrinsic_width, intrinsic_height) : (Double, Double) = match
      input_type {
      "radio" | "checkbox" => (13.0, 13.0)
      "button" | "submit" | "reset" => {
        let label = match elem.attributes.get("value") {
          Some(v) if !v.is_empty() => v
          _ =>
            match input_type {
              "submit" => "Submit"
              "reset" => "Reset"
              _ => ""
            }
        }
        let mut label_cols = 0
        for c in label.iter() {
          label_cols = label_cols + char_display_width(c)
        }
        let label_width = label_cols.to_double() * char_width
        let min_width = control_font_size * 1.75
        let intrinsic_w = @types.max(
          min_width,
          label_width + control_font_size * 0.72,
        )
        (intrinsic_w, 21.0)
      }
      "range" => (129.0, 21.0)
      "color" => (44.0, 23.0)
      "file" => (238.0, 21.0)
      "text" | "password" | "search" | "email" | "url" | "tel" | "number" => {
        let size_chars = match elem.attributes.get("size") {
          Some(size_attr) =>
            match parse_html_dimension(size_attr) {
              Some(v) if v > 0.0 => v
              _ => 20.0
            }
          None => 20.0
        }
        let padding_h = resolve_dimension_to_px(style.padding.left) +
          resolve_dimension_to_px(style.padding.right)
        let padding_v = resolve_dimension_to_px(style.padding.top) +
          resolve_dimension_to_px(style.padding.bottom)
        let border_h = resolve_dimension_to_px(style.border.left) +
          resolve_dimension_to_px(style.border.right)
        let border_v = resolve_dimension_to_px(style.border.top) +
          resolve_dimension_to_px(style.border.bottom)
        let control_extra_width = if control_font_size <= 13.0 {
          control_font_size
        } else {
          control_font_size * 0.75
        }
        let control_extra_height = if control_font_size <= 13.0 {
          4.5
        } else {
          control_font_size * 0.35
        }
        let input_extra_width = if padding_h > 0.0 {
          padding_h + border_h
        } else {
          control_extra_width
        }
        let input_extra_height = if padding_v > 0.0 {
          padding_v + border_v
        } else {
          control_extra_height
        }
        (
          size_chars * char_width + input_extra_width,
          control_line_height + input_extra_height,
        )
      }
      // text, password, email, url, tel, search, number, date, etc.
      _ => (150.0, 21.0)
    }
    let measure = create_input_measure(intrinsic_width, intrinsic_height)
    let preserve_auto_width = should_preserve_auto_replaced_width(style)
    let preserve_auto_height = should_preserve_auto_replaced_height(style)
    let input_text = resolve_input_paint_text(input_type, elem.attributes)
    let placeholder_text = input_uses_placeholder_text(
      input_type,
      elem.attributes,
    )
    let input_style : @style.Style = {
      ..style,
      color: if placeholder_text {
        @types.Color::rgb(117, 117, 117)
      } else {
        style.color
      },
      width: if style.width == @types.Auto && !preserve_auto_width {
        @types.Length(intrinsic_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto && !preserve_auto_height {
        @types.Length(intrinsic_height)
      } else {
        style.height
      },
    }
    match input_text {
      Some(text) =>
        return @node.Node::with_measure(node_id, input_style, measure, text~)
      None => return @node.Node::with_measure(node_id, input_style, measure)
    }
  }
  let style = if tag_lower == "button" &&
    !style.contain.size &&
    !style.writing_mode.is_vertical() {
    fn is_zero_padding(dim : @types.Dimension) -> Bool {
      match dim {
        @types.Length(v) => v == 0.0
        _ => false
      }
    }
    let has_zero_padding = is_zero_padding(style.padding.top) &&
      is_zero_padding(style.padding.right) &&
      is_zero_padding(style.padding.bottom) &&
      is_zero_padding(style.padding.left)
    if has_zero_padding {
      {
        ..style,
        padding: {
          top: @types.Length(0.7),
          right: @types.Length(4.75),
          bottom: @types.Length(0.7),
          left: @types.Length(4.75),
        },
      }
    } else {
      style
    }
  } else {
    style
  }
  if tag_lower == "textarea" {
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    // Browser default textarea intrinsic row-height is tighter than generic
    // line-height: normal; approximate as font-size + 1px per row.
    let control_line_height = font_size + 1.0
    // Browsers include textarea chrome around the rows even under border-box.
    // Keep this narrow so form-control regressions stay localized to textarea.
    let control_extra_height = 6.0
    let char_width = resolve_control_char_width(
      font_size,
      control_line_height,
      style.writing_mode,
    )
    let cols = match elem.attributes.get("cols") {
      Some(cols_attr) =>
        match parse_html_dimension(cols_attr) {
          Some(v) if v > 0.0 => v
          _ => 20.0
        }
      None => 20.0
    }
    let rows = match elem.attributes.get("rows") {
      Some(rows_attr) =>
        match parse_html_dimension(rows_attr) {
          Some(v) if v > 0.0 => v
          _ => 2.0
        }
      None => 2.0
    }
    let intrinsic_width = cols * char_width + font_size * 1.1
    let intrinsic_height = rows * control_line_height + control_extra_height
    let measure = create_input_measure(intrinsic_width, intrinsic_height)
    let preserve_auto_width = should_preserve_auto_replaced_width(style)
    let preserve_auto_height = should_preserve_auto_replaced_height(style)
    let textarea_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto && !preserve_auto_width {
        @types.Length(intrinsic_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto && !preserve_auto_height {
        @types.Length(intrinsic_height)
      } else {
        style.height
      },
    }
    return @node.Node::with_measure(node_id, textarea_style, measure)
  }
  if tag_lower == "select" {
    fn border_is_zero_length(dim : @types.Dimension) -> Bool {
      match dim {
        @types.Length(v) => v == 0.0
        _ => false
      }
    }
    let has_ua_border = !(border_is_zero_length(style.border.top) &&
      border_is_zero_length(style.border.right) &&
      border_is_zero_length(style.border.bottom) &&
      border_is_zero_length(style.border.left))
    let select_size = match elem.attributes.get("size") {
      Some(size_attr) =>
        match parse_html_dimension(size_attr) {
          Some(v) if v > 0.0 => v.to_int()
          _ => 0
        }
      None => 0
    }
    let has_multiple = elem.attributes.contains("multiple")
    let is_listbox = has_multiple || select_size > 1
    let visible_rows = if select_size > 0 {
      select_size
    } else if is_listbox {
      4
    } else {
      1
    }
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    let default_line_height = if style.line_height > 0.0 {
      style.line_height
    } else {
      font_size * 1.2
    }
    let char_width = resolve_control_char_width(
      font_size,
      default_line_height,
      style.writing_mode,
    )
    let suppress_intrinsic_width = style.suppresses_intrinsic_width()
    fn collect_html_text(node : @html.Node) -> String {
      match node {
        @html.Node::Text(text) => text
        @html.Node::Element(child_elem) => {
          let mut text = ""
          for grand_child in child_elem.children {
            text = text + collect_html_text(grand_child)
          }
          text
        }
      }
    }
    let mut max_option_cols = 0
    if !suppress_intrinsic_width {
      for child in elem.children {
        match child {
          @html.Node::Element(child_elem) =>
            if child_elem.tag.to_lower() == "option" {
              let mut option_text = ""
              for option_child in child_elem.children {
                option_text = option_text + collect_html_text(option_child)
              }
              let mut cols = 0
              for c in option_text.iter() {
                cols = cols + char_display_width(c)
              }
              if cols > max_option_cols {
                max_option_cols = cols
              }
            }
          _ => ()
        }
      }
    }
    let content_based_width = if max_option_cols > 0 {
      max_option_cols.to_double() * char_width + font_size * 0.375
    } else {
      0.0
    }
    let single_default_width = @types.max(22.0, content_based_width)
    let listbox_default_width = if suppress_intrinsic_width {
      2.0
    } else if max_option_cols > 0 {
      @types.max(2.0, content_based_width)
    } else {
      2.0
    }
    let default_width = if is_listbox {
      listbox_default_width
    } else if suppress_intrinsic_width {
      22.0
    } else {
      single_default_width
    }
    let default_height = if is_listbox {
      if visible_rows <= 1 {
        17.5
      } else if visible_rows == 4 {
        if font_size <= 12.0 {
          48.0
        } else {
          64.0
        }
      } else {
        let row_height = if font_size <= 12.0 { 11.5 } else { 15.5 }
        2.0 + visible_rows.to_double() * row_height
      }
    } else {
      19.0
    }
    let default_border : @types.Rect[@types.Dimension] = @types.Rect::new(
      @types.Length(1.0),
      @types.Length(1.0),
      @types.Length(1.0),
      @types.Length(1.0),
    )
    let zero_dim_rect : @types.Rect[@types.Dimension] = @types.Rect::new(
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
    )

    let normalized_children : Array[@node.Node] = []
    let mut option_index = 0
    for child in children {
      let is_option = node_id_is_tag(child.id, "option")
      if is_option {
        let option_style = if is_listbox {
          let option_font_size = if child.style.font_size > 0.0 {
            child.style.font_size
          } else {
            font_size
          }
          let option_row_height = option_font_size * 1.15 + 1.0
          {
            ..child.style,
            display: @types.Block,
            height: @types.Length(option_row_height),
          }
        } else {
          let top_offset = if option_index == 0 {
            -default_line_height
          } else {
            0.0
          }
          {
            ..child.style,
            display: @types.Block,
            width: @types.Length(0.0),
            height: @types.Length(0.0),
            margin: @types.Rect::new(
              @types.Length(top_offset),
              @types.Length(0.0),
              @types.Length(0.0),
              @types.Length(0.0),
            ),
            padding: zero_dim_rect,
            border: zero_dim_rect,
          }
        }
        let option_children = if is_listbox { child.children } else { [] }
        normalized_children.push(
          @node.Node::with_uid_and_measure(
            child.id,
            child.uid,
            option_style,
            option_children,
            child.measure,
            child.text,
          ),
        )
        option_index = option_index + 1
      } else {
        normalized_children.push(child)
      }
    }
    let preserve_auto_width = should_preserve_auto_replaced_width(style)
    let preserve_auto_height = should_preserve_auto_replaced_height(style)
    let select_style : @style.Style = {
      ..style,
      border: if has_ua_border {
        style.border
      } else {
        default_border
      },
      width: if style.width == @types.Auto && !preserve_auto_width {
        @types.Length(default_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto && !preserve_auto_height {
        @types.Length(default_height)
      } else {
        style.height
      },
    }
    return @node.Node::new(node_id, select_style, normalized_children)
  }
  if tag_lower == "svg" && children.is_empty() {
    // Root SVG behaves as a replaced element with default object size 300x150.
    // Keep CSS width/height auto semantics and expose intrinsic size via MeasureFunc.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let intrinsic_width = if attr_width > 0.0 { attr_width } else { 300.0 }
    let intrinsic_height = if attr_height > 0.0 { attr_height } else { 150.0 }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, style, measure)
  }
  if tag_lower == "img" && children.is_empty() {
    // HTML width/height attributes are presentational hints (used as CSS defaults),
    // while decoded image size is intrinsic data used for MeasureFunc/aspect-ratio.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let mut intrinsic_width = attr_width
    let mut intrinsic_height = attr_height
    let mut uses_svg_fallback_object_size = false
    let mut uses_alt_fallback_size = false
    let mut uses_alt_text_overflow_box = false
    // Fill missing intrinsic dimensions from src data when available.
    if intrinsic_width == 0.0 || intrinsic_height == 0.0 {
      match elem.attributes.get("src") {
        Some(src) =>
          match get_image_intrinsic_size(src) {
            Some((w, h)) => {
              if intrinsic_width == 0.0 {
                intrinsic_width = w
              }
              if intrinsic_height == 0.0 {
                intrinsic_height = h
              }
            }
            None => ()
          }
        None => ()
      }
    }
    // Data-SVG without intrinsic dimensions falls back to 300x150.
    let has_svg_data_src = match elem.attributes.get("src") {
      Some(src) => src.to_lower().has_prefix("data:image/svg+xml")
      None => false
    }
    if intrinsic_width == 0.0 && intrinsic_height == 0.0 && has_svg_data_src {
      intrinsic_width = 300.0
      intrinsic_height = 150.0
      uses_svg_fallback_object_size = true
    }
    let alt_text = elem.attributes.get("alt")
    let has_non_data_src = match elem.attributes.get("src") {
      Some(src) => !src.to_lower().has_prefix("data:")
      None => false
    }
    // Chromium-style broken image fallback in our WPT setup: when external
    // image loading is unavailable and alt text exists, keep a visible fallback box.
    if intrinsic_width == 0.0 &&
      intrinsic_height == 0.0 &&
      has_non_data_src &&
      !style.suppresses_intrinsic_width() &&
      !style.suppresses_intrinsic_height() {
      match alt_text {
        Some(alt) =>
          if alt.length() > 0 {
            if broken_img_alt_uses_non_replaced_overflow_box(style) {
              uses_alt_text_overflow_box = true
            } else {
              intrinsic_width = 64.0
              intrinsic_height = if style.display == @types.Block {
                let fallback_line_height = if style.line_height > 0.0 {
                  style.line_height
                } else {
                  style.font_size
                }
                96.0 + fallback_line_height
              } else {
                96.0
              }
              uses_alt_fallback_size = true
            }
          }
        None => ()
      }
    }

    // Check if CSS dimensions are percentages - we need to handle these specially
    // even if intrinsic dimensions are 0
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    // Always treat <img> as replaced; unknown intrinsic size remains 0x0,
    // but CSS sizing keywords/percentages still need replaced-element behavior.
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    // Calculate intrinsic aspect ratio (width / height)
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 &&
      intrinsic_width > 0.0 &&
      !uses_svg_fallback_object_size &&
      !uses_alt_fallback_size {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }

    // Build img style similar to canvas:
    // - Use HTML attribute dimension as default when CSS is Auto
    // - CSS dimensions (%, px, etc.) override HTML attributes
    // - Set aspect ratio from intrinsic dimensions if not already set
    // - If height is %, keep width as Auto so aspect_ratio can compute it
    let resolved_width : @types.Dimension = if style.width == @types.Auto {
      if suppress_auto_inline_size {
        @types.Auto
        // If height is %, keep width Auto to let aspect_ratio compute it
      } else if height_is_percent {
        @types.Auto
      } else if attr_width > 0.0 {
        @types.Length(attr_width)
      } else {
        style.width
      }
    } else {
      style.width
    }
    let resolved_height : @types.Dimension = if style.height == @types.Auto {
      if suppress_auto_block_size {
        @types.Auto
        // If width is %, keep height Auto to let aspect_ratio compute it
      } else if width_is_percent {
        @types.Auto
      } else if style.width != @types.Auto {
        @types.Auto
      } else if attr_height > 0.0 {
        @types.Length(attr_height)
      } else {
        style.height
      }
    } else {
      style.height
    }
    let keep_intrinsic_ratio = should_apply_intrinsic_replaced_aspect_ratio(
      resolved_width, resolved_height,
    )
    let img_style : @style.Style = {
      ..style,
      width: resolved_width,
      height: resolved_height,
      // Set aspect ratio from intrinsic dimensions (for % sizing)
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio // Keep CSS-specified ratio
        None => if keep_intrinsic_ratio { intrinsic_aspect_ratio } else { None }
      },
    }
    let src_attr = elem.attributes.get("src")
    return match alt_text {
      Some(alt) =>
        if uses_alt_text_overflow_box {
          @node.Node::new(node_id, { ..img_style, aspect_ratio: None }, [
            create_text_node(alt, img_style),
          ])
        } else {
          @node.Node::with_measure(
            node_id,
            img_style,
            measure,
            text=alt,
            src=src_attr,
          )
        }
      None =>
        @node.Node::with_measure(node_id, img_style, measure, src=src_attr)
    }
  }
  // Handle canvas element with intrinsic sizing
  if tag_lower == "canvas" && children.is_empty() {
    // Canvas has default intrinsic size of 300x150 (HTML spec)
    let default_width = 300.0
    let default_height = 150.0

    // Get dimensions from HTML attributes (override defaults)
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }

    // Calculate intrinsic aspect ratio (width / height)
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }

    // Build canvas style:
    // - Keep CSS auto dimensions as auto; intrinsic size still comes from MeasureFunc
    // - CSS dimensions (%, px, etc.) override the intrinsic defaults
    // - Set aspect ratio from intrinsic dimensions if not already set
    // - If one axis is percentage-sized, keep the opposite axis auto so aspect-ratio can compute it
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let resolved_width : @types.Dimension = if style.width == @types.Auto {
      if suppress_auto_inline_size {
        @types.Auto
        // If height is %, keep width Auto to let aspect_ratio compute it
      } else if height_is_percent {
        @types.Auto
      } else {
        @types.Auto
      }
    } else {
      style.width
    }
    let resolved_height : @types.Dimension = if style.height == @types.Auto {
      if suppress_auto_block_size {
        @types.Auto
        // If width is %, keep height Auto to let aspect_ratio compute it
      } else if width_is_percent {
        @types.Auto
      } else {
        @types.Auto
      }
    } else {
      style.height
    }
    let keep_intrinsic_ratio = should_apply_intrinsic_replaced_aspect_ratio(
      resolved_width, resolved_height,
    )
    let canvas_style : @style.Style = {
      ..style,
      width: resolved_width,
      height: resolved_height,
      // Set aspect ratio from intrinsic dimensions (for % sizing)
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio // Keep CSS-specified ratio
        None =>
          if style.contain.size || !keep_intrinsic_ratio {
            None
          } else {
            intrinsic_aspect_ratio
          }
      },
    }

    // Always use MeasureFunc to provide intrinsic size
    // The layout algorithm will use CSS dimensions if specified
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, canvas_style, measure)
  }

  // Handle iframe/object/embed as replaced elements with default intrinsic sizing
  if (tag_lower == "iframe" || tag_lower == "object" || tag_lower == "embed") &&
    children.is_empty() {
    if tag_lower == "embed" {
      let has_src = match elem.attributes.get("src") {
        Some(src) => src.trim().length() > 0
        None => false
      }
      if !has_src {
        return @node.Node::leaf(node_id, {
          ..style,
          display: @types.Display::None,
        })
      }
    }
    // HTML replaced elements default intrinsic size is 300x150
    let default_width = 300.0
    let default_height = 150.0
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let resolved_width : @types.Dimension = if style.width == @types.Auto {
      if suppress_auto_inline_size {
        @types.Auto
      } else if height_is_percent {
        @types.Auto
      } else {
        @types.Length(intrinsic_width)
      }
    } else {
      style.width
    }
    let resolved_height : @types.Dimension = if style.height == @types.Auto {
      if suppress_auto_block_size {
        @types.Auto
      } else if width_is_percent {
        @types.Auto
      } else {
        @types.Length(intrinsic_height)
      }
    } else {
      style.height
    }
    let keep_intrinsic_ratio = should_apply_intrinsic_replaced_aspect_ratio(
      resolved_width, resolved_height,
    )
    let replaced_style : @style.Style = {
      ..style,
      width: resolved_width,
      height: resolved_height,
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio
        None =>
          if style.contain.size || !keep_intrinsic_ratio {
            None
          } else {
            intrinsic_aspect_ratio
          }
      },
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, replaced_style, measure)
  }

  // Handle video/audio as replaced elements with fallback intrinsic size.
  // These fallback sizes should not imply a concrete intrinsic aspect ratio,
  // and source/track/fallback descendants do not affect the outer replaced box.
  if tag_lower == "video" || tag_lower == "audio" {
    let default_width = 300.0
    let default_height = 150.0
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let media_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        if suppress_auto_inline_size {
          @types.Auto
        } else if height_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_width)
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        if suppress_auto_block_size {
          @types.Auto
        } else if width_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_height)
        }
      } else {
        style.height
      },
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio
        None => None
      },
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, media_style, measure)
  }

  // Handle br element with line-height for height
  if tag_lower == "br" {
    // br elements have zero width but take up line-height vertically
    // line_height is already computed as absolute pixel value
    let measure = create_br_measure(
      style.line_height,
      style.font_size,
      style.writing_mode,
    )
    return @node.Node::with_measure(node_id, style, measure)
  }
  if children.is_empty() {
    @node.Node::leaf(node_id, style)
  } else {
    @node.Node::new(node_id, style, children)
  }
}
