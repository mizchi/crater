///|
test "tokenize basic selectors" {
  let tokens = tokenize(".foo #bar div")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Delim(.)\", \"Ident(foo)\", \"Whitespace\", \"Hash(bar)\", \"Whitespace\", \"Ident(div)\", \"EOF\"]",
  )
}

///|
test "tokenize property declaration" {
  let tokens = tokenize("width: 100px")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Ident(width)\", \"Colon\", \"Whitespace\", \"Dimension(100, px)\", \"EOF\"]",
  )
}

///|
test "tokenize numbers" {
  let tokens = tokenize("10 10.5 10% 10px 10em")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Number(10, int)\", \"Whitespace\", \"Number(10.5, num)\", \"Whitespace\", \"Percentage(10)\", \"Whitespace\", \"Dimension(10, px)\", \"Whitespace\", \"Dimension(10, em)\", \"EOF\"]",
  )
}

///|
test "tokenize function" {
  let tokens = tokenize("calc(100% - 20px)")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Function(calc)\", \"Percentage(100)\", \"Whitespace\", \"Delim(-)\", \"Whitespace\", \"Dimension(20, px)\", \"RightParen\", \"EOF\"]",
  )
}

///|
test "tokenize string" {
  let tokens = tokenize("\"hello world\"")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"String(hello world)\", \"EOF\"]",
  )
}

///|
test "tokenize at-rule" {
  let tokens = tokenize("@media screen")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"AtKeyword(media)\", \"Whitespace\", \"Ident(screen)\", \"EOF\"]",
  )
}

///|
test "tokenize braces and brackets" {
  let tokens = tokenize("{ [ ( ) ] }")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"LeftBrace\", \"Whitespace\", \"LeftBracket\", \"Whitespace\", \"LeftParen\", \"Whitespace\", \"RightParen\", \"Whitespace\", \"RightBracket\", \"Whitespace\", \"RightBrace\", \"EOF\"]",
  )
}

///|
test "tokenize comment" {
  let tokens = tokenize("a /* comment */ b")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Ident(a)\", \"Whitespace\", \"Whitespace\", \"Ident(b)\", \"EOF\"]",
  )
}

///|
test "tokenize css rule" {
  let tokens = tokenize(".container { display: flex; }")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Delim(.)\", \"Ident(container)\", \"Whitespace\", \"LeftBrace\", \"Whitespace\", \"Ident(display)\", \"Colon\", \"Whitespace\", \"Ident(flex)\", \"Semicolon\", \"Whitespace\", \"RightBrace\", \"EOF\"]",
  )
}

///|
test "tokenize negative number" {
  let tokens = tokenize("-10px")
  inspect(
    tokens.map(fn(t) { t.to_string() }),
    content="[\"Dimension(-10, px)\", \"EOF\"]",
  )
}
