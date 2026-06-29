///|
/// Incremental reflow must not change what is rendered: with the flag on, a
/// re-render that rebuilds the node tree reconciles against the prior layout
/// tree, and the output must match a plain full-rebuild render.

///|
test "incremental reflow flag preserves the dynamic rendered output" {
  let html =
    #|<html><body style="margin:0">
    #|<div style="width:120px;height:40px">a</div>
    #|<div style="width:80px;height:60px">b</div>
    #|</body></html>
  // Baseline: flag off (full rebuild every time).
  let baseline = Browser::new(400, 300)
  baseline.set_html_content(html)
  let want = baseline.render_text()

  // Flag on: render once (prev = None -> from_node, records baseline tree), then
  // force a rebuild and render again so the second render reconciles against the
  // recorded tree.
  let incremental = Browser::new(400, 300)
  incremental.set_incremental_reflow(true)
  incremental.set_html_content(html)
  let _ = incremental.render_text()
  incremental.clear_render_cache()
  let got = incremental.render_text()
  inspect(got == want, content="true")
}

///|
fn render_after_html_swap(
  first : String,
  second : String,
  incremental : Bool,
) -> String {
  let browser = Browser::new(400, 300)
  browser.set_incremental_reflow(incremental)
  browser.set_html_content(first)
  let _ = browser.render_text()
  browser.set_html_content(second)
  browser.render_text()
}

///|
fn incremental_swap_matches_full(first : String, second : String) -> Bool {
  render_after_html_swap(first, second, false) ==
  render_after_html_swap(first, second, true)
}

///|
test "incremental reflow equals full rebuild across common mutations" {
  let text1 =
    #|<html><body style="margin:0"><p>alpha</p></body></html>
  let text2 =
    #|<html><body style="margin:0"><p>beta</p></body></html>
  inspect(incremental_swap_matches_full(text1, text2), content="true")

  let size1 =
    #|<html><body style="margin:0"><div style="width:80px;height:20px">box</div><div>tail</div></body></html>
  let size2 =
    #|<html><body style="margin:0"><div style="width:160px;height:20px">box</div><div>tail</div></body></html>
  inspect(incremental_swap_matches_full(size1, size2), content="true")

  let display1 =
    #|<html><body style="margin:0"><div style="display:block">shown</div><div>tail</div></body></html>
  let display2 =
    #|<html><body style="margin:0"><div style="display:none">shown</div><div>tail</div></body></html>
  inspect(incremental_swap_matches_full(display1, display2), content="true")

  let append1 =
    #|<html><body style="margin:0"><div>a</div></body></html>
  let append2 =
    #|<html><body style="margin:0"><div>a</div><div>b</div></body></html>
  inspect(incremental_swap_matches_full(append1, append2), content="true")

  let remove1 =
    #|<html><body style="margin:0"><div>a</div><div>b</div></body></html>
  let remove2 =
    #|<html><body style="margin:0"><div>a</div></body></html>
  inspect(incremental_swap_matches_full(remove1, remove2), content="true")

  let move1 =
    #|<html><body style="margin:0"><div>a</div><div>b</div></body></html>
  let move2 =
    #|<html><body style="margin:0"><div>b</div><div>a</div></body></html>
  inspect(incremental_swap_matches_full(move1, move2), content="true")
}

///|
fn seed_box_style(w : Double, h : Double) -> @style.Style {
  @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(w),
    height: @types.Length(h),
  }
}

///|
fn seed_node(
  uid : Int,
  style : @style.Style,
  children : Array[@node.Node],
) -> @node.Node {
  @node.Node::with_uid("n" + uid.to_string(), uid, style, children)
}

///|
fn seed_tree(child : @node.Node) -> @layout.LayoutTree {
  let root = seed_node(1, seed_box_style(200.0, 200.0), [child])
  @layout.LayoutTree::from_node(root, 200.0, 200.0)
}

///|
fn seed_has_uid(uids : Array[Int], uid : Int) -> Bool {
  for item in uids {
    if item == uid {
      return true
    }
  }
  false
}

///|
fn seed_measure() -> @layout_types.MeasureFunc {
  {
    func: fn(_w : Double, _h : Double) -> @layout_types.IntrinsicSize {
      { min_width: 10.0, max_width: 10.0, min_height: 10.0, max_height: 10.0 }
    },
  }
}

///|
test "changed_seed_uids tracks layout-relevant changes only" {
  let base_child = seed_node(2, seed_box_style(100.0, 50.0), [])
  let prev = seed_tree(base_child)

  let layout_child = seed_node(2, seed_box_style(120.0, 50.0), [])
  let layout_seeds = changed_seed_uids(
    seed_node(1, seed_box_style(200.0, 200.0), [layout_child]),
    prev,
  )
  inspect(seed_has_uid(layout_seeds, 2), content="true")

  let paint_child = seed_node(2, {
    ..seed_box_style(100.0, 50.0),
    opacity: 0.5,
  }, [])
  let paint_seeds = changed_seed_uids(
    seed_node(1, seed_box_style(200.0, 200.0), [paint_child]),
    prev,
  )
  inspect(seed_has_uid(paint_seeds, 2), content="false")
}

///|
test "changed_seed_uids tracks text src and measure presence changes" {
  let base_child = @node.Node::with_uid_and_measure(
    "n2",
    2,
    seed_box_style(100.0, 50.0),
    [],
    Some(seed_measure()),
    Some("a"),
    src=Some("a.png"),
  )
  let prev = seed_tree(base_child)

  let same_child = @node.Node::with_uid_and_measure(
    "n2",
    2,
    seed_box_style(100.0, 50.0),
    [],
    Some(seed_measure()),
    Some("a"),
    src=Some("a.png"),
  )
  let same_seeds = changed_seed_uids(
    seed_node(1, seed_box_style(200.0, 200.0), [same_child]),
    prev,
  )
  inspect(seed_has_uid(same_seeds, 2), content="false")

  let text_child = @node.Node::with_uid_and_measure(
    "n2",
    2,
    seed_box_style(100.0, 50.0),
    [],
    Some(seed_measure()),
    Some("b"),
    src=Some("a.png"),
  )
  let text_seeds = changed_seed_uids(
    seed_node(1, seed_box_style(200.0, 200.0), [text_child]),
    prev,
  )
  inspect(seed_has_uid(text_seeds, 2), content="true")

  let src_child = @node.Node::with_uid_and_measure(
    "n2",
    2,
    seed_box_style(100.0, 50.0),
    [],
    Some(seed_measure()),
    Some("a"),
    src=Some("b.png"),
  )
  let src_seeds = changed_seed_uids(
    seed_node(1, seed_box_style(200.0, 200.0), [src_child]),
    prev,
  )
  inspect(seed_has_uid(src_seeds, 2), content="true")

  let measure_child = @node.Node::with_uid_and_measure(
    "n2",
    2,
    seed_box_style(100.0, 50.0),
    [],
    None,
    Some("a"),
    src=Some("a.png"),
  )
  let measure_seeds = changed_seed_uids(
    seed_node(1, seed_box_style(200.0, 200.0), [measure_child]),
    prev,
  )
  inspect(seed_has_uid(measure_seeds, 2), content="true")
}
