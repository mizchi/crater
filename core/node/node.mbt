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
  mut uid : Int // Unique identifier for caching (stabilized across re-renders for incremental reflow)
  style : @style.Style
  children : Array[Node]
  measure : @layout_types.MeasureFunc?
  text : String? // Text content for text nodes
  src : String? // Image source for replaced image content
  /// Originating `@dom.DomTree` node id, when this render node was built from a
  /// live DOM (the dynamic-rendering path). `None` for the static parse path.
  /// A stable, mutation-surviving identity used to key incremental reflow (see
  /// docs/incremental-reflow-design.md); does not affect layout or cascade.
  mut dom_id : Int?
}

///|
/// Attach the originating DomTree node id (dynamic-rendering path).
pub fn Node::set_dom_id(self : Node, dom_id : Int?) -> Unit {
  self.dom_id = dom_id
}

///|
/// Overwrite the cache uid. Used to stabilize uids across re-renders so
/// incremental reflow can match a rebuilt node to its prior layout (see
/// `stabilize_uids`).
pub fn Node::set_uid(self : Node, uid : Int) -> Unit {
  self.uid = uid
}

///|
pub fn Node::new(
  id : String,
  style : @style.Style,
  children : Array[Node],
) -> Node {
  {
    id,
    uid: next_uid(),
    style,
    children,
    measure: None,
    text: None,
    src: None,
    dom_id: None,
  }
}

///|
/// Create a node with a specific uid (for incremental layout)
pub fn Node::with_uid(
  id : String,
  uid : Int,
  style : @style.Style,
  children : Array[Node],
) -> Node {
  {
    id,
    uid,
    style,
    children,
    measure: None,
    text: None,
    src: None,
    dom_id: None,
  }
}

///|
/// Create a node with a specific uid and measure function
pub fn Node::with_uid_and_measure(
  id : String,
  uid : Int,
  style : @style.Style,
  children : Array[Node],
  measure : @layout_types.MeasureFunc?,
  text : String?,
  src? : String? = None,
) -> Node {
  { id, uid, style, children, measure, text, src, dom_id: None }
}

///|
pub fn Node::leaf(id : String, style : @style.Style) -> Node {
  {
    id,
    uid: next_uid(),
    style,
    children: [],
    measure: None,
    text: None,
    src: None,
    dom_id: None,
  }
}

///|
/// Create a leaf node with a custom measure function
/// Optional text parameter for alt text (images) or other content
pub fn Node::with_measure(
  id : String,
  style : @style.Style,
  measure : @layout_types.MeasureFunc,
  text? : String,
  src? : String? = None,
) -> Node {
  {
    id,
    uid: next_uid(),
    style,
    children: [],
    measure: Some(measure),
    text,
    src,
    dom_id: None,
  }
}

///|
/// Create a text node with content
pub fn Node::text(
  id : String,
  style : @style.Style,
  measure : @layout_types.MeasureFunc,
  content : String,
) -> Node {
  {
    id,
    uid: next_uid(),
    style,
    children: [],
    measure: Some(measure),
    text: Some(content),
    src: None,
    dom_id: None,
  }
}

///|
/// Dispatch function type - passed through layout computation to enable
/// cross-layout-type dispatch without global state.
/// The function takes (node, context, dispatch) and returns Layout.
pub(all) struct DispatchFn(
  (Node, @layout_types.LayoutContext, DispatchFn) -> @layout_types.Layout
)

///|
/// @deprecated Use DispatchFn instead
/// Layout dispatch function type (kept for backward compatibility with incremental compute)
pub(all) struct LayoutDispatchFunc(
  (Node, @layout_types.LayoutContext) -> @layout_types.Layout
)

///|
/// Global layout dispatch function (for incremental compute caching)
let layout_dispatcher : Ref[LayoutDispatchFunc?] = { val: None }

///|
/// Set the global layout dispatcher (used by incremental compute for caching)
pub fn set_layout_dispatcher(f : LayoutDispatchFunc) -> Unit {
  layout_dispatcher.val = Some(f)
}

///|
/// Get the global layout dispatcher
pub fn get_layout_dispatcher() -> LayoutDispatchFunc? {
  layout_dispatcher.val
}

///|
/// Create a minimal fallback layout for a node (used when dispatch is unavailable)
pub fn fallback_layout(
  node : Node,
  ctx : @layout_types.LayoutContext,
) -> @layout_types.Layout {
  let width = match node.style.width {
    @types.Dimension::Length(w) => w
    @types.Dimension::Percent(p) => ctx.available_width * p
    @types.Dimension::Auto => ctx.available_width
    @types.Dimension::MinContent => 0.0
    @types.Dimension::MaxContent => ctx.available_width
    @types.Dimension::FitContent(_) => ctx.available_width
    @types.Dimension::Calc(px, pct) => ctx.available_width * pct + px
    @types.Dimension::MathFn(op, terms) =>
      @types.apply_math_op(
        op,
        terms.map(fn(t) { t.0 + t.1 * ctx.available_width }),
      )
  }
  let height = match node.style.height {
    @types.Dimension::Length(h) => h
    @types.Dimension::Percent(p) => ctx.available_height.unwrap_or(0.0) * p
    @types.Dimension::Auto => 0.0
    @types.Dimension::MinContent => 0.0
    @types.Dimension::MaxContent => 0.0
    @types.Dimension::FitContent(_) => 0.0
    @types.Dimension::Calc(px, pct) =>
      ctx.available_height.unwrap_or(0.0) * pct + px
    @types.Dimension::MathFn(op, terms) =>
      @types.apply_math_op(
        op,
        terms.map(fn(t) { t.0 + t.1 * ctx.available_height.unwrap_or(0.0) }),
      )
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
    scroll_width: width,
    scroll_height: height,
    children: [],
    text: node.text,
  }
}

///|
/// Allocation-free prefix test. `String::has_prefix` in core uses Boyer-Moore-
/// Horspool and allocates a skip table per call; layout calls it per node (text
/// detection via `id.has_prefix("#text")`), which made it the single largest
/// allocation site in the render pipeline. This compares the prefix directly.
pub fn str_has_prefix(s : String, prefix : String) -> Bool {
  let plen = prefix.length()
  if plen == 0 {
    return true
  }
  if s.length() < plen {
    return false
  }
  for i = 0; i < plen; i = i + 1 {
    if s[i].to_int() != prefix[i].to_int() {
      return false
    }
  }
  true
}
