///|
/// Incremental layout computation with per-node caching

///|
/// Global cache for mapping uid -> LayoutNode during incremental computation
/// This enables child nodes to use their cached layouts
let layout_node_cache_map : Ref[Map[Int, LayoutNode]] = { val: {} }

///|
/// Global stats reference for cache tracking during dispatch
let global_cache_stats : Ref[CacheStats?] = { val: None }

///|
/// Build node map recursively from LayoutNode tree
fn build_layout_node_map(node : LayoutNode, map : Map[Int, LayoutNode]) -> Unit {
  map[node.uid] = node
  for child in node.children {
    build_layout_node_map(child, map)
  }
}

///|
/// Extended constraint space for cache comparison
pub struct ConstraintSpace {
  available_width : Double
  available_height : Double?
  sizing_mode : @node.SizingMode
  // For percentage resolution
  parent_width : Double
  parent_height : Double?
  // Viewport dimensions for viewport-relative units
  viewport_width : Double
  viewport_height : Double
}

///|
pub fn ConstraintSpace::new(
  available_width : Double,
  available_height : Double?,
  sizing_mode : @node.SizingMode,
  parent_width : Double,
  parent_height : Double?,
  viewport_width? : Double = 0.0,
  viewport_height? : Double = 0.0,
) -> ConstraintSpace {
  {
    available_width,
    available_height,
    sizing_mode,
    parent_width,
    parent_height,
    viewport_width,
    viewport_height,
  }
}

///|
/// Convert to LayoutContext for existing compute functions
pub fn ConstraintSpace::to_context(
  self : ConstraintSpace,
) -> @node.LayoutContext {
  {
    available_width: self.available_width,
    available_height: self.available_height,
    sizing_mode: self.sizing_mode,
    viewport_width: self.viewport_width,
    viewport_height: self.viewport_height,
  }
}

///|
/// Convert to ConstraintKey for cache lookup
pub fn ConstraintSpace::to_key(self : ConstraintSpace) -> ConstraintKey {
  ConstraintKey::new(
    self.available_width,
    self.available_height,
    self.sizing_mode,
  )
}

///|
/// Check if node can use cached layout under given constraint
/// Returns true if:
/// 1. Node has cached layout
/// 2. Constraint matches (considering style dependencies)
fn can_use_cache(node : LayoutNode, constraint : ConstraintSpace) -> Bool {
  // If node is dirty, cannot use cache
  if node.dirty {
    return false
  }

  // Check if we have a cache
  let cache = match node.cached_layout {
    Some(c) => c
    None => return false
  }

  // Check constraint compatibility based on style
  let style = node.style

  // Fixed width doesn't depend on available width
  let width_ok = match style.width {
    @types.Length(_) => true
    @types.Percent(p) => {
      // Percent depends on parent width
      let cached_parent = cache.constraint.available_width
      (constraint.parent_width * p - cached_parent).abs() < 0.001
    }
    @types.Auto =>
      // Auto depends on available width
      (constraint.available_width - cache.constraint.available_width).abs() <
      0.001
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      // Intrinsic sizing depends on available width for constraint
      (constraint.available_width - cache.constraint.available_width).abs() <
      0.001
  }
  if not(width_ok) {
    return false
  }

  // Fixed height doesn't depend on available height
  let height_ok = match style.height {
    @types.Length(_) => true
    @types.Percent(p) =>
      // Percent depends on parent height
      match (constraint.parent_height, cache.constraint.available_height) {
        (Some(ph), Some(ch)) => (ph * p - ch).abs() < 0.001
        (None, None) => true
        _ => false
      }
    @types.Auto =>
      // Auto may depend on available height
      match (constraint.available_height, cache.constraint.available_height) {
        (Some(a), Some(b)) => (a - b).abs() < 0.001
        (None, None) => true
        _ => false
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      // Intrinsic sizing depends on available height
      match (constraint.available_height, cache.constraint.available_height) {
        (Some(a), Some(b)) => (a - b).abs() < 0.001
        (None, None) => true
        _ => false
      }
  }
  if not(height_ok) {
    return false
  }

  // Sizing mode must match
  constraint.sizing_mode == cache.constraint.sizing_mode
}

///|
/// Statistics for cache performance
pub struct CacheStats {
  mut cache_hits : Int
  mut cache_misses : Int
  mut nodes_computed : Int
}

///|
pub fn CacheStats::new() -> CacheStats {
  { cache_hits: 0, cache_misses: 0, nodes_computed: 0 }
}

///|
pub fn CacheStats::hit_rate(self : CacheStats) -> Double {
  let total = self.cache_hits + self.cache_misses
  if total == 0 {
    0.0
  } else {
    self.cache_hits.to_double() / total.to_double()
  }
}

///|
/// Compute layout for a LayoutNode with caching
/// This wraps the existing compute functions with cache logic
pub fn compute_node(
  node : LayoutNode,
  constraint : ConstraintSpace,
  stats : CacheStats,
) -> @node.Layout {
  stats.nodes_computed = stats.nodes_computed + 1

  // Fast path: no dirty flags and constraint matches cache
  if can_use_cache(node, constraint) && not(node.children_dirty) {
    stats.cache_hits = stats.cache_hits + 1
    match node.cached_layout {
      Some(cache) => return cache.result
      None => () // Shouldn't happen, but fallback to compute
    }
  }

  // Optimization: if constraint matches and children_dirty but
  // all children's cached sizes match cached layout's children sizes,
  // we can use the cached result (children didn't actually change size)
  if node.children_dirty && not(node.dirty) && can_use_cache(node, constraint) {
    match node.cached_layout {
      Some(cache) =>
        if children_sizes_match(node, cache.result) {
          stats.cache_hits = stats.cache_hits + 1
          // Clear children_dirty since we verified sizes match
          node.children_dirty = false
          return cache.result
        }
      None => ()
    }
  }
  stats.cache_misses = stats.cache_misses + 1

  // Convert to Node and compute using existing algorithm
  let immutable_node = node.to_node()
  let ctx = constraint.to_context()
  let result = @node.dispatch_layout(immutable_node, ctx)

  // Cache the result
  node.cached_layout = Some({ constraint: constraint.to_key(), result })

  // Sync child caches from computed result
  sync_child_caches(node, result)

  // Clear dirty flags
  node.clear_dirty()
  result
}

///|
/// Check if we can use cache for a node based on uid lookup
fn try_cache_by_uid(uid : Int, ctx : @node.LayoutContext) -> @node.Layout? {
  let map = layout_node_cache_map.val
  match map.get(uid) {
    Some(layout_node) => {
      // Create constraint from context
      let constraint = ConstraintSpace::new(
        ctx.available_width,
        ctx.available_height,
        ctx.sizing_mode,
        ctx.available_width,
        ctx.available_height,
      )
      // Check cache
      if can_use_cache(layout_node, constraint) &&
        not(layout_node.children_dirty) {
        match global_cache_stats.val {
          Some(stats) => stats.cache_hits = stats.cache_hits + 1
          None => ()
        }
        match layout_node.cached_layout {
          Some(cache) => return Some(cache.result)
          None => ()
        }
      }
    }
    None => ()
  }
  None
}

///|
/// Update cache for a node after computation
fn update_cache_by_uid(
  uid : Int,
  ctx : @node.LayoutContext,
  result : @node.Layout,
) -> Unit {
  let map = layout_node_cache_map.val
  match map.get(uid) {
    Some(layout_node) => {
      let constraint_key = ConstraintKey::new(
        ctx.available_width,
        ctx.available_height,
        ctx.sizing_mode,
      )
      layout_node.cached_layout = Some({ constraint: constraint_key, result })
      layout_node.clear_dirty()
    }
    None => ()
  }
}

///|
/// Cached dispatch function - wraps original dispatcher with cache logic
fn cached_dispatch(
  original : @node.LayoutDispatchFunc,
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.Layout {
  // Try cache first
  match try_cache_by_uid(node.uid, ctx) {
    Some(cached) => cached
    None => {
      // Cache miss - compute using original dispatcher
      match global_cache_stats.val {
        Some(stats) => stats.cache_misses = stats.cache_misses + 1
        None => ()
      }
      let @node.LayoutDispatchFunc(f) = original
      let result = f(node, ctx)
      // Update cache
      update_cache_by_uid(node.uid, ctx, result)
      result
    }
  }
}

///|
/// Check if all children's cached sizes match the given layout's children sizes
/// Returns true if sizes match AND no children are dirty
/// (dirty children might compute to different sizes)
fn children_sizes_match(node : LayoutNode, layout : @node.Layout) -> Bool {
  if node.children.length() != layout.children.length() {
    return false
  }
  for i = 0; i < node.children.length(); i = i + 1 {
    let child_node = node.children[i]
    let expected_layout = layout.children[i]

    // If child or any of its descendants is dirty, sizes might change
    // Optimization: Use dirty flags directly instead of recursive traversal
    // children_dirty flag already tracks whether any descendant is dirty
    if child_node.dirty || child_node.children_dirty {
      return false
    }
    match child_node.cached_layout {
      Some(cache) =>
        if (cache.result.width - expected_layout.width).abs() > 0.001 ||
          (cache.result.height - expected_layout.height).abs() > 0.001 {
          return false
        }
      None => return false
    }
  }
  true
}

///|
/// Sync computed layout results back to LayoutNode child caches
/// This enables cache hits on subsequent computations
fn sync_child_caches(node : LayoutNode, layout : @node.Layout) -> Unit {
  // Match children by index
  let len = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  for i = 0; i < len; i = i + 1 {
    let child_node = node.children[i]
    let child_layout = layout.children[i]

    // Create constraint key based on computed size
    let child_key = ConstraintKey::new(
      child_layout.width,
      Some(child_layout.height),
      @node.Definite,
    )

    // Update child cache
    child_node.cached_layout = Some({
      constraint: child_key,
      result: child_layout,
    })
    child_node.clear_dirty()

    // Recursively sync grandchildren
    sync_child_caches(child_node, child_layout)
  }
}

///|
/// Compute layout for entire tree with incremental optimization
/// Uses cached dispatcher to enable child-level cache hits
pub fn compute_tree_incremental(
  tree : LayoutTree,
  stats : CacheStats,
) -> @node.Layout {
  // 1. Build uid -> LayoutNode map for cache lookup
  let map : Map[Int, LayoutNode] = {}
  build_layout_node_map(tree.root, map)
  layout_node_cache_map.val = map

  // 2. Set up global stats reference
  global_cache_stats.val = Some(stats)

  // 3. Save original dispatcher and set up cached dispatcher
  let original_dispatcher = @node.get_layout_dispatcher()
  match original_dispatcher {
    Some(original) => {
      let cached = @node.LayoutDispatchFunc(fn(node, ctx) {
        cached_dispatch(original, node, ctx)
      })
      @node.set_layout_dispatcher(cached)
    }
    None => ()
  }

  // 4. Compute layout
  let constraint = ConstraintSpace::new(
    tree.viewport_width,
    Some(tree.viewport_height),
    @node.Definite,
    tree.viewport_width,
    Some(tree.viewport_height),
  )
  let result = compute_node(tree.root, constraint, stats)

  // 5. Restore original dispatcher and clean up
  match original_dispatcher {
    Some(d) => @node.set_layout_dispatcher(d)
    None => ()
  }
  global_cache_stats.val = None
  layout_node_cache_map.val = {}
  result
}

///|
/// Compute with stats tracking (for testing/debugging)
pub fn LayoutTree::compute_with_stats(
  self : LayoutTree,
  stats : CacheStats,
) -> @node.Layout {
  compute_tree_incremental(self, stats)
}
