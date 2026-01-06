///|
/// Intrinsic size measurement result
pub(all) struct IntrinsicSize {
  min_width : Double
  max_width : Double
  min_height : Double
  max_height : Double
}

///|
/// Default intrinsic size for leaf nodes without measure function
/// Matches Taffy behavior: empty/unmeasured nodes have zero intrinsic size
pub fn IntrinsicSize::default() -> IntrinsicSize {
  { min_width: 0.0, max_width: 0.0, min_height: 0.0, max_height: 0.0 }
}

///|
/// Measure function type - called to determine intrinsic size of a node
/// Parameters: (available_width, available_height) -> IntrinsicSize
pub(all) struct MeasureFunc {
  func : (Double, Double) -> IntrinsicSize
}

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
  measure : MeasureFunc?
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
  measure : MeasureFunc?,
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
  measure : MeasureFunc,
  text? : String,
) -> Node {
  {
    id,
    uid: next_uid(),
    style,
    children: [],
    measure: Some(measure),
    text,
  }
}

///|
/// Create a text node with content
pub fn Node::text(
  id : String,
  style : @style.Style,
  measure : MeasureFunc,
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
/// Complete layout result for a node
pub(all) struct Layout {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  // Box model resolved values
  margin : @types.Rect[Double]
  padding : @types.Rect[Double]
  border : @types.Rect[Double]
  // Overflow clipping info
  overflow_x : @style.Overflow
  overflow_y : @style.Overflow
  // Children layouts
  children : Array[Layout]
  // Text content for text nodes
  text : String?
}

///|
pub fn Layout::to_bounding_rect(self : Layout) -> @types.BoundingRect {
  { x: self.x, y: self.y, width: self.width, height: self.height }
}

///|
/// Sizing mode for layout computation
/// Definite: Use available space (normal flow)
/// MaxContent: Use intrinsic max-content (shrink-to-fit)
pub(all) enum SizingMode {
  Definite
  MaxContent
} derive(Eq)

///|
/// Context for layout computation
pub(all) struct LayoutContext {
  /// Available width from parent
  available_width : Double
  /// Available height from parent (may be undefined)
  available_height : Double?
  /// Sizing mode (defaults to MaxContent for root-level intrinsic sizing)
  sizing_mode : SizingMode
  /// Viewport width for position: fixed elements
  viewport_width : Double
  /// Viewport height for position: fixed elements
  viewport_height : Double
}

///|
/// Warnings emitted during layout computation
pub(all) enum LayoutWarning {
  UnsupportedFloat(String) // node id with float: left/right
  UnsupportedPosition(String) // node id with position: absolute/fixed
  UnsupportedDisplay(String) // node id with unsupported display type
} derive(Show)

///|
/// Result of layout computation with warnings
pub(all) struct LayoutResult {
  layout : Layout
  warnings : Array[LayoutWarning]
}

///|
/// Layout dispatch function type
/// Used to delegate layout computation to the appropriate algorithm based on display type
pub(all) struct LayoutDispatchFunc((Node, LayoutContext) -> Layout)

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
pub fn dispatch_layout(node : Node, ctx : LayoutContext) -> Layout {
  match layout_dispatcher.val {
    Some(LayoutDispatchFunc(f)) => f(node, ctx)
    None => {
      // Fallback: create minimal layout from node dimensions
      let width = match node.style.width {
        @types.Length(w) => w
        @types.Percent(p) => ctx.available_width * p
        @types.Auto => ctx.available_width
        @types.MinContent => 0.0 // Fallback: use minimal size
        @types.MaxContent => ctx.available_width
        @types.FitContent(_) => ctx.available_width
      }
      let height = match node.style.height {
        @types.Length(h) => h
        @types.Percent(p) => ctx.available_height.unwrap_or(0.0) * p
        @types.Auto => 0.0
        @types.MinContent => 0.0
        @types.MaxContent => 0.0
        @types.FitContent(_) => 0.0
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
        overflow_x: @style.Visible,
        overflow_y: @style.Visible,
        children: [],
        text: node.text,
      }
    }
  }
}
