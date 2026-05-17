///|
/// CorsBlocked surfaces as BiDi errorText with the upstream reason embedded.
test "CorsBlocked maps to BiDi errorText with reason" {
  let text = error_text_of(@http.HttpError::CorsBlocked("missing ACA-Origin"))
  inspect(text, content="CORS: missing ACA-Origin")
}

///|
/// PreflightFailed surfaces as BiDi errorText with a distinct prefix so the
/// driver can distinguish the actual-request rejection from preflight.
test "PreflightFailed maps to BiDi errorText with preflight prefix" {
  let text = error_text_of(
    @http.HttpError::PreflightFailed("ACA-Methods missing PUT"),
  )
  inspect(text, content="CORS preflight: ACA-Methods missing PUT")
}

///|
/// The legacy variants must keep producing a sensible errorText so the new
/// arms don't break the fallthrough for existing fetch failures.
test "legacy HttpError variants still map to readable errorText" {
  inspect(
    error_text_of(@http.HttpError::NetworkError("DNS failure")),
    content="NetworkError: DNS failure",
  )
  inspect(
    error_text_of(@http.HttpError::InvalidUrl("not a url")),
    content="InvalidUrl: not a url",
  )
  inspect(error_text_of(@http.HttpError::TimeoutError), content="TimeoutError")
  inspect(
    error_text_of(@http.HttpError::CorsError("legacy reason")),
    content="CorsError: legacy reason",
  )
  inspect(
    error_text_of(@http.HttpError::SandboxError("blocked iframe")),
    content="SandboxError: blocked iframe",
  )
}

///|
/// The synthetic fetchError event builder must accept the mapped errorText so
/// driver clients see `"CORS: <reason>"` in the BiDi payload. This exercises
/// the end-to-end path: mapper output flows through
/// `build_synthetic_fetch_error_event_json` into the JSON wire format.
test "build_synthetic_fetch_error_event_json embeds mapped CORS errorText" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let mapped = error_text_of(@http.HttpError::CorsBlocked("origin mismatch"))
  let payload = "{\"id\":2,\"method\":\"network.buildFetchErrorEvent\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/x\",\"method\":\"GET\",\"requestId\":\"request-1\",\"requestHeaders\":[],\"errorText\":\"" +
    mapped +
    "\"}}"
  let _ = proto.process_message(payload)
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"errorText\":\"CORS: origin mismatch\""))
}
