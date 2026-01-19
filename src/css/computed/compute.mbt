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
  /// CSS Custom Properties (variables) - inherited from parent and local
  custom_properties : Map[String, String]
}

///|
pub fn ComputeContext::new() -> ComputeContext {
  {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: {},
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
    custom_properties: {},
  }
}

///|
/// Create context with parent style and inherited custom properties
pub fn ComputeContext::with_parent_and_vars(
  parent : @style.Style,
  parent_vars : Map[String, String],
) -> ComputeContext {
  // Copy parent vars for inheritance (custom properties inherit by default)
  let vars : Map[String, String] = {}
  for k, v in parent_vars {
    vars[k] = v
  }
  {
    parent_style: Some(parent),
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1920.0,
    viewport_height: 1080.0,
    custom_properties: vars,
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
    custom_properties: {},
  }
}

///|
/// Mutable style builder for collecting computed values
priv struct StyleBuilder {
  mut display : @types.Display
  mut position : @types.Position
  mut float : @types.Float
  mut clear : @types.Clear
  mut box_sizing : @types.BoxSizing
  mut overflow_x : @types.Overflow
  mut overflow_y : @types.Overflow
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
  mut flex_direction : @types.FlexDirection
  mut flex_wrap : @types.FlexWrap
  mut justify_content : @types.Alignment
  mut align_items : @types.Alignment
  mut align_content : @types.Alignment
  mut align_self : @types.AlignSelf
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
  mut grid_auto_flow : @types.GridAutoFlow
  mut grid_template_columns : Array[@types.TrackSizingFunction]
  mut grid_template_rows : Array[@types.TrackSizingFunction]
  // Grid item placement
  mut grid_column_start : @types.GridPlacement
  mut grid_column_end : @types.GridPlacement
  mut grid_row_start : @types.GridPlacement
  mut grid_row_end : @types.GridPlacement
  // Font properties
  mut font_size : Double
  mut line_height : Double
  // Vertical alignment for inline elements
  mut vertical_align : @style.VerticalAlign
  // Clip (legacy)
  mut clip : @types.ClipRect
  // Paint properties
  mut visibility : @style.Visibility
  mut z_index : @style.ZIndex
  mut opacity : Double
  // Color properties
  mut color : @types.Color
  mut background_color : @types.Color
  // Containment
  mut contain : @style.Contain
  // Transform
  mut transform : @style.Transform
  // Table properties
  mut border_spacing : Double
  mut border_collapse : @style.BorderCollapse
  mut table_layout : @style.TableLayout
  mut caption_side : @style.CaptionSide
  // Table cell properties (not mutable via CSS, set from HTML attributes)
  rowspan : Int
  colspan : Int
}

///|
fn StyleBuilder::new() -> StyleBuilder {
  {
    display: @types.Display::Block,
    position: @types.Position::Static,
    float: @types.Float::None,
    clear: @types.Clear::None,
    box_sizing: @types.BoxSizing::ContentBox,
    overflow_x: @types.Overflow::Visible,
    overflow_y: @types.Overflow::Visible,
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
    flex_direction: @types.FlexDirection::Row,
    flex_wrap: @types.FlexWrap::NoWrap,
    justify_content: @types.Alignment::Start,
    align_items: @types.Alignment::Stretch,
    align_content: @types.Alignment::Stretch,
    align_self: @types.AlignSelf::Auto,
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
    grid_auto_flow: @types.GridAutoFlow::Row,
    grid_template_columns: [],
    grid_template_rows: [],
    grid_column_start: @types.GridPlacement::Auto,
    grid_column_end: @types.GridPlacement::Auto,
    grid_row_start: @types.GridPlacement::Auto,
    grid_row_end: @types.GridPlacement::Auto,
    font_size: 16.0,
    line_height: 16.0,
    vertical_align: @style.VerticalAlign::Baseline,
    clip: @types.ClipRect::Auto,
    visibility: @style.Visibility::Visible,
    z_index: @style.ZIndex::Auto,
    opacity: 1.0,
    color: @types.Color::black(),
    background_color: @types.Color::transparent(),
    contain: @style.Contain::none(),
    transform: @style.Transform::none(),
    border_spacing: 0.0,
    border_collapse: @style.BorderCollapse::Separate,
    table_layout: @style.TableLayout::Auto,
    caption_side: @style.CaptionSide::Top,
    rowspan: 1,
    colspan: 1,
  }
}

///|
/// Create a StyleBuilder from an existing Style
fn StyleBuilder::from_style(style : @style.Style) -> StyleBuilder {
  {
    display: style.display,
    position: style.position,
    float: style.float,
    clear: style.clear,
    box_sizing: style.box_sizing,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    width: style.width,
    height: style.height,
    min_width: style.min_width,
    min_height: style.min_height,
    max_width: style.max_width,
    max_height: style.max_height,
    margin_top: style.margin.top,
    margin_right: style.margin.right,
    margin_bottom: style.margin.bottom,
    margin_left: style.margin.left,
    padding_top: style.padding.top,
    padding_right: style.padding.right,
    padding_bottom: style.padding.bottom,
    padding_left: style.padding.left,
    border_top: style.border.top,
    border_right: style.border.right,
    border_bottom: style.border.bottom,
    border_left: style.border.left,
    flex_direction: style.flex_direction,
    flex_wrap: style.flex_wrap,
    justify_content: style.justify_content,
    align_items: style.align_items,
    align_content: style.align_content,
    align_self: style.align_self,
    flex_grow: style.flex_grow,
    flex_shrink: style.flex_shrink,
    flex_basis: style.flex_basis,
    order: style.order,
    row_gap: style.row_gap,
    column_gap: style.column_gap,
    aspect_ratio: style.aspect_ratio,
    inset_top: style.inset.top,
    inset_right: style.inset.right,
    inset_bottom: style.inset.bottom,
    inset_left: style.inset.left,
    grid_auto_flow: style.grid_auto_flow,
    grid_template_columns: style.grid_template_columns,
    grid_template_rows: style.grid_template_rows,
    grid_column_start: style.grid_column.start,
    grid_column_end: style.grid_column.end,
    grid_row_start: style.grid_row.start,
    grid_row_end: style.grid_row.end,
    font_size: style.font_size,
    line_height: style.line_height,
    vertical_align: style.vertical_align,
    clip: style.clip,
    visibility: style.visibility,
    z_index: style.z_index,
    opacity: style.opacity,
    color: style.color,
    background_color: style.background_color,
    contain: style.contain,
    transform: style.transform,
    border_spacing: style.border_spacing,
    border_collapse: style.border_collapse,
    table_layout: style.table_layout,
    caption_side: style.caption_side,
    rowspan: style.rowspan,
    colspan: style.colspan,
  }
}

///|
fn StyleBuilder::build(self : StyleBuilder) -> @style.Style {
  {
    display: self.display,
    position: self.position,
    float: self.float,
    clear: self.clear,
    box_sizing: self.box_sizing,
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
    grid_row: { start: self.grid_row_start, end: self.grid_row_end },
    grid_column: { start: self.grid_column_start, end: self.grid_column_end },
    grid_area: None,
    justify_items: @types.Alignment::Stretch,
    justify_self: @types.AlignSelf::Auto,
    font_size: self.font_size,
    line_height: self.line_height,
    vertical_align: self.vertical_align,
    clip: self.clip,
    visibility: self.visibility,
    z_index: self.z_index,
    opacity: self.opacity,
    color: self.color,
    background_color: self.background_color,
    contain: self.contain,
    transform: self.transform,
    border_spacing: self.border_spacing,
    border_collapse: self.border_collapse,
    table_layout: self.table_layout,
    caption_side: self.caption_side,
    rowspan: self.rowspan,
    colspan: self.colspan,
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
        @types.Display::Block => "block"
        @types.Display::Inline => "inline"
        @types.Display::InlineBlock => "inline-block"
        @types.Display::Flex => "flex"
        @types.Display::InlineFlex => "inline-flex"
        @types.Display::Grid => "grid"
        @types.Display::InlineGrid => "inline-grid"
        @types.Display::Table => "table"
        @types.Display::InlineTable => "inline-table"
        @types.Display::TableRow => "table-row"
        @types.Display::TableCell => "table-cell"
        @types.Display::TableCaption => "table-caption"
        @types.Display::TableRowGroup => "table-row-group"
        @types.Display::TableHeaderGroup => "table-header-group"
        @types.Display::TableFooterGroup => "table-footer-group"
        @types.Display::TableColumn => "table-column"
        @types.Display::TableColumnGroup => "table-column-group"
        @types.Display::None => "none"
        @types.Display::Contents => "contents"
        @types.Display::FlowRoot => "flow-root"
      }
    "position" =>
      match style.position {
        @types.Position::Static => "static"
        @types.Position::Relative => "relative"
        @types.Position::Absolute => "absolute"
        @types.Position::Fixed => "fixed"
      }
    "flex-direction" =>
      match style.flex_direction {
        @types.FlexDirection::Row => "row"
        @types.FlexDirection::RowReverse => "row-reverse"
        @types.FlexDirection::Column => "column"
        @types.FlexDirection::ColumnReverse => "column-reverse"
      }
    "flex-wrap" =>
      match style.flex_wrap {
        @types.FlexWrap::NoWrap => "nowrap"
        @types.FlexWrap::Wrap => "wrap"
        @types.FlexWrap::WrapReverse => "wrap-reverse"
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
    "color" => style.color.to_hex()
    "background-color" => style.background_color.to_hex()
    "caption-side" =>
      match style.caption_side {
        @style.CaptionSide::Top => "top"
        @style.CaptionSide::Bottom => "bottom"
      }
    "border-collapse" =>
      match style.border_collapse {
        @style.BorderCollapse::Separate => "separate"
        @style.BorderCollapse::Collapse => "collapse"
      }
    "border-spacing" => style.border_spacing.to_string() + "px"
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
    @types.Dimension::MinContent => "min-content"
    @types.Dimension::MaxContent => "max-content"
    @types.Dimension::FitContent(n) => "fit-content(" + n.to_string() + "px)"
  }
}

///|
/// Compute a Style from cascaded values
pub fn compute(
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> @style.Style {
  let builder = StyleBuilder::new()

  // First pass: collect custom properties (--*)
  // Custom properties are stored in the context for var() resolution
  let props = cascaded.properties()
  for prop in props {
    if prop.has_prefix("--") {
      match cascaded.get(prop) {
        Some(decl) => {
          let value = resolve_keyword(prop, decl.value, ctx)
          // Store custom property in context
          ctx.custom_properties[prop] = value
        }
        None => ()
      }
    }
  }

  // Second pass: apply regular properties with var() resolution
  for prop in props {
    if not(prop.has_prefix("--")) {
      match cascaded.get(prop) {
        Some(decl) => {
          let value = resolve_keyword(prop, decl.value, ctx)
          apply_property(builder, prop, value, ctx)
        }
        None => ()
      }
    }
  }

  // Handle inheritance for inherited properties
  apply_inheritance(builder, cascaded, ctx)
  builder.build()
}

///|
/// Compute a Style and return updated custom properties
/// Used when building a style tree to pass custom properties to children
pub fn compute_with_vars(
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> (@style.Style, Map[String, String]) {
  let builder = StyleBuilder::new()

  // First pass: collect custom properties (--*)
  let props = cascaded.properties()
  for prop in props {
    if prop.has_prefix("--") {
      match cascaded.get(prop) {
        Some(decl) => {
          let value = resolve_keyword(prop, decl.value, ctx)
          ctx.custom_properties[prop] = value
        }
        None => ()
      }
    }
  }

  // Second pass: apply regular properties
  for prop in props {
    if not(prop.has_prefix("--")) {
      match cascaded.get(prop) {
        Some(decl) => {
          let value = resolve_keyword(prop, decl.value, ctx)
          apply_property(builder, prop, value, ctx)
        }
        None => ()
      }
    }
  }

  // Handle inheritance
  apply_inheritance(builder, cascaded, ctx)

  // Return both the style and the custom properties for children
  (builder.build(), ctx.custom_properties)
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
    "box-sizing" =>
      builder.box_sizing = match value.trim().to_lower() {
        "border-box" => @types.BoxSizing::BorderBox
        "content-box" | "initial" | "inherit" => @types.BoxSizing::ContentBox
        _ => @types.BoxSizing::ContentBox
      }
    // Sizing
    "width" => builder.width = resolve_dimension(value, ctx)
    "height" => builder.height = resolve_dimension(value, ctx)
    "min-width" => builder.min_width = resolve_dimension(value, ctx)
    "min-height" => builder.min_height = resolve_dimension(value, ctx)
    "max-width" => builder.max_width = resolve_dimension(value, ctx)
    "max-height" => builder.max_height = resolve_dimension(value, ctx)
    // Logical sizing properties (horizontal-tb writing mode only)
    // inline-size -> width, block-size -> height
    "inline-size" => builder.width = resolve_dimension(value, ctx)
    "block-size" => builder.height = resolve_dimension(value, ctx)
    "min-inline-size" => builder.min_width = resolve_dimension(value, ctx)
    "min-block-size" => builder.min_height = resolve_dimension(value, ctx)
    "max-inline-size" => builder.max_width = resolve_dimension(value, ctx)
    "max-block-size" => builder.max_height = resolve_dimension(value, ctx)
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
    // Logical margin properties (LTR horizontal-tb writing mode)
    "margin-inline" => {
      let dim = resolve_dimension(value, ctx)
      builder.margin_left = dim
      builder.margin_right = dim
    }
    "margin-inline-start" => builder.margin_left = resolve_dimension(value, ctx)
    "margin-inline-end" => builder.margin_right = resolve_dimension(value, ctx)
    "margin-block" => {
      let dim = resolve_dimension(value, ctx)
      builder.margin_top = dim
      builder.margin_bottom = dim
    }
    "margin-block-start" => builder.margin_top = resolve_dimension(value, ctx)
    "margin-block-end" => builder.margin_bottom = resolve_dimension(value, ctx)
    "padding-top" => builder.padding_top = resolve_dimension(value, ctx)
    "padding-right" => builder.padding_right = resolve_dimension(value, ctx)
    "padding-bottom" => builder.padding_bottom = resolve_dimension(value, ctx)
    "padding-left" => builder.padding_left = resolve_dimension(value, ctx)
    "padding" => {
      // Shorthand: padding (1, 2, 3, or 4 values)
      let parts = value.trim().to_string().split(" ")
      let values : Array[@types.Dimension] = []
      for part in parts {
        let p = part.to_string().trim().to_string()
        if not(p.is_empty()) {
          values.push(resolve_dimension(p, ctx))
        }
      }
      match values.length() {
        1 => {
          builder.padding_top = values[0]
          builder.padding_right = values[0]
          builder.padding_bottom = values[0]
          builder.padding_left = values[0]
        }
        2 => {
          builder.padding_top = values[0]
          builder.padding_right = values[1]
          builder.padding_bottom = values[0]
          builder.padding_left = values[1]
        }
        3 => {
          builder.padding_top = values[0]
          builder.padding_right = values[1]
          builder.padding_bottom = values[2]
          builder.padding_left = values[1]
        }
        _ =>
          // 4 or more values
          if values.length() >= 4 {
            builder.padding_top = values[0]
            builder.padding_right = values[1]
            builder.padding_bottom = values[2]
            builder.padding_left = values[3]
          }
      }
    }
    // Logical padding properties (block/inline)
    "padding-block" => {
      let dim = resolve_dimension(value, ctx)
      builder.padding_top = dim
      builder.padding_bottom = dim
    }
    "padding-block-start" => builder.padding_top = resolve_dimension(value, ctx)
    "padding-block-end" =>
      builder.padding_bottom = resolve_dimension(value, ctx)
    "padding-inline" => {
      let dim = resolve_dimension(value, ctx)
      builder.padding_left = dim
      builder.padding_right = dim
    }
    "padding-inline-start" =>
      builder.padding_left = resolve_dimension(value, ctx)
    "padding-inline-end" =>
      builder.padding_right = resolve_dimension(value, ctx)
    "border-width" => {
      // Shorthand: border-width (1, 2, 3, or 4 values)
      let parts = value.trim().to_string().split(" ")
      let values : Array[@types.Dimension] = []
      for part in parts {
        let p = part.to_string().trim().to_string()
        if not(p.is_empty()) {
          values.push(resolve_dimension(p, ctx))
        }
      }
      if values.length() == 1 {
        // All sides
        builder.border_top = values[0]
        builder.border_right = values[0]
        builder.border_bottom = values[0]
        builder.border_left = values[0]
      } else if values.length() == 2 {
        // top/bottom, left/right
        builder.border_top = values[0]
        builder.border_bottom = values[0]
        builder.border_right = values[1]
        builder.border_left = values[1]
      } else if values.length() == 3 {
        // top, left/right, bottom
        builder.border_top = values[0]
        builder.border_right = values[1]
        builder.border_left = values[1]
        builder.border_bottom = values[2]
      } else if values.length() >= 4 {
        // top, right, bottom, left
        builder.border_top = values[0]
        builder.border_right = values[1]
        builder.border_bottom = values[2]
        builder.border_left = values[3]
      }
    }
    "border" => {
      // Shorthand: border: [width] [style] [color]
      // Extract width value from the shorthand (e.g., "solid 3px", "1px solid red")
      let width = extract_border_width(value)
      builder.border_top = width
      builder.border_right = width
      builder.border_bottom = width
      builder.border_left = width
    }
    "border-top" => builder.border_top = extract_border_width(value)
    "border-right" => builder.border_right = extract_border_width(value)
    "border-bottom" => builder.border_bottom = extract_border_width(value)
    "border-left" => builder.border_left = extract_border_width(value)
    "border-top-width" => builder.border_top = resolve_dimension(value, ctx)
    "border-right-width" => builder.border_right = resolve_dimension(value, ctx)
    "border-bottom-width" =>
      builder.border_bottom = resolve_dimension(value, ctx)
    "border-left-width" => builder.border_left = resolve_dimension(value, ctx)
    // Logical border properties (block/inline)
    "border-block" | "border-block-width" => {
      let width = extract_border_width(value)
      builder.border_top = width
      builder.border_bottom = width
    }
    "border-block-start" | "border-block-start-width" =>
      builder.border_top = extract_border_width(value)
    "border-block-end" | "border-block-end-width" =>
      builder.border_bottom = extract_border_width(value)
    "border-inline" | "border-inline-width" => {
      let width = extract_border_width(value)
      builder.border_left = width
      builder.border_right = width
    }
    "border-inline-start" | "border-inline-start-width" =>
      builder.border_left = extract_border_width(value)
    "border-inline-end" | "border-inline-end-width" =>
      builder.border_right = extract_border_width(value)
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
    "flex-basis" => {
      // CSS spec: negative values are invalid, keep as auto
      let dim = resolve_dimension(value, ctx)
      match dim {
        @types.Length(v) => if v >= 0.0 { builder.flex_basis = dim }
        @types.Percent(v) => if v >= 0.0 { builder.flex_basis = dim }
        @types.Auto => builder.flex_basis = dim
        @types.MinContent => builder.flex_basis = dim
        @types.MaxContent => builder.flex_basis = dim
        @types.FitContent(_) => builder.flex_basis = dim
      }
    }
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
          builder.flex_direction = @types.FlexDirection::Row
        } else if p == "row-reverse" {
          builder.flex_direction = @types.FlexDirection::RowReverse
        } else if p == "column" {
          builder.flex_direction = @types.FlexDirection::Column
        } else if p == "column-reverse" {
          builder.flex_direction = @types.FlexDirection::ColumnReverse
          // Check flex-wrap values
        } else if p == "nowrap" {
          builder.flex_wrap = @types.FlexWrap::NoWrap
        } else if p == "wrap" {
          builder.flex_wrap = @types.FlexWrap::Wrap
        } else if p == "wrap-reverse" {
          builder.flex_wrap = @types.FlexWrap::WrapReverse
        }
      }
    }
    // Gap (grid-gap is legacy alias)
    "gap" | "grid-gap" => {
      let dim = resolve_dimension(value, ctx)
      builder.row_gap = dim
      builder.column_gap = dim
    }
    "row-gap" | "grid-row-gap" =>
      builder.row_gap = resolve_dimension(value, ctx)
    "column-gap" | "grid-column-gap" =>
      builder.column_gap = resolve_dimension(value, ctx)
    // Inset
    "top" => builder.inset_top = resolve_dimension(value, ctx)
    "right" => builder.inset_right = resolve_dimension(value, ctx)
    "bottom" => builder.inset_bottom = resolve_dimension(value, ctx)
    "left" => builder.inset_left = resolve_dimension(value, ctx)
    "inset" => {
      let dim = resolve_dimension(value, ctx)
      builder.inset_top = dim
      builder.inset_right = dim
      builder.inset_bottom = dim
      builder.inset_left = dim
    }
    // Logical inset properties (LTR horizontal-tb writing mode)
    "inset-inline" => {
      let dim = resolve_dimension(value, ctx)
      builder.inset_left = dim
      builder.inset_right = dim
    }
    "inset-inline-start" => builder.inset_left = resolve_dimension(value, ctx)
    "inset-inline-end" => builder.inset_right = resolve_dimension(value, ctx)
    "inset-block" => {
      let dim = resolve_dimension(value, ctx)
      builder.inset_top = dim
      builder.inset_bottom = dim
    }
    "inset-block-start" => builder.inset_top = resolve_dimension(value, ctx)
    "inset-block-end" => builder.inset_bottom = resolve_dimension(value, ctx)
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
    // Grid item placement
    "grid-column-start" =>
      builder.grid_column_start = parse_grid_placement(value)
    "grid-column-end" => builder.grid_column_end = parse_grid_placement(value)
    "grid-row-start" => builder.grid_row_start = parse_grid_placement(value)
    "grid-row-end" => builder.grid_row_end = parse_grid_placement(value)
    "grid-column" => {
      let (start, end) = parse_grid_line_shorthand(value)
      builder.grid_column_start = start
      builder.grid_column_end = end
    }
    "grid-row" => {
      let (start, end) = parse_grid_line_shorthand(value)
      builder.grid_row_start = start
      builder.grid_row_end = end
    }
    // Font properties
    "font-size" => builder.font_size = parse_font_size(value, ctx)
    "line-height" =>
      builder.line_height = parse_line_height(value, builder.font_size)
    "vertical-align" => builder.vertical_align = parse_vertical_align(value)
    "font" => {
      // Parse font shorthand: [style] [variant] [weight] size[/line-height] family
      let (fs, lh) = parse_font_shorthand(value, ctx)
      builder.font_size = fs
      builder.line_height = lh
    }
    // CSS Containment
    "contain" => builder.contain = parse_contain(value)
    // Clip (legacy, deprecated but widely used for a11y)
    "clip" => builder.clip = parse_clip(value)
    // Paint properties (visual, not layout)
    "visibility" => builder.visibility = parse_visibility(value)
    "z-index" => builder.z_index = parse_z_index(value)
    "opacity" => builder.opacity = parse_opacity(value)
    // Color properties
    "color" => {
      let parsed = parse_color_with_ctx(value, ctx)
      match parsed {
        Resolved(c) => builder.color = c
        CurrentColor =>
          // currentColor for 'color' property inherits from parent
          match ctx.parent_style {
            Some(parent) => builder.color = parent.color
            None => () // Keep default (black)
          }
        Inherit =>
          match ctx.parent_style {
            Some(parent) => builder.color = parent.color
            None => ()
          }
      }
    }
    "background-color" | "background" => {
      // For background shorthand, we only extract the color part
      let parsed = parse_color_with_ctx(value, ctx)
      match parsed {
        Resolved(c) => builder.background_color = c
        CurrentColor =>
          // currentColor uses the element's computed color
          builder.background_color = builder.color
        Inherit =>
          match ctx.parent_style {
            Some(parent) => builder.background_color = parent.background_color
            None => ()
          }
      }
    }
    // Transform (visual position offset)
    "transform" => builder.transform = parse_transform(value)
    // Table properties
    "border-spacing" =>
      builder.border_spacing = parse_border_spacing(value, ctx)
    "border-collapse" => builder.border_collapse = parse_border_collapse(value)
    "table-layout" => builder.table_layout = parse_table_layout(value)
    "caption-side" => builder.caption_side = parse_caption_side(value)
    _ => ()
  }
}

///|
/// Parse border-collapse value
fn parse_border_collapse(value : String) -> @style.BorderCollapse {
  match value.trim() {
    "collapse" => @style.Collapse
    "separate" => @style.Separate
    _ => @style.Separate
  }
}

///|
/// Parse table-layout value
fn parse_table_layout(value : String) -> @style.TableLayout {
  match value.trim() {
    "fixed" => @style.TableLayout::Fixed
    "auto" => @style.Auto
    _ => @style.Auto
  }
}

///|
/// Parse caption-side value
fn parse_caption_side(value : String) -> @style.CaptionSide {
  match value.trim() {
    "top" => @style.CaptionSide::Top
    "bottom" => @style.CaptionSide::Bottom
    _ => @style.CaptionSide::Top
  }
}

///|
/// Parse border-spacing value (single value or two values)
fn parse_border_spacing(value : String, ctx : ComputeContext) -> Double {
  let v = value.trim()
  // Split by whitespace
  let parts : Array[StringView] = v
    .split(" ")
    .filter(fn(s) { not(s.is_empty()) })
    .collect()
  // Use first value (or the only value)
  if parts.length() >= 1 {
    let dim = resolve_dimension(parts[0].to_string(), ctx)
    match dim {
      @types.Length(px) => return px
      _ => return 0.0
    }
  }
  0.0
}

///|
/// Parse a value inside CSS math functions and resolve it to a dimension
/// Handles recursively nested calc(), min(), max(), clamp()
fn parse_css_value_to_px(value : String, ctx : ComputeContext) -> Double? {
  let v = value.trim()
  if v.is_empty() {
    return None
  }

  // Handle nested calc()
  if v.has_prefix("calc(") && v.has_suffix(")") {
    let inner = v[5:v.length() - 1].to_string() catch { _ => return None }
    return parse_simple_calc_expr(inner, ctx)
  }

  // Handle nested min()
  if v.has_prefix("min(") && v.has_suffix(")") {
    let inner = v[4:v.length() - 1].to_string() catch { _ => return None }
    let args = split_css_args(inner)
    let mut min_val : Double? = None
    for arg in args {
      match parse_css_value_to_px(arg, ctx) {
        Some(val) =>
          match min_val {
            None => min_val = Some(val)
            Some(current) => if val < current { min_val = Some(val) }
          }
        None => return None
      }
    }
    return min_val
  }

  // Handle nested max()
  if v.has_prefix("max(") && v.has_suffix(")") {
    let inner = v[4:v.length() - 1].to_string() catch { _ => return None }
    let args = split_css_args(inner)
    let mut max_val : Double? = None
    for arg in args {
      match parse_css_value_to_px(arg, ctx) {
        Some(val) =>
          match max_val {
            None => max_val = Some(val)
            Some(current) => if val > current { max_val = Some(val) }
          }
        None => return None
      }
    }
    return max_val
  }

  // Handle nested clamp()
  if v.has_prefix("clamp(") && v.has_suffix(")") {
    let inner = v[6:v.length() - 1].to_string() catch { _ => return None }
    let args = split_css_args(inner)
    if args.length() != 3 {
      return None
    }
    let min_px = parse_css_value_to_px(args[0], ctx)
    let val_px = parse_css_value_to_px(args[1], ctx)
    let max_px = parse_css_value_to_px(args[2], ctx)
    match (min_px, val_px, max_px) {
      (Some(min_v), Some(val_v), Some(max_v)) => {
        // clamp(min, val, max) = max(min, min(val, max))
        let clamped = if val_v < min_v {
          min_v
        } else if val_v > max_v {
          max_v
        } else {
          val_v
        }
        return Some(clamped)
      }
      _ => return None
    }
  }

  // Parse simple dimension value
  let dim = resolve_dimension(v.to_string(), ctx)
  match dim {
    @types.Length(px) => Some(px)
    @types.Percent(_) => None // Cannot simplify percentages
    @types.Auto => None
    @types.MinContent => None
    @types.MaxContent => None
    @types.FitContent(_) => None
  }
}

///|
/// Split CSS function arguments by comma (handling nested parentheses)
fn split_css_args(input : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = StringBuilder::new()
  let mut paren_depth = 0
  for i = 0; i < input.length(); i = i + 1 {
    let c = input[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
      current.write_char(c)
    } else if c == ')' {
      paren_depth -= 1
      current.write_char(c)
    } else if c == ',' && paren_depth == 0 {
      let s = current.to_string().trim().to_string()
      if not(s.is_empty()) {
        result.push(s)
      }
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  let s = current.to_string().trim().to_string()
  if not(s.is_empty()) {
    result.push(s)
  }
  result
}

///|
/// Parse a simple calc expression (handles + - * / with px values)
fn parse_simple_calc_expr(expr : String, ctx : ComputeContext) -> Double? {
  let mut result : Double = 0.0
  let mut current_op : Char = '+'
  let mut i = 0
  let mut token_start = 0
  while i <= expr.length() {
    let c = if i < expr.length() {
      expr[i].to_int().unsafe_to_char()
    } else {
      ' '
    }
    if c == '+' || c == '-' || c == '*' || c == '/' || i == expr.length() {
      if i > token_start {
        let token = expr[token_start:i].to_string().trim() catch { _ => "" }
        if not(token.is_empty()) {
          match parse_css_value_to_px(token.to_string(), ctx) {
            Some(val) =>
              match current_op {
                '+' => result = result + val
                '-' => result = result - val
                '*' => result = result * val
                '/' => result = result / val
                _ => ()
              }
            None => {
              // Try parsing as unitless number for * and /
              let n = @strconv.parse_double(token.to_string()) catch {
                _ => return None
              }
              match current_op {
                '*' => result = result * n
                '/' => result = result / n
                '+' | '-' =>
                  // Unitless number for + or - is invalid unless 0
                  if n != 0.0 {
                    return None
                  }
                _ => ()
              }
            }
          }
        }
      }
      if i < expr.length() {
        current_op = c
      }
      token_start = i + 1
    }
    i = i + 1
  }
  Some(result)
}

///|
/// Parse min(), max(), clamp() CSS functions
fn parse_css_math_function(
  expr : String,
  ctx : ComputeContext,
) -> @types.Dimension? {
  let v = expr.trim()

  // Handle min()
  if v.has_prefix("min(") && v.has_suffix(")") {
    match parse_css_value_to_px(v.to_string(), ctx) {
      Some(px) => return Some(@types.Length(px))
      None => return None
    }
  }

  // Handle max()
  if v.has_prefix("max(") && v.has_suffix(")") {
    match parse_css_value_to_px(v.to_string(), ctx) {
      Some(px) => return Some(@types.Length(px))
      None => return None
    }
  }

  // Handle clamp()
  if v.has_prefix("clamp(") && v.has_suffix(")") {
    match parse_css_value_to_px(v.to_string(), ctx) {
      Some(px) => return Some(@types.Length(px))
      None => return None
    }
  }
  None
}

///|
/// Parse a calc() expression from a string and try to simplify it
/// Returns Some(dimension) if simplification is possible, None otherwise
fn parse_calc_string(expr : String) -> @types.Dimension? {
  // Extract the expression inside calc(...)
  let v = expr.trim()
  if not(v.has_prefix("calc(")) || not(v.has_suffix(")")) {
    return None
  }
  // Extract content: "calc(" has 5 chars, ")" has 1 char
  let inner = v[5:v.length() - 1].to_string() catch { _ => return None }
  // Parse simple expressions: accumulate px and % values
  let mut result_px : Double = 0.0
  let mut result_pct : Double = 0.0
  let mut current_op : Char = '+'
  // Split by operators while preserving them
  let mut i = 0
  let mut token_start = 0
  while i <= inner.length() {
    let c = if i < inner.length() {
      inner[i].to_int().unsafe_to_char()
    } else {
      ' '
    } // End of string
    if c == '+' || c == '-' || c == '*' || c == '/' || i == inner.length() {
      // Process token before operator
      if i > token_start {
        let token = inner[token_start:i].to_string().trim() catch { _ => "" }
        if not(token.is_empty()) {
          // Parse the token
          if token.has_suffix("%") {
            let num_str = token[:token.length() - 1].to_string() catch {
              _ => ""
            }
            let n = @strconv.parse_double(num_str.to_string()) catch {
              _ => 0.0
            }
            match current_op {
              '+' => result_pct = result_pct + n
              '-' => result_pct = result_pct - n
              '*' => result_pct = result_pct * n
              '/' => result_pct = result_pct / n
              _ => ()
            }
          } else if token.has_suffix("px") {
            let num_str = token[:token.length() - 2].to_string() catch {
              _ => ""
            }
            let n = @strconv.parse_double(num_str.to_string()) catch {
              _ => 0.0
            }
            match current_op {
              '+' => result_px = result_px + n
              '-' => result_px = result_px - n
              '*' => result_px = result_px * n
              '/' => result_px = result_px / n
              _ => ()
            }
          } else {
            // Try as unitless number (treat as px if 0, otherwise skip)
            let n = @strconv.parse_double(token) catch { _ => 0.0 }
            if n == 0.0 {
              // 0 has no effect on the result
              ()
            } else {
              // Non-zero unitless - treat as multiplier for current values if *, /
              match current_op {
                '*' => {
                  result_px = result_px * n
                  result_pct = result_pct * n
                }
                '/' => {
                  result_px = result_px / n
                  result_pct = result_pct / n
                }
                _ => ()
              }
            }
          }
        }
      }
      // Save operator for next token
      if i < inner.length() {
        current_op = c
      }
      token_start = i + 1
    }
    i = i + 1
  }
  // Determine final dimension type
  if result_pct.abs() < 0.0001 {
    // Pure length
    Some(@types.Length(result_px))
  } else if result_px.abs() < 0.0001 {
    // Pure percentage
    Some(@types.Percent(result_pct / 100.0))
  } else {
    // Mixed - cannot simplify
    None
  }
}

///|
/// Resolve CSS var() function with context lookup
/// Looks up variable in context, falls back to provided fallback value if not found
fn resolve_var(value : String, ctx : ComputeContext) -> String {
  let v = value.trim().to_string()
  if not(v.has_prefix("var(")) || not(v.has_suffix(")")) {
    return v
  }
  // Extract content inside var(...) - skip "var(" (4 chars) and ")" (1 char)
  let inner : String = v[4:v.length() - 1].to_string() catch { _ => return v }
  // Find the comma separating variable name from fallback
  // Need to handle nested var() and other functions
  let mut paren_depth = 0
  let mut comma_pos = -1
  for i = 0; i < inner.length(); i = i + 1 {
    let c = inner[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
    } else if c == ')' {
      paren_depth -= 1
    } else if c == ',' && paren_depth == 0 {
      comma_pos = i
      break
    }
  }
  // Extract variable name as String
  let var_name : String = if comma_pos > 0 {
    let slice = inner[:comma_pos].to_string() catch { _ => inner }
    slice.trim().to_string()
  } else {
    inner.trim().to_string()
  }
  // Look up variable in context
  match ctx.custom_properties.get(var_name) {
    Some(var_value) =>
      // Variable found - recursively resolve if it contains var()
      if var_value.contains("var(") {
        resolve_var(var_value, ctx)
      } else {
        var_value
      }
    None =>
      // Variable not found - use fallback if available
      if comma_pos > 0 {
        let fallback_slice = inner[comma_pos + 1:].to_string() catch {
          _ => return ""
        }
        let fallback = fallback_slice.trim().to_string()
        // Recursively resolve fallback (it may also contain var())
        resolve_var(fallback, ctx)
      } else {
        // No fallback and no variable - return empty (invalid value)
        ""
      }
  }
}

///|
/// Resolve all var() references in a value string
fn resolve_all_vars(value : String, ctx : ComputeContext) -> String {
  let v = value.trim()
  // If no var() in value, return as-is
  if not(v.contains("var(")) {
    return v.to_string()
  }
  // Simple case: entire value is a var()
  if v.has_prefix("var(") && v.has_suffix(")") {
    // Check if there's only one var() (no content after)
    let mut depth = 0
    let mut end_pos = 0
    for i = 0; i < v.length(); i = i + 1 {
      let c = v[i].to_int().unsafe_to_char()
      if c == '(' {
        depth += 1
      } else if c == ')' {
        depth -= 1
        if depth == 0 {
          end_pos = i
          break
        }
      }
    }
    if end_pos == v.length() - 1 {
      // Entire value is a single var()
      return resolve_var(v.to_string(), ctx)
    }
  }
  // Complex case: var() embedded in value like "10px var(--gap) 20px"
  // Need to replace each var() with its resolved value
  let result = StringBuilder::new()
  let mut i = 0
  while i < v.length() {
    // Look for "var("
    if i + 4 <= v.length() {
      let substr = v[i:i + 4].to_string() catch { _ => "" }
      if substr == "var(" {
        // Find matching closing paren
        let mut depth = 1
        let mut j = i + 4
        while j < v.length() && depth > 0 {
          let c = v[j].to_int().unsafe_to_char()
          if c == '(' {
            depth += 1
          } else if c == ')' {
            depth -= 1
          }
          j += 1
        }
        // Extract and resolve the var()
        let var_expr = v[i:j].to_string() catch { _ => "" }
        let resolved = resolve_var(var_expr, ctx)
        result.write_string(resolved)
        i = j
        continue
      }
    }
    result.write_char(v[i].to_int().unsafe_to_char())
    i += 1
  }
  result.to_string()
}

///|
/// Resolve dimension with relative unit conversion
fn resolve_dimension(value : String, ctx : ComputeContext) -> @types.Dimension {
  // First resolve any var() functions
  let v = resolve_all_vars(value, ctx).trim()
  if v == "auto" || v == "none" {
    return @types.Dimension::Auto
  }

  // Handle intrinsic sizing keywords
  if v == "min-content" {
    return @types.Dimension::MinContent
  }
  if v == "max-content" {
    return @types.Dimension::MaxContent
  }
  if v == "fit-content" {
    // fit-content without argument is equivalent to fit-content(max-content)
    return @types.Dimension::FitContent(1.0e10)
  }

  // Handle calc() expressions
  if v.has_prefix("calc(") {
    match parse_calc_string(v.to_string()) {
      Some(dim) => return dim
      None => return @types.Dimension::Auto // Fallback for complex calc
    }
  }

  // Handle min(), max(), clamp() CSS math functions
  if v.has_prefix("min(") || v.has_prefix("max(") || v.has_prefix("clamp(") {
    match parse_css_math_function(v.to_string(), ctx) {
      Some(dim) => return dim
      None => return @types.Dimension::Auto // Fallback for complex expressions
    }
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

  // Handle vmin units (smaller of vw or vh)
  match v.strip_suffix("vmin") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      let min_dimension = if ctx.viewport_width < ctx.viewport_height {
        ctx.viewport_width
      } else {
        ctx.viewport_height
      }
      return @types.Dimension::Length(n * min_dimension / 100.0)
    }
    None => ()
  }

  // Handle vmax units (larger of vw or vh)
  match v.strip_suffix("vmax") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      let max_dimension = if ctx.viewport_width > ctx.viewport_height {
        ctx.viewport_width
      } else {
        ctx.viewport_height
      }
      return @types.Dimension::Length(n * max_dimension / 100.0)
    }
    None => ()
  }

  // Handle ch units (width of "0" glyph, approximated as 0.5em)
  match v.strip_suffix("ch") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.font_size * 0.5)
    }
    None => ()
  }

  // Handle ex units (x-height, approximated as 0.5em)
  match v.strip_suffix("ex") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * ctx.font_size * 0.5)
    }
    None => ()
  }

  // Handle pt units (1pt = 1/72 inch = 96/72 px ≈ 1.333px)
  match v.strip_suffix("pt") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * 96.0 / 72.0)
    }
    None => ()
  }

  // Handle pc units (1pc = 12pt = 16px)
  match v.strip_suffix("pc") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * 16.0)
    }
    None => ()
  }

  // Handle in units (1in = 96px)
  match v.strip_suffix("in") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * 96.0)
    }
    None => ()
  }

  // Handle cm units (1cm = 96/2.54 px ≈ 37.795px)
  match v.strip_suffix("cm") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * 96.0 / 2.54)
    }
    None => ()
  }

  // Handle mm units (1mm = 96/25.4 px ≈ 3.7795px)
  match v.strip_suffix("mm") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * 96.0 / 25.4)
    }
    None => ()
  }

  // Handle Q units (1Q = 1/4mm = 96/101.6 px)
  match v.strip_suffix("Q") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n * 96.0 / 101.6)
    }
    None => ()
  }

  // Fall back to simple dimension parsing (px, %)
  parse_dimension(v.to_string())
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
/// Parse CSS transform property
/// Supports translate(x, y), translateX(x), translateY(y)
fn parse_transform(value : String) -> @style.Transform {
  let v = value.trim().to_lower()
  // Handle none
  if v == "none" || v.is_empty() {
    return @style.Transform::none()
  }
  let mut translate_x = @style.TranslateValue::Length(0.0)
  let mut translate_y = @style.TranslateValue::Length(0.0)
  // Parse transform functions
  // We handle each function in sequence
  let chars = v.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    // Skip whitespace
    while i < len && (chars[i] == ' ' || chars[i] == '\t') {
      i = i + 1
    }
    if i >= len {
      break
    }
    // Find function name
    let func_start = i
    while i < len && chars[i] != '(' {
      i = i + 1
    }
    if i >= len {
      break
    }
    let func_name = chars_to_string(chars[func_start:i])
    i = i + 1 // Skip '('
    // Find function arguments (handle nested parens)
    let args_start = i
    let mut paren_depth = 1
    while i < len && paren_depth > 0 {
      if chars[i] == '(' {
        paren_depth = paren_depth + 1
      } else if chars[i] == ')' {
        paren_depth = paren_depth - 1
      }
      i = i + 1
    }
    let args_str = chars_to_string(chars[args_start:i - 1])
    // Parse transform function
    match func_name.trim() {
      "translate" => {
        // translate(x) or translate(x, y)
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      "translatex" => translate_x = parse_translate_value(args_str)
      "translatey" => translate_y = parse_translate_value(args_str)
      "translate3d" => {
        // translate3d(x, y, z) - we only use x and y
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      _ => () // Ignore unsupported functions like rotate, scale, etc.
    }
  }
  { translate_x, translate_y }
}

///|
/// Parse a single translate value (can be length or percentage)
fn parse_translate_value(value : String) -> @style.TranslateValue {
  let v = value.trim()
  if v.is_empty() {
    return @style.TranslateValue::Length(0.0)
  }
  // Check for percentage
  if v.has_suffix("%") {
    let num_str = v[:v.length() - 1].to_string() catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Percent(n / 100.0)
  } else if v.has_suffix("px") {
    let num_str = v[:v.length() - 2].to_string() catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n)
  } else if v.has_suffix("em") || v.has_suffix("rem") {
    // em/rem - convert to pixels assuming 16px base
    let suffix_len = if v.has_suffix("rem") { 3 } else { 2 }
    let num_str = v[:v.length() - suffix_len].to_string() catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n * 16.0)
  } else {
    // Try parsing as plain number (assumed px)
    let n = @strconv.parse_double(v) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n)
  }
}

///|
/// Split string by comma (for transform arguments)
fn split_by_comma(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ',' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string()
  if not(last.is_empty()) {
    result.push(last)
  }
  result
}

///|
/// Convert char array slice to string
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
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
/// Compute style from inline style string (raw, without box-sizing adjustment)
/// Use this when merging individual properties into an existing style.
/// The caller is responsible for calling adjust_for_box_sizing on the final result.
pub fn compute_inline_raw(
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

  // Compute (without box-sizing adjustment)
  compute(cascaded, ctx)
}

///|
/// Compute style from inline style string
/// This is the standard function that applies box-sizing adjustment.
pub fn compute_inline(
  inline_css : String,
  ctx : ComputeContext,
) -> @style.Style {
  let style = compute_inline_raw(inline_css, ctx)
  // Convert content-box dimensions to border-box dimensions
  // The layout engine always works with outer (border-box) dimensions
  adjust_for_box_sizing(style)
}

///|
/// Apply a single CSS property to an existing style directly
/// This skips the CSS string parsing step for better performance
pub fn apply_property_direct(
  style : @style.Style,
  property : String,
  value : String,
  ctx : ComputeContext,
) -> @style.Style {
  // Special handling for font-size: when font-size changes,
  // update line-height proportionally to maintain the ratio
  if property == "font-size" {
    let builder = StyleBuilder::from_style(style)
    let old_fs = style.font_size
    apply_property(builder, property, value, ctx)
    let new_fs = builder.font_size
    // Maintain line-height / font-size ratio
    let lh_ratio = if old_fs > 0.0 { style.line_height / old_fs } else { 1.0 }
    builder.line_height = new_fs * lh_ratio
    return builder.build()
  }
  let builder = StyleBuilder::from_style(style)
  apply_property(builder, property, value, ctx)
  builder.build()
}

///|
/// Adjust dimensions for box-sizing: content-box
/// When box-sizing is content-box (default), specified width/height are content dimensions.
/// The layout engine expects outer dimensions (border-box), so we adjust here.
fn adjust_for_box_sizing(style : @style.Style) -> @style.Style {
  match style.box_sizing {
    @types.BorderBox => style // No adjustment needed
    @types.ContentBox => {
      // Calculate padding and border sums
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)

      // Adjust width and height to include padding+border
      let adjusted_width = match style.width {
        @types.Dimension::Length(w) =>
          @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_height = match style.height {
        @types.Dimension::Length(h) =>
          @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      // Adjust min/max constraints too
      let adjusted_min_width = match style.min_width {
        @types.Dimension::Length(w) =>
          @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_min_height = match style.min_height {
        @types.Dimension::Length(h) =>
          @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      let adjusted_max_width = match style.max_width {
        @types.Dimension::Length(w) =>
          @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_max_height = match style.max_height {
        @types.Dimension::Length(h) =>
          @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      {
        ..style,
        width: adjusted_width,
        height: adjusted_height,
        min_width: adjusted_min_width,
        min_height: adjusted_min_height,
        max_width: adjusted_max_width,
        max_height: adjusted_max_height,
        // Mark as adjusted (now using border-box semantics internally)
        box_sizing: @types.BorderBox,
      }
    }
  }
}

///|
/// Helper to resolve a dimension to pixels (for padding/border calculation)
fn resolve_dimension_to_px(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0 // Percentages are resolved later
    @types.Auto => 0.0
    @types.MinContent => 0.0 // Intrinsic sizing resolved during layout
    @types.MaxContent => 0.0
    @types.FitContent(_) => 0.0
  }
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

// =============================================================================
// Containment Parsing
// =============================================================================

///|
/// Parse contain property
fn parse_contain(value : String) -> @style.Contain {
  let v = value.trim().to_string()
  // Handle keywords
  if v == "none" {
    return @style.Contain::none()
  }
  if v == "strict" {
    return @style.Contain::strict()
  }
  if v == "content" {
    return @style.Contain::content()
  }
  // Parse space-separated values
  let mut result = @style.Contain::none()
  let parts = v.split(" ")
  for part in parts {
    let p = part.to_string().trim()
    if p == "size" {
      result = { ..result, size: true }
    } else if p == "inline-size" {
      result = { ..result, inline_size: true }
    } else if p == "layout" {
      result = { ..result, layout: true }
    } else if p == "paint" {
      result = { ..result, paint: true }
    } else if p == "style" {
      result = { ..result, style: true }
    }
  }
  result
}

// Paint Property Parsing
// =============================================================================

///|
/// Parse visibility property
fn parse_visibility(value : String) -> @style.Visibility {
  match value.trim().to_string() {
    "visible" => @style.Visibility::Visible
    "hidden" => @style.Visibility::Hidden
    "collapse" => @style.Visibility::Collapse
    _ => @style.Visibility::Visible
  }
}

///|
/// Parse vertical-align property
fn parse_vertical_align(value : String) -> @style.VerticalAlign {
  match value.trim().to_string() {
    "baseline" => @style.VerticalAlign::Baseline
    "top" => @style.VerticalAlign::Top
    "middle" => @style.VerticalAlign::Middle
    "bottom" => @style.VerticalAlign::Bottom
    "text-top" => @style.VerticalAlign::TextTop
    "text-bottom" => @style.VerticalAlign::TextBottom
    "sub" => @style.VerticalAlign::Sub
    "super" => @style.VerticalAlign::Super
    _ => @style.VerticalAlign::Baseline
  }
}

///|
/// Parse z-index property
fn parse_z_index(value : String) -> @style.ZIndex {
  let trimmed = value.trim().to_string()
  if trimmed == "auto" {
    @style.ZIndex::Auto
  } else {
    try {
      let v = @strconv.parse_int(trimmed)
      @style.ZIndex::Value(v)
    } catch {
      _ => @style.ZIndex::Auto
    }
  }
}

///|
/// Parse opacity property (0.0 to 1.0)
fn parse_opacity(value : String) -> Double {
  let trimmed = value.trim().to_string()
  try {
    let v = @strconv.parse_double(trimmed)
    // Clamp to valid range
    if v < 0.0 {
      0.0
    } else if v > 1.0 {
      1.0
    } else {
      v
    }
  } catch {
    _ => 1.0
  }
}
