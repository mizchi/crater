///|
pub using @paint_diff {
  type PaintLayoutShift,
  type PaintPropertyChange,
  type PaintTreeDiff,
}

///|
pub fn diff_trees(before : PaintNode, after : PaintNode) -> PaintTreeDiff {
  @paint_diff.diff_trees(before, after)
}
