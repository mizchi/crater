///|
test "AuthState::default is empty" {
  let state = AuthState::default()
  inspect(
    state,
    content=(
      #|AuthState{}
    ),
  )
}

///|
test "Profile::default has jar enabled and no UA override" {
  let p = Profile::default()
  inspect(p.user_agent, content="None")
  // Verify jar is enabled: store a cookie and check size > 0
  p.cookie_jar.store_from_header(
    "Set-Cookie: test=1; Path=/", "example.com", false,
  )
  inspect(p.cookie_jar.size() > 0, content="true")
}

///|
test "Profile::new(jar_enabled=false) yields disabled jar" {
  let p = Profile::new(jar_enabled=false)
  // Verify jar is disabled: store attempt is no-op, size stays 0
  p.cookie_jar.store_from_header(
    "Set-Cookie: test=1; Path=/", "example.com", false,
  )
  inspect(p.cookie_jar.size(), content="0")
}

///|
test "Profile::new(user_agent=Some(...)) is reflected" {
  let p = Profile::new(user_agent="UA/1.0")
  inspect(p.user_agent, content="Some(UA/1.0)")
}

///|
test "effective_user_agent returns set UA, else None-passthrough" {
  let with_ua = Profile::new(user_agent="UA/2.0")
  inspect(with_ua.effective_user_agent(), content="Some(UA/2.0)")
  let without = Profile::default()
  inspect(without.effective_user_agent(), content="None")
}
