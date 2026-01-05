///|
/// Tests for ARIA Snapshot generation

///|
test "snapshot: simple button" {
  let node = AccessibilityNode::new("btn-1", Button).with_name("Click me")
  let snapshot = node.to_aria_snapshot()
  inspect(snapshot, content=
    #|- button "Click me"
    #|
  )
}

///|
test "snapshot: heading with level" {
  let node = AccessibilityNode::new("h1", Heading).with_name("Title").with_level(
    1,
  )
  let snapshot = node.to_aria_snapshot()
  inspect(snapshot, content=
    #|- heading "Title" [level=1]
    #|
  )
}

///|
test "snapshot: checkbox checked" {
  let node = AccessibilityNode::new("cb-1", Checkbox).with_name("Accept terms").add_state(
    Checked,
  )
  let snapshot = node.to_aria_snapshot()
  inspect(snapshot, content=
    #|- checkbox "Accept terms" [checked]
    #|
  )
}

///|
test "snapshot: nested list" {
  let item1 = AccessibilityNode::new("li-1", ListItem).with_name("Item 1")
  let item2 = AccessibilityNode::new("li-2", ListItem).with_name("Item 2")
  let list = AccessibilityNode::new("list-1", List).with_name("Features").add_child(
    item1,
  ).add_child(item2)
  let snapshot = list.to_aria_snapshot()
  inspect(snapshot, content=
    #|- list "Features":
    #|  - listitem "Item 1"
    #|  - listitem "Item 2"
    #|
  )
}

///|
test "snapshot: navigation with links" {
  let link1 = AccessibilityNode::new("link-1", Link).with_name("Home")
  let link2 = AccessibilityNode::new("link-2", Link).with_name("About")
  let nav = AccessibilityNode::new("nav-1", Navigation).with_name("Main").add_child(
    link1,
  ).add_child(link2)
  let snapshot = nav.to_aria_snapshot()
  inspect(snapshot, content=
    #|- navigation "Main":
    #|  - link "Home"
    #|  - link "About"
    #|
  )
}

///|
test "snapshot: disabled button" {
  let node = AccessibilityNode::new("btn-2", Button).with_name("Submit").add_state(
    Disabled,
  )
  let snapshot = node.to_aria_snapshot()
  inspect(snapshot, content=
    #|- button "Submit" [disabled]
    #|
  )
}

///|
test "snapshot: tree from html" {
  let html = "<button>Click me</button>"
  let tree = build_accessibility_tree_from_element(@html.parse(html).unwrap())
  let snapshot = tree.to_aria_snapshot()
  inspect(snapshot, content=
    (#|- button "Click me": Click me
    #|
)
  )
}

///|
test "snapshot: complex page structure" {
  let html =
    #|<nav aria-label="Main">
    #|  <a href="/">Home</a>
    #|  <a href="/about">About</a>
    #|</nav>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Just verify it doesn't crash and produces output
  let snapshot = tree.to_aria_snapshot()
  inspect(snapshot.length() > 0, content="true")
}

// =============================================================================
// JSON Format Tests
// =============================================================================

///|
test "json: simple button" {
  let node = AccessibilityNode::new("btn-1", Button).with_name("Click me")
  let json = node.to_aria_json()
  inspect(json, content=
    #|{
    #|  "role": "button",
    #|  "name": "Click me"
    #|}
  )
}

///|
test "json: heading with level" {
  let node = AccessibilityNode::new("h1", Heading).with_name("Title").with_level(
    1,
  )
  let json = node.to_aria_json()
  inspect(json, content=
    #|{
    #|  "role": "heading",
    #|  "name": "Title",
    #|  "level": 1
    #|}
  )
}

///|
test "json: checkbox checked" {
  let node = AccessibilityNode::new("cb-1", Checkbox).with_name("Accept").add_state(
    Checked,
  )
  let json = node.to_aria_json()
  inspect(json, content=
    #|{
    #|  "role": "checkbox",
    #|  "name": "Accept",
    #|  "states": ["checked"]
    #|}
  )
}

///|
test "json: nested list" {
  let item1 = AccessibilityNode::new("li-1", ListItem).with_name("Item 1")
  let item2 = AccessibilityNode::new("li-2", ListItem).with_name("Item 2")
  let list = AccessibilityNode::new("list-1", List).with_name("Features").add_child(
    item1,
  ).add_child(item2)
  let json = list.to_aria_json()
  inspect(json, content=
    #|{
    #|  "role": "list",
    #|  "name": "Features",
    #|  "children": [
    #|    {
    #|      "role": "listitem",
    #|      "name": "Item 1"
    #|    },
    #|    {
    #|      "role": "listitem",
    #|      "name": "Item 2"
    #|    }
    #|  ]
    #|}
  )
}
