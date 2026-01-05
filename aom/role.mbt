///|
/// HTML-AAM Role Mapping
/// Based on HTML Accessibility API Mappings 1.0
/// https://www.w3.org/TR/html-aam-1.0/

// =============================================================================
// Role Mapping Context
// =============================================================================

///|
/// Context for determining contextual roles
pub(all) struct RoleMappingContext {
  // Parent element tag (for contextual roles like header/footer)
  parent_tag : String?
  // Whether element has accessible name
  has_accessible_name : Bool
  // Whether element is in a sectioning content
  in_sectioning_content : Bool
}

///|
pub fn RoleMappingContext::default() -> RoleMappingContext {
  {
    parent_tag: Option::None,
    has_accessible_name: false,
    in_sectioning_content: false,
  }
}

// =============================================================================
// Main Role Mapping Function
// =============================================================================

///|
/// Get the computed role for an HTML element
/// Follows HTML-AAM specification for role mapping
pub fn compute_role(
  element : @html.Element,
  context : RoleMappingContext,
) -> Role {
  // 1. Check for explicit role attribute
  match element.attributes.get("role") {
    Some(role_str) =>
      match Role::from_string(role_str.to_lower()) {
        Some(explicit_role) => return explicit_role
        Option::None => () // Invalid role, fall through to implicit
      }
    Option::None => ()
  }

  // 2. Compute implicit role based on element tag and context
  compute_implicit_role(element, context)
}

///|
/// Compute the implicit role based on HTML element semantics
fn compute_implicit_role(
  element : @html.Element,
  context : RoleMappingContext,
) -> Role {
  let tag = element.tag.to_lower()
  match tag {
    // Sectioning content
    "article" => Article
    "aside" => Complementary
    "nav" => Navigation
    "section" => if context.has_accessible_name { Region } else { Generic }

    // Heading content
    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => Heading

    // Grouping content
    "p" => Paragraph
    "hr" => Separator
    "pre" => Generic
    "blockquote" => Blockquote
    "ol" | "ul" => List
    "menu" => List
    "li" => ListItem
    "dl" => List
    "dt" => Term
    "dd" => Definition
    "figure" => Figure
    "figcaption" => Caption
    "main" => Main
    "div" => Generic
    "address" => Group

    // Text-level semantics
    "a" => if element.attributes.contains("href") { Link } else { Generic }
    "em" => Emphasis
    "strong" => Strong
    "small" => Generic
    "s" => Deletion
    "cite" => Generic
    "q" => Generic
    "dfn" => Term
    "abbr" => Generic
    "ruby" => Generic
    "rt" => Generic
    "rp" => Generic
    "data" => Generic
    "time" => Time
    "code" => Code
    "var" => Generic
    "samp" => Generic
    "kbd" => Generic
    "sub" => Subscript
    "sup" => Superscript
    "i" => Generic
    "b" => Generic
    "u" => Generic
    "mark" => Mark
    "bdi" => Generic
    "bdo" => Generic
    "span" => Generic
    "br" => Generic
    "wbr" => Generic

    // Edits
    "ins" => Insertion
    "del" => Deletion

    // Embedded content
    "img" => compute_img_role(element)
    "iframe" => Generic
    "embed" => Generic
    "object" => Generic
    "video" => HtmlVideo
    "audio" => HtmlAudio
    "canvas" => HtmlCanvas
    "map" => Generic
    "area" => if element.attributes.contains("href") { Link } else { Generic }
    "svg" => Generic
    "math" => Math

    // Tabular data
    "table" => Table
    "caption" => Caption
    "colgroup" => Generic
    "col" => Generic
    "tbody" | "thead" | "tfoot" => RowGroup
    "tr" => Row
    "td" => Cell
    "th" => compute_th_role(element)

    // Forms
    "form" => if context.has_accessible_name { Form } else { Generic }
    "label" => HtmlLabel
    "input" => compute_input_role(element)
    "button" => Button
    "select" => compute_select_role(element)
    "datalist" => Listbox
    "optgroup" => Group
    "option" => Option
    "textarea" => Textbox
    "output" => Status
    "progress" => Progressbar
    "meter" => Meter
    "fieldset" => Group
    "legend" => Generic

    // Interactive elements
    "details" => Group
    "summary" => HtmlSummary
    "dialog" => Dialog
    "hgroup" => Group

    // Scripting
    "script" | "noscript" | "template" => Generic

    // Document structure
    "html" => Document
    "head" => Generic
    "title" => Generic
    "body" => Generic
    "header" => compute_header_role(context)
    "footer" => compute_footer_role(context)
    "search" => Search

    // Default
    _ => Generic
  }
}

// =============================================================================
// Contextual Role Helpers
// =============================================================================

///|
/// Compute role for <img> element
fn compute_img_role(element : @html.Element) -> Role {
  // img with empty alt is presentational, unless it has aria-label/aria-labelledby
  match element.attributes.get("alt") {
    Some(alt) if alt.is_empty() =>
      // Check if element has an accessible name source that overrides presentation
      if element.attributes.contains("aria-label") ||
        element.attributes.contains("aria-labelledby") {
        Img
      } else {
        Presentation
      }
    _ => Img
  }
}

///|
/// Compute role for <th> element based on scope
fn compute_th_role(element : @html.Element) -> Role {
  match element.attributes.get("scope") {
    Some("row") => RowHeader
    Some("rowgroup") => RowHeader
    _ => ColumnHeader
  }
}

///|
/// Compute role for <input> element based on type
fn compute_input_role(element : @html.Element) -> Role {
  let input_type = match element.attributes.get("type") {
    Some(t) => t.to_lower()
    Option::None => "text" // default type
  }
  match input_type {
    "button" | "submit" | "reset" | "image" => Button
    "checkbox" => Checkbox
    "radio" => Radio
    "range" => Slider
    "number" => SpinButton
    "search" => SearchBox
    "email" | "tel" | "url" | "text" | "password" => Textbox
    "hidden" => Generic
    "color" => Generic
    "date" | "datetime-local" | "month" | "time" | "week" => Generic
    "file" => Generic
    _ => Textbox
  }
}

///|
/// Compute role for <select> element
fn compute_select_role(element : @html.Element) -> Role {
  // Multiple select or size > 1 is listbox, otherwise combobox
  if element.attributes.contains("multiple") {
    return Listbox
  }
  // Check size attribute - if > 1, it's a listbox
  match element.attributes.get("size") {
    Some(size_str) => {
      // Simple numeric check for size attribute
      let size = parse_size_attr(size_str)
      if size > 1 {
        Listbox
      } else {
        Combobox
      }
    }
    _ => Combobox
  }
}

///|
/// Parse size attribute value (returns 1 if invalid)
fn parse_size_attr(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      break
    }
  }
  if result == 0 {
    1
  } else {
    result
  }
}

///|
/// Compute role for <header> element
fn compute_header_role(context : RoleMappingContext) -> Role {
  // header is banner only when direct child of body
  // or not inside article, aside, main, nav, or section
  if context.in_sectioning_content {
    Generic
  } else {
    Banner
  }
}

///|
/// Compute role for <footer> element
fn compute_footer_role(context : RoleMappingContext) -> Role {
  // footer is contentinfo only when direct child of body
  // or not inside article, aside, main, nav, or section
  if context.in_sectioning_content {
    Generic
  } else {
    ContentInfo
  }
}

// =============================================================================
// Role Properties
// =============================================================================

///|
/// Check if a role supports accessible name from contents
pub fn role_supports_name_from_content(role : Role) -> Bool {
  match role {
    Button
    | Checkbox
    | Link
    | MenuItem
    | MenuItemCheckbox
    | MenuItemRadio
    | Option
    | Radio
    | Switch
    | Tab
    | Tooltip
    | TreeItem
    | Heading
    | ListItem
    | Cell
    | ColumnHeader
    | GridCell
    | Row
    | RowHeader
    | HtmlSummary => true // summary element gets name from contents
    _ => false
  }
}

///|
/// Check if a role is inherently focusable
pub fn role_is_inherently_focusable(role : Role) -> Bool {
  match role {
    Button
    | Checkbox
    | Combobox
    | Link
    | Listbox
    | Menu
    | MenuBar
    | MenuItem
    | MenuItemCheckbox
    | MenuItemRadio
    | Option
    | Radio
    | Scrollbar
    | SearchBox
    | Slider
    | SpinButton
    | Switch
    | Tab
    | Textbox
    | Tree
    | TreeItem => true
    _ => false
  }
}

///|
/// Check if a role is a landmark role
pub fn role_is_landmark(role : Role) -> Bool {
  match role {
    Banner
    | Complementary
    | ContentInfo
    | Form
    | Main
    | Navigation
    | Region
    | Search => true
    _ => false
  }
}

///|
/// Check if element is sectioning content (affects header/footer role)
pub fn is_sectioning_content(tag : String) -> Bool {
  match tag.to_lower() {
    "article" | "aside" | "nav" | "section" | "main" => true
    _ => false
  }
}

// =============================================================================
// Heading Level Helper
// =============================================================================

///|
/// Get heading level from tag name or aria-level
pub fn get_heading_level(element : @html.Element) -> Int? {
  // First check aria-level
  match element.attributes.get("aria-level") {
    Some(level_str) => {
      let level = @strconv.parse_int(level_str) catch {
        _ => return Option::None
      }
      if level >= 1 && level <= 6 {
        return Some(level)
      }
    }
    Option::None => ()
  }

  // Then check tag name
  match element.tag.to_lower() {
    "h1" => Some(1)
    "h2" => Some(2)
    "h3" => Some(3)
    "h4" => Some(4)
    "h5" => Some(5)
    "h6" => Some(6)
    _ => Option::None
  }
}
