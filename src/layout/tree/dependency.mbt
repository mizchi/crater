///|
/// Dependency analysis for incremental layout invalidation

///|
/// What a node's layout depends on
pub(all) enum DependencyKind {
  /// Only fixed values (Length) - never needs re-layout due to parent changes
  Static
  /// Depends on parent's width (Percent in width/margin/padding)
  ParentWidth
  /// Depends on parent's height (Percent in height)
  ParentHeight
  /// Depends on both parent dimensions
  ParentBoth
  /// Depends on children's content (Auto sizing)
  Intrinsic
  /// Depends on viewport (vw/vh - future extension)
  Viewport
} derive(Show, Eq)

///|
/// Merge two dependency kinds into a combined dependency
pub fn DependencyKind::merge(
  self : DependencyKind,
  other : DependencyKind,
) -> DependencyKind {
  match (self, other) {
    // Static + anything = the other
    (Static, x) => x
    (x, Static) => x
    // Same dependency
    (x, y) if x == y => x
    // ParentWidth + ParentHeight = ParentBoth
    (ParentWidth, ParentHeight) => ParentBoth
    (ParentHeight, ParentWidth) => ParentBoth
    // ParentBoth absorbs ParentWidth/ParentHeight
    (ParentBoth, ParentWidth) => ParentBoth
    (ParentBoth, ParentHeight) => ParentBoth
    (ParentWidth, ParentBoth) => ParentBoth
    (ParentHeight, ParentBoth) => ParentBoth
    // Viewport is separate concern
    (Viewport, ParentWidth) => ParentBoth // Simplification
    (Viewport, ParentHeight) => ParentBoth
    (ParentWidth, Viewport) => ParentBoth
    (ParentHeight, Viewport) => ParentBoth
    // Intrinsic combines with parent dependencies
    (Intrinsic, ParentWidth) => ParentWidth
    (Intrinsic, ParentHeight) => ParentHeight
    (ParentWidth, Intrinsic) => ParentWidth
    (ParentHeight, Intrinsic) => ParentHeight
    (Intrinsic, ParentBoth) => ParentBoth
    (ParentBoth, Intrinsic) => ParentBoth
    // Default: most general
    _ => ParentBoth
  }
}

///|
/// Check if a Dimension depends on parent width
fn dimension_depends_on_parent_width(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Percent(_) => true
    _ => false
  }
}

///|
/// Check if a Dimension is auto (depends on content)
fn dimension_is_auto(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Auto => true
    _ => false
  }
}

///|
/// Analyze what a style depends on for layout
pub fn analyze_style_dependencies(style : @style.Style) -> DependencyKind {
  let mut deps = Static

  // Width dependency
  if dimension_depends_on_parent_width(style.width) {
    deps = deps.merge(ParentWidth)
  } else if dimension_is_auto(style.width) {
    deps = deps.merge(Intrinsic)
  }

  // Height dependency
  match style.height {
    @types.Percent(_) => deps = deps.merge(ParentHeight)
    @types.Auto => deps = deps.merge(Intrinsic)
    _ => ()
  }

  // Min/max width (% depends on parent width)
  if dimension_depends_on_parent_width(style.min_width) ||
    dimension_depends_on_parent_width(style.max_width) {
    deps = deps.merge(ParentWidth)
  }

  // Min/max height (% depends on parent height)
  match style.min_height {
    @types.Percent(_) => deps = deps.merge(ParentHeight)
    _ => ()
  }
  match style.max_height {
    @types.Percent(_) => deps = deps.merge(ParentHeight)
    _ => ()
  }

  // Margin/padding percentages always depend on parent WIDTH (CSS spec)
  if dimension_depends_on_parent_width(style.margin.left) ||
    dimension_depends_on_parent_width(style.margin.right) ||
    dimension_depends_on_parent_width(style.margin.top) ||
    dimension_depends_on_parent_width(style.margin.bottom) ||
    dimension_depends_on_parent_width(style.padding.left) ||
    dimension_depends_on_parent_width(style.padding.right) ||
    dimension_depends_on_parent_width(style.padding.top) ||
    dimension_depends_on_parent_width(style.padding.bottom) {
    deps = deps.merge(ParentWidth)
  }

  // Flex basis
  if dimension_depends_on_parent_width(style.flex_basis) {
    deps = deps.merge(ParentWidth)
  }
  deps
}

///|
/// Check if node needs re-layout when parent width changes
fn depends_on_parent_width(deps : DependencyKind) -> Bool {
  match deps {
    ParentWidth | ParentBoth => true
    _ => false
  }
}

///|
/// Check if node needs re-layout when parent height changes
fn depends_on_parent_height(deps : DependencyKind) -> Bool {
  match deps {
    ParentHeight | ParentBoth => true
    _ => false
  }
}

///|
/// Check if node needs re-layout when viewport changes
fn depends_on_viewport(deps : DependencyKind) -> Bool {
  match deps {
    Viewport => true
    _ => false
  }
}

///|
/// Check if node is completely static (never needs re-layout from ancestor changes)
fn is_static(deps : DependencyKind) -> Bool {
  match deps {
    Static => true
    _ => false
  }
}
