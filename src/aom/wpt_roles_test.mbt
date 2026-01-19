///|
/// WPT html-aam Role Mapping Tests (auto-generated)
/// Source: wpt-tests/html-aam/roles.html
/// Run: npx tsx tools/gen-wpt-aom-tests.ts html-aam-roles

///|
test "html-aam/roles: el-address" {
  let html = "<address >x</address>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Group")
}

///|
test "html-aam/roles: el-article" {
  let html = "<article >x</article>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Article")
}

///|
test "html-aam/roles: el-blockquote" {
  let html = "<blockquote >x</blockquote>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Blockquote")
}

///|
test "html-aam/roles: el-button" {
  let html = "<button >x</button>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "html-aam/roles: el-code" {
  let html = "<code >x</code>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Code")
}

///|
test "html-aam/roles: el-dd" {
  let html = "<dd >x</dd>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Definition")
}

///|
test "html-aam/roles: el-del" {
  let html = "<del >x</del>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Deletion")
}

///|
test "html-aam/roles: el-details" {
  let html = "<details >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Group")
}

///|
test "html-aam/roles: el-dfn" {
  let html = "<dfn >x</dfn>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Term")
}

///|
test "html-aam/roles: el-dt" {
  let html = "<dt >x</dt>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Term")
}

///|
test "html-aam/roles: el-em" {
  let html = "<em >x</em>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Emphasis")
}

///|
test "html-aam/roles: el-fieldset" {
  let html = "<fieldset >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Group")
}

///|
test "html-aam/roles: el-figure" {
  let html = "<figure >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Figure")
}

///|
test "html-aam/roles: el-form" {
  let html = "<form aria-label=\"form\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Form")
}

///|
test "html-aam/roles: el-h1" {
  let html = "<h1 >x</h1>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
}

///|
test "html-aam/roles: el-h2" {
  let html = "<h2 >x</h2>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
}

///|
test "html-aam/roles: el-h3" {
  let html = "<h3 >x</h3>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
}

///|
test "html-aam/roles: el-h4" {
  let html = "<h4 >x</h4>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
}

///|
test "html-aam/roles: el-h5" {
  let html = "<h5 >x</h5>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
}

///|
test "html-aam/roles: el-h6" {
  let html = "<h6 >x</h6>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Heading")
}

///|
test "html-aam/roles: el-hgroup" {
  let html = "<hgroup >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Group")
}

///|
test "html-aam/roles: el-hr" {
  let html = "<hr >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Separator")
}

///|
test "html-aam/roles: el-img" {
  let html = "<img alt=\"x\" src=\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\">"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Img")
}

///|
test "html-aam/roles: el-input-button" {
  let html = "<input type=\"button\" value=\"x\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "html-aam/roles: el-input-checkbox" {
  let html = "<input type=\"checkbox\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Checkbox")
}

///|
test "html-aam/roles: el-input-email" {
  let html = "<input type=\"email\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam/roles: el-input-number" {
  let html = "<input type=\"number\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="SpinButton")
}

///|
test "html-aam/roles: el-input-radio" {
  let html = "<input type=\"radio\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Radio")
}

///|
test "html-aam/roles: el-input-range" {
  let html = "<input type=\"range\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Slider")
}

///|
test "html-aam/roles: el-input-reset" {
  let html = "<input type=\"reset\" value=\"x\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "html-aam/roles: el-input-search" {
  let html = "<input type=\"search\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="SearchBox")
}

///|
test "html-aam/roles: el-input-search-with-role" {
  let html = "<input type=\"search\" role=\"combobox\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Combobox")
}

///|
test "html-aam/roles: el-input-submit" {
  let html = "<input type=\"submit\" value=\"x\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Button")
}

///|
test "html-aam/roles: el-input-tel" {
  let html = "<input type=\"tel\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam/roles: el-input-text" {
  let html = "<input type=\"text\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam/roles: el-input-url" {
  let html = "<input type=\"url\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam/roles: el-ins" {
  let html = "<ins >x</ins>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Insertion")
}

///|
test "html-aam/roles: el-li-in-ul" {
  let html = "<li >x</li>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="ListItem")
}

///|
test "html-aam/roles: el-li-in-ol" {
  let html = "<li >x</li>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="ListItem")
}

///|
test "html-aam/roles: el-main" {
  let html = "<main >x</main>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Main")
}

///|
test "html-aam/roles: el-mark" {
  let html = "<mark >x</mark>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Mark")
}

///|
test "html-aam/roles: el-menu" {
  let html = "<menu >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="List")
}

///|
test "html-aam/roles: el-meter" {
  let html = "<meter min=\"0\" max=\"100\" low=\"20\" high=\"80\" optimum=\"60\" value=\"50\">x</meter>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Meter")
}

///|
test "html-aam/roles: el-nav" {
  let html = "<nav >x</nav>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Navigation")
}

///|
test "html-aam/roles: el-ol" {
  let html = "<ol >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="List")
}

///|
test "html-aam/roles: el-option" {
  let html = "<option >x</option>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Option")
}

///|
test "html-aam/roles: el-output" {
  let html = "<output >x</output>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Status")
}

///|
test "html-aam/roles: el-p" {
  let html = "<p >x</p>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Paragraph")
}

///|
test "html-aam/roles: el-progress" {
  let html = "<progress >x</progress>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Progressbar")
}

///|
test "html-aam/roles: el-s" {
  let html = "<s >x</s>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Deletion")
}

///|
test "html-aam/roles: el-search" {
  let html = "<search >x</search>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Search")
}

///|
test "html-aam/roles: el-select-combobox" {
  let html = "<select >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Combobox")
}

///|
test "html-aam/roles: el-select-listbox" {
  let html = "<select size=\"2\" >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Listbox")
}

///|
test "html-aam/roles: el-strong" {
  let html = "<strong >x</strong>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Strong")
}

///|
test "html-aam/roles: el-sub" {
  let html = "<sub >x</sub>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Subscript")
}

///|
test "html-aam/roles: el-sup" {
  let html = "<sup >x</sup>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Superscript")
}

///|
test "html-aam/roles: el-time" {
  let html = "<time >x</time>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Time")
}

///|
test "html-aam/roles: el-textarea" {
  let html = "<textarea >x</textarea>"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="Textbox")
}

///|
test "html-aam/roles: el-ul" {
  let html = "<ul >"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="List")
}
