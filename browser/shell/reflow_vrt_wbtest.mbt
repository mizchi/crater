///|
/// Dynamic-reflow VRT harness: a corpus of (before, after) page states (the
/// "after" modelling a post-mutation DOM) is rendered two ways — incrementally
/// (flag on: render `before`, then reconcile to `after`) and by a full rebuild
/// of `after` — and their **layout box geometry** (`id:x,y,w,h` per box) must
/// match. This is the offline, browser-free equivalent of a paint VRT for the
/// dynamic path: equal geometry means equal paint. The real-browser / native-V8
/// round-trip is the on-device counterpart (`just test-native-full`); this runs
/// on the js target in CI with no V8.
///
/// Extend `reflow_vrt_corpus` with more (name, before, after) triples — ideally
/// derived from real-world fixtures — to widen coverage ahead of default-on.

///|
/// Render `after` incrementally (after a `before` baseline) and fully, and
/// compare the layout-box geometry. Returns the full-render geometry and the
/// incremental geometry so a caller can report the diff.
fn reflow_vrt_render(before : String, after : String) -> (String, String) {
  let full = Browser::new(800, 600)
  full.set_html_content(after)
  let want = full.layout_box_snapshot()
  let incr = Browser::new(800, 600)
  incr.set_incremental_reflow(true)
  incr.set_html_content(before)
  let _ = incr.layout_box_snapshot() // establish the reconcile baseline
  incr.set_html_content(after)
  incr.clear_render_cache()
  let got = incr.layout_box_snapshot()
  (want, got)
}

///|
/// The corpus. Each entry: (name, before, after). `after` is the post-mutation
/// state; the harness asserts incremental(after | before) geometry == full(after).
fn reflow_vrt_corpus() -> Array[(String, String, String)] {
  let page = fn(body : String) {
    "<html><body style=\"margin:0\">" + body + "</body></html>"
  }
  [
    (
      "list: append a row",
      page("<div style=\"width:300px\"><div style=\"width:280px;height:24px\">r1</div><div style=\"width:280px;height:24px\">r2</div></div>"),
      page("<div style=\"width:300px\"><div style=\"width:280px;height:24px\">r1</div><div style=\"width:280px;height:24px\">r2</div><div style=\"width:280px;height:24px\">r3</div></div>"),
    ),
    (
      "list: remove the middle row",
      page("<div style=\"width:300px\"><div style=\"width:280px;height:24px\">r1</div><div style=\"width:280px;height:24px\">r2</div><div style=\"width:280px;height:24px\">r3</div></div>"),
      page("<div style=\"width:300px\"><div style=\"width:280px;height:24px\">r1</div><div style=\"width:280px;height:24px\">r3</div></div>"),
    ),
    (
      "card: grow body height (shifts footer)",
      page("<div style=\"width:240px\"><div style=\"width:220px;height:30px\">title</div><div style=\"width:220px;height:60px\">body</div><div style=\"width:240px;height:20px\">footer</div></div>"),
      page("<div style=\"width:240px\"><div style=\"width:220px;height:30px\">title</div><div style=\"width:220px;height:160px\">body</div><div style=\"width:240px;height:20px\">footer</div></div>"),
    ),
    (
      "flex toolbar: item width change",
      page("<div style=\"display:flex;width:400px;height:40px\"><div style=\"width:100px;height:30px\">a</div><div style=\"width:100px;height:30px\">b</div><div style=\"width:100px;height:30px\">c</div></div>"),
      page("<div style=\"display:flex;width:400px;height:40px\"><div style=\"width:200px;height:30px\">a</div><div style=\"width:100px;height:30px\">b</div><div style=\"width:100px;height:30px\">c</div></div>"),
    ),
    (
      "text panel: re-wrap on width change",
      page("<div style=\"width:300px\">the quick brown fox jumps over the lazy dog again and again</div>"),
      page("<div style=\"width:120px\">the quick brown fox jumps over the lazy dog again and again</div>"),
    ),
    (
      "nested: insert deep, sibling shifts",
      page("<div style=\"width:260px\"><div style=\"width:240px;height:20px\">h</div><div style=\"width:240px\"><div style=\"width:220px;height:30px\">x</div></div><div style=\"width:260px;height:20px\">f</div></div>"),
      page("<div style=\"width:260px\"><div style=\"width:240px;height:20px\">h</div><div style=\"width:240px\"><div style=\"width:220px;height:30px\">x</div><div style=\"width:220px;height:44px\">y</div></div><div style=\"width:260px;height:20px\">f</div></div>"),
    ),
    (
      "no-op: identical re-render",
      page("<div style=\"width:120px;height:40px\">a</div><div style=\"width:80px;height:60px\">b</div>"),
      page("<div style=\"width:120px;height:40px\">a</div><div style=\"width:80px;height:60px\">b</div>"),
    ),
  ]
}

///|
test "reflow VRT: incremental geometry equals full rebuild across the corpus" {
  let failures : Array[String] = []
  for entry in reflow_vrt_corpus() {
    let (name, before, after) = entry
    let (want, got) = reflow_vrt_render(before, after)
    if got != want {
      failures.push(name)
    }
  }
  inspect(failures, content="[]")
}
