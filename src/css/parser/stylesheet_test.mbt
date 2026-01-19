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
  inspect(
    decl_strs,
    content=(
      #|["display: flex", "flex-direction: row", "gap: 10px"]
    ),
  )
}

///|
test "parse comma-separated selectors" {
  let css = "h1, h2, h3 { color: red; }"
  let stylesheet = @parser.parse_stylesheet(css)
  // Each selector becomes a separate rule
  inspect(stylesheet.rules.length(), content="3")
  inspect(stylesheet.rules[0].selector_text, content="h1")
  inspect(stylesheet.rules[1].selector_text, content="h2")
  inspect(stylesheet.rules[2].selector_text, content="h3")
}

///|
test "parse !important declarations" {
  let css = ".urgent { color: red !important; background: blue; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let rule = stylesheet.rules[0]
  // Check that first declaration is important
  inspect(rule.declarations[0].importance, content="Important")
  inspect(rule.declarations[1].importance, content="Normal")
}

///|
test "parse @media rule and following rule" {
  let css =
    #|@media screen { .hidden { display: none; } }
    #|.visible { display: block; }
  let stylesheet = @parser.parse_stylesheet(css)
  // Should parse @media rule and .visible
  inspect(stylesheet.rules.length(), content="2")
  inspect(stylesheet.rules[0].selector_text, content=".hidden")
  match stylesheet.rules[0].media_query {
    Some(mq) => inspect(mq.queries[0].media_type, content="Some(Screen)")
    None => inspect("should have media query", content="has media query")
  }
  inspect(stylesheet.rules[1].selector_text, content=".visible")
  inspect(stylesheet.rules[1].media_query, content="None")
}

///|
test "skip @import rule" {
  let css =
    #|@import url("styles.css");
    #|body { margin: 0; }
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="body")
}

///|
test "parse complex selectors" {
  let css = "div.container > p.text { margin: 10px; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="div.container > p.text")
}

///|
test "parse attribute selectors" {
  let css = "input[type=\"text\"] { border: 1px; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
}

///|
test "parse pseudo-class selectors" {
  let css = "a:hover { text-decoration: underline; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
}

///|
test "parse multiple rules" {
  let css =
    #|* { box-sizing: border-box; }
    #|html, body { margin: 0; padding: 0; }
    #|.container { max-width: 1200px; }
    #|#main { display: flex; }
  let stylesheet = @parser.parse_stylesheet(css)
  // * -> 1, html,body -> 2, .container -> 1, #main -> 1
  inspect(stylesheet.rules.length(), content="5")
}

///|
test "parse empty rule" {
  let css = ".empty { }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="0")
}

///|
test "parse rule with trailing semicolon" {
  let css = ".test { width: 100px; height: 50px; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="2")
}

///|
test "parse rule without trailing semicolon" {
  let css = ".test { width: 100px; height: 50px }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="2")
}

///|
test "parse calc value" {
  let css = ".calc { width: calc(100% - 20px); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let decl = stylesheet.rules[0].declarations[0]
  match decl.value {
    @cascade.Value(v) => inspect(v, content="calc(100% - 20px)")
    _ => ()
  }
}

///|
test "parse minmax value" {
  let css = ".grid { grid-template-columns: minmax(100px, 1fr); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
}

///|
test "parse var function" {
  let css = ".themed { color: var(--primary-color); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let decl = stylesheet.rules[0].declarations[0]
  match decl.value {
    @cascade.Value(v) => inspect(v, content="var(--primary-color)")
    _ => ()
  }
}

///|
test "parse descendant selector" {
  let css = "div p span { color: blue; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="div p span")
}

///|
test "parse child combinator selector" {
  let css = "ul > li > a { color: green; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="ul > li > a")
}

///|
test "parse adjacent sibling selector" {
  let css = "h1 + p { margin-top: 0; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="h1 + p")
}

///|
test "parse general sibling selector" {
  let css = "h1 ~ p { color: gray; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="h1 ~ p")
}

///|
test "parse multiple declarations" {
  let css =
    #|.box {
    #|  width: 100px;
    #|  height: 200px;
    #|  margin: 10px;
    #|  padding: 20px;
    #|  display: flex;
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="5")
}

///|
test "parse empty stylesheet" {
  let css = ""
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="0")
}

///|
test "parse stylesheet with only whitespace" {
  let css = "   \n\t\n   "
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="0")
}

///|
test "skip @keyframes rule" {
  let css =
    #|@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    #|.fade { animation: fadeIn 1s; }
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content=".fade")
}

///|
test "skip @font-face rule" {
  let css =
    #|@font-face { font-family: "MyFont"; src: url("font.woff"); }
    #|body { font-family: "MyFont"; }
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="body")
}

///|
test "skip @charset rule" {
  let css =
    #|@charset "UTF-8";
    #|.content { color: black; }
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content=".content")
}

///|
test "parse id selector" {
  let css = "#header { height: 60px; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="#header")
}

///|
test "parse class and id combined" {
  let css = "div#main.container { width: 100%; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="div#main.container")
}

///|
test "parse universal selector" {
  let css = "* { margin: 0; padding: 0; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="*")
  inspect(stylesheet.rules[0].declarations.length(), content="2")
}

///|
test "parse pseudo-element selector" {
  let css = "p::first-line { font-weight: bold; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="p::first-line")
}

///|
test "parse multiple pseudo-classes" {
  let css = "a:hover:focus { outline: none; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="a:hover:focus")
}

///|
test "parse nth-child selector" {
  let css = "li:nth-child(2n+1) { background: #eee; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  // Note: the + sign is consumed as part of the number token, resulting in "2n1"
  inspect(stylesheet.rules[0].selector_text, content="li:nth-child(2n1)")
}

///|
test "parse attribute selector with value" {
  let css = "a[href^=\"https\"] { color: green; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
}

///|
test "parse multiple @rules before content" {
  let css =
    #|@charset "UTF-8";
    #|@import url("base.css");
    #|@media print { .no-print { display: none; } }
    #|.main { display: block; }
  let stylesheet = @parser.parse_stylesheet(css)
  // @charset and @import are skipped, @media is parsed, then .main
  inspect(stylesheet.rules.length(), content="2")
  inspect(stylesheet.rules[0].selector_text, content=".no-print")
  match stylesheet.rules[0].media_query {
    Some(mq) => inspect(mq.queries[0].media_type, content="Some(Print)")
    None => inspect("should have media query", content="has media query")
  }
  inspect(stylesheet.rules[1].selector_text, content=".main")
  inspect(stylesheet.rules[1].media_query, content="None")
}

///|
test "parse rgb color value" {
  let css = ".color { background: rgb(255, 128, 0); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let decl = stylesheet.rules[0].declarations[0]
  match decl.value {
    @cascade.Value(v) => inspect(v, content="rgb(255, 128, 0)")
    _ => ()
  }
}

///|
test "parse rgba color value" {
  let css = ".color { background: rgba(255, 128, 0, 0.5); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let decl = stylesheet.rules[0].declarations[0]
  match decl.value {
    @cascade.Value(v) => inspect(v, content="rgba(255, 128, 0, 0.5)")
    _ => ()
  }
}

///|
test "parse url function" {
  let css = ".bg { background-image: url(\"image.png\"); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let decl = stylesheet.rules[0].declarations[0]
  match decl.value {
    @cascade.Value(v) => inspect(v, content="url(\"image.png\")")
    _ => ()
  }
}

///|
test "parse negative values" {
  let css = ".neg { margin: -10px; top: -20px; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="2")
}

///|
test "parse float values" {
  let css = ".float { opacity: 0.5; line-height: 1.5; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="2")
}

///|
test "parse multiple classes selector" {
  let css = ".class1.class2.class3 { display: block; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content=".class1.class2.class3")
}

///|
test "parse complex comma-separated selectors" {
  let css = "div.a, span.b, p.c { color: red; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="3")
  inspect(stylesheet.rules[0].selector_text, content="div.a")
  inspect(stylesheet.rules[1].selector_text, content="span.b")
  inspect(stylesheet.rules[2].selector_text, content="p.c")
}

///|
test "parse repeat function value" {
  let css = ".grid { grid-template-columns: repeat(3, 1fr); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let decl = stylesheet.rules[0].declarations[0]
  match decl.value {
    @cascade.Value(v) => inspect(v, content="repeat(3, 1fr)")
    _ => ()
  }
}

///|
test "parse transform function" {
  let css = ".transform { transform: rotate(45deg) scale(1.5); }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
}

///|
test "parse multiple selectors with different combinators" {
  let css = "nav > ul li a:hover { color: blue; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="nav > ul li a:hover")
}

///|
test "parse shorthand property values" {
  let css = ".box { margin: 10px 20px 30px 40px; border: 1px solid black; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].declarations.length(), content="2")
}

///|
test "parse !important with extra spaces" {
  let css = ".urgent { color: red   !   important; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let rule = stylesheet.rules[0]
  inspect(rule.declarations[0].importance, content="Important")
}

///|
test "parse :not pseudo-class" {
  let css = "p:not(.special) { color: gray; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content="p:not(.special)")
}

///|
test "parse :first-child and :last-child" {
  let css = "li:first-child { margin-top: 0; } li:last-child { margin-bottom: 0; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="2")
  inspect(stylesheet.rules[0].selector_text, content="li:first-child")
  inspect(stylesheet.rules[1].selector_text, content="li:last-child")
}

///|
test "parse @media rule with screen" {
  let css =
    #|@media screen {
    #|  .container { width: 100%; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content=".container")
  // Check that the rule has a media query
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries.length(), content="1")
      inspect(mq.queries[0].media_type, content="Some(Screen)")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with min-width" {
  let css =
    #|@media (min-width: 768px) {
    #|  .sidebar { display: block; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  inspect(stylesheet.rules[0].selector_text, content=".sidebar")
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries.length(), content="1")
      inspect(mq.queries[0].conditions.length(), content="1")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with multiple conditions" {
  let css =
    #|@media screen and (min-width: 768px) {
    #|  .responsive { flex-direction: row; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries[0].media_type, content="Some(Screen)")
      inspect(mq.queries[0].conditions.length(), content="1")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with multiple rules inside" {
  let css =
    #|@media print {
    #|  .no-print { display: none; }
    #|  .print-only { display: block; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="2")
  inspect(stylesheet.rules[0].selector_text, content=".no-print")
  inspect(stylesheet.rules[1].selector_text, content=".print-only")
  // Both rules should have the same media query
  match (stylesheet.rules[0].media_query, stylesheet.rules[1].media_query) {
    (Some(mq1), Some(mq2)) => {
      inspect(mq1.queries[0].media_type, content="Some(Print)")
      inspect(mq2.queries[0].media_type, content="Some(Print)")
    }
    _ => inspect("should have media query", content="has media query")
  }
}

///|
test "parse mixed rules and @media rules" {
  let css =
    #|.always { color: black; }
    #|@media screen {
    #|  .screen-only { color: blue; }
    #|}
    #|.also-always { color: red; }
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="3")
  inspect(stylesheet.rules[0].selector_text, content=".always")
  inspect(stylesheet.rules[0].media_query, content="None")
  inspect(stylesheet.rules[1].selector_text, content=".screen-only")
  match stylesheet.rules[1].media_query {
    Some(_) => inspect("has media query", content="has media query")
    None => inspect("should have media query", content="has media query")
  }
  inspect(stylesheet.rules[2].selector_text, content=".also-always")
  inspect(stylesheet.rules[2].media_query, content="None")
}

///|
test "parse @media rule with prefers-color-scheme" {
  let css =
    #|@media (prefers-color-scheme: dark) {
    #|  body { background: #000; color: #fff; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  match stylesheet.rules[0].media_query {
    Some(mq) => inspect(mq.queries[0].conditions.length(), content="1")
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media prefers-color-scheme and verify media query" {
  let css =
    #|@media (prefers-color-scheme: dark) {
    #|  body { background: #1a1a1a; color: #eee; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let rule = stylesheet.rules[0]
  match rule.media_query {
    Some(mq) => {
      inspect(mq.queries.length(), content="1")
      inspect(
        mq.queries[0].conditions[0],
        content="PrefersColorScheme(\"dark\")",
      )
      // Evaluate against light mode - should NOT match
      let light_env = @media.MediaEnvironment::with_color_scheme(
        375.0,
        600.0,
        @media.ColorScheme::Light,
      )
      inspect(mq.evaluate(light_env), content="false")
      // Evaluate against dark mode - should match
      let dark_env = @media.MediaEnvironment::with_color_scheme(
        375.0,
        600.0,
        @media.ColorScheme::Dark,
      )
      inspect(mq.evaluate(dark_env), content="true")
    }
    None => fail("Expected media query")
  }
}

///|
test "parse multiple @media rules" {
  let css =
    #|@media screen {
    #|  .screen { display: block; }
    #|}
    #|@media print {
    #|  .print { display: block; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="2")
  inspect(stylesheet.rules[0].selector_text, content=".screen")
  inspect(stylesheet.rules[1].selector_text, content=".print")
  match (stylesheet.rules[0].media_query, stylesheet.rules[1].media_query) {
    (Some(mq1), Some(mq2)) => {
      inspect(mq1.queries[0].media_type, content="Some(Screen)")
      inspect(mq2.queries[0].media_type, content="Some(Print)")
    }
    _ => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with comma-separated queries" {
  let css =
    #|@media screen, print {
    #|  .universal { display: block; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries.length(), content="2")
      inspect(mq.queries[0].media_type, content="Some(Screen)")
      inspect(mq.queries[1].media_type, content="Some(Print)")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with not modifier" {
  let css =
    #|@media not print {
    #|  .no-print { display: block; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries[0].negated, content="true")
      inspect(mq.queries[0].media_type, content="Some(Print)")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with only modifier" {
  let css =
    #|@media only screen {
    #|  .modern { display: flex; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries[0].only, content="true")
      inspect(mq.queries[0].media_type, content="Some(Screen)")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse @media rule with comma-separated selectors inside" {
  let css =
    #|@media screen {
    #|  h1, h2, h3 { color: blue; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  // Each selector should be a separate rule
  inspect(stylesheet.rules.length(), content="3")
  inspect(stylesheet.rules[0].selector_text, content="h1")
  inspect(stylesheet.rules[1].selector_text, content="h2")
  inspect(stylesheet.rules[2].selector_text, content="h3")
  // All should have the same media query
  for i = 0; i < 3; i = i + 1 {
    match stylesheet.rules[i].media_query {
      Some(mq) => inspect(mq.queries[0].media_type, content="Some(Screen)")
      None => inspect("should have media query", content="has media query")
    }
  }
}

///|
test "parse @media with range syntax" {
  let css =
    #|@media (width >= 768px) {
    #|  .wide { width: 100%; }
    #|}
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  match stylesheet.rules[0].media_query {
    Some(mq) => {
      inspect(mq.queries.length(), content="1")
      inspect(mq.queries[0].conditions.length(), content="1")
    }
    None => inspect("should have media query", content="has media query")
  }
}

///|
test "parse border-collapse property" {
  let css = "table { border-collapse: collapse; border-spacing: 0; }"
  let stylesheet = @parser.parse_stylesheet(css)
  inspect(stylesheet.rules.length(), content="1")
  let rule = stylesheet.rules[0]
  inspect(rule.declarations.length(), content="2")

  // Check declarations
  let decl_strs : Array[String] = []
  for decl in rule.declarations {
    match decl.value {
      @cascade.Value(v) => decl_strs.push(decl.property + ": " + v)
      _ => ()
    }
  }
  inspect(
    decl_strs,
    content=(
      #|["border-collapse: collapse", "border-spacing: 0"]
    ),
  )
}
