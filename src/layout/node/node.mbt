///|
/// Global counter for generating unique node IDs
let node_uid_counter : Ref[Int] = { val: 0 }

///|
/// Generate a new unique node ID
fn next_uid() -> Int {
  let uid = node_uid_counter.val
  node_uid_counter.val = uid + 1
  uid
}

///|
/// A node in the layout tree
pub struct Node {
  id : String
  uid : Int // Unique identifier for caching
  style : @style.Style
  children : Array[Node]
  measure : @types.MeasureFunc?
  text : String? // Text content for text nodes
}

///|
pub fn Node::new(
  id : String,
  style : @style.Style,
  children : Array[Node],
) -> Node {
  { id, uid: next_uid(), style, children, measure: None, text: None }
}

///|
/// Create a node with a specific uid (for incremental layout)
pub fn Node::with_uid(
  id : String,
  uid : Int,
  style : @style.Style,
  children : Array[Node],
) -> Node {
  { id, uid, style, children, measure: None, text: None }
}

///|
/// Create a node with a specific uid and measure function
pub fn Node::with_uid_and_measure(
  id : String,
  uid : Int,
  style : @style.Style,
  children : Array[Node],
  measure : @types.MeasureFunc?,
  text : String?,
) -> Node {
  { id, uid, style, children, measure, text }
}

///|
pub fn Node::leaf(id : String, style : @style.Style) -> Node {
  { id, uid: next_uid(), style, children: [], measure: None, text: None }
}

///|
/// Create a leaf node with a custom measure function
/// Optional text parameter for alt text (images) or other content
pub fn Node::with_measure(
  id : String,
  style : @style.Style,
  measure : @types.MeasureFunc,
  text? : String,
) -> Node {
  { id, uid: next_uid(), style, children: [], measure: Some(measure), text }
}

///|
/// Create a text node with content
pub fn Node::text(
  id : String,
  style : @style.Style,
  measure : @types.MeasureFunc,
  content : String,
) -> Node {
  {
    id,
    uid: next_uid(),
    style,
    children: [],
    measure: Some(measure),
    text: Some(content),
  }
}

///|
/// Layout dispatch function type
/// Used to delegate layout computation to the appropriate algorithm based on display type
pub(all) struct LayoutDispatchFunc(
  (Node, @types.LayoutContext) -> @types.Layout
)

///|
/// Global layout dispatch function
/// Set this before layout computation to enable cross-layout-type dispatch
let layout_dispatcher : Ref[LayoutDispatchFunc?] = { val: None }

///|
/// Set the global layout dispatcher
pub fn set_layout_dispatcher(f : LayoutDispatchFunc) -> Unit {
  layout_dispatcher.val = Some(f)
}

///|
/// Get the global layout dispatcher (for checking if it's set)
pub fn get_layout_dispatcher() -> LayoutDispatchFunc? {
  layout_dispatcher.val
}

///|
/// Compute layout for a node using the global dispatcher
/// Falls back to returning a minimal layout if no dispatcher is set
pub fn dispatch_layout(
  node : Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  match layout_dispatcher.val {
    Some(LayoutDispatchFunc(f)) => f(node, ctx)
    None => {
      // Fallback: create minimal layout from node dimensions
      let width = match node.style.width {
        @types.Dimension::Length(w) => w
        @types.Dimension::Percent(p) => ctx.available_width * p
        @types.Dimension::Auto => ctx.available_width
        @types.Dimension::MinContent => 0.0 // Fallback: use minimal size
        @types.Dimension::MaxContent => ctx.available_width
        @types.Dimension::FitContent(_) => ctx.available_width
      }
      let height = match node.style.height {
        @types.Dimension::Length(h) => h
        @types.Dimension::Percent(p) => ctx.available_height.unwrap_or(0.0) * p
        @types.Dimension::Auto => 0.0
        @types.Dimension::MinContent => 0.0
        @types.Dimension::MaxContent => 0.0
        @types.Dimension::FitContent(_) => 0.0
      }
      {
        id: node.id,
        x: 0.0,
        y: 0.0,
        width,
        height,
        margin: @types.Rect::zero(),
        padding: @types.Rect::zero(),
        border: @types.Rect::zero(),
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        children: [],
        text: node.text,
      }
    }
  }
}
