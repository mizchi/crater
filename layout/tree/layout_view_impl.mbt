///|
/// Implementation of the abstract `@view.LayoutView` interface for
/// the layout engine's concrete `LayoutNode`. Consumers (web vitals,
/// accessibility walks, ...) can stay generic over `LayoutView` and
/// avoid taking a direct dependency on the layout engine.

///|
pub impl @view.LayoutView for LayoutNode with fn uid(self) {
  self.uid
}

///|
pub impl @view.LayoutView for LayoutNode with fn computed_x(self) {
  self.computed_x
}

///|
pub impl @view.LayoutView for LayoutNode with fn computed_y(self) {
  self.computed_y
}

///|
pub impl @view.LayoutView for LayoutNode with fn computed_width(self) {
  self.computed_width
}

///|
pub impl @view.LayoutView for LayoutNode with fn computed_height(self) {
  self.computed_height
}

///|
pub impl @view.LayoutView for LayoutNode with fn children(self) {
  self.children
}

///|
pub impl @view.LayoutView for LayoutNode with fn text(self) {
  self.text
}

///|
pub impl @view.LayoutView for LayoutNode with fn resource_state(self) {
  match self.intrinsic_state {
    Some(Resolved(..)) => Some(@view.ResourceLoadState::Resolved)
    Some(Pending(..)) => Some(@view.ResourceLoadState::Pending)
    Some(Error) => Some(@view.ResourceLoadState::Error)
    None => None
  }
}
