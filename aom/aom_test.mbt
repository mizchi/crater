///|
/// Tests for AOM module
test "basic role mapping - button" {
  let html = "<button>Click me</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
  inspect(tree.root.name, content="Some(\"Click me\")")
  inspect(tree.root.focusable, content="true")
}

///|
test "basic role mapping - link" {
  let html = "<a href=\"/home\">Home</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Link")
  inspect(tree.root.name, content="Some(\"Home\")")
}

///|
test "basic role mapping - heading" {
  let html = "<h1>Main Title</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
  inspect(tree.root.level, content="Some(1)")
  inspect(tree.root.name, content="Some(\"Main Title\")")
}

///|
test "role mapping - list" {
  let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="List")
  inspect(tree.root.children.length(), content="2")
  inspect(tree.root.children[0].role, content="ListItem")
}

///|
test "aria-label takes precedence" {
  let html = "<button aria-label=\"Close dialog\">X</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Close dialog\")")
}

///|
test "input types" {
  let html = "<input type=\"checkbox\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Checkbox")
}

///|
test "landmark - nav" {
  let html = "<nav><a href=\"/\">Home</a></nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Navigation")
  let landmarks = find_landmarks(tree)
  inspect(landmarks.length(), content="1")
}

///|
test "states - disabled button" {
  let html = "<button disabled>Can't click</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.states.length(), content="1")
  inspect(tree.root.states[0], content="Disabled")
  inspect(tree.root.focusable, content="false")
}

///|
test "find headings" {
  let html = "<div><h1>Title</h1><p>Content</p><h2>Subtitle</h2></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let headings = find_headings(tree)
  inspect(headings.length(), content="2")
  inspect(headings[0].level, content="Some(1)")
  inspect(headings[1].level, content="Some(2)")
}

///|
test "find interactive elements" {
  let html =
    #|<div>
    #|  <button>Click</button>
    #|  <a href="/page">Link</a>
    #|  <input type="text" />
    #|  <p>Plain text</p>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let interactive = find_interactive(tree)
  inspect(interactive.length(), content="3")
}

///|
test "explicit role attribute" {
  let html = "<div role=\"button\">Custom Button</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "img with alt" {
  let html = "<img src=\"logo.png\" alt=\"Company Logo\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Img")
  inspect(tree.root.name, content="Some(\"Company Logo\")")
}

///|
test "img with empty alt is skipped (presentational)" {
  // img with alt="" is presentational and removed from accessibility tree
  // The tree builder returns a Generic wrapper since the element is skipped
  let html = "<div><img src=\"decorative.png\" alt=\"\" /><span>Text</span></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  // The img should be skipped, only span's text content should remain
  inspect(tree.root.children.length(), content="1")
}

///|
test "label[for] association" {
  let html =
    #|<div>
    #|  <label for="myinput">Input label</label>
    #|  <input id="myinput" type="text" />
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the input element in the tree
  let inputs = tree.find_by_role(Textbox)
  inspect(inputs.length(), content="1")
  inspect(inputs[0].name, content="Some(\"Input label\")")
}

///|
test "label encapsulation - input wrapped in label" {
  let html =
    #|<div>
    #|  <label><input type="text" />textfield label</label>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let inputs = tree.find_by_role(Textbox)
  inspect(inputs.length(), content="1")
  inspect(inputs[0].name, content="Some(\"textfield label\")")
}

///|
test "label encapsulation - checkbox wrapped in label" {
  let html =
    #|<div>
    #|  <label><input type="checkbox" />checkbox label</label>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let checkboxes = tree.find_by_role(Checkbox)
  inspect(checkboxes.length(), content="1")
  inspect(checkboxes[0].name, content="Some(\"checkbox label\")")
}
