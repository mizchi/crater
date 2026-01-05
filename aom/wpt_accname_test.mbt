///|
/// WPT accname Tests (auto-generated)
/// Source: wpt-tests/accname/
/// Run: npx tsx tools/gen-wpt-aom-tests.ts accname

///|
test "accname: A button using aria-owns to specify its label" {
  let html =
    #|<div>
    #|  <div hidden><span id="play">Play</span></div>
    #|  <button aria-owns="play" > <div aria-hidden="true"> <span id="play">Play</span> <span id="pause">Pause</span> </div> </button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Play\")")
}

///|
test "accname: A link using aria-owns to concatenate extra text" {
  let html =
    #|<div>
    #|  <div hidden><span id="new-window-warning-1"> (opens in a new window)</span></div>
    #|  <a href="https://www.w3.org/" target="_blank" aria-owns="new-window-warning-1" > World Wide Web Consortium </a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"World Wide Web Consortium (opens in a new window)\")")
}

///|
test "accname: Ignore aria-owns when on an element that is hidden from all users" {
  let html =
    #|<div>
    #|  <mark id="treasure">treasure</mark>
    #|  <h3 > <span hidden aria-owns="treasure"> This ninja can’t steal the... </span> <mark id="treasure">treasure</mark> </h3>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"treasure\")")
}

///|
test "accname: Computed name of parent heading persists when aria-owns fails to relocate its contents" {
  let html = "<h4 > <!-- TODO: This subtest only succeeds in confirming that the h4’s computed name remains \"a pearl\". It does *not* confirm that #pearl remains unmoved in the accessibility tree after aria-owns is processed on the h3. This subtle distinction is importance since we’ve discovered at least one case where the h4 is simultaneously correctly named but emptied of its contents: https://github.com/web-platform-tests/wpt/pull/44822#issuecomment-3251614062 A better test would assert that the #pearl text node remains unmoved. --> <mark id=\"pearl\">a pearl</mark> </h4>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"a pearl\")")
}

///|
test "accname: Computed name of parent heading excludes content relocated by aria-owns" {
  let html = "<h4 > Speeding <mark id=\"car\">car</mark> </h4>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Speeding\")")
}

///|
test "accname: Ignore aria-owns when on an element with aria-hidden" {
  let html =
    #|<div>
    #|  <mark id="reflection">reflection</mark>
    #|  <h3 > <span aria-hidden="true" aria-owns="reflection"> This vampire can’t see its... </span> <mark id="reflection">reflection</mark> </h3>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"reflection\")")
}

///|
test "accname: Ignore aria-owns when it targets an element that is hidden from all users" {
  let html =
    #|<div>
    #|  <span id="new-window-warning-2" hidden> (opens in a new window)</span>
    #|  <a href="https://www.w3.org/" aria-owns="new-window-warning-2" > World Wide Web Consortium </a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"World Wide Web Consortium\")")
}

///|
test "accname: Ignore aria-owns when it targets an element with an ancestor that is hidden from all users" {
  let html =
    #|<div>
    #|  <div hidden><span id="new-window-warning-3"> (opens in a new window)</span></div>
    #|  <a href="https://www.w3.org/" aria-owns="new-window-warning-3" > World Wide Web Consortium </a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"World Wide Web Consortium\")")
}

///|
test "accname: aria-hidden remains in effect on an element after it is relocated using aria-owns" {
  let html =
    #|<div>
    #|  <span id="new-window-warning-4" aria-hidden="true"> (opens in a new window)</span>
    #|  <a href="https://www.w3.org/" aria-owns="new-window-warning-4" > World Wide Web Consortium </a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"World Wide Web Consortium\")")
}

///|
test "accname: checkbox label with embedded textfield" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <input value=\"3\" aria-label=\"number of times\" > times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded textfield inside checkbox label" {
  let html = "<input value=\"3\" aria-label=\"number of times\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded select:not([size])" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <select aria-label=\"number of times\" > <option value=\"1\">1</option> <option value=\"2\">2</option> <option value=\"3\" selected>3</option> <option value=\"4\">4</option> <option value=\"5\">5</option> </select> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded select:not([size]) inside checkbox label" {
  let html = "<select aria-label=\"number of times\" > <option value=\"1\">1</option> <option value=\"2\">2</option> <option value=\"3\" selected>3</option> <option value=\"4\">4</option> <option value=\"5\">5</option> </select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded select[size]" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <select size=5 aria-label=\"number of times\" > <option value=\"1\">1</option> <option value=\"2\">2</option> <option value=\"3\" selected>3</option> <option value=\"4\">4</option> <option value=\"5\">5</option> </select> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded select[size] inside checkbox label" {
  let html = "<select size=5 aria-label=\"number of times\" > <option value=\"1\">1</option> <option value=\"2\">2</option> <option value=\"3\" selected>3</option> <option value=\"4\">4</option> <option value=\"5\">5</option> </select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded combobox (input[type=text])" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <input role=\"combobox\" value=\"3\" aria-label=\"number of times\" > times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded combobox (input[type=text]) inside checkbox label" {
  let html = "<input role=\"combobox\" value=\"3\" aria-label=\"number of times\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded combobox (span)" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <span role=\"combobox\" tabindex=\"0\" aria-label=\"number of times\" >3</span> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded combobox (span) inside checkbox label" {
  let html = "<span role=\"combobox\" tabindex=\"0\" aria-label=\"number of times\" >3</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded combobox (div)" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <div style=\"display: inline-block;\" role=\"combobox\" tabindex=\"0\" aria-label=\"number of times\" >3</div> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded combobox (div) inside checkbox label" {
  let html = "<div style=\"display: inline-block;\" role=\"combobox\" tabindex=\"0\" aria-label=\"number of times\" >3</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded input[type=range]" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <input type =\"range\" min=\"1\" max=\"5\" value=\"3\" step=\"1\" aria-label=\"number of times\" > times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded input[type=range] inside checkbox label" {
  let html = "<input type =\"range\" min=\"1\" max=\"5\" value=\"3\" step=\"1\" aria-label=\"number of times\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded input[type=number]" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <input type =\"number\" min=\"1\" max=\"5\" value=\"3\" step=\"1\" aria-label=\"number of times\" > times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded input[type=number] inside checkbox label" {
  let html = "<input type =\"number\" min=\"1\" max=\"5\" value=\"3\" step=\"1\" aria-label=\"number of times\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded ARIA slider (aria-valuenow)" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <span tabindex=\"0\" role=\"slider\" aria-valuemin=\"1\" aria-valuemax=\"5\" aria-valuenow=\"3\" aria-label=\"number of times\" >3.0</span> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded ARIA slider (aria-valuenow) inside checkbox label" {
  let html = "<span tabindex=\"0\" role=\"slider\" aria-valuemin=\"1\" aria-valuemax=\"5\" aria-valuenow=\"3\" aria-label=\"number of times\" >3.0</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded ARIA slider (aria-valuetext)" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <span tabindex=\"0\" role=\"slider\" aria-valuemin=\"1.0\" aria-valuemax=\"5.0\" aria-valuenow=\"3.0\" aria-valuetext=\"3\" aria-label=\"number of times\" >3.0</span> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded ARIA slider (aria-valuetext) inside checkbox label" {
  let html = "<span tabindex=\"0\" role=\"slider\" aria-valuemin=\"1.0\" aria-valuemax=\"5.0\" aria-valuenow=\"3.0\" aria-valuetext=\"3\" aria-label=\"number of times\" >3.0</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded ARIA spinbutton (aria-valuenow)" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <span tabindex=\"0\" role=\"spinbutton\" aria-valuemin=\"1\" aria-valuemax=\"5\" aria-valuenow=\"3\" aria-label=\"number of times\" >3.0</span> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded ARIA spinbutton (aria-valuenow) inside checkbox label" {
  let html = "<span tabindex=\"0\" role=\"spinbutton\" aria-valuemin=\"1\" aria-valuemax=\"5\" aria-valuenow=\"3\" aria-label=\"number of times\" >3.0</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: checkbox label with embedded ARIA spinbutton (aria-valuetext)" {
  let html = "<label> <input type=\"checkbox\" > Flash the screen <span tabindex=\"0\" role=\"spinbutton\" aria-valuemin=\"1.0\" aria-valuemax=\"5.0\" aria-valuenow=\"3.0\" aria-valuetext=\"3\" aria-label=\"number of times\" >3.0</span> times </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"Flash the screen 3 times\")")
}

///|
test "accname: label of embedded ARIA spinbutton (aria-valuetext) inside checkbox label" {
  let html = "<span tabindex=\"0\" role=\"spinbutton\" aria-valuemin=\"1.0\" aria-valuemax=\"5.0\" aria-valuenow=\"3.0\" aria-valuetext=\"3\" aria-label=\"number of times\" >3.0</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"number of times\")")
}

///|
test "accname: button containing a rendered, unreferenced element that is aria-hidden=true, an unreferenced element with the hidden host language attribute, and an unreferenced element that is unconditionally rendered" {
  let html = "<button > <span aria-hidden=\"true\">hidden,</span> <span hidden>hidden from all users,</span> <span>visible to all users</span> </button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"visible to all users\")")
}

///|
test "accname: button labelled by element that is aria-hidden=true" {
  let html =
    #|<div>
    #|  <span aria-hidden="true" id="button-label-2">hidden but referenced,</span>
    #|  <button aria-labelledby="button-label-2" > <span aria-hidden="true" id="button-label-2">hidden but referenced,</span> <span hidden>hidden from all users,</span> <span>visible to all users</span> </button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"hidden but referenced,\")")
}

///|
test "accname: button labelled by element with the hidden host language attribute" {
  let html =
    #|<div>
    #|  <span hidden id="button-label-3">hidden from all users but referenced,</span>
    #|  <button aria-labelledby="button-label-3" > <span aria-hidden="true">hidden,</span> <span hidden id="button-label-3">hidden from all users but referenced,</span> <span>visible to all users</span> </button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"hidden from all users but referenced,\")")
}

///|
test "accname: link labelled by elements with assorted visibility and a11y tree exposure" {
  let html =
    #|<div>
    #|  <span aria-hidden="true" id="link-label-1b">hidden but referenced,</span>
    #|  <span hidden id="link-label-1c">hidden from all users but referenced</span>
    #|  <a href="#" aria-labelledby="link-label-1a link-label-1b link-label-1c" > <span id="link-label-1a"> <span>visible to all users,</span> <span aria-hidden="true">hidden,</span> </span> <span aria-hidden="true" id="link-label-1b">hidden but referenced,</span> <span hidden id="link-label-1c">hidden from all users but referenced</span> </a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"visible to all users, hidden but referenced, hidden from all users but referenced\")")
}

///|
test "accname: heading with name from content, containing element that is visibility:hidden with nested content that is visibility:visible" {
  let html = "<h2 > visible to all users, <span style=\"visibility: hidden;\"> hidden from all users, <span style=\"visibility: visible;\">un-hidden for all users</span> </span> </h2>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"visible to all users, un-hidden for all users\")")
}

///|
test "accname: html: input[type=button]" {
  let html = "<input type=\"button\" value=\"button label\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: html: input[type=image]" {
  let html = "<input type=\"image\" alt=\"image input label\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"image input label\")")
}

///|
test "accname: html: input[type=reset]" {
  let html = "<input type=\"reset\" value=\"reset label\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"reset label\")")
}

///|
test "accname: html: input[type=submit]" {
  let html = "<input type=\"submit\" value=\"submit label\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"submit label\")")
}

///|
test "accname: html: label[for] input[type=checkbox]" {
  let html =
    #|<div>
    #|  <label for="cb">checkbox label</label>
    #|  <input id="cb" type="checkbox" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"checkbox label\")")
}

///|
test "accname: html: label[for] input[type=checkbox][checked]" {
  let html =
    #|<div>
    #|  <label for="cbc">checkbox label checked</label>
    #|  <input id="cbc" type="checkbox" checked>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"checkbox label checked\")")
}

///|
test "accname: html: label[for] input[type=color]" {
  let html =
    #|<div>
    #|  <label for="co">color label</label>
    #|  <input id="co" type="color" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("co") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"color label\")")
}

///|
test "accname: html: label[for] input[type=date]" {
  let html =
    #|<div>
    #|  <label for="da">date label</label>
    #|  <input id="da" type="date" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("da") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"date label\")")
}

///|
test "accname: html: label[for] input[type=datetime-local]" {
  let html =
    #|<div>
    #|  <label for="dtl">datetime-local label</label>
    #|  <input id="dtl" type="date" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("dtl") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"datetime-local label\")")
}

///|
test "accname: html: label[for] input[type=email]" {
  let html =
    #|<div>
    #|  <label for="em">email label</label>
    #|  <input id="em" type="email" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"email label\")")
}

///|
test "accname: html: label[for] input[type=file]" {
  let html =
    #|<div>
    #|  <label for="fi">file label</label>
    #|  <input id="fi" type="file" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("fi") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"file label\")")
}

///|
test "accname: html: label[for] input[type=month]" {
  let html =
    #|<div>
    #|  <label for="mo">month label</label>
    #|  <input id="mo" type="month" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("mo") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"month label\")")
}

///|
test "accname: html: label[for] input[type=number]" {
  let html =
    #|<div>
    #|  <label for="n">number label</label>
    #|  <input id="n" type="number" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(SpinButton)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"number label\")")
}

///|
test "accname: html: label[for] input[type=number][value=2025]" {
  let html =
    #|<div>
    #|  <label for="nv">number label with non-empty value</label>
    #|  <input id="nv" type="number" value="2025">
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(SpinButton)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"number label with non-empty value\")")
}

///|
test "accname: html: label[for] input[type=password]" {
  let html =
    #|<div>
    #|  <label for="pw">password label</label>
    #|  <input id="pw" type="password" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"password label\")")
}

///|
test "accname: html: label[for] input[type=radio]" {
  let html =
    #|<div>
    #|  <label for="ra">radio label</label>
    #|  <input id="ra" type="radio" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Radio)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"radio label\")")
}

///|
test "accname: html: label[for] input[type=range]" {
  let html =
    #|<div>
    #|  <label for="rng">range label</label>
    #|  <input id="rng" type="range" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Slider)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"range label\")")
}

///|
test "accname: html: label[for] input[type=range][min=0][max=10][value=5]" {
  let html =
    #|<div>
    #|  <label for="rngv">range label with non-empty value</label>
    #|  <input id="rngv" type="range" min="0" max="10" value="5">
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Slider)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"range label with non-empty value\")")
}

///|
test "accname: html: label[for] input[type=search]" {
  let html =
    #|<div>
    #|  <label for="search">search label</label>
    #|  <input id="search" type="search" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(SearchBox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"search label\")")
}

///|
test "accname: html: label[for] input[type=tel]" {
  let html =
    #|<div>
    #|  <label for="tel">tel label</label>
    #|  <input id="tel" type="tel" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"tel label\")")
}

///|
test "accname: html: label[for] input[type=text]" {
  let html =
    #|<div>
    #|  <label for="t">textfield label</label>
    #|  <input id="t" type="text" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"textfield label\")")
}

///|
test "accname: html: label[for] input[type=time]" {
  let html =
    #|<div>
    #|  <label for="time">time label</label>
    #|  <input id="time" type="time" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("time") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"time label\")")
}

///|
test "accname: html: label[for] input[type=url]" {
  let html =
    #|<div>
    #|  <label for="url">url label</label>
    #|  <input id="url" type="url" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"url label\")")
}

///|
test "accname: html: label[for] input[type=week]" {
  let html =
    #|<div>
    #|  <label for="week">week label</label>
    #|  <input id="week" type="week" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("week") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="Some(\"week label\")")
}

///|
test "accname: html: label input[type=checkbox] encapsulation" {
  let html = "<label><input type=\"checkbox\" >checkbox label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"checkbox label\")")
}

///|
test "accname: html: label input[type=checkbox][checked] encapsulation" {
  let html = "<label><input type=\"checkbox\" checked>checkbox label checked</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Checkbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"checkbox label checked\")")
}

///|
test "accname: html: label input[type=color] encapsulation" {
  let html = "<label><input type=\"color\" >color label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"color label\")")
}

///|
test "accname: html: label input[type=date] encapsulation" {
  let html = "<label><input type=\"date\" >date label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"date label\")")
}

///|
test "accname: html: label input[type=datetime-local] encapsulation" {
  let html = "<label><input type=\"datetime-local\" >datetime-local label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"datetime-local label\")")
}

///|
test "accname: html: label input[type=email] encapsulation" {
  let html = "<label><input type=\"email\" >email label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"email label\")")
}

///|
test "accname: html: label input[type=file] encapsulation" {
  let html = "<label><input type=\"file\" >file label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"file label\")")
}

///|
test "accname: html: label input[type=month] encapsulation" {
  let html = "<label><input type=\"month\" >month label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"month label\")")
}

///|
test "accname: html: label input[type=number] encapsulation" {
  let html = "<label><input type=\"number\" >number label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(SpinButton)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"number label\")")
}

///|
test "accname: html: label input[type=number][value=1] encapsulation" {
  let html = "<label><input type=\"number\" value=\"1\">number label with non-empty value</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(SpinButton)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"number label with non-empty value\")")
}

///|
test "accname: html: label input[type=password] encapsulation" {
  let html = "<label><input type=\"password\" >password label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"password label\")")
}

///|
test "accname: html: label input[type=radio] encapsulation" {
  let html = "<label><input type=\"radio\" >radio label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Radio)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"radio label\")")
}

///|
test "accname: html: label input[type=range] encapsulation" {
  let html = "<label><input type=\"range\" >range label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Slider)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"range label\")")
}

///|
test "accname: html: label input[type=search] encapsulation" {
  let html = "<label><input type=\"search\" >search label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(SearchBox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"search label\")")
}

///|
test "accname: html: label input[type=tel] encapsulation" {
  let html = "<label><input type=\"tel\" >tel label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"tel label\")")
}

///|
test "accname: html: label[for] input[type=text] encapsulation" {
  let html = "<label><input type=\"text\" >textfield label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"textfield label\")")
}

///|
test "accname: html: label input[type=time] encapsulation" {
  let html = "<label><input type=\"time\" >time label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"time label\")")
}

///|
test "accname: html: label input[type=url] encapsulation" {
  let html = "<label><input type=\"url\" >url label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"url label\")")
}

///|
test "accname: html: label input[type=week] encapsulation" {
  let html = "<label><input type=\"week\" >week label</label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="Some(\"week label\")")
}

///|
test "accname: html: label[for] textarea" {
  let html = "<textarea ></textarea>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"textarea label\")")
}

///|
test "accname: html: textarea encapsulation" {
  let html = "<label for=\"ta\">textarea label<textarea ></textarea></label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"textarea label\")")
}

///|
test "accname: html: select for/id" {
  let html =
    #|<div>
    #|  <label for="select">select label</label>
    #|  <select id="select" > <option>foo</option> </select>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Combobox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"select label\")")
}

///|
test "accname: html: select encapsulation" {
  let html = "<label> select label <select > <option>foo</option> </select> </label>"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Combobox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"select label\")")
}

///|
test "accname: html: select w/selected option" {
  let html = "<select > <option>foo</option> <option selected>select label</option> <option>bar</option> </select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"select label\")")
}

///|
test "accname: html: img[alt] (non-empty)" {
  let html = "<img alt=\"image label\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"image label\")")
}

///|
test "accname: img[alt] with single space character as name" {
  let html = "<img alt=\" \" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: img[alt] with single tab as name" {
  let html = "<img alt=\" \" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: img[alt] with new line as name" {
  let html = "<img alt=\" \" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: img[alt] with single space character and tab as name" {
  let html = "<img alt=\" \" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: img[alt] with form feed as name" {
  let html = "<img alt=\" \" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: img[alt] with interior single tab in the name" {
  let html = "<img alt=\"foo bar\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"foo bar\")")
}

///|
test "accname: img[alt] with interior new line in the name" {
  let html = "<img alt=\"foo bar\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"foo bar\")")
}

///|
test "accname: img[alt] with interior single space and tab in the name" {
  let html = "<img alt=\"foo bar\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"foo bar\")")
}

///|
test "accname: img[alt] with interior form feed in the name" {
  let html = "<img alt=\"foo bar\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"foo bar\")")
}

///|
test "accname: html: multiple label elements[for]" {
  let html =
    #|<div>
    #|  <label for="multi-label">textfield label 1</label>
    #|  <input id="multi-label" type="text" >
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"textfield label 1 textfield label 2\")")
}

///|
test "accname: label valid on div with alert role" {
  let html = "<div role=\"alert\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with alertdialog role" {
  let html = "<div role=\"alertdialog\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with application role" {
  let html = "<div role=\"application\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with article role" {
  let html = "<div role=\"article\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with banner role" {
  let html = "<div role=\"banner\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with blockquote role" {
  let html = "<div role=\"blockquote\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with button role" {
  let html = "<div role=\"button\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with cell role" {
  let html = "<div role=\"cell\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with checkbox role" {
  let html = "<div role=\"checkbox\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with columnheader role" {
  let html = "<div role=\"columnheader\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with combobox role" {
  let html = "<div role=\"combobox\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with complementary role" {
  let html = "<div role=\"complementary\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with contentinfo role" {
  let html = "<div role=\"contentinfo\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with dialog role" {
  let html = "<div role=\"dialog\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with directory role" {
  let html = "<div role=\"directory\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with document role" {
  let html = "<div role=\"document\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with feed role" {
  let html = "<div role=\"feed\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with figure role" {
  let html = "<div role=\"figure\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with form role" {
  let html = "<div role=\"form\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with grid role" {
  let html = "<div role=\"grid\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with gridcell role" {
  let html = "<div role=\"gridcell\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with group role" {
  let html = "<div role=\"group\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with heading role" {
  let html = "<div role=\"heading\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with img role" {
  let html = "<div role=\"img\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with link role" {
  let html = "<div role=\"link\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with list role" {
  let html = "<div role=\"list\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with listbox role" {
  let html = "<div role=\"listbox\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with listitem role" {
  let html = "<div role=\"listitem\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with log role" {
  let html = "<div role=\"log\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with main role" {
  let html = "<div role=\"main\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with marquee role" {
  let html = "<div role=\"marquee\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with math role" {
  let html = "<div role=\"math\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with menu role" {
  let html = "<div role=\"menu\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with menubar role" {
  let html = "<div role=\"menubar\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with menuitem role" {
  let html = "<div role=\"menuitem\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with menuitemcheckbox role" {
  let html = "<div role=\"menuitemcheckbox\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with menuitemradio role" {
  let html = "<div role=\"menuitemradio\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with meter role" {
  let html = "<div role=\"meter\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with navigation role" {
  let html = "<div role=\"navigation\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with note role" {
  let html = "<div role=\"note\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with option role" {
  let html = "<div role=\"option\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with progressbar role" {
  let html = "<div role=\"progressbar\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with radio role" {
  let html = "<div role=\"radio\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with radiogroup role" {
  let html = "<div role=\"radiogroup\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with region role" {
  let html = "<div role=\"region\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with row role" {
  let html = "<div role=\"row\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with rowgroup role" {
  let html = "<div role=\"rowgroup\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with rowheader role" {
  let html = "<div role=\"rowheader\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with scrollbar role" {
  let html = "<div role=\"scrollbar\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with search role" {
  let html = "<div role=\"search\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with searchbox role" {
  let html = "<div role=\"searchbox\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with separator role" {
  let html = "<div role=\"separator\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with slider role" {
  let html = "<div role=\"slider\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with spinbutton role" {
  let html = "<div role=\"spinbutton\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with status role" {
  let html = "<div role=\"status\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with switch role" {
  let html = "<div role=\"switch\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with tab role" {
  let html = "<div role=\"tab\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with table role" {
  let html = "<div role=\"table\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with tablist role" {
  let html = "<div role=\"tablist\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with tabpanel role" {
  let html = "<div role=\"tabpanel\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with textbox role" {
  let html = "<div role=\"textbox\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with timer role" {
  let html = "<div role=\"timer\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with toolbar role" {
  let html = "<div role=\"toolbar\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with tooltip role" {
  let html = "<div role=\"tooltip\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with tree role" {
  let html = "<div role=\"tree\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with treegrid role" {
  let html = "<div role=\"treegrid\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on div with treeitem role" {
  let html = "<div role=\"treeitem\" aria-label=\"label\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on link element" {
  let html = "<a href=\"\" aria-label=\"label\" >x</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on article element" {
  let html = "<article aria-label=\"label\" >x</article>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on aside element" {
  let html = "<aside aria-label=\"label\" >x</aside>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on blockquote element" {
  let html = "<blockquote aria-label=\"label\" >x</blockquote>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on button element" {
  let html = "<button aria-label=\"label\" >x</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on dl element" {
  let html = "<dl aria-label=\"label\" > <!-- dt/dd pending listitemkey and listitemvalue roles: https://github.com/w3c/aria/issues/1662 --> <!-- Currently these map to `term` and `definition` for which name is prohibited. --> <!-- Using aria-label here would be an authoring error, however whether there is a user agent requirement to ignore the author provided role is still pending https://github.com/w3c/accname/issues/240 --> <!-- See \"Priorities of Constituencies\" https://www.w3.org/TR/design-principles/#priority-of-constituencies --> <dt>x</dt> <dd>x</dd> </dl>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on footer element" {
  let html = "<footer aria-label=\"label\" >x</footer>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on fieldset element" {
  let html = "<fieldset aria-label=\"label\" >x</fieldset>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on figure element" {
  let html = "<figure aria-label=\"label\" >x</figure>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on form element" {
  let html = "<form action=\"\" aria-label=\"label\" >x</form>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on header element" {
  let html = "<header aria-label=\"label\" >x</header>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on h1 element" {
  let html = "<h1 aria-label=\"label\" >x</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on h2 element" {
  let html = "<h2 aria-label=\"label\" >x</h2>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on h3 element" {
  let html = "<h3 aria-label=\"label\" >x</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on h4 element" {
  let html = "<h4 aria-label=\"label\" >x</h4>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on h5 element" {
  let html = "<h5 aria-label=\"label\" >x</h5>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on h6 element" {
  let html = "<h6 aria-label=\"label\" >x</h6>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on hr element" {
  let html = "<hr aria-label=\"label\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on img element" {
  let html = "<img alt=\"\" aria-label=\"label\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on input type checkbox element" {
  let html = "<input type=\"checkbox\" aria-label=\"label\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on input type radio element" {
  let html = "<input type=\"radio\" aria-label=\"label\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on input type search element" {
  let html = "<input type=\"search\" aria-label=\"label\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on input type text element" {
  let html = "<input type=\"text\" aria-label=\"label\" />"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on listitem element" {
  let html = "<li aria-label=\"label\" >x</li>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on main element" {
  let html = "<main aria-label=\"label\" >x</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on math element" {
  let html = "<math aria-label=\"label\" >x</math>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on meter element" {
  let html = "<meter aria-label=\"label\" >x</meter>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on nav element" {
  let html = "<nav aria-label=\"label\" >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on list (ordered) element" {
  let html = "<ol aria-label=\"label\" >x</ol>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on section element" {
  let html = "<section aria-label=\"label\" >x</section>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on select element" {
  let html = "<select aria-label=\"label\" >x</select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on option element" {
  let html = "<option aria-label=\"label\" value=\"foo\" >x</option>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on table element" {
  let html = "<table aria-label=\"label\" > <thead aria-label=\"label\" > <tr> <th scope=\"col\" aria-label=\"label\" >x</th> <th scope=\"row\" aria-label=\"label\" >x</th> </tr> </thead> <tbody aria-label=\"label\" > <tr aria-label=\"label\" > <td aria-label=\"label\" >x</td> <td>x</td> </tr> </tbody> <tfoot aria-label=\"label\" > <tr> <td>x</td> <td>x</td> </tr> </tfoot> </table>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on thead element" {
  let html = "<thead aria-label=\"label\" > <tr> <th scope=\"col\" aria-label=\"label\" >x</th> <th scope=\"row\" aria-label=\"label\" >x</th> </tr> </thead>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on th element with the scope of col" {
  let html = "<th scope=\"col\" aria-label=\"label\" >x</th>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on th (scope row) element" {
  let html = "<th scope=\"row\" aria-label=\"label\" >x</th>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on tbody element" {
  let html = "<tbody aria-label=\"label\" > <tr aria-label=\"label\" > <td aria-label=\"label\" >x</td> <td>x</td> </tr> </tbody>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on tr element" {
  let html = "<tr aria-label=\"label\" > <td aria-label=\"label\" >x</td> <td>x</td> </tr>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on td element" {
  let html = "<td aria-label=\"label\" >x</td>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on tfoot element" {
  let html = "<tfoot aria-label=\"label\" > <tr> <td>x</td> <td>x</td> </tr> </tfoot>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on textarea element" {
  let html = "<textarea aria-label=\"label\" >x</textarea>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: label valid on list (unordered) element" {
  let html = "<ul aria-label=\"label\" >x</ul>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: input with label for association is superceded by aria-label" {
  let html =
    #|<div>
    #|  <label for="input1">label</label>
    #|  <input type="text" id="input1" aria-label="foo" />
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"foo\")")
}

///|
test "accname: button name from contents is superceded by aria-label" {
  let html = "<button aria-label=\"label\" >x</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: h1 text is superceded by aria-label" {
  let html = "<h1 aria-label=\"label\" >x</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: button with title is superceded by aria-label" {
  let html = "<button aria-label=\"label\" title=\"foo\" >x</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: button with blank braille pattern has name as such (not treated as whitespace per Unicode standard)" {
  let html = "<button aria-label=\"⠀\" >my button</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"⠀\")")
}

///|
test "accname: div with role alert and carriage return in aria-label is valid" {
  let html = "<div role=\"alert\" aria-label=\" alert message\" >x</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"alert message\")")
}

///|
test "accname: button with leading form feed control character in aria-label is valid" {
  let html = "<button aria-label=\" label\" >my button</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: nav with trailing nbsp char aria-label is valid (nbsp is preserved in name)" {
  let html = "<nav aria-label=\"label&nbsp;\" >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label&nbsp;\")")
}

///|
test "accname: button with leading nbsp char in aria-label is valid (and uses aria-label)" {
  let html = "<button aria-label=\"&nbsp;label\" >my button</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"&nbsp;label\")")
}

///|
test "accname: button with empty aria-label does not use aria-label as name" {
  let html = "<button aria-label=\"\" >my button</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"my button\")")
}

///|
test "accname: textarea with tab character as aria-label does not use aria-label as name" {
  let html = "<textarea aria-label=\" \" title=\"title\" >textarea contents</textarea>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: button with carriage return as aria-label does not use aria-label as name" {
  let html = "<button aria-label=\" \" >my button</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"my button\")")
}

///|
test "accname: button with space characters as aria-label does not use aria-label as name" {
  let html = "<button aria-label=\" \" >my button</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"my button\")")
}

///|
test "accname: div group with aria-labeledby" {
  let html = "<div role=\"group\" aria-labeledby=\"h\" > <h2 id=\"h\">first heading</h2> <p>text inside div group</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: div group with aria-label and aria-labeledby" {
  let html = "<div role=\"group\" aria-label=\"self label\" id=\"g2\" aria-labeledby=\"g2 h2\" > <h2 id=\"h2\">+ first heading</h2> <p>text inside div group</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"self label\")")
}

///|
test "accname: div group with aria-labeledby and aria-labelledby" {
  let html =
    #|<div>
    #|  <p id="p3">text inside div group</p>
    #|  <div role="group" aria-labeledby="h2" aria-labelledby="p3" > <h2 id="h3">+ first heading</h2> <p id="p3">text inside div group</p> </div>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"text inside div group\")")
}

///|
test "accname: div group explicitly labelledby heading" {
  let html =
    #|<div>
    #|  <h2 id="h">first heading</h2>
    #|  <div role="group" aria-labelledby="h" > <h2 id="h">first heading</h2> <p>text inside div group</p> </div>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"first heading\")")
}

///|
test "accname: div group explicitly labelledby self and heading" {
  let html =
    #|<div>
    #|  <h2 id="h2">+ first heading</h2>
    #|  <div role="group" aria-label="self label" id="g2" aria-labelledby="g2 h2" > <h2 id="h2">+ first heading</h2> <p>text inside div group</p> </div>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"self label + first heading\")")
}

///|
test "accname: nav with verified spaces appended between each of IDREFS" {
  let html =
    #|<div>
    #|  <span id="s1">verify</span>
    #|  <span id="s2">spaces</span>
    #|  <span id="s3">between</span>
    #|  <span id="s4">foreach</span>
    #|  <nav aria-labelledby="s1 s2 s3 s4" > <span id="s1">verify</span><span id="s2">spaces</span><span>FAIL IF INCLUDED</span><span id="s3">between</span><span id="s4">foreach</span> </nav>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Navigation)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"verify spaces between foreach\")")
}

///|
test "accname: link labelled by aria-labelledby supercedes aria-labeledby (non-standard spelling)" {
  let html =
    #|<div>
    #|  <span id="n1">first label</span>
    #|  <a href="#" aria-labelledby="n1" aria-labeledby="n2" >x</a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"first label\")")
}

///|
test "accname: button labelled by aria-labelledby supercedes aria-labeledby (non-standard spelling)" {
  let html =
    #|<div>
    #|  <span id="n1">first label</span>
    #|  <button aria-labelledby="n1" aria-labeledby="n2" >x</button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"first label\")")
}

///|
test "accname: div labelled by aria-labelledby supercedes aria-labeledby (non-standard spelling)" {
  let html =
    #|<div>
    #|  <span id="n1">first label</span>
    #|  <div role="group" aria-labelledby="n1" aria-labeledby="n2" >x</div>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"first label\")")
}

///|
test "accname: link labelled by [aria-labeledby][aria-labelledby]" {
  let html =
    #|<div>
    #|  <span id="n2">second label</span>
    #|  <a href="#" aria-labeledby="n1" aria-labelledby="n2" >x</a>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"second label\")")
}

///|
test "accname: button labelled by [aria-labeledby][aria-labelledby]" {
  let html =
    #|<div>
    #|  <span id="n2">second label</span>
    #|  <button aria-labeledby="n1" aria-labelledby="n2" >x</button>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"second label\")")
}

///|
test "accname: div labelled by [aria-labeledby][aria-labelledby]" {
  let html =
    #|<div>
    #|  <span id="n2">second label</span>
    #|  <div role="group" aria-labeledby="n1" aria-labelledby="n2" >x</div>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Group)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"second label\")")
}

///|
test "accname: link name from content for each child including nested image (referenced elsewhere via labeledby)" {
  let html = "<a href=\"#\" > link2 <img id=\"nested_image_label2\" alt=\"image\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> <!-- image skipped in this link (when computing heading text) because it was already referenced by the first link within this heading label recursion cycle. --> <!-- but image not skipped when computing the text of the link itself since it has not been referenced in that context --> link3 </a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link2 image link3\")")
}

///|
test "accname: aria button name from content, inline" {
  let html = "<span tabindex=\"0\" role=\"button\" >label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: aria heading name from content, inline" {
  let html = "<span tabindex=\"0\" role=\"heading\" >label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: aria link name from content, inline" {
  let html = "<span tabindex=\"0\" role=\"link\" >label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: aria button name from content, block" {
  let html = "<div tabindex=\"0\" role=\"button\" >label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: aria heading name from content, block" {
  let html = "<div tabindex=\"0\" role=\"heading\" >label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: aria link name from content, block" {
  let html = "<div tabindex=\"0\" role=\"link\" >label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: button name from content" {
  let html = "<button >label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: heading name from content" {
  let html = "<h3 >label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: link name from content" {
  let html = "<a href=\"#\" >label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"label\")")
}

///|
test "accname: button with alt counter on ::before" {
  let html =
    #|<style>
    #|    /*
    #|    
    #|          Since the AccName spec is in flux about whitespace joiners, and the implementations don't match,
    #|          normalize the whitespace (with extra leading/trailing) space.
    #|    
    #|          No point in having the same in-flux spec change cause failures the remaining unrelated tests.
    #|    
    #|          See more here:
    #|          https://github.com/w3c/accname/issues/205
    #|          https://github.com/w3c/accname/projects/1#card-42288231
    #|    
    #|        */
    #|    
    #|        .alt-counter::before { counter-set: cnt 5051;
    #|          content: "" / counter(cnt); }
    #|</style>
    #|<button class="ex alt-counter">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"5051 label\")")
}

///|
test "accname: heading with alt counter on ::before" {
  let html =
    #|<style>
    #|    /*
    #|    
    #|          Since the AccName spec is in flux about whitespace joiners, and the implementations don't match,
    #|          normalize the whitespace (with extra leading/trailing) space.
    #|    
    #|          No point in having the same in-flux spec change cause failures the remaining unrelated tests.
    #|    
    #|          See more here:
    #|          https://github.com/w3c/accname/issues/205
    #|          https://github.com/w3c/accname/projects/1#card-42288231
    #|    
    #|        */
    #|    
    #|        .alt-counter::before { counter-set: cnt 5051;
    #|          content: "" / counter(cnt); }
    #|</style>
    #|<h3 class="ex alt-counter">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"5051 label\")")
}

///|
test "accname: link with alt counter on ::before" {
  let html =
    #|<style>
    #|    /*
    #|    
    #|          Since the AccName spec is in flux about whitespace joiners, and the implementations don't match,
    #|          normalize the whitespace (with extra leading/trailing) space.
    #|    
    #|          No point in having the same in-flux spec change cause failures the remaining unrelated tests.
    #|    
    #|          See more here:
    #|          https://github.com/w3c/accname/issues/205
    #|          https://github.com/w3c/accname/projects/1#card-42288231
    #|    
    #|        */
    #|    
    #|        .alt-counter::before { counter-set: cnt 5051;
    #|          content: "" / counter(cnt); }
    #|</style>
    #|<a href="#" class="ex alt-counter">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"5051 label\")")
}

///|
test "accname: button with multiple alt counters and counter increments" {
  let html = "<button ><span>alpha</span> <span>beta</span> <span>gamma</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"11 alpha 13 beta 14 gamma\")")
}

///|
test "accname: heading with multiple alt counters and counter increments" {
  let html = "<h3 ><span>alpha</span> <span>beta</span> <span>gamma</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"11 alpha 13 beta 14 gamma\")")
}

///|
test "accname: link with multiple alt counters and counter increments" {
  let html = "<a href=\"#\" ><span>alpha</span> <span>beta</span> <span>gamma</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"11 alpha 13 beta 14 gamma\")")
}

///|
test "accname: button name from content with ::before" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<button class="ex simple-before">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"before label\")")
}

///|
test "accname: heading name from content with ::before" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<h3 class="ex simple-before">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"before label\")")
}

///|
test "accname: link name from content with ::before" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<a href="#" class="ex simple-before">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"before label\")")
}

///|
test "accname: button name from content with ::after" {
  let html =
    #|<style>
    #|    .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<button class="ex simple-after">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"label after\")")
}

///|
test "accname: heading name from content with ::after" {
  let html =
    #|<style>
    #|    .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<h3 class="ex simple-after">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"label after\")")
}

///|
test "accname: link name from content with ::after" {
  let html =
    #|<style>
    #|    .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<a href="#" class="ex simple-after">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"label after\")")
}

///|
test "accname: button name from content with ::before and ::after" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<button class="ex simple-before simple-after">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"before label after\")")
}

///|
test "accname: heading name from content with ::before and ::after" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<h3 class="ex simple-before simple-after">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"before label after\")")
}

///|
test "accname: link name from content with ::before and ::after" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<a href="#" class="ex simple-before simple-after">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"before label after\")")
}

///|
test "accname: button name from content no space joiners ::before and ::after" {
  let html =
    #|<style>
    #|    .no-space::before, .no-space::after { content: "nospace"; /* [sic] Unlike the others, NO extra leading/trailing space here. */ }
    #|</style>
    #|<button class="ex no-space">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"nospacelabelnospace\")")
}

///|
test "accname: heading name from content no space joiners ::before and ::after" {
  let html =
    #|<style>
    #|    .no-space::before, .no-space::after { content: "nospace"; /* [sic] Unlike the others, NO extra leading/trailing space here. */ }
    #|</style>
    #|<h3 class="ex no-space">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"nospacelabelnospace\")")
}

///|
test "accname: link name from content no space joiners ::before and ::after" {
  let html =
    #|<style>
    #|    .no-space::before, .no-space::after { content: "nospace"; /* [sic] Unlike the others, NO extra leading/trailing space here. */ }
    #|</style>
    #|<a href="#" class="ex no-space">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"nospacelabelnospace\")")
}

///|
test "accname: button name from content with ::before and ::after in rtl" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<button class="ex simple-before simple-after">اسم</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"من قبل اسم بعد\")")
}

///|
test "accname: heading name from content with ::before and ::after in rtl" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<h3 class="ex simple-before simple-after">اسم</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"من قبل اسم بعد\")")
}

///|
test "accname: link name from content with ::before and ::after in rtl" {
  let html =
    #|<style>
    #|    .simple-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          margin:0 0.1em; }
    #|        .simple-before::before { content: " من قبل "; /* [sic] leading and trailing space */ }
    #|        .simple-after::after { content: " بعد "; /* [sic] leading and trailing space */ }
    #|</style>
    #|<a href="#" class="ex simple-before simple-after">اسم</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"من قبل اسم بعد\")")
}

///|
test "accname: button name from fallback content with ::before and ::after" {
  let html =
    #|<style>
    #|    .fallback-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " alt-before "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " alt-after "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-before-empty::before { content: "before"  / ""; }
    #|        .fallback-before-image-empty::before { content: "before " url(/images/blue.png) / ""; }
    #|        .fallback-before-mixed::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " start " attr(data-alt-text-before) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after-mixed::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " start " attr(data-alt-text-after) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|</style>
    #|<button class="ex fallback-before fallback-after">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"alt-before label alt-after\")")
}

///|
test "accname: heading name from fallback content with ::before and ::after" {
  let html =
    #|<style>
    #|    .fallback-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " alt-before "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " alt-after "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-before-empty::before { content: "before"  / ""; }
    #|        .fallback-before-image-empty::before { content: "before " url(/images/blue.png) / ""; }
    #|        .fallback-before-mixed::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " start " attr(data-alt-text-before) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after-mixed::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " start " attr(data-alt-text-after) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|</style>
    #|<h3 class="ex fallback-before fallback-after">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"alt-before label alt-after\")")
}

///|
test "accname: link name from fallback content with ::before and ::after" {
  let html =
    #|<style>
    #|    .fallback-before::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " alt-before "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " alt-after "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-before-empty::before { content: "before"  / ""; }
    #|        .fallback-before-image-empty::before { content: "before " url(/images/blue.png) / ""; }
    #|        .fallback-before-mixed::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " start " attr(data-alt-text-before) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after-mixed::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " start " attr(data-alt-text-after) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|</style>
    #|<a href="#" class="ex fallback-before fallback-after">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"alt-before label alt-after\")")
}

///|
test "accname: button name from fallback content mixing attr() and strings with ::before and ::after" {
  let html =
    #|<style>
    #|    .fallback-before-mixed::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " start " attr(data-alt-text-before) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after-mixed::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " start " attr(data-alt-text-after) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|</style>
    #|<button data-alt-text-before="alt-before" data-alt-text-after="alt-after" class="ex fallback-before-mixed fallback-after-mixed">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"start alt-before end label start alt-after end\")")
}

///|
test "accname: heading name from fallback content mixing attr() and strings with ::before and ::after" {
  let html =
    #|<style>
    #|    .fallback-before-mixed::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " start " attr(data-alt-text-before) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after-mixed::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " start " attr(data-alt-text-after) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|</style>
    #|<h3 data-alt-text-before="alt-before" data-alt-text-after="alt-after" class="ex fallback-before-mixed fallback-after-mixed">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"start alt-before end label start alt-after end\")")
}

///|
test "accname: link name from fallback content mixing attr() and strings with ::before and ::after" {
  let html =
    #|<style>
    #|    .fallback-before-mixed::before { content: " before "; /* [sic] leading and trailing space */
    #|          content: " before " / " start " attr(data-alt-text-before) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|        .fallback-after-mixed::after { content: " after "; /* [sic] leading and trailing space */
    #|          content: " after " / " start " attr(data-alt-text-after) " end "; /* Override the previous line for engines that support the Alternative Text syntax. */ }
    #|</style>
    #|<a href="#" data-alt-text-before="alt-before" data-alt-text-after="alt-after" class="ex fallback-before-mixed fallback-after-mixed">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"start alt-before end label start alt-after end\")")
}

///|
test "accname: primitive radio input with ::before containing empty alternative text" {
  let html =
    #|<style>
    #|    .fallback-before-empty::before { content: "before"  / ""; }
    #|</style>
    #|<input class="ex fallback-before-empty" type=radio style=appearance:none>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="None")
}

///|
test "accname: primitive radio input with ::before containing empty alternative text for an image" {
  let html =
    #|<style>
    #|    .fallback-before-image-empty::before { content: "before " url(/images/blue.png) / ""; }
    #|</style>
    #|<input class="ex fallback-before-image-empty" type=radio style=appearance:none>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Textbox)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="None")
}

///|
test "accname: button name from content for each child" {
  let html = "<button ><span>one</span> <span>two</span> <span>three</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: heading name from content for each child" {
  let html = "<h3 ><span>one</span> <span>two</span> <span>three</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: link name from content for each child" {
  let html = "<a href=\"#\" ><span>one</span> <span>two</span> <span>three</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: button name from content for each child including image" {
  let html = "<button ><span>one</span> <img alt=\"two\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> <span>three</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: heading name from content for each child including image" {
  let html = "<h3 ><span>one</span> <img alt=\"two\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> <span>three</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: link name from content for each child including image" {
  let html = "<a href=\"#\" ><span>one</span> <img alt=\"two\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> <span>three</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: button name from content for each child including nested image" {
  let html = "<button ><span>one</span> <span>two <img alt=\"three\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"></span> <span>four</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three four\")")
}

///|
test "accname: heading name from content for each child including nested image" {
  let html = "<h3 ><span>one</span> <span>two <img alt=\"three\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"></span> <span>four</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three four\")")
}

///|
test "accname: link name from content for each child including nested image" {
  let html = "<a href=\"#\" ><span>one</span> <span>two <img alt=\"three\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"></span> <span>four</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three four\")")
}

///|
test "accname: heading name from content for each child including nested button with nested image" {
  let html = "<h3 > heading <button> button <img alt=\"image\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> button </button> heading </h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading button image button heading\")")
}

///|
test "accname: heading name from content for each child including nested link with nested image" {
  let html = "<h3 > heading <a href=\"#\"> link <img alt=\"image\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> link </a> heading </h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading link image link heading\")")
}

///|
test "accname: heading name from content for each child including nested link using aria-label with nested image" {
  let html = "<h3 > heading <a href=\"#\" aria-label=\"link aria-label\"><!-- should skip the other link text --> ignored link text <img id=\"nested_image_label_1\" alt=\"ignored image alt\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> ignored link text </a> heading </h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading link aria-label heading\")")
}

///|
test "accname: heading name from content for each child including nested link using aria-labelledby with nested image" {
  let html =
    #|<div>
    #|  <img id="nested_image_label1" alt="image" src="data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="> ignored link text </a>
    #|  <h3 > heading <a href="#" aria-labelledby="nested_image_label1"><!-- should skip the other link text --> ignored link text <img id="nested_image_label1" alt="image" src="data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="> ignored link text </a> heading </h3>
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"heading image heading\")")
}

///|
test "accname: link name from content for each child including nested image (referenced elsewhere via labelledby)" {
  let html = "<a href=\"#\" > link2 <img id=\"nested_image_label2\" alt=\"image\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"> <!-- image skipped in this link (when computing heading text) because it was already referenced by the first link within this heading label recursion cycle. --> <!-- but image not skipped when computing the text of the link itself since it has not been referenced in that context --> link3 </a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link2 image link3\")")
}

///|
test "accname: button name from content for each child (no space, inline)" {
  let html = "<button ><span>one</span><span>two</span><span>three</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"onetwothree\")")
}

///|
test "accname: heading name from content for each child (no space, inline)" {
  let html = "<h3 ><span>one</span><span>two</span><span>three</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"onetwothree\")")
}

///|
test "accname: link name from content for each child (no space, inline)" {
  let html = "<a href=\"#\" ><span>one</span><span>two</span><span>three</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"onetwothree\")")
}

///|
test "accname: button name from content for each child (no space, display:block)" {
  let html = "<button ><span>one</span><span>two</span><span>three</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: heading name from content for each child (no space, display:block)" {
  let html = "<h3 ><span>one</span><span>two</span><span>three</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: link name from content for each child (no space, display:block)" {
  let html = "<a href=\"#\" ><span>one</span><span>two</span><span>three</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: button name from content for each child (no space, display:inline-block)" {
  let html = "<button ><span>one</span><span>two</span><span>three</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: heading name from content for each child (no space, display:inline-block)" {
  let html = "<h3 ><span>one</span><span>two</span><span>three</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: link name from content for each child (no space, display:inline-block)" {
  let html = "<a href=\"#\" ><span>one</span><span>two</span><span>three</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"one two three\")")
}

///|
test "accname: heading name from content with text-transform:none" {
  let html = "<h1 style=\"text-transform:none;\">Call us</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Call us\")")
}

///|
test "accname: heading name from content with text-transform:uppercase" {
  let html = "<h1 style=\"text-transform:uppercase;\">Call us</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"CALL US\")")
}

///|
test "accname: heading name from content with text-transform:capitalize" {
  let html = "<h1 style=\"text-transform:capitalize;\">Call us</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Call Us\")")
}

///|
test "accname: heading name from content with text-transform:lowercase" {
  let html = "<h1 style=\"text-transform:lowercase;\">Call us</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"call us\")")
}

///|
test "accname: heading name from content with text-transform:full-size-kana" {
  let html = "<h3 lang=\"ja\" style=\"text-transform:full-size-kana;\" >びょういんのかんじゃサービス</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"びょういんのかんじゃサービス\")")
}

///|
test "accname: implicit button name from content containing a dfn element" {
  let html = "<button ><span>this is an </span><dfn>example</dfn></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: implicit heading name from content containing a dfn element" {
  let html = "<h3 ><span>this is an </span><dfn>example</dfn></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: implicit link name from content containing a dfn element" {
  let html = "<a href=\"#\" ><span>this is an </span><dfn>example</dfn></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: implicit button name from content containing an element with explicit term role" {
  let html = "<button ><span>this is an </span><span role=\"term\">example</span></button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: implicit heading name from content containing an element with explicit term role" {
  let html = "<h3 ><span>this is an </span><span role=\"term\">example</span></h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: implicit link name from content containing an element explicit with term role" {
  let html = "<a href=\"#\" ><span>this is an </span><span role=\"term\">example</span></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: explicit button name from content containing a dfn element" {
  let html = "<div role=\"button\" tabindex=\"0\" ><span>this is an </span><dfn>example</dfn></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: explicit heading name from content containing a dfn element" {
  let html = "<div role=\"heading\" ><span>this is an </span><dfn>example</dfn></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: explicit link name from content containing a dfn element" {
  let html = "<div role=\"link\" tabindex=\"0\" ><span>this is an </span><dfn>example</dfn></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: explicit button name from content containing an element explicit with term role" {
  let html = "<div role=\"button\" tabindex=\"0\" ><span>this is an </span><span role=\"term\">example</span></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: explicit heading name from content containing an element explicit with term role" {
  let html = "<div role=\"heading\" ><span>this is an </span><span role=\"term\">example</span></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: explicit link name from content containing an element explicit with term role" {
  let html = "<div role=\"link\" tabindex=\"0\" ><span>this is an </span><span role=\"term\">example</span></div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"this is an example\")")
}

///|
test "accname: comp_name_from_content_alt_counter_invalidation: button with alt counter on ::before" {
  let html =
    #|<style>
    #|    .alt-counter::before { counter-set: cnt 5051;
    #|      content: "" / counter(cnt); }
    #|</style>
    #|<button class="ex alt-counter">label</button>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Button)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"228 label\")")
}

///|
test "accname: comp_name_from_content_alt_counter_invalidation: heading with alt counter on ::before" {
  let html =
    #|<style>
    #|    .alt-counter::before { counter-set: cnt 5051;
    #|      content: "" / counter(cnt); }
    #|</style>
    #|<h3 class="ex alt-counter">label</h3>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Heading)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"228 label\")")
}

///|
test "accname: comp_name_from_content_alt_counter_invalidation: link with alt counter on ::before" {
  let html =
    #|<style>
    #|    .alt-counter::before { counter-set: cnt 5051;
    #|      content: "" / counter(cnt); }
    #|</style>
    #|<a href="#" class="ex alt-counter">label</a>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(Link)
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="Some(\"228 label\")")
}

///|
test "accname: first button" {
  let html = "<button >label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"1 label\")")
}

///|
test "accname: heading" {
  let html = "<h3 >label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"2 label\")")
}

///|
test "accname: link" {
  let html = "<a href=\"#\" >label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"3 label\")")
}

///|
test "accname: alertdialog role, name from heading" {
  let html = "<div role=\"alertdialog\" > <h2>alertdialog role heading contents</h2> <p>More alertdialog content.</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"alertdialog role heading contents\")")
}

///|
test "accname: article role, name from heading" {
  let html = "<div role=\"article\" > <h2>article role heading contents</h2> <p>More article content.</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"article role heading contents\")")
}

///|
test "accname: dialog role, name from heading" {
  let html = "<div role=\"dialog\" > <h2>dialog role heading contents</h2> <p>More dialog content.</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"dialog role heading contents\")")
}

///|
test "accname: group role, verify name is NOT from heading" {
  let html = "<div role=\"group\" > <div role=\"group\"> <h3>Not this one</h3> </div> <h2>nor this one</h2> <p>Nor this content.</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}

///|
test "accname: native dialog element, name from heading" {
  let html = "<dialog open > <h2>dialog heading contents</h2> <p>More dialog content.</p> </dialog>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"dialog heading contents\")")
}

///|
test "accname: article role, name from DFS heading" {
  let html = "<div role=\"article\" > <div role=\"group\"> <h3>article role simple DFS</h3> </div> <h2>Not this one</h2> <p>More article content.</p> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"article role simple DFS\")")
}

///|
test "accname: span[role=button] with text/element/text nodes, no space" {
  let html = "<span role=\"button\" tabindex=\"0\" >button<span></span>label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"buttonlabel\")")
}

///|
test "accname: div[role=heading] with text/element/text nodes, no space" {
  let html = "<div role=\"heading\" >heading<span></span>label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"headinglabel\")")
}

///|
test "accname: button with text/element/text nodes, no space" {
  let html = "<button >button<span></span>label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"buttonlabel\")")
}

///|
test "accname: heading with text/element/text nodes, no space" {
  let html = "<h3 >heading<span></span>label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"headinglabel\")")
}

///|
test "accname: link with text/element/text nodes, no space" {
  let html = "<a href=\"#\" >link<span></span>label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"linklabel\")")
}

///|
test "accname: span[role=button] with text/comment/text nodes, no space" {
  let html = "<span role=\"button\" tabindex=\"0\" > button<!-- with non-text node splitting concatenated text nodes -->label<!-- [sic] no extra spaces around first comment --> </span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"buttonlabel\")")
}

///|
test "accname: div[role=heading] with text/comment/text nodes, no space" {
  let html = "<div role=\"heading\" > heading<!-- with non-text node splitting concatenated text nodes -->label<!-- [sic] no extra spaces around first comment --> </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"headinglabel\")")
}

///|
test "accname: button with text/comment/text nodes, no space" {
  let html = "<button > button<!-- with non-text node splitting concatenated text nodes -->label<!-- [sic] no extra spaces around first comment --> </button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"buttonlabel\")")
}

///|
test "accname: heading with text/comment/text nodes, no space" {
  let html = "<h3 > heading<!-- with non-text node splitting concatenated text nodes -->label<!-- [sic] no extra spaces around first comment --> </h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"headinglabel\")")
}

///|
test "accname: link with text/comment/text nodes, no space" {
  let html = "<a href=\"#\" > link<!-- with non-text node splitting concatenated text nodes -->label<!-- [sic] no extra spaces around first comment --> </a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"linklabel\")")
}

///|
test "accname: span[role=button] with text/comment/text nodes, with space" {
  let html = "<span role=\"button\" tabindex=\"0\" > button <!-- comment node between text nodes with leading/trailing whitespace --> label </span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: div[role=heading] with text/comment/text nodes, with space" {
  let html = "<div role=\"heading\" > heading <!-- comment node between text nodes with leading/trailing whitespace --> label </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: button with text/comment/text nodes, with space" {
  let html = "<button > button <!-- comment node between text nodes with leading/trailing whitespace --> label </button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: heading with text/comment/text nodes, with space" {
  let html = "<h3 > heading <!-- comment node between text nodes with leading/trailing whitespace --> label </h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: link with text/comment/text nodes, with space" {
  let html = "<a href=\"#\" > link <!-- comment node between text nodes with leading/trailing whitespace --> label </a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link label\")")
}

///|
test "accname: span[role=button] with text node, with tab char" {
  let html = "<span role=\"button\" tabindex=\"0\" >button label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: div[role=heading] with text node, with tab char" {
  let html = "<div role=\"heading\" >heading label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: button with text node, with tab char" {
  let html = "<button >button label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: heading with text node, with tab char" {
  let html = "<h3 >heading label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: link with text node, with tab char" {
  let html = "<a href=\"#\" >link label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link label\")")
}

///|
test "accname: span[role=button] with text node, with non-breaking space" {
  let html = "<span role=\"button\" tabindex=\"0\" >button&nbsp;label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button&nbsp;label\")")
}

///|
test "accname: div[role=heading] with text node, with non-breaking space" {
  let html = "<div role=\"heading\" >heading&nbsp;label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading&nbsp;label\")")
}

///|
test "accname: button with text node, with non-breaking space" {
  let html = "<button >button&nbsp;label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button&nbsp;label\")")
}

///|
test "accname: heading with text node, with non-breaking space" {
  let html = "<h3 >heading&nbsp;label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading&nbsp;label\")")
}

///|
test "accname: link with text node, with non-breaking space" {
  let html = "<a href=\"#\" >link&nbsp;label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link&nbsp;label\")")
}

///|
test "accname: span[role=button] with text node, with extra non-breaking space" {
  let html = "<span role=\"button\" tabindex=\"0\" >button&nbsp;&nbsp;&nbsp;label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button&nbsp;&nbsp;&nbsp;label\")")
}

///|
test "accname: div[role=heading] with text node, with extra non-breaking space" {
  let html = "<div role=\"heading\" >heading&nbsp;&nbsp;&nbsp;label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading&nbsp;&nbsp;&nbsp;label\")")
}

///|
test "accname: button with text node, with extra non-breaking space" {
  let html = "<button >button&nbsp;&nbsp;&nbsp;label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button&nbsp;&nbsp;&nbsp;label\")")
}

///|
test "accname: heading with text node, with extra non-breaking space" {
  let html = "<h3 >heading&nbsp;&nbsp;&nbsp;label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading&nbsp;&nbsp;&nbsp;label\")")
}

///|
test "accname: link with text node, with extra non-breaking space" {
  let html = "<a href=\"#\" >link&nbsp;&nbsp;&nbsp;label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link&nbsp;&nbsp;&nbsp;label\")")
}

///|
test "accname: span[role=button] with text node, with leading/trailing non-breaking space" {
  let html = "<span role=\"button\" tabindex=\"0\" >&nbsp;button&nbsp;label&nbsp;</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"&nbsp;button&nbsp;label&nbsp;\")")
}

///|
test "accname: div[role=heading] with text node, with leading/trailing non-breaking space" {
  let html = "<div role=\"heading\" >&nbsp;heading&nbsp;label&nbsp;</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"&nbsp;heading&nbsp;label&nbsp;\")")
}

///|
test "accname: button with text node, with leading/trailing non-breaking space" {
  let html = "<button >&nbsp;button&nbsp;label&nbsp;</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"&nbsp;button&nbsp;label&nbsp;\")")
}

///|
test "accname: heading with text node, with leading/trailing non-breaking space" {
  let html = "<h3 >&nbsp;heading&nbsp;label&nbsp;</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"&nbsp;heading&nbsp;label&nbsp;\")")
}

///|
test "accname: link with text node, with leading/trailing non-breaking space" {
  let html = "<a href=\"#\" >&nbsp;link&nbsp;label&nbsp;</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"&nbsp;link&nbsp;label&nbsp;\")")
}

///|
test "accname: span[role=button] with text node, with mixed space and non-breaking space" {
  let html = "<span role=\"button\" tabindex=\"0\" >button &nbsp; label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button &nbsp; label\")")
}

///|
test "accname: div[role=heading] with text node, with mixed space and non-breaking space" {
  let html = "<div role=\"heading\" >heading &nbsp; label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading &nbsp; label\")")
}

///|
test "accname: button with text node, with mixed space and non-breaking space" {
  let html = "<button >button &nbsp; label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button &nbsp; label\")")
}

///|
test "accname: heading with text node, with mixed space and non-breaking space" {
  let html = "<h3 >heading &nbsp; label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading &nbsp; label\")")
}

///|
test "accname: link with text node, with mixed space and non-breaking space" {
  let html = "<a href=\"#\" >link &nbsp; label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link &nbsp; label\")")
}

///|
test "accname: span[role=button] with text node, with deeply nested space" {
  let html = "<span role=\"button\" tabindex=\"0\" > button<span><span><span><span><span><span><span> </span></span></span></span></span></span></span>label </span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: div[role=heading] with text node, with deeply nested space" {
  let html = "<div role=\"heading\" > heading<span><span><span><span><span><span><span> </span></span></span></span></span></span></span>label </div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: button with text node, with deeply nested space" {
  let html = "<button > button<span><span><span><span><span><span><span> </span></span></span></span></span></span></span>label </button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: heading with text node, with deeply nested space" {
  let html = "<h3 > heading<span><span><span><span><span><span><span> </span></span></span></span></span></span></span>label </h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: link with text node, with deeply nested space" {
  let html = "<a href=\"#\" > link<span><span><span><span><span><span><span> </span></span></span></span></span></span></span>label </a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link label\")")
}

///|
test "accname: span[role=button] with text node, with single line break" {
  let html = "<span role=\"button\" tabindex=\"0\" >button label</span>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: div[role=heading] with text node, with single line break" {
  let html = "<div role=\"heading\" >heading label</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: button with text node, with single line break" {
  let html = "<button >button label</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"button label\")")
}

///|
test "accname: heading with text node, with single line break" {
  let html = "<h3 >heading label</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"heading label\")")
}

///|
test "accname: link with text node, with single line break" {
  let html = "<a href=\"#\" >link label</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"link label\")")
}

///|
test "accname: link with img with tooltip label" {
  let html = "<a href=\"#\" title=\"title\" ><img alt=\"\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\"></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: link with text with tooltip label and no contents" {
  let html = "<a href=\"#\" title=\"title\" ></a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: link with text with tooltip label and contents" {
  let html = "<a href=\"#\" title=\"title\" >contents</a>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"contents\")")
}

///|
test "accname: div with text with tooltip label" {
  let html = "<div title=\"title\" role=\"group\" >contents</div>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: img with tooltip label without alt" {
  let html = "<img title=\"title\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: img with tooltip label with alt" {
  let html = "<img title=\"title\" alt=\"alt\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"alt\")")
}

///|
test "accname: img with tooltip label without title" {
  let html = "<img alt=\"alt\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"alt\")")
}

///|
test "accname: select with tooltip label" {
  let html = "<select title=\"title\" > <option value=\"\" disabled selected>select options</option> <option value=\"1\">option 1</option> <option value=\"2\">option 2</option> <option value=\"3\">option 3</option> </select>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: button with tooltip label" {
  let html = "<button title=\"title\" >contents</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"contents\")")
}

///|
test "accname: checkbox input with tooltip label" {
  let html = "<input type=\"checkbox\" title=\"title\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: radio input with tooltip label" {
  let html = "<input type=\"radio\" title=\"title\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: text input with placeholder and tooltip label" {
  let html = "<input type=\"text\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: password input with placeholder and tooltip label" {
  let html = "<input type=\"password\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: number input with placeholder and tooltip label" {
  let html = "<input type=\"number\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: search input with placeholder and tooltip label" {
  let html = "<input type=\"search\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: tel input with placeholder and tooltip label" {
  let html = "<input type=\"tel\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: email input with placeholder and tooltip label" {
  let html = "<input type=\"email\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: url input with placeholder and tooltip label" {
  let html = "<input type=\"url\" title=\"title\" placeholder=\"placeholder\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: textarea with placeholder and tooltip label" {
  let html = "<textarea title=\"title\" placeholder=\"placeholder\" ></textarea>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: abbr with tooltip label" {
  let html = "<abbr title=\"Web Platform Tests\" >WPT</abbr>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Web Platform Tests\")")
}

///|
test "accname: kbd with tooltip label" {
  let html = "<kbd title=\"Control + Option\" >CTRL + OPT</kbd>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"Control + Option\")")
}

///|
test "accname: summary with tooltip label and contents" {
  let html = "<summary title=\"title\" >contents</summary>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"contents\")")
}

///|
test "accname: iframe with tooltip label" {
  let html = "<iframe title=\"title\" width=\"20px\" height=\"20px\" ></iframe>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="Some(\"title\")")
}

///|
test "accname: img with tooltip label with empty alt" {
  let html = "<img title=\"title\" alt=\"\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="None")
}
