///|

///|
test "drag move target plan normalizes source and hover transitions" {
  let plan_1 = drag_move_target_plan("source", "", "source")
  let plan_2 = drag_move_target_plan("source", "", "target")
  let plan_3 = drag_move_target_plan("source", "target", "")
  let plan_4 = drag_move_target_plan("source", "old", "new")
  inspect(
    (
      (
        plan_1.over_target,
        plan_1.emit_dragleave,
        plan_1.emit_dragenter,
        plan_1.emit_dragover,
      ),
      (
        plan_2.over_target,
        plan_2.emit_dragleave,
        plan_2.emit_dragenter,
        plan_2.emit_dragover,
      ),
      (
        plan_3.over_target,
        plan_3.emit_dragleave,
        plan_3.emit_dragenter,
        plan_3.emit_dragover,
      ),
      (
        plan_4.over_target,
        plan_4.emit_dragleave,
        plan_4.emit_dragenter,
        plan_4.emit_dragover,
      ),
    ),
    content="((\"\", false, false, false), (\"target\", false, true, true), (\"\", true, false, false), (\"new\", true, true, true))",
  )
}

///|
test "drag acceptance helpers only drop on accepted current target" {
  inspect(
    (
      drag_accept_target("source", "target", true),
      drag_accept_target("source", "target", false),
      drag_accept_target("source", "source", true),
      drag_drop_target("source", "target", "target"),
      drag_drop_target("source", "target", ""),
      drag_drop_target("source", "other", "target"),
    ),
    content="(\"target\", \"\", \"\", \"target\", \"\", \"\")",
  )
}

///|
test "drop effect helpers normalize and validate browser-style defaults" {
  inspect(
    (
      normalized_drop_effect("all", "none"),
      normalized_drop_effect("move", "none"),
      normalized_drop_effect("copyLink", "none"),
      normalized_drop_effect("copy", "move"),
      is_drop_effect_compatible("all", "none"),
      is_drop_effect_compatible("move", "none"),
      is_drop_effect_compatible("copy", "move"),
      is_drop_effect_compatible("copyMove", "move"),
      is_drop_effect_compatible("none", "copy"),
    ),
    content="(\"copy\", \"move\", \"copy\", \"move\", true, true, false, true, false)",
  )
}
