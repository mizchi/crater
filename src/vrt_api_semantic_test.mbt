///|
fn find_semantic_text_node(
  node : @paint.PaintNode,
  text : String,
) -> @paint.PaintNode? {
  match node.text {
    Some(content) => if content == text { return Some(node) }
    None => ()
  }
  for child in node.children {
    match find_semantic_text_node(child, text) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
test "render_html_to_paint_tree applies semantic inline defaults" {
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
  match find_semantic_text_node(paint_tree, "Bold") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="true")
    None => fail("bold text node not found")
  }
  match find_semantic_text_node(paint_tree, "Strong") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="true")
    None => fail("strong text node not found")
  }
  match find_semantic_text_node(paint_tree, "Link") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="true")
    None => fail("link text node not found")
  }
  match find_semantic_text_node(paint_tree, "Underline") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="true")
    None => fail("underline text node not found")
  }
  match find_semantic_text_node(paint_tree, "Strike") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_line_through, content="true")
    None => fail("strike text node not found")
  }
}

///|
test "render_html_to_paint_tree lets author styles override semantic defaults" {
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
  match find_semantic_text_node(paint_tree, "BoldReset") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="false")
    None => fail("bold reset text node not found")
  }
  match find_semantic_text_node(paint_tree, "StrongReset") {
    Some(text_node) => inspect(text_node.paint.is_bold, content="false")
    None => fail("strong reset text node not found")
  }
  match find_semantic_text_node(paint_tree, "LinkReset") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="false")
    None => fail("link reset text node not found")
  }
  match find_semantic_text_node(paint_tree, "UnderlineReset") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_underline, content="false")
    None => fail("underline reset text node not found")
  }
  match find_semantic_text_node(paint_tree, "StrikeReset") {
    Some(text_node) =>
      inspect(text_node.paint.text_decoration_line_through, content="false")
    None => fail("strike reset text node not found")
  }
}
