///|
pub using @core_subset_pkg {type CoreIssue, type CoreComputeResult}

///|
pub fn validate_core_subset(node : @layout.Node) -> Array[CoreIssue] {
  @core_subset_pkg.validate_core_subset(node)
}

///|
pub fn compute_core_layout(
  node : @layout.Node,
  viewport : @types.Size[Double],
) -> CoreComputeResult {
  @core_subset_pkg.compute_core_layout(node, viewport)
}
