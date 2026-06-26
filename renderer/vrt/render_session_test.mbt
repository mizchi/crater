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
