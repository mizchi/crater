///|
/// FileReader / File / Blob surface in the BiDi runtime realm (#180).
///
/// Node 22+ exposes Blob and File natively. FileReader doesn't exist
/// in Node — we install a shim that wraps Blob.text() / arrayBuffer()
/// and fires the standard load/loadend events. URL.createObjectURL /
/// URL.revokeObjectURL come from Node natively (the URL global itself
/// is already reserved).
///
/// Real upload UIs touch all of this:
///   `<input type='file'>` produces a File, the page calls
///   `new FileReader().readAsDataURL(file)` to preview it, or
///   `URL.createObjectURL(file)` for a blob: src on an img.
/// These tests pin the surface so the next refactor of the realm
/// sync can't strip any of it out.

///|
test "Blob and File constructors are reachable" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__b = String(typeof Blob); globalThis.__f = String(typeof File); globalThis.__fr = String(typeof FileReader);",
  )
  let b = read_global_string(proto, 3, "__b")
  assert_true(b.contains("\"function\""))
  let f = read_global_string(proto, 4, "__f")
  assert_true(f.contains("\"function\""))
  let fr = read_global_string(proto, 5, "__fr")
  assert_true(fr.contains("\"function\""))
}

///|
test "Blob exposes size and type from its constructor options" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "const b = new Blob(['hello world'], { type: 'text/plain' }); globalThis.__bSize = String(b.size); globalThis.__bType = String(b.type);",
  )
  let size = read_global_string(proto, 3, "__bSize")
  assert_true(size.contains("\"11\""))
  let ty = read_global_string(proto, 4, "__bType")
  assert_true(ty.contains("\"text/plain\""))
}

///|
async test "FileReader.readAsText fires load with the text contents" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__frResult = '<none>'; globalThis.__frEnd = '<none>'; const blob = new Blob(['mizchi'], { type: 'text/plain' }); const r = new FileReader(); r.onload = () => { globalThis.__frResult = String(r.result); }; r.onloadend = () => { globalThis.__frEnd = String(r.readyState); }; r.readAsText(blob);",
  )
  // FileReader fires load asynchronously (Blob.text() returns a Promise).
  @async.sleep(40)
  let result = read_global_string(proto, 3, "__frResult")
  assert_true(result.contains("\"mizchi\""))
  let end = read_global_string(proto, 4, "__frEnd")
  // FileReader.DONE === 2 — the loadend fires AFTER readyState is set.
  assert_true(end.contains("\"2\""))
}

///|
async test "FileReader.readAsDataURL produces a base64-encoded data URL" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__frUrl = '<none>'; const blob = new Blob(['hi'], { type: 'text/plain' }); const r = new FileReader(); r.onload = () => { globalThis.__frUrl = String(r.result); }; r.readAsDataURL(blob);",
  )
  @async.sleep(40)
  let resp = read_global_string(proto, 3, "__frUrl")
  // btoa('hi') = 'aGk=' — the data URL embeds it as base64 with the
  // blob's content-type prefix.
  assert_true(resp.contains("data:text/plain;base64,aGk="))
}

///|
async test "FileReader fires loadstart/load/loadend in order" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__frEvents = []; const blob = new Blob(['x'], { type: 'text/plain' }); const r = new FileReader(); r.addEventListener('loadstart', () => globalThis.__frEvents.push('s')); r.addEventListener('load', () => globalThis.__frEvents.push('l')); r.addEventListener('loadend', () => globalThis.__frEvents.push('e')); r.readAsText(blob);",
  )
  @async.sleep(40)
  run_sync_in_context(
    proto, 3, "globalThis.__frEventReport = (globalThis.__frEvents || []).join(',');",
  )
  let resp = read_global_string(proto, 4, "__frEventReport")
  // Spec order: loadstart -> load -> loadend.
  assert_true(resp.contains("\"s,l,e\""))
}

///|
test "URL.createObjectURL returns a blob: URL for a Blob argument" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "const b = new Blob(['x'], { type: 'text/plain' }); const url = URL.createObjectURL(b); globalThis.__objUrl = String(url); URL.revokeObjectURL(url);",
  )
  let resp = read_global_string(proto, 3, "__objUrl")
  // Spec: returned URL begins with `blob:` followed by an opaque token.
  assert_true(resp.contains("blob:"))
}
