///|
/// Flex layout cache and support records
///
/// Keeps intrinsic/resolved style caches out of the main flex algorithm file.

///|
/// Layout with DOM index for sorting
priv struct IndexedLayout {
  dom_index : Int
  layout : @layout_types.Layout
}

///|
priv struct SimpleFixedLeafFlexItem {
  node : @node.Node
  width : Double
  height : Double
}

///|
/// Session-scoped cache for intrinsic size computation.
/// Key: (node_uid * 2 + is_row_flag)
/// This dramatically reduces redundant calculations in deep nesting.
priv struct IntrinsicCache {
  data : Map[Int, Double]
}

///|
fn IntrinsicCache::new() -> IntrinsicCache {
  { data: {} }
}

///|
/// Global intrinsic cache that persists across incremental layout updates.
/// This avoids recomputing intrinsic sizes for unchanged nodes.
let global_intrinsic_cache : Ref[Map[Int, Double]] = { val: {} }

///|
/// Clear intrinsic cache entries for a specific node.
/// Call this when a node is marked dirty.
pub fn clear_intrinsic_cache_for_node(uid : Int) -> Unit {
  let cache = global_intrinsic_cache.val
  // Clear both width and height entries (uid*2 and uid*2+1)
  cache.remove(uid * 2)
  cache.remove(uid * 2 + 1)
}

///|
/// Clear intrinsic cache for a node and all its descendants.
/// More efficient than clearing entries one by one.
pub fn clear_intrinsic_cache_for_subtree(node : @node.Node) -> Unit {
  clear_intrinsic_cache_for_node(node.uid)
  for child in node.children {
    clear_intrinsic_cache_for_subtree(child)
  }
}

///|
/// Reset the global intrinsic cache entirely.
/// Call this for a full re-layout.
pub fn reset_intrinsic_cache() -> Unit {
  global_intrinsic_cache.val = {}
}

///|
/// Detect whether a subtree contains a table element with percentage width.
/// Such descendants need a definite containing block width during flex base-size
/// resolution to avoid collapsing to border-box minimums.
fn has_percent_width_table_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    let is_table = child.style.display == @types.Table ||
      child.style.display == @types.InlineTable
    let has_percent_width = match child.style.width {
      @types.Percent(_) => true
      _ => false
    }
    if is_table && has_percent_width {
      return true
    }
    if has_percent_width_table_descendant(child) {
      return true
    }
  }
  false
}

///|
fn has_flex_grow_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    if child.style.flex_grow > 0.0 {
      return true
    }
    if has_flex_grow_descendant(child) {
      return true
    }
  }
  false
}

///|
fn IntrinsicCache::get(
  self : IntrinsicCache,
  node_uid : Int,
  is_row : Bool,
) -> Double? {
  let key = node_uid * 2 + (if is_row { 1 } else { 0 })
  // Check session cache first, then global cache
  match self.data.get(key) {
    Some(v) => Some(v)
    None => global_intrinsic_cache.val.get(key)
  }
}

///|
fn IntrinsicCache::set(
  self : IntrinsicCache,
  node_uid : Int,
  is_row : Bool,
  value : Double,
) -> Unit {
  let key = node_uid * 2 + (if is_row { 1 } else { 0 })
  // Update both session and global cache
  self.data.set(key, value)
  global_intrinsic_cache.val.set(key, value)
}
