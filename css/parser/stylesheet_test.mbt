///|
test "parse stylesheet with flex properties" {
  let css =
    #|.row { display: flex; flex-direction: row; gap: 10px; }
    #|.box { width: 50px; height: 50px; }
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="2")

  // Check first rule
  let rule0 = stylesheet.rules[0]
  inspect(rule0.selector_text, content=".row")

  // Check declarations
  let decl_strs : Array[String] = []
  for decl in rule0.declarations {
    match decl.value {
      @cascade.Value(v) => decl_strs.push(decl.property + ": " + v)
      _ => ()
    }
  }
  inspect(decl_strs, content=(
    #|["display: flex", "flex-direction: row", "gap: 10px"]
  ))
}
