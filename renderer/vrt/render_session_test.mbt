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
