///|
pub using @html {type Document, type Element, type Node}

///|
pub using @dom_core {
  type CoreError,
  type DomTree,
  type FlushResult,
  type GetBBoxOptions,
  type MutationQueue,
  type MutationRecord,
  type MutationType,
  type NodeId,
  type NodeInfo,
  type NodeType,
  type Point,
  type Rect,
  type SVGAngle,
  type SVGLength,
  type SVGMatrix,
  type SVGPoint,
  type SVGRect,
  type SVGTransform,
}

///|
pub using @aom {
  type AccessibilityNode,
  type AccessibilityTree,
  type Bounds,
  type FocusManager,
  type FocusableItem,
  type Role,
  type SelectOption,
  type State,
}

///|
pub using @scheduler {
  type DiscoveredResource,
  type DocumentParser,
  type DocumentRenderCoordinator,
  type DocumentStyleCoordinator,
  type FetchResult,
  type HttpMethod,
  type InputEvent,
  type KeyEventType,
  type KeyboardEvent,
  type LayoutComputeResult,
  type LayoutManager,
  type LayoutStats,
  type MouseButton,
  type MouseEvent,
  type MouseEventType,
  type NetworkRequest,
  type NetworkResponse,
  type ParseCompleteResult,
  type RenderPipelineResult,
  type ResourceDiscoveryResult,
  type ResourceType,
  type ResizeResult,
  type Scheduler,
  type TaskId,
}

///|
pub fn parse(html : String) -> Element? {
  @html.parse(html)
}

///|
pub fn parse_document(html : String) -> Document {
  @html.parse_document(html)
}

///|
pub fn parse_fragment(html : String) -> Element {
  @html.parse_fragment(html)
}

///|
pub fn build_accessibility_tree(document : Document) -> AccessibilityTree {
  @aom.build_accessibility_tree(document)
}

///|
pub fn build_accessibility_tree_from_element(
  element : Element,
) -> AccessibilityTree {
  @aom.build_accessibility_tree_from_element(element)
}

///|
pub fn compute_accessible_name(
  element : Element,
  find_by_id : (String) -> Element?,
) -> String? {
  @aom.compute_accessible_name(element, find_by_id)
}

///|
pub fn compute_accessible_description(
  element : Element,
  find_by_id : (String) -> Element?,
) -> String? {
  @aom.compute_accessible_description(element, find_by_id)
}

///|
pub fn discover_resources(element : Element) -> ResourceDiscoveryResult {
  @scheduler.discover_resources(element)
}

///|
pub fn parse_and_schedule(
  scheduler : Scheduler,
  html : String,
  base_url? : String,
) -> ParseCompleteResult {
  @scheduler.parse_and_schedule(scheduler, html, base_url?)
}
