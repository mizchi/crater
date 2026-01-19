///|
/// ARIA Snapshot Generation
/// Generates Playwright-compatible YAML format from AccessibilityTree
/// https://playwright.dev/docs/aria-snapshots

// =============================================================================
// Public API - YAML Format
// =============================================================================

///|
/// Generate an ARIA snapshot in YAML format from an AccessibilityTree
pub fn AccessibilityTree::to_aria_snapshot(self : AccessibilityTree) -> String {
  self.root.to_aria_snapshot_with_indent(0)
}

///|
/// Generate an ARIA snapshot for a single node
pub fn AccessibilityNode::to_aria_snapshot(self : AccessibilityNode) -> String {
  self.to_aria_snapshot_with_indent(0)
}

// =============================================================================
// Public API - JSON Format
// =============================================================================

///|
/// Generate an ARIA snapshot in JSON format from an AccessibilityTree
pub fn AccessibilityTree::to_aria_json(self : AccessibilityTree) -> String {
  self.root.to_aria_json()
}

///|
/// Generate an ARIA snapshot in JSON format for a single node
pub fn AccessibilityNode::to_aria_json(self : AccessibilityNode) -> String {
  let buf = StringBuilder::new()
  render_node_json(self, buf, 0)
  buf.to_string()
}

///|
fn render_node_json(
  node : AccessibilityNode,
  buf : StringBuilder,
  indent : Int,
) -> Unit {
  write_indent(buf, indent)
  buf.write_string("{\n")

  // Role
  write_indent(buf, indent + 1)
  buf.write_string("\"role\": \"")
  buf.write_string(role_to_snapshot_string(node.role))
  buf.write_string("\"")

  // Ref ID (for AI - simple sequential identifier for element targeting)
  match node.ref_id {
    Some(ref_id) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"ref\": \"")
      buf.write_string(escape_string(ref_id))
      buf.write_string("\"")
    }
    None => ()
  }

  // Name
  match node.name {
    Some(name) if not(name.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"name\": \"")
      buf.write_string(escape_string(name))
      buf.write_string("\"")
    }
    _ => ()
  }

  // Level
  match node.level {
    Some(level) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"level\": ")
      buf.write_string(level.to_string())
    }
    None => ()
  }

  // Focusable (for AI - helps identify interactive elements)
  if node.focusable {
    buf.write_string(",\n")
    write_indent(buf, indent + 1)
    buf.write_string("\"focusable\": true")
  }

  // Tabindex (for AI - helps understand navigation order)
  match node.tabindex {
    Some(tabindex) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"tabindex\": ")
      buf.write_string(tabindex.to_string())
    }
    None => ()
  }

  // Source ID (for AI - reference to original HTML element)
  match node.source_id {
    Some(source_id) if not(source_id.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"sourceId\": \"")
      buf.write_string(escape_string(source_id))
      buf.write_string("\"")
    }
    _ => ()
  }

  // href (for AI - link URL)
  match node.href {
    Some(href) if not(href.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"href\": \"")
      buf.write_string(escape_string(href))
      buf.write_string("\"")
    }
    _ => ()
  }

  // Tag name (for AI - original HTML tag)
  match node.tag_name {
    Some(tag) if not(tag.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"tag\": \"")
      buf.write_string(escape_string(tag))
      buf.write_string("\"")
    }
    _ => ()
  }

  // Selector (for AI - CSS selector for element targeting)
  match node.selector {
    Some(sel) if not(sel.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"selector\": \"")
      buf.write_string(escape_string(sel))
      buf.write_string("\"")
    }
    _ => ()
  }

  // Visible flag (for AI - false for style/script/meta content)
  if not(node.visible) {
    buf.write_string(",\n")
    write_indent(buf, indent + 1)
    buf.write_string("\"visible\": false")
  }

  // Bounds (for AI - spatial information)
  match node.bounds {
    Some(bounds) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"bounds\": { \"x\": ")
      buf.write_string(bounds.x.to_string())
      buf.write_string(", \"y\": ")
      buf.write_string(bounds.y.to_string())
      buf.write_string(", \"width\": ")
      buf.write_string(bounds.width.to_string())
      buf.write_string(", \"height\": ")
      buf.write_string(bounds.height.to_string())
      buf.write_string(" }")
    }
    None => ()
  }

  // Form input fields (for AI - form interaction)
  match node.input_type {
    Some(input_type) if not(input_type.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"inputType\": \"")
      buf.write_string(escape_string(input_type))
      buf.write_string("\"")
    }
    _ => ()
  }
  match node.placeholder {
    Some(placeholder) if not(placeholder.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"placeholder\": \"")
      buf.write_string(escape_string(placeholder))
      buf.write_string("\"")
    }
    _ => ()
  }
  match node.input_value {
    Some(value) if not(value.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"value\": \"")
      buf.write_string(escape_string(value))
      buf.write_string("\"")
    }
    _ => ()
  }
  if node.required {
    buf.write_string(",\n")
    write_indent(buf, indent + 1)
    buf.write_string("\"required\": true")
  }

  // Aggregated text content (for paragraphs, headings, etc.)
  match node.text {
    Some(text) if not(text.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"text\": \"")
      buf.write_string(escape_string(text))
      buf.write_string("\"")
    }
    _ => ()
  }

  // Select options
  if not(node.options.is_empty()) {
    buf.write_string(",\n")
    write_indent(buf, indent + 1)
    buf.write_string("\"options\": [\n")
    for i, option in node.options {
      if i > 0 {
        buf.write_string(",\n")
      }
      write_indent(buf, indent + 2)
      buf.write_string("{ \"value\": \"")
      buf.write_string(escape_string(option.value))
      buf.write_string("\", \"label\": \"")
      buf.write_string(escape_string(option.label))
      buf.write_string("\"")
      if option.selected {
        buf.write_string(", \"selected\": true")
      }
      buf.write_string(" }")
    }
    buf.write_string("\n")
    write_indent(buf, indent + 1)
    buf.write_string("]")
  }

  // Labelled by reference
  match node.labelled_by {
    Some(labelled_by) if not(labelled_by.is_empty()) => {
      buf.write_string(",\n")
      write_indent(buf, indent + 1)
      buf.write_string("\"labelledBy\": \"")
      buf.write_string(escape_string(labelled_by))
      buf.write_string("\"")
    }
    _ => ()
  }

  // States
  if not(node.states.is_empty()) {
    buf.write_string(",\n")
    write_indent(buf, indent + 1)
    buf.write_string("\"states\": [")
    for i, state in node.states {
      if i > 0 {
        buf.write_string(", ")
      }
      buf.write_string("\"")
      buf.write_string(state_to_json_string(state))
      buf.write_string("\"")
    }
    buf.write_string("]")
  }

  // Children
  if not(node.children.is_empty()) {
    buf.write_string(",\n")
    write_indent(buf, indent + 1)
    buf.write_string("\"children\": [\n")
    for i, child in node.children {
      if i > 0 {
        buf.write_string(",\n")
      }
      render_node_json(child, buf, indent + 2)
    }
    buf.write_string("\n")
    write_indent(buf, indent + 1)
    buf.write_string("]")
  }
  buf.write_string("\n")
  write_indent(buf, indent)
  buf.write_string("}")
}

///|
fn state_to_json_string(state : State) -> String {
  match state {
    Busy => "busy"
    Checked => "checked"
    CheckedMixed => "checked-mixed"
    Disabled => "disabled"
    Expanded => "expanded"
    Grabbed => "grabbed"
    Hidden => "hidden"
    Invalid => "invalid"
    Pressed => "pressed"
    PressedMixed => "pressed-mixed"
    Selected => "selected"
  }
}

// =============================================================================
// Internal Implementation
// =============================================================================

///|
fn AccessibilityNode::to_aria_snapshot_with_indent(
  self : AccessibilityNode,
  indent : Int,
) -> String {
  let buf = StringBuilder::new()
  render_node(self, buf, indent)
  buf.to_string()
}

///|
fn render_node(
  node : AccessibilityNode,
  buf : StringBuilder,
  indent : Int,
) -> Unit {
  // Skip nodes with no role or generic role
  if node.role == Generic && node.name is None && node.children.is_empty() {
    return
  }

  // Write indentation
  write_indent(buf, indent)
  buf.write_string("- ")

  // Write role
  buf.write_string(role_to_snapshot_string(node.role))

  // Write name if present
  match node.name {
    Some(name) if not(name.is_empty()) => {
      buf.write_string(" \"")
      buf.write_string(escape_string(name))
      buf.write_string("\"")
    }
    _ => ()
  }

  // Write attributes
  render_attributes(node, buf)

  // Handle children
  if node.children.is_empty() {
    buf.write_string("\n")
  } else {
    // Check if all children are text-like (no nested structure)
    let has_complex_children = node.children
      .iter()
      .any(fn(child) { not(child.children.is_empty()) || child.role != Generic })
    if not(has_complex_children) && node.children.length() == 1 {
      // Single simple child - render inline
      match node.children[0].name {
        Some(text) if not(text.is_empty()) => {
          buf.write_string(": ")
          buf.write_string(escape_string(text))
        }
        _ => ()
      }
      buf.write_string("\n")
    } else {
      // Complex children - render nested
      buf.write_string(":\n")
      for child in node.children {
        render_node(child, buf, indent + 1)
      }
    }
  }
}

///|
fn render_attributes(node : AccessibilityNode, buf : StringBuilder) -> Unit {
  let attrs : Array[String] = []

  // Level attribute (for headings)
  match node.level {
    Some(level) => attrs.push("level=\{level}")
    None => ()
  }

  // State attributes
  for state in node.states {
    match state {
      Checked => attrs.push("checked")
      CheckedMixed => attrs.push("checked=mixed")
      Disabled => attrs.push("disabled")
      Expanded => attrs.push("expanded")
      Pressed => attrs.push("pressed")
      PressedMixed => attrs.push("pressed=mixed")
      Selected => attrs.push("selected")
      _ => ()
    }
  }

  // Write attributes if any
  if not(attrs.is_empty()) {
    buf.write_string(" [")
    for i, attr in attrs {
      if i > 0 {
        buf.write_string("][")
      }
      buf.write_string(attr)
    }
    buf.write_string("]")
  }
}

///|
fn write_indent(buf : StringBuilder, level : Int) -> Unit {
  for _ in 0..<level {
    buf.write_string("  ")
  }
}

///|
fn escape_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn role_to_snapshot_string(role : Role) -> String {
  match role {
    // Landmarks
    Banner => "banner"
    Complementary => "complementary"
    ContentInfo => "contentinfo"
    Form => "form"
    Main => "main"
    Navigation => "navigation"
    Region => "region"
    Search => "search"

    // Document structure
    Article => "article"
    Cell => "cell"
    ColumnHeader => "columnheader"
    Definition => "definition"
    Directory => "directory"
    Document => "document"
    Feed => "feed"
    Figure => "figure"
    Generic => "generic"
    Group => "group"
    Heading => "heading"
    Img => "img"
    List => "list"
    ListItem => "listitem"
    Math => "math"
    None => "none"
    Note => "note"
    Paragraph => "paragraph"
    Presentation => "presentation"
    Row => "row"
    RowGroup => "rowgroup"
    RowHeader => "rowheader"
    Separator => "separator"
    Table => "table"
    Term => "term"
    Toolbar => "toolbar"
    Tooltip => "tooltip"

    // Widgets
    Alert => "alert"
    AlertDialog => "alertdialog"
    Application => "application"
    Button => "button"
    Checkbox => "checkbox"
    Combobox => "combobox"
    Dialog => "dialog"
    GridCell => "gridcell"
    Link => "link"
    Listbox => "listbox"
    Log => "log"
    Marquee => "marquee"
    Menu => "menu"
    MenuBar => "menubar"
    MenuItem => "menuitem"
    MenuItemCheckbox => "menuitemcheckbox"
    MenuItemRadio => "menuitemradio"
    Meter => "meter"
    Option => "option"
    Progressbar => "progressbar"
    Radio => "radio"
    RadioGroup => "radiogroup"
    Scrollbar => "scrollbar"
    SearchBox => "searchbox"
    Slider => "slider"
    SpinButton => "spinbutton"
    Status => "status"
    Switch => "switch"
    Tab => "tab"
    TabList => "tablist"
    TabPanel => "tabpanel"
    Textbox => "textbox"
    Timer => "timer"
    Tree => "tree"
    TreeGrid => "treegrid"
    TreeItem => "treeitem"

    // Text-level semantics
    Caption => "caption"
    Code => "code"
    Deletion => "deletion"
    Emphasis => "emphasis"
    Insertion => "insertion"
    Strong => "strong"
    Subscript => "subscript"
    Superscript => "superscript"
    Time => "time"
    Blockquote => "blockquote"
    Mark => "mark"

    // Window roles
    Window => "window"

    // HTML-specific mappings
    HtmlAudio => "audio"
    HtmlVideo => "video"
    HtmlCanvas => "canvas"
    HtmlLabel => "label"
    HtmlSummary => "summary"
  }
}
