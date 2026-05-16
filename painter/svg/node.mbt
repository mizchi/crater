///|
/// SVG node (element in the scene graph)
pub(all) struct SVGNode {
  mut id : String
  mut shape : Shape
  mut transform : Transform
  mut fill : Paint
  mut fill_rule : FillRule
  mut fill_opacity : Double
  mut stroke : StrokeStyle
  mut stroke_opacity : Double
  mut opacity : Double
  mut z_index : Int // Layer order (higher = front)
  mut node_dirty : Bool // Per-node dirty flag
  mut prev_bounds : BoundingBox? // Previous bounding box for dirty rect
  mut filters : Array[Filter] // Filter effects to apply
  mut mask_id : String? // Reference to mask by ID
  mut clip_path_id : String? // Reference to clip path by ID
  children : Array[SVGNode]
}

///|
pub fn SVGNode::new(shape : Shape) -> SVGNode {
  {
    id: "",
    shape,
    transform: Transform::identity(),
    fill: SolidColor(Color::black()),
    fill_rule: NonZero,
    fill_opacity: 1.0,
    stroke: StrokeStyle::default(),
    stroke_opacity: 1.0,
    opacity: 1.0,
    z_index: 0,
    node_dirty: true,
    prev_bounds: None,
    filters: [],
    mask_id: None,
    clip_path_id: None,
    children: [],
  }
}

///|
/// Add a filter to the node
pub fn SVGNode::add_filter(self : SVGNode, filter : Filter) -> Unit {
  let node = self.to_msvg()
  node.add_filter(filter_to_msvg(filter))
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear all filters from the node
pub fn SVGNode::clear_filters(self : SVGNode) -> Unit {
  let node = self.to_msvg()
  node.clear_filters()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Set mask reference by ID
pub fn SVGNode::set_mask(self : SVGNode, mask_id : String) -> Unit {
  let node = self.to_msvg()
  node.set_mask(mask_id)
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear mask reference
pub fn SVGNode::clear_mask(self : SVGNode) -> Unit {
  let node = self.to_msvg()
  node.clear_mask()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Set clip path reference by ID
pub fn SVGNode::set_clip_path(self : SVGNode, clip_path_id : String) -> Unit {
  let node = self.to_msvg()
  node.set_clip_path(clip_path_id)
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear clip path reference
pub fn SVGNode::clear_clip_path(self : SVGNode) -> Unit {
  let node = self.to_msvg()
  node.clear_clip_path()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Mark a node as dirty (needs re-render)
pub fn SVGNode::mark_dirty(self : SVGNode) -> Unit {
  let node = self.to_msvg()
  node.mark_dirty()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear the dirty flag
pub fn SVGNode::clear_dirty(self : SVGNode) -> Unit {
  let node = self.to_msvg()
  node.clear_dirty()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clone an SVGNode
pub fn SVGNode::clone(self : SVGNode) -> SVGNode {
  SVGNode::from_msvg(self.to_msvg().clone())
}

///|
fn SVGNode::sync_animation_state_from_msvg(
  self : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  let current_color = Color::from_msvg_option(source.color)
  self.transform = Transform::from_msvg(source.transform)
  self.fill = paint_from_msvg(source.fill, current_color)
  self.opacity = source.opacity
}

///|
fn SVGNode::to_msvg(self : SVGNode) -> @msvg.SVGNode {
  let node = @msvg.SVGNode::new(self.shape.to_msvg())
  node.id = self.id
  node.transform = self.transform.to_msvg()
  node.fill = paint_to_msvg(self.fill)
  node.fill_rule = fill_rule_to_msvg(self.fill_rule)
  node.fill_opacity = self.fill_opacity
  node.stroke = stroke_style_to_msvg(self.stroke)
  node.stroke_opacity = self.stroke_opacity
  node.opacity = self.opacity
  node.z_index = self.z_index
  node.node_dirty = self.node_dirty
  node.prev_bounds = match self.prev_bounds {
    Some(bbox) => Some(bbox.to_msvg())
    None => None
  }
  node.filters = self.filters.map(filter_to_msvg)
  node.mask_id = self.mask_id
  node.clip_path_id = self.clip_path_id
  for child in self.children {
    node.children.push(child.to_msvg())
  }
  node
}

///|
fn SVGNode::from_msvg(source : @msvg.SVGNode) -> SVGNode {
  let current_color = Color::from_msvg_option(source.color)
  let node = SVGNode::new(Shape::from_msvg(source.shape))
  node.id = source.id
  node.transform = Transform::from_msvg(source.transform)
  node.fill = paint_from_msvg(source.fill, current_color)
  node.fill_rule = fill_rule_from_msvg(source.fill_rule)
  node.fill_opacity = source.fill_opacity
  node.stroke = stroke_style_from_msvg(source.stroke, current_color)
  node.stroke_opacity = source.stroke_opacity
  node.opacity = source.opacity
  node.z_index = source.z_index
  node.node_dirty = source.node_dirty
  node.prev_bounds = BoundingBox::from_msvg_option(source.prev_bounds)
  node.filters = source.filters.map(filter_from_msvg)
  node.mask_id = source.mask_id
  node.clip_path_id = source.clip_path_id
  for child in source.children {
    node.children.push(SVGNode::from_msvg(child))
  }
  node
}

///|
fn SVGNode::sync_animation_tree_state_from_msvg(
  self : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  self.sync_animation_state_from_msvg(source)
  let len = if self.children.length() < source.children.length() {
    self.children.length()
  } else {
    source.children.length()
  }
  for i = 0; i < len; i = i + 1 {
    self.children[i].sync_animation_tree_state_from_msvg(source.children[i])
  }
}
