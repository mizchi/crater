///|
// Multi-column and fragmentation renderer regression tests split from
// render_test.mbt and renderer_test.mbt.

///|
test "fieldset_multicol_ignores_first_break_before_column_after_legend" {
  let html_str =
    #|<!doctype html>
    #|<style>
    #|  body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|  #scroller {
    #|    overflow: hidden;
    #|    columns: 2;
    #|    column-fill: auto;
    #|    padding: 0;
    #|    gap: 0;
    #|    width: 400px;
    #|    height: 100px;
    #|}
    #|  fieldset {
    #|    border: 3px solid black;
    #|  }
    #|</style>
    #|<fieldset id="scroller">
    #|  <legend>Legend</legend>
    #|  <div style="break-before:column;">first</div>
    #|  <div style="break-before:column;">second</div>
    #|</fieldset>
  let body = @renderer.render(html_str, @renderer.RenderContext::default())
  let fieldset = body.children[0]
  let first = fieldset.children[1]
  let second = fieldset.children[2]
  guard (first.x - 3.0).abs() < 0.01 else {
    fail("first post-legend multicol child should stay in first column")
  }
  guard (first.y - 19.2).abs() < 0.01 else {
    fail("first post-legend multicol child should start below legend band")
  }
  guard (second.x - 203.0).abs() < 0.01 else {
    fail("second child with break-before:column should move to second column")
  }
}

///|
test "balanced_multicol_child_uses_union_width_without_containment" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|div { min-height: 10px; margin-bottom: 10px; }
    #|.columns {
    #|  columns: 2;
    #|  column-rule-width: medium;
    #|  column-rule-style: solid;
    #|}
    #|.inner { height: 20px; }
    #|</style>
    #|<div class="columns"><div class="inner"></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let columns = layout.children[0]
  let inner = columns.children[0]
  inspect(columns.height, content="25")
  inspect(inner.width, content="800")
  inspect(inner.height, content="15")
}

///|
test "wpt_contain_layout_breaks_forced_column_break_stays_in_multicol" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|article {
    #|  columns: 2 1ch;
    #|  column-gap: 0;
    #|  font-family: monospace;
    #|  line-height: 1;
    #|  height: 4em;
    #|  column-fill: auto;
    #|}
    #|#forced { break-before: column; }
    #|</style>
    #|<article>
    #|  <div>
    #|    <div id="first">A<br>A</div>
    #|    <div id="forced">A<br>A</div>
    #|  </div>
    #|</article>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let article = layout.children[0]
  let wrapper = article.children[0]
  let first = wrapper.children[0]
  let forced = wrapper.children[1]
  guard forced.x > first.x else {
    fail("break-before:column child should move to the next column")
  }
  inspect(forced.y, content="0")
}

///|
test "wpt_contain_layout_forced_break_does_not_escape_parent" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|article {
    #|  columns: 2 100px;
    #|  column-fill: auto;
    #|  column-gap: 0;
    #|  float: left;
    #|  height: 400px;
    #|}
    #|#yellow-normal { border-top: yellow solid 100px; }
    #|#blue-parent {
    #|  border-top: blue solid 100px;
    #|  contain: layout;
    #|}
    #|#orange-child {
    #|  border-top: orange solid 100px;
    #|  break-before: column;
    #|}
    #|</style>
    #|<article>
    #|  <div id="yellow-normal"></div>
    #|  <div id="blue-parent"><div id="orange-child"></div></div>
    #|</article>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let article = layout.children[0]
  let blue_parent = article.children[1]
  let orange_child = blue_parent.children[0]
  inspect(blue_parent.x, content="0")
  inspect(blue_parent.y, content="100")
  inspect(blue_parent.height, content="200")
  inspect(orange_child.x, content="0")
  inspect(orange_child.y, content="100")
}

///|
test "multicol_break_inside_avoid_keeps_block_unfragmented" {
  // Regression for css-contain/contain-style-breaks-00{1,2,3}.html.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|article {
    #|  columns: 2 1ch;
    #|  column-gap: 0;
    #|  font-family: monospace;
    #|}
    #|#target {
    #|  break-inside: avoid;
    #|}
    #|</style>
    #|<article id="article">
    #|  <div id="target">
    #|    A<br>
    #|    A<br>
    #|    A<br>
    #|    A
    #|  </div>
    #|</article>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let article = layout.children[0]
  let target = article.children[0]
  let mut max_child_x = 0.0
  let mut min_delta_y = 0.0
  let mut prev_y = -1.0
  for child in target.children {
    if child.x > max_child_x {
      max_child_x = child.x
    }
    if prev_y >= 0.0 {
      let delta = child.y - prev_y
      if delta < min_delta_y {
        min_delta_y = delta
      }
    }
    prev_y = child.y
  }
  guard max_child_x <= 8.5 else {
    fail("break-inside:avoid block children should not spill to next column")
  }
  guard min_delta_y >= -0.1 else {
    fail("break-inside:avoid block should keep child flow in one column")
  }
}

///|
test "multicol_balance_break_before_avoid_keeps_balanced_column_boundary" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="width:100px; columns:2; column-gap:0;">
    #|  <div style="height:25px;"></div>
    #|  <div style="height:50px;"></div>
    #|  <div style="height:25px; break-before:avoid;"></div>
    #|  <div id="last" style="height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let last = target.children[3]
  inspect(target.height, content="100")
  inspect(last.x, content="50")
  inspect(last.y, content="0")
}

///|
test "multicol_auto_fill_break_avoid_moves_group_start_to_next_column" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:160px;">
    #|  <div style="height:50px;"></div>
    #|  <div style="height:50px;"></div>
    #|  <div id="third" style="height:50px;"></div>
    #|  <div id="last" style="height:50px; break-before:avoid;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let third = target.children[2]
  let last = target.children[3]
  inspect(third.x, content="50")
  inspect(third.y, content="0")
  inspect(last.x, content="50")
  inspect(last.y, content="50")
}

///|
test "multicol_nested_forced_break_at_start_moves_wrapper_to_next_column" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; column-fill:auto; column-gap:0; height:250px;">
    #|    <div id="first" style="height:100px;"></div>
    #|    <div id="wrapper"><div style="break-before:column;"></div></div>
    #|    <div id="last" style="height:100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let wrapper = target.children[1]
  let last = target.children[2]
  inspect(wrapper.x, content="50")
  inspect(wrapper.y, content="0")
  inspect(last.x, content="50")
  inspect(last.y, content="0")
}

///|
test "multicol_nested_forced_break_at_end_moves_next_sibling_to_next_column" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; column-fill:auto; column-gap:0; height:250px;">
    #|    <div id="first" style="height:100px;"></div>
    #|    <div id="wrapper"><div style="break-after:column;"></div></div>
    #|    <div id="last" style="height:100px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let last = target.children[2]
  inspect(last.x, content="50")
  inspect(last.y, content="0")
}

///|
test "multicol_forced_break_trumps_break_avoid_grouping" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:110px;">
    #|  <div style="height:50px;"></div>
    #|  <div id="second" style="height:50px; break-after:column;"></div>
    #|  <div id="third" style="height:50px; break-before:avoid;"></div>
    #|  <div id="last" style="height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let second = target.children[1]
  let third = target.children[2]
  let last = target.children[3]
  inspect(second.x, content="0")
  inspect(second.y, content="50")
  inspect(third.x, content="50")
  inspect(third.y, content="0")
  inspect(last.x, content="50")
  inspect(last.y, content="50")
}

///|
test "multicol_discards_top_margin_at_fragment_start" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:100px;">
    #|  <div style="height:70px;"><div style="height:150px;"></div></div>
    #|  <div id="wrapper">
    #|    <div id="inner" style="margin-top:60px;">
    #|      <div style="height:50px;"></div>
    #|      <div id="green" style="height:50px;"></div>
    #|    </div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let first = target.children[0]
  let tall = first.children[0]
  let wrapper = target.children[1]
  let inner = wrapper.children[0]
  let green = inner.children[1]
  inspect(tall.width, content="100")
  inspect(tall.height, content="100")
  inspect(wrapper.x, content="50")
  inspect(wrapper.y, content="0")
  inspect(wrapper.width, content="50")
  inspect(inner.y, content="0")
  inspect(green.y, content="50")
}

///|
test "multicol_break_avoid_backtracks_inside_wrapper_for_following_sibling" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; column-fill:auto; column-gap:0; width:100px; height:160px;">
    #|  <div id="wrapper">
    #|    <div style="height:50px;"></div>
    #|    <div>
    #|      <div id="deep">
    #|        <div style="height:50px; break-inside:avoid;"></div>
    #|        <div id="moved" style="height:50px; break-inside:avoid;"></div>
    #|      </div>
    #|    </div>
    #|  </div>
    #|  <div id="tail" style="height:50px; break-before:avoid;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let wrapper = target.children[0]
  let nested = wrapper.children[1]
  let deep = nested.children[0]
  let moved = deep.children[1]
  let tail = target.children[1]
  inspect(wrapper.width, content="100")
  inspect(nested.y, content="0")
  inspect(deep.width, content="100")
  inspect(moved.x, content="50")
  inspect(moved.y, content="0")
  inspect(tail.x, content="50")
  inspect(tail.y, content="50")
}

///|
test "multicol_break_avoid_can_move_previous_sibling_to_keep_group_together" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="column-count:4; column-gap:0; column-fill:auto; width:100px; height:100px;">
    #|  <div style="width:25px; height:50px;"></div>
    #|  <div id="second" style="width:25px; height:50px;"></div>
    #|  <div id="wrapper">
    #|    <div id="keep" style="height:50px; break-before:avoid;"></div>
    #|    <div id="spill" style="height:200px;"></div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0]
  let second = target.children[1]
  let wrapper = target.children[2]
  let keep = wrapper.children[0]
  let spill = wrapper.children[1]
  inspect(second.x, content="25")
  inspect(second.y, content="0")
  inspect(keep.y, content="50")
  inspect(spill.x, content="25")
  inspect(spill.y, content="0")
}

///|
test "multicol_break_avoid_reflows_single_child_block_wrapper_descendants" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; column-fill:auto; width:250px; column-gap:50px; margin-left:-150px; height:110px;">
    #|    <div style="height:2px;"></div>
    #|    <div id="wrapper1">
    #|      <div id="wrapper2">
    #|        <div id="wrapper3">
    #|          <div style="contain:size; height:50px;"></div>
    #|          <div id="b" style="contain:size; height:50px;"></div>
    #|        </div>
    #|      </div>
    #|      <div id="c" style="break-before:avoid; contain:size; height:50px;"></div>
    #|    </div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let wrapper1 = target.children[1]
  let wrapper2 = wrapper1.children[0]
  let wrapper3 = wrapper2.children[0]
  let b = wrapper3.children[1]
  let c = wrapper1.children[1]
  inspect(wrapper2.width, content="250")
  inspect(wrapper3.width, content="250")
  inspect(b.x, content="150")
  inspect(b.y, content="0")
  inspect(c.x, content="150")
  inspect(c.y, content="42")
}

///|
test "multicol_break_avoid_moves_float_with_following_reserved_group" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div style="width:100px; height:100px;">
    #|  <div id="target" style="columns:2; gap:0; column-fill:auto; height:150px;">
    #|    <div style="height:100px;"></div>
    #|    <div style="height:30px;"></div>
    #|    <div id="float" style="float:left; width:50%;">
    #|      <div style="height:10px; contain:size;"></div>
    #|      <div style="height:10px; contain:size;"></div>
    #|    </div>
    #|    <div id="keep" style="break-before:avoid; break-inside:avoid;">
    #|      <div id="keep-first" style="margin-left:auto; width:50%; height:20px;"></div>
    #|      <div style="height:50px;"></div>
    #|    </div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let float_box = target.children[2]
  let keep = target.children[3]
  let keep_first = keep.children[0]
  inspect(float_box.x, content="50")
  inspect(float_box.y, content="30")
  inspect(keep.x, content="50")
  inspect(keep.y, content="30")
  inspect(keep_first.x, content="25")
}

///|
test "multicol_margin_fragment_start_preserves_block_stack_width_inside_inline_wrapper" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; gap:0; column-fill:auto; width:100px; height:100px;">
    #|  <span>
    #|    <div style="height:70px;"><div style="height:150px;"></div></div>
    #|    <span>
    #|      <div style="margin-top:60px;">
    #|        <div id="first" style="height:50px;"></div>
    #|        <div id="green" style="height:50px;"></div>
    #|      </div>
    #|    </span>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let span = outer.children[0]
  let tail_span = span.children[1]
  let inner = tail_span.children[0]
  let first = inner.children[0]
  let green = inner.children[1]
  inspect(span.width, content="100")
  inspect(tail_span.x, content="50")
  inspect(tail_span.width, content="50")
  inspect(inner.width, content="50")
  inspect(first.y, content="0")
  inspect(green.x, content="0")
  inspect(green.y, content="50")
}

///|
test "multicol_margin_fragment_start_keeps_float_only_inline_wrapper_zero_sized" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="target" style="columns:2; gap:0; column-fill:auto; width:100px; height:100px;">
    #|  <span>
    #|    <div style="height:70px;"><div style="height:150px;"></div></div>
    #|    <span id="tail-span">
    #|      <div id="float-wrap" style="margin-top:160px;">
    #|        <div style="float:left; width:100%;">
    #|          <div id="first" style="height:50px;"></div>
    #|          <div id="green" style="height:50px;"></div>
    #|        </div>
    #|      </div>
    #|    </span>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let span = outer.children[0]
  let tail_span = span.children[1]
  let float_wrap = tail_span.children[0]
  let float_box = float_wrap.children[0]
  let green = float_box.children[1]
  inspect(span.width, content="150")
  inspect(tail_span.x, content="100")
  inspect(tail_span.width, content="50")
  inspect(float_wrap.x, content="50")
  inspect(float_wrap.width, content="50")
  inspect(float_box.width, content="50")
  inspect(green.y, content="50")
}

///|
test "wpt_contain_inline_size_multicol_spanner_balances_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>body { margin: 0; }</style>
    #|<div id="outer" style="columns:4; column-gap:0; contain:inline-size; width:fit-content; border:solid green; border-width:0 50px;">
    #|  <div id="tall" style="width:25px; height:200px;"></div>
    #|  <div id="spanner" style="column-span:all; width:400px; height:50px;"></div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let outer = layout.children[0]
  let tall = outer.children[0]
  let spanner = outer.children[1]
  inspect(outer.height, content="100")
  inspect(tall.height, content="50")
  inspect(spanner.y, content="50")
}

///|
test "contain_size_multicol_fragment_union_matches_browser_rects" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.contain {
    #|  contain: size;
    #|  border: 1em solid green;
    #|  background: red;
    #|  column-count: 3;
    #|}
    #|.inner {
    #|  color: transparent;
    #|  width: 50px;
    #|  height: 50px;
    #|}
    #|</style>
    #|<div id="contain" class="contain"><div id="inner" class="inner">inner</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let contain = layout.children[0]
  let inner = contain.children[0]
  inspect(contain.width, content="800")
  inspect(contain.height, content="32")
  guard inner.width > 560.0 else {
    fail("fragmented union width should span later columns")
  }
  guard inner.height < 30.0 else {
    fail("fragmented union height should collapse to one fragment band")
  }
}

///|
test "contain_size_text_only_multicol_child_keeps_zero_outer_height" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#multi-column {
    #|  column-count: 2;
    #|  column-fill: balance;
    #|  column-gap: 4ch;
    #|  column-rule: red solid 4ch;
    #|  column-width: 2ch;
    #|  font-family: monospace;
    #|  font-size: 20px;
    #|  width: 8ch;
    #|}
    #|#size-contain { contain: size; }
    #|</style>
    #|<div id="multi-column"><div id="size-contain">AB CD EF GH</div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let multicol = layout.children[0]
  let contain = multicol.children[0]
  inspect(multicol.height, content="0")
  inspect(contain.height, content="0")
}

///|
test "wpt_column_scroll_marker_004_fieldset_multicol_fragments" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  #container {
    #|    overflow: hidden;
    #|    columns: 3;
    #|    column-fill: auto;
    #|    gap: 0;
    #|    height: 50px;
    #|    margin: 0;
    #|    border: 15px solid green;
    #|    padding: 0;
    #|    scroll-marker-group: before;
    #|    background: red;
    #|  }
    #|  #container::scroll-marker-group {
    #|    display: flex;
    #|    height: 20px;
    #|    background: red;
    #|  }
    #|  #container::column::scroll-marker {
    #|    display: flex;
    #|    width: 20px;
    #|    height: 100%;
    #|    background: green;
    #|    content: "";
    #|  }
    #|</style>
    #|<div style="width:100px; height:100px; background:red;">
    #|  <fieldset id="container">
    #|    <legend style="width:50px; height:15px; background:green;"></legend>
    #|    <div style="height:210px; background:green;"></div>
    #|  </fieldset>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let raw_wrapper = node.children[0]
  let raw_carousel = raw_wrapper.children[0]
  inspect(
    raw_carousel.style.box_sizing,
    content=(
      #|BorderBox
    ),
  )
  inspect(
    raw_carousel.children.length(),
    content=(
      #|2
    ),
  )
  let wrapper = layout.children[0]
  let container = wrapper.children[0]
  let content = container.children[1]
  inspect(container.id, content="fieldset#container")
  inspect(content.width, content="116.66666666666666")
  inspect(content.height, content="50")
}

///|
test "wpt_targeted_column_scroll_marker_selection_001_static_layout_metrics" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|  .wrapper {
    #|    display: grid;
    #|    justify-content: center;
    #|  }
    #|  .carousel {
    #|    width: 800px;
    #|    height: 200px;
    #|    overflow-x: scroll;
    #|    scroll-snap-type: x mandatory;
    #|    list-style-type: none;
    #|    scroll-behavior: smooth;
    #|    border: solid 2px grey;
    #|    padding-top: 10%;
    #|    text-align: center;
    #|    counter-set: markeridx -1;
    #|    columns: 2;
    #|
    #|    &::column::scroll-marker {
    #|      content: counter(markeridx);
    #|      counter-increment: markeridx;
    #|      align-content: center;
    #|      text-align: center;
    #|      width: 35px;
    #|      height: 35px;
    #|      border-radius: 50%;
    #|      margin: 3px;
    #|      background-color: red;
    #|    }
    #|    &::column::scroll-marker:target-current {
    #|      background-color: green;
    #|    }
    #|    &>.item {
    #|      scroll-snap-align: center;
    #|      height: 80%;
    #|      width: 158px;
    #|      border: 1px solid;
    #|      place-content: center;
    #|      display: inline-block;
    #|    }
    #|
    #|    scroll-marker-group: after;
    #|
    #|    &::scroll-marker-group {
    #|      height: 45px;
    #|      display: flex;
    #|      align-items: center;
    #|      justify-content: center;
    #|      border: solid 1px black;
    #|      border-radius: 30px;
    #|    }
    #|  }
    #|</style>
    #|<div class="wrapper" id="wrapper">
    #|  <div class="carousel" id="carousel">
    #|    <div class="item item0" tabindex=0>0</div>
    #|    <div class="item item1" tabindex=0>1</div>
    #|    <div class="item item2" tabindex=0>2</div>
    #|    <div class="item item3" tabindex=0>3</div>
    #|    <div class="item item4" tabindex=0>4</div>
    #|    <div class="item item5" tabindex=0>5</div>
    #|    <div class="item item6" tabindex=0>6</div>
    #|    <div class="item item7" tabindex=0>7</div>
    #|    <div class="item item8" tabindex=0>8</div>
    #|    <div class="item item9" tabindex=0>9</div>
    #|    <div class="item item10" tabindex=0>10</div>
    #|    <div class="item item11" tabindex=0>11</div>
    #|    <div class="item item12" tabindex=0>12</div>
    #|    <div class="item item13" tabindex=0>13</div>
    #|    <div class="item item14" tabindex=0>14</div>
    #|    <div class="item item15" tabindex=0>15</div>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let node = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let raw_wrapper = node.children[0]
  let raw_carousel = raw_wrapper.children[0]
  inspect(
    raw_carousel.children.length(),
    content=(
      #|31
    ),
  )
  let wrapper = layout.children[0]
  let carousel = wrapper.children[0]
  let item0 = carousel.children[0]
  inspect(carousel.id, content="div#carousel")
  inspect(carousel.padding.top, content="80.4")
  inspect(carousel.height, content="284.4")
  inspect(
    item0.x,
    content=(
      #|30
    ),
  )
  inspect(
    item0.height,
    content=(
      #|160
    ),
  )
}

///|
test "contain_size_multicol_intrinsic_width_in_flex_includes_gaps" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|.flexBaselineCheck { display: flex; align-items: baseline; }
    #|.contain {
    #|  contain: size;
    #|  border: 1em solid green;
    #|  background: red;
    #|  column-count: 3;
    #|}
    #|.inner {
    #|  color: transparent;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div class="flexBaselineCheck">
    #|  outside before
    #|  <div id="contain" class="contain"><div id="inner" class="inner">inner</div></div>
    #|  outside after
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let flex = layout.children[0]
  let contain = flex.children[1]
  let inner = contain.children[0]
  inspect(
    contain.width,
    content=(
      #|64
    ),
  )
  inspect(contain.height, content="32")
  inspect(
    inner.width,
    content=(
      #|132
    ),
  )
  guard inner.height > 30.0 && inner.height < 36.0 else {
    fail("contain:size multicol child should clip to one balanced fragment")
  }
}

///|
test "fieldset_columns_shorthand_applies_in_wpt_like_case" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  #container {
    #|    overflow: hidden;
    #|    columns: 3;
    #|    column-fill: auto;
    #|    gap: 0;
    #|    height: 50px;
    #|    margin: 0;
    #|    border: 15px solid green;
    #|    padding: 0;
    #|    scroll-marker-group: before;
    #|    background: red;
    #|  }
    #|</style>
    #|</head>
    #|<body>
    #|<div style="width:100px; height:100px; background:red;">
    #|  <fieldset id="container">
    #|    <legend style="width:50px; height:15px; background:green;"></legend>
    #|    <div style="height:210px; background:green;"></div>
    #|  </fieldset>
    #|</div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let wrapper = node.children[0]
  let container = wrapper.children[0]
  inspect(container.id, content="fieldset#container")
  inspect(container.style.column_count, content="Some(3)")
  inspect(container.style.box_sizing, content="BorderBox")
  inspect(container.style.height, content="Length(80)")
  inspect(container.style.column_gap, content="Length(0)")
  inspect(container.style.column_gap_is_normal, content="false")
}

///|
test "html_columns_propagate_to_body_root_style" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  html {
    #|    columns: 3;
    #|    max-height: 600px;
    #|  }
    #|  body { margin: 0; }
    #|</style>
    #|</head>
    #|<body>
    #|  <div style="height: 100px"></div>
    #|</body></html>
  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(root.id, content="body")
  inspect(root.style.column_count, content="Some(3)")
  inspect(root.style.column_gap_is_normal, content="true")
}

///|
test "fieldset_columns_shorthand_survives_following_column_scroll_marker_rule" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  #container {
    #|    overflow: hidden;
    #|    columns: 3;
    #|    column-fill: auto;
    #|    gap: 0;
    #|    height: 50px;
    #|    margin: 0;
    #|    border: 15px solid green;
    #|    padding: 0;
    #|    scroll-marker-group: before;
    #|    background: red;
    #|  }
    #|  #container::scroll-marker-group {
    #|    display: flex;
    #|    height: 20px;
    #|    background: red;
    #|  }
    #|  #container::column::scroll-marker {
    #|    display: flex;
    #|    width: 20px;
    #|    height: 100%;
    #|    background: green;
    #|    content: "";
    #|  }
    #|</style>
    #|</head>
    #|<body>
    #|<div style="width:100px; height:100px; background:red;">
    #|  <fieldset id="container">
    #|    <legend style="width:50px; height:15px; background:green;"></legend>
    #|    <div style="height:210px; background:green;"></div>
    #|  </fieldset>
    #|</div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let wrapper = node.children[0]
  let container = wrapper.children[0]
  inspect(container.id, content="fieldset#container")
  inspect(container.style.column_count, content="Some(3)")
  inspect(container.style.box_sizing, content="BorderBox")
  inspect(container.style.height, content="Length(80)")
  inspect(container.style.column_gap, content="Length(0)")
  inspect(container.style.column_gap_is_normal, content="false")
}
