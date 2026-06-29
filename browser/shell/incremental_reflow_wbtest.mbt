///|
/// Incremental reflow must not change what is rendered: with the flag on, a
/// re-render that rebuilds the node tree reconciles against the prior layout
/// tree, and the output must match a plain full-rebuild render.

///|
test "incremental reflow flag preserves the rendered output" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:120px;height:40px">a</div>
    #|<div style="width:80px;height:60px">b</div>
    #|</body></html>
  // Baseline: flag off (full rebuild every time).
  let baseline = Browser::new(400, 300)
  baseline.set_html_content(html)
  let want = baseline.render_text_full_page()

  // Flag on: render once (prev = None -> from_node, records baseline tree), then
  // force a rebuild and render again so the second render reconciles against the
  // recorded tree.
  let incremental = Browser::new(400, 300)
  incremental.set_incremental_reflow(true)
  incremental.set_html_content(html)
  let _ = incremental.render_text_full_page()
  incremental.clear_render_cache()
  let got = incremental.render_text_full_page()
  inspect(got == want, content="true")
}

///|
/// Render `v2` with the incremental flag on, after first rendering `v1` (so the
/// second render reconciles `v2` against the `v1` baseline with a tight,
/// `layout_eq`-derived dirty seed), and assert it byte-matches a from-scratch
/// full render of `v2`. This is the on-vs-off equivalence per mutation kind.
fn incremental_mutation_matches_full(v1 : String, v2 : String) -> Bool {
  let full = Browser::new(400, 300)
  full.set_html_content(v2)
  let want = full.render_text_full_page()
  let incr = Browser::new(400, 300)
  incr.set_incremental_reflow(true)
  incr.set_html_content(v1)
  let _ = incr.render_text_full_page()
  incr.set_html_content(v2)
  incr.clear_render_cache()
  let got = incr.render_text_full_page()
  got == want
}

///|
test "incremental reflow: a text mutation matches a full rebuild" {
  let mk = fn(t : String) {
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px\">a</div>" +
    "<div style=\"width:80px;height:60px\">" +
    t +
    "</div></body></html>"
  }
  inspect(incremental_mutation_matches_full(mk("b"), mk("bbbbb changed")), content="true")
}

///|
test "incremental reflow: a size mutation matches a full rebuild" {
  let mk = fn(h : String) {
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px\">a</div>" +
    "<div style=\"width:80px;height:" +
    h +
    "\">b</div>" +
    "<div style=\"width:60px;height:20px\">c</div></body></html>"
  }
  inspect(incremental_mutation_matches_full(mk("60px"), mk("120px")), content="true")
}

///|
test "incremental reflow: a paint-only mutation matches a full rebuild" {
  let mk = fn(c : String) {
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px;color:" +
    c +
    "\">a</div>" +
    "<div style=\"width:80px;height:60px\">b</div></body></html>"
  }
  // color is paint-only: layout_eq holds, so the node stays clean — and the
  // rendered layout still matches a full rebuild.
  inspect(incremental_mutation_matches_full(mk("red"), mk("blue")), content="true")
}

///|
test "incremental reflow: appending a child matches a full rebuild" {
  let v1 =
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px\">a</div></body></html>"
  let v2 =
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px\">a</div>" +
    "<div style=\"width:80px;height:60px\">b</div></body></html>"
  inspect(incremental_mutation_matches_full(v1, v2), content="true")
}

///|
test "incremental reflow: removing a child matches a full rebuild" {
  let v1 =
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px\">a</div>" +
    "<div style=\"width:80px;height:60px\">b</div></body></html>"
  let v2 =
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:120px;height:40px\">a</div></body></html>"
  inspect(incremental_mutation_matches_full(v1, v2), content="true")
}
