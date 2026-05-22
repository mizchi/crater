///|
/// Verifies that `crater.setOriginCredentials` stores a username/password
/// pair on the per-session profile's AuthState under the requested origin.
test "crater.setOriginCredentials stores per-origin credentials" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\",\"username\":\"alice\",\"password\":\"wonderland\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  let profile = proto.profile_for_session("session-1").unwrap()
  let creds = profile
    .auth_state()
    .credentials_for_origin("https://api.example.com")
  inspect(creds is Some(_), content="true")
  match creds {
    Some(c) => {
      assert_eq(c.username(), "alice")
      assert_eq(c.password(), "wonderland")
    }
    None => assert_false(true)
  }
}

///|
/// Origin is normalized before storage: uppercase host lowercased,
/// default port stripped. Mirror of the equivalent Authorization test.
test "crater.setOriginCredentials normalizes origin" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://Example.COM:443\",\"username\":\"u\",\"password\":\"p\"}}",
  )
  ignore(proto.take_messages())
  let profile = proto.profile_for_session("session-1").unwrap()
  inspect(
    profile.auth_state().credentials_for_origin("https://example.com")
    is Some(_),
    content="true",
  )
  inspect(
    profile.auth_state().credentials_for_origin("https://Example.COM:443")
    is Some(_),
    content="false",
  )
}

///|
/// Missing username produces `invalid argument` with a message naming
/// the offending field.
test "crater.setOriginCredentials rejects missing username" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\",\"password\":\"p\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("username"))
}

///|
/// Missing password produces `invalid argument` with a message naming
/// the offending field.
test "crater.setOriginCredentials rejects missing password" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\",\"username\":\"u\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("password"))
}

///|
/// Control characters in credentials are rejected — same hardening as
/// the Authorization path, prevents header / log injection at use sites.
test "crater.setOriginCredentials rejects control characters in password" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\",\"username\":\"u\",\"password\":\"p\\nLog-Forge: evil\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("control"))
}

///|
/// `crater.clearOriginCredentials` removes a previously-stored entry.
test "crater.clearOriginCredentials removes the per-origin entry" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\",\"username\":\"u\",\"password\":\"p\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"crater.clearOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\"}}",
  )
  ignore(proto.take_messages())
  let profile = proto.profile_for_session("session-1").unwrap()
  inspect(
    profile.auth_state().credentials_for_origin("https://api.example.com")
    is Some(_),
    content="false",
  )
}

///|
/// `crater.listOriginCredentials` returns the registered origins WITHOUT
/// exposing any username/password. Defends against an attacker WebDriver
/// client (or a hijacked transport) introspecting the registered set.
test "crater.listOriginCredentials returns origins, never credentials" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginCredentials\",\"params\":{\"origin\":\"https://api.example.com\",\"username\":\"alice\",\"password\":\"wonderland\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"crater.listOriginCredentials\",\"params\":{}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("https://api.example.com"))
  // The username and password values must NOT appear in the response.
  assert_false(json.contains("alice"))
  assert_false(json.contains("wonderland"))
}

///|
/// AuthState Show impl redacts both stored headers AND stored credentials,
/// so panic stack traces / structural debug output never leak either.
test "AuthState Show redacts credentials" {
  let state = @browser_http.AuthState::default()
  state.set_origin_credentials("https://api.example.com", "alice", "wonderland")
  inspect(
    state,
    content=(
      #|AuthState{headers=[], credentials=[https://api.example.com: <redacted>]}
    ),
  )
}
