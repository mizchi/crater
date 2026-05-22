///|
/// Verifies that BiDi `emulation.setUserAgentOverride` (global form, no
/// `contexts` / `userContexts`) mirrors the override into the per-session
/// Profile that BidiEmulationState now carries alongside the legacy
/// `emulation_user_agent_global` field.
test "emulation_user_agent_global is mirrored on session profile user agent" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"UA/test\"}}",
  )
  ignore(proto.take_messages())
  let profile = proto.profile_for_session("session-1").unwrap()
  assert_true(profile.effective_user_agent() is Some("UA/test"))
}

///|
/// Clearing the global override (`userAgent: null`) clears the per-session
/// profile user-agent as well.
test "clearing global UA clears session profile user agent" {
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
  let profile = proto.profile_for_session("session-1").unwrap()
  assert_true(profile.effective_user_agent() is None)
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
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"UA/test\"}}",
  )
  ignore(proto.take_messages())
  // Confirm entry was created
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
/// `resolve_effective_user_agent` falls back to the profile user-agent when
/// the standalone `emulation_user_agent_global` field is None. This
/// exercises the fallback chain introduced in this task without going
/// through a setter that mutates both — useful as a guard for the
/// option (a) wiring.
test "resolve_effective_user_agent falls back to profile user agent when global is None" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  // Seed only the profile (not the legacy global) — emulates a future
  // caller that talks to the profile directly.
  let profile = proto.profile_for_session("session-1").unwrap()
  profile.set_user_agent("UA/profile-only")
  inspect(
    proto.resolve_effective_user_agent("session-1"),
    content="UA/profile-only",
  )
}
