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
  baseline.set_incremental_reflow(false)
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
  full.set_incremental_reflow(false)
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
test "incremental reflow: a flex-item mutation matches a full rebuild" {
  let mk = fn(w : String) {
    "<html><body style=\"margin:0\">" +
    "<div style=\"display:flex;width:300px;height:50px\">" +
    "<div style=\"width:" +
    w +
    ";height:40px\">a</div>" +
    "<div style=\"width:80px;height:40px\">b</div>" +
    "<div style=\"width:60px;height:40px\">c</div>" +
    "</div></body></html>"
  }
  inspect(incremental_mutation_matches_full(mk("60px"), mk("120px")), content="true")
}

///|
test "incremental reflow: a deep nested mutation matches a full rebuild" {
  let mk = fn(h : String) {
    "<html><body style=\"margin:0\">" +
    "<div style=\"width:200px\">" +
    "<div style=\"width:180px;height:30px\">head</div>" +
    "<div style=\"width:180px\">" +
    "<div style=\"width:160px;height:" +
    h +
    "\">deep</div>" +
    "</div></div>" +
    "<div style=\"width:200px;height:25px\">footer</div></body></html>"
  }
  inspect(incremental_mutation_matches_full(mk("40px"), mk("90px")), content="true")
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
/// Broad equivalence sweep across layout modes and mutation kinds: each (v1, v2)
/// pair must render byte-identically whether reached incrementally (flag on,
/// v1 then v2) or by a full rebuild of v2. This is the confidence base for
/// considering the flag default-on; native-V8 round-trip validation is the
/// remaining real-environment sign-off.
test "incremental reflow: broad equivalence sweep (layout modes x mutations)" {
  let cases : Array[(String, String, String)] = [
    // (name, v1, v2)
    (
      "block: resize middle (shifts following)",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:100px;height:30px\">a</div><div style=\"width:100px;height:30px\">b</div><div style=\"width:100px;height:30px\">c</div></div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:100px;height:30px\">a</div><div style=\"width:100px;height:80px\">b</div><div style=\"width:100px;height:30px\">c</div></div></body></html>",
    ),
    (
      "flex column: wrap toggle",
      "<html><body style=\"margin:0\"><div style=\"display:flex;flex-direction:column;width:200px;height:300px\"><div style=\"width:80px;height:40px\">a</div><div style=\"width:80px;height:40px\">b</div></div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"display:flex;flex-direction:row;width:200px;height:300px\"><div style=\"width:80px;height:40px\">a</div><div style=\"width:80px;height:40px\">b</div></div></body></html>",
    ),
    (
      "flex wrap: item width grows past wrap",
      "<html><body style=\"margin:0\"><div style=\"display:flex;flex-wrap:wrap;width:200px\"><div style=\"width:80px;height:30px\">a</div><div style=\"width:80px;height:30px\">b</div><div style=\"width:80px;height:30px\">c</div></div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"display:flex;flex-wrap:wrap;width:200px\"><div style=\"width:150px;height:30px\">a</div><div style=\"width:80px;height:30px\">b</div><div style=\"width:80px;height:30px\">c</div></div></body></html>",
    ),
    (
      "text: wrapping width change",
      "<html><body style=\"margin:0\"><div style=\"width:200px\">the quick brown fox jumps over the lazy dog</div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"width:90px\">the quick brown fox jumps over the lazy dog</div></body></html>",
    ),
    (
      "margins: collapse change",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:100px;height:20px;margin-bottom:10px\">a</div><div style=\"width:100px;height:20px;margin-top:10px\">b</div></div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:100px;height:20px;margin-bottom:40px\">a</div><div style=\"width:100px;height:20px;margin-top:10px\">b</div></div></body></html>",
    ),
    (
      "nested: deep insert + sibling shift",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:180px;height:20px\">h</div><div style=\"width:180px\"><div style=\"width:160px;height:30px\">x</div></div><div style=\"width:200px;height:20px\">f</div></div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:180px;height:20px\">h</div><div style=\"width:180px\"><div style=\"width:160px;height:30px\">x</div><div style=\"width:160px;height:50px\">y</div></div><div style=\"width:200px;height:20px\">f</div></div></body></html>",
    ),
    (
      "multiple simultaneous mutations",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:100px;height:30px\">a</div><div style=\"width:100px;height:30px\">b</div><div style=\"width:100px;height:30px\">c</div></div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"width:200px\"><div style=\"width:140px;height:30px\">a</div><div style=\"width:100px;height:70px\">b</div><div style=\"width:60px;height:30px\">c changed</div></div></body></html>",
    ),
    (
      "no-op re-render (identical)",
      "<html><body style=\"margin:0\"><div style=\"width:120px;height:40px\">a</div><div style=\"width:80px;height:60px\">b</div></body></html>",
      "<html><body style=\"margin:0\"><div style=\"width:120px;height:40px\">a</div><div style=\"width:80px;height:60px\">b</div></body></html>",
    ),
  ]
  let failures : Array[String] = []
  for c in cases {
    let (name, v1, v2) = c
    if !incremental_mutation_matches_full(v1, v2) {
      failures.push(name)
    }
  }
  inspect(failures, content="[]")
}

///|
/// The seed must be *tight*: only the persisted uids whose layout inputs
/// actually changed, so the block-flow / per-uid memoization can reuse the rest.
/// A layout change seeds exactly that node; a paint-only change seeds nothing
/// (the precondition for the dynamic-path speedup, and a regression guard against
/// the seed silently collapsing back to "all uids").
fn seed_box(uid : Int, w : Double, h : Double) -> @node.Node {
  let style = @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(w),
    height: @types.Length(h),
  }
  @node.Node::with_uid("b" + uid.to_string(), uid, style, [])
}

///|
fn seed_box_colored(uid : Int, w : Double, h : Double) -> @node.Node {
  let style = @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(w),
    height: @types.Length(h),
    color: @types.Color::{ r: 255, g: 0, b: 0, a: 1.0 },
  }
  @node.Node::with_uid("b" + uid.to_string(), uid, style, [])
}

///|
fn seed_uids_for(prev : @node.Node, next : @node.Node) -> Array[Int] {
  let by_uid : Map[Int, @node.Node] = {}
  index_nodes_by_uid(prev, by_uid)
  let seeds : Array[Int] = []
  collect_changed_seed_uids(next, by_uid, seeds)
  seeds
}

///|
test "incremental reflow seed: a layout change seeds exactly the changed node" {
  let prev = @node.Node::with_uid("root", 0, @style.Style::default(), [
    seed_box(1, 100.0, 40.0),
    seed_box(2, 80.0, 60.0),
  ])
  // Widen #1 only.
  let next = @node.Node::with_uid("root", 0, @style.Style::default(), [
    seed_box(1, 150.0, 40.0),
    seed_box(2, 80.0, 60.0),
  ])
  inspect(seed_uids_for(prev, next), content="[1]")
}

///|
test "incremental reflow seed: a paint-only change seeds nothing (layout_eq holds)" {
  let prev = @node.Node::with_uid("root", 0, @style.Style::default(), [
    seed_box(1, 100.0, 40.0),
    seed_box(2, 80.0, 60.0),
  ])
  // Only #1's color changes — layout_eq ignores it.
  let next = @node.Node::with_uid("root", 0, @style.Style::default(), [
    seed_box_colored(1, 100.0, 40.0),
    seed_box(2, 80.0, 60.0),
  ])
  inspect(seed_uids_for(prev, next), content="[]")
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
