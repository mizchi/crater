///|
/// WPT Accessibility Tests
/// Based on tests from https://github.com/web-platform-tests/wpt

// =============================================================================
// accname: Name from content
// =============================================================================

test "accname: button name from content" {
  let html = "<button>Submit</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Submit\")")
}

///|
test "accname: link name from content" {
  let html = "<a href=\"/\">Home Page</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Home Page\")")
}

///|
test "accname: heading name from content" {
  let html = "<h1>Welcome to My Site</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Welcome to My Site\")")
}

// =============================================================================
// accname: aria-label
// =============================================================================

///|
test "accname: aria-label overrides content" {
  let html = "<button aria-label=\"Close\">X</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Close\")")
}

///|
test "accname: aria-label on input" {
  let html = "<input type=\"text\" aria-label=\"Search\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Search\")")
}

// =============================================================================
// accname: Native text alternatives
// =============================================================================

///|
test "accname: img alt attribute" {
  let html = "<img src=\"logo.png\" alt=\"Company Logo\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Company Logo\")")
}

///|
test "accname: input submit default value" {
  let html = "<input type=\"submit\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Submit\")")
}

///|
test "accname: input submit custom value" {
  let html = "<input type=\"submit\" value=\"Send\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Send\")")
}

///|
test "accname: input reset default value" {
  let html = "<input type=\"reset\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Reset\")")
}

// =============================================================================
// accname: title attribute as fallback
// =============================================================================

///|
test "accname: title attribute fallback for link" {
  let html = "<a href=\"/\" title=\"Go to home\"></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Go to home\")")
}

// =============================================================================
// html-aam: Role mapping
// =============================================================================

///|
test "html-aam: button role" {
  let html = "<button>Click</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "html-aam: link role" {
  let html = "<a href=\"/\">Link</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Link")
}

///|
test "html-aam: anchor without href is generic" {
  let html = "<a>Not a link</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Generic")
}

///|
test "html-aam: input checkbox role" {
  let html = "<input type=\"checkbox\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Checkbox")
}

///|
test "html-aam: input radio role" {
  let html = "<input type=\"radio\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Radio")
}

///|
test "html-aam: input text role" {
  let html = "<input type=\"text\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam: input search role" {
  let html = "<input type=\"search\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="SearchBox")
}

///|
test "html-aam: input range role" {
  let html = "<input type=\"range\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Slider")
}

///|
test "html-aam: select role" {
  let html = "<select><option>A</option></select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Combobox")
}

///|
test "html-aam: select multiple role" {
  let html = "<select multiple><option>A</option></select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Listbox")
}

///|
test "html-aam: textarea role" {
  let html = "<textarea></textarea>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam: ul role" {
  let html = "<ul><li>Item</li></ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="List")
}

///|
test "html-aam: ol role" {
  let html = "<ol><li>Item</li></ol>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="List")
}

///|
test "html-aam: li role" {
  let html = "<li>Item</li>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="ListItem")
}

///|
test "html-aam: nav role" {
  let html = "<nav>Navigation</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Navigation")
}

///|
test "html-aam: main role" {
  let html = "<main>Main content</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Main")
}

///|
test "html-aam: article role" {
  let html = "<article>Article</article>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Article")
}

///|
test "html-aam: aside role" {
  let html = "<aside>Sidebar</aside>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Complementary")
}

///|
test "html-aam: table role" {
  let html = "<table><tr><td>Cell</td></tr></table>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Table")
}

///|
test "html-aam: hr role" {
  let html = "<hr />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Separator")
}

///|
test "html-aam: progress role" {
  let html = "<progress value=\"50\" max=\"100\"></progress>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Progressbar")
}

///|
test "html-aam: meter role" {
  let html = "<meter value=\"50\" min=\"0\" max=\"100\"></meter>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Meter")
}

///|
test "html-aam: dialog role" {
  let html = "<dialog>Dialog content</dialog>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Dialog")
}

// =============================================================================
// html-aam: Heading levels
// =============================================================================

///|
test "html-aam: h1 level" {
  let html = "<h1>Heading 1</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
  inspect(tree.root.level, content="Some(1)")
}

///|
test "html-aam: h2 level" {
  let html = "<h2>Heading 2</h2>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.level, content="Some(2)")
}

///|
test "html-aam: h6 level" {
  let html = "<h6>Heading 6</h6>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.level, content="Some(6)")
}

// =============================================================================
// html-aam: States
// =============================================================================

///|
test "html-aam: checked checkbox" {
  let html = "<input type=\"checkbox\" checked />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.states.length(), content="1")
  inspect(tree.root.states[0], content="Checked")
}

///|
test "html-aam: disabled button" {
  let html = "<button disabled>Disabled</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_disabled = tree.root.states.iter().any(fn(s) { s == Disabled })
  inspect(has_disabled, content="true")
}

///|
test "html-aam: selected option" {
  let html = "<option selected>Selected</option>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_selected = tree.root.states.iter().any(fn(s) { s == Selected })
  inspect(has_selected, content="true")
}

// =============================================================================
// wai-aria: Explicit role override
// =============================================================================

///|
test "wai-aria: role attribute overrides implicit role" {
  let html = "<div role=\"button\">Custom button</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "wai-aria: role=navigation on div" {
  let html = "<div role=\"navigation\">Nav</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Navigation")
}

///|
test "wai-aria: role=link on span" {
  let html = "<span role=\"link\">Link</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Link")
}

// =============================================================================
// wai-aria: ARIA states
// =============================================================================

///|
test "wai-aria: aria-checked true" {
  let html = "<div role=\"checkbox\" aria-checked=\"true\">Checked</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_checked = tree.root.states.iter().any(fn(s) { s == Checked })
  inspect(has_checked, content="true")
}

///|
test "wai-aria: aria-checked mixed" {
  let html = "<div role=\"checkbox\" aria-checked=\"mixed\">Mixed</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_mixed = tree.root.states.iter().any(fn(s) { s == CheckedMixed })
  inspect(has_mixed, content="true")
}

///|
test "wai-aria: aria-expanded true" {
  let html = "<button aria-expanded=\"true\">Expanded</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_expanded = tree.root.states.iter().any(fn(s) { s == Expanded })
  inspect(has_expanded, content="true")
}

///|
test "wai-aria: aria-pressed true" {
  let html = "<button aria-pressed=\"true\">Pressed</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_pressed = tree.root.states.iter().any(fn(s) { s == Pressed })
  inspect(has_pressed, content="true")
}

///|
test "wai-aria: aria-disabled true" {
  let html = "<button aria-disabled=\"true\">Disabled</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let has_disabled = tree.root.states.iter().any(fn(s) { s == Disabled })
  inspect(has_disabled, content="true")
}

// =============================================================================
// accname: aria-labelledby
// =============================================================================

///|
test "accname: aria-labelledby single reference" {
  let html =
    #|<div>
    #|  <span id="label1">Username</span>
    #|  <input type="text" aria-labelledby="label1" />
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Use find_by_role to search the entire tree, get first match
  let inputs = tree.find_by_role(Textbox)
  inspect(inputs[0].name, content="Some(\"Username\")")
}

///|
test "accname: aria-labelledby multiple references" {
  let html =
    #|<div>
    #|  <span id="first">First</span>
    #|  <span id="last">Last</span>
    #|  <input type="text" aria-labelledby="first last" />
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let inputs = tree.find_by_role(Textbox)
  inspect(inputs[0].name, content="Some(\"First Last\")")
}

///|
test "accname: aria-labelledby overrides aria-label" {
  let html =
    #|<div>
    #|  <span id="ref">Referenced Label</span>
    #|  <button aria-label="Inline Label" aria-labelledby="ref">Content</button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let buttons = tree.find_by_role(Button)
  inspect(buttons[0].name, content="Some(\"Referenced Label\")")
}

///|
test "accname: aria-labelledby references hidden element" {
  let html =
    #|<div>
    #|  <span id="hidden-label" aria-hidden="true">Hidden Label</span>
    #|  <button aria-labelledby="hidden-label">Visible Content</button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let buttons = tree.find_by_role(Button)
  // aria-labelledby can reference aria-hidden elements
  inspect(buttons[0].name, content="Some(\"Hidden Label\")")
}

///|
test "accname: aria-labelledby ignores invalid reference" {
  let html = "<button aria-labelledby=\"nonexistent\">Fallback Content</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  // Falls back to content when reference is invalid
  inspect(tree.root.name, content="Some(\"Fallback Content\")")
}

///|
test "accname: aria-labelledby with self-reference" {
  let html =
    #|<div>
    #|  <span id="extra">Extra</span>
    #|  <button id="btn" aria-labelledby="btn extra">Self</button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let buttons = tree.find_by_role(Button)
  // Self-reference includes button's content, plus referenced element
  inspect(buttons[0].name, content="Some(\"Self Extra\")")
}
