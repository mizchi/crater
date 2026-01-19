///|
/// Mutation Types and Records
///
/// Based on the MutationObserver API, with extensions for style changes.
/// Used for batching DOM changes before applying them to the layout tree.

///|
/// Type of DOM mutation
pub enum MutationType {
  /// Child nodes added or removed
  ChildList
  /// Attribute changed
  Attributes
  /// Text content changed (for Text/Comment nodes)
  CharacterData
  /// Style property changed (extension for layout optimization)
  StyleChange
} derive(Eq, Show)

///|
/// Record of a single DOM mutation
pub struct MutationRecord {
  /// Type of mutation
  type_ : MutationType
  /// Target node ID (the node that was mutated)
  target : NodeId
  /// For ChildList: nodes that were added
  added_nodes : Array[NodeId]
  /// For ChildList: nodes that were removed
  removed_nodes : Array[NodeId]
  /// For Attributes: the name of the changed attribute
  attribute_name : String?
  /// For Attributes: the old value
  old_value : String?
  /// For Attributes: the new value
  new_value : String?
  /// For StyleChange: which CSS properties changed
  changed_properties : Array[String]
} derive(Show)

///|
/// Create a ChildList mutation record
pub fn MutationRecord::child_list(
  target : NodeId,
  added? : Array[NodeId] = [],
  removed? : Array[NodeId] = [],
) -> MutationRecord {
  {
    type_: ChildList,
    target,
    added_nodes: added,
    removed_nodes: removed,
    attribute_name: None,
    old_value: None,
    new_value: None,
    changed_properties: [],
  }
}

///|
/// Create an Attributes mutation record
pub fn MutationRecord::attribute(
  target : NodeId,
  name : String,
  old_value? : String? = None,
  new_value? : String? = None,
) -> MutationRecord {
  {
    type_: Attributes,
    target,
    added_nodes: [],
    removed_nodes: [],
    attribute_name: Some(name),
    old_value,
    new_value,
    changed_properties: [],
  }
}

///|
/// Create a CharacterData mutation record
pub fn MutationRecord::character_data(
  target : NodeId,
  old_value? : String? = None,
  new_value? : String? = None,
) -> MutationRecord {
  {
    type_: CharacterData,
    target,
    added_nodes: [],
    removed_nodes: [],
    attribute_name: None,
    old_value,
    new_value,
    changed_properties: [],
  }
}

///|
/// Create a StyleChange mutation record
pub fn MutationRecord::style_change(
  target : NodeId,
  properties : Array[String],
) -> MutationRecord {
  {
    type_: StyleChange,
    target,
    added_nodes: [],
    removed_nodes: [],
    attribute_name: None,
    old_value: None,
    new_value: None,
    changed_properties: properties,
  }
}

///|
/// Check if this mutation affects layout (vs paint-only)
pub fn MutationRecord::affects_layout(self : MutationRecord) -> Bool {
  match self.type_ {
    ChildList => true // Adding/removing children always affects layout
    CharacterData => true // Text changes affect intrinsic size
    Attributes =>
      // Only certain attributes affect layout
      match self.attribute_name {
        Some("class") | Some("style") => true
        Some("width") | Some("height") => true
        _ => false
      }
    StyleChange =>
      // Check if any changed property affects layout
      self.changed_properties.iter().any(is_layout_property)
  }
}

///|
/// Check if a CSS property affects layout (vs paint-only)
fn is_layout_property(prop : String) -> Bool {
  match prop {
    // Box model
    "width"
    | "height"
    | "min-width"
    | "max-width"
    | "min-height"
    | "max-height" => true
    "margin"
    | "margin-top"
    | "margin-right"
    | "margin-bottom"
    | "margin-left" => true
    "padding"
    | "padding-top"
    | "padding-right"
    | "padding-bottom"
    | "padding-left" => true
    "border"
    | "border-width"
    | "border-top-width"
    | "border-right-width"
    | "border-bottom-width"
    | "border-left-width" => true
    // Display and positioning
    "display" | "position" | "top" | "right" | "bottom" | "left" => true
    "float" | "clear" => true
    // Flexbox
    "flex" | "flex-grow" | "flex-shrink" | "flex-basis" => true
    "flex-direction" | "flex-wrap" | "flex-flow" => true
    "justify-content" | "align-items" | "align-self" | "align-content" => true
    "order" => true
    // Grid
    "grid-template-rows" | "grid-template-columns" | "grid-template-areas" =>
      true
    "grid-auto-rows" | "grid-auto-columns" | "grid-auto-flow" => true
    "grid-row" | "grid-column" | "grid-row-start" | "grid-row-end" => true
    "grid-column-start" | "grid-column-end" => true
    "gap" | "row-gap" | "column-gap" => true
    // Other layout
    "overflow" | "overflow-x" | "overflow-y" => true
    "box-sizing" => true
    "contain" => true
    "aspect-ratio" => true
    // Text layout
    "font-size" | "line-height" | "letter-spacing" | "word-spacing" => true
    "text-align" | "white-space" | "word-break" | "overflow-wrap" => true
    // Paint-only properties (return false)
    _ => false
  }
}
