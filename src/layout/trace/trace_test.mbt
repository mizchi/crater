// =============================================================================
// Tests for Layout Dependency Tracing
// =============================================================================

///|
/// Default dispatch for tests
fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    @flex.compute(node, ctx, dispatch)
  })
}

///|
test "trace_simple_layout" {
  // Create a simple parent-child structure
  let child = @node.Node::leaf("child", {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let parent = @node.Node::new(
    "parent",
    {
      ..@style.Style::default(),
      display: @types.Flex,
      width: @types.Length(200.0),
      height: @types.Length(100.0),
    },
    [child],
  )
  // Compute layout with tracing
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  let result = @flex.compute_with_trace(parent, ctx, default_dispatch())
  // Verify traces were collected
  let parent_trace = result.tracer.get_trace(parent.uid)
  assert_true(parent_trace is Some(_))
  let pt = parent_trace.unwrap()
  // Check parent output matches layout
  assert_eq(pt.output.width, 200.0)
  assert_eq(pt.output.height, 100.0)
  // Check child trace
  let child_trace = result.tracer.get_trace(child.uid)
  assert_true(child_trace is Some(_))
  let ct = child_trace.unwrap()
  assert_eq(ct.output.width, 50.0)
  assert_eq(ct.output.height, 30.0)
}

///|
test "trace_dependencies_recorded" {
  let child1 = @node.Node::leaf("child1", {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(40.0),
  })
  let parent = @node.Node::new(
    "parent",
    {
      ..@style.Style::default(),
      display: @types.Flex,
      width: @types.Length(200.0),
    },
    [child1, child2],
  )
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: None,
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  let result = @flex.compute_with_trace(parent, ctx, default_dispatch())
  // Parent should have dependencies on children's intrinsic sizes
  let parent_trace = result.tracer.get_trace(parent.uid)
  assert_true(parent_trace is Some(_))
  let pt = parent_trace.unwrap()
  // Should have ParentWidth and ChildIntrinsicMain dependencies
  assert_true(pt.dependencies.length() >= 1) // At least ParentWidth
  // Check that ParentWidth is recorded
  let has_parent_width = pt.dependencies
    .iter()
    .any(fn(d) {
      match d {
        @trace.ParentWidth => true
        _ => false
      }
    })
  assert_true(has_parent_width)
  // Check that children intrinsic dependencies are recorded
  let child1_dep_found = pt.dependencies
    .iter()
    .any(fn(d) {
      match d {
        @trace.ChildIntrinsicMain(uid) => uid == child1.uid
        _ => false
      }
    })
  assert_true(child1_dep_found)
  let child2_dep_found = pt.dependencies
    .iter()
    .any(fn(d) {
      match d {
        @trace.ChildIntrinsicMain(uid) => uid == child2.uid
        _ => false
      }
    })
  assert_true(child2_dep_found)
}

///|
test "trace_unique_uids" {
  // Ensure each node has a unique uid
  let child1 = @node.Node::leaf("a", @style.Style::default())
  let child2 = @node.Node::leaf("a", @style.Style::default()) // Same id, different uid
  let child3 = @node.Node::leaf("a", @style.Style::default())
  // All should have different uids
  assert_true(child1.uid != child2.uid)
  assert_true(child2.uid != child3.uid)
  assert_true(child1.uid != child3.uid)
}

///|
test "trace_needs_recompute" {
  let node = @node.Node::leaf("test", {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let ctx1 : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  let result = @flex.compute_with_trace(node, ctx1, default_dispatch())
  // Same context should not need recompute
  assert_eq(result.tracer.needs_recompute(node.uid, ctx1), false)
  // Different width should need recompute
  let ctx2 : @types.LayoutContext = {
    available_width: 500.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  assert_eq(result.tracer.needs_recompute(node.uid, ctx2), true)
  // Different height should need recompute
  let ctx3 : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(400.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  assert_eq(result.tracer.needs_recompute(node.uid, ctx3), true)
  // Unknown node should need recompute
  let unknown = @node.Node::leaf("unknown", @style.Style::default())
  assert_eq(result.tracer.needs_recompute(unknown.uid, ctx1), true)
}

///|
test "trace_nested_structure" {
  // Create a nested structure: parent -> middle -> leaf
  let leaf = @node.Node::leaf("leaf", {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  })
  let middle = @node.Node::new(
    "middle",
    {
      ..@style.Style::default(),
      display: @types.Flex,
      width: @types.Length(60.0),
      height: @types.Length(60.0),
    },
    [leaf],
  )
  let parent = @node.Node::new(
    "parent",
    {
      ..@style.Style::default(),
      display: @types.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [middle],
  )
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  let result = @flex.compute_with_trace(parent, ctx, default_dispatch())
  // All three nodes should have traces
  assert_true(result.tracer.get_trace(parent.uid) is Some(_))
  assert_true(result.tracer.get_trace(middle.uid) is Some(_))
  assert_true(result.tracer.get_trace(leaf.uid) is Some(_))
  // Verify traced nodes count
  let traced_nodes = result.tracer.get_traced_nodes()
  assert_eq(traced_nodes.length(), 3)
}
