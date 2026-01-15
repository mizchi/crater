///|
/// TUI Application renderer with reactive signals integration
/// Provides ink-like API for building terminal UIs

///|
/// App manages the render loop and diff-based updates
pub struct App {
  width : Int
  height : Int
  mut prev_buffer : CharBuffer?
  pub mut last_layout : @node.Layout?
  handlers : EventHandlers
}

///|
pub fn App::new(width : Int, height : Int) -> App {
  {
    width,
    height,
    prev_buffer: None,
    last_layout: None,
    handlers: EventHandlers::new(),
  }
}

///|
/// Render a component tree to ANSI string
pub fn App::render(self : App, component : Component) -> String {
  // Compute layout
  let layout = compute_layout(component.node, self.width, self.height)

  // Save layout for hit testing
  self.last_layout = Some(layout)

  // Create new buffer
  let buf = CharBuffer::new(self.width, self.height)
  render_layout(buf, layout, component.styles, component.texts, 0, 0)

  // Generate output with diff if possible
  let output = match self.prev_buffer {
    Some(prev) => buffer_diff_to_ansi(buf, prev)
    None =>
      // First render: clear screen and render full
      ansi_clear_screen() + ansi_move_to(0, 0) + buffer_to_ansi(buf)
  }

  // Save current buffer for next diff
  self.prev_buffer = Some(buf)
  output
}

///|
/// Render with cursor hidden and positioned at origin
pub fn App::render_frame(self : App, component : Component) -> String {
  ansi_hide_cursor() + self.render(component)
}

///|
/// Create a reactive effect that re-renders when signals change
/// Returns a dispose function
pub fn App::create_render_effect(
  self : App,
  render_fn : () -> Component,
  output_fn : (String) -> Unit,
) -> () -> Unit {
  @signals.render_effect(fn() {
    let component = render_fn()
    let output = self.render_frame(component)
    output_fn(output)
  })
}

///|
/// Initialize terminal (enter alt screen, hide cursor)
pub fn App::init_terminal() -> String {
  ansi_enter_alt_screen() + ansi_hide_cursor() + ansi_clear_screen()
}

///|
/// Restore terminal (show cursor, leave alt screen)
pub fn App::restore_terminal() -> String {
  ansi_show_cursor() + ansi_leave_alt_screen()
}

///|
/// Full-screen app helper: sets up alt screen and handles cleanup
pub fn run_app(
  width : Int,
  height : Int,
  render_fn : () -> Component,
  output_fn : (String) -> Unit,
) -> () -> Unit {
  let app = App::new(width, height)

  // Initialize terminal
  output_fn(App::init_terminal())

  // Create render effect
  let dispose = app.create_render_effect(render_fn, output_fn)

  // Return cleanup function
  fn() {
    dispose()
    output_fn(App::restore_terminal())
  }
}

///|
/// Simple render function for one-shot rendering (no reactivity)
pub fn render_once(width : Int, height : Int, component : Component) -> String {
  let app = App::new(width, height)
  app.render(component)
}

///|
/// Register a click handler for a component ID
pub fn App::on_click(self : App, id : String, handler : () -> Unit) -> Unit {
  self.handlers.on_click(id, ClickHandler(handler))
}

///|
/// Handle a mouse event
/// Returns true if an event handler was invoked
pub fn App::handle_mouse(self : App, event : MouseEvent) -> Bool {
  match event.event_type {
    MouseEventType::Press =>
      match event.button {
        MouseButton::Left =>
          match self.last_layout {
            Some(layout) =>
              handle_click(layout, self.handlers, event.x, event.y)
            None => false
          }
        _ => false
      }
    _ => false
  }
}

///|
/// Perform hit test at coordinates
pub fn App::hit_test(self : App, x : Int, y : Int) -> HitTestResult? {
  match self.last_layout {
    Some(layout) => hit_test_root(layout, x, y)
    None => None
  }
}
