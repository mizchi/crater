///|
/// Handle input.performActions.
fn BidiProtocol::handle_input_perform_actions(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(id) => id
    None => return false
  }
  let sources = match get_param_raw(params, "actions") {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id, "invalid argument", "actions must be an array",
      )
      return false
    }
  }

  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  let source_types : Array[String] = []
  let source_actions_list : Array[Array[Json]] = []
  let source_pointer_types : Array[String] = []

  for source in sources {
    let (source_type, source_actions, pointer_type) = match source {
      Object(source_map) => {
        let source_type = match source_map.get("type") {
          Some(String(t)) =>
            if t == "none" || t == "key" || t == "pointer" || t == "wheel" {
              t
            } else {
              self.send_error(
                request_id, "invalid argument", "input source type is invalid",
              )
              return false
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "input source type must be a string",
            )
            return false
          }
        }
        match source_map.get("id") {
          Some(String(_)) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "input source id must be a string",
            )
            return false
          }
        }
        let actions = match source_map.get("actions") {
          Some(Array(a)) => a
          _ => {
            self.send_error(
              request_id, "invalid argument", "input source actions must be an array",
            )
            return false
          }
        }
        let mut pointer_type = "mouse"
        if source_type == "pointer" {
          match source_map.get("parameters") {
            Some(Object(pointer_params)) =>
              match pointer_params.get("pointerType") {
                Some(String(pt)) =>
                  if pt == "mouse" || pt == "pen" || pt == "touch" {
                    pointer_type = pt
                  } else {
                    self.send_error(
                      request_id, "invalid argument", "pointerType is invalid",
                    )
                    return false
                  }
                Some(_) => {
                  self.send_error(
                    request_id, "invalid argument", "pointerType must be a string",
                  )
                  return false
                }
                None => ()
              }
            Some(_) => {
              self.send_error(
                request_id, "invalid argument", "pointer parameters must be an object",
              )
              return false
            }
            None => ()
          }
          self.input_pointer_type[ctx_id] = pointer_type
        }
        (source_type, actions, pointer_type)
      }
      _ => {
        self.send_error(
          request_id, "invalid argument", "input source must be an object",
        )
        return false
      }
    }
    source_types.push(source_type)
    source_actions_list.push(source_actions)
    source_pointer_types.push(pointer_type)
  }

  let mut max_ticks = 0
  for source_actions in source_actions_list {
    if source_actions.length() > max_ticks {
      max_ticks = source_actions.length()
    }
  }

  for tick in 0..<max_ticks {
    for source_idx in 0..<source_types.length() {
      let source_type = source_types[source_idx]
      let source_actions = source_actions_list[source_idx]
      let pointer_type = source_pointer_types[source_idx]
      if tick >= source_actions.length() {
        continue
      }
      let raw_action = source_actions[tick]

      if self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return false
      }
      let action_map = match raw_action {
        Object(m) => m
        _ => {
          self.send_error(
            request_id, "invalid argument", "action entry must be an object",
          )
          return false
        }
      }
      let action_type = match action_map.get("type") {
        Some(String(t)) => t
        _ => {
          self.send_error(
            request_id, "invalid argument", "action type must be a string",
          )
          return false
        }
      }

      if action_type == "pause" {
        let mut pause_duration_ms = 0
        match action_map.get("duration") {
          Some(duration) =>
            match json_as_safe_int(duration, 0.0, 9007199254740991.0) {
              Some(parsed) => pause_duration_ms = parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "pause duration must be a non-negative integer",
                )
                return false
              }
            }
          None => ()
        }
        self.input_action_clock_ms[ctx_id] = self.input_action_clock_ms
          .get(ctx_id)
          .unwrap_or(0.0) +
          pause_duration_ms.to_double()
        continue
      }

      match source_type {
        "none" => {
          self.send_error(
            request_id, "invalid argument", "none source supports only pause actions",
          )
          return false
        }
        "key" => {
          if action_type != "keyDown" && action_type != "keyUp" {
            self.send_error(
              request_id, "invalid argument", "key action type is invalid",
            )
            return false
          }
          let key_value = match action_map.get("value") {
            Some(String(v)) => v
            _ => {
              self.send_error(
                request_id, "invalid argument", "key action value must be a string",
              )
              return false
            }
          }
          if !input_is_single_grapheme(key_value) {
            self.send_error(
              request_id, "invalid argument", "key action value must be a single grapheme",
            )
            return false
          }
          let normalized_key = normalize_input_key(key_value)
          if action_type == "keyUp" &&
            !self.has_pressed_key(ctx_id, normalized_key) {
            continue
          }
          let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
            ctx_id,
            normalized_key,
            action_type == "keyDown",
          )
          dispatch_interaction_key_command(
            bidi_key_interaction_command(action_type, normalized_key),
            key_value,
            ctrl,
            alt,
            shift,
            meta,
          )
          if action_type == "keyDown" {
            if self.handle_inline_attribute_navigation(ctx_id, "onkeydown") {
              self.input_pressed_keys.remove(ctx_id)
              continue
            }
            if self.context_has_window_close_onkeydown(ctx_id) {
              if self.force_close_context_from_input(ctx_id) {
                self.send_error(
                  request_id,
                  "no such frame",
                  "Unknown context: " + ctx_id,
                )
                return false
              }
            }
            self.push_pressed_key(ctx_id, normalized_key)
          } else {
            self.remove_pressed_key(ctx_id, normalized_key)
          }
        }
        "pointer" => {
          if !(action_type == "pointerMove" ||
            action_type == "pointerDown" ||
            action_type == "pointerUp") {
            self.send_error(
              request_id, "invalid argument", "pointer action type is invalid",
            )
            return false
          }
          if !self.validate_pointer_common_properties(request_id, action_map) {
            return false
          }
          if action_type == "pointerMove" {
            let x = match action_map.get("x") {
              Some(value) =>
                match
                  json_as_safe_number(
                    value, -9007199254740991.0, 9007199254740991.0,
                  ) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointerMove x must be a number",
                    )
                    return false
                  }
                }
              None => {
                self.send_error(
                  request_id, "invalid argument", "pointerMove x is required",
                )
                return false
              }
            }
            let y = match action_map.get("y") {
              Some(value) =>
                match
                  json_as_safe_number(
                    value, -9007199254740991.0, 9007199254740991.0,
                  ) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointerMove y must be a number",
                    )
                    return false
                  }
                }
              None => {
                self.send_error(
                  request_id, "invalid argument", "pointerMove y is required",
                )
                return false
              }
            }
            let move_duration_ms = match action_map.get("duration") {
              Some(value) =>
                match json_as_safe_int(value, 0.0, 9007199254740991.0) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointerMove duration must be a non-negative integer",
                    )
                    return false
                  }
                }
              None => 0
            }
            self.input_action_clock_ms[ctx_id] = self.input_action_clock_ms
              .get(ctx_id)
              .unwrap_or(0.0) +
              move_duration_ms.to_double()
            let (final_x, final_y, origin_target_shared) = match
              self.resolve_pointer_origin(
                request_id,
                ctx_id,
                action_map.get("origin"),
                x,
                y,
                true,
              ) {
              Some(resolved) => resolved
              None => return false
            }
            let target_shared = if origin_target_shared != "" {
              origin_target_shared
            } else {
              get_runtime_shared_node_at_point(final_x, final_y).unwrap_or("")
            }
            if !self.ensure_pointer_within_viewport(
                request_id, final_x, final_y,
              ) {
              return false
            }
            let previous_target_shared = self.input_pointer_target_shared
              .get(ctx_id)
              .unwrap_or("")
            self.input_pointer_x[ctx_id] = final_x
            self.input_pointer_y[ctx_id] = final_y
            self.input_pointer_target_shared[ctx_id] = target_shared
            let buttons = self.input_pointer_buttons.get(ctx_id).unwrap_or(0)
            let width = match action_map.get("width") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let height = match action_map.get("height") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let pressure = match action_map.get("pressure") {
              Some(Number(n, ..)) => n
              _ =>
                if button_state_contains(buttons, button_to_mask(0)) {
                  0.5
                } else {
                  0.0
                }
            }
            let tangential_pressure = match
              action_map.get("tangentialPressure") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let twist = match action_map.get("twist") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 359.0).unwrap_or(0).to_double()
              None => 0.0
            }
            let altitude_angle = match action_map.get("altitudeAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let azimuth_angle = match action_map.get("azimuthAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            if button_state_contains(buttons, button_to_mask(0)) {
              let down_x = self.input_pointer_down_x
                .get(ctx_id)
                .unwrap_or(final_x)
              let down_y = self.input_pointer_down_y
                .get(ctx_id)
                .unwrap_or(final_y)
              let down_target = self.input_pointer_down_target_shared
                .get(ctx_id)
                .unwrap_or(target_shared)
              if abs_double(final_x - down_x) > 0.5 ||
                abs_double(final_y - down_y) > 0.5 ||
                down_target != target_shared {
                self.input_pointer_dragged[ctx_id] = true
              }
            }
            let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
              ctx_id, "", false,
            )
            input_set_pointer_event_properties(
              width, height, pressure, tangential_pressure, twist, altitude_angle,
              azimuth_angle,
            )
            let should_emit_move = pointer_type == "mouse" ||
              button_state_contains(buttons, button_to_mask(0))
            if should_emit_move {
              dispatch_interaction_hover_sequence(
                @interaction.pointer_hover_event_sequence(
                  pointer_type,
                  previous_target_shared != "" &&
                  previous_target_shared != target_shared,
                  target_shared != "" && previous_target_shared != target_shared,
                  target_shared != "",
                ),
                previous_target_shared,
                target_shared,
                final_x,
                final_y,
                buttons,
                pointer_type,
                ctrl,
                alt,
                shift,
                meta,
              )
            }
            if button_state_contains(buttons, button_to_mask(0)) {
              let drag_origin_x = self.input_pointer_down_x
                .get(ctx_id)
                .unwrap_or(final_x)
              let drag_origin_y = self.input_pointer_down_y
                .get(ctx_id)
                .unwrap_or(final_y)
              let drag_source = self.input_pointer_down_target_shared
                .get(ctx_id)
                .unwrap_or(
                  self.input_html_drag_source_shared.get(ctx_id).unwrap_or(""),
                )
              let drag_source = if drag_source != "" &&
                has_runtime_shared_node(drag_source) {
                drag_source
              } else {
                get_runtime_shared_node_at_point(drag_origin_x, drag_origin_y).unwrap_or(
                  drag_source,
                )
              }
              if drag_source != "" {
                self.input_html_drag_source_shared[ctx_id] = drag_source
              }
              if drag_source != "" {
                let drag_active = self.input_html_drag_active
                  .get(ctx_id)
                  .unwrap_or(false)
                let previous_drag_target = self.input_html_drag_over_shared
                  .get(ctx_id)
                  .unwrap_or("")
                let move_plan = @interaction.drag_move_target_plan(
                  drag_source, previous_drag_target, target_shared,
                )
                let drag_target = move_plan.over_target
                let drag_transfer_id = self.input_html_drag_transfer_id
                  .get(ctx_id)
                  .unwrap_or("")
                let mut dragover_prevented = false
                for
                  event in @interaction.drag_move_event_sequence(
                    emit_dragstart=!drag_active,
                    emit_dragleave=move_plan.emit_dragleave,
                    emit_dragenter=move_plan.emit_dragenter,
                    emit_dragover=move_plan.emit_dragover,
                  ) {
                  let dispatch_target = match event.target {
                    @interaction.Source => drag_source
                    @interaction.PreviousTarget => previous_drag_target
                    @interaction.CurrentTarget => drag_target
                  }
                  if dispatch_target == "" {
                    continue
                  }
                  let related_target = match event.target {
                    @interaction.Source => drag_target
                    @interaction.PreviousTarget => drag_target
                    @interaction.CurrentTarget =>
                      if previous_drag_target != "" {
                        previous_drag_target
                      } else {
                        drag_source
                      }
                  }
                  let prevented = input_dispatch_drag_event(
                    dispatch_target,
                    event.event_type,
                    final_x,
                    final_y,
                    0,
                    buttons,
                    pointer_type,
                    ctrl,
                    alt,
                    shift,
                    meta,
                    related_target,
                    drag_transfer_id,
                  )
                  if event.event_type == "dragover" {
                    dragover_prevented = prevented
                  }
                }
                self.input_html_drag_active[ctx_id] = true
                if drag_target != "" {
                  self.input_html_drag_over_shared[ctx_id] = drag_target
                } else {
                  self.input_html_drag_over_shared.remove(ctx_id)
                }
                let accepted_target = @interaction.drag_accept_target(
                  drag_source, drag_target, dragover_prevented,
                )
                if accepted_target != "" {
                  self.input_html_drag_accept_shared[ctx_id] = accepted_target
                } else {
                  self.input_html_drag_accept_shared.remove(ctx_id)
                }
              }
            }
            input_clear_pointer_event_properties()
          } else {
            let button = match action_map.get("button") {
              Some(value) =>
                match json_as_safe_int(value, 0.0, 9007199254740991.0) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointer button must be a non-negative integer",
                    )
                    return false
                  }
                }
              None => {
                self.send_error(
                  request_id, "invalid argument", "pointer button is required",
                )
                return false
              }
            }
            let current_x = self.input_pointer_x.get(ctx_id).unwrap_or(0.0)
            let current_y = self.input_pointer_y.get(ctx_id).unwrap_or(0.0)
            let target_shared = self.input_pointer_target_shared
              .get(ctx_id)
              .unwrap_or("")
            let old_buttons = self.input_pointer_buttons
              .get(ctx_id)
              .unwrap_or(0)
            let width = match action_map.get("width") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let height = match action_map.get("height") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let tangential_pressure = match
              action_map.get("tangentialPressure") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let twist = match action_map.get("twist") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 359.0).unwrap_or(0).to_double()
              None => 0.0
            }
            let altitude_angle = match action_map.get("altitudeAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let azimuth_angle = match action_map.get("azimuthAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            if action_type == "pointerDown" {
              let next_buttons = button_state_add(old_buttons, button)
              self.input_pointer_buttons[ctx_id] = next_buttons
              let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
                ctx_id, "", false,
              )
              let pressure = match action_map.get("pressure") {
                Some(Number(n, ..)) => n
                _ => if button == 0 { 0.5 } else { 0.0 }
              }
              input_set_pointer_event_properties(
                width, height, pressure, tangential_pressure, twist, altitude_angle,
                azimuth_angle,
              )
              dispatch_interaction_pointer_sequence(
                @interaction.pointer_press_event_sequence(pointer_type, button),
                target_shared,
                current_x,
                current_y,
                next_buttons,
                pointer_type,
                ctrl,
                alt,
                shift,
                meta,
              )
              input_clear_pointer_event_properties()
              if self.handle_inline_attribute_navigation(
                  ctx_id, "onpointerdown",
                ) {
                continue
              }
              if self.context_has_window_close_onpointerdown(ctx_id) {
                if !self.force_close_context_from_input(ctx_id) {
                  self.send_error(
                    request_id,
                    "no such frame",
                    "Unknown context: " + ctx_id,
                  )
                  return false
                }
              }
              if self.handle_inline_attribute_navigation(ctx_id, "onmousedown") {
                continue
              }
              if self.context_has_window_close_onmousedown(ctx_id) {
                if !self.force_close_context_from_input(ctx_id) {
                  self.send_error(
                    request_id,
                    "no such frame",
                    "Unknown context: " + ctx_id,
                  )
                  return false
                }
              }
              if button == 0 {
                self.input_pointer_down_x[ctx_id] = current_x
                self.input_pointer_down_y[ctx_id] = current_y
                self.input_pointer_down_target_shared[ctx_id] = target_shared
                self.input_pointer_dragged[ctx_id] = false
                if target_shared != "" &&
                  runtime_shared_node_is_draggable(target_shared) {
                  self.input_html_drag_source_shared[ctx_id] = target_shared
                  self.input_html_drag_active[ctx_id] = false
                  self.input_html_drag_over_shared.remove(ctx_id)
                  self.input_html_drag_accept_shared.remove(ctx_id)
                  self.input_html_drag_transfer_id[ctx_id] = ctx_id
                } else {
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
                }
                let now = self.input_action_clock_ms.get(ctx_id).unwrap_or(0.0)
                let pending_double_click = match
                  self.input_last_click_time.get(ctx_id) {
                  Some(last_time) => {
                    let last_target = self.input_last_click_target_shared
                      .get(ctx_id)
                      .unwrap_or("")
                    let last_x = self.input_last_click_x
                      .get(ctx_id)
                      .unwrap_or(-999999.0)
                    let last_y = self.input_last_click_y
                      .get(ctx_id)
                      .unwrap_or(-999999.0)
                    now - last_time <= 640.0 &&
                    last_target == target_shared &&
                    abs_double(current_x - last_x) <= 4.0 &&
                    abs_double(current_y - last_y) <= 4.0
                  }
                  None => false
                }
                self.input_pending_double_click[ctx_id] = pending_double_click
              } else {
                self.input_pending_double_click.remove(ctx_id)
              }
            } else {
              let next_buttons = button_state_remove(old_buttons, button)
              self.input_pointer_buttons[ctx_id] = next_buttons
              let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
                ctx_id, "", false,
              )
              input_set_pointer_event_properties(
                width, height, 0.0, tangential_pressure, twist, altitude_angle, azimuth_angle,
              )
              dispatch_interaction_pointer_sequence(
                @interaction.pointer_release_event_sequence(
                  pointer_type, button,
                ),
                target_shared,
                current_x,
                current_y,
                next_buttons,
                pointer_type,
                ctrl,
                alt,
                shift,
                meta,
              )
              input_clear_pointer_event_properties()
              let is_mac_ctrl_left_click = button == 0 &&
                ctrl &&
                input_is_mac_platform()
              if is_mac_ctrl_left_click {
                dispatch_interaction_pointer_sequence(
                  @interaction.pointer_post_release_mouse_event_sequence(
                    button, true, false, false,
                  ),
                  target_shared,
                  current_x,
                  current_y,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
                self.input_pending_double_click.remove(ctx_id)
                if button == 0 {
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
                }
              } else if button == 0 {
                let drag_origin_x = self.input_pointer_down_x
                  .get(ctx_id)
                  .unwrap_or(current_x)
                let drag_origin_y = self.input_pointer_down_y
                  .get(ctx_id)
                  .unwrap_or(current_y)
                let drag_source = self.input_pointer_down_target_shared
                  .get(ctx_id)
                  .unwrap_or(
                    self.input_html_drag_source_shared.get(ctx_id).unwrap_or(""),
                  )
                let drag_source = if drag_source != "" &&
                  has_runtime_shared_node(drag_source) {
                  drag_source
                } else {
                  get_runtime_shared_node_at_point(drag_origin_x, drag_origin_y).unwrap_or(
                    drag_source,
                  )
                }
                if drag_source != "" {
                  self.input_html_drag_source_shared[ctx_id] = drag_source
                }
                let drag_active = self.input_html_drag_active
                  .get(ctx_id)
                  .unwrap_or(false)
                let drag_over_target = self.input_html_drag_over_shared
                  .get(ctx_id)
                  .unwrap_or("")
                let drag_accept_target = self.input_html_drag_accept_shared
                  .get(ctx_id)
                  .unwrap_or("")
                let drag_transfer_id = self.input_html_drag_transfer_id
                  .get(ctx_id)
                  .unwrap_or("")
                if drag_source != "" && drag_active {
                  let drop_target = @interaction.drag_drop_target(
                    drag_source, drag_over_target, drag_accept_target,
                  )
                  let drop_allowed = if drop_target != "" {
                    let state = input_drag_transfer_state(drag_transfer_id)
                    match state.find("/") {
                      Some(idx) => {
                        let effect_allowed = state
                          .unsafe_substring(start=0, end=idx)
                          .to_lower()
                        let drop_effect = state
                          .unsafe_substring(start=idx + 1, end=state.length())
                          .to_lower()
                        @interaction.is_drop_effect_compatible(
                          effect_allowed, drop_effect,
                        )
                      }
                      None => false
                    }
                  } else {
                    false
                  }
                  for
                    event in @interaction.drag_release_event_sequence(
                      emit_drop=drop_allowed,
                    ) {
                    let dispatch_target = match event.target {
                      @interaction.Source => drag_source
                      @interaction.PreviousTarget => ""
                      @interaction.CurrentTarget => drop_target
                    }
                    if dispatch_target == "" {
                      continue
                    }
                    let related_target = match event.target {
                      @interaction.Source => drop_target
                      @interaction.PreviousTarget => ""
                      @interaction.CurrentTarget => drag_source
                    }
                    let _ = input_dispatch_drag_event(
                      dispatch_target,
                      event.event_type,
                      current_x,
                      current_y,
                      button,
                      next_buttons,
                      pointer_type,
                      ctrl,
                      alt,
                      shift,
                      meta,
                      related_target,
                      drag_transfer_id,
                    )
                  }
                }
                let was_dragged = self.input_pointer_dragged
                  .get(ctx_id)
                  .unwrap_or(false)
                dispatch_interaction_pointer_sequence(
                  @interaction.pointer_post_release_mouse_event_sequence(
                    button,
                    false,
                    !was_dragged,
                    !was_dragged &&
                    self.input_pending_double_click.get(ctx_id).unwrap_or(false),
                  ),
                  target_shared,
                  current_x,
                  current_y,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
                if !was_dragged {
                  self.input_last_click_time[ctx_id] = self.input_action_clock_ms
                    .get(ctx_id)
                    .unwrap_or(0.0)
                  self.input_last_click_x[ctx_id] = current_x
                  self.input_last_click_y[ctx_id] = current_y
                  self.input_last_click_target_shared[ctx_id] = target_shared
                  self.handle_pointer_click_navigation(
                    ctx_id, target_shared, current_x, current_y,
                  )
                }
                self.input_pending_double_click.remove(ctx_id)
                self.input_pointer_down_x.remove(ctx_id)
                self.input_pointer_down_y.remove(ctx_id)
                self.input_pointer_down_target_shared.remove(ctx_id)
                self.input_pointer_dragged.remove(ctx_id)
                self.input_html_drag_source_shared.remove(ctx_id)
                self.input_html_drag_active.remove(ctx_id)
                self.input_html_drag_over_shared.remove(ctx_id)
                self.input_html_drag_accept_shared.remove(ctx_id)
                if drag_transfer_id != "" {
                  input_clear_drag_transfer(drag_transfer_id)
                }
                self.input_html_drag_transfer_id.remove(ctx_id)
              } else if button == 2 {
                dispatch_interaction_pointer_sequence(
                  @interaction.pointer_post_release_mouse_event_sequence(
                    button, true, false, false,
                  ),
                  target_shared,
                  current_x,
                  current_y,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
                self.input_pending_double_click.remove(ctx_id)
              } else {
                dispatch_interaction_pointer_sequence(
                  @interaction.pointer_post_release_mouse_event_sequence(
                    button, false, false, false,
                  ),
                  target_shared,
                  current_x,
                  current_y,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
              }
            }
          }
        }
        "wheel" => {
          if action_type != "scroll" {
            self.send_error(
              request_id, "invalid argument", "wheel action type is invalid",
            )
            return false
          }
          let x = match action_map.get("x") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel x must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel x is required",
              )
              return false
            }
          }
          let y = match action_map.get("y") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel y must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel y is required",
              )
              return false
            }
          }
          let delta_x = match action_map.get("deltaX") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel deltaX must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel deltaX is required",
              )
              return false
            }
          }
          let delta_y = match action_map.get("deltaY") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel deltaY must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel deltaY is required",
              )
              return false
            }
          }
          let (final_x, final_y, target_shared) = match
            self.resolve_pointer_origin(
              request_id,
              ctx_id,
              action_map.get("origin"),
              x.to_double(),
              y.to_double(),
              false,
            ) {
            Some(resolved) => resolved
            None => return false
          }
          if !self.ensure_pointer_within_viewport(request_id, final_x, final_y) {
            return false
          }
          let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
            ctx_id, "", false,
          )
          input_dispatch_wheel_event(
            target_shared,
            final_x,
            final_y,
            delta_x.to_double(),
            delta_y.to_double(),
            ctrl,
            alt,
            shift,
            meta,
          )
        }
        _ => ()
      }
    }
  }
  true
}

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

///|
fn BidiProtocol::handle_input_record_synthetic_events(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) => ctx_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return
  }
  let events = match map.get("events") {
    Some(Array(events)) => events
    _ => {
      self.send_error(request_id, "invalid argument", "events must be an array")
      return
    }
  }
  let existing = self.input_synthetic_events_by_context
    .get(ctx_id)
    .unwrap_or([])
  for event in events {
    match event {
      Object(_) => existing.push(event)
      _ => {
        self.send_error(
          request_id, "invalid argument", "events entries must be objects",
        )
        return
      }
    }
  }
  self.input_synthetic_events_by_context[ctx_id] = existing
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_input_set_files(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return
  }
  let element = match map.get("element") {
    Some(Object(element)) => element
    _ => {
      self.send_error(
        request_id, "invalid argument", "element must be an object",
      )
      return
    }
  }
  let source_paths = match self.input_set_files_source_paths(request_id, map) {
    Some(values) => values
    None => return
  }
  let display_names = match
    self.input_set_files_display_names(request_id, map, source_paths) {
    Some(values) => values
    None => return
  }
  if source_paths.length() != display_names.length() {
    self.send_error(
      request_id, "invalid argument", "sourcePaths and displayNames must have the same length",
    )
    return
  }
  let (element_id, allow_fallback) = match
    self.resolve_input_set_files_locator(request_id, element) {
    Some(locator) => locator
    None => return
  }
  let summary = match
    self.apply_input_set_files_summary(
      ctx_id, element_id, allow_fallback, source_paths, display_names,
    ) {
    Some(summary) => summary
    None => {
      self.send_error(request_id, "no such element", "No such element")
      return
    }
  }
  let found = input_set_files_summary_bool(summary, "found")
  let is_element = input_set_files_summary_bool(summary, "isElement")
  let disabled = input_set_files_summary_bool(summary, "disabled")
  let multiple = input_set_files_summary_bool(summary, "multiple")
  let tag_name = input_set_files_summary_string(summary, "tagName").unwrap_or(
    "",
  )
  let input_type = input_set_files_summary_string(summary, "inputType").unwrap_or(
    "",
  )

  if !found || !is_element {
    self.send_error(request_id, "no such element", "No such element")
    return
  }
  if tag_name != "input" ||
    input_type != "file" ||
    disabled ||
    (source_paths.length() > 1 && !multiple) {
    self.send_error(
      request_id, "unable to set file input", "Unable to set file input",
    )
    return
  }

  let event_files = match
    input_set_files_summary_string_list(summary, "eventFiles") {
    Some(values) => values
    None => display_names
  }
  match input_set_files_summary_string_list(summary, "eventTypes") {
    Some(event_types) =>
      if event_types.length() > 0 {
        self.append_input_synthetic_events(ctx_id, event_types, event_files)
      }
    None => ()
  }
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::append_input_synthetic_events(
  self : BidiProtocol,
  ctx_id : String,
  event_types : Array[String],
  event_files : Array[String],
) -> Unit {
  let existing = self.input_synthetic_events_by_context
    .get(ctx_id)
    .unwrap_or([])
  let files_json : Array[Json] = []
  for file_name in event_files {
    files_json.push(Json::string(file_name))
  }
  for event_type in event_types {
    existing.push(
      make_object({
        "type": Json::string(event_type),
        "files": Json::array(files_json),
      }),
    )
  }
  self.input_synthetic_events_by_context[ctx_id] = existing
}

///|
fn BidiProtocol::handle_input_is_file_dialog_canceled_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return
  }
  let handler = self.resolve_unhandled_prompt_handler(ctx_id, "file")
  self.send_success(request_id, Some(Json::boolean(handler != "ignore")))
}

///|
fn BidiProtocol::resolve_input_set_files_locator(
  self : BidiProtocol,
  request_id : Int,
  element : Map[String, Json],
) -> (String, Bool)? {
  match element.get("type") {
    Some(String(type_name)) if type_name == "null" => return Some(("", true))
    _ => ()
  }
  let value_map = match element.get("value") {
    Some(Object(value_map)) => Some(value_map)
    _ => None
  }
  let shared_id = match element.get("sharedId") {
    Some(String(shared_id)) => Some(shared_id)
    _ =>
      match value_map {
        Some(value_map) =>
          match value_map.get("sharedId") {
            Some(String(shared_id)) => Some(shared_id)
            _ => None
          }
        None => None
      }
  }
  let shared_id = match shared_id {
    Some(shared_id) => shared_id
    None => {
      self.send_error(
        request_id, "invalid argument", "element.sharedId must be a string",
      )
      return None
    }
  }
  match value_map {
    Some(value_map) =>
      match value_map.get("nodeType") {
        Some(Number(node_type, ..)) if node_type != 1.0 => {
          self.send_error(request_id, "no such element", "No such element")
          return None
        }
        _ => ()
      }
    None => ()
  }
  if !has_runtime_shared_node(shared_id) {
    self.send_error(
      request_id,
      "no such node",
      "Unknown sharedId: " + shared_id,
    )
    return None
  }
  if !runtime_shared_node_is_element(shared_id) {
    self.send_error(request_id, "no such element", "No such element")
    return None
  }
  let element_id = match value_map {
    Some(value_map) =>
      match value_map.get("attributes") {
        Some(Object(attributes)) =>
          match attributes.get("id") {
            Some(String(element_id)) => element_id
            _ => ""
          }
        _ => ""
      }
    None => ""
  }
  Some((element_id, false))
}

///|
fn BidiProtocol::apply_input_set_files_summary(
  self : BidiProtocol,
  ctx_id : String,
  element_id : String,
  allow_fallback : Bool,
  source_paths : Array[String],
  display_names : Array[String],
) -> Map[String, Json]? {
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let source_paths_json : Array[Json] = []
  for path in source_paths {
    source_paths_json.push(Json::string(path))
  }
  let display_names_json : Array[Json] = []
  for name in display_names {
    display_names_json.push(Json::string(name))
  }
  let payload = js_input_apply_file_selection(
    element_id,
    allow_fallback,
    Json::array(source_paths_json).stringify(),
    Json::array(display_names_json).stringify(),
  )
  let summary = @json.parse(payload) catch { _ => return None }
  match summary {
    Object(summary) => Some(summary)
    _ => None
  }
}

///|
/// Validate input context parameter and return context ID.
fn BidiProtocol::validate_input_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let ctx_id = match get_param_raw(params, "context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }
  Some(ctx_id)
}

///|
fn BidiProtocol::input_set_files_string_array(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json?,
  field_name : String,
) -> Array[String]? {
  let items = match raw_value {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an array",
      )
      return None
    }
  }
  let values : Array[String] = []
  for item in items {
    match item {
      String(value) => values.push(value)
      _ => {
        self.send_error(
          request_id,
          "invalid argument",
          field_name + " entries must be strings",
        )
        return None
      }
    }
  }
  Some(values)
}

///|
fn BidiProtocol::input_set_files_source_paths(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
) -> Array[String]? {
  match map.get("files") {
    Some(raw_value) =>
      self.input_set_files_string_array(request_id, Some(raw_value), "files")
    None =>
      self.input_set_files_string_array(
        request_id,
        map.get("sourcePaths"),
        "sourcePaths",
      )
  }
}

///|
fn BidiProtocol::input_set_files_display_names(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
  source_paths : Array[String],
) -> Array[String]? {
  match map.get("displayNames") {
    Some(raw_value) =>
      self.input_set_files_string_array(
        request_id,
        Some(raw_value),
        "displayNames",
      )
    None => Some(input_set_files_default_display_names(source_paths))
  }
}

///|
fn input_set_files_default_display_names(
  source_paths : Array[String],
) -> Array[String] {
  let display_names : Array[String] = []
  for source_path in source_paths {
    display_names.push(input_set_files_display_name(source_path))
  }
  display_names
}

///|
fn input_set_files_display_name(source_path : String) -> String {
  let mut last_separator = -1
  let mut search_from = 0
  while search_from < source_path.length() {
    match find_substring(source_path, "/", search_from) {
      Some(idx) => {
        last_separator = idx
        search_from = idx + 1
      }
      None => break
    }
  }
  search_from = 0
  while search_from < source_path.length() {
    match find_substring(source_path, "\\", search_from) {
      Some(idx) => {
        if idx > last_separator {
          last_separator = idx
        }
        search_from = idx + 1
      }
      None => break
    }
  }
  if last_separator < 0 {
    return source_path
  }
  let base_name = source_path.unsafe_substring(
    start=last_separator + 1,
    end=source_path.length(),
  )
  if base_name.length() == 0 {
    return source_path
  }
  base_name
}

///|
fn input_set_files_summary_bool(
  summary : Map[String, Json],
  key : String,
) -> Bool {
  match summary.get(key) {
    Some(True) => true
    Some(False) => false
    _ => false
  }
}

///|
fn input_set_files_summary_string(
  summary : Map[String, Json],
  key : String,
) -> String? {
  match summary.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn input_set_files_summary_string_list(
  summary : Map[String, Json],
  key : String,
) -> Array[String]? {
  let items = match summary.get(key) {
    Some(Array(items)) => items
    _ => return None
  }
  let values : Array[String] = []
  for item in items {
    match item {
      String(value) => values.push(value)
      _ => ()
    }
  }
  Some(values)
}

///|
/// Validate pointer common property types/ranges.
fn BidiProtocol::validate_pointer_common_properties(
  self : BidiProtocol,
  request_id : Int,
  action_map : Map[String, Json],
) -> Bool {
  match action_map.get("width") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer width must be a non-negative integer",
        )
        return false
      }
    None => ()
  }
  match action_map.get("height") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer height must be a non-negative integer",
        )
        return false
      }
    None => ()
  }
  match action_map.get("pressure") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer pressure must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("tangentialPressure") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer tangentialPressure must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("twist") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 359.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer twist must be an integer in [0, 359]",
        )
        return false
      }
    None => ()
  }
  match action_map.get("altitudeAngle") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer altitudeAngle must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("azimuthAngle") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer azimuthAngle must be a number",
      )
      return false
    }
    None => ()
  }
  true
}

///|
/// Resolve pointer/wheel origin with integer offsets.
fn BidiProtocol::resolve_pointer_origin(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  origin : Json?,
  offset_x : Double,
  offset_y : Double,
  allow_pointer_origin : Bool,
) -> (Double, Double, String)? {
  match origin {
    None | Some(String("viewport")) => Some((offset_x, offset_y, ""))
    Some(String("pointer")) =>
      if allow_pointer_origin {
        Some(
          (
            self.input_pointer_x.get(ctx_id).unwrap_or(0.0) + offset_x,
            self.input_pointer_y.get(ctx_id).unwrap_or(0.0) + offset_y,
            self.input_pointer_target_shared.get(ctx_id).unwrap_or(""),
          ),
        )
      } else {
        self.send_error(
          request_id, "invalid argument", "pointer origin is not supported for this action",
        )
        None
      }
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport', 'pointer', or element origin",
      )
      None
    }
    Some(Object(origin_map)) => {
      let origin_type = match origin_map.get("type") {
        Some(String(s)) => s
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.type must be a string",
          )
          return None
        }
      }
      if origin_type != "element" {
        self.send_error(
          request_id, "invalid argument", "origin.type must be 'element'",
        )
        return None
      }
      let element_obj = match origin_map.get("element") {
        Some(Object(elem)) => elem
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.element must be an object",
          )
          return None
        }
      }
      let shared_id = match element_obj.get("sharedId") {
        Some(String(id)) => id
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.element.sharedId must be a string",
          )
          return None
        }
      }
      if !has_runtime_shared_node(shared_id) ||
        !runtime_shared_node_is_element(shared_id) {
        self.send_error(
          request_id,
          "no such element",
          "Unknown element: " + shared_id,
        )
        return None
      }
      let center_json = @json.parse(
        get_runtime_shared_node_center_json(shared_id),
      ) catch {
        _ => make_object({})
      }
      let center_x = match get_field(center_json, "x") {
        Some(Number(n, ..)) => n
        _ => 0.0
      }
      let center_y = match get_field(center_json, "y") {
        Some(Number(n, ..)) => n
        _ => 0.0
      }
      Some((center_x + offset_x, center_y + offset_y, shared_id))
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "origin must be a string or object",
      )
      None
    }
  }
}

///|
/// Validate pointer target coordinates against viewport.
fn BidiProtocol::ensure_pointer_within_viewport(
  self : BidiProtocol,
  request_id : Int,
  x : Double,
  y : Double,
) -> Bool {
  if x < 0.0 || y < 0.0 || x > 1024.0 || y > 768.0 {
    self.send_error(
      request_id, "move target out of bounds", "Target coordinate is outside viewport",
    )
    false
  } else {
    true
  }
}

///|
/// Absolute value helper for doubles.
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
/// Parse safe integer JSON value.
fn json_as_safe_int(value : Json, min : Double, max : Double) -> Int? {
  match value {
    Number(n, ..) =>
      if n == n.to_int64().to_double() && n >= min && n <= max {
        Some(n.to_int64().to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse safe JSON number value.
fn json_as_safe_number(value : Json, min : Double, max : Double) -> Double? {
  match value {
    Number(n, ..) => if n >= min && n <= max { Some(n) } else { None }
    _ => None
  }
}

///|
/// Normalize WebDriver special key value for internal state tracking.
fn normalize_input_key(value : String) -> String {
  match value {
    "\uE003" => "Backspace"
    "\uE004" => "Tab"
    "\uE006" | "\uE007" => "Enter"
    "\uE008" | "\uE050" => "Shift"
    "\uE009" | "\uE051" => "Control"
    "\uE00A" | "\uE052" => "Alt"
    "\uE00C" => "Escape"
    "\uE03D" | "\uE053" => "Meta"
    _ => value
  }
}

///|
/// Convert normalized key names back to WebDriver key values for dispatch.
fn restore_input_key_for_dispatch(value : String) -> String {
  match value {
    "Shift" => "\uE008"
    "Control" => "\uE009"
    "Alt" => "\uE00A"
    "Meta" => "\uE03D"
    "Enter" => "\uE006"
    "Escape" => "\uE00C"
    _ => value
  }
}

///|
/// Push pressed key in stack order.
fn BidiProtocol::push_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Unit {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  keys.push(key)
  self.input_pressed_keys[ctx_id] = keys
}

///|
/// Check whether key is currently pressed in the context.
fn BidiProtocol::has_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Bool {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  for existing in keys {
    if existing == key {
      return true
    }
  }
  false
}

///|
/// Remove first matching pressed key.
fn BidiProtocol::remove_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Unit {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let filtered : Array[String] = []
  let mut removed = false
  for existing in keys {
    if !removed && existing == key {
      removed = true
    } else {
      filtered.push(existing)
    }
  }
  if filtered.length() == 0 {
    self.input_pressed_keys.remove(ctx_id)
  } else {
    self.input_pressed_keys[ctx_id] = filtered
  }
}

///|
/// Resolve modifier booleans from pressed key state.
fn BidiProtocol::resolve_input_modifiers(
  self : BidiProtocol,
  ctx_id : String,
  current_key : String,
  include_current : Bool,
) -> (Bool, Bool, Bool, Bool) {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let mut ctrl = false
  let mut alt = false
  let mut shift = false
  let mut meta = false
  for key in keys {
    if key == "Control" {
      ctrl = true
    } else if key == "Alt" {
      alt = true
    } else if key == "Shift" {
      shift = true
    } else if key == "Meta" {
      meta = true
    }
  }
  if include_current {
    if current_key == "Control" {
      ctrl = true
    } else if current_key == "Alt" {
      alt = true
    } else if current_key == "Shift" {
      shift = true
    } else if current_key == "Meta" {
      meta = true
    }
  }
  (ctrl, alt, shift, meta)
}

///|
/// Convert pointer button to bit mask compatible with MouseEvent.buttons.
fn button_to_mask(button : Int) -> Int {
  match button {
    0 => 1
    1 => 4
    2 => 2
    _ => 0
  }
}

///|
/// Check whether button bit mask exists in state.
fn button_state_contains(state : Int, mask : Int) -> Bool {
  if mask == 1 {
    state % 2 == 1
  } else if mask == 2 {
    state / 2 % 2 == 1
  } else if mask == 4 {
    state / 4 % 2 == 1
  } else {
    false
  }
}

///|
/// Add button into button state bitfield.
fn button_state_add(state : Int, button : Int) -> Int {
  let mask = button_to_mask(button)
  if mask == 0 || button_state_contains(state, mask) {
    state
  } else {
    state + mask
  }
}

///|
/// Remove button from button state bitfield.
fn button_state_remove(state : Int, button : Int) -> Int {
  let mask = button_to_mask(button)
  if mask == 0 || !button_state_contains(state, mask) {
    state
  } else {
    state - mask
  }
}

///|
fn evaluate_current_file_input_remote_value() -> Json? {
  let eval_result_json = evaluate_js_with_console(
    "(() => { const input = document.getElementById(\"input\"); return input ?? null; })()",
    false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return None }
  match get_string_field(eval_result, "type") {
    Some("success") => get_field(eval_result, "result")
    _ => None
  }
}

///|
fn evaluate_current_file_input_multiple() -> Bool {
  let eval_result_json = evaluate_js_with_console(
    "(() => { const input = document.getElementById(\"input\"); return Boolean(input && (input.multiple || (typeof input.hasAttribute === \"function\" && input.hasAttribute(\"multiple\")))); })()",
    false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return false }
  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(remote_value) =>
          remote_value_as_bool(remote_value).unwrap_or(false)
        None => false
      }
    _ => false
  }
}

///|
extern "js" fn js_input_apply_file_selection(
  element_id : String,
  allow_fallback : Bool,
  source_paths_json : String,
  display_names_json : String,
) -> String =
  #| (elementId, allowFallback, sourcePathsJson, displayNamesJson) => {
  #|   const sourcePaths = (() => {
  #|     try {
  #|       const value = JSON.parse(String(sourcePathsJson ?? "[]"));
  #|       return Array.isArray(value) ? value.map(path => String(path)) : [];
  #|     } catch (_) {
  #|       return [];
  #|     }
  #|   })();
  #|   const displayNames = (() => {
  #|     try {
  #|       const value = JSON.parse(String(displayNamesJson ?? "[]"));
  #|       return Array.isArray(value) ? value.map(name => String(name)) : [];
  #|     } catch (_) {
  #|       return [];
  #|     }
  #|   })();
  #|   let input = null;
  #|   if (typeof document !== "undefined" && typeof elementId === "string" && elementId !== "") {
  #|     input = document.getElementById(elementId);
  #|   }
  #|   if (!input && allowFallback && typeof document !== "undefined") {
  #|     input = document.querySelector("input[type=file], #input");
  #|   }
  #|   if (!input && allowFallback && typeof document !== "undefined" && document.body && typeof document.createElement === "function") {
  #|     input = document.createElement("input");
  #|     input.type = "file";
  #|     input.id = "input";
  #|     document.body.appendChild(input);
  #|   }
  #|   if (!input) {
  #|     return JSON.stringify({
  #|       found: false,
  #|       isElement: false,
  #|       tagName: "",
  #|       inputType: "",
  #|       disabled: false,
  #|       multiple: false,
  #|       eventTypes: [],
  #|       eventFiles: [],
  #|     });
  #|   }
  #|   const isElement = Number(input?.nodeType || 0) === 1;
  #|   const tagName = isElement ? String(input.localName || input.tagName || "").toLowerCase() : "";
  #|   const getAttr = (name) => typeof input?.getAttribute === "function" ? input.getAttribute(name) : null;
  #|   const inputType = isElement && tagName === "input" ? String(input.type || getAttr("type") || "").toLowerCase() : "";
  #|   const disabled = isElement && tagName === "input" ? (Boolean(input.disabled) || getAttr("disabled") !== null) : false;
  #|   const multiple = isElement && tagName === "input" ? (Boolean(input.multiple) || getAttr("multiple") !== null) : false;
  #|   const summary = {
  #|     found: true,
  #|     isElement,
  #|     tagName,
  #|     inputType,
  #|     disabled,
  #|     multiple,
  #|     eventTypes: [],
  #|     eventFiles: [],
  #|   };
  #|   if (!isElement || tagName !== "input" || inputType !== "file" || disabled || (!multiple && sourcePaths.length > 1)) {
  #|     return JSON.stringify(summary);
  #|   }
  #|   summary.eventFiles = displayNames.slice();
  #|   const previousSourcePaths = Array.isArray(input.__craterSyntheticSourcePaths) ? input.__craterSyntheticSourcePaths.slice() : [];
  #|   const isSameSelection = previousSourcePaths.length === sourcePaths.length && previousSourcePaths.every((path, index) => path === sourcePaths[index]);
  #|   const syntheticFiles = displayNames.map(name => ({ name }));
  #|   try {
  #|     Object.defineProperty(input, "files", {
  #|       configurable: true,
  #|       get: () => syntheticFiles,
  #|     });
  #|   } catch (_) {
  #|     input.files = syntheticFiles;
  #|   }
  #|   input.__craterSyntheticSourcePaths = sourcePaths.slice();
  #|   const eventBuffer = (() => {
  #|     if (typeof window === "undefined") return null;
  #|     if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|       window.allEvents = { events: [] };
  #|     }
  #|     return window.allEvents.events;
  #|   })();
  #|   const recordEvent = (type) => {
  #|     if (!Array.isArray(eventBuffer)) return;
  #|     eventBuffer.push({ type, files: displayNames.slice() });
  #|   };
  #|   const emit = (type) => {
  #|     if (typeof Event === "function") {
  #|       input.dispatchEvent(new Event(type, { bubbles: true }));
  #|       return;
  #|     }
  #|     if (typeof document !== "undefined" && typeof document.createEvent === "function") {
  #|       const event = document.createEvent("Event");
  #|       event.initEvent(type, true, false);
  #|       input.dispatchEvent(event);
  #|     }
  #|   };
  #|   if (isSameSelection) {
  #|     emit("cancel");
  #|     recordEvent("cancel");
  #|     summary.eventTypes = ["cancel"];
  #|     return JSON.stringify(summary);
  #|   }
  #|   emit("input");
  #|   emit("change");
  #|   recordEvent("input");
  #|   recordEvent("change");
  #|   summary.eventTypes = ["input", "change"];
  #|   return JSON.stringify(summary);
  #| }

///|
fn BidiProtocol::emit_input_file_dialog_opened(
  self : BidiProtocol,
  ctx_id : String,
  multiple : Bool,
  element : Json?,
) -> Unit {
  let event_name = "input.fileDialogOpened"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "multiple": Json::boolean(multiple),
  }
  match element {
    Some(element_value) => params["element"] = element_value
    None => ()
  }
  self.outbox.push(
    Event({ event_method: event_name, params: make_object(params) }),
  )
}

///|
fn parse_show_open_file_picker_multiple(expression : String) -> Bool {
  expression.contains("multiple': true") ||
  expression.contains("\"multiple\": true")
}

///|
fn is_synthetic_file_dialog_cancel_probe(expression : String) -> Bool {
  let has_create_input = expression.contains("document.createElement('input')") ||
    expression.contains("document.createElement(\"input\")")
  let has_file_type = expression.contains("picker.type = 'file'") ||
    expression.contains("picker.type = \"file\"")
  let has_cancel_listener = expression.contains("addEventListener('cancel'") ||
    expression.contains("addEventListener(\"cancel\"")
  has_create_input &&
  has_file_type &&
  has_cancel_listener &&
  expression.contains("picker.click()")
}

///|
fn BidiProtocol::maybe_emit_file_dialog_opened_for_input(
  self : BidiProtocol,
  ctx_id : String,
  input_value : Json?,
) -> Unit {
  if !self.is_subscribed_for_context("input.fileDialogOpened", ctx_id) {
    return
  }
  let mut element : Json? = None
  match input_value {
    Some(value) => element = simplify_node_remote_value(value)
    None => ()
  }
  match element {
    Some(_) => ()
    None =>
      match evaluate_current_file_input_remote_value() {
        Some(value) => element = simplify_node_remote_value(value)
        None => ()
      }
  }
  match element {
    Some(element_value) =>
      self.emit_input_file_dialog_opened(
        ctx_id,
        evaluate_current_file_input_multiple(),
        Some(element_value),
      )
    None => ()
  }
}

///|
fn BidiProtocol::try_handle_synthetic_file_dialog_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
) -> Bool {
  let trimmed = expression.trim().to_owned()
  if trimmed.has_prefix("window.showOpenFilePicker(") {
    self.emit_input_file_dialog_opened(
      ctx_id,
      parse_show_open_file_picker_multiple(trimmed),
      None,
    )
    self.send_script_undefined_result(request_id, realm_id)
    return true
  }
  if is_synthetic_file_dialog_cancel_probe(trimmed) {
    let handler = self.resolve_unhandled_prompt_handler(ctx_id, "file")
    if handler == "ignore" {
      return true
    }
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("boolean"),
        "value": Json::boolean(true),
      }),
      unwrap_result,
    )
    return true
  }

  let handled_expression = match trimmed {
    "input.click()" =>
      Some(
        "(() => { const input = document.getElementById(\"input\"); if (input && typeof input.click === \"function\") { input.click(); } return undefined; })()",
      )
    "input.showPicker()" =>
      Some(
        "(() => { const input = document.getElementById(\"input\"); if (!input) return undefined; if (typeof input.showPicker === \"function\") { input.showPicker(); } else if (typeof input.click === \"function\") { input.click(); } return undefined; })()",
      )
    "input.click(); input" =>
      Some(
        "(() => { const input = document.getElementById(\"input\"); if (input && typeof input.click === \"function\") { input.click(); } return input ?? null; })()",
      )
    _ => None
  }

  let rewritten = match handled_expression {
    Some(rewritten) => rewritten
    None => return false
  }
  let eval_result = match
    self.evaluate_handled_script_expression(
      request_id, ctx_id, realm_id, rewritten, capture_console, user_activation,
      root_ownership, serialization_options_json,
    ) {
    Some(eval_result) => eval_result
    None => return true
  }

  let result_value = match get_string_field(eval_result, "type") {
    Some("success") => get_field(eval_result, "result")
    _ => None
  }
  self.maybe_emit_file_dialog_opened_for_input(ctx_id, result_value)

  if trimmed == "input.click(); input" {
    self.send_script_eval_result_mode(
      request_id, realm_id, eval_result, unwrap_result,
    )
  } else {
    self.send_script_undefined_response(request_id, realm_id, unwrap_result)
  }
  true
}
