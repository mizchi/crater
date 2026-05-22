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
test "Profile::default has jar enabled and no UA override" {
  let p = Profile::default()
  inspect(p.effective_user_agent() is None, content="true")
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

///|
test "Profile::new(user_agent=Some(...)) is reflected" {
  let p = Profile::new(user_agent="UA/1.0")
  match p.effective_user_agent() {
    Some(user_agent) => inspect(user_agent, content="UA/1.0")
    None => fail("expected UA override")
  }
}

///|
test "effective_user_agent returns set UA, else None-passthrough" {
  let with_ua = Profile::new(user_agent="UA/2.0")
  match with_ua.effective_user_agent() {
    Some(user_agent) => inspect(user_agent, content="UA/2.0")
    None => fail("expected effective UA")
  }
  let without = Profile::default()
  inspect(without.effective_user_agent() is None, content="true")
}
