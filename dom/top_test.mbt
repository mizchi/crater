///|
test "dom facade parses html and builds accessibility tree" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|  <body>
    #|    <main>
    #|      <button id="save">Save</button>
    #|    </main>
    #|  </body>
    #|</html>
  let document = parse_document(html)

  let tree = build_accessibility_tree(document)
  let buttons = tree.find_by_role(Role::Button)

  inspect(document.root.tag, content="html")
  inspect(buttons.length(), content="1")
  inspect(buttons[0].name, content="Some(\"Save\")")
}

///|
test "dom facade exposes dom tree and scheduler entry points" {
  let scheduler = Scheduler::new()
  let html =
    #|<html>
    #|  <head><style>body { margin: 0; }</style></head>
    #|  <body><img src="/hero.png" /></body>
    #|</html>
  let parse_result = parse_and_schedule(scheduler, html)

  let tree = DomTree::new()
  let document = tree.get_document()
  let button = tree.create_element("button")
  tree.append_child(document, button).unwrap()
  tree.set_attribute(button, "id", "save").unwrap()

  inspect(scheduler.is_idle(), content="false")
  inspect(parse_result.root.tag, content="html")
  inspect(parse_result.resource_count, content="1")
  inspect(parse_result.inline_style_count, content="1")
  inspect(tree.get_tag_name(button).unwrap(), content="button")
}
