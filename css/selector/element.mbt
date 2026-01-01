///|
/// Element interface for selector matching
/// This represents a DOM-like element with the information needed for CSS selector matching

///|
/// Attribute value on an element
pub struct Attribute {
  name : String
  value : String
}

///|
/// Element data for selector matching
/// This is a concrete type that can be used with or without a real DOM
pub(all) struct Element {
  /// Tag name (lowercase, e.g. "div", "span")
  tag_name : String
  /// ID attribute (without #)
  id : String?
  /// Class names (without .)
  classes : Array[String]
  /// Other attributes
  attributes : Array[Attribute]
  /// Parent element (for ancestor/parent selectors)
  parent : Element?
  /// Previous sibling (for adjacent/general sibling selectors)
  prev_sibling : Element?
  /// Next sibling
  next_sibling : Element?
  /// Child elements
  children : Array[Element]
  /// Index among siblings (1-based for :nth-child)
  sibling_index : Int
  /// Total number of siblings (for :last-child, :nth-last-child)
  sibling_count : Int
}

///|
/// Create a new element with minimal information
pub fn Element::new(tag_name : String) -> Element {
  {
    tag_name,
    id: None,
    classes: [],
    attributes: [],
    parent: None,
    prev_sibling: None,
    next_sibling: None,
    children: [],
    sibling_index: 1,
    sibling_count: 1,
  }
}

///|
/// Create an element with id
pub fn Element::with_id(tag_name : String, id : String) -> Element {
  {
    tag_name,
    id: Some(id),
    classes: [],
    attributes: [],
    parent: None,
    prev_sibling: None,
    next_sibling: None,
    children: [],
    sibling_index: 1,
    sibling_count: 1,
  }
}

///|
/// Create an element with classes
pub fn Element::with_classes(tag_name : String, classes : Array[String]) -> Element {
  {
    tag_name,
    id: None,
    classes,
    attributes: [],
    parent: None,
    prev_sibling: None,
    next_sibling: None,
    children: [],
    sibling_index: 1,
    sibling_count: 1,
  }
}

///|
/// Get attribute value by name
pub fn Element::get_attribute(self : Element, name : String) -> String? {
  for attr in self.attributes {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
/// Check if element has a specific class
pub fn Element::has_class(self : Element, class_name : String) -> Bool {
  for cls in self.classes {
    if cls == class_name {
      return true
    }
  }
  false
}

///|
/// Check if element is first child
pub fn Element::is_first_child(self : Element) -> Bool {
  self.sibling_index == 1
}

///|
/// Check if element is last child
pub fn Element::is_last_child(self : Element) -> Bool {
  self.sibling_index == self.sibling_count
}

///|
/// Builder for creating elements with fluent API
pub fn Element::set_id(self : Element, id : String) -> Element {
  { ..self, id: Some(id) }
}

///|
pub fn Element::add_class(self : Element, class_name : String) -> Element {
  let classes = self.classes.copy()
  classes.push(class_name)
  { ..self, classes }
}

///|
pub fn Element::set_attribute(
  self : Element,
  name : String,
  value : String
) -> Element {
  let attributes = self.attributes.copy()
  attributes.push({ name, value })
  { ..self, attributes }
}

///|
pub fn Element::set_sibling_info(
  self : Element,
  index : Int,
  count : Int
) -> Element {
  { ..self, sibling_index: index, sibling_count: count }
}

///|
pub fn Element::set_parent(self : Element, parent : Element) -> Element {
  { ..self, parent: Some(parent) }
}
