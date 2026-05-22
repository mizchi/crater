///|
/// BiDi `emulation.setUserAgentOverride` resolves through emulation state,
/// not through the per-session HTTP Profile.
test "global user agent override is resolved from emulation state" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"UA/test\"}}",
  )
  ignore(proto.take_messages())
  inspect(proto.resolve_effective_user_agent("session-1"), content="UA/test")
}

///|
/// Clearing the global override (`userAgent: null`) returns to the runtime
/// default.
test "clearing global UA returns runtime default" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"UA/test\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":null}}",
  )
  ignore(proto.take_messages())
  assert_true(
    proto.resolve_effective_user_agent("session-1") ==
    @browser_domain.default_runtime_user_agent(),
  )
}

///|
/// After browsingContext.close the session_profiles entry must be removed.
/// Regression test for the lifecycle gap flagged after Task 5.
test "session_profiles entry is removed on browsingContext.close" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.profile_for_session("session-1").unwrap()
  assert_true(
    proto.emulation_state.session_profiles.get("session-1") is Some(_),
  )
  // Close the context
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.close\",\"params\":{\"context\":\"session-1\"}}",
  )
  ignore(proto.take_messages())
  // Entry must have been removed
  assert_true(proto.emulation_state.session_profiles.get("session-1") is None)
}

///|
/// A session Profile carries HTTP security state only. Its presence must not
/// affect user-agent resolution.
test "resolve_effective_user_agent ignores session profile state" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.profile_for_session("session-1").unwrap()
  assert_true(
    proto.resolve_effective_user_agent("session-1") ==
    @browser_domain.default_runtime_user_agent(),
  )
}
