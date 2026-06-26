///|
test "flatten_css_cascade_layers unwraps @layer blocks" {
  // Block layer: inner rules survive, wrapper removed.
  inspect(
    flatten_css_cascade_layers("@layer base{body{margin:0}}"),
    content="body{margin:0}",
  )
}

///|
test "flatten_css_cascade_layers handles nesting and statements" {
  inspect(
    flatten_css_cascade_layers("@layer a{@layer b{.x{color:red}}}"),
    content=".x{color:red}",
  )
  // Bare @layer ordering statement is dropped.
  inspect(
    flatten_css_cascade_layers("@layer a,b;.y{color:blue}"),
    content=".y{color:blue}",
  )
}

///|
test "flatten_css_cascade_layers preserves @media inside a layer" {
  inspect(
    flatten_css_cascade_layers("@layer a{@media(min-width:1px){.z{color:red}}}"),
    content="@media(min-width:1px){.z{color:red}}",
  )
}

///|
test "flatten_css_cascade_layers leaves layer-free css untouched" {
  let css = ".a{color:red}.b{display:flex}"
  inspect(
    flatten_css_cascade_layers(css),
    content=".a{color:red}.b{display:flex}",
  )
}

///|
test "flatten_css_cascade_layers ignores @layer inside strings" {
  // A brace/keyword inside a string literal must not corrupt counting.
  inspect(
    flatten_css_cascade_layers(".a::before{content:\"@layer x{\"}"),
    content=".a::before{content:\"@layer x{\"}",
  )
}
