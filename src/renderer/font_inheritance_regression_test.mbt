///|
test "ua default line-height does not reset inherited font metrics on inline descendants" {
  let html =
    #|<!doctype html>
    #|<style>
    #|#host { font-size: 20px; line-height: 30px; }
    #|</style>
    #|<div id="host"><span id="child">hello</span></div>
  let node = render_to_node(html, RenderContext::default())
  let host = node.children[0]
  inspect(host.id, content="div#host")
  inspect(host.style.font_size, content="20")
  inspect(host.style.line_height, content="30")

  let child = host.children[0]
  inspect(child.id, content="span#child")
  inspect(child.style.font_size, content="20")
  inspect(child.style.line_height, content="30")

  let text = child.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="20")
  inspect(text.style.line_height, content="30")
}
