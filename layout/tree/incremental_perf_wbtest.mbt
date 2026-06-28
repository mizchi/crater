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
test "perf(block): changing the LAST block still recomputes the whole stack (cache unused)" {
  @dispatch.setup()
  let n = 12
  let tree1 = LayoutTree::from_node(
    perf_stack(@types.Block, n, -1, 40.0), 200.0, 2000.0,
  )
  let _ = tree1.compute_incremental()
  // Change the last block. It has no following siblings, so the dirty set is
  // just it — ideally every preceding block is reused. It is not: in-flow block
  // children bypass the per-uid cache, so only the root is "computed" and the
  // whole subtree recomputes inside block flow without cache reads.
  let dirty = tree1.flow_dirty_uids([n])
  inspect(dirty.length(), content="1")
  let tree2 = LayoutTree::reconcile_from(
    tree1, perf_stack(@types.Block, n, n - 1, 80.0), dirty, 200.0, 2000.0,
  )
  let stats = CacheStats::new()
  let _ = tree2.compute_with_stats(stats)
  inspect(
    "hits=\{stats.cache_hits} misses=\{stats.cache_misses}",
    content="hits=0 misses=1",
  )
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
/// single cache hit, no descent. This is the reuse the dynamic path relies on
/// (no-op / paint-only / disjoint-subtree re-renders); the block-flow case above
/// gets none of it.
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
