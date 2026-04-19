///|

///|
pub struct DragMoveTargetPlan {
  over_target : String
  emit_dragleave : Bool
  emit_dragenter : Bool
  emit_dragover : Bool
}

///|
pub fn drag_move_target_plan(
  drag_source : String,
  previous_over_target : String,
  hover_target : String,
) -> DragMoveTargetPlan {
  let over_target = if hover_target != "" && hover_target != drag_source {
    hover_target
  } else {
    ""
  }
  {
    over_target,
    emit_dragleave: previous_over_target != "" &&
    previous_over_target != over_target &&
    previous_over_target != drag_source,
    emit_dragenter: over_target != "" &&
    over_target != previous_over_target &&
    over_target != drag_source,
    emit_dragover: over_target != "" && over_target != drag_source,
  }
}

///|
pub fn drag_accept_target(
  drag_source : String,
  drag_target : String,
  dragover_prevented : Bool,
) -> String {
  if dragover_prevented && drag_target != "" && drag_target != drag_source {
    drag_target
  } else {
    ""
  }
}

///|
pub fn drag_drop_target(
  drag_source : String,
  drag_over_target : String,
  accepted_target : String,
) -> String {
  if drag_over_target != "" &&
    accepted_target == drag_over_target &&
    drag_over_target != drag_source {
    drag_over_target
  } else {
    ""
  }
}

///|
pub fn normalized_drop_effect(
  effect_allowed : String,
  drop_effect : String,
) -> String {
  let allowed = effect_allowed.to_lower()
  let effect = drop_effect.to_lower()
  if effect != "" && effect != "none" {
    effect
  } else {
    match allowed {
      "copy" | "copylink" | "copymove" | "all" | "uninitialized" => "copy"
      "link" | "linkmove" => "link"
      "move" => "move"
      _ => "none"
    }
  }
}

///|
pub fn is_drop_effect_compatible(
  effect_allowed : String,
  drop_effect : String,
) -> Bool {
  let allowed = effect_allowed.to_lower()
  let effect = normalized_drop_effect(effect_allowed, drop_effect)
  if effect == "none" {
    return false
  }
  match allowed {
    "all" => true
    "uninitialized" => true
    "copy" => effect == "copy"
    "copylink" => effect == "copy" || effect == "link"
    "copymove" => effect == "copy" || effect == "move"
    "link" => effect == "link"
    "linkmove" => effect == "link" || effect == "move"
    "move" => effect == "move"
    _ => false
  }
}
