///|
/// Handle input.releaseActions.
fn BidiProtocol::handle_input_release_actions(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(id) => id
    None => return false
  }

  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  let pointer_type = self.input_pointer_type.get(ctx_id).unwrap_or("mouse")
  let pressed = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let mut idx = pressed.length()
  while idx > 0 {
    idx = idx - 1
    let key = pressed[idx]
    let dispatch_key = restore_input_key_for_dispatch(key)
    let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
      ctx_id, "", false,
    )
    dispatch_interaction_key_command(
      bidi_key_interaction_command("keyUp", key),
      dispatch_key,
      ctrl,
      alt,
      shift,
      meta,
    )
    self.remove_pressed_key(ctx_id, key)
  }
  self.input_pressed_keys.remove(ctx_id)

  let current_x = self.input_pointer_x.get(ctx_id).unwrap_or(0.0)
  let current_y = self.input_pointer_y.get(ctx_id).unwrap_or(0.0)
  let target_shared = self.input_pointer_target_shared.get(ctx_id).unwrap_or("")
  let current_buttons = self.input_pointer_buttons.get(ctx_id).unwrap_or(0)
  if button_state_contains(current_buttons, button_to_mask(2)) {
    dispatch_interaction_pointer_command(
      bidi_pointer_interaction_command("pointerUp", current_x, current_y, 2),
      target_shared,
      current_x,
      current_y,
      button_state_remove(current_buttons, 2),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared,
      "mouseup",
      current_x,
      current_y,
      2,
      button_state_remove(current_buttons, 2),
      pointer_type,
      false,
      false,
      false,
      false,
    )
  }
  if button_state_contains(current_buttons, button_to_mask(1)) {
    dispatch_interaction_pointer_command(
      bidi_pointer_interaction_command("pointerUp", current_x, current_y, 1),
      target_shared,
      current_x,
      current_y,
      button_state_remove(current_buttons, 1),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared,
      "mouseup",
      current_x,
      current_y,
      1,
      button_state_remove(current_buttons, 1),
      pointer_type,
      false,
      false,
      false,
      false,
    )
  }
  if button_state_contains(current_buttons, button_to_mask(0)) {
    dispatch_interaction_pointer_command(
      bidi_pointer_interaction_command("pointerUp", current_x, current_y, 0),
      target_shared,
      current_x,
      current_y,
      button_state_remove(current_buttons, 0),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared,
      "mouseup",
      current_x,
      current_y,
      0,
      button_state_remove(current_buttons, 0),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared, "click", current_x, current_y, 0, 0, pointer_type, false, false,
      false, false,
    )
  }
  self.input_pointer_buttons.remove(ctx_id)
  self.input_pointer_target_shared.remove(ctx_id)
  self.input_pointer_x.remove(ctx_id)
  self.input_pointer_y.remove(ctx_id)
  self.input_pointer_down_x.remove(ctx_id)
  self.input_pointer_down_y.remove(ctx_id)
  self.input_pointer_down_target_shared.remove(ctx_id)
  self.input_pointer_dragged.remove(ctx_id)
  self.input_html_drag_source_shared.remove(ctx_id)
  self.input_html_drag_active.remove(ctx_id)
  self.input_html_drag_over_shared.remove(ctx_id)
  self.input_html_drag_accept_shared.remove(ctx_id)
  let drag_transfer_id = self.input_html_drag_transfer_id
    .get(ctx_id)
    .unwrap_or("")
  if drag_transfer_id != "" {
    input_clear_drag_transfer(drag_transfer_id)
  }
  self.input_html_drag_transfer_id.remove(ctx_id)
  self.input_last_click_time.remove(ctx_id)
  self.input_last_click_x.remove(ctx_id)
  self.input_last_click_y.remove(ctx_id)
  self.input_last_click_target_shared.remove(ctx_id)
  self.input_pending_double_click.remove(ctx_id)
  self.input_action_clock_ms.remove(ctx_id)
  true
}
