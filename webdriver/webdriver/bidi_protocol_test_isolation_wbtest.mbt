///|
/// session.end on a context that previously called
/// script.rememberSyntheticLocationHref must clear the synthetic
/// window.location.href override so a subsequent session.new sees the
/// default about:blank baseline. PR #138's e2e investigation observed
/// that the rememberSyntheticLocationHref state was implicitly carried
/// over and masked bug.bidi.navigate-http-url-not-parsed (now fixed in
/// PR #139). This test pins the negative case: after session.end, the
/// override is gone.
test "bidi rememberSyntheticLocationHref does not leak across session.end" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://alice.example.com:8000/seed.html\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let pre_end_json = proto.take_messages()[0].to_json()
  assert_true(pre_end_json.contains("alice.example.com"))
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.end\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let post_end_json = proto.take_messages()[0].to_json()
  assert_false(post_end_json.contains("alice.example.com"))
}

///|
/// session.resetForTest is the explicit isolation hook used by Crater's
/// Playwright fixtures: after it, the synthetic location override must
/// be gone even within the same logical session, so a follow-up
/// browsingContext.navigate sees the default base URL rather than the
/// leaked override.
test "bidi rememberSyntheticLocationHref is cleared by session.resetForTest" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://bob.example.com:8000/seed.html\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.resetForTest\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let post_reset_json = proto.take_messages()[0].to_json()
  assert_false(post_reset_json.contains("bob.example.com"))
}

///|
/// Two independent BidiProtocol::new() instances must not share any
/// per-context state. PR #138 observed that an e2e test process keeps
/// one BidiProtocol alive across tests, so the contract verified here
/// (a fresh BidiProtocol observes none of a sibling protocol's
/// per-context overrides) is what the Playwright fixture relies on
/// when it reuses session.new + session.end as the isolation boundary.
test "bidi independent BidiProtocol instances do not share synthetic location state" {
  let proto_a = BidiProtocol::new()
  let _ = proto_a.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto_a.take_messages()
  let _ = proto_a.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://carol.example.com:8000/seed.html\"}}",
  )
  let _ = proto_a.take_messages()
  let proto_b = BidiProtocol::new()
  let _ = proto_b.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto_b.take_messages()
  let _ = proto_b.process_message(
    "{\"id\":2,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let proto_b_json = proto_b.take_messages()[0].to_json()
  assert_false(proto_b_json.contains("carol.example.com"))
}
