///|
test "renderer facade renders paint tree json" {
  let html =
    #|<!DOCTYPE html><body><div style="width: 100px; height: 50px;">hello</div></body>
  let json = render_html_to_paint_tree_json(
    html,
    @types.Size::new(320.0, 200.0),
  )
  assert_true(json.contains("\"id\":\"div\""))
}

///|
test "renderer facade renders batch variants" {
  let html =
    #|<html><body><div class="box" style="width: 100px; height: 50px; background: red;">hello</div></body></html>
  let viewport = @types.Size::new(800.0, 600.0)
  let variants : Array[RenderVariant] = [
    { id: "baseline", mutations: [] },
    {
      id: "wider",
      mutations: [
        {
          selector: ".box",
          property: "width",
          action: CssMutationAction::Override("200px"),
        },
      ],
    },
  ]
  let results = render_html_batch_variants(html, viewport, variants)
  assert_eq(results.length(), 2)
  assert_eq(results[0].id, "baseline")
  assert_eq(results[1].id, "wider")
}

///|
fn find_text_node(
  node : @paint_model.PaintNode,
  text : String,
) -> @paint_model.PaintNode? {
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
  diff : @paint_diff.PaintTreeDiff,
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
test "renderer facade propagates font weight and text decoration" {
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
test "renderer facade exposes text input value and placeholder to paint tree" {
  let placeholder_html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; } input { font: 14px Arial; }</style>
    #|<input id="placeholder" type="email" placeholder="you@example.com">
  let placeholder_tree = render_html_to_paint_tree(
    placeholder_html,
    @types.Size::new(320.0, 120.0),
  )
  match find_text_node(placeholder_tree, "you@example.com") {
    Some(text_node) => {
      inspect(text_node.paint.color.r, content="117")
      inspect(text_node.paint.color.g, content="117")
      inspect(text_node.paint.color.b, content="117")
    }
    None => fail("placeholder text not found")
  }
  let value_html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; } input { font: 14px Arial; }</style>
    #|<input id="value" type="text" value="Ada">
  let value_tree = render_html_to_paint_tree(
    value_html,
    @types.Size::new(320.0, 120.0),
  )
  match find_text_node(value_tree, "Ada") {
    Some(_) => ()
    None => fail("input value text not found")
  }
}

///|
test "renderer facade reports layout and paint changes" {
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
test "renderer facade applies external css" {
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
test "renderer facade applies semantic inline defaults" {
  let html =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div><b>Bold</b></div>
    #|<div><strong>Strong</strong></div>
    #|<div><a href="#">Link</a></div>
    #|<div><u>Underline</u></div>
    #|<div><s>Strike</s></div>
  let paint_tree = render_html_to_paint_tree(
    html,
    @types.Size::new(320.0, 160.0),
  )
  match find_text_node(paint_tree, "Bold") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="true")
    None => fail("bold text node not found")
  }
  match find_text_node(paint_tree, "Strong") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="true")
    None => fail("strong text node not found")
  }
  match find_text_node(paint_tree, "Link") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="true")
    None => fail("link text node not found")
  }
  match find_text_node(paint_tree, "Underline") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="true")
    None => fail("underline text node not found")
  }
  match find_text_node(paint_tree, "Strike") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_line_through, content="true")
    None => fail("strike text node not found")
  }
}

///|
test "renderer facade preserves nested inline link paint color" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.title { color: #828282; }
    #|a:link { color: #000000; text-decoration: none; }
    #|</style>
    #|<span class="title"><span class="titleline"><a href="#">Black title</a><span> gray site</span></span></span>
  let paint_tree = render_html_to_paint_tree(
    html,
    @types.Size::new(320.0, 80.0),
  )
  match find_text_node(paint_tree, "Black title") {
    Some(text_node) => {
      inspect(text_node.paint.color.r, content="0")
      inspect(text_node.paint.color.g, content="0")
      inspect(text_node.paint.color.b, content="0")
    }
    None => fail("nested link text node not found")
  }
  match find_text_node(paint_tree, " gray site") {
    Some(text_node) => {
      inspect(text_node.paint.color.r, content="130")
      inspect(text_node.paint.color.g, content="130")
      inspect(text_node.paint.color.b, content="130")
    }
    None => fail("sibling inline text node not found")
  }
}

///|
test "renderer facade lets author styles override semantic defaults" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|b.plain,
    #|strong.plain { font-weight: 400; }
    #|a.reset,
    #|u.reset,
    #|s.reset { text-decoration: none; }
    #|</style>
    #|<div><b class="plain">BoldReset</b></div>
    #|<div><strong class="plain">StrongReset</strong></div>
    #|<div><a href="#" class="reset">LinkReset</a></div>
    #|<div><u class="reset">UnderlineReset</u></div>
    #|<div><s class="reset">StrikeReset</s></div>
  let paint_tree = render_html_to_paint_tree(
    html,
    @types.Size::new(360.0, 160.0),
  )
  match find_text_node(paint_tree, "BoldReset") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="false")
    None => fail("bold reset text node not found")
  }
  match find_text_node(paint_tree, "StrongReset") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="false")
    None => fail("strong reset text node not found")
  }
  match find_text_node(paint_tree, "LinkReset") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="false")
    None => fail("link reset text node not found")
  }
  match find_text_node(paint_tree, "UnderlineReset") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="false")
    None => fail("underline reset text node not found")
  }
  match find_text_node(paint_tree, "StrikeReset") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_line_through, content="false")
    None => fail("strike reset text node not found")
  }
}
