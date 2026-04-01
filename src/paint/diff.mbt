///|
pub(all) struct PaintPropertyChange {
  node_path : String
  node_id : String
  property : String
  before : String?
  after : String?
}

///|
pub(all) struct PaintLayoutShift {
  node_path : String
  node_id : String
  dx : Double
  dy : Double
  dw : Double
  dh : Double
}

///|
pub(all) struct PaintTreeDiff {
  changes : Array[PaintPropertyChange]
  layout_shifts : Array[PaintLayoutShift]
}

///|
priv struct FlatPaintNode {
  path : String
  node : PaintNode
}

///|
pub fn diff_trees(before : PaintNode, after : PaintNode) -> PaintTreeDiff {
  let before_nodes : Array[FlatPaintNode] = []
  let after_nodes : Array[FlatPaintNode] = []
  let before_by_path : Map[String, FlatPaintNode] = {}
  let after_by_path : Map[String, FlatPaintNode] = {}
  collect_flat_nodes(before, before.tag + "[0]", before_nodes, before_by_path)
  collect_flat_nodes(after, after.tag + "[0]", after_nodes, after_by_path)

  let changes : Array[PaintPropertyChange] = []
  let layout_shifts : Array[PaintLayoutShift] = []

  for flat in before_nodes {
    match after_by_path.get(flat.path) {
      Some(other) => compare_nodes(flat, other, changes, layout_shifts)
      None =>
        changes.push({
          node_path: flat.path,
          node_id: flat.node.id,
          property: "node_presence",
          before: Some("present"),
          after: None,
        })
    }
  }

  for flat in after_nodes {
    if before_by_path.get(flat.path) is None {
      changes.push({
        node_path: flat.path,
        node_id: flat.node.id,
        property: "node_presence",
        before: None,
        after: Some("present"),
      })
    }
  }

  { changes, layout_shifts }
}

///|
fn collect_flat_nodes(
  node : PaintNode,
  path : String,
  flat_nodes : Array[FlatPaintNode],
  by_path : Map[String, FlatPaintNode],
) -> Unit {
  let flat = { path, node }
  flat_nodes.push(flat)
  by_path.set(path, flat)
  for i, child in node.children {
    collect_flat_nodes(
      child,
      path + "/" + child.tag + "[" + i.to_string() + "]",
      flat_nodes,
      by_path,
    )
  }
}

///|
fn compare_nodes(
  before : FlatPaintNode,
  after : FlatPaintNode,
  changes : Array[PaintPropertyChange],
  layout_shifts : Array[PaintLayoutShift],
) -> Unit {
  let before_node = before.node
  let after_node = after.node

  if before_node.x != after_node.x ||
    before_node.y != after_node.y ||
    before_node.width != after_node.width ||
    before_node.height != after_node.height {
    layout_shifts.push({
      node_path: before.path,
      node_id: after_node.id,
      dx: after_node.x - before_node.x,
      dy: after_node.y - before_node.y,
      dw: after_node.width - before_node.width,
      dh: after_node.height - before_node.height,
    })
  }

  compare_string_property(
    before.path,
    before_node.id,
    "id",
    before_node.id,
    after_node.id,
    changes,
  )
  compare_string_property(
    before.path,
    before_node.id,
    "tag",
    before_node.tag,
    after_node.tag,
    changes,
  )
  compare_optional_string_property(
    before.path,
    before_node.id,
    "text",
    before_node.text,
    after_node.text,
    changes,
  )
  compare_optional_string_property(
    before.path,
    before_node.id,
    "src",
    before_node.src,
    after_node.src,
    changes,
  )
  compare_double_property(
    before.path,
    before_node.id,
    "scroll_width",
    before_node.scroll_width,
    after_node.scroll_width,
    changes,
  )
  compare_double_property(
    before.path,
    before_node.id,
    "scroll_height",
    before_node.scroll_height,
    after_node.scroll_height,
    changes,
  )
  compare_string_property(
    before.path,
    before_node.id,
    "clip",
    before_node.clip.to_string(),
    after_node.clip.to_string(),
    changes,
  )
  compare_string_property(
    before.path,
    before_node.id,
    "overflow_x",
    overflow_to_string(before_node.overflow_x),
    overflow_to_string(after_node.overflow_x),
    changes,
  )
  compare_string_property(
    before.path,
    before_node.id,
    "overflow_y",
    overflow_to_string(before_node.overflow_y),
    overflow_to_string(after_node.overflow_y),
    changes,
  )
  compare_paint_properties(
    before.path,
    before_node.id,
    before_node.paint,
    after_node.paint,
    changes,
  )
}

///|
fn compare_paint_properties(
  path : String,
  node_id : String,
  before : PaintProperties,
  after : PaintProperties,
  changes : Array[PaintPropertyChange],
) -> Unit {
  compare_string_property(
    path,
    node_id,
    "z_index",
    before.z_index.to_string(),
    after.z_index.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "visibility",
    before.visibility.to_string(),
    after.visibility.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "pointer_events",
    before.pointer_events.to_string(),
    after.pointer_events.to_string(),
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "opacity",
    before.opacity,
    after.opacity,
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "color",
    before.color.to_string(),
    after.color.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "background_color",
    before.background_color.to_string(),
    after.background_color.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "background_image",
    before.background_image.to_string(),
    after.background_image.to_string(),
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "font_size",
    before.font_size,
    after.font_size,
    changes,
  )
  compare_bool_property(
    path,
    node_id,
    "is_bold",
    before.is_bold,
    after.is_bold,
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "font_family",
    before.font_family,
    after.font_family,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_top_left_radius",
    before.border_top_left_radius,
    after.border_top_left_radius,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_top_right_radius",
    before.border_top_right_radius,
    after.border_top_right_radius,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_bottom_right_radius",
    before.border_bottom_right_radius,
    after.border_bottom_right_radius,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_bottom_left_radius",
    before.border_bottom_left_radius,
    after.border_bottom_left_radius,
    changes,
  )
  compare_bool_property(
    path,
    node_id,
    "text_decoration_underline",
    before.text_decoration_underline,
    after.text_decoration_underline,
    changes,
  )
  compare_bool_property(
    path,
    node_id,
    "text_decoration_line_through",
    before.text_decoration_line_through,
    after.text_decoration_line_through,
    changes,
  )
  compare_bool_property(
    path,
    node_id,
    "text_decoration_overline",
    before.text_decoration_overline,
    after.text_decoration_overline,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_top_width",
    before.border_top_width,
    after.border_top_width,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_right_width",
    before.border_right_width,
    after.border_right_width,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_bottom_width",
    before.border_bottom_width,
    after.border_bottom_width,
    changes,
  )
  compare_double_property(
    path,
    node_id,
    "border_left_width",
    before.border_left_width,
    after.border_left_width,
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "border_top_color",
    before.border_top_color.to_string(),
    after.border_top_color.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "border_right_color",
    before.border_right_color.to_string(),
    after.border_right_color.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "border_bottom_color",
    before.border_bottom_color.to_string(),
    after.border_bottom_color.to_string(),
    changes,
  )
  compare_string_property(
    path,
    node_id,
    "border_left_color",
    before.border_left_color.to_string(),
    after.border_left_color.to_string(),
    changes,
  )
}

///|
fn compare_bool_property(
  path : String,
  node_id : String,
  property : String,
  before : Bool,
  after : Bool,
  changes : Array[PaintPropertyChange],
) -> Unit {
  if before != after {
    changes.push({
      node_path: path,
      node_id,
      property,
      before: Some(before.to_string()),
      after: Some(after.to_string()),
    })
  }
}

///|
fn compare_double_property(
  path : String,
  node_id : String,
  property : String,
  before : Double,
  after : Double,
  changes : Array[PaintPropertyChange],
) -> Unit {
  if before != after {
    changes.push({
      node_path: path,
      node_id,
      property,
      before: Some(before.to_string()),
      after: Some(after.to_string()),
    })
  }
}

///|
fn compare_string_property(
  path : String,
  node_id : String,
  property : String,
  before : String,
  after : String,
  changes : Array[PaintPropertyChange],
) -> Unit {
  if before != after {
    changes.push({
      node_path: path,
      node_id,
      property,
      before: Some(before),
      after: Some(after),
    })
  }
}

///|
fn compare_optional_string_property(
  path : String,
  node_id : String,
  property : String,
  before : String?,
  after : String?,
  changes : Array[PaintPropertyChange],
) -> Unit {
  if before != after {
    changes.push({ node_path: path, node_id, property, before, after })
  }
}

///|
fn overflow_to_string(value : @types.Overflow) -> String {
  match value {
    @types.Visible => "visible"
    @types.Hidden => "hidden"
    @types.Clip => "clip"
    @types.Scroll => "scroll"
    @types.Auto => "auto"
  }
}
