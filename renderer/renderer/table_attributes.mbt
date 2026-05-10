///|
// Table HTML attribute normalization for layout style conversion.

///|
fn apply_table_attributes(
  elem : @html.Element,
  cell_tag : String,
  style : @style.Style,
) -> @style.Style {
  let style = apply_table_element_attributes(elem, cell_tag, style)
  apply_table_cell_attributes(elem, cell_tag, style)
}

///|
fn apply_table_element_attributes(
  elem : @html.Element,
  cell_tag : String,
  style : @style.Style,
) -> @style.Style {
  if cell_tag != "table" {
    return style
  }
  let border_spacing = match elem.attributes.get("cellspacing") {
    Some(val) => {
      let n = @string.parse_double(val) catch { _ => style.border_spacing }
      if n >= 0.0 {
        n
      } else {
        style.border_spacing
      }
    }
    None => style.border_spacing
  }
  match elem.attributes.get("cellpadding") {
    Some(val) => {
      let n = @string.parse_double(val) catch { _ => -1.0 }
      if n >= 0.0 {
        current_cellpadding.val = n
      }
    }
    None => ()
  }
  let border_spacing_vertical = match elem.attributes.get("cellspacing") {
    Some(_) => border_spacing
    None => style.border_spacing_vertical
  }
  { ..style, border_spacing, border_spacing_vertical }
}

///|
fn apply_table_cell_attributes(
  elem : @html.Element,
  cell_tag : String,
  style : @style.Style,
) -> @style.Style {
  if cell_tag != "td" && cell_tag != "th" {
    return style
  }
  let rowspan = match elem.attributes.get("rowspan") {
    Some(val) => {
      let n = @string.parse_int(val) catch { _ => 1 }
      if n > 0 {
        n
      } else {
        1
      }
    }
    None => 1
  }
  let colspan = match elem.attributes.get("colspan") {
    Some(val) => {
      let n = @string.parse_int(val) catch { _ => 1 }
      if n > 0 {
        n
      } else {
        1
      }
    }
    None => 1
  }
  let mut next_style = { ..style, rowspan, colspan }
  let cp = current_cellpadding.val
  if cp >= 0.0 {
    let default_pad = @types.Dimension::Length(0.0)
    let has_css_padding = next_style.padding.top != @types.Dimension::Auto &&
      next_style.padding.top != default_pad
    if !has_css_padding {
      next_style = {
        ..next_style,
        padding: {
          top: @types.Dimension::Length(cp),
          right: @types.Dimension::Length(cp),
          bottom: @types.Dimension::Length(cp),
          left: @types.Dimension::Length(cp),
        },
      }
    }
  }
  next_style
}
