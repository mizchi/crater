///|
/// CSS Computed Values
/// Resolves cascaded values to computed values with inheritance

///|
/// Computed values context for resolving relative units
pub(all) struct ComputeContext {
  /// Parent's computed style (for inheritance)
  parent_style : @style.Style?
  /// Root font size (for rem units)
  root_font_size : Double
  /// Current font size (for em units)
  font_size : Double
  /// Viewport width (for vw units)
  viewport_width : Double
  /// Viewport height (for vh units)
  viewport_height : Double
}

///|
pub fn ComputeContext::new() -> ComputeContext {
  {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
  }
}

///|
pub fn ComputeContext::with_parent(parent : @style.Style) -> ComputeContext {
  {
    parent_style: Some(parent),
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
  }
}

///|
/// Create context with custom viewport dimensions
pub fn ComputeContext::with_viewport(
  viewport_width : Double,
  viewport_height : Double,
) -> ComputeContext {
  {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width,
    viewport_height,
  }
}

///|
/// Mutable style builder for collecting computed values
priv struct StyleBuilder {
  mut display : @style.Display
  mut position : @style.Position
  mut float : @style.Float
  mut clear : @style.Clear
  mut overflow_x : @style.Overflow
  mut overflow_y : @style.Overflow
  mut width : @types.Dimension
  mut height : @types.Dimension
  mut min_width : @types.Dimension
  mut min_height : @types.Dimension
  mut max_width : @types.Dimension
  mut max_height : @types.Dimension
  mut margin_top : @types.Dimension
  mut margin_right : @types.Dimension
  mut margin_bottom : @types.Dimension
  mut margin_left : @types.Dimension
  mut padding_top : @types.Dimension
  mut padding_right : @types.Dimension
  mut padding_bottom : @types.Dimension
  mut padding_left : @types.Dimension
  mut border_top : @types.Dimension
  mut border_right : @types.Dimension
  mut border_bottom : @types.Dimension
  mut border_left : @types.Dimension
  mut flex_direction : @style.FlexDirection
  mut flex_wrap : @style.FlexWrap
  mut justify_content : @style.Alignment
  mut align_items : @style.Alignment
  mut align_content : @style.Alignment
  mut align_self : @style.AlignSelf
  mut flex_grow : Double
  mut flex_shrink : Double
  mut flex_basis : @types.Dimension
  mut order : Int
  mut row_gap : @types.Dimension
  mut column_gap : @types.Dimension
  mut aspect_ratio : Double?
  mut inset_top : @types.Dimension
  mut inset_right : @types.Dimension
  mut inset_bottom : @types.Dimension
  mut inset_left : @types.Dimension
  mut grid_auto_flow : @style.GridAutoFlow
  mut grid_template_columns : Array[@style.TrackSizingFunction]
  mut grid_template_rows : Array[@style.TrackSizingFunction]
  // Font properties
  mut font_size : Double
  mut line_height : Double
}

///|
fn StyleBuilder::new() -> StyleBuilder {
  {
    display: @style.Display::Block,
    position: @style.Position::Relative,
    float: @style.Float::None,
    clear: @style.Clear::None,
    overflow_x: @style.Overflow::Visible,
    overflow_y: @style.Overflow::Visible,
    width: @types.Dimension::Auto,
    height: @types.Dimension::Auto,
    min_width: @types.Dimension::Auto,
    min_height: @types.Dimension::Auto,
    max_width: @types.Dimension::Auto,
    max_height: @types.Dimension::Auto,
    margin_top: @types.Dimension::Length(0.0),
    margin_right: @types.Dimension::Length(0.0),
    margin_bottom: @types.Dimension::Length(0.0),
    margin_left: @types.Dimension::Length(0.0),
    padding_top: @types.Dimension::Length(0.0),
    padding_right: @types.Dimension::Length(0.0),
    padding_bottom: @types.Dimension::Length(0.0),
    padding_left: @types.Dimension::Length(0.0),
    border_top: @types.Dimension::Length(0.0),
    border_right: @types.Dimension::Length(0.0),
    border_bottom: @types.Dimension::Length(0.0),
    border_left: @types.Dimension::Length(0.0),
    flex_direction: @style.FlexDirection::Row,
    flex_wrap: @style.FlexWrap::NoWrap,
    justify_content: @style.Alignment::Start,
    align_items: @style.Alignment::Stretch,
    align_content: @style.Alignment::Stretch,
    align_self: @style.AlignSelf::Auto,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    flex_basis: @types.Dimension::Auto,
    order: 0,
    row_gap: @types.Dimension::Length(0.0),
    column_gap: @types.Dimension::Length(0.0),
    aspect_ratio: None,
    inset_top: @types.Dimension::Auto,
    inset_right: @types.Dimension::Auto,
    inset_bottom: @types.Dimension::Auto,
    inset_left: @types.Dimension::Auto,
    grid_auto_flow: @style.GridAutoFlow::Row,
    grid_template_columns: [],
    grid_template_rows: [],
    font_size: 16.0,
    line_height: 16.0,
  }
}

///|
fn StyleBuilder::build(self : StyleBuilder) -> @style.Style {
  {
    display: self.display,
    position: self.position,
    float: self.float,
    clear: self.clear,
    overflow_x: self.overflow_x,
    overflow_y: self.overflow_y,
    width: self.width,
    height: self.height,
    min_width: self.min_width,
    min_height: self.min_height,
    max_width: self.max_width,
    max_height: self.max_height,
    margin: {
      top: self.margin_top,
      right: self.margin_right,
      bottom: self.margin_bottom,
      left: self.margin_left,
    },
    padding: {
      top: self.padding_top,
      right: self.padding_right,
      bottom: self.padding_bottom,
      left: self.padding_left,
    },
    border: {
      top: self.border_top,
      right: self.border_right,
      bottom: self.border_bottom,
      left: self.border_left,
    },
    flex_direction: self.flex_direction,
    flex_wrap: self.flex_wrap,
    justify_content: self.justify_content,
    align_items: self.align_items,
    align_content: self.align_content,
    align_self: self.align_self,
    flex_grow: self.flex_grow,
    flex_shrink: self.flex_shrink,
    flex_basis: self.flex_basis,
    order: self.order,
    row_gap: self.row_gap,
    column_gap: self.column_gap,
    aspect_ratio: self.aspect_ratio,
    inset: {
      top: self.inset_top,
      right: self.inset_right,
      bottom: self.inset_bottom,
      left: self.inset_left,
    },
    grid_template_rows: self.grid_template_rows,
    grid_template_columns: self.grid_template_columns,
    grid_auto_rows: [],
    grid_auto_columns: [],
    grid_auto_flow: self.grid_auto_flow,
    grid_template_areas: [],
    grid_row: @style.GridLine::auto(),
    grid_column: @style.GridLine::auto(),
    grid_area: None,
    justify_items: @style.Alignment::Stretch,
    justify_self: @style.AlignSelf::Auto,
    font_size: self.font_size,
    line_height: self.line_height,
  }
}

///|
/// Resolve a CSS keyword value to actual value
fn resolve_keyword(
  property : String,
  value : @cascade.PropertyValue,
  ctx : ComputeContext,
) -> String {
  match value {
    @cascade.PropertyValue::Value(v) => v
    @cascade.PropertyValue::Inherit =>
      // Get value from parent, or use initial if no parent
      get_inherited_value(property, ctx)
    @cascade.PropertyValue::Initial => initial_value(property)
    @cascade.PropertyValue::Unset =>
      // For inherited properties, acts like inherit
      // For non-inherited properties, acts like initial
      if is_inherited(property) {
        get_inherited_value(property, ctx)
      } else {
        initial_value(property)
      }
    @cascade.PropertyValue::Revert =>
      // Revert to user-agent stylesheet (we use initial as fallback)
      initial_value(property)
    @cascade.PropertyValue::RevertLayer =>
      // Revert to previous cascade layer (we use initial as fallback)
      initial_value(property)
  }
}

///|
/// Get inherited value from parent or initial value
fn get_inherited_value(property : String, ctx : ComputeContext) -> String {
  match ctx.parent_style {
    Some(parent) => get_style_value_as_string(property, parent)
    None => initial_value(property)
  }
}

///|
/// Get a style property value as string representation
fn get_style_value_as_string(property : String, style : @style.Style) -> String {
  match property {
    "display" =>
      match style.display {
        @style.Display::Block => "block"
        @style.Display::Flex => "flex"
        @style.Display::InlineFlex => "inline-flex"
        @style.Display::Grid => "grid"
        @style.Display::InlineGrid => "inline-grid"
        @style.Display::None => "none"
      }
    "position" =>
      match style.position {
        @style.Position::Relative => "relative"
        @style.Position::Absolute => "absolute"
      }
    "flex-direction" =>
      match style.flex_direction {
        @style.FlexDirection::Row => "row"
        @style.FlexDirection::RowReverse => "row-reverse"
        @style.FlexDirection::Column => "column"
        @style.FlexDirection::ColumnReverse => "column-reverse"
      }
    "flex-wrap" =>
      match style.flex_wrap {
        @style.FlexWrap::NoWrap => "nowrap"
        @style.FlexWrap::Wrap => "wrap"
        @style.FlexWrap::WrapReverse => "wrap-reverse"
      }
    "width" => dimension_to_string(style.width)
    "height" => dimension_to_string(style.height)
    "min-width" => dimension_to_string(style.min_width)
    "min-height" => dimension_to_string(style.min_height)
    "max-width" => dimension_to_string(style.max_width)
    "max-height" => dimension_to_string(style.max_height)
    "margin-top" => dimension_to_string(style.margin.top)
    "margin-right" => dimension_to_string(style.margin.right)
    "margin-bottom" => dimension_to_string(style.margin.bottom)
    "margin-left" => dimension_to_string(style.margin.left)
    "padding-top" => dimension_to_string(style.padding.top)
    "padding-right" => dimension_to_string(style.padding.right)
    "padding-bottom" => dimension_to_string(style.padding.bottom)
    "padding-left" => dimension_to_string(style.padding.left)
    "flex-grow" => style.flex_grow.to_string()
    "flex-shrink" => style.flex_shrink.to_string()
    "flex-basis" => dimension_to_string(style.flex_basis)
    _ => initial_value(property)
  }
}

///|
/// Convert dimension to string
fn dimension_to_string(dim : @types.Dimension) -> String {
  match dim {
    @types.Dimension::Auto => "auto"
    @types.Dimension::Length(n) =>
      if n == 0.0 {
        "0"
      } else {
        n.to_string() + "px"
      }
    @types.Dimension::Percent(n) => (n * 100.0).to_string() + "%"
  }
}

///|
/// Compute a Style from cascaded values
pub fn compute(
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> @style.Style {
  let builder = StyleBuilder::new()

  // Process each property
  let props = cascaded.properties()
  for prop in props {
    match cascaded.get(prop) {
      Some(decl) => {
        let value = resolve_keyword(prop, decl.value, ctx)
        apply_property(builder, prop, value, ctx)
      }
      None => ()
    }
  }

  // Handle inheritance for inherited properties
  apply_inheritance(builder, cascaded, ctx)
  builder.build()
}

///|
/// Apply a resolved property value to a style builder
fn apply_property(
  builder : StyleBuilder,
  property : String,
  value : String,
  ctx : ComputeContext,
) -> Unit {
  match property {
    // Display and positioning
    "display" => builder.display = parse_display(value)
    "position" => builder.position = parse_position(value)
    "float" => builder.float = parse_float(value)
    "clear" => builder.clear = parse_clear(value)
    // Sizing
    "width" => builder.width = resolve_dimension(value, ctx)
    "height" => builder.height = resolve_dimension(value, ctx)
    "min-width" => builder.min_width = resolve_dimension(value, ctx)
    "min-height" => builder.min_height = resolve_dimension(value, ctx)
    "max-width" => builder.max_width = resolve_dimension(value, ctx)
    "max-height" => builder.max_height = resolve_dimension(value, ctx)
    // Box model
    "margin" => {
      // Parse margin shorthand: 1-4 values
      let parts : Array[StringView] = value
        .split(" ")
        .filter(fn(s) { not(s.is_empty()) })
        .collect()
      match parts.length() {
        1 => {
          let dim = resolve_dimension(parts[0].to_string(), ctx)
          builder.margin_top = dim
          builder.margin_right = dim
          builder.margin_bottom = dim
          builder.margin_left = dim
        }
        2 => {
          let tb = resolve_dimension(parts[0].to_string(), ctx)
          let lr = resolve_dimension(parts[1].to_string(), ctx)
          builder.margin_top = tb
          builder.margin_bottom = tb
          builder.margin_left = lr
          builder.margin_right = lr
        }
        3 => {
          builder.margin_top = resolve_dimension(parts[0].to_string(), ctx)
          let lr = resolve_dimension(parts[1].to_string(), ctx)
          builder.margin_left = lr
          builder.margin_right = lr
          builder.margin_bottom = resolve_dimension(parts[2].to_string(), ctx)
        }
        4 => {
          builder.margin_top = resolve_dimension(parts[0].to_string(), ctx)
          builder.margin_right = resolve_dimension(parts[1].to_string(), ctx)
          builder.margin_bottom = resolve_dimension(parts[2].to_string(), ctx)
          builder.margin_left = resolve_dimension(parts[3].to_string(), ctx)
        }
        _ => ()
      }
    }
    "margin-top" => builder.margin_top = resolve_dimension(value, ctx)
    "margin-right" => builder.margin_right = resolve_dimension(value, ctx)
    "margin-bottom" => builder.margin_bottom = resolve_dimension(value, ctx)
    "margin-left" => builder.margin_left = resolve_dimension(value, ctx)
    "padding-top" => builder.padding_top = resolve_dimension(value, ctx)
    "padding-right" => builder.padding_right = resolve_dimension(value, ctx)
    "padding-bottom" => builder.padding_bottom = resolve_dimension(value, ctx)
    "padding-left" => builder.padding_left = resolve_dimension(value, ctx)
    "border-top-width" => builder.border_top = resolve_dimension(value, ctx)
    "border-right-width" => builder.border_right = resolve_dimension(value, ctx)
    "border-bottom-width" =>
      builder.border_bottom = resolve_dimension(value, ctx)
    "border-left-width" => builder.border_left = resolve_dimension(value, ctx)
    // Flexbox container
    "flex-direction" => builder.flex_direction = parse_flex_direction(value)
    "flex-wrap" => builder.flex_wrap = parse_flex_wrap(value)
    "justify-content" => builder.justify_content = parse_alignment(value)
    "align-items" => builder.align_items = parse_alignment(value)
    "align-content" => builder.align_content = parse_alignment(value)
    // Flexbox item
    "align-self" => builder.align_self = parse_align_self(value)
    "flex-grow" => {
      let v = parse_number(value)
      if v >= 0.0 {
        builder.flex_grow = v
      }
    }
    "flex-shrink" => {
      let v = parse_number(value)
      if v >= 0.0 {
        builder.flex_shrink = v
      }
    }
    "flex-basis" => builder.flex_basis = resolve_dimension(value, ctx)
    "order" => builder.order = parse_integer(value)
    "flex" => {
      // Parse flex shorthand: none | auto | <flex-grow> [<flex-shrink>] [<flex-basis>]
      // Order must be: numbers first (grow, shrink), then optionally basis
      // Invalid orders like "1 0% 1" (basis in middle) must be rejected
      let v = value.trim()
      if v == "none" {
        builder.flex_grow = 0.0
        builder.flex_shrink = 0.0
        builder.flex_basis = @types.Dimension::Auto
      } else if v == "auto" {
        builder.flex_grow = 1.0
        builder.flex_shrink = 1.0
        builder.flex_basis = @types.Dimension::Auto
      } else if v == "initial" {
        builder.flex_grow = 0.0
        builder.flex_shrink = 1.0
        builder.flex_basis = @types.Dimension::Auto
      } else {
        // Try to parse as number(s) and optionally a basis
        let parts : Array[StringView] = v
          .split(" ")
          .filter(fn(s) { not(s.is_empty()) })
          .collect()
        // Validate ordering: numbers first, then basis
        // A value is a "number" if it's purely numeric (no % or units)
        // A value is a "basis" if it has %, px, or is "auto"/"content"
        let mut num_count = 0
        let mut basis_found = false
        let mut valid = true
        for i = 0; i < parts.length(); i = i + 1 {
          let p = parts[i].to_string()
          if is_flex_basis_value(p) {
            if basis_found {
              // Second basis value is invalid
              valid = false
            }
            basis_found = true
          } else if is_pure_number(p) {
            if basis_found {
              // Number after basis is invalid (e.g., "1 0% 1")
              valid = false
            }
            num_count = num_count + 1
          } else {
            // Unknown token
            valid = false
          }
        }
        if valid {
          match parts.length() {
            1 =>
              if num_count == 1 {
                // flex: <number> = <number> 1 0
                builder.flex_grow = parse_number(parts[0].to_string())
                builder.flex_shrink = 1.0
                builder.flex_basis = @types.Dimension::Length(0.0)
              } else if basis_found {
                // flex: <basis> = 1 1 <basis>
                builder.flex_grow = 1.0
                builder.flex_shrink = 1.0
                builder.flex_basis = resolve_dimension(
                  parts[0].to_string(),
                  ctx,
                )
              }
            2 =>
              if num_count == 2 {
                // flex: <grow> <shrink> = <grow> <shrink> 0
                builder.flex_grow = parse_number(parts[0].to_string())
                builder.flex_shrink = parse_number(parts[1].to_string())
                builder.flex_basis = @types.Dimension::Length(0.0)
              } else if num_count == 1 && basis_found {
                // flex: <grow> <basis>
                builder.flex_grow = parse_number(parts[0].to_string())
                builder.flex_shrink = 1.0
                builder.flex_basis = resolve_dimension(
                  parts[1].to_string(),
                  ctx,
                )
              }
            3 =>
              if num_count == 2 && basis_found {
                // flex: <grow> <shrink> <basis>
                builder.flex_grow = parse_number(parts[0].to_string())
                builder.flex_shrink = parse_number(parts[1].to_string())
                builder.flex_basis = resolve_dimension(
                  parts[2].to_string(),
                  ctx,
                )
              }
            // If num_count != 2 or basis not at end, it's invalid and we do nothing
            _ => ()
          }
        }
        // If not valid, we don't modify the builder (keep defaults)
      }
    }
    // flex-flow shorthand: <flex-direction> || <flex-wrap>
    "flex-flow" => {
      let parts : Array[StringView] = value
        .trim()
        .split(" ")
        .filter(fn(s) { not(s.is_empty()) })
        .collect()
      for part in parts {
        let p = part.to_string()
        // Check flex-direction values
        if p == "row" {
          builder.flex_direction = @style.FlexDirection::Row
        } else if p == "row-reverse" {
          builder.flex_direction = @style.FlexDirection::RowReverse
        } else if p == "column" {
          builder.flex_direction = @style.FlexDirection::Column
        } else if p == "column-reverse" {
          builder.flex_direction = @style.FlexDirection::ColumnReverse
          // Check flex-wrap values
        } else if p == "nowrap" {
          builder.flex_wrap = @style.FlexWrap::NoWrap
        } else if p == "wrap" {
          builder.flex_wrap = @style.FlexWrap::Wrap
        } else if p == "wrap-reverse" {
          builder.flex_wrap = @style.FlexWrap::WrapReverse
        }
      }
    }
    // Gap
    "gap" => {
      let dim = resolve_dimension(value, ctx)
      builder.row_gap = dim
      builder.column_gap = dim
    }
    "row-gap" => builder.row_gap = resolve_dimension(value, ctx)
    "column-gap" => builder.column_gap = resolve_dimension(value, ctx)
    // Inset
    "top" => builder.inset_top = resolve_dimension(value, ctx)
    "right" => builder.inset_right = resolve_dimension(value, ctx)
    "bottom" => builder.inset_bottom = resolve_dimension(value, ctx)
    "left" => builder.inset_left = resolve_dimension(value, ctx)
    // Aspect ratio
    "aspect-ratio" => builder.aspect_ratio = parse_aspect_ratio(value)
    // Overflow
    "overflow" => {
      let ov = parse_overflow(value)
      builder.overflow_x = ov
      builder.overflow_y = ov
    }
    "overflow-x" => builder.overflow_x = parse_overflow(value)
    "overflow-y" => builder.overflow_y = parse_overflow(value)
    // Grid container
    "grid-auto-flow" => builder.grid_auto_flow = parse_grid_auto_flow(value)
    "grid-template-columns" =>
      builder.grid_template_columns = parse_grid_template_tracks(value)
    "grid-template-rows" =>
      builder.grid_template_rows = parse_grid_template_tracks(value)
    // Font properties
    "font-size" => builder.font_size = parse_font_size(value, ctx)
    "line-height" =>
      builder.line_height = parse_line_height(value, builder.font_size)
    "font" => {
      // Parse font shorthand: [style] [variant] [weight] size[/line-height] family
      let (fs, lh) = parse_font_shorthand(value, ctx)
      builder.font_size = fs
      builder.line_height = lh
    }
    _ => ()
  }
}

///|
/// Resolve dimension with relative unit conversion
fn resolve_dimension(value : String, ctx : ComputeContext) -> @types.Dimension {
  let v = value.trim()
  if v == "auto" || v == "none" {
    return @types.Dimension::Auto
  }

  // Handle rem units (check before em)
  match v.strip_suffix("rem") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.root_font_size)
    }
    None => ()
  }

  // Handle em units
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.font_size)
    }
    None => ()
  }

  // Handle vw units
  match v.strip_suffix("vw") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.viewport_width / 100.0)
    }
    None => ()
  }

  // Handle vh units
  match v.strip_suffix("vh") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.viewport_height / 100.0)
    }
    None => ()
  }

  // Fall back to simple dimension parsing (px, %)
  parse_dimension(value)
}

///|
/// Check if a string is a pure number (no units)
fn is_pure_number(s : String) -> Bool {
  let v = s.trim()
  if v.is_empty() {
    return false
  }
  // Try to parse as double - will fail if it has units
  let _ = @strconv.parse_double(v.to_string()) catch { _ => return false }
  // Make sure it doesn't have any unit suffixes that parse_double might accept
  for i = 0; i < v.length(); i = i + 1 {
    let c = v[i]
    if not(
        c == '0' ||
        c == '1' ||
        c == '2' ||
        c == '3' ||
        c == '4' ||
        c == '5' ||
        c == '6' ||
        c == '7' ||
        c == '8' ||
        c == '9' ||
        c == '.' ||
        c == '-' ||
        c == '+',
      ) {
      return false
    }
  }
  true
}

///|
/// Check if a string is a flex-basis value (has units, % or is auto/content)
fn is_flex_basis_value(s : String) -> Bool {
  let v = s.trim().to_lower()
  if v == "auto" || v == "content" {
    return true
  }
  // Check for common dimension suffixes
  v.has_suffix("%") ||
  v.has_suffix("px") ||
  v.has_suffix("em") ||
  v.has_suffix("rem") ||
  v.has_suffix("vw") ||
  v.has_suffix("vh")
}

///|
/// Apply inheritance for inherited properties not in cascaded values
fn apply_inheritance(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  // List of inherited properties we support
  let inherited_props = [
    "direction", "writing-mode", "text-align", "line-height", "font-size", "font-family",
    "font-weight", "font-style", "color", "visibility",
  ]
  for prop in inherited_props {
    // If property not in cascaded values, inherit from parent
    if not(cascaded.has(prop)) {
      match ctx.parent_style {
        Some(parent) => {
          let value = get_style_value_as_string(prop, parent)
          apply_property(builder, prop, value, ctx)
        }
        None => ()
      }
    }
  }
}

///|
/// Compute style from inline style string
pub fn compute_inline(
  inline_css : String,
  ctx : ComputeContext,
) -> @style.Style {
  // Parse inline style to declarations
  let decls : Array[@cascade.Declaration] = []
  // Simple parsing: split by semicolon
  let pairs = inline_css.split(";")
  let mut order = 0
  for pair in pairs {
    let pair_str = pair.to_string().trim()
    if pair_str.is_empty() {
      continue
    }
    // Find colon
    let mut colon_pos = -1
    for i = 0; i < pair_str.length(); i = i + 1 {
      if pair_str[i].to_int().unsafe_to_char() == ':' {
        colon_pos = i
        break
      }
    }
    if colon_pos > 0 {
      let prop = pair_str[:colon_pos].to_string().trim() catch { _ => "" }
      let val = pair_str[colon_pos + 1:].to_string().trim() catch { _ => "" }
      if not(prop.is_empty()) && not(val.is_empty()) {
        decls.push(
          @cascade.Declaration::with_metadata(
            prop.to_string(),
            @cascade.PropertyValue::Value(val.to_string()),
            @cascade.Origin::Author,
            @cascade.Importance::Normal,
            { a: 1000, b: 0, c: 0 },
            order,
          ),
        )
        order += 1
      }
    }
  }

  // Cascade
  let cascaded = @cascade.cascade(decls)

  // Compute
  compute(cascaded, ctx)
}

///|
/// Parse font-size value and return computed value in pixels
fn parse_font_size(value : String, ctx : ComputeContext) -> Double {
  let v = value.trim()

  // Handle em units (relative to parent font-size)
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch { _ => 1.0 }
      return n * ctx.font_size
    }
    None => ()
  }

  // Handle rem units (relative to root font-size)
  match v.strip_suffix("rem") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch { _ => 1.0 }
      return n * ctx.root_font_size
    }
    None => ()
  }

  // Handle px units
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return ctx.font_size
      }
      return n
    }
    None => ()
  }

  // Handle pt units (1pt = 1.333px)
  match v.strip_suffix("pt") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return ctx.font_size
      }
      return n * 1.333
    }
    None => ()
  }

  // Handle percent (relative to parent font-size)
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return ctx.font_size
      }
      return n / 100.0 * ctx.font_size
    }
    None => ()
  }

  // Handle keyword values
  match v {
    "xx-small" => 9.0
    "x-small" => 10.0
    "small" => 13.0
    "medium" => 16.0
    "large" => 18.0
    "x-large" => 24.0
    "xx-large" => 32.0
    "smaller" => ctx.font_size * 0.833
    "larger" => ctx.font_size * 1.2
    _ => ctx.font_size // Default to inherited font-size
  }
}

///|
/// Parse line-height value and return computed value in pixels
fn parse_line_height(value : String, font_size : Double) -> Double {
  let v = value.trim()

  // Handle unitless number (multiplier of font-size)
  // Check if it's a pure number
  let is_pure_number = {
    let mut pure = true
    for i = 0; i < v.length(); i = i + 1 {
      let c = v[i].to_int().unsafe_to_char()
      if c != '.' && not(c >= '0' && c <= '9') {
        pure = false
        break
      }
    }
    pure
  }
  if is_pure_number && not(v.is_empty()) {
    let n = @strconv.parse_double(v.to_string()) catch { _ => 1.0 }
    return n * font_size
  }

  // Handle px units
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return font_size
      }
      return n
    }
    None => ()
  }

  // Handle em units
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return font_size
      }
      return n * font_size
    }
    None => ()
  }

  // Handle percent (relative to font-size)
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return font_size
      }
      return n / 100.0 * font_size
    }
    None => ()
  }

  // "normal" = 1.2 * font-size typically
  if v == "normal" {
    return font_size * 1.2
  }

  // Default to font-size
  font_size
}

///|
/// Parse font shorthand and extract font-size and line-height
/// Supports: [style] [variant] [weight] size[/line-height] family
fn parse_font_shorthand(
  value : String,
  ctx : ComputeContext,
) -> (Double, Double) {
  let v = value.trim()

  // Split by whitespace
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  let mut in_quotes = false
  for c in v.iter() {
    if c == '"' || c == '\'' {
      in_quotes = not(in_quotes)
      current.write_char(c)
    } else if (c == ' ' || c == '\t') && not(in_quotes) {
      let s = current.to_string()
      if s.length() > 0 {
        parts.push(s)
      }
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  let s = current.to_string()
  if s.length() > 0 {
    parts.push(s)
  }

  // Find the part with font-size (and optional /line-height)
  // Font-size is required and comes before font-family
  // Look for a part that starts with a digit or contains 'px', 'em', 'rem', '%'
  let mut font_size = ctx.font_size
  let mut line_height = ctx.font_size
  for part in parts {
    // Check if this part contains size/line-height
    if part.contains("/") {
      // Split by /
      let mut slash_idx = -1
      for i = 0; i < part.length(); i = i + 1 {
        if part[i] == '/' {
          slash_idx = i
          break
        }
      }
      if slash_idx > 0 {
        try {
          let size_part = part[:slash_idx].to_string()
          let lh_part = part[slash_idx + 1:].to_string()
          font_size = parse_font_size(size_part, ctx)
          line_height = parse_line_height(lh_part, font_size)
          break
        } catch {
          _ => ()
        }
      }
    } else {
      // Check if it's a size value (starts with digit or contains unit)
      let first_char = if part.length() > 0 { part[0] } else { ' ' }
      if first_char >= '0' && first_char <= '9' {
        font_size = parse_font_size(part, ctx)
        line_height = font_size // Default line-height = font-size (ratio 1)
        break
      }
    }
  }
  (font_size, line_height)
}
