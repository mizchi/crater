///|
fn find_text_node(node : @paint.PaintNode, text : String) -> @paint.PaintNode? {
  match node.text {
    Some(content) => if content == text { return Some(node) }
    None => ()
  }
  for child in node.children {
    match find_text_node(child, text) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn has_change(
  diff : @paint.PaintTreeDiff,
  node_id : String,
  property : String,
) -> Bool {
  for change in diff.changes {
    if change.node_id == node_id && change.property == property {
      return true
    }
  }
  false
}

///|
test "render_html_to_paint_tree propagates font weight and text decoration" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.card {
    #|  color: #123456;
    #|  font-weight: 700;
    #|  text-decoration: underline line-through overline;
    #|}
    #|</style>
    #|<p class="card">Hello paint</p>
  let paint_tree = render_html_to_paint_tree(
    html,
    @types.Size::new(240.0, 120.0),
  )
  match find_text_node(paint_tree, "Hello paint") {
    Some(text_node) => {
      inspect(text_node.paint.is_bold, content="true")
      inspect(text_node.paint.text_decoration_underline, content="true")
      inspect(text_node.paint.text_decoration_line_through, content="true")
      inspect(text_node.paint.text_decoration_overline, content="true")
    }
    None => fail("text node not found")
  }
}

///|
test "diff_rendered_paint_trees reports layout and paint changes" {
  let baseline =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.card { padding: 20px; background: #eeeeee; }
    #|</style>
    #|<div class="card"><span>Callout</span></div>
  let current =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.card { padding: 0; background: #cccccc; }
    #|</style>
    #|<div class="card"><span>Callout</span></div>
  let diff = diff_rendered_paint_trees(
    baseline,
    current,
    @types.Size::new(240.0, 120.0),
  )
  inspect(has_change(diff, "div.card", "background_color"), content="true")
  inspect(diff.layout_shifts.length() > 0, content="true")
}
