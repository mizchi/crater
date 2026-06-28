///|
/// V8 + Full mock DOM: dynamic-rendering layout bridge.
///
/// When the host injects `globalThis.__craterLayoutBoxes` /
/// `__craterComputedStyles` (see renderer/vrt `layout_bridge_init_js` and the
/// shell's `Browser::inject_layout_bridge`), element measurement reads crater's
/// real layout instead of the inline-style heuristic. These tests exercise the
/// mock-DOM consumer in real V8: the join key is `tag#id`, with a zeroed /
/// empty fallback when nothing is injected.

///|
test "V8+Bridge: getBoundingClientRect / offset* read injected layout boxes" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__craterLayoutBoxes = [{index:0,id:'div#a',x:5,y:7,width:100,height:40}];" +
    "const a = document.createElement('div'); a.id = 'a'; document.body.appendChild(a);" +
    "const r = a.getBoundingClientRect();" +
    "return [r.x, r.y, r.width, r.height, r.top, r.right, r.bottom, r.left, a.offsetWidth, a.offsetHeight, a.offsetTop, a.offsetLeft].join(',')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "5,7,100,40,7,105,47,5,100,40,7,5")
}

///|
test "V8+Bridge: getComputedStyle reads injected computed styles" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__craterComputedStyles = [{index:0,id:'div#b',display:'flex',position:'relative',visibility:'visible',fontSize:'20px',fontFamily:'serif',opacity:'0.5',zIndex:'7',color:'rgb(255, 0, 0)',backgroundColor:'rgb(0, 255, 0)'}];" +
    "const b = document.createElement('div'); b.id = 'b'; document.body.appendChild(b);" +
    "const cs = window.getComputedStyle(b);" +
    "return [cs.display, cs.position, cs.fontSize, cs.getPropertyValue('font-size'), cs.color, cs.getPropertyValue('background-color'), cs.zIndex].join('|')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(
    result.value,
    "flex|relative|20px|20px|rgb(255, 0, 0)|rgb(0, 255, 0)|7",
  )
}

///|
test "V8+Bridge: falls back to zeros / empty when nothing is injected" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const a = document.createElement('div'); a.id = 'a'; document.body.appendChild(a);" +
    "const r = a.getBoundingClientRect();" +
    "const cs = window.getComputedStyle(a);" +
    "return [r.width, r.height, a.offsetWidth, cs.display, cs.getPropertyValue('color')].join('|')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "0|0|0||")
}

///|
test "V8+Bridge: an element without a matching id keeps the fallback" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__craterLayoutBoxes = [{index:0,id:'div#a',x:5,y:7,width:100,height:40}];" +
    "const other = document.createElement('div'); other.id = 'zzz'; document.body.appendChild(other);" +
    "const r = other.getBoundingClientRect();" +
    "return [r.width, r.height].join(',')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "0,0")
}
