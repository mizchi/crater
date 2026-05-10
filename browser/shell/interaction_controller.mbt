///|
fn cell_to_client_x(col : Int) -> Int {
  col * 8 + 4
}

///|
fn cell_to_client_y(row : Int) -> Int {
  let viewport_row = if row > 0 { row } else { 0 }
  viewport_row * 16 + 8
}

///|
fn Browser::get_client_coords_for_source_id(
  self : Browser,
  source_id : String,
) -> (Int, Int)? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.source_id == source_id {
      let center_col = region.col + region.width / 2
      let center_row = region.row + region.height / 2
      return Some((cell_to_client_x(center_col), cell_to_client_y(center_row)))
    }
    i = i - 1
  }
  None
}

///|
fn Browser::get_hit_region_for_source_id(
  self : Browser,
  source_id : String,
) -> @tui.HitRegion? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.source_id == source_id {
      return Some(region)
    }
    i = i - 1
  }
  None
}

///|
pub async fn Browser::handle_focused_key(
  self : Browser,
  key : String,
) -> Bool raise @http.HttpError {
  let source_id = self.get_focused_source_id()
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      match self.dispatch_focused_key_to_source_id(id, key) {
        Handled => true
        Activate => self.activate_focused_link()
        Submit =>
          match self.dispatch_submit_to_source_id(id) {
            Prevented => true
            Handled => true
            Navigate(request) => {
              let resolved_request = {
                ..request,
                url: resolve_url(self.current_url, request.url),
              }
              let _ = self.navigate_request(resolved_request)
              true
            }
            NotSubmittable => true
          }
        NotHandled => false
      }
    }
    None => false
  }
}

///|
pub async fn Browser::activate_focused_link(
  self : Browser,
) -> Bool raise @http.HttpError {
  let source_id = self.get_focused_source_id()
  let href = self.get_focused_link_url()
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      let (client_x, client_y) = match
        self.get_client_coords_for_source_id(id) {
        Some(coords) => coords
        None => (0, 0)
      }
      let dispatch = self.dispatch_click_to_source_id(id, client_x~, client_y~)
      if !dispatch.allow_default {
        return true
      }
      if self.dispatch_activation_default_to_source_id(id) {
        return true
      }
      match self.dispatch_submit_to_source_id(id, client_x~, client_y~) {
        Prevented => return true
        Handled => return true
        Navigate(request) => {
          let resolved_request = {
            ..request,
            url: resolve_url(self.current_url, request.url),
          }
          let _ = self.navigate_request(resolved_request)
          return true
        }
        NotSubmittable => ()
      }
      if href is None && dispatch.handled {
        return true
      }
    }
    None => ()
  }
  match href {
    Some(url) if url.length() > 0 => {
      let _ = self.navigate(url)
      true
    }
    _ => false
  }
}

///|
pub fn Browser::hover_at(self : Browser, col : Int, row : Int) -> Bool {
  let next_source_id = self.get_hover_source_id_at(col, row)
  let changed = self.dispatch_hover_transition(
    self.hovered_source_id,
    next_source_id,
    cell_to_client_x(col),
    cell_to_client_y(row),
  )
  self.hovered_source_id = next_source_id
  changed
}

///|
pub fn Browser::pointer_down_at(self : Browser, col : Int, row : Int) -> Bool {
  let source_id = self.get_hover_source_id_at(col, row)
  self.hovered_source_id = source_id
  self.dragging_source_id = None
  self.drag_over_source_id = None
  self.drop_allowed_source_id = None
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      if self.set_text_control_caret_from_cell(id, col, row) {
        self.text_selection_anchor_source_id = Some(id)
        self.text_selection_anchor_col = col
        self.text_selection_anchor_row = row
      } else {
        self.text_selection_anchor_source_id = None
      }
      self.pressed_source_id = Some(id)
      self.dispatch_pointer_mouse_event_to_source_id(
        id,
        "pointerdown",
        "mousedown",
        cell_to_client_x(col),
        cell_to_client_y(row),
      )
    }
    None => {
      self.pressed_source_id = None
      self.text_selection_anchor_source_id = None
      false
    }
  }
}

///|
pub fn Browser::pointer_move_at(self : Browser, col : Int, row : Int) -> Bool {
  let client_x = cell_to_client_x(col)
  let client_y = cell_to_client_y(row)
  let mut changed = self.hover_at(col, row)
  match self.pressed_source_id {
    Some(pressed_id) => {
      match self.text_selection_anchor_source_id {
        Some(anchor_source_id) if anchor_source_id == pressed_id &&
          self.dragging_source_id is None =>
          if self.set_text_control_selection_from_cells(
              pressed_id,
              self.text_selection_anchor_col,
              self.text_selection_anchor_row,
              col,
              row,
            ) {
            changed = true
          }
        _ => ()
      }
      if self.dragging_source_id is None &&
        self.is_draggable_source_id(pressed_id) {
        if self.dispatch_drag_event_to_source_id(
            pressed_id,
            "dragstart",
            client_x,
            client_y,
            related_source_id=None,
          ) {
          self.dragging_source_id = Some(pressed_id)
          changed = true
        }
      }
      match self.dragging_source_id {
        Some(drag_id) => {
          let plan = @interaction_policy.drag_move_target_plan(
            drag_id,
            self.drag_over_source_id.unwrap_or(""),
            self.get_hover_source_id_at(col, row).unwrap_or(""),
          )
          let next_target = if plan.over_target != "" {
            Some(plan.over_target)
          } else {
            None
          }
          if self.dispatch_drag_event_to_source_id(
              drag_id,
              "drag",
              client_x,
              client_y,
              related_source_id=next_target,
            ) {
            changed = true
          }
          if self.drag_over_source_id != next_target {
            self.drop_allowed_source_id = None
            match self.drag_over_source_id {
              Some(previous_target) if plan.emit_dragleave =>
                if self.dispatch_drag_event_to_source_id(
                    previous_target,
                    "dragleave",
                    client_x,
                    client_y,
                    related_source_id=next_target,
                  ) {
                  changed = true
                }
              _ => ()
            }
            match next_target {
              Some(next_id) if plan.emit_dragenter =>
                if self.dispatch_drag_event_to_source_id(
                    next_id,
                    "dragenter",
                    client_x,
                    client_y,
                    related_source_id=self.drag_over_source_id,
                  ) {
                  changed = true
                }
              _ => ()
            }
            self.drag_over_source_id = next_target
          }
          match self.drag_over_source_id {
            Some(target_id) if plan.emit_dragover => {
              let (handled_drag_over, canceled_drag_over) = self.dispatch_drag_event_status_to_source_id(
                target_id,
                "dragover",
                client_x,
                client_y,
                related_source_id=Some(drag_id),
              )
              if handled_drag_over {
                changed = true
              }
              let accepted_target = @interaction_policy.drag_accept_target(
                drag_id, target_id, canceled_drag_over,
              )
              self.drop_allowed_source_id = if accepted_target != "" {
                Some(accepted_target)
              } else {
                None
              }
            }
            _ => ()
          }
        }
        None => ()
      }
      changed
    }
    None => changed
  }
}

///|
pub async fn Browser::pointer_up_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  let client_x = cell_to_client_x(col)
  let client_y = cell_to_client_y(row)
  let up_source_id = self.get_hover_source_id_at(col, row)
  let pressed_source_id = self.pressed_source_id
  let dragging_source_id = self.dragging_source_id
  let drag_over_source_id = self.drag_over_source_id
  let drop_allowed_source_id = self.drop_allowed_source_id
  let mut handled = false
  match up_source_id {
    Some(id) =>
      if self.dispatch_pointer_mouse_event_to_source_id(
          id, "pointerup", "mouseup", client_x, client_y,
        ) {
        handled = true
      }
    None => ()
  }
  self.pressed_source_id = None
  self.text_selection_anchor_source_id = None
  self.dragging_source_id = None
  self.drag_over_source_id = None
  self.drop_allowed_source_id = None
  match dragging_source_id {
    Some(drag_id) => {
      let drop_target = @interaction_policy.drag_drop_target(
        drag_id,
        drag_over_source_id.unwrap_or(""),
        drop_allowed_source_id.unwrap_or(""),
      )
      match drag_over_source_id {
        Some(target_id) if drop_target == target_id &&
          self.is_current_drop_allowed() =>
          if self.dispatch_drag_event_to_source_id(
              target_id,
              "drop",
              client_x,
              client_y,
              related_source_id=Some(drag_id),
            ) {
            handled = true
          }
        _ => ()
      }
      if self.dispatch_drag_event_to_source_id(
          drag_id,
          "dragend",
          client_x,
          client_y,
          related_source_id=drag_over_source_id,
        ) {
        handled = true
      }
      return handled
    }
    None => ()
  }
  match (pressed_source_id, up_source_id) {
    (Some(down_id), Some(up_id)) if down_id == up_id => {
      let dispatch = self.dispatch_click_only_to_source_id(
        down_id, client_x, client_y,
      )
      if !dispatch.allow_default {
        return true
      }
      if self.dispatch_activation_default_to_source_id(down_id) {
        return true
      }
      match self.dispatch_submit_to_source_id(down_id, client_x~, client_y~) {
        Prevented => return true
        Handled => return true
        Navigate(request) => {
          let resolved_request = {
            ..request,
            url: resolve_url(self.current_url, request.url),
          }
          let _ = self.navigate_request(resolved_request)
          return true
        }
        NotSubmittable => ()
      }
      match self.get_href_for_source_id(down_id) {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(resolve_url(self.current_url, url))
          true
        }
        _ => handled || dispatch.handled
      }
    }
    _ => handled
  }
}

///|
pub async fn Browser::activate_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  let source_id = self.get_source_id_at(col, row)
  let href = match self.get_link_at(col, row) {
    Some(url) => Some(resolve_url(self.current_url, url))
    None =>
      match source_id {
        Some(id) => self.get_href_for_source_id(id)
        None => None
      }
  }
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      let _ = self.set_text_control_caret_from_cell(id, col, row)
      let dispatch = self.dispatch_click_to_source_id(
        id,
        client_x=cell_to_client_x(col),
        client_y=cell_to_client_y(row),
      )
      if !dispatch.allow_default {
        return true
      }
      if self.dispatch_activation_default_to_source_id(id) {
        return true
      }
      match
        self.dispatch_submit_to_source_id(
          id,
          client_x=cell_to_client_x(col),
          client_y=cell_to_client_y(row),
        ) {
        Prevented => return true
        Handled => return true
        Navigate(request) => {
          let resolved_request = {
            ..request,
            url: resolve_url(self.current_url, request.url),
          }
          let _ = self.navigate_request(resolved_request)
          return true
        }
        NotSubmittable => ()
      }
      match href {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(url)
          true
        }
        _ => dispatch.handled
      }
    }
    None =>
      match href {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(url)
          true
        }
        _ => false
      }
  }
}

///|
pub async fn Browser::activate_link_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  self.activate_at(col, row)
}
