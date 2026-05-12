///|
/// SVG display normalization and attribute sizing helpers.

///|
/// Check if tag is an SVG element
fn is_svg_element(tag : String) -> Bool {
  match tag {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path"
    | "text"
    | "tspan"
    | "defs"
    | "use"
    | "symbol"
    | "clipPath"
    | "mask"
    | "pattern"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "image"
    | "foreignObject"
    | "switch"
    | "a" => true
    // Note: "a" in SVG context is an SVG element, but we can't distinguish here
    // It will be handled by context in the future
    _ => false
  }
}

///|
fn selector_parent_is_svg(selector_elem : @css.Element) -> Bool {
  match selector_elem.parent {
    Some(parent) => is_svg_element(parent.tag_name.to_lower())
    None => false
  }
}

///|
fn normalize_svg_display_contents(
  tag : String,
  style : @style.Style,
  parent_is_svg : Bool,
) -> @style.Style {
  if style.display != @types.Contents {
    return style
  }
  if tag == "svg" && !parent_is_svg {
    // Root-level SVG display:contents should not leak SVG descendants into
    // HTML flow sizing.
    return { ..style, display: @types.Display::None }
  }
  if tag == "text" && parent_is_svg {
    // SVG <text> with display:contents does not create a CSS flow box.
    return { ..style, display: @types.Display::None }
  }
  style
}

///|
/// Apply SVG attributes (width, height, x, y, line coords, circle/ellipse) to style
fn apply_svg_attributes_to_style(
  style : @style.Style,
  attrs : Map[String, String],
  tag : String,
) -> @style.Style {
  let mut result = style
  fn parse_svg_dimension(value : String) -> @types.Dimension? {
    let trimmed = value.trim().to_owned()
    if trimmed.is_empty() {
      return None
    }
    if trimmed.has_suffix("%") {
      let percent_str = remove_suffix(trimmed, 1)
      let percent = @string.parse_double(percent_str) catch { _ => return None }
      return Some(@types.Percent(percent / 100.0))
    }
    let length = parse_svg_length(trimmed)
    // Keep zero as a valid explicit length (e.g. width="0").
    if length == 0.0 {
      let raw = @string.parse_double(trimmed) catch { _ => return None }
      return Some(@types.Length(raw))
    }
    Some(@types.Length(length))
  }

  let attr_width_for_ratio = match attrs.get("width") {
    Some(w) => parse_svg_length(w)
    None => 0.0
  }
  let attr_height_for_ratio = match attrs.get("height") {
    Some(h) => parse_svg_length(h)
    None => 0.0
  }
  if attr_width_for_ratio > 0.0 &&
    attr_height_for_ratio > 0.0 &&
    result.aspect_ratio is None {
    result = {
      ..result,
      aspect_ratio: Some(attr_width_for_ratio / attr_height_for_ratio),
    }
  }
  if result.aspect_ratio is None {
    match attrs.get("viewBox") {
      Some(vb) =>
        match parse_viewbox(vb) {
          Some((vb_w, vb_h)) if vb_w > 0.0 && vb_h > 0.0 =>
            result = { ..result, aspect_ratio: Some(vb_w / vb_h) }
          _ => ()
        }
      None => ()
    }
  }

  // Root <svg> width/height attributes behave as intrinsic dimensions.
  // If CSS already specifies either dimension, keep attributes only as ratio hints.
  let can_apply_svg_size_attrs = if tag == "svg" {
    result.width == @types.Auto && result.height == @types.Auto
  } else {
    true
  }

  // Get width from attribute
  match attrs.get("width") {
    Some(w) =>
      match (can_apply_svg_size_attrs, result.width, parse_svg_dimension(w)) {
        (false, _, _) => ()
        (true, @types.Auto, Some(dim)) => result = { ..result, width: dim }
        _ => ()
      }
    None => ()
  }

  // Get height from attribute
  match attrs.get("height") {
    Some(h) =>
      match (can_apply_svg_size_attrs, result.height, parse_svg_dimension(h)) {
        (false, _, _) => ()
        (true, @types.Auto, Some(dim)) => result = { ..result, height: dim }
        _ => ()
      }
    None => ()
  }

  // Handle SVG x/y position attributes for rect, text, etc.
  let has_x = attrs.contains("x")
  let has_y = attrs.contains("y")
  if has_x || has_y {
    let svg_x = match attrs.get("x") {
      Some(x_str) => parse_svg_length(x_str)
      None => 0.0
    }
    let svg_y = match attrs.get("y") {
      Some(y_str) => parse_svg_length(y_str)
      None => 0.0
    }
    result = {
      ..result,
      position: @types.Absolute,
      inset: {
        left: @types.Length(svg_x),
        right: result.inset.right,
        top: @types.Length(svg_y),
        bottom: result.inset.bottom,
      },
    }
  }

  // Handle SVG line elements (x1, y1, x2, y2) - compute bounding box
  let has_x1 = attrs.contains("x1")
  let has_y1 = attrs.contains("y1")
  let has_x2 = attrs.contains("x2")
  let has_y2 = attrs.contains("y2")
  if has_x1 || has_y1 || has_x2 || has_y2 {
    let x1 = match attrs.get("x1") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let y1 = match attrs.get("y1") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let x2 = match attrs.get("x2") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let y2 = match attrs.get("y2") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let min_x = if x1 < x2 { x1 } else { x2 }
    let min_y = if y1 < y2 { y1 } else { y2 }
    let width = if x1 > x2 { x1 - x2 } else { x2 - x1 }
    let height = if y1 > y2 { y1 - y2 } else { y2 - y1 }
    result = {
      ..result,
      position: @types.Absolute,
      width: @types.Length(width),
      height: @types.Length(height),
      inset: {
        left: @types.Length(min_x),
        right: result.inset.right,
        top: @types.Length(min_y),
        bottom: result.inset.bottom,
      },
    }
  }

  // Handle SVG circle elements (cx, cy, r) - compute bounding box
  let has_r = attrs.contains("r")
  if has_r {
    let cx = match attrs.get("cx") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let cy = match attrs.get("cy") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let r = match attrs.get("r") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    result = {
      ..result,
      position: @types.Absolute,
      width: @types.Length(r * 2.0),
      height: @types.Length(r * 2.0),
      inset: {
        left: @types.Length(cx - r),
        right: result.inset.right,
        top: @types.Length(cy - r),
        bottom: result.inset.bottom,
      },
    }
  }

  // Handle SVG ellipse elements (cx, cy, rx, ry) - compute bounding box
  let has_rx = attrs.contains("rx")
  let has_ry = attrs.contains("ry")
  if (has_rx || has_ry) && !has_r {
    let cx = match attrs.get("cx") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let cy = match attrs.get("cy") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let rx = match attrs.get("rx") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let ry = match attrs.get("ry") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    result = {
      ..result,
      position: @types.Absolute,
      width: @types.Length(rx * 2.0),
      height: @types.Length(ry * 2.0),
      inset: {
        left: @types.Length(cx - rx),
        right: result.inset.right,
        top: @types.Length(cy - ry),
        bottom: result.inset.bottom,
      },
    }
  }
  result
}

///|
/// Apply intrinsic fallback size for root SVG elements.
/// If width/height are auto, browsers use 300x150 with intrinsic ratio 2:1.
fn apply_svg_intrinsic_size(style : @style.Style, tag : String) -> @style.Style {
  if tag != "svg" {
    return style
  }

  let width_is_percent = match style.width {
    @types.Percent(_) => true
    _ => false
  }
  let height_is_percent = match style.height {
    @types.Percent(_) => true
    _ => false
  }
  let has_default_object_size = style.width == @types.Auto &&
    style.height == @types.Auto &&
    !style.contain.size &&
    style.display != @types.Contents

  {
    ..style
    // SVG behaves as a replaced inline element. Inline-block approximation
    // ensures width/height and intrinsic ratio participate in layout.
    ,
    display: if style.display == @types.Inline {
      @types.InlineBlock
    } else {
      style.display
    },
    width: if style.width == @types.Auto && height_is_percent {
      @types.Auto
    } else if has_default_object_size {
      @types.Length(300.0)
    } else {
      style.width
    },
    height: if style.height == @types.Auto && width_is_percent {
      @types.Auto
    } else if has_default_object_size {
      @types.Length(150.0)
    } else {
      style.height
    },
    aspect_ratio: match style.aspect_ratio {
      Some(_) => style.aspect_ratio
      None => if style.contain.size { None } else { Some(2.0) }
    },
  }
}

///|
/// Parse SVG length value (e.g., "100", "100px", "50%")
fn parse_svg_length(value : String) -> Double {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return 0.0
  }

  // Remove common units
  let num_str = if trimmed.has_suffix("px") {
    remove_suffix(trimmed, 2)
  } else if trimmed.has_suffix("pt") {
    remove_suffix(trimmed, 2)
  } else if trimmed.has_suffix("em") || trimmed.has_suffix("ex") {
    // em/ex are relative units, treat as pixels for now
    remove_suffix(trimmed, 2)
  } else if trimmed.has_suffix("%") {
    // Percentage - return 0 to skip (handled by CSS)
    return 0.0
  } else {
    trimmed
  }
  @string.parse_double(num_str) catch {
    _ => 0.0
  }
}
