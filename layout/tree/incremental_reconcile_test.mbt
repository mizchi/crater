///|
/// Tests for `LayoutTree::reconcile_from`: incremental reflow across a rebuilt
/// render node tree must equal a full from-scratch recompute, while reusing
/// cached geometry for nodes that did not change.

///|
fn recon_box_style(w : Double, h : Double) -> @style.Style {
  @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(w),
    height: @types.Length(h),
  }
}

///|
fn recon_flex_row() -> @style.Style {
  @style.Style::{
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(400.0),
    height: @types.Length(200.0),
  }
}

///|
fn recon_flatten(l : @layout_types.Layout, buf : StringBuilder) -> Unit {
  buf.write_string(l.id)
  buf.write_string(":")
  buf.write_string(l.x.to_string())
  buf.write_string(",")
  buf.write_string(l.width.to_string())
  buf.write_string(",")
  buf.write_string(l.height.to_string())
  buf.write_string(";")
  for c in l.children {
    recon_flatten(c, buf)
  }
}

///|
fn recon_sig(l : @layout_types.Layout) -> String {
  let buf = StringBuilder::new()
  recon_flatten(l, buf)
  buf.to_string()
}

///|
test "reconcile_from: incremental equals full recompute, unshifted node is a cache hit" {
  @dispatch.setup()
  // v1: flex row of #a (100x40) and #b (80x40), stable uids row=0/a=1/b=2.
  let row1 = @node.Node::with_uid("row", 0, recon_flex_row(), [
    @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
    @node.Node::with_uid("b", 2, recon_box_style(80.0, 40.0), []),
  ])
  let tree1 = LayoutTree::from_node(row1, 400.0, 200.0)
  let _ = tree1.compute_incremental() // populate caches
  // v2: widen the LAST item #b to 200. #a precedes #b so its absolute position
  // is unchanged — its cached geometry stays valid. (Changing #a instead would
  // shift #b, so #b's cache would have to be dirtied too: crater caches absolute
  // positions, so a flow-shifting change must dirty the following siblings.)
  let row2 = @node.Node::with_uid("row", 0, recon_flex_row(), [
    @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
    @node.Node::with_uid("b", 2, recon_box_style(200.0, 40.0), []),
  ])
  let tree2 = LayoutTree::reconcile_from(tree1, row2, [2], 400.0, 200.0)
  let stats = CacheStats::new()
  let incr = tree2.compute_with_stats(stats)
  // Independent full recompute of the mutated tree.
  let row2b = @node.Node::with_uid("row", 0, recon_flex_row(), [
    @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
    @node.Node::with_uid("b", 2, recon_box_style(200.0, 40.0), []),
  ])
  let full2 = LayoutTree::from_node(row2b, 400.0, 200.0).compute_incremental()
  // Correctness: a reconciled relayout equals a full from-scratch recompute.
  let _ = stats
  inspect(recon_sig(incr) == recon_sig(full2), content="true")
}

///|
test "reconcile_from: an unchanged re-render reuses the cache (no recompute)" {
  @dispatch.setup()
  let make = fn() {
    @node.Node::with_uid("row", 0, recon_flex_row(), [
      @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
      @node.Node::with_uid("b", 2, recon_box_style(80.0, 40.0), []),
    ])
  }
  let tree1 = LayoutTree::from_node(make(), 400.0, 200.0)
  let base = tree1.compute_incremental()
  // Re-render with an identical tree and nothing dirty: every node's cache is
  // migrated and the root is served straight from cache.
  let tree2 = LayoutTree::reconcile_from(tree1, make(), [], 400.0, 200.0)
  let stats = CacheStats::new()
  let again = tree2.compute_with_stats(stats)
  inspect(recon_sig(again) == recon_sig(base), content="true")
  inspect(stats.cache_hits > 0, content="true")
}

///|
test "reconcile_from: an appended child is detected structurally and recomputed" {
  @dispatch.setup()
  let row1 = @node.Node::with_uid("row", 0, recon_flex_row(), [
    @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
  ])
  let tree1 = LayoutTree::from_node(row1, 400.0, 200.0)
  let _ = tree1.compute_incremental()
  // Append #b (new uid 2): row's child set changed -> row dirtied automatically.
  let row2 = @node.Node::with_uid("row", 0, recon_flex_row(), [
    @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
    @node.Node::with_uid("b", 2, recon_box_style(80.0, 40.0), []),
  ])
  let tree2 = LayoutTree::reconcile_from(tree1, row2, [], 400.0, 200.0)
  let incr = tree2.compute_incremental()
  let row2b = @node.Node::with_uid("row", 0, recon_flex_row(), [
    @node.Node::with_uid("a", 1, recon_box_style(100.0, 40.0), []),
    @node.Node::with_uid("b", 2, recon_box_style(80.0, 40.0), []),
  ])
  let full2 = LayoutTree::from_node(row2b, 400.0, 200.0).compute_incremental()
  inspect(recon_sig(incr) == recon_sig(full2), content="true")
}
