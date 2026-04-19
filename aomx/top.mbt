///|
pub using @arc90 {type ContentBlock, type ExtractConfig, type ExtractionResult}

///|
pub using @diff {
  type ChangeType,
  type DiffConfig,
  type DiffResult,
  type Difference,
}

///|
pub using @grounding {
  type GroundingResult,
  type SpatialQuery,
  type SpatialRegion,
  type SpatialRelation,
  type Viewport,
}

///|
pub fn extract_content(
  tree : @dom.AccessibilityTree,
  config : ExtractConfig,
) -> ExtractionResult {
  @arc90.extract_content(tree, config)
}

///|
pub fn extract_main_content(
  tree : @dom.AccessibilityTree,
) -> @dom.AccessibilityNode? {
  @arc90.extract_main_content(tree)
}

///|
pub fn get_extraction_stats(result : ExtractionResult) -> String {
  @arc90.get_extraction_stats(result)
}

///|
pub fn print_extraction_result(result : ExtractionResult) -> String {
  @arc90.print_extraction_result(result)
}

///|
pub fn diff_trees(
  before : @dom.AccessibilityTree,
  after : @dom.AccessibilityTree,
  config : DiffConfig,
) -> DiffResult {
  @diff.diff_trees(before, after, config)
}

///|
pub fn diff_summary(
  before : @dom.AccessibilityTree,
  after : @dom.AccessibilityTree,
) -> String {
  @diff.diff_summary(before, after)
}

///|
pub fn trees_equal(
  before : @dom.AccessibilityTree,
  after : @dom.AccessibilityTree,
) -> Bool {
  @diff.trees_equal(before, after)
}

///|
pub fn find_best(
  tree : @dom.AccessibilityTree,
  query : SpatialQuery,
  viewport : Viewport,
) -> GroundingResult? {
  @grounding.find_best(tree, query, viewport)
}

///|
pub fn find_by_spatial(
  tree : @dom.AccessibilityTree,
  query : SpatialQuery,
  viewport : Viewport,
) -> Array[GroundingResult] {
  @grounding.find_by_spatial(tree, query, viewport)
}

///|
pub fn get_click_coords(
  tree : @dom.AccessibilityTree,
  source_id : String,
) -> (Double, Double)? {
  @grounding.get_click_coords(tree, source_id)
}
