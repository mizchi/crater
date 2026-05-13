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
