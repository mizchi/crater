///|
/// Get maximum scroll position
fn Browser::max_scroll(self : Browser) -> Int {
  (self.content_height - self.viewport_height).max(0)
}

///|
/// Scroll down
pub fn Browser::scroll_down(self : Browser, amount : Int) -> Unit {
  self.scroll_y = (self.scroll_y + amount).min(self.max_scroll())
}

///|
/// Scroll up
pub fn Browser::scroll_up(self : Browser, amount : Int) -> Unit {
  self.scroll_y = (self.scroll_y - amount).max(0)
}

///|
/// Initialize scroll state for an element
/// Call this when a scrollable element is detected
fn Browser::init_element_scroll(
  self : Browser,
  element_id : String,
  scroll_width : Double,
  scroll_height : Double,
  client_width : Double,
  client_height : Double,
) -> Unit {
  let state = @dom.ScrollState::new(
    scroll_width, scroll_height, client_width, client_height,
  )
  self.element_scroll_states.set(element_id, state)
}

///|
/// Clear all element scroll states (call on page navigation)
fn Browser::clear_element_scroll_states(self : Browser) -> Unit {
  self.element_scroll_states.clear()
  self.focused_scrollable.val = None
}

///|
/// Initialize scroll states from detected scrollable elements
/// Called during render to set up scroll states for elements with overflow
fn Browser::init_scrollable_elements(
  self : Browser,
  elements : Array[@tui_paint_runtime.ScrollableElement],
) -> Unit {
  for elem in elements {
    // Only initialize if not already tracked (preserve scroll position)
    if !self.element_scroll_states.contains(elem.id) {
      self.init_element_scroll(
        elem.id,
        elem.scroll_width,
        elem.scroll_height,
        elem.client_width,
        elem.client_height,
      )
    }
  }
}

///|
/// Convert element scroll states to TUI format for rendering
fn Browser::get_element_scroll_positions(
  self : Browser,
) -> Map[String, @tui.ElementScrollPos] {
  let result : Map[String, @tui.ElementScrollPos] = {}
  self.element_scroll_states.each(fn(id, state) {
    result.set(id, {
      scroll_top: state.scroll_top,
      scroll_height: state.scroll_height,
      client_height: state.client_height,
    })
  })
  result
}
