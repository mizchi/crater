// =============================================================================
// Layout Dependency Tracing
// =============================================================================
// This module provides infrastructure for tracking layout computation dependencies.
// It enables future incremental layout optimization by recording what each node
// reads during layout computation.

///|
/// The type of dependency a node has on another value
pub(all) enum DependencyKind {
  /// Read parent's available width
  ParentWidth
  /// Read parent's available height
  ParentHeight
  /// Read child's intrinsic main size
  ChildIntrinsicMain(Int) // child uid
  /// Read child's intrinsic cross size
  ChildIntrinsicCross(Int) // child uid
  /// Read sibling's computed size (for flex space distribution)
  SiblingSize(Int) // sibling uid
  /// Read own style property
  OwnStyle
} derive(Show, Eq)

///|
/// A single dependency record
pub(all) struct Dependency {
  /// The node that has this dependency
  node_uid : Int
  /// What kind of dependency
  kind : DependencyKind
} derive(Show)

///|
/// Input context snapshot for a node's layout computation
pub(all) struct ComputeInput {
  node_uid : Int
  available_width : Double
  available_height : Double?
  sizing_mode : @types.SizingMode
}

///|
/// Output snapshot for a node's layout computation
pub(all) struct ComputeOutput {
  node_uid : Int
  width : Double
  height : Double
} derive(Show)

///|
/// A trace record for one node's computation
pub(all) struct NodeTrace {
  input : ComputeInput
  output : ComputeOutput
  dependencies : Array[DependencyKind]
}

///|
/// Collector for layout traces during computation
pub struct LayoutTracer {
  /// Map from node_uid to its trace
  traces : Map[Int, NodeTrace]
  /// Whether tracing is enabled
  enabled : Bool
}

///|
pub fn LayoutTracer::new(enabled : Bool) -> LayoutTracer {
  { traces: {}, enabled }
}

///|
/// Create a disabled tracer (no-op for performance)
pub fn LayoutTracer::disabled() -> LayoutTracer {
  { traces: {}, enabled: false }
}

///|
/// Check if tracing is enabled
pub fn LayoutTracer::is_enabled(self : LayoutTracer) -> Bool {
  self.enabled
}

///|
/// Record computation input for a node
pub fn LayoutTracer::begin_compute(
  self : LayoutTracer,
  node_uid : Int,
  ctx : @types.LayoutContext,
) -> Unit {
  if not(self.enabled) {
    return
  }
  let input : ComputeInput = {
    node_uid,
    available_width: ctx.available_width,
    available_height: ctx.available_height,
    sizing_mode: ctx.sizing_mode,
  }
  // Initialize trace with empty output (will be filled in end_compute)
  let trace : NodeTrace = {
    input,
    output: { node_uid, width: 0.0, height: 0.0 },
    dependencies: [],
  }
  self.traces.set(node_uid, trace)
}

///|
/// Record computation output for a node
pub fn LayoutTracer::end_compute(
  self : LayoutTracer,
  node_uid : Int,
  width : Double,
  height : Double,
) -> Unit {
  if not(self.enabled) {
    return
  }
  match self.traces.get(node_uid) {
    Some(trace) => {
      let updated : NodeTrace = {
        input: trace.input,
        output: { node_uid, width, height },
        dependencies: trace.dependencies,
      }
      self.traces.set(node_uid, updated)
    }
    None => ()
  }
}

///|
/// Record a dependency for the current node
pub fn LayoutTracer::add_dependency(
  self : LayoutTracer,
  node_uid : Int,
  kind : DependencyKind,
) -> Unit {
  if not(self.enabled) {
    return
  }
  match self.traces.get(node_uid) {
    Some(trace) => trace.dependencies.push(kind)
    None => ()
  }
}

///|
/// Get all recorded traces
pub fn LayoutTracer::get_traces(self : LayoutTracer) -> Map[Int, NodeTrace] {
  self.traces
}

///|
/// Get trace for a specific node
pub fn LayoutTracer::get_trace(
  self : LayoutTracer,
  node_uid : Int,
) -> NodeTrace? {
  self.traces.get(node_uid)
}

///|
/// Get all node UIDs that were traced
pub fn LayoutTracer::get_traced_nodes(self : LayoutTracer) -> Array[Int] {
  let result : Array[Int] = []
  self.traces.each(fn(uid, _) { result.push(uid) })
  result
}

///|
/// Check if a node's output would change given a new input
/// Returns true if recomputation is needed
pub fn LayoutTracer::needs_recompute(
  self : LayoutTracer,
  node_uid : Int,
  new_ctx : @types.LayoutContext,
) -> Bool {
  match self.traces.get(node_uid) {
    Some(trace) => {
      // Compare input contexts
      let old = trace.input
      if old.available_width != new_ctx.available_width {
        return true
      }
      match (old.available_height, new_ctx.available_height) {
        (Some(a), Some(b)) if a != b => return true
        (Some(_), None) | (None, Some(_)) => return true
        _ => ()
      }
      // If context is the same, no recompute needed
      false
    }
    None => true // No trace means we need to compute
  }
}

///|
/// Clear all traces (no-op - create new LayoutTracer instead)
pub fn LayoutTracer::clear(_self : LayoutTracer) -> Unit {
  // Note: Map doesn't have clear() in MoonBit
  // Caller should create new LayoutTracer if needed
  ()
}

///|
/// Collect traces by walking the node tree and matching with layout results.
/// This is a post-hoc collection that doesn't require modifying compute_internal.
pub fn LayoutTracer::collect_from_tree(
  self : LayoutTracer,
  node : @node.Node,
  layout : @types.Layout,
  ctx : @types.LayoutContext,
) -> Unit {
  if not(self.enabled) {
    return
  }
  // Record this node's trace
  let input : ComputeInput = {
    node_uid: node.uid,
    available_width: ctx.available_width,
    available_height: ctx.available_height,
    sizing_mode: ctx.sizing_mode,
  }
  let output : ComputeOutput = {
    node_uid: node.uid,
    width: layout.width,
    height: layout.height,
  }
  // Compute dependencies based on node structure
  let deps : Array[DependencyKind] = []
  deps.push(ParentWidth)
  match ctx.available_height {
    Some(_) => deps.push(ParentHeight)
    None => ()
  }
  // Children contribute intrinsic sizes
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    deps.push(ChildIntrinsicMain(child.uid))
  }
  let trace : NodeTrace = { input, output, dependencies: deps }
  self.traces.set(node.uid, trace)
  // Recursively process children
  // Match children by index (assumes layout.children corresponds to node.children)
  let min_len = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  for i = 0; i < min_len; i = i + 1 {
    let child_node = node.children[i]
    let child_layout = layout.children[i]
    // Child's context is based on parent's content area
    let child_ctx : @types.LayoutContext = {
      available_width: layout.width -
      layout.padding.left -
      layout.padding.right -
      layout.border.left -
      layout.border.right,
      available_height: Some(
        layout.height -
        layout.padding.top -
        layout.padding.bottom -
        layout.border.top -
        layout.border.bottom,
      ),
      sizing_mode: @types.Definite,
      viewport_width: ctx.viewport_width,
      viewport_height: ctx.viewport_height,
    }
    self.collect_from_tree(child_node, child_layout, child_ctx)
  }
}
