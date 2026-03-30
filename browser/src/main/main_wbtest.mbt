///|

///|
fn output_mode_name(mode : @shell.OutputMode) -> String {
  match mode {
    @shell.OutputMode::Sixel => "Sixel"
    @shell.OutputMode::Kitty => "Kitty"
    @shell.OutputMode::Text => "Text"
    @shell.OutputMode::Json => "Json"
    @shell.OutputMode::Aom => "Aom"
    @shell.OutputMode::Arc90 => "Arc90"
    @shell.OutputMode::ExtractMain => "ExtractMain"
    @shell.OutputMode::Grounding => "Grounding"
  }
}

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

///|
test "resolve_requested_output_mode keeps kitty when supported" {
  let options = parse_args_list(["--kitty", "https://example.com"])
  let support = { kitty: true, sixel: true }
  inspect(
    output_mode_name(resolve_requested_output_mode(options, support)),
    content="Kitty",
  )
}

///|
test "resolve_requested_output_mode falls back from kitty to sixel" {
  let options = parse_args_list(["--kitty", "https://example.com"])
  let support = { kitty: false, sixel: true }
  inspect(
    output_mode_name(resolve_requested_output_mode(options, support)),
    content="Sixel",
  )
}

///|
test "resolve_requested_output_mode falls back from kitty to text when no graphics are supported" {
  let options = parse_args_list(["--kitty", "https://example.com"])
  let support = { kitty: false, sixel: false }
  inspect(
    output_mode_name(resolve_requested_output_mode(options, support)),
    content="Text",
  )
}

///|
test "detect_terminal_graphics_support recognizes kitty envs" {
  let env : Map[String, String] = {}
  env["KITTY_WINDOW_ID"] = "1"
  env["TERM"] = "xterm-kitty"
  let support = detect_terminal_graphics_support_from_env(env)
  inspect(support.kitty, content="true")
  inspect(support.sixel, content="false")
}

///|
test "detect_terminal_graphics_support recognizes sixel envs" {
  let env : Map[String, String] = {}
  env["TERM"] = "xterm-sixel"
  let support = detect_terminal_graphics_support_from_env(env)
  inspect(support.kitty, content="false")
  inspect(support.sixel, content="true")
}
