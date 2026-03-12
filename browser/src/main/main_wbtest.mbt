///|
test "parse_args_list enables kitty output mode" {
  let options = parse_args_list(["--kitty", "https://example.com"])
  inspect(options.kitty, content="true")
  inspect(options.text, content="false")
  inspect(options.sixel, content="false")
  inspect(options.url, content="https://example.com")
}

///|
test "parse_args_list defaults to text when no output mode is provided" {
  let options = parse_args_list(["https://example.com"])
  inspect(options.kitty, content="false")
  inspect(options.text, content="true")
  inspect(options.url, content="https://example.com")
}
