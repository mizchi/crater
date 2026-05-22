///|
test "AuthState::default has empty origin_headers" {
  let state = AuthState::default()
  inspect(state.list_origins().length(), content="0")
  inspect(state.list_credential_origins().length(), content="0")
}

///|
test "set_origin_header round-trips through header_for_origin" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer abc123")
  match state.header_for_origin("https://api.example.com") {
    Some(header) => inspect(header, content="Bearer abc123")
    None => fail("expected origin header")
  }
  inspect(state.header_for_origin("https://other.com") is None, content="true")
}

///|
test "set_origin_header overwrites prior value for same origin" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer first")
  state.set_origin_header("https://api.example.com", "Bearer second")
  match state.header_for_origin("https://api.example.com") {
    Some(header) => inspect(header, content="Bearer second")
    None => fail("expected origin header")
  }
}

///|
test "clear_origin_header removes the entry" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer abc")
  state.clear_origin_header("https://api.example.com")
  inspect(
    state.header_for_origin("https://api.example.com") is None,
    content="true",
  )
}

///|
test "list_origins returns sorted origins" {
  let state = AuthState::default()
  state.set_origin_header("https://b.example.com", "Bearer b")
  state.set_origin_header("https://a.example.com", "Bearer a")
  state.set_origin_header("https://c.example.com", "Bearer c")
  let origins = state.list_origins()
  inspect(
    origins.join(", "),
    content="https://a.example.com, https://b.example.com, https://c.example.com",
  )
}

///|
test "AuthState cannot be debug-printed with secrets exposed" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer secret-token")
  // Verify the type does not have a Debug derive that would dump origin_headers verbatim.
  // The Show impl is the only way to render AuthState; it redacts.
  let buf = StringBuilder::new()
  state.output(buf)
  inspect(buf.to_string().contains("secret-token"), content="false")
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
