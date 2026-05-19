///|
/// Playwright file chooser + download contract (#184).
///
/// The infrastructure for both flows IS wired today; this file pins the
/// end-to-end behavior so a refactor of the synthetic handlers can't
/// silently regress what Playwright integrations rely on.
///
/// Download flow:
///   1. Page clicks a download anchor (synthetic handler matches
///      `download_link.click()` / `content_disposition_link.click()` /
///      `redirect_link.click()`)
///   2. Crater emits `browsingContext.downloadWillBegin` with the
///      suggested filename + url
///   3. Crater writes the file to `/tmp/<filename>` and emits
///      `browsingContext.downloadEnd` with status="complete" and
///      filepath set
///
/// File chooser flow:
///   1. Page calls `window.showOpenFilePicker(...)` or activates a
///      `<input type="file">`
///   2. Crater emits `input.fileDialogOpened` with the multiple flag
///      and (when available) the element handle
///   3. BiDi client (Playwright) calls `input.setFiles({element, files})`
///      to drive the chooser
///
/// What's NOT covered here (Playwright adapter work, not Crater BiDi):
///   - The Playwright BiDi adapter wiring `page.on('filechooser', ...)`
///     subscription to the input.fileDialogOpened event
///   - The Playwright adapter exposing `download.saveAs(path)` over
///     `browsingContext.downloadEnd.filepath` (saveAs is a client-side
///     file copy from the emitted filepath; Crater already does the
///     write)

///|
fn dl_proto() -> BidiProtocol {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  proto
}

///|
fn dl_subscribe(
  proto : BidiProtocol,
  request_id : Int,
  event_name : String,
) -> Unit {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"session.subscribe\",\"params\":{\"events\":[\"" +
    event_name +
    "\"],\"contexts\":[\"session-1\"]}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
fn dl_eval(
  proto : BidiProtocol,
  request_id : Int,
  expr : String,
) -> Array[String] {
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let out : Array[String] = []
  for msg in proto.take_messages() {
    out.push(msg.to_json())
  }
  out
}

///|
fn dl_filter(messages : Array[String], event_name : String) -> Array[String] {
  let out : Array[String] = []
  for msg in messages {
    if msg.contains("\"method\":\"" + event_name + "\"") {
      out.push(msg)
    }
  }
  out
}

///|
test "click on a synthetic download anchor emits downloadWillBegin" {
  let proto = dl_proto()
  dl_subscribe(proto, 2, "browsingContext.downloadWillBegin")
  dl_subscribe(proto, 3, "browsingContext.downloadEnd")
  let _ = proto.take_messages()
  let messages = dl_eval(proto, 4, "download_link.click();")
  let will_begin = dl_filter(messages, "browsingContext.downloadWillBegin")
  assert_true(will_begin.length() >= 1)
  // The event carries a suggestedFilename and url field. We don't
  // assert specific values (the synthetic handler defaults to
  // download.txt when no `download` attribute is present) — just that
  // the fields are present in the payload.
  let payload = will_begin[0]
  assert_true(payload.contains("\"suggestedFilename\""))
  assert_true(payload.contains("\"url\""))
  assert_true(payload.contains("\"timestamp\""))
}

///|
test "synthetic download click also emits downloadEnd with a filepath" {
  let proto = dl_proto()
  dl_subscribe(proto, 2, "browsingContext.downloadEnd")
  let _ = proto.take_messages()
  let messages = dl_eval(proto, 3, "download_link.click();")
  let end_events = dl_filter(messages, "browsingContext.downloadEnd")
  assert_true(end_events.length() >= 1)
  let payload = end_events[0]
  // The synthetic handler writes the file to /tmp/<filename> and
  // includes the filepath in the event. Status is "complete" for an
  // un-cancelled download.
  assert_true(payload.contains("\"filepath\""))
  assert_true(payload.contains("\"status\":\"complete\""))
  assert_true(payload.contains("/tmp/"))
}

///|
test "showOpenFilePicker triggers input.fileDialogOpened" {
  let proto = dl_proto()
  dl_subscribe(proto, 2, "input.fileDialogOpened")
  let _ = proto.take_messages()
  // The multiple-flag detector matches against the LITERAL source
  // including a quoted `"multiple"` key — the synthetic handler
  // doesn't parse JS, it pattern-matches the expression string. Using
  // unquoted shorthand `{ multiple: true }` would fall through to
  // the default of `false`. Pin the quoted form here.
  let messages = dl_eval(
    proto, 3, "window.showOpenFilePicker({ \"multiple\": true });",
  )
  let opened = dl_filter(messages, "input.fileDialogOpened")
  assert_true(opened.length() >= 1)
  // The event carries the multiple flag — Playwright's filechooser
  // event uses this to expose `chooser.isMultiple()`.
  let payload = opened[0]
  assert_true(payload.contains("\"multiple\":true"))
}

///|
test "single-file showOpenFilePicker reports multiple=false" {
  let proto = dl_proto()
  dl_subscribe(proto, 2, "input.fileDialogOpened")
  let _ = proto.take_messages()
  let messages = dl_eval(proto, 3, "window.showOpenFilePicker({ });")
  let opened = dl_filter(messages, "input.fileDialogOpened")
  assert_true(opened.length() >= 1)
  let payload = opened[0]
  // Without a quoted `"multiple": true` marker, the handler defaults
  // to `false` — single-file picker semantics.
  assert_true(payload.contains("\"multiple\":false"))
}

///|
test "downloadWillBegin event is gated on subscription" {
  // Negative path: without a subscribe, the event must NOT be emitted.
  // Pins the per-context gate in `is_subscribed_for_context` — a
  // refactor that always pushed download events would flood
  // unsubscribed BiDi clients.
  let proto = dl_proto()
  let _ = proto.take_messages()
  let messages = dl_eval(proto, 2, "download_link.click();")
  let will_begin = dl_filter(messages, "browsingContext.downloadWillBegin")
  assert_eq(will_begin.length(), 0)
}
