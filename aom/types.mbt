///|
/// Accessibility Object Model (AOM) Types
/// Based on WAI-ARIA 1.2 and HTML-AAM 1.0 specifications

// =============================================================================
// ARIA Roles (WAI-ARIA 1.2)
// =============================================================================

///|
/// ARIA Role categories based on WAI-ARIA specification
pub(all) enum Role {
  // Document structure roles
  Article
  Blockquote
  Caption
  Cell
  Code
  ColumnHeader
  Definition
  Deletion
  Directory
  Document
  Emphasis
  Feed
  Figure
  Generic
  Group
  Heading
  Img
  Insertion
  List
  ListItem
  Mark
  Math
  Meter
  None
  Note
  Paragraph
  Presentation
  Row
  RowGroup
  RowHeader
  Separator
  Strong
  Subscript
  Superscript
  Table
  Term
  Time
  Toolbar
  Tooltip

  // Widget roles
  Button
  Checkbox
  Combobox
  GridCell
  Link
  Listbox
  Menu
  MenuBar
  MenuItem
  MenuItemCheckbox
  MenuItemRadio
  Option
  Progressbar
  Radio
  RadioGroup
  Scrollbar
  SearchBox
  Slider
  SpinButton
  Switch
  Tab
  TabList
  TabPanel
  Textbox
  Tree
  TreeGrid
  TreeItem

  // Landmark roles
  Application
  Banner
  Complementary
  ContentInfo
  Form
  Main
  Navigation
  Region
  Search

  // Live region roles
  Alert
  AlertDialog
  Dialog
  Log
  Marquee
  Status
  Timer

  // Window roles
  Window

  // HTML-specific mappings (not in ARIA but needed for HTML-AAM)
  HtmlAudio
  HtmlVideo
  HtmlCanvas
  HtmlLabel
  HtmlSummary
} derive(Eq, Show)

///|
pub fn Role::to_string(self : Role) -> String {
  match self {
    Article => "article"
    Blockquote => "blockquote"
    Caption => "caption"
    Cell => "cell"
    Code => "code"
    ColumnHeader => "columnheader"
    Definition => "definition"
    Deletion => "deletion"
    Directory => "directory"
    Document => "document"
    Emphasis => "emphasis"
    Feed => "feed"
    Figure => "figure"
    Generic => "generic"
    Group => "group"
    Heading => "heading"
    Img => "img"
    Insertion => "insertion"
    List => "list"
    ListItem => "listitem"
    Mark => "mark"
    Math => "math"
    Meter => "meter"
    None => "none"
    Note => "note"
    Paragraph => "paragraph"
    Presentation => "presentation"
    Row => "row"
    RowGroup => "rowgroup"
    RowHeader => "rowheader"
    Separator => "separator"
    Strong => "strong"
    Subscript => "subscript"
    Superscript => "superscript"
    Table => "table"
    Term => "term"
    Time => "time"
    Toolbar => "toolbar"
    Tooltip => "tooltip"
    Button => "button"
    Checkbox => "checkbox"
    Combobox => "combobox"
    GridCell => "gridcell"
    Link => "link"
    Listbox => "listbox"
    Menu => "menu"
    MenuBar => "menubar"
    MenuItem => "menuitem"
    MenuItemCheckbox => "menuitemcheckbox"
    MenuItemRadio => "menuitemradio"
    Option => "option"
    Progressbar => "progressbar"
    Radio => "radio"
    RadioGroup => "radiogroup"
    Scrollbar => "scrollbar"
    SearchBox => "searchbox"
    Slider => "slider"
    SpinButton => "spinbutton"
    Switch => "switch"
    Tab => "tab"
    TabList => "tablist"
    TabPanel => "tabpanel"
    Textbox => "textbox"
    Tree => "tree"
    TreeGrid => "treegrid"
    TreeItem => "treeitem"
    Application => "application"
    Banner => "banner"
    Complementary => "complementary"
    ContentInfo => "contentinfo"
    Form => "form"
    Main => "main"
    Navigation => "navigation"
    Region => "region"
    Search => "search"
    Alert => "alert"
    AlertDialog => "alertdialog"
    Dialog => "dialog"
    Log => "log"
    Marquee => "marquee"
    Status => "status"
    Timer => "timer"
    Window => "window"
    HtmlAudio => "html-audio"
    HtmlVideo => "html-video"
    HtmlCanvas => "html-canvas"
    HtmlLabel => "html-label"
    HtmlSummary => "html-summary"
  }
}

///|
pub fn Role::from_string(s : String) -> Role? {
  match s {
    "article" => Some(Article)
    "blockquote" => Some(Blockquote)
    "caption" => Some(Caption)
    "cell" => Some(Cell)
    "code" => Some(Code)
    "columnheader" => Some(ColumnHeader)
    "definition" => Some(Definition)
    "deletion" => Some(Deletion)
    "directory" => Some(Directory)
    "document" => Some(Document)
    "emphasis" => Some(Emphasis)
    "feed" => Some(Feed)
    "figure" => Some(Figure)
    "generic" => Some(Generic)
    "group" => Some(Group)
    "heading" => Some(Heading)
    "img" | "image" => Some(Img)
    "insertion" => Some(Insertion)
    "list" => Some(List)
    "listitem" => Some(ListItem)
    "mark" => Some(Mark)
    "math" => Some(Math)
    "meter" => Some(Meter)
    "none" => Some(None)
    "note" => Some(Note)
    "paragraph" => Some(Paragraph)
    "presentation" => Some(Presentation)
    "row" => Some(Row)
    "rowgroup" => Some(RowGroup)
    "rowheader" => Some(RowHeader)
    "separator" => Some(Separator)
    "strong" => Some(Strong)
    "subscript" => Some(Subscript)
    "superscript" => Some(Superscript)
    "table" => Some(Table)
    "term" => Some(Term)
    "time" => Some(Time)
    "toolbar" => Some(Toolbar)
    "tooltip" => Some(Tooltip)
    "button" => Some(Button)
    "checkbox" => Some(Checkbox)
    "combobox" => Some(Combobox)
    "gridcell" => Some(GridCell)
    "link" => Some(Link)
    "listbox" => Some(Listbox)
    "menu" => Some(Menu)
    "menubar" => Some(MenuBar)
    "menuitem" => Some(MenuItem)
    "menuitemcheckbox" => Some(MenuItemCheckbox)
    "menuitemradio" => Some(MenuItemRadio)
    "option" => Some(Option)
    "progressbar" => Some(Progressbar)
    "radio" => Some(Radio)
    "radiogroup" => Some(RadioGroup)
    "scrollbar" => Some(Scrollbar)
    "searchbox" => Some(SearchBox)
    "slider" => Some(Slider)
    "spinbutton" => Some(SpinButton)
    "switch" => Some(Switch)
    "tab" => Some(Tab)
    "tablist" => Some(TabList)
    "tabpanel" => Some(TabPanel)
    "textbox" => Some(Textbox)
    "tree" => Some(Tree)
    "treegrid" => Some(TreeGrid)
    "treeitem" => Some(TreeItem)
    "application" => Some(Application)
    "banner" => Some(Banner)
    "complementary" => Some(Complementary)
    "contentinfo" => Some(ContentInfo)
    "form" => Some(Form)
    "main" => Some(Main)
    "navigation" => Some(Navigation)
    "region" => Some(Region)
    "search" => Some(Search)
    "alert" => Some(Alert)
    "alertdialog" => Some(AlertDialog)
    "dialog" => Some(Dialog)
    "log" => Some(Log)
    "marquee" => Some(Marquee)
    "status" => Some(Status)
    "timer" => Some(Timer)
    "window" => Some(Window)
    _ => Option::None
  }
}

// =============================================================================
// ARIA States and Properties
// =============================================================================

///|
/// ARIA state values
pub(all) enum State {
  // Boolean states
  Busy
  Checked
  Disabled
  Expanded
  Grabbed
  Hidden
  Invalid
  Pressed
  Selected

  // Tristate
  CheckedMixed
  PressedMixed
} derive(Eq, Show)

///|
pub fn State::to_string(self : State) -> String {
  match self {
    Busy => "busy"
    Checked => "checked"
    Disabled => "disabled"
    Expanded => "expanded"
    Grabbed => "grabbed"
    Hidden => "hidden"
    Invalid => "invalid"
    Pressed => "pressed"
    Selected => "selected"
    CheckedMixed => "mixed"
    PressedMixed => "mixed"
  }
}

// =============================================================================
// Accessibility Node
// =============================================================================

///|
/// Bounding rectangle for spatial information
pub(all) struct Bounds {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn Bounds::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Bounds {
  { x, y, width, height }
}

///|
pub fn Bounds::default() -> Bounds {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
/// Core accessibility node in the AOM tree
pub(all) struct AccessibilityNode {
  // Identity
  id : String

  // HTML-AAM computed role
  role : Role

  // Accessible name (accname spec)
  name : String?

  // Accessible description
  description : String?

  // Heading level (1-6, only for Heading role)
  level : Int?

  // Current states
  states : Array[State]

  // ARIA properties
  properties : Map[String, String]

  // Spatial information (from layout)
  bounds : Bounds?

  // Tree structure
  children : Array[AccessibilityNode]

  // Focusable / interactive
  focusable : Bool

  // Tabindex value for tab navigation order
  // None = no explicit tabindex (inherent focusability only)
  // Some(-1) = programmatically focusable but not via Tab
  // Some(0) = focusable in document order
  // Some(n) where n > 0 = focusable in priority order
  tabindex : Int?

  // Reference to source element id (for debugging/tooling)
  source_id : String?

  // === AI scraping enhancements ===

  // URL for links (href attribute)
  href : String?

  // Original HTML tag name (for disambiguation when role is generic)
  tag_name : String?

  // CSS selector for element targeting (for AI interaction)
  selector : String?

  // Whether this is visible content (false for style, script, head content)
  visible : Bool

  // Sequential reference ID for AI interaction (e.g., "ref_1", "ref_2")
  // Simple, unique identifier for element targeting
  ref_id : String?

  // === Form input enhancements ===

  // Input type for form elements (text, email, password, checkbox, radio, etc.)
  input_type : String?

  // Placeholder text for form inputs
  placeholder : String?

  // Current value of form inputs
  input_value : String?

  // Whether the form field is required
  required : Bool
}

///|
pub fn AccessibilityNode::new(id : String, role : Role) -> AccessibilityNode {
  {
    id,
    role,
    name: Option::None,
    description: Option::None,
    level: Option::None,
    states: [],
    properties: {},
    bounds: Option::None,
    children: [],
    focusable: false,
    tabindex: Option::None,
    source_id: Option::None,
    href: Option::None,
    tag_name: Option::None,
    selector: Option::None,
    visible: true,
    ref_id: Option::None,
    input_type: Option::None,
    placeholder: Option::None,
    input_value: Option::None,
    required: false,
  }
}

///|
pub fn AccessibilityNode::with_name(
  self : AccessibilityNode,
  name : String,
) -> AccessibilityNode {
  { ..self, name: Some(name) }
}

///|
pub fn AccessibilityNode::with_bounds(
  self : AccessibilityNode,
  bounds : Bounds,
) -> AccessibilityNode {
  { ..self, bounds: Some(bounds) }
}

///|
pub fn AccessibilityNode::with_level(
  self : AccessibilityNode,
  level : Int,
) -> AccessibilityNode {
  { ..self, level: Some(level) }
}

///|
pub fn AccessibilityNode::add_state(
  self : AccessibilityNode,
  state : State,
) -> AccessibilityNode {
  let new_states = self.states.copy()
  new_states.push(state)
  { ..self, states: new_states }
}

///|
pub fn AccessibilityNode::add_child(
  self : AccessibilityNode,
  child : AccessibilityNode,
) -> AccessibilityNode {
  let new_children = self.children.copy()
  new_children.push(child)
  { ..self, children: new_children }
}

///|
pub fn AccessibilityNode::set_focusable(
  self : AccessibilityNode,
  focusable : Bool,
) -> AccessibilityNode {
  { ..self, focusable, }
}

///|
pub fn AccessibilityNode::with_tabindex(
  self : AccessibilityNode,
  tabindex : Int,
) -> AccessibilityNode {
  { ..self, tabindex: Some(tabindex) }
}

// =============================================================================
// Accessibility Tree
// =============================================================================

///|
/// The complete accessibility tree
pub(all) struct AccessibilityTree {
  root : AccessibilityNode
  // Index for fast lookup by id
  node_map : Map[String, AccessibilityNode]
}

///|
pub fn AccessibilityTree::new(root : AccessibilityNode) -> AccessibilityTree {
  let node_map : Map[String, AccessibilityNode] = {}
  build_node_map(root, node_map)
  { root, node_map }
}

///|
fn build_node_map(
  node : AccessibilityNode,
  map : Map[String, AccessibilityNode],
) -> Unit {
  map[node.id] = node
  for child in node.children {
    build_node_map(child, map)
  }
}

///|
pub fn AccessibilityTree::find_by_id(
  self : AccessibilityTree,
  id : String,
) -> AccessibilityNode? {
  self.node_map.get(id)
}

///|
pub fn AccessibilityTree::find_by_role(
  self : AccessibilityTree,
  role : Role,
) -> Array[AccessibilityNode] {
  let result : Array[AccessibilityNode] = []
  find_by_role_recursive(self.root, role, result)
  result
}

///|
fn find_by_role_recursive(
  node : AccessibilityNode,
  role : Role,
  result : Array[AccessibilityNode],
) -> Unit {
  if node.role == role {
    result.push(node)
  }
  for child in node.children {
    find_by_role_recursive(child, role, result)
  }
}

///|
pub fn AccessibilityTree::find_focusable(
  self : AccessibilityTree,
) -> Array[AccessibilityNode] {
  let result : Array[AccessibilityNode] = []
  find_focusable_recursive(self.root, result)
  result
}

///|
fn find_focusable_recursive(
  node : AccessibilityNode,
  result : Array[AccessibilityNode],
) -> Unit {
  if node.focusable {
    result.push(node)
  }
  for child in node.children {
    find_focusable_recursive(child, result)
  }
}

///|
/// Find node by its source element id
pub fn AccessibilityTree::find_by_source_id(
  self : AccessibilityTree,
  source_id : String,
) -> AccessibilityNode? {
  find_by_source_id_recursive(self.root, source_id)
}

///|
fn find_by_source_id_recursive(
  node : AccessibilityNode,
  source_id : String,
) -> AccessibilityNode? {
  match node.source_id {
    Some(id) if id == source_id => return Some(node)
    _ => ()
  }
  for child in node.children {
    match find_by_source_id_recursive(child, source_id) {
      Some(found) => return Some(found)
      Option::None => ()
    }
  }
  Option::None
}
