// =============================================================================
// Paint Model Package - Visual properties and paint node types
// =============================================================================

///|
pub(all) struct PaintProperties {
  z_index : @style.ZIndex
  visibility : @style.Visibility
  pointer_events : @style.PointerEvents
  opacity : Double
  color : @types.Color
  background_color : @types.Color
  background_image : @types.BackgroundImage
  box_shadows : Array[@style.BoxShadow]
  font_size : Double
  line_height : Double
  letter_spacing : Double
  word_spacing : Double
  is_bold : Bool
  font_family : String
  clip_path : @style.ClipPath
  border_top_left_radius : Double
  border_top_right_radius : Double
  border_bottom_right_radius : Double
  border_bottom_left_radius : Double
  overflow_x : @types.Overflow
  overflow_y : @types.Overflow
  text_decoration_underline : Bool
  text_decoration_line_through : Bool
  text_decoration_overline : Bool
  border_top_width : Double
  border_right_width : Double
  border_bottom_width : Double
  border_left_width : Double
  border_top_color : @types.Color
  border_right_color : @types.Color
  border_bottom_color : @types.Color
  border_left_color : @types.Color
}

///|
pub fn PaintProperties::default() -> PaintProperties {
  {
    z_index: @style.ZIndex::Auto,
    visibility: @style.Visibility::Visible,
    pointer_events: @style.PointerEvents::Auto,
    opacity: 1.0,
    color: @types.Color::black(),
    background_color: @types.Color::transparent(),
    background_image: @types.None,
    box_shadows: [],
    font_size: 16.0,
    line_height: 16.0,
    letter_spacing: 0.0,
    word_spacing: 0.0,
    is_bold: false,
    font_family: "",
    clip_path: @style.ClipPath::none(),
    border_top_left_radius: 0.0,
    border_top_right_radius: 0.0,
    border_bottom_right_radius: 0.0,
    border_bottom_left_radius: 0.0,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    text_decoration_underline: false,
    text_decoration_line_through: false,
    text_decoration_overline: false,
    border_top_width: 0.0,
    border_right_width: 0.0,
    border_bottom_width: 0.0,
    border_left_width: 0.0,
    border_top_color: @types.Color::transparent(),
    border_right_color: @types.Color::transparent(),
    border_bottom_color: @types.Color::transparent(),
    border_left_color: @types.Color::transparent(),
  }
}

///|
pub fn PaintProperties::from_style(style : @style.Style) -> PaintProperties {
  {
    z_index: style.z_index,
    visibility: style.visibility,
    pointer_events: style.pointer_events,
    opacity: style.opacity,
    color: style.color,
    background_color: style.background_color,
    background_image: style.background_image,
    box_shadows: style.box_shadows,
    font_size: style.font_size,
    line_height: style.line_height,
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
    is_bold: is_bold_weight(style.font_weight),
    font_family: style.font_family,
    clip_path: style.clip_path,
    border_top_left_radius: style.border_top_left_radius,
    border_top_right_radius: style.border_top_right_radius,
    border_bottom_right_radius: style.border_bottom_right_radius,
    border_bottom_left_radius: style.border_bottom_left_radius,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    text_decoration_underline: style.text_decoration_underline,
    text_decoration_line_through: style.text_decoration_line_through,
    text_decoration_overline: style.text_decoration_overline,
    border_top_width: 0.0,
    border_right_width: 0.0,
    border_bottom_width: 0.0,
    border_left_width: 0.0,
    border_top_color: style.border_color.top,
    border_right_color: style.border_color.right,
    border_bottom_color: style.border_color.bottom,
    border_left_color: style.border_color.left,
  }
}

///|
pub impl Show for PaintProperties with output(self, logger) {
  logger.write_string("PaintProperties { z_index: ")
  self.z_index.output(logger)
  logger.write_string(", visibility: ")
  self.visibility.output(logger)
  logger.write_string(", opacity: ")
  self.opacity.output(logger)
  logger.write_string(", pointer_events: ")
  self.pointer_events.output(logger)
  logger.write_string(", color: ")
  self.color.output(logger)
  logger.write_string(", background_color: ")
  self.background_color.output(logger)
  logger.write_string(" }")
}

///|
pub fn PaintProperties::clips_overflow(self : PaintProperties) -> Bool {
  match (self.overflow_x, self.overflow_y) {
    (@types.Visible, @types.Visible) => false
    _ => true
  }
}

///|
pub fn PaintProperties::should_render(self : PaintProperties) -> Bool {
  match self.visibility {
    @style.Visibility::Visible => self.opacity > 0.0
    _ => false
  }
}

///|
pub fn PaintProperties::z_index_value(self : PaintProperties) -> Int {
  match self.z_index {
    @style.ZIndex::Auto => 0
    @style.ZIndex::Value(v) => v
  }
}

///|
fn is_bold_weight(weight : Double) -> Bool {
  weight >= 600.0
}

///|
pub(all) struct PaintNode {
  id : String
  tag : String
  x : Double
  y : Double
  width : Double
  height : Double
  overflow_x : @types.Overflow
  overflow_y : @types.Overflow
  scroll_width : Double
  scroll_height : Double
  clip : @types.ClipRect
  paint : PaintProperties
  stacking_order : Int
  text : String?
  src : String?
  visual_polygon : Array[(Double, Double)] // local points relative to node x/y; empty means rect
  children : Array[PaintNode]
}

///|
pub fn PaintNode::new(
  id : String,
  tag : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : PaintProperties,
  children : Array[PaintNode],
  text? : String? = None,
  src? : String? = None,
  overflow_x? : @types.Overflow = @types.Visible,
  overflow_y? : @types.Overflow = @types.Visible,
  scroll_width? : Double = 0.0,
  scroll_height? : Double = 0.0,
  clip? : @types.ClipRect = @types.ClipRect::Auto,
  visual_polygon? : Array[(Double, Double)] = [],
) -> PaintNode {
  {
    id,
    tag,
    x,
    y,
    width,
    height,
    overflow_x,
    overflow_y,
    scroll_width: if scroll_width == 0.0 {
      width
    } else {
      scroll_width
    },
    scroll_height: if scroll_height == 0.0 {
      height
    } else {
      scroll_height
    },
    clip,
    paint,
    stacking_order: paint.z_index_value(),
    text,
    src,
    visual_polygon,
    children,
  }
}

///|
pub impl Show for PaintNode with output(self, logger) {
  logger.write_string(self.id)
  logger.write_string(" (")
  self.x.output(logger)
  logger.write_string(", ")
  self.y.output(logger)
  logger.write_string(") ")
  self.width.output(logger)
  logger.write_string("x")
  self.height.output(logger)
  if self.stacking_order != 0 {
    logger.write_string(" z:")
    self.stacking_order.output(logger)
  }
  if !self.paint.should_render() {
    logger.write_string(" [hidden]")
  }
  if self.paint.opacity < 1.0 {
    logger.write_string(" opacity:")
    self.paint.opacity.output(logger)
  }
  if self.clips_content() {
    logger.write_string(" [clips]")
  }
}

///|
pub fn PaintNode::clips_content(self : PaintNode) -> Bool {
  let overflow_clips = match (self.overflow_x, self.overflow_y) {
    (@types.Visible, @types.Visible) => false
    _ => true
  }
  let clip_clips = match self.clip {
    @types.ClipRect::Auto => false
    @types.ClipRect::Rect(_) => true
  }
  overflow_clips || clip_clips
}

///|
pub fn PaintNode::has_horizontal_scrollbar(self : PaintNode) -> Bool {
  match self.overflow_x {
    @types.Overflow::Scroll => true
    @types.Overflow::Auto => self.scroll_width > self.width
    _ => false
  }
}

///|
pub fn PaintNode::has_vertical_scrollbar(self : PaintNode) -> Bool {
  match self.overflow_y {
    @types.Overflow::Scroll => true
    @types.Overflow::Auto => self.scroll_height > self.height
    _ => false
  }
}

///|
pub fn PaintNode::is_scrollable(self : PaintNode) -> Bool {
  self.has_horizontal_scrollbar() || self.has_vertical_scrollbar()
}

///|
pub fn PaintNode::get_max_scroll(self : PaintNode) -> (Double, Double) {
  let max_x = if self.scroll_width > self.width {
    self.scroll_width - self.width
  } else {
    0.0
  }
  let max_y = if self.scroll_height > self.height {
    self.scroll_height - self.height
  } else {
    0.0
  }
  (max_x, max_y)
}

///|
pub fn PaintNode::has_legacy_clip(self : PaintNode) -> Bool {
  match self.clip {
    @types.ClipRect::Auto => false
    @types.ClipRect::Rect(_) => true
  }
}

///|
pub fn PaintNode::get_legacy_clip(
  self : PaintNode,
) -> (Double, Double, Double, Double)? {
  match self.clip {
    @types.ClipRect::Auto => None
    @types.ClipRect::Rect(top~, right~, bottom~, left~) =>
      Some((top, right, bottom, left))
  }
}

///|
pub fn PaintNode::get_clip_rect(
  self : PaintNode,
) -> (Double, Double, Double, Double)? {
  match self.clip {
    @types.ClipRect::Rect(top~, right~, bottom~, left~) => {
      let clip_x = self.x + left
      let clip_y = self.y + top
      let clip_width = right - left
      let clip_height = bottom - top
      Some((clip_x, clip_y, clip_width, clip_height))
    }
    @types.ClipRect::Auto =>
      match (self.overflow_x, self.overflow_y) {
        (@types.Visible, @types.Visible) => None
        _ => Some((self.x, self.y, self.width, self.height))
      }
  }
}
