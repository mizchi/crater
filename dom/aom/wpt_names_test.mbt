///|
/// WPT html-aam Accessible Name Tests (auto-generated)
/// Source: wpt-tests/html-aam/names.html
/// Run: npx tsx tools/gen-wpt-aom-tests.ts html-aam-names

///|
test "html-aam/names: address no name" {
  let html = "<address >x</address>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: address aria-label" {
  let html = "<address aria-label=\"label\" >x</address>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: address aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <address aria-labelledby="labelledby" >x</address>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: address title" {
  let html = "<address title=\"title\" >x</address>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: address aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <address aria-labelledby="labelledby" aria-label="label" title="title" >x</address>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: address aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <address aria-labelledby="labelledby" aria-label="label" >x</address>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: address aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <address aria-labelledby="labelledby" title="title" >x</address>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: address aria-label vs title" {
  let html = "<address aria-label=\"label\" title=\"title\" >x</address>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: aside no name" {
  let html = "<aside >x</aside>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: aside aria-label" {
  let html = "<aside aria-label=\"label\" >x</aside>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: aside aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <aside aria-labelledby="labelledby" >x</aside>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Complementary)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: aside title" {
  let html = "<aside title=\"title\" >x</aside>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: aside aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <aside aria-labelledby="labelledby" aria-label="label" title="title" >x</aside>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Complementary)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: aside aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <aside aria-labelledby="labelledby" aria-label="label" >x</aside>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Complementary)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: aside aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <aside aria-labelledby="labelledby" title="title" >x</aside>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Complementary)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: aside aria-label vs title" {
  let html = "<aside aria-label=\"label\" title=\"title\" >x</aside>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: blockquote no name" {
  let html = "<blockquote >x</blockquote>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: blockquote aria-label" {
  let html = "<blockquote aria-label=\"label\" >x</blockquote>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: blockquote aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <blockquote aria-labelledby="labelledby" >x</blockquote>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Blockquote)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: blockquote title" {
  let html = "<blockquote title=\"title\" >x</blockquote>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: blockquote aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <blockquote aria-labelledby="labelledby" aria-label="label" title="title" >x</blockquote>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Blockquote)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: blockquote aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <blockquote aria-labelledby="labelledby" aria-label="label" >x</blockquote>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Blockquote)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: blockquote aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <blockquote aria-labelledby="labelledby" title="title" >x</blockquote>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Blockquote)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: blockquote aria-label vs title" {
  let html = "<blockquote aria-label=\"label\" title=\"title\" >x</blockquote>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: details no name" {
  let html = "<details ><summary>x</summary></details>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: details aria-label" {
  let html = "<details aria-label=\"label\" ><summary>x</summary></details>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: details aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <details aria-labelledby="labelledby" ><summary>x</summary></details>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: details title" {
  let html = "<details title=\"title\" ><summary>x</summary></details>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: details aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <details aria-labelledby="labelledby" aria-label="label" title="title" ><summary>x</summary></details>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: details aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <details aria-labelledby="labelledby" aria-label="label" ><summary>x</summary></details>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: details aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <details aria-labelledby="labelledby" title="title" ><summary>x</summary></details>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: details aria-label vs title" {
  let html = "<details aria-label=\"label\" title=\"title\" ><summary>x</summary></details>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: figure no name" {
  let html = "<figure >x</figure>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: figure aria-label" {
  let html = "<figure aria-label=\"label\" >x</figure>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: figure aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <figure aria-labelledby="labelledby" >x</figure>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Figure)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: figure title" {
  let html = "<figure title=\"title\" >x</figure>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: figure aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <figure aria-labelledby="labelledby" aria-label="label" title="title" >x</figure>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Figure)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: figure aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <figure aria-labelledby="labelledby" aria-label="label" >x</figure>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Figure)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: figure aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <figure aria-labelledby="labelledby" title="title" >x</figure>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Figure)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: figure aria-label vs title" {
  let html = "<figure aria-label=\"label\" title=\"title\" >x</figure>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: footer no name" {
  let html = "<footer >x</footer>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: footer aria-label" {
  let html = "<footer aria-label=\"label\" >x</footer>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: footer aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <footer aria-labelledby="labelledby" >x</footer>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(ContentInfo)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: footer title" {
  let html = "<footer title=\"title\" >x</footer>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: footer aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <footer aria-labelledby="labelledby" aria-label="label" title="title" >x</footer>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(ContentInfo)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: footer aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <footer aria-labelledby="labelledby" aria-label="label" >x</footer>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(ContentInfo)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: footer aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <footer aria-labelledby="labelledby" title="title" >x</footer>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(ContentInfo)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: footer aria-label vs title" {
  let html = "<footer aria-label=\"label\" title=\"title\" >x</footer>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: form no name" {
  let html = "<form >x</form>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: form aria-label" {
  let html = "<form aria-label=\"label\" >x</form>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: form aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <form aria-labelledby="labelledby" >x</form>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Form)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: form title" {
  let html = "<form title=\"title\" >x</form>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: form aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <form aria-labelledby="labelledby" aria-label="label" title="title" >x</form>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Form)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: form aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <form aria-labelledby="labelledby" aria-label="label" >x</form>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Form)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: form aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <form aria-labelledby="labelledby" title="title" >x</form>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Form)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: form aria-label vs title" {
  let html = "<form aria-label=\"label\" title=\"title\" >x</form>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: hgroup no name" {
  let html = "<hgroup ><h3>x</h3><p>y</p></hgroup>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: hgroup aria-label" {
  let html = "<hgroup aria-label=\"label\" ><h3>x</h3><p>y</p></hgroup>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: hgroup aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hgroup aria-labelledby="labelledby" ><h3>x</h3><p>y</p></hgroup>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hgroup title" {
  let html = "<hgroup title=\"title\" ><h3>x</h3><p>y</p></hgroup>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: hgroup aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hgroup aria-labelledby="labelledby" aria-label="label" title="title" ><h3>x</h3><p>y</p></hgroup>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hgroup aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hgroup aria-labelledby="labelledby" aria-label="label" ><h3>x</h3><p>y</p></hgroup>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hgroup aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hgroup aria-labelledby="labelledby" title="title" ><h3>x</h3><p>y</p></hgroup>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hgroup aria-label vs title" {
  let html = "<hgroup aria-label=\"label\" title=\"title\" ><h3>x</h3><p>y</p></hgroup>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: hr no name" {
  let html = "<hr >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: hr aria-label" {
  let html = "<hr aria-label=\"label\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: hr aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hr aria-labelledby="labelledby" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Separator)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hr title" {
  let html = "<hr title=\"title\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: hr aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hr aria-labelledby="labelledby" aria-label="label" title="title" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Separator)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hr aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hr aria-labelledby="labelledby" aria-label="label" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Separator)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hr aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <hr aria-labelledby="labelledby" title="title" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Separator)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: hr aria-label vs title" {
  let html = "<hr aria-label=\"label\" title=\"title\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: ol no name" {
  let html = "<ol ><li>x</li></ol>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: ol aria-label" {
  let html = "<ol aria-label=\"label\" ><li>x</li></ol>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: ol aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ol aria-labelledby="labelledby" ><li>x</li></ol>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ol title" {
  let html = "<ol title=\"title\" ><li>x</li></ol>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: ol aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ol aria-labelledby="labelledby" aria-label="label" title="title" ><li>x</li></ol>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ol aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ol aria-labelledby="labelledby" aria-label="label" ><li>x</li></ol>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ol aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ol aria-labelledby="labelledby" title="title" ><li>x</li></ol>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ol aria-label vs title" {
  let html = "<ol aria-label=\"label\" title=\"title\" ><li>x</li></ol>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: main no name" {
  let html = "<main >x</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: main aria-label" {
  let html = "<main aria-label=\"label\" >x</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: main aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <main aria-labelledby="labelledby" >x</main>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Main)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: main title" {
  let html = "<main title=\"title\" >x</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: main aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <main aria-labelledby="labelledby" aria-label="label" title="title" >x</main>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Main)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: main aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <main aria-labelledby="labelledby" aria-label="label" >x</main>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Main)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: main aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <main aria-labelledby="labelledby" title="title" >x</main>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Main)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: main aria-label vs title" {
  let html = "<main aria-label=\"label\" title=\"title\" >x</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: menu no name" {
  let html = "<menu ><li>x</li></menu>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: menu aria-label" {
  let html = "<menu aria-label=\"label\" ><li>x</li></menu>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: menu aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <menu aria-labelledby="labelledby" ><li>x</li></menu>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: menu title" {
  let html = "<menu title=\"title\" ><li>x</li></menu>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: menu aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <menu aria-labelledby="labelledby" aria-label="label" title="title" ><li>x</li></menu>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: menu aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <menu aria-labelledby="labelledby" aria-label="label" ><li>x</li></menu>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: menu aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <menu aria-labelledby="labelledby" title="title" ><li>x</li></menu>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: menu aria-label vs title" {
  let html = "<menu aria-label=\"label\" title=\"title\" ><li>x</li></menu>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: nav no name" {
  let html = "<nav >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: nav aria-label" {
  let html = "<nav aria-label=\"label\" >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: nav aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <nav aria-labelledby="labelledby" >x</nav>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Navigation)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: nav title" {
  let html = "<nav title=\"title\" >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: nav aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <nav aria-labelledby="labelledby" aria-label="label" title="title" >x</nav>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Navigation)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: nav aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <nav aria-labelledby="labelledby" aria-label="label" >x</nav>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Navigation)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: nav aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <nav aria-labelledby="labelledby" title="title" >x</nav>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Navigation)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: nav aria-label vs title" {
  let html = "<nav aria-label=\"label\" title=\"title\" >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: search no name" {
  let html = "<search >x</search>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: search aria-label" {
  let html = "<search aria-label=\"label\" >x</search>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: search aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <search aria-labelledby="labelledby" >x</search>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Search)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: search title" {
  let html = "<search title=\"title\" >x</search>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: search aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <search aria-labelledby="labelledby" aria-label="label" title="title" >x</search>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Search)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: search aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <search aria-labelledby="labelledby" aria-label="label" >x</search>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Search)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: search aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <search aria-labelledby="labelledby" title="title" >x</search>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Search)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: search aria-label vs title" {
  let html = "<search aria-label=\"label\" title=\"title\" >x</search>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: section no name" {
  let html = "<section >x</section>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: section aria-label" {
  let html = "<section aria-label=\"label\" >x</section>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: section aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <section aria-labelledby="labelledby" >x</section>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Region)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: section title" {
  let html = "<section title=\"title\" >x</section>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: section aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <section aria-labelledby="labelledby" aria-label="label" title="title" >x</section>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Region)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: section aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <section aria-labelledby="labelledby" aria-label="label" >x</section>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Region)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: section aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <section aria-labelledby="labelledby" title="title" >x</section>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Region)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: section aria-label vs title" {
  let html = "<section aria-label=\"label\" title=\"title\" >x</section>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: ul no name" {
  let html = "<ul ><li>x</li></ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "html-aam/names: ul aria-label" {
  let html = "<ul aria-label=\"label\" ><li>x</li></ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "html-aam/names: ul aria-labelledby" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ul aria-labelledby="labelledby" ><li>x</li></ul>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ul title" {
  let html = "<ul title=\"title\" ><li>x</li></ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "html-aam/names: ul aria-labelledby vs aria-label vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ul aria-labelledby="labelledby" aria-label="label" title="title" ><li>x</li></ul>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ul aria-labelledby vs aria-label" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ul aria-labelledby="labelledby" aria-label="label" ><li>x</li></ul>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ul aria-labelledby vs title" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  <ul aria-labelledby="labelledby" title="title" ><li>x</li></ul>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(List)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(
    name,
    content=(
      #|Some("labelledby")
    ),
  )
}

///|
test "html-aam/names: ul aria-label vs title" {
  let html = "<ul aria-label=\"label\" title=\"title\" ><li>x</li></ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}
