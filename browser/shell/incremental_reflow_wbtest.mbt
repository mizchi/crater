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
