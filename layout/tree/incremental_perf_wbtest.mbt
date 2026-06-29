///|
/// Characterization of incremental-reflow cache effectiveness (item 3): when a
/// late element in a stack changes, how much preceding work is actually reused.
/// Whitebox so they can read `CacheStats`. These pin the *current* behavior and
/// the exact bottleneck driving the layout-engine perf lever (see
/// docs/incremental-reflow-design.md) — they are characterization tests, not a
/// target: when the block-flow cache lands they update to show reuse.
///
/// Finding: the per-uid layout cache (`try_cache_by_uid`) is only consulted for
/// children dispatched through the cache-aware callback — i.e. flex / grid /
/// table / inline-block BFC roots (block.mbt:5609). Ordinary in-flow block
/// children are laid out by `compute_with_collapse` directly (block.mbt:5623),
/// which never reads the cache, so a `display:block` stack recomputes in full
/// regardless of how little changed. A flex stack, by contrast, reuses the
/// cache for unchanged children.

///|
fn recon_flatten_perf(l : @layout_types.Layout, buf : StringBuilder) -> Unit {
  buf.write_string(l.id)
  buf.write_string(":")
  buf.write_string(l.x.to_string())
  buf.write_string(",")
  buf.write_string(l.y.to_string())
  buf.write_string(",")
  buf.write_string(l.width.to_string())
  buf.write_string(",")
  buf.write_string(l.height.to_string())
  buf.write_string(";")
  for c in l.children {
    recon_flatten_perf(c, buf)
  }
}

///|
fn recon_sig_perf(l : @layout_types.Layout) -> String {
  let buf = StringBuilder::new()
  recon_flatten_perf(l, buf)
  buf.to_string()
}

///|
fn perf_block(w : Double, h : Double) -> @style.Style {
  @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(w),
    height: @types.Length(h),
  }
}

///|
/// `n` fixed-size children under a root with `display`. Root uid 0; child #i
/// uid i+1; child `changed_idx` gets height `tweak`.
fn perf_stack(
  display : @types.Display,
  n : Int,
  changed_idx : Int,
  tweak : Double,
) -> @node.Node {
  let children : Array[@node.Node] = []
  for i = 0; i < n; i = i + 1 {
    let h = if i == changed_idx { tweak } else { 40.0 }
    children.push(@node.Node::with_uid("b" + i.to_string(), i + 1, perf_block(
      100.0, h,
    ), []))
  }
  let root_style = @style.Style::{ ..perf_block(200.0, 2000.0), display, }
  @node.Node::with_uid("root", 0, root_style, children)
}

///|
test "perf(block): changing the LAST block reuses every preceding block via block-flow memoization" {
  @dispatch.setup()
  let n = 12
  let tree1 = LayoutTree::from_node(
    perf_stack(@types.Block, n, -1, 40.0), 200.0, 2000.0,
  )
  @block.clear_block_flow_cache()
  let _ = tree1.compute_incremental() // populate the block-flow cache
  // Change the last block. It has no following siblings, so the dirty set is
  // just it — every preceding block is unchanged and reused from the block-flow
  // cache (compute_with_collapse is skipped for the 11 clean children).
  let dirty = tree1.flow_dirty_uids([n])
  inspect(dirty.length(), content="1")
  let tree2 = LayoutTree::reconcile_from(
    tree1, perf_stack(@types.Block, n, n - 1, 80.0), dirty, 200.0, 2000.0,
  )
  @block.reset_block_flow_cache_hits()
  let incr = tree2.compute_incremental()
  // The 11 unchanged blocks (uids 1..11) are served from the block-flow cache.
  inspect(@block.block_flow_cache_hit_count(), content="11")
  // Correctness: incremental result is byte-identical to a full recompute.
  let full = LayoutTree::from_node(
    perf_stack(@types.Block, n, n - 1, 80.0), 200.0, 2000.0,
  ).compute_incremental()
  inspect(recon_sig_perf(incr) == recon_sig_perf(full), content="true")
}

///|
/// A flex container (its own BFC) of `n` fixed items; the item at `changed_idx`
/// gets height `tweak`. uids are assigned from `base` (container = base, items
/// base+1..). Used as a reusable subtree under a parent root.
fn perf_flex_group(
  base : Int,
  tag : String,
  n : Int,
  changed_idx : Int,
  tweak : Double,
) -> @node.Node {
  let items : Array[@node.Node] = []
  for i = 0; i < n; i = i + 1 {
    let h = if i == changed_idx { tweak } else { 40.0 }
    items.push(@node.Node::with_uid(
      tag + "i" + i.to_string(), base + 1 + i, perf_block(30.0, h), [],
    ))
  }
  let style = @style.Style::{ ..perf_block(200.0, 60.0), display: @types.Flex }
  @node.Node::with_uid(tag, base, style, items)
}

///|
/// The one reuse that works today: an unchanged BFC subtree that does not move
/// is served whole from the per-uid cache (the "high-subtree short-circuit").
/// Two flex groups A then B stacked in a block column; change deep inside B.
/// A precedes B so its absolute position is unchanged — A's entire subtree is a
/// single cache hit, no descent. This is the BFC short-circuit (complementary to
/// the block-flow memoization above, which covers in-flow block children).
test "perf: an unchanged, unmoved BFC subtree is reused whole (high-subtree short-circuit)" {
  @dispatch.setup()
  // Root column (uid 0). Group A uids 1..5 (base 1), Group B uids 10..14.
  let mk = fn(b_tweak : Double) {
    let root_style = @style.Style::{
      ..perf_block(200.0, 200.0),
      display: @types.Block,
    }
    @node.Node::with_uid("root", 0, root_style, [
      perf_flex_group(1, "A", 4, -1, 40.0),
      perf_flex_group(10, "B", 4, 0, b_tweak),
    ])
  }
  let tree1 = LayoutTree::from_node(mk(40.0), 200.0, 200.0)
  let _ = tree1.compute_incremental()
  // Change item B0's height. B follows A and is the last child, so nothing that
  // precedes shifts; only B's subtree is dirty.
  let dirty = tree1.flow_dirty_uids([11]) // B's first item uid = 10+1
  let tree2 = LayoutTree::reconcile_from(tree1, mk(80.0), dirty, 200.0, 200.0)
  let stats = CacheStats::new()
  let _ = tree2.compute_with_stats(stats)
  // A's subtree is reused without descending into it: at least one cache hit.
  inspect(stats.cache_hits > 0, content="true")
}

///|
/// Adversarial guard: a constraint change (the viewport / available width) must
/// NOT reuse a stale block-flow cache entry — the cache key includes the
/// constraint, so a width change recomputes even "clean" children, and the
/// result still equals a full recompute at the new width.
test "perf(block): a width change invalidates the block-flow cache (no stale reuse)" {
  @dispatch.setup()
  let n = 6
  // Percent-width children so the available width actually changes their box.
  let mk = fn(vw : Double) {
    let children : Array[@node.Node] = []
    for i = 0; i < n; i = i + 1 {
      let s = @style.Style::{
        ..@style.Style::default(),
        width: @types.Percent(0.5),
        height: @types.Length(40.0),
      }
      children.push(@node.Node::with_uid("b" + i.to_string(), i + 1, s, []))
    }
    let root = @style.Style::{
      ..@style.Style::default(),
      width: @types.Length(vw),
      height: @types.Length(1000.0),
    }
    @node.Node::with_uid("root", 0, root, children)
  }
  let tree1 = LayoutTree::from_node(mk(400.0), 400.0, 1000.0)
  @block.clear_block_flow_cache()
  let _ = tree1.compute_incremental()
  // Re-render with the root widened (its own width style changed -> root in the
  // dirty set). The children are structurally unchanged ("clean") but the
  // constraint handed to them differs, so the block-flow cache key misses and
  // each percent-width child is recomputed at the new available width.
  let tree2 = LayoutTree::reconcile_from(tree1, mk(800.0), [0], 800.0, 1000.0)
  @block.reset_block_flow_cache_hits()
  let incr = tree2.compute_incremental()
  inspect(@block.block_flow_cache_hit_count(), content="0")
  let full = LayoutTree::from_node(mk(800.0), 800.0, 1000.0).compute_incremental()
  inspect(recon_sig_perf(incr) == recon_sig_perf(full), content="true")
}

///|
/// Nested block subtrees: a change deep in one branch reuses the sibling
/// branch's whole subtree through the memoized in-flow path, and the result is
/// byte-identical to a full recompute.
test "perf(block): nested block subtrees reuse the unchanged sibling branch" {
  @dispatch.setup()
  // root(0) -> [groupA(1) -> [a0(2), a1(3)], groupB(4) -> [b0(5), b1(6)]]
  let mk = fn(b1_h : Double) {
    let col = fn(id, uid, kids) {
      let s = @style.Style::{ ..perf_block(200.0, 0.0), height: @types.Auto }
      @node.Node::with_uid(id, uid, s, kids)
    }
    @node.Node::with_uid("root", 0, perf_block(200.0, 600.0), [
      col("groupA", 1, [
        @node.Node::with_uid("a0", 2, perf_block(100.0, 30.0), []),
        @node.Node::with_uid("a1", 3, perf_block(100.0, 30.0), []),
      ]),
      col("groupB", 4, [
        @node.Node::with_uid("b0", 5, perf_block(100.0, 30.0), []),
        @node.Node::with_uid("b1", 6, perf_block(100.0, b1_h), []),
      ]),
    ])
  }
  let tree1 = LayoutTree::from_node(mk(30.0), 200.0, 600.0)
  @block.clear_block_flow_cache()
  let _ = tree1.compute_incremental()
  // Change b1 (uid 6). groupA (uid 1) precedes groupB and is entirely unchanged.
  let dirty = tree1.flow_dirty_uids([6])
  let tree2 = LayoutTree::reconcile_from(tree1, mk(50.0), dirty, 200.0, 600.0)
  @block.reset_block_flow_cache_hits()
  let incr = tree2.compute_incremental()
  // groupA's whole subtree is reused at the top in-flow level (1 hit for the
  // group; its descendants don't re-enter the block loop).
  inspect(@block.block_flow_cache_hit_count() > 0, content="true")
  let full = LayoutTree::from_node(mk(50.0), 200.0, 600.0).compute_incremental()
  inspect(recon_sig_perf(incr) == recon_sig_perf(full), content="true")
}
