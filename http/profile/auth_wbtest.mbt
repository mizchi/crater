///|
test "AuthState::default has empty origin_headers" {
  let state = AuthState::default()
  inspect(state.origin_headers.length(), content="0")
}

///|
test "set_origin_header round-trips through header_for_origin" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer abc123")
  inspect(
    state.header_for_origin("https://api.example.com"),
    content="Some(Bearer abc123)",
  )
  inspect(state.header_for_origin("https://other.com"), content="None")
}

///|
test "set_origin_header overwrites prior value for same origin" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer first")
  state.set_origin_header("https://api.example.com", "Bearer second")
  inspect(
    state.header_for_origin("https://api.example.com"),
    content="Some(Bearer second)",
  )
}

///|
test "clear_origin_header removes the entry" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer abc")
  state.clear_origin_header("https://api.example.com")
  inspect(state.header_for_origin("https://api.example.com"), content="None")
}

///|
test "list_origins returns sorted origins" {
  let state = AuthState::default()
  state.set_origin_header("https://b.example.com", "Bearer b")
  state.set_origin_header("https://a.example.com", "Bearer a")
  state.set_origin_header("https://c.example.com", "Bearer c")
  let origins = state.list_origins()
  inspect(
    origins,
    content="[https://a.example.com, https://b.example.com, https://c.example.com]",
  )
}

///|
test "Show impl redacts header values" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer secret-token")
  let buf = StringBuilder::new()
  state.output(buf)
  let rendered = buf.to_string()
  inspect(rendered.contains("secret-token"), content="false")
  inspect(rendered.contains("<redacted>"), content="true")
  inspect(rendered.contains("https://api.example.com"), content="true")
}
