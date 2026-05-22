///|
test "AuthState::default is empty" {
  let state = AuthState::default()
  inspect(
    state,
    content=(
      #|AuthState{headers=[], credentials=[]}
    ),
  )
}

///|
test "Profile::default has jar enabled" {
  let p = Profile::default()
  // Verify jar is enabled: store a cookie and check size > 0
  p
  .cookie_jar()
  .store_from_header("Set-Cookie: test=1; Path=/", "example.com", false)
  inspect(p.cookie_jar().size() > 0, content="true")
}

///|
test "Profile::new(jar_enabled=false) yields disabled jar" {
  let p = Profile::new(jar_enabled=false)
  // Verify jar is disabled: store attempt is no-op, size stays 0
  p
  .cookie_jar()
  .store_from_header("Set-Cookie: test=1; Path=/", "example.com", false)
  inspect(p.cookie_jar().size(), content="0")
}
