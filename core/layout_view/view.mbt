///|
/// Loading state of an intrinsic-sized resource (image, etc).
/// Abstract view of layout-engine-specific resource tracking so that
/// downstream consumers (web vitals, accessibility walks, ...) can
/// reason about resource readiness without depending on the layout
/// engine's internal state representation.
pub(all) enum ResourceLoadState {
  Pending
  Resolved
  Error
}

///|
/// Read-only view of a computed layout tree node.
///
/// Implementations expose just the fields needed by external consumers
/// (web vitals metrics, accessibility tree walks, etc.) without leaking
/// layout-engine state. The layout engine's `LayoutNode` (in
/// `mizchi/crater-layout/tree`) is the canonical implementation; tests
/// and alternative engines can provide their own.
pub(open) trait LayoutView {
  fn uid(Self) -> Int
  fn computed_x(Self) -> Double
  fn computed_y(Self) -> Double
  fn computed_width(Self) -> Double
  fn computed_height(Self) -> Double
  fn children(Self) -> Array[Self]
  fn text(Self) -> String?
  fn resource_state(Self) -> ResourceLoadState?
}
