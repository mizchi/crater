///|
/// Tests for focus navigation and tab order

///|
test "focus: basic tab order with buttons" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2">Second</button>
    #|  <button id="btn3">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="3")

  // Should be in document order (all have implicit tabindex=0)
  inspect(order[0], content="btn1")
  inspect(order[1], content="btn2")
  inspect(order[2], content="btn3")
}

///|
test "focus: tabindex positive values come first" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2" tabindex="2">Second</button>
    #|  <button id="btn3" tabindex="1">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="3")

  // tabindex=1 first, then tabindex=2, then implicit 0
  inspect(order[0], content="btn3")
  inspect(order[1], content="btn2")
  inspect(order[2], content="btn1")
}

///|
test "focus: tabindex negative values excluded" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2" tabindex="-1">Hidden from tab</button>
    #|  <button id="btn3">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  // btn2 should be excluded from tab order
  inspect(order.length(), content="2")
  inspect(order[0], content="btn1")
  inspect(order[1], content="btn3")
}

///|
test "focus: mixed focusable elements" {
  let html =
    #|<div>
    #|  <a id="link1" href="#">Link</a>
    #|  <input id="input1" type="text">
    #|  <button id="btn1">Button</button>
    #|  <select id="select1"><option>Option</option></select>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="4")

  // All should be in document order
  inspect(order[0], content="link1")
  inspect(order[1], content="input1")
  inspect(order[2], content="btn1")
  inspect(order[3], content="select1")
}

///|
test "focus: FocusManager focus_next cycles through elements" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2">Second</button>
    #|  <button id="btn3">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let manager = FocusManager::new(tree)

  // Initially no focus
  inspect(manager.has_focus(), content="false")
  inspect(manager.current_id(), content="None")

  // First Tab -> btn1
  let node1 = manager.focus_next()
  inspect(node1 is Some(_), content="true")
  inspect(manager.current_id(), content="Some(\"btn1\")")

  // Second Tab -> btn2
  let _ = manager.focus_next()
  inspect(manager.current_id(), content="Some(\"btn2\")")

  // Third Tab -> btn3
  let _ = manager.focus_next()
  inspect(manager.current_id(), content="Some(\"btn3\")")

  // Fourth Tab -> wraps to btn1
  let _ = manager.focus_next()
  inspect(manager.current_id(), content="Some(\"btn1\")")
}

///|
test "focus: FocusManager focus_prev cycles backwards" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2">Second</button>
    #|  <button id="btn3">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let manager = FocusManager::new(tree)

  // Start from the end
  let _ = manager.focus_last()
  inspect(manager.current_id(), content="Some(\"btn3\")")

  // Shift+Tab -> btn2
  let _ = manager.focus_prev()
  inspect(manager.current_id(), content="Some(\"btn2\")")

  // Shift+Tab -> btn1
  let _ = manager.focus_prev()
  inspect(manager.current_id(), content="Some(\"btn1\")")

  // Shift+Tab -> wraps to btn3
  let _ = manager.focus_prev()
  inspect(manager.current_id(), content="Some(\"btn3\")")
}

///|
test "focus: FocusManager focus_by_id" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2">Second</button>
    #|  <button id="btn3">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let manager = FocusManager::new(tree)

  // Focus btn2 directly
  let result = manager.focus_by_id("btn2")
  inspect(result, content="true")
  inspect(manager.current_id(), content="Some(\"btn2\")")

  // Try to focus non-existent
  let result2 = manager.focus_by_id("nonexistent")
  inspect(result2, content="false")
  // Focus should remain on btn2
  inspect(manager.current_id(), content="Some(\"btn2\")")
}

///|
test "focus: FocusManager blur clears focus" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let manager = FocusManager::new(tree)
  let _ = manager.focus_first()
  inspect(manager.has_focus(), content="true")
  manager.blur()
  inspect(manager.has_focus(), content="false")
  inspect(manager.current_id(), content="None")
}

///|
test "focus: disabled elements not focusable" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <button id="btn2" disabled>Disabled</button>
    #|  <button id="btn3">Third</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="2")
  inspect(order[0], content="btn1")
  inspect(order[1], content="btn3")
}

///|
test "focus: input type hidden not focusable" {
  let html =
    #|<div>
    #|  <input id="visible" type="text">
    #|  <input id="hidden" type="hidden">
    #|  <button id="btn">Button</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="2")
  inspect(order[0], content="visible")
  inspect(order[1], content="btn")
}

///|
test "focus: anchor without href not focusable" {
  let html =
    #|<div>
    #|  <a id="link1" href="#">With href</a>
    #|  <a id="link2">Without href</a>
    #|  <button id="btn">Button</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="2")
  inspect(order[0], content="link1")
  inspect(order[1], content="btn")
}

///|
test "focus: tabindex=0 makes non-focusable element focusable" {
  let html =
    #|<div>
    #|  <button id="btn1">First</button>
    #|  <div id="div1" tabindex="0">Focusable div</div>
    #|  <button id="btn2">Second</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)
  inspect(order.length(), content="3")
  inspect(order[0], content="btn1")
  inspect(order[1], content="div1")
  inspect(order[2], content="btn2")
}

///|
test "focus: complex tabindex ordering" {
  let html =
    #|<div>
    #|  <button id="btn1">First (0)</button>
    #|  <button id="btn2" tabindex="3">tabindex=3</button>
    #|  <button id="btn3" tabindex="1">tabindex=1</button>
    #|  <button id="btn4">Second (0)</button>
    #|  <button id="btn5" tabindex="1">tabindex=1 second</button>
    #|  <button id="btn6" tabindex="-1">Not tabbable</button>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let order = get_tab_order_ids(tree)

  // Order should be:
  // 1. tabindex=1 elements in document order: btn3, btn5
  // 2. tabindex=3 elements: btn2
  // 3. tabindex=0 (implicit) in document order: btn1, btn4
  // btn6 is excluded (tabindex=-1)
  inspect(order.length(), content="5")
  inspect(order[0], content="btn3")
  inspect(order[1], content="btn5")
  inspect(order[2], content="btn2")
  inspect(order[3], content="btn1")
  inspect(order[4], content="btn4")
}

///|
test "focus: empty tree has no focusable elements" {
  let html =
    #|<div>
    #|  <p>No focusable elements here</p>
    #|</div>
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  let manager = FocusManager::new(tree)
  inspect(manager.focusable_count(), content="0")
  inspect(manager.focus_next() is None, content="true")
  inspect(manager.focus_prev() is None, content="true")
}
