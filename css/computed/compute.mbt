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
pub fn ComputeContext::with_viewport(viewport_width : Double, viewport_height : Double) -> ComputeContext {
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
  mut row_gap : @types.Dimension
  mut column_gap : @types.Dimension
  mut aspect_ratio : Double?
  mut inset_top : @types.Dimension
  mut inset_right : @types.Dimension
  mut inset_bottom : @types.Dimension
  mut inset_left : @types.Dimension
  mut grid_auto_flow : @style.GridAutoFlow
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
    row_gap: @types.Dimension::Length(0.0),
    column_gap: @types.Dimension::Length(0.0),
    aspect_ratio: None,
    inset_top: @types.Dimension::Auto,
    inset_right: @types.Dimension::Auto,
    inset_bottom: @types.Dimension::Auto,
    inset_left: @types.Dimension::Auto,
    grid_auto_flow: @style.GridAutoFlow::Row,
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
    row_gap: self.row_gap,
    column_gap: self.column_gap,
    aspect_ratio: self.aspect_ratio,
    inset: {
      top: self.inset_top,
      right: self.inset_right,
      bottom: self.inset_bottom,
      left: self.inset_left,
    },
    grid_template_rows: [],
    grid_template_columns: [],
    grid_auto_rows: [],
    grid_auto_columns: [],
    grid_auto_flow: self.grid_auto_flow,
    grid_template_areas: [],
    grid_row: @style.GridLine::auto(),
    grid_column: @style.GridLine::auto(),
    grid_area: None,
    justify_items: @style.Alignment::Stretch,
    justify_self: @style.AlignSelf::Auto,
  }
}

///|
/// Resolve a CSS keyword value to actual value
fn resolve_keyword(
  property : String,
  value : @cascade.PropertyValue,
  ctx : ComputeContext
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
        @style.Display::Grid => "grid"
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
  ctx : ComputeContext
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
  ctx : ComputeContext
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
    "flex-grow" => builder.flex_grow = parse_number(value)
    "flex-shrink" => builder.flex_shrink = parse_number(value)
    "flex-basis" => builder.flex_basis = resolve_dimension(value, ctx)
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
      let n = try { @strconv.parse_double(num_str.to_string()) } catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.root_font_size)
    }
    None => ()
  }

  // Handle em units
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = try { @strconv.parse_double(num_str.to_string()) } catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.font_size)
    }
    None => ()
  }

  // Handle vw units
  match v.strip_suffix("vw") {
    Some(num_str) => {
      let n = try { @strconv.parse_double(num_str.to_string()) } catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.viewport_width / 100.0)
    }
    None => ()
  }

  // Handle vh units
  match v.strip_suffix("vh") {
    Some(num_str) => {
      let n = try { @strconv.parse_double(num_str.to_string()) } catch {
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
/// Apply inheritance for inherited properties not in cascaded values
fn apply_inheritance(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext
) -> Unit {
  // List of inherited properties we support
  let inherited_props = [
    "direction", "writing-mode", "text-align", "line-height", "font-size",
    "font-family", "font-weight", "font-style", "color", "visibility",
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
  ctx : ComputeContext
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
      let prop = try { pair_str[:colon_pos].to_string().trim() } catch {
        _ => ""
      }
      let val = try { pair_str[colon_pos + 1:].to_string().trim() } catch {
        _ => ""
      }
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
