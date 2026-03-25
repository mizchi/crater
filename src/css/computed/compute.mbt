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
fn view_to_string(v : StringView) -> String {
  let sb = StringBuilder::new()
  sb.write_stringview(v)
  sb.to_string()
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
  mut scroll_snap_type : @style.ScrollSnapType
  mut scroll_snap_align_x : @style.ScrollSnapAlign
  mut scroll_snap_align_y : @style.ScrollSnapAlign
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
  mut margin_trim : @style.MarginTrim
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
  mut justify_content_unsafe : Bool
  mut align_content_unsafe : Bool
  mut align_self : @types.AlignSelf
  mut justify_self : @types.AlignSelf
  mut justify_items : @types.Alignment
  mut flex_grow : Double
  mut flex_shrink : Double
  mut flex_basis : @types.Dimension
  mut order : Int
  mut row_gap : @types.Dimension
  mut column_gap : @types.Dimension
  mut column_gap_is_normal : Bool
  mut column_count : Int?
  mut column_width : @types.Dimension
  mut column_fill : @style.ColumnFill
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
  mut font_weight : Double
  mut line_height : Double
  // Text wrapping and direction
  mut text_align : @style.TextAlign
  mut white_space : @style.WhiteSpace
  mut writing_mode : @style.WritingMode
  mut direction : @style.Direction
  // Vertical alignment for inline elements
  mut vertical_align : @style.VerticalAlign
  // Clip (legacy)
  mut clip : @types.ClipRect
  // Paint properties
  mut visibility : @style.Visibility
  mut pointer_events : @style.PointerEvents
  mut z_index : @style.ZIndex
  mut opacity : Double
  // Color properties
  mut color : @types.Color
  mut background_color : @types.Color
  // Containment
  mut contain : @style.Contain
  // Fragmentation
  mut break_before : @style.BreakBefore
  mut break_after : @style.BreakBefore
  mut break_inside : @style.BreakInside
  mut column_span : @style.ColumnSpan
  mut contain_intrinsic_inline_size : Double?
  mut contain_intrinsic_block_size : Double?
  // Transform
  mut transform : @style.Transform
  // Zoom (affects layout scaling)
  mut zoom : Double
  // Table properties
  mut border_spacing : Double
  mut border_spacing_vertical : Double
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
    scroll_snap_type: @style.ScrollSnapType::none(),
    scroll_snap_align_x: @style.ScrollSnapAlign::None,
    scroll_snap_align_y: @style.ScrollSnapAlign::None,
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
    margin_trim: @style.MarginTrim::None,
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
    justify_content: @types.Alignment::FlexStart,
    align_items: @types.Alignment::Stretch,
    align_content: @types.Alignment::Stretch,
    justify_content_unsafe: false,
    align_content_unsafe: false,
    align_self: @types.AlignSelf::Auto,
    justify_self: @types.AlignSelf::Auto,
    justify_items: @types.Alignment::Stretch,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    flex_basis: @types.Dimension::Auto,
    order: 0,
    row_gap: @types.Dimension::Length(0.0),
    column_gap: @types.Dimension::Length(0.0),
    column_gap_is_normal: true,
    column_count: None,
    column_width: @types.Dimension::Auto,
    column_fill: @style.ColumnFill::Balance,
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
    font_weight: 400.0,
    line_height: 16.0,
    text_align: @style.TextAlign::Start,
    white_space: @style.WhiteSpace::Normal,
    writing_mode: @style.WritingMode::HorizontalTb,
    direction: @style.Direction::Ltr,
    vertical_align: @style.VerticalAlign::Baseline,
    clip: @types.ClipRect::Auto,
    visibility: @style.Visibility::Visible,
    pointer_events: @style.PointerEvents::Auto,
    z_index: @style.ZIndex::Auto,
    opacity: 1.0,
    color: @types.Color::black(),
    background_color: @types.Color::transparent(),
    contain: @style.Contain::none(),
    break_before: @style.BreakBefore::Auto,
    break_after: @style.BreakBefore::Auto,
    break_inside: @style.BreakInside::Auto,
    column_span: @style.ColumnSpan::None,
    contain_intrinsic_inline_size: None,
    contain_intrinsic_block_size: None,
    transform: @style.Transform::none(),
    zoom: 1.0,
    border_spacing: 0.0,
    border_spacing_vertical: 0.0,
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
    scroll_snap_type: style.scroll_snap_type,
    scroll_snap_align_x: style.scroll_snap_align_x,
    scroll_snap_align_y: style.scroll_snap_align_y,
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
    margin_trim: style.margin_trim,
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
    justify_content_unsafe: style.justify_content_unsafe,
    align_content_unsafe: style.align_content_unsafe,
    align_self: style.align_self,
    justify_self: style.justify_self,
    justify_items: style.justify_items,
    flex_grow: style.flex_grow,
    flex_shrink: style.flex_shrink,
    flex_basis: style.flex_basis,
    order: style.order,
    row_gap: style.row_gap,
    column_gap: style.column_gap,
    column_gap_is_normal: style.column_gap_is_normal,
    column_count: style.column_count,
    column_width: style.column_width,
    column_fill: style.column_fill,
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
    font_weight: style.font_weight,
    line_height: style.line_height,
    text_align: style.text_align,
    white_space: style.white_space,
    writing_mode: style.writing_mode,
    direction: style.direction,
    vertical_align: style.vertical_align,
    clip: style.clip,
    visibility: style.visibility,
    pointer_events: style.pointer_events,
    z_index: style.z_index,
    opacity: style.opacity,
    color: style.color,
    background_color: style.background_color,
    contain: style.contain,
    break_before: style.break_before,
    break_after: style.break_after,
    break_inside: style.break_inside,
    column_span: style.column_span,
    contain_intrinsic_inline_size: style.contain_intrinsic_inline_size,
    contain_intrinsic_block_size: style.contain_intrinsic_block_size,
    transform: style.transform,
    zoom: style.zoom,
    border_spacing: style.border_spacing,
    border_spacing_vertical: style.border_spacing_vertical,
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
    scroll_snap_type: self.scroll_snap_type,
    scroll_snap_align_x: self.scroll_snap_align_x,
    scroll_snap_align_y: self.scroll_snap_align_y,
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
    margin_trim: self.margin_trim,
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
    justify_content_unsafe: self.justify_content_unsafe,
    align_content_unsafe: self.align_content_unsafe,
    align_self: self.align_self,
    flex_grow: self.flex_grow,
    flex_shrink: self.flex_shrink,
    flex_basis: self.flex_basis,
    order: self.order,
    row_gap: self.row_gap,
    column_gap: self.column_gap,
    column_gap_is_normal: self.column_gap_is_normal,
    column_count: self.column_count,
    column_width: self.column_width,
    column_fill: self.column_fill,
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
    justify_items: self.justify_items,
    justify_self: self.justify_self,
    font_size: self.font_size,
    font_weight: self.font_weight,
    line_height: self.line_height,
    text_align: self.text_align,
    white_space: self.white_space,
    writing_mode: self.writing_mode,
    direction: self.direction,
    vertical_align: self.vertical_align,
    clip: self.clip,
    visibility: self.visibility,
    pointer_events: self.pointer_events,
    z_index: self.z_index,
    opacity: self.opacity,
    color: self.color,
    background_color: self.background_color,
    contain: self.contain,
    break_before: self.break_before,
    break_after: self.break_after,
    break_inside: self.break_inside,
    column_span: self.column_span,
    contain_intrinsic_inline_size: self.contain_intrinsic_inline_size,
    contain_intrinsic_block_size: self.contain_intrinsic_block_size,
    transform: self.transform,
    zoom: self.zoom,
    border_spacing: self.border_spacing,
    border_spacing_vertical: self.border_spacing_vertical,
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
    "margin-trim" =>
      match style.margin_trim {
        @style.MarginTrim::None => "none"
        @style.MarginTrim::BlockStart => "block-start"
        @style.MarginTrim::BlockEnd => "block-end"
        @style.MarginTrim::Block => "block"
        @style.MarginTrim::InlineStart => "inline-start"
        @style.MarginTrim::InlineEnd => "inline-end"
        @style.MarginTrim::Inline => "inline"
      }
    "padding-top" => dimension_to_string(style.padding.top)
    "padding-right" => dimension_to_string(style.padding.right)
    "padding-bottom" => dimension_to_string(style.padding.bottom)
    "padding-left" => dimension_to_string(style.padding.left)
    "column-count" =>
      match style.column_count {
        Some(v) => v.to_string()
        None => "auto"
      }
    "column-width" => dimension_to_string(style.column_width)
    "column-fill" =>
      match style.column_fill {
        @style.ColumnFill::Balance => "balance"
        @style.ColumnFill::Auto => "auto"
      }
    "break-before" =>
      match style.break_before {
        @style.BreakBefore::Auto => "auto"
        @style.BreakBefore::Column => "column"
        @style.BreakBefore::Avoid => "avoid"
      }
    "break-after" =>
      match style.break_after {
        @style.BreakBefore::Auto => "auto"
        @style.BreakBefore::Column => "column"
        @style.BreakBefore::Avoid => "avoid"
      }
    "break-inside" | "page-break-inside" =>
      match style.break_inside {
        @style.BreakInside::Auto => "auto"
        @style.BreakInside::Avoid => "avoid"
      }
    "column-span" =>
      match style.column_span {
        @style.ColumnSpan::None => "none"
        @style.ColumnSpan::All => "all"
      }
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
    "border-spacing" =>
      if style.border_spacing == style.border_spacing_vertical {
        style.border_spacing.to_string() + "px"
      } else {
        style.border_spacing.to_string() +
        "px " +
        style.border_spacing_vertical.to_string() +
        "px"
      }
    "writing-mode" =>
      match style.writing_mode {
        @style.WritingMode::HorizontalTb => "horizontal-tb"
        @style.WritingMode::VerticalRl => "vertical-rl"
        @style.WritingMode::VerticalLr => "vertical-lr"
      }
    "direction" =>
      match style.direction {
        @style.Direction::Ltr => "ltr"
        @style.Direction::Rtl => "rtl"
      }
    "font-size" => style.font_size.to_string() + "px"
    "line-height" => style.line_height.to_string() + "px"
    "text-align" =>
      match style.text_align {
        @style.TextAlign::Start => "start"
        @style.TextAlign::End => "end"
        @style.TextAlign::Left => "left"
        @style.TextAlign::Right => "right"
        @style.TextAlign::Center => "center"
        @style.TextAlign::Justify => "justify"
      }
    "white-space" =>
      match style.white_space {
        @style.WhiteSpace::Normal => "normal"
        @style.WhiteSpace::Nowrap => "nowrap"
        @style.WhiteSpace::Pre => "pre"
        @style.WhiteSpace::PreWrap => "pre-wrap"
        @style.WhiteSpace::PreLine => "pre-line"
      }
    "pointer-events" =>
      match style.pointer_events {
        @style.PointerEvents::Auto => "auto"
        @style.PointerEvents::None => "none"
      }
    "contain-intrinsic-inline-size" =>
      match style.contain_intrinsic_inline_size {
        Some(v) => v.to_string() + "px"
        None => "none"
      }
    "contain-intrinsic-block-size" =>
      match style.contain_intrinsic_block_size {
        Some(v) => v.to_string() + "px"
        None => "none"
      }
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
  cascaded.each(fn(prop, decl) {
    if prop.has_prefix("--") {
      let value = resolve_keyword(prop, decl.value, ctx)
      // Store custom property in context
      ctx.custom_properties[prop] = value
    }
  })

  seed_direction(builder, cascaded, ctx)
  // Seed writing-mode before applying logical properties.
  // Logical sizing must follow the element's effective writing mode.
  seed_writing_mode(builder, cascaded, ctx)
  // Seed font metrics before resolving em/ch/ex units in other properties.
  let font_ctx = seed_font_metrics(builder, cascaded, ctx)

  // Second pass: apply regular properties with var() resolution
  cascaded.each(fn(prop, decl) {
    if not(prop.has_prefix("--")) && not(is_preseeded_font_property(prop)) {
      let value = resolve_keyword(prop, decl.value, font_ctx)
      apply_property(builder, prop, value, font_ctx)
    }
  })

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
  cascaded.each(fn(prop, decl) {
    if prop.has_prefix("--") {
      let value = resolve_keyword(prop, decl.value, ctx)
      ctx.custom_properties[prop] = value
    }
  })

  // Seed writing-mode before applying logical properties.
  seed_direction(builder, cascaded, ctx)
  seed_writing_mode(builder, cascaded, ctx)
  let font_ctx = seed_font_metrics(builder, cascaded, ctx)

  // Second pass: apply regular properties
  cascaded.each(fn(prop, decl) {
    if not(prop.has_prefix("--")) && not(is_preseeded_font_property(prop)) {
      let value = resolve_keyword(prop, decl.value, font_ctx)
      apply_property(builder, prop, value, font_ctx)
    }
  })

  // Handle inheritance
  apply_inheritance(builder, cascaded, ctx)

  // Return both the style and the custom properties for children
  (builder.build(), ctx.custom_properties)
}

///|
fn seed_direction(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  match ctx.parent_style {
    Some(parent_style) => builder.direction = parent_style.direction
    None => ()
  }
  match cascaded.get("direction") {
    Some(decl) => {
      let value = resolve_keyword("direction", decl.value, ctx)
      builder.direction = parse_direction(value)
    }
    None => ()
  }
}

///|
/// Seed writing-mode on the builder before logical properties are applied.
/// Uses inherited writing-mode as default, then overrides with explicit declaration.
fn seed_writing_mode(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> Unit {
  match ctx.parent_style {
    Some(parent_style) => builder.writing_mode = parent_style.writing_mode
    None => ()
  }
  match cascaded.get("writing-mode") {
    Some(decl) => {
      let value = resolve_keyword("writing-mode", decl.value, ctx)
      builder.writing_mode = parse_writing_mode(value)
    }
    None => ()
  }
}

///|
fn is_preseeded_font_property(property : String) -> Bool {
  property == "font" || property == "font-size" || property == "line-height"
}

///|
/// Seed font-size/line-height ahead of general property application so
/// em/ch/ex units in width/height and gaps resolve against the element's font.
fn seed_font_metrics(
  builder : StyleBuilder,
  cascaded : @cascade.CascadedValues,
  ctx : ComputeContext,
) -> ComputeContext {
  let mut seeded_font_size = ctx.font_size
  let mut seeded_line_height = ctx.font_size
  let mut font_decl : @cascade.Declaration? = None
  let mut font_size_decl : @cascade.Declaration? = None
  let mut line_height_decl : @cascade.Declaration? = None
  match cascaded.get("font") {
    Some(decl) => font_decl = Some(decl)
    None => ()
  }
  match cascaded.get("font-size") {
    Some(decl) => font_size_decl = Some(decl)
    None => ()
  }
  match cascaded.get("line-height") {
    Some(decl) => line_height_decl = Some(decl)
    None => ()
  }
  for idx = 0; idx < 3; idx = idx + 1 {
    let mut next_prop = ""
    let mut next_decl : @cascade.Declaration? = None
    let mut next_order = 2147483647
    match font_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "font"
          next_decl = Some(decl)
          next_order = decl.source_order
        }
      None => ()
    }
    match font_size_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "font-size"
          next_decl = Some(decl)
          next_order = decl.source_order
        }
      None => ()
    }
    match line_height_decl {
      Some(decl) =>
        if decl.source_order < next_order {
          next_prop = "line-height"
          next_decl = Some(decl)
        }
      None => ()
    }
    if next_prop == "" {
      break
    }
    let decl = match next_decl {
      Some(decl) => decl
      None => break
    }
    let value = resolve_keyword(next_prop, decl.value, ctx)
    match next_prop {
      "font" => {
        let (font_size, line_height) = parse_font_shorthand(value, ctx)
        seeded_font_size = font_size
        seeded_line_height = line_height
        font_decl = None
      }
      "font-size" => {
        seeded_font_size = parse_font_size(value, ctx)
        font_size_decl = None
      }
      "line-height" => {
        seeded_line_height = parse_line_height(value, seeded_font_size)
        line_height_decl = None
      }
      _ => ()
    }
  }

  builder.font_size = seeded_font_size
  builder.line_height = seeded_line_height
  { ..ctx, font_size: seeded_font_size }
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
    "float" =>
      builder.float = parse_float_with_direction(value, builder.direction)
    "clear" =>
      builder.clear = parse_clear_with_direction(value, builder.direction)
    "box-sizing" =>
      builder.box_sizing = match value.trim().to_lower() {
        "border-box" => @types.BoxSizing::BorderBox
        "content-box" | "initial" | "inherit" => @types.BoxSizing::ContentBox
        _ => @types.BoxSizing::ContentBox
      }
    // Sizing
    "width" =>
      builder.width = resolve_dimension_with_calc_percent_fallback(value, ctx)
    "height" =>
      builder.height = resolve_dimension_with_calc_percent_fallback(value, ctx)
    "min-width" =>
      builder.min_width = resolve_dimension_with_mixed_calc_fallback(
        "min-width", value, ctx,
      )
    "min-height" =>
      builder.min_height = resolve_dimension_with_mixed_calc_fallback(
        "min-height", value, ctx,
      )
    "max-width" => builder.max_width = resolve_dimension(value, ctx)
    "max-height" => builder.max_height = resolve_dimension(value, ctx)
    // Logical sizing properties
    // In vertical writing-modes:
    // - inline axis is vertical -> inline-size maps to height
    // - block axis is horizontal -> block-size maps to width
    "inline-size" => {
      let dim = resolve_dimension_with_calc_percent_fallback(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.height = dim
      } else {
        builder.width = dim
      }
    }
    "block-size" => {
      let dim = resolve_dimension_with_calc_percent_fallback(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.width = dim
      } else {
        builder.height = dim
      }
    }
    "min-inline-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.min_height = dim
      } else {
        builder.min_width = dim
      }
    }
    "min-block-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.min_width = dim
      } else {
        builder.min_height = dim
      }
    }
    "max-inline-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.max_height = dim
      } else {
        builder.max_width = dim
      }
    }
    "max-block-size" => {
      let dim = resolve_dimension(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.max_width = dim
      } else {
        builder.max_height = dim
      }
    }
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
    "margin-trim" => builder.margin_trim = parse_margin_trim(value)
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
      // Resolve width value from shorthand (e.g., "solid 3px", "1em solid red").
      let width = resolve_border_width(value, ctx)
      builder.border_top = width
      builder.border_right = width
      builder.border_bottom = width
      builder.border_left = width
    }
    "border-top" => builder.border_top = resolve_border_width(value, ctx)
    "border-right" => builder.border_right = resolve_border_width(value, ctx)
    "border-bottom" => builder.border_bottom = resolve_border_width(value, ctx)
    "border-left" => builder.border_left = resolve_border_width(value, ctx)
    "border-top-width" => builder.border_top = resolve_dimension(value, ctx)
    "border-right-width" => builder.border_right = resolve_dimension(value, ctx)
    "border-bottom-width" =>
      builder.border_bottom = resolve_dimension(value, ctx)
    "border-left-width" => builder.border_left = resolve_dimension(value, ctx)
    "border-style" => {
      let raw_parts = value.trim().to_lower().split(" ")
      let parts : Array[String] = []
      for part in raw_parts {
        let p = part.to_string().trim().to_string()
        if not(p.is_empty()) {
          parts.push(p)
        }
      }
      let mut top_none = false
      let mut right_none = false
      let mut bottom_none = false
      let mut left_none = false
      if parts.length() == 1 {
        let is_none = is_none_border_style(parts[0])
        top_none = is_none
        right_none = is_none
        bottom_none = is_none
        left_none = is_none
      } else if parts.length() == 2 {
        let v = is_none_border_style(parts[0])
        let h = is_none_border_style(parts[1])
        top_none = v
        bottom_none = v
        right_none = h
        left_none = h
      } else if parts.length() == 3 {
        top_none = is_none_border_style(parts[0])
        right_none = is_none_border_style(parts[1])
        left_none = is_none_border_style(parts[1])
        bottom_none = is_none_border_style(parts[2])
      } else if parts.length() >= 4 {
        top_none = is_none_border_style(parts[0])
        right_none = is_none_border_style(parts[1])
        bottom_none = is_none_border_style(parts[2])
        left_none = is_none_border_style(parts[3])
      }
      if top_none {
        builder.border_top = @types.Length(0.0)
      }
      if right_none {
        builder.border_right = @types.Length(0.0)
      }
      if bottom_none {
        builder.border_bottom = @types.Length(0.0)
      }
      if left_none {
        builder.border_left = @types.Length(0.0)
      }
    }
    "border-top-style" =>
      if is_none_border_style(value) {
        builder.border_top = @types.Length(0.0)
      }
    "border-right-style" =>
      if is_none_border_style(value) {
        builder.border_right = @types.Length(0.0)
      }
    "border-bottom-style" =>
      if is_none_border_style(value) {
        builder.border_bottom = @types.Length(0.0)
      }
    "border-left-style" =>
      if is_none_border_style(value) {
        builder.border_left = @types.Length(0.0)
      }
    // Logical border properties (block/inline)
    "border-block" | "border-block-width" => {
      let width = resolve_border_width(value, ctx)
      builder.border_top = width
      builder.border_bottom = width
    }
    "border-block-style" => {
      let raw_parts = value.trim().to_lower().split(" ")
      let parts : Array[String] = []
      for part in raw_parts {
        let p = part.to_string().trim().to_string()
        if not(p.is_empty()) {
          parts.push(p)
        }
      }
      if parts.length() > 0 && is_none_border_style(parts[0]) {
        builder.border_top = @types.Length(0.0)
      }
      if parts.length() > 1 && is_none_border_style(parts[1]) {
        builder.border_bottom = @types.Length(0.0)
      } else if parts.length() == 1 && is_none_border_style(parts[0]) {
        builder.border_bottom = @types.Length(0.0)
      }
    }
    "border-block-start" | "border-block-start-width" =>
      builder.border_top = resolve_border_width(value, ctx)
    "border-block-end" | "border-block-end-width" =>
      builder.border_bottom = resolve_border_width(value, ctx)
    "border-inline" | "border-inline-width" => {
      let width = resolve_border_width(value, ctx)
      if builder.writing_mode.is_vertical() {
        builder.border_top = width
        builder.border_bottom = width
      } else {
        builder.border_left = width
        builder.border_right = width
      }
    }
    "border-inline-style" => {
      let raw_parts = value.trim().to_lower().split(" ")
      let parts : Array[String] = []
      for part in raw_parts {
        let p = part.to_string().trim().to_string()
        if not(p.is_empty()) {
          parts.push(p)
        }
      }
      if builder.writing_mode.is_vertical() {
        if parts.length() > 0 && is_none_border_style(parts[0]) {
          builder.border_top = @types.Length(0.0)
        }
        if parts.length() > 1 && is_none_border_style(parts[1]) {
          builder.border_bottom = @types.Length(0.0)
        } else if parts.length() == 1 && is_none_border_style(parts[0]) {
          builder.border_bottom = @types.Length(0.0)
        }
      } else {
        if parts.length() > 0 && is_none_border_style(parts[0]) {
          builder.border_left = @types.Length(0.0)
        }
        if parts.length() > 1 && is_none_border_style(parts[1]) {
          builder.border_right = @types.Length(0.0)
        } else if parts.length() == 1 && is_none_border_style(parts[0]) {
          builder.border_right = @types.Length(0.0)
        }
      }
    }
    "border-inline-start" | "border-inline-start-width" =>
      if builder.writing_mode.is_vertical() {
        builder.border_top = resolve_border_width(value, ctx)
      } else {
        builder.border_left = resolve_border_width(value, ctx)
      }
    "border-inline-end" | "border-inline-end-width" =>
      if builder.writing_mode.is_vertical() {
        builder.border_bottom = resolve_border_width(value, ctx)
      } else {
        builder.border_right = resolve_border_width(value, ctx)
      }
    // Flexbox container
    "flex-direction" => builder.flex_direction = parse_flex_direction(value)
    "flex-wrap" => builder.flex_wrap = parse_flex_wrap(value)
    "justify-content" => {
      let (alignment, is_unsafe) = parse_alignment_with_overflow(value)
      builder.justify_content = alignment
      builder.justify_content_unsafe = is_unsafe
    }
    "align-items" => builder.align_items = parse_alignment(value)
    "align-content" => {
      let normalized = value.trim().to_lower().to_string()
      let (alignment, is_unsafe) = if normalized == "normal" {
        (@types.Alignment::Stretch, false)
      } else if normalized == "last baseline" {
        (@types.Alignment::Baseline, false)
      } else {
        parse_alignment_with_overflow(value)
      }
      builder.align_content = alignment
      builder.align_content_unsafe = is_unsafe
    }
    "place-content" =>
      match parse_place_content_with_overflow(value) {
        Some(((align_content, align_unsafe), (justify_content, justify_unsafe))) => {
          builder.align_content = align_content
          builder.align_content_unsafe = align_unsafe
          builder.justify_content = justify_content
          builder.justify_content_unsafe = justify_unsafe
        }
        None => ()
      }
    // Flexbox/Grid item alignment
    "align-self" => builder.align_self = parse_align_self(value)
    "justify-self" => builder.justify_self = parse_align_self(value)
    // Grid container alignment
    "justify-items" => builder.justify_items = parse_alignment(value)
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
                // flex: <number> = <number> 1 0%
                builder.flex_grow = parse_number(parts[0].to_string())
                builder.flex_shrink = 1.0
                builder.flex_basis = @types.Dimension::Percent(0.0)
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
                // flex: <grow> <shrink> = <grow> <shrink> 0%
                builder.flex_grow = parse_number(parts[0].to_string())
                builder.flex_shrink = parse_number(parts[1].to_string())
                builder.flex_basis = @types.Dimension::Percent(0.0)
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
      let parts : Array[StringView] = value
        .trim()
        .split(" ")
        .filter(fn(s) { not(s.is_empty()) })
        .collect()
      builder.column_gap_is_normal = false
      match parts.length() {
        1 => {
          let dim = resolve_dimension_with_calc_percent_fallback(
            parts[0].to_string(),
            ctx,
          )
          builder.row_gap = dim
          builder.column_gap = dim
        }
        2 => {
          builder.row_gap = resolve_dimension_with_calc_percent_fallback(
            parts[0].to_string(),
            ctx,
          )
          builder.column_gap = resolve_dimension_with_calc_percent_fallback(
            parts[1].to_string(),
            ctx,
          )
        }
        _ => {
          let dim = resolve_dimension_with_calc_percent_fallback(value, ctx)
          builder.row_gap = dim
          builder.column_gap = dim
        }
      }
    }
    "row-gap" | "grid-row-gap" =>
      builder.row_gap = resolve_dimension_with_calc_percent_fallback(value, ctx)
    "column-gap" | "grid-column-gap" => {
      builder.column_gap = resolve_dimension_with_calc_percent_fallback(
        value, ctx,
      )
      builder.column_gap_is_normal = false
    }
    // Multi-column
    "column-count" => builder.column_count = parse_column_count(value)
    "column-width" => builder.column_width = parse_column_width(value, ctx)
    "column-fill" => builder.column_fill = parse_column_fill(value)
    "columns" =>
      match parse_columns_shorthand(value, ctx) {
        Some((count, width)) => {
          builder.column_count = count
          builder.column_width = width
        }
        None => ()
      }
    "break-before" => builder.break_before = parse_break_before(value)
    "break-after" => builder.break_after = parse_break_before(value)
    "break-inside" | "page-break-inside" =>
      builder.break_inside = parse_break_inside(value)
    "column-span" => builder.column_span = parse_column_span(value)
    // Inset
    "top" => builder.inset_top = resolve_dimension(value, ctx)
    "right" => builder.inset_right = resolve_dimension(value, ctx)
    "bottom" => builder.inset_bottom = resolve_dimension(value, ctx)
    "left" => builder.inset_left = resolve_dimension(value, ctx)
    "inset" => {
      let parts : Array[StringView] = value
        .split(" ")
        .filter(fn(s) { not(s.is_empty()) })
        .collect()
      match parts.length() {
        1 => {
          let dim = resolve_dimension(parts[0].to_string(), ctx)
          builder.inset_top = dim
          builder.inset_right = dim
          builder.inset_bottom = dim
          builder.inset_left = dim
        }
        2 => {
          let tb = resolve_dimension(parts[0].to_string(), ctx)
          let lr = resolve_dimension(parts[1].to_string(), ctx)
          builder.inset_top = tb
          builder.inset_bottom = tb
          builder.inset_left = lr
          builder.inset_right = lr
        }
        3 => {
          builder.inset_top = resolve_dimension(parts[0].to_string(), ctx)
          let lr = resolve_dimension(parts[1].to_string(), ctx)
          builder.inset_left = lr
          builder.inset_right = lr
          builder.inset_bottom = resolve_dimension(parts[2].to_string(), ctx)
        }
        4 => {
          builder.inset_top = resolve_dimension(parts[0].to_string(), ctx)
          builder.inset_right = resolve_dimension(parts[1].to_string(), ctx)
          builder.inset_bottom = resolve_dimension(parts[2].to_string(), ctx)
          builder.inset_left = resolve_dimension(parts[3].to_string(), ctx)
        }
        _ => ()
      }
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
    "scroll-snap-type" =>
      builder.scroll_snap_type = parse_scroll_snap_type(value)
    "scroll-snap-align" => {
      let (inline_align, block_align) = parse_scroll_snap_align(value)
      builder.scroll_snap_align_x = inline_align
      builder.scroll_snap_align_y = block_align
    }
    // Grid container
    "grid-auto-flow" => builder.grid_auto_flow = parse_grid_auto_flow(value)
    "grid-template-columns" =>
      builder.grid_template_columns = parse_grid_template_tracks(value)
    "grid-template-rows" =>
      builder.grid_template_rows = parse_grid_template_tracks(value)
    "grid-template" =>
      match parse_grid_template_shorthand(value) {
        Some((rows, cols)) => {
          builder.grid_template_rows = rows
          builder.grid_template_columns = cols
        }
        None => ()
      }
    "grid" =>
      match parse_grid_template_shorthand(value) {
        Some((rows, cols)) => {
          builder.grid_template_rows = rows
          builder.grid_template_columns = cols
        }
        None => ()
      }
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
    "grid-area" => {
      let (row_start, column_start, row_end, column_end) = parse_grid_area_shorthand(
        value,
      )
      builder.grid_row_start = row_start
      builder.grid_column_start = column_start
      builder.grid_row_end = row_end
      builder.grid_column_end = column_end
    }
    // Font properties
    "font-size" => builder.font_size = parse_font_size(value, ctx)
    "line-height" =>
      builder.line_height = parse_line_height(value, builder.font_size)
    "text-align" => builder.text_align = parse_text_align(value)
    "white-space" => builder.white_space = parse_white_space(value)
    "writing-mode" => builder.writing_mode = parse_writing_mode(value)
    "direction" => builder.direction = parse_direction(value)
    "vertical-align" => builder.vertical_align = parse_vertical_align(value)
    "font" => {
      // Parse font shorthand: [style] [variant] [weight] size[/line-height] family
      let (fs, lh) = parse_font_shorthand(value, ctx)
      builder.font_size = fs
      builder.line_height = lh
    }
    // CSS Containment
    "contain" => builder.contain = parse_contain(value)
    "container-type" =>
      match parse_container_type(value) {
        Some(implied) =>
          if implied.has_containment() {
            builder.contain = merge_contain(builder.contain, implied)
          }
        None => ()
      }
    "contain-intrinsic-inline-size" =>
      builder.contain_intrinsic_inline_size = parse_contain_intrinsic_axis(
        value, ctx,
      )
    "contain-intrinsic-block-size" =>
      builder.contain_intrinsic_block_size = parse_contain_intrinsic_axis(
        value, ctx,
      )
    "contain-intrinsic-size" =>
      match parse_contain_intrinsic_size(value, ctx) {
        Some((inline_size, block_size)) => {
          builder.contain_intrinsic_inline_size = inline_size
          builder.contain_intrinsic_block_size = block_size
        }
        None => ()
      }
    // Clip (legacy, deprecated but widely used for a11y)
    "clip" => builder.clip = parse_clip(value)
    // Paint properties (visual, not layout)
    "visibility" => builder.visibility = parse_visibility(value)
    "pointer-events" => builder.pointer_events = parse_pointer_events(value)
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
    // Font weight
    "font-weight" => builder.font_weight = parse_font_weight(value)
    // Transform (visual position offset)
    "transform" => builder.transform = parse_transform(value)
    // Zoom (layout scaling, inherited)
    "zoom" => builder.zoom = parse_zoom(value)
    // Table properties
    "border-spacing" => {
      let (horizontal, vertical) = parse_border_spacing(value, ctx)
      builder.border_spacing = horizontal
      builder.border_spacing_vertical = vertical
    }
    "border-collapse" => builder.border_collapse = parse_border_collapse(value)
    "table-layout" => builder.table_layout = parse_table_layout(value)
    "caption-side" => builder.caption_side = parse_caption_side(value)
    _ => ()
  }
}

///|
fn parse_font_weight(value : String) -> Double {
  match value.trim().to_lower() {
    "normal" => 400.0
    "bold" => 700.0
    "lighter" => 100.0
    "bolder" => 700.0
    _ => {
      let n = @strconv.parse_double(value.trim()) catch { _ => return 400.0 }
      if n >= 1.0 && n <= 1000.0 {
        n
      } else {
        400.0
      }
    }
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
/// Border style keywords that suppress used border width.
fn is_none_border_style(value : String) -> Bool {
  let v = value.trim().to_lower()
  v == "none" || v == "hidden"
}

///|
/// Resolve border width from width/style/color shorthand tokens.
/// Falls back to the existing default 1.5px for style-only shorthands.
fn resolve_border_width(
  value : String,
  ctx : ComputeContext,
) -> @types.Dimension {
  let v = value.trim().to_lower()
  if v == "none" || v == "hidden" || v == "0" {
    return @types.Length(0.0)
  }

  let mut has_visible_style = false
  let mut has_none_style = false

  let parts = v
    .split(" ")
    .map(fn(part) { part.to_string().trim().to_string() })
    .filter(fn(part) { not(part.is_empty()) })
    .collect()

  for part in parts {
    match part {
      "none" | "hidden" => {
        has_none_style = true
        continue
      }
      "thin" => return @types.Length(1.0)
      "medium" => return @types.Length(3.0)
      "thick" => return @types.Length(5.0)
      "solid"
      | "dotted"
      | "dashed"
      | "double"
      | "groove"
      | "ridge"
      | "inset"
      | "outset" => {
        has_visible_style = true
        continue
      }
      _ => ()
    }

    // Length-like token found in shorthand.
    match resolve_dimension(part, ctx) {
      @types.Length(px) => return @types.Length(px)
      _ => ()
    }
  }

  if has_none_style {
    @types.Length(0.0)
  } else if has_visible_style {
    @types.Length(1.5)
  } else {
    @types.Length(0.0)
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
/// Parse margin-trim value
fn parse_margin_trim(value : String) -> @style.MarginTrim {
  match value.trim().to_lower() {
    "none" => @style.MarginTrim::None
    "block-start" => @style.MarginTrim::BlockStart
    "block-end" => @style.MarginTrim::BlockEnd
    "block" => @style.MarginTrim::Block
    "inline-start" => @style.MarginTrim::InlineStart
    "inline-end" => @style.MarginTrim::InlineEnd
    "inline" => @style.MarginTrim::Inline
    _ => @style.MarginTrim::None
  }
}

///|
/// Parse border-spacing value (single value or two values)
fn parse_border_spacing(
  value : String,
  ctx : ComputeContext,
) -> (Double, Double) {
  let v = value.trim()
  // Split by whitespace
  let parts : Array[StringView] = v
    .split(" ")
    .filter(fn(s) { not(s.is_empty()) })
    .collect()
  if parts.length() == 0 {
    return (0.0, 0.0)
  }
  let horizontal = match resolve_dimension(parts[0].to_string(), ctx) {
    @types.Length(px) => px
    _ => 0.0
  }
  let vertical = if parts.length() >= 2 {
    match resolve_dimension(parts[1].to_string(), ctx) {
      @types.Length(px) => px
      _ => horizontal
    }
  } else {
    horizontal
  }
  (horizontal, vertical)
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
    let inner = view_to_string(
      v.view(start_offset=5, end_offset=v.length() - 1),
    )
    return parse_simple_calc_expr(inner, ctx)
  }

  // Handle nested min()
  if v.has_prefix("min(") && v.has_suffix(")") {
    let inner = view_to_string(
      v.view(start_offset=4, end_offset=v.length() - 1),
    )
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
    let inner = view_to_string(
      v.view(start_offset=4, end_offset=v.length() - 1),
    )
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
    let inner = view_to_string(
      v.view(start_offset=6, end_offset=v.length() - 1),
    )
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
        let token = expr.unsafe_substring(start=token_start, end=i).trim()
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
/// Parse calc() terms and return (length_px, percent_ratio)
/// percent_ratio is 0.5 for 50%.
fn parse_calc_terms(expr : String, ctx : ComputeContext) -> (Double, Double)? {
  // Extract the expression inside calc(...)
  let v = expr.trim()
  if not(v.has_prefix("calc(")) || not(v.has_suffix(")")) {
    return None
  }
  // Extract content: "calc(" has 5 chars, ")" has 1 char
  let inner = view_to_string(v.view(start_offset=5, end_offset=v.length() - 1))
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
        let token = inner.unsafe_substring(start=token_start, end=i).trim()
        if not(token.is_empty()) {
          // Parse the token
          if token.has_suffix("%") {
            let num_str = view_to_string(
              token.view(end_offset=token.length() - 1),
            )
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
          } else {
            // Try to resolve known length units to px for calc() simplification.
            let resolved_px : Double? = if token.has_suffix("px") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 2),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              Some(n)
            } else if token.has_suffix("vw") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 2),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              Some(n * ctx.viewport_width / 100.0)
            } else if token.has_suffix("vh") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 2),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              Some(n * ctx.viewport_height / 100.0)
            } else if token.has_suffix("vmin") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 4),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              let min_dimension = if ctx.viewport_width < ctx.viewport_height {
                ctx.viewport_width
              } else {
                ctx.viewport_height
              }
              Some(n * min_dimension / 100.0)
            } else if token.has_suffix("vmax") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 4),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              let max_dimension = if ctx.viewport_width > ctx.viewport_height {
                ctx.viewport_width
              } else {
                ctx.viewport_height
              }
              Some(n * max_dimension / 100.0)
            } else if token.has_suffix("rem") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 3),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              Some(n * ctx.root_font_size)
            } else if token.has_suffix("em") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 2),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              Some(n * ctx.font_size)
            } else if token.has_suffix("pt") {
              let num_str = view_to_string(
                token.view(end_offset=token.length() - 2),
              )
              let n = @strconv.parse_double(num_str.to_string()) catch {
                _ => return None
              }
              Some(n * 96.0 / 72.0)
            } else {
              None
            }
            match resolved_px {
              Some(n) =>
                match current_op {
                  '+' => result_px = result_px + n
                  '-' => result_px = result_px - n
                  '*' => result_px = result_px * n
                  '/' => result_px = result_px / n
                  _ => ()
                }
              None => {
                // Try as unitless number (treat as px if 0, otherwise skip)
                let n = @strconv.parse_double(token) catch { _ => return None }
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
                    _ => return None
                  }
                }
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
  Some((result_px, result_pct / 100.0))
}

///|
/// Extract first percentage token from calc() expression as ratio.
/// Used as a fallback when mixed calc contains multiplicative terms.
fn extract_first_percent_ratio(expr : String) -> Double? {
  let mut i = 0
  while i < expr.length() {
    if expr[i].to_int().unsafe_to_char() == '%' {
      let mut start = i
      while start > 0 {
        let c = expr[start - 1].to_int().unsafe_to_char()
        if (c >= '0' && c <= '9') || c == '.' {
          start = start - 1
          continue
        }
        if c == '+' || c == '-' {
          start = start - 1
        }
        break
      }
      let num = expr.unsafe_substring(start~, end=i).trim()
      if not(num.is_empty()) {
        let n = @strconv.parse_double(num.to_string()) catch {
          _ => return None
        }
        return Some(n / 100.0)
      }
    }
    i = i + 1
  }
  None
}

///|
/// Parse a calc() expression from a string and try to simplify it
/// Returns Some(dimension) if simplification is possible, None otherwise
fn parse_calc_string(expr : String, ctx : ComputeContext) -> @types.Dimension? {
  match parse_calc_terms(expr, ctx) {
    Some((result_px, result_percent)) =>
      if result_percent.abs() < 0.0001 {
        Some(@types.Length(result_px))
      } else if result_px.abs() < 0.0001 {
        Some(@types.Percent(result_percent))
      } else {
        None
      }
    None => None
  }
}

///|
/// Choose a width reference for mixed calc() fallback.
/// Prefer parent's definite width when available; otherwise use viewport width.
fn mixed_calc_width_reference(ctx : ComputeContext) -> Double {
  match ctx.parent_style {
    Some(parent) =>
      match parent.width {
        @types.Length(w) => w
        @types.Percent(p) => ctx.viewport_width * p
        _ => ctx.viewport_width
      }
    None => ctx.viewport_width
  }
}

///|
/// Fallback for mixed calc() on properties that need concrete dimensions.
/// For expressions like calc(50% - 10px), resolve using a width reference.
fn resolve_dimension_with_calc_percent_fallback(
  value : String,
  ctx : ComputeContext,
) -> @types.Dimension {
  let dim = resolve_dimension(value, ctx)
  match dim {
    @types.Auto =>
      if value.trim().has_prefix("calc(") {
        match parse_calc_terms(value, ctx) {
          Some((length_px, percent_ratio)) =>
            if percent_ratio.abs() >= 0.0001 {
              let percent_for_resolution = if value.contains("*") ||
                value.contains("/") {
                match extract_first_percent_ratio(value) {
                  Some(p) => p
                  None => percent_ratio
                }
              } else {
                percent_ratio
              }
              let basis = mixed_calc_width_reference(ctx)
              @types.Length(basis * percent_for_resolution + length_px)
            } else if length_px.abs() >= 0.0001 {
              @types.Length(length_px)
            } else {
              @types.Length(0.0)
            }
          None => dim
        }
      } else {
        dim
      }
    _ => dim
  }
}

///|
/// Compatibility fallback for mixed calc() in min-size properties.
/// keep current Dimension model and pick axis-specific term when mixed.
fn resolve_dimension_with_mixed_calc_fallback(
  property : String,
  value : String,
  ctx : ComputeContext,
) -> @types.Dimension {
  let dim = resolve_dimension(value, ctx)
  match dim {
    @types.Auto =>
      if value.trim().has_prefix("calc(") {
        match parse_calc_terms(value, ctx) {
          Some((length_px, percent_ratio)) =>
            if length_px.abs() >= 0.0001 && percent_ratio.abs() >= 0.0001 {
              match property {
                "min-width" => @types.Length(length_px)
                "min-height" =>
                  @types.Length(ctx.viewport_width * percent_ratio)
                _ => dim
              }
            } else {
              dim
            }
          None => dim
        }
      } else {
        dim
      }
    _ => dim
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
  let inner : String = view_to_string(
    v.view(start_offset=4, end_offset=v.length() - 1),
  )
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
    let slice = inner.unsafe_substring(start=0, end=comma_pos)
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
        let fallback_slice = inner.unsafe_substring(
          start=comma_pos + 1,
          end=inner.length(),
        )
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
      let substr = view_to_string(v.view(start_offset=i, end_offset=i + 4))
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
        let var_expr = view_to_string(v.view(start_offset=i, end_offset=j))
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
fn strip_css_ascii_whitespace(value : String) -> String {
  let sb = StringBuilder::new()
  for c in value.iter() {
    if c != ' ' && c != '\t' && c != '\n' && c != '\r' && c != '\u000C' {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Resolve dimension with relative unit conversion
fn resolve_dimension(value : String, ctx : ComputeContext) -> @types.Dimension {
  // First resolve any var() functions
  let raw_v = resolve_all_vars(value, ctx).trim()
  let v = strip_css_ascii_whitespace(raw_v.to_string())
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
  if raw_v.has_prefix("calc(") {
    match parse_calc_string(raw_v.to_string(), ctx) {
      Some(dim) => return dim
      None => return @types.Dimension::Auto // Fallback for complex calc
    }
  }

  // Handle min(), max(), clamp() CSS math functions
  if raw_v.has_prefix("min(") ||
    raw_v.has_prefix("max(") ||
    raw_v.has_prefix("clamp(") {
    match parse_css_math_function(raw_v.to_string(), ctx) {
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
/// Supports translate(x, y), translateX(x), translateY(y), scale(x, y), scaleX(x), scaleY(y)
fn parse_transform(value : String) -> @style.Transform {
  let v = value.trim().to_lower()
  // Handle none
  if v == "none" || v.is_empty() {
    return @style.Transform::none()
  }
  let mut translate_x = @style.TranslateValue::Length(0.0)
  let mut translate_y = @style.TranslateValue::Length(0.0)
  let mut scale_x = 1.0
  let mut scale_y = 1.0
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
      "scale" => {
        // scale(x) or scale(x, y)
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          let sx = parse_scale_value(args[0])
          scale_x = scale_x * sx
          scale_y = scale_y * sx // If only one arg, use same scale for both
        }
        if args.length() >= 2 {
          scale_y = scale_y /
            scale_x *
            parse_scale_value(args[1]) *
            scale_x /
            scale_x
          // Actually: if second arg provided, override scale_y
          scale_y = parse_scale_value(args[1])
        }
      }
      "scalex" => scale_x = scale_x * parse_scale_value(args_str)
      "scaley" => scale_y = scale_y * parse_scale_value(args_str)
      "scale3d" => {
        // scale3d(x, y, z) - we only use x and y
        let args = split_by_comma(args_str)
        if args.length() >= 1 {
          scale_x = scale_x * parse_scale_value(args[0])
        }
        if args.length() >= 2 {
          scale_y = scale_y * parse_scale_value(args[1])
        }
      }
      _ => () // Ignore unsupported functions like rotate, skew, etc.
    }
  }
  { translate_x, translate_y, scale_x, scale_y }
}

///|
/// Parse a scale value (number, no unit)
fn parse_scale_value(value : String) -> Double {
  let v = value.trim()
  if v.is_empty() {
    return 1.0
  }
  @strconv.parse_double(v) catch {
    _ => 1.0
  }
}

///|
/// Parse CSS zoom property
/// Supports: normal, number, percentage
fn parse_zoom(value : String) -> Double {
  let v = value.trim().to_lower()
  if v.is_empty() || v == "normal" {
    return 1.0
  }
  // Check for percentage (e.g., "150%")
  if v.has_suffix("%") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 1))
    let n = @strconv.parse_double(num_str.trim()) catch { _ => return 1.0 }
    return n / 100.0
  }
  // Parse as number (e.g., "1.5" or "2")
  @strconv.parse_double(v) catch {
    _ => 1.0
  }
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
    let num_str = view_to_string(v.view(end_offset=v.length() - 1))
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Percent(n / 100.0)
  } else if v.has_suffix("px") {
    let num_str = view_to_string(v.view(end_offset=v.length() - 2))
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n)
  } else if v.has_suffix("em") || v.has_suffix("rem") {
    // em/rem - convert to pixels assuming 16px base
    let suffix_len = if v.has_suffix("rem") { 3 } else { 2 }
    let num_str = view_to_string(v.view(end_offset=v.length() - suffix_len))
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
    "font-weight", "font-style", "color", "visibility", "white-space", "pointer-events",
  ]
  for prop in inherited_props {
    let covered_by_font_shorthand = cascaded.has("font") &&
      (prop == "font-size" || prop == "line-height")
    // If property not in cascaded values, inherit from parent
    if not(cascaded.has(prop)) && not(covered_by_font_shorthand) {
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
      let prop = view_to_string(pair_str.view(end_offset=colon_pos)).trim()
      let val = view_to_string(pair_str.view(start_offset=colon_pos + 1)).trim()
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

  // Handle rem units (relative to root font-size) first.
  // "1rem" also ends with "em", so ordering matters.
  match v.strip_suffix("rem") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch { _ => 1.0 }
      return n * ctx.root_font_size
    }
    None => ()
  }

  // Handle em units (relative to parent font-size)
  match v.strip_suffix("em") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch { _ => 1.0 }
      return n * ctx.font_size
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

  let plain_number = @strconv.parse_double(v) catch { _ => -1.0 }
  if plain_number == 0.0 {
    return 0.0
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
        let size_part = part.unsafe_substring(start=0, end=slash_idx)
        let lh_part = part.unsafe_substring(
          start=slash_idx + 1,
          end=part.length(),
        )
        font_size = parse_font_size(size_part, ctx)
        line_height = parse_line_height(lh_part, font_size)
        break
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
// Multi-column / Fragmentation Parsing
// =============================================================================

///|
fn parse_column_count(value : String) -> Int? {
  let trimmed = value.trim().to_string()
  if trimmed.is_empty() || trimmed == "auto" {
    return None
  }
  try {
    let parsed = @strconv.parse_int(trimmed)
    if parsed >= 1 {
      Some(parsed)
    } else {
      None
    }
  } catch {
    _ => None
  }
}

///|
fn parse_column_width(value : String, ctx : ComputeContext) -> @types.Dimension {
  let trimmed = value.trim().to_string()
  if trimmed.is_empty() || trimmed == "auto" {
    return @types.Dimension::Auto
  }
  let dim = resolve_dimension_with_calc_percent_fallback(trimmed, ctx)
  match dim {
    @types.Dimension::Length(v) =>
      if v > 0.0 {
        @types.Dimension::Length(v)
      } else {
        @types.Dimension::Auto
      }
    @types.Dimension::Percent(v) =>
      if v > 0.0 {
        @types.Dimension::Percent(v)
      } else {
        @types.Dimension::Auto
      }
    @types.Dimension::Auto
    | @types.Dimension::MinContent
    | @types.Dimension::MaxContent
    | @types.Dimension::FitContent(_) => @types.Dimension::Auto
  }
}

///|
fn parse_column_fill(value : String) -> @style.ColumnFill {
  match value.trim().to_string() {
    "auto" => @style.ColumnFill::Auto
    _ => @style.ColumnFill::Balance
  }
}

///|
fn parse_break_before(value : String) -> @style.BreakBefore {
  match value.trim().to_string() {
    "column" => @style.BreakBefore::Column
    "avoid" => @style.BreakBefore::Avoid
    _ => @style.BreakBefore::Auto
  }
}

///|
fn parse_break_inside(value : String) -> @style.BreakInside {
  match value.trim().to_string() {
    "avoid" => @style.BreakInside::Avoid
    _ => @style.BreakInside::Auto
  }
}

///|
fn parse_column_span(value : String) -> @style.ColumnSpan {
  match value.trim().to_string() {
    "all" => @style.ColumnSpan::All
    _ => @style.ColumnSpan::None
  }
}

///|
fn parse_columns_shorthand(
  value : String,
  ctx : ComputeContext,
) -> (Int?, @types.Dimension)? {
  let parts : Array[StringView] = value
    .trim()
    .split(" ")
    .filter(fn(s) { not(s.is_empty()) })
    .collect()
  if parts.length() == 0 {
    return None
  }
  let mut count : Int? = None
  let mut width = @types.Dimension::Auto
  for part in parts {
    let token = part.to_string()
    if token == "auto" {
      continue
    }
    if count is None {
      match parse_column_count(token) {
        Some(v) => {
          count = Some(v)
          continue
        }
        None => ()
      }
    }
    let parsed_width = parse_column_width(token, ctx)
    match parsed_width {
      @types.Dimension::Auto => ()
      _ => width = parsed_width
    }
  }
  Some((count, width))
}

// =============================================================================
// Containment Parsing
// =============================================================================

///|
/// Parse contain-intrinsic-inline-size / contain-intrinsic-block-size.
/// Returns a content-box fallback length in px, or None for none/auto.
fn parse_contain_intrinsic_axis(
  value : String,
  ctx : ComputeContext,
) -> Double? {
  let v = resolve_all_vars(value, ctx).trim().to_string()
  if v.is_empty() || v == "none" || v == "auto" {
    return None
  }
  match resolve_dimension(v, ctx) {
    @types.Length(length) => if length > 0.0 { Some(length) } else { Some(0.0) }
    _ => None
  }
}

///|
/// Parse contain-intrinsic-size shorthand.
/// One value applies to both inline/block axes; two values map to inline then block.
fn parse_contain_intrinsic_size(
  value : String,
  ctx : ComputeContext,
) -> (Double?, Double?)? {
  let v = resolve_all_vars(value, ctx).trim().to_string()
  if v.is_empty() {
    return None
  }
  let axis_values : Array[Double?] = []
  let parts = v.split(" ")
  for part in parts {
    let p = part.to_string().trim().to_string()
    if p.is_empty() || p == "auto" {
      continue
    }
    if p == "none" {
      axis_values.push(None)
      continue
    }
    match parse_contain_intrinsic_axis(p, ctx) {
      Some(length) => axis_values.push(Some(length))
      None => ()
    }
  }
  if axis_values.length() == 0 {
    None
  } else if axis_values.length() == 1 {
    Some((axis_values[0], axis_values[0]))
  } else {
    Some((axis_values[0], axis_values[1]))
  }
}

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

///|
fn merge_contain(
  base : @style.Contain,
  extra : @style.Contain,
) -> @style.Contain {
  let merged : @style.Contain = {
    size: base.size || extra.size,
    inline_size: base.inline_size || extra.inline_size,
    layout: base.layout || extra.layout,
    paint: base.paint || extra.paint,
    style: base.style || extra.style,
  }
  if merged.size {
    { ..merged, inline_size: false }
  } else {
    merged
  }
}

///|
/// Parse container-type into implied contain bits.
/// Supported: normal | size | inline-size
fn parse_container_type(value : String) -> @style.Contain? {
  match value.trim().to_string() {
    "normal" => Some(@style.Contain::none())
    "size" => Some({ ..@style.Contain::none(), size: true, style: true })
    "inline-size" =>
      Some({ ..@style.Contain::none(), inline_size: true, style: true })
    _ => None
  }
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
fn parse_pointer_events(value : String) -> @style.PointerEvents {
  match value.trim().to_string() {
    "none" => @style.PointerEvents::None
    _ => @style.PointerEvents::Auto
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
