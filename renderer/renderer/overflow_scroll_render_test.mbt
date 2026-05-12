///|
// Overflow and scroll renderer regression tests split from render_test.mbt.

///|
test "mixed_block_parent_ignores_overflowing_descendants_of_fixed_height_child" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|header { line-height: 32px; }
    #|nav { display: grid; height: 46.4px; overflow: visible; }
    #|nav > div { height: 90.4px; }
    #|mdn-search-modal { display: inline; }
    #|.breadcrumbs { display: flex; height: 32px; }
    #|</style>
    #|<header>
    #|  <nav><div></div></nav>
    #|  <mdn-search-modal></mdn-search-modal>
    #|  <div class="breadcrumbs"></div>
    #|</header>
  let (_node, layout) = @renderer.render_to_node_and_layout(
    html_str,
    @renderer.RenderContext::default(),
  )
  let header = layout.children[0]
  inspect(header.height, content="78.4")
}

///|
test "scroll_snap_center_applies_initial_horizontal_offset" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.scroller {
    #|  width: 50px;
    #|  height: 50px;
    #|  overflow: hidden;
    #|  white-space: nowrap;
    #|  scroll-snap-type: x mandatory;
    #|  padding: 0 20px;
    #|  box-sizing: border-box;
    #|}
    #|.scroller > div {
    #|  display: inline-block;
    #|  width: 45px;
    #|  height: 45px;
    #|  margin: 5px;
    #|  box-sizing: border-box;
    #|  scroll-snap-align: center;
    #|}
    #|</style>
    #|<div class="scroller">
    #|  <div></div>
    #|  <div></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let node_tree = @renderer.render_to_node(html_str, ctx)
  let scroller_node = node_tree.children[0]
  let first_node = scroller_node.children[0]
  inspect(scroller_node.style.scroll_snap_type.axis, content="X")
  inspect(scroller_node.style.scroll_snap_type.strictness, content="Mandatory")
  inspect(first_node.style.scroll_snap_align_x, content="Center")
  inspect(first_node.style.scroll_snap_align_y, content="Center")

  let layout = @renderer.render(html_str, ctx)
  let scroller = layout.children[0]
  let first = scroller.children[0]

  inspect(scroller.width, content="50")
  inspect(first.x, content="2.5")
}
