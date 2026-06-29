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
  full.set_incremental_reflow(false)
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
      "grid: template column count change",
      page("<div style=\"display:grid;grid-template-columns:1fr 1fr;width:300px\"><div style=\"height:30px\">a</div><div style=\"height:30px\">b</div><div style=\"height:30px\">c</div><div style=\"height:30px\">d</div></div>"),
      page("<div style=\"display:grid;grid-template-columns:1fr 1fr 1fr;width:300px\"><div style=\"height:30px\">a</div><div style=\"height:30px\">b</div><div style=\"height:30px\">c</div><div style=\"height:30px\">d</div></div>"),
    ),
    (
      "grid: cell height change",
      page("<div style=\"display:grid;grid-template-columns:1fr 1fr;width:300px\"><div style=\"height:30px\">a</div><div style=\"height:30px\">b</div><div style=\"height:30px\">c</div><div style=\"height:30px\">d</div></div>"),
      page("<div style=\"display:grid;grid-template-columns:1fr 1fr;width:300px\"><div style=\"height:30px\">a</div><div style=\"height:90px\">b</div><div style=\"height:30px\">c</div><div style=\"height:30px\">d</div></div>"),
    ),
    (
      "table: append a row",
      page("<table style=\"width:300px\"><tr><td>a1</td><td>a2</td></tr><tr><td>b1</td><td>b2</td></tr></table>"),
      page("<table style=\"width:300px\"><tr><td>a1</td><td>a2</td></tr><tr><td>b1</td><td>b2</td></tr><tr><td>c1</td><td>c2</td></tr></table>"),
    ),
    (
      "table: remove the first row",
      page("<table style=\"width:300px\"><tr><td>a1</td><td>a2</td></tr><tr><td>b1</td><td>b2</td></tr><tr><td>c1</td><td>c2</td></tr></table>"),
      page("<table style=\"width:300px\"><tr><td>b1</td><td>b2</td></tr><tr><td>c1</td><td>c2</td></tr></table>"),
    ),
    (
      "positioned: absolute child inset change",
      page("<div style=\"position:relative;width:300px;height:200px\"><div style=\"position:absolute;top:10px;left:10px;width:50px;height:50px\">x</div></div>"),
      page("<div style=\"position:relative;width:300px;height:200px\"><div style=\"position:absolute;top:80px;left:120px;width:50px;height:50px\">x</div></div>"),
    ),
    (
      "margin collapse: between siblings",
      page("<div style=\"width:200px\"><div style=\"height:20px;margin-bottom:10px\">a</div><div style=\"height:20px;margin-top:10px\">b</div></div>"),
      page("<div style=\"width:200px\"><div style=\"height:20px;margin-bottom:50px\">a</div><div style=\"height:20px;margin-top:10px\">b</div></div>"),
    ),
    (
      "flex wrap: item grows past wrap (line count change)",
      page("<div style=\"display:flex;flex-wrap:wrap;width:200px\"><div style=\"width:80px;height:30px\">a</div><div style=\"width:80px;height:30px\">b</div><div style=\"width:80px;height:30px\">c</div></div>"),
      page("<div style=\"display:flex;flex-wrap:wrap;width:200px\"><div style=\"width:160px;height:30px\">a</div><div style=\"width:80px;height:30px\">b</div><div style=\"width:80px;height:30px\">c</div></div>"),
    ),
    (
      "flex: direction row -> column",
      page("<div style=\"display:flex;flex-direction:row;width:300px;height:200px\"><div style=\"width:60px;height:40px\">a</div><div style=\"width:60px;height:40px\">b</div></div>"),
      page("<div style=\"display:flex;flex-direction:column;width:300px;height:200px\"><div style=\"width:60px;height:40px\">a</div><div style=\"width:60px;height:40px\">b</div></div>"),
    ),
    (
      "display: block container becomes flex",
      page("<div style=\"width:300px\"><div style=\"width:60px;height:40px\">a</div><div style=\"width:60px;height:40px\">b</div></div>"),
      page("<div style=\"display:flex;width:300px\"><div style=\"width:60px;height:40px\">a</div><div style=\"width:60px;height:40px\">b</div></div>"),
    ),
    (
      "display: none hides a sibling (following shifts up)",
      page("<div style=\"width:200px\"><div style=\"height:30px\">a</div><div style=\"height:30px\">b</div><div style=\"height:30px\">c</div></div>"),
      page("<div style=\"width:200px\"><div style=\"height:30px\">a</div><div style=\"display:none;height:30px\">b</div><div style=\"height:30px\">c</div></div>"),
    ),
    (
      "constraint: min-height kicks in",
      page("<div style=\"width:200px\"><div style=\"width:180px;height:20px;min-height:0\">a</div><div style=\"width:180px;height:20px\">b</div></div>"),
      page("<div style=\"width:200px\"><div style=\"width:180px;height:20px;min-height:80px\">a</div><div style=\"width:180px;height:20px\">b</div></div>"),
    ),
    (
      "box model: padding + border change",
      page("<div style=\"width:200px\"><div style=\"width:160px;height:30px;padding:4px;border:1px solid\">a</div><div style=\"width:160px;height:30px\">b</div></div>"),
      page("<div style=\"width:200px\"><div style=\"width:160px;height:30px;padding:20px;border:6px solid\">a</div><div style=\"width:160px;height:30px\">b</div></div>"),
    ),
    (
      "percentage: child width under widened parent",
      page("<div style=\"width:200px\"><div style=\"width:50%;height:30px\">a</div></div>"),
      page("<div style=\"width:360px\"><div style=\"width:50%;height:30px\">a</div></div>"),
    ),
    (
      "deep stack: change the LAST of many (memo reuse path)",
      page("<div style=\"width:200px\"><div style=\"height:20px\">1</div><div style=\"height:20px\">2</div><div style=\"height:20px\">3</div><div style=\"height:20px\">4</div><div style=\"height:20px\">5</div><div style=\"height:20px\">6</div><div style=\"height:20px\">7</div><div style=\"height:20px\">8</div></div>"),
      page("<div style=\"width:200px\"><div style=\"height:20px\">1</div><div style=\"height:20px\">2</div><div style=\"height:20px\">3</div><div style=\"height:20px\">4</div><div style=\"height:20px\">5</div><div style=\"height:20px\">6</div><div style=\"height:20px\">7</div><div style=\"height:70px\">8 grew</div></div>"),
    ),
    (
      "multiple simultaneous mutations across the tree",
      page("<div style=\"width:300px\"><div style=\"width:280px;height:30px\">head</div><div style=\"display:flex;width:280px\"><div style=\"width:80px;height:40px\">x</div><div style=\"width:80px;height:40px\">y</div></div><div style=\"width:280px;height:20px\">tail</div></div>"),
      page("<div style=\"width:300px\"><div style=\"width:280px;height:60px\">head taller</div><div style=\"display:flex;width:280px\"><div style=\"width:140px;height:40px\">x</div><div style=\"width:80px;height:70px\">y</div></div><div style=\"width:280px;height:20px\">tail</div></div>"),
    ),
    (
      "no-op: identical re-render",
      page("<div style=\"width:120px;height:40px\">a</div><div style=\"width:80px;height:60px\">b</div>"),
      page("<div style=\"width:120px;height:40px\">a</div><div style=\"width:80px;height:60px\">b</div>"),
    ),
  ]
}

///|
fn reflow_vrt_run(corpus : Array[(String, String, String)]) -> Array[String] {
  let failures : Array[String] = []
  for entry in corpus {
    let (name, before, after) = entry
    let (want, got) = reflow_vrt_render(before, after)
    if got != want {
      failures.push(name)
    }
  }
  failures
}

///|
test "reflow VRT: incremental geometry equals full rebuild across the corpus" {
  inspect(reflow_vrt_run(reflow_vrt_corpus()), content="[]")
}

///|
/// Real-world fixtures (example.com, Hacker News) + a synthetic DOM mutation,
/// generated by scripts/gen-reflow-vrt-fixtures.mjs. Exercises reconcile on real,
/// deep pages: incremental re-render geometry must equal a full rebuild.
test "reflow VRT: incremental geometry equals full rebuild across real-world fixtures" {
  inspect(reflow_vrt_run(reflow_vrt_fixture_corpus()), content="[]")
}
