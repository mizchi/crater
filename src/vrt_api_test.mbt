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

///|
test "render_html_to_paint_tree_with_external_css applies public wrapper styles" {
  let html =
    #|<!DOCTYPE html>
    #|<p class="card">Hello external css</p>
  let paint_tree = render_html_to_paint_tree_with_external_css(
    html,
    @types.Size::new(240.0, 120.0),
    [
      "body { margin: 0; }", ".card { font-weight: 700; text-decoration: underline; }",
    ],
  )
  match find_text_node(paint_tree, "Hello external css") {
    Some(text_node) => {
      inspect(text_node.paint.is_bold, content="true")
      inspect(text_node.paint.text_decoration_underline, content="true")
    }
    None => fail("text node not found")
  }
}

///|
test "render_html_batch_variants exposes remove and override via public api" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.msg { font-weight: 700; text-decoration: underline; }
    #|</style>
    #|<p class="msg">Variant text</p>
  let results = render_html_batch_variants(
    html,
    @types.Size::new(240.0, 120.0),
    [
      { id: "baseline", mutations: [] },
      {
        id: "reset",
        mutations: [
          {
            selector: ".msg",
            property: "font-weight",
            action: CssMutationAction::Remove,
          },
          {
            selector: ".msg",
            property: "text-decoration",
            action: CssMutationAction::Remove,
          },
        ],
      },
      {
        id: "strike",
        mutations: [
          {
            selector: ".msg",
            property: "text-decoration",
            action: CssMutationAction::Override("line-through"),
          },
        ],
      },
    ],
  )
  assert_eq(results.length(), 3)

  match find_text_node(results[0].paint_tree, "Variant text") {
    Some(text_node) => {
      inspect(text_node.paint.is_bold, content="true")
      inspect(text_node.paint.text_decoration_underline, content="true")
      inspect(text_node.paint.text_decoration_line_through, content="false")
    }
    None => fail("baseline text node not found")
  }

  match find_text_node(results[1].paint_tree, "Variant text") {
    Some(text_node) => {
      inspect(text_node.paint.is_bold, content="false")
      inspect(text_node.paint.text_decoration_underline, content="false")
      inspect(text_node.paint.text_decoration_line_through, content="false")
    }
    None => fail("reset text node not found")
  }

  match find_text_node(results[2].paint_tree, "Variant text") {
    Some(text_node) => {
      inspect(text_node.paint.is_bold, content="true")
      inspect(text_node.paint.text_decoration_underline, content="false")
      inspect(text_node.paint.text_decoration_line_through, content="true")
    }
    None => fail("strike text node not found")
  }
}
