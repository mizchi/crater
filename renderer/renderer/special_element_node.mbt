///|
// Final node construction for replaced elements, form controls, and br.

///|
fn escape_svg_attr(value : String) -> String {
  let buf = StringBuilder::new()
  for c in value.iter() {
    match c {
      '&' => buf.write_string("&amp;")
      '"' => buf.write_string("&quot;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn escape_svg_text(value : String) -> String {
  let buf = StringBuilder::new()
  for c in value.iter() {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn append_svg_attr(buf : StringBuilder, name : String, value : String) -> Unit {
  if name.is_empty() {
    return
  }
  buf.write_char(' ')
  buf.write_string(name)
  buf.write_string("=\"")
  buf.write_string(escape_svg_attr(value))
  buf.write_char('"')
}

///|
fn svg_color_to_hex(color : @types.Color) -> String {
  fn hex_char(n : Int) -> Char {
    if n < 10 {
      ('0'.to_int() + n).unsafe_to_char()
    } else {
      ('a'.to_int() + n - 10).unsafe_to_char()
    }
  }

  fn hex2(n : Int) -> String {
    let clamped = n.max(0).min(255)
    let hi = clamped / 16 % 16
    let lo = clamped % 16
    let buf = StringBuilder::new()
    buf.write_char(hex_char(hi))
    buf.write_char(hex_char(lo))
    buf.to_string()
  }

  "#" + hex2(color.r) + hex2(color.g) + hex2(color.b)
}

///|
fn is_svg_paintable_element(tag : String) -> Bool {
  match tag.to_lower() {
    "path"
    | "rect"
    | "circle"
    | "ellipse"
    | "polygon"
    | "polyline"
    | "text"
    | "tspan" => true
    _ => false
  }
}

///|
fn collect_html_text(node : @html.Node) -> String {
  match node {
    @html.Node::Text(text) => text
    @html.Node::Element(child_elem) => collect_element_text(child_elem)
  }
}

///|
fn collect_element_text(elem : @html.Element) -> String {
  let mut text = ""
  for child in elem.children {
    text = text + collect_html_text(child)
  }
  text
}

///|
fn resolve_textarea_paint_text(elem : @html.Element) -> String? {
  let text = collect_element_text(elem)
  if text.is_empty() {
    None
  } else {
    Some(text)
  }
}

///|
fn find_option_paint_text(
  elem : @html.Element,
  require_selected : Bool,
) -> String? {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let tag = child_elem.tag.to_lower()
        if tag == "option" {
          if !require_selected || child_elem.attributes.contains("selected") {
            return Some(collect_element_text(child_elem).trim().to_owned())
          }
        } else {
          match find_option_paint_text(child_elem, require_selected) {
            Some(text) => return Some(text)
            None => ()
          }
        }
      }
      @html.Node::Text(_) => ()
    }
  }
  None
}

///|
fn resolve_single_select_paint_text(elem : @html.Element) -> String? {
  match find_option_paint_text(elem, true) {
    Some(text) => Some(text)
    None => find_option_paint_text(elem, false)
  }
}

///|
fn find_svg_char_index(s : String, target : Char) -> Int? {
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int().unsafe_to_char() == target {
      return Some(i)
    }
  }
  None
}

///|
fn resolve_svg_paint_value(
  value : String,
  inherited_color : String,
  css_vars : Map[String, String],
  depth : Int,
) -> String {
  if depth > 8 {
    return inherited_color
  }
  let trimmed = value.trim().to_owned()
  let lower = trimmed.to_lower()
  if lower == "currentcolor" {
    return inherited_color
  }
  if lower.has_prefix("var(") && trimmed.has_suffix(")") {
    let inner = trimmed.unsafe_substring(start=4, end=trimmed.length() - 1)
    let comma_idx = find_svg_char_index(inner, ',')
    let name = match comma_idx {
      Some(idx) => inner.unsafe_substring(start=0, end=idx).trim().to_owned()
      None => inner.trim().to_owned()
    }
    match css_vars.get(name) {
      Some(found) =>
        return resolve_svg_paint_value(
          found,
          inherited_color,
          css_vars,
          depth + 1,
        )
      None =>
        match comma_idx {
          Some(idx) => {
            let fallback = inner.unsafe_substring(
              start=idx + 1,
              end=inner.length(),
            )
            return resolve_svg_paint_value(
              fallback,
              inherited_color,
              css_vars,
              depth + 1,
            )
          }
          None => return inherited_color
        }
    }
  }
  trimmed
}

///|
fn append_serialized_svg_element(
  buf : StringBuilder,
  elem : @html.Element,
  inherited_color : String,
  css_vars : Map[String, String],
) -> Unit {
  buf.write_char('<')
  buf.write_string(elem.tag)
  match elem.id {
    Some(id) => append_svg_attr(buf, "id", id)
    None => ()
  }
  if !elem.classes.is_empty() {
    append_svg_attr(buf, "class", elem.classes.join(" "))
  }
  match elem.style {
    Some(style) => append_svg_attr(buf, "style", style)
    None => ()
  }
  let mut has_xmlns = false
  let mut has_fill = false
  let mut element_fill = inherited_color
  elem.attributes.each(fn(name, value) {
    if name == "xmlns" {
      has_xmlns = true
    }
    if name == "fill" {
      has_fill = true
      let resolved = resolve_svg_paint_value(
        value, inherited_color, css_vars, 0,
      )
      if resolved.to_lower() != "none" {
        element_fill = resolved
      }
      append_svg_attr(buf, name, resolved)
    } else if name == "stroke" {
      append_svg_attr(
        buf,
        name,
        resolve_svg_paint_value(value, inherited_color, css_vars, 0),
      )
    } else {
      append_svg_attr(buf, name, value)
    }
  })
  if elem.tag == "svg" && !has_xmlns {
    append_svg_attr(buf, "xmlns", "http://www.w3.org/2000/svg")
  }
  if !has_fill &&
    is_svg_paintable_element(elem.tag) &&
    inherited_color != "#000000" {
    append_svg_attr(buf, "fill", inherited_color)
  }
  buf.write_char('>')
  for child in elem.children {
    match child {
      @html.Node::Text(text) => buf.write_string(escape_svg_text(text))
      @html.Node::Element(child_elem) =>
        append_serialized_svg_element(buf, child_elem, element_fill, css_vars)
    }
  }
  buf.write_string("</")
  buf.write_string(elem.tag)
  buf.write_char('>')
}

///|
fn inline_svg_data_uri(
  elem : @html.Element,
  style : @style.Style,
  css_vars : Map[String, String],
) -> String {
  let buf = StringBuilder::new()
  append_serialized_svg_element(
    buf,
    elem,
    svg_color_to_hex(style.color),
    css_vars,
  )
  "data:image/svg+xml," + buf.to_string()
}

///|
fn finalize_special_element_node(
  elem : @html.Element,
  tag_lower : String,
  style : @style.Style,
  children : Array[@node.Node],
  css_vars : Map[String, String],
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
        let label_width = resolve_control_label_width(
          label,
          control_font_size,
          control_line_height,
          style.writing_mode,
        )
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
    match resolve_textarea_paint_text(elem) {
      Some(text) =>
        return @node.Node::with_measure(node_id, textarea_style, measure, text~)
      None => return @node.Node::with_measure(node_id, textarea_style, measure)
    }
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
    let padding_v = resolve_dimension_to_px(style.padding.top) +
      resolve_dimension_to_px(style.padding.bottom)
    let border_v = resolve_dimension_to_px(style.border.top) +
      resolve_dimension_to_px(style.border.bottom)
    let single_default_height = @types.max(
      19.0,
      default_line_height + padding_v + border_v,
    )
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
      single_default_height
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
    let select_node = @node.Node::new(
      node_id, select_style, normalized_children,
    )
    if is_listbox {
      return select_node
    }
    match resolve_single_select_paint_text(elem) {
      Some(text) =>
        return @node.Node::with_uid_and_measure(
          select_node.id,
          select_node.uid,
          select_node.style,
          select_node.children,
          select_node.measure,
          Some(text),
        )
      None => return select_node
    }
  }
  if tag_lower == "svg" {
    // Root SVG is replaced; viewBox supplies intrinsic ratio/size while the
    // style layer resolves auto viewport size.
    // Keep CSS width/height auto semantics and expose intrinsic size via MeasureFunc.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let viewbox_size = match elem.attributes.get("viewBox") {
      Some(vb) => parse_viewbox(vb)
      None => None
    }
    let intrinsic_width = if attr_width > 0.0 {
      attr_width
    } else {
      match viewbox_size {
        Some((vb_w, _)) if vb_w > 0.0 => vb_w
        _ => 300.0
      }
    }
    let intrinsic_height = if attr_height > 0.0 {
      attr_height
    } else {
      match viewbox_size {
        Some((_, vb_h)) if vb_h > 0.0 => vb_h
        _ => 150.0
      }
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(
      node_id,
      style,
      measure,
      src=Some(inline_svg_data_uri(elem, style, css_vars)),
    )
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
