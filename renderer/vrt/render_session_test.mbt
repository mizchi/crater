///|
/// A paint-only branch that reuses the base layout must produce the same paint
/// tree as a full re-layout branch (the layout is identical for a paint-only
/// delta), at a fraction of the cost.
test "render session: layout-reusing paint-only branch matches full re-layout" {
  let html =
    #|<!DOCTYPE html><style>
    #|body { margin: 0; }
    #|.box { width: 120px; height: 40px; background: #eee; color: #111; }
    #|.row { display: flex; gap: 8px; }
    #|</style>
    #|<div class="row"><div class="box">one</div><div class="box">two</div></div>
  let viewport = @types.Size::new(400.0, 200.0)
  let session = RenderSession::open(html, viewport, [])
  // Paint-only mutation: recolor .box backgrounds (no geometry change).
  let mutations : Array[CssMutation] = [
    {
      selector: ".box",
      property: "background",
      action: CssMutationAction::Override("#3366ff"),
    },
    {
      selector: ".box",
      property: "color",
      action: CssMutationAction::Override("#ffffff"),
    },
  ]
  let reuse = session.branch_reusing_layout(mutations).to_json_string()
  let full = session.branch_full(mutations).to_json_string()
  inspect(reuse == full, content="true")
}

///|
/// The base paint tree is stable and a paint-only branch differs from it (the
/// diff is non-empty), confirming the branch actually applied the mutation.
test "render session: paint-only branch diff is non-empty vs base" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}.b{width:50px;height:50px;background:#000}</style>
    #|<div class="b"></div>
  let viewport = @types.Size::new(100.0, 100.0)
  let session = RenderSession::open(html, viewport, [])
  let mutations : Array[CssMutation] = [
    {
      selector: ".b",
      property: "background",
      action: CssMutationAction::Override("#ff0000"),
    },
  ]
  let diff = session.branch_reusing_layout_diff(mutations)
  // The background color change shows up as a paint property change.
  inspect(diff.changes.length() > 0, content="true")
}

///|
/// A session records the text-measurement side effect at open(); restoring a
/// session from that recording reproduces the base render byte-identically and
/// supports branching — without needing a font engine. This is the portable
/// VRT snapshot: capture once, persist measurements, reproduce anywhere.
test "render session records measurements and restores from them" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}.box{display:inline-block;color:#111}</style>
    #|<div class="box">Hello snapshot world</div>
  let viewport = @types.Size::new(400.0, 200.0)
  let session = RenderSession::open(html, viewport, [])
  let recording = session.recorded_measurements()
  inspect(recording.length() > 0, content="true")

  // Restore from the recording (replay-only) and compare the base render.
  let restored = RenderSession::open_with_recording(
    html,
    viewport,
    [],
    recording,
    session.recorded_images(),
  )
  inspect(
    restored.base_paint_tree().to_json_string() ==
    session.base_paint_tree().to_json_string(),
    content="true",
  )

  // A paint-only branch on the restored session matches the original session.
  let mutations : Array[CssMutation] = [
    {
      selector: ".box",
      property: "color",
      action: CssMutationAction::Override("#ff0000"),
    },
  ]
  inspect(
    restored.branch_reusing_layout(mutations).to_json_string() ==
    session.branch_reusing_layout(mutations).to_json_string(),
    content="true",
  )
}

///|
/// branch() auto-selects: a paint-only delta reuses the base layout (matches
/// branch_reusing_layout), a geometry delta re-lays-out (matches branch_full).
test "render session branch() auto-selects strategy by mutation kind" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}.b{display:inline-block;width:80px;height:20px;background:#000}</style>
    #|<div class="b">x</div>
  let viewport = @types.Size::new(300.0, 100.0)
  let session = RenderSession::open(html, viewport, [])
  // paint-only
  let paint_mut : Array[CssMutation] = [
    {
      selector: ".b",
      property: "background",
      action: CssMutationAction::Override("#0f0"),
    },
  ]
  inspect(paint_mut[0].is_paint_only(), content="true")
  inspect(
    session.branch(paint_mut).to_json_string() ==
    session.branch_reusing_layout(paint_mut).to_json_string(),
    content="true",
  )
  // layout-affecting
  let layout_mut : Array[CssMutation] = [
    {
      selector: ".b",
      property: "width",
      action: CssMutationAction::Override("200px"),
    },
  ]
  inspect(layout_mut[0].is_paint_only(), content="false")
  inspect(
    session.branch(layout_mut).to_json_string() ==
    session.branch_full(layout_mut).to_json_string(),
    content="true",
  )
}

///|
/// The layout-box geometry index reports each element's real absolute box —
/// the data page JS getBoundingClientRect / offsetWidth / offsetHeight needs
/// (today the runtime guesses from inline styles). A flex row of two fixed
/// boxes lays out at x=0/w=100 and x=100/w=80.
test "layout box geometry index matches the real layout" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}</style>
    #|<div style="display:flex">
    #|  <div id="a" style="width:100px;height:40px"></div>
    #|  <div id="b" style="width:80px;height:40px"></div>
    #|</div>
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: 400.0,
    viewport_height: 200.0,
  }
  let layout = @renderer.render(html, ctx)
  let a = layout_box_by_id(layout, "#a").unwrap()
  inspect("\{a.x},\{a.width},\{a.height}", content="0,100,40")
  let b = layout_box_by_id(layout, "#b").unwrap()
  inspect("\{b.x},\{b.width},\{b.height}", content="100,80,40")
  // The flatten is document-order and includes the container; b comes after a.
  inspect(b.index > a.index, content="true")
}

///|
/// The computed-style index reports each element's resolved style in the form
/// page JS getComputedStyle reads (display "flex", color "rgb(...)", font-size
/// "20px") — the node-tree analogue of the layout-box geometry index, keyed by
/// the same document-order index so the two can be joined element-for-element.
test "computed style index matches the resolved style" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}
    #|#card { display: flex; position: relative; color: #ff0000;
    #|        background-color: #00ff00; font-size: 20px; opacity: 0.5; z-index: 7; }
    #|</style>
    #|<div id="card">hi</div>
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: 400.0,
    viewport_height: 200.0,
  }
  let node = @renderer.render_to_node(html, ctx)
  let card = computed_style_by_id(node, "#card").unwrap()
  debug_inspect(
    card,
    content=(
      #|{
      #|  id: "div#card",
      #|  index: 1,
      #|  display: "flex",
      #|  position: "relative",
      #|  visibility: "visible",
      #|  font_size: "20px",
      #|  font_family: "serif",
      #|  opacity: "0.5",
      #|  z_index: "7",
      #|  color: "rgb(255, 0, 0)",
      #|  background_color: "rgb(0, 255, 0)",
      #|}
    ),
  )
}

///|
/// The bridge serializer emits the two page-realm globals the mock DOM reads,
/// each as a document-order array whose entries carry the join key (`index` +
/// `tag#id` `id`). Hand-built indexes pin the exact JS so a format regression is
/// caught: integral geometry serializes without a trailing `.0`, CSS value
/// strings are quoted, and getComputedStyle's camelCase keys are used.
test "layout bridge serializes both page-realm globals" {
  let boxes : Array[LayoutBox] = [
    { id: "div#a", index: 0, x: 0.0, y: 0.0, width: 100.0, height: 40.0 },
    { id: "div#b", index: 1, x: 100.0, y: 0.0, width: 80.5, height: 40.0 },
  ]
  let styles : Array[ComputedStyleEntry] = [
    {
      id: "div#a",
      index: 0,
      display: "flex",
      position: "static",
      visibility: "visible",
      font_size: "16px",
      font_family: "serif",
      opacity: "1",
      z_index: "auto",
      color: "rgb(0, 0, 0)",
      background_color: "rgba(0, 0, 0, 0)",
    },
  ]
  let js = layout_bridge_init_js(boxes, styles)
  let expected =
    "globalThis.__craterLayoutBoxes = [" +
    "{\"index\":0,\"id\":\"div#a\",\"x\":0,\"y\":0,\"width\":100,\"height\":40}," +
    "{\"index\":1,\"id\":\"div#b\",\"x\":100,\"y\":0,\"width\":80.5,\"height\":40}];\n" +
    "globalThis.__craterComputedStyles = [" +
    "{\"index\":0,\"id\":\"div#a\",\"display\":\"flex\",\"position\":\"static\"," +
    "\"visibility\":\"visible\",\"fontSize\":\"16px\",\"fontFamily\":\"serif\"," +
    "\"opacity\":\"1\",\"zIndex\":\"auto\",\"color\":\"rgb(0, 0, 0)\"," +
    "\"backgroundColor\":\"rgba(0, 0, 0, 0)\"}];\n"
  inspect(js == expected, content="true")
}

///|
/// End-to-end from a RenderSession: the injected globals describe the real
/// layout of the flex row (`#a` at x=0/w=100, `#b` at x=100/w=80) and the
/// resolved styles, so the mock DOM can join an element to its geometry by its
/// `tag#id` id.
test "render session emits bridge init js for the real layout" {
  let html =
    #|<!DOCTYPE html><style>body{margin:0}</style>
    #|<div style="display:flex">
    #|  <div id="a" style="width:100px;height:40px"></div>
    #|  <div id="b" style="width:80px;height:40px"></div>
    #|</div>
  let viewport = @types.Size::new(400.0, 200.0)
  let session = RenderSession::open(html, viewport, [])
  let js = session.layout_bridge_init_js()
  inspect(js.contains("globalThis.__craterLayoutBoxes = ["), content="true")
  inspect(js.contains("globalThis.__craterComputedStyles = ["), content="true")
  inspect(js.contains("\"id\":\"div#a\""), content="true")
  inspect(js.contains("\"id\":\"div#b\""), content="true")
  // #a is 100x40, #b is 100px to the right and 80x40 (see the layout-box test).
  inspect(js.contains("\"width\":100,\"height\":40"), content="true")
  inspect(js.contains(",\"x\":100,"), content="true")
  inspect(js.contains("\"width\":80,\"height\":40"), content="true")
}
