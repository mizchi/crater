///|
/// HTML → layout → AOM-with-bounds integration test.
///
/// Verifies that running the layout engine on a simple HTML snippet and
/// then building an accessibility tree against the layout produces
/// elements whose bounds are attached — which is what `crater-aomx`
/// `grounding` relies on for spatial queries.
///
/// Lives here (rather than under `aomx/grounding`) so that
/// `mizchi/crater-aomx` itself does not need a `crater-layout` dep.
test "grounding pipeline: layout produces AOM with bounds" {
  @layout.setup()
  let html =
    #|<div id="container" style="width:800px;height:600px">
    #|  <button id="btn-top-left" style="position:absolute;left:50px;top:50px;width:100px;height:40px">Top Left</button>
    #|  <button id="btn-center" style="position:absolute;left:350px;top:280px;width:100px;height:40px">Center</button>
    #|  <button id="btn-bottom-right" style="position:absolute;left:650px;top:510px;width:100px;height:40px">Bottom Right</button>
    #|</div>
  let doc = @html.assign_synthetic_ids(@html.parse_document(html))
  let layout_tree = @layout_html_tree.layout_tree_from_html_document(
    doc, 800.0, 600.0,
  )
  let _ = layout_tree.calculate_layout(800.0, 600.0)
  let tree = @aom.build_accessibility_tree_with_layout(doc, layout_tree)
  let interactive = @aom.find_interactive(tree)
  inspect(interactive.length(), content="3")
  let mut buttons_with_bounds = 0
  for node in interactive {
    if node.bounds is Some(_) {
      buttons_with_bounds += 1
    }
  }
  inspect(buttons_with_bounds, content="3")
}
