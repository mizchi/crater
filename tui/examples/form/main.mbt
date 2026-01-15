///|
/// Form example - demonstrates input/textarea components with IME support

///|
fn main {
  // Get terminal size
  let (cols, rows) = @tui.get_terminal_size()
  let width = cols
  let height = rows

  // Create reactive state
  let name = @signals.signal("")
  let email = @signals.signal("")
  let message = @signals.signal("")
  let focused_id = @signals.signal("")
  let running = @signals.signal(true)

  // Focus order
  let focusable_ids = [
    "name-input", "email-input", "message-textarea", "submit-btn",
  ]

  // Create the app
  let app = @tui.App::new(width, height)

  // Helper to get input state
  fn get_input_state(id : String) -> @c.InputState {
    if focused_id.get() == id {
      @c.InputState::Focused
    } else {
      @c.InputState::Idle
    }
  }

  // Helper to get textarea state
  fn get_textarea_state(id : String) -> @c.TextareaState {
    if focused_id.get() == id {
      @c.TextareaState::Focused
    } else {
      @c.TextareaState::Idle
    }
  }

  // Helper to get button state
  fn get_button_state(id : String) -> @c.ButtonState {
    if focused_id.get() == id {
      @c.ButtonState::Hover
    } else {
      @c.ButtonState::Normal
    }
  }

  // Render function that creates the component tree
  fn render_ui() -> @tui.Component {
    @c.column(
      [
        // Title
        @c.row(
          [
            @c.text(
              "Form Demo (IME Enabled)",
              fg=@tui.Color::yellow(),
              bold=true,
            ),
          ],
          justify=@style.Alignment::Center,
          margin_y=1.0,
        ),
        // Form fields
        @c.column(
          [
            // Name field
            @c.row(
              [
                @c.text("Name:    "),
                @c.input(
                  name.get(),
                  id="name-input",
                  placeholder="Enter your name",
                  state=get_input_state("name-input"),
                  min_width=30.0,
                ),
              ],
              margin_y=0.5,
            ),
            // Email field
            @c.row(
              [
                @c.text("Email:   "),
                @c.input(
                  email.get(),
                  id="email-input",
                  placeholder="user@example.com",
                  state=get_input_state("email-input"),
                  min_width=30.0,
                ),
              ],
              margin_y=0.5,
            ),
            // Message field (textarea)
            @c.row(
              [
                @c.text("Message: "),
                @c.textarea(
                  message.get(),
                  id="message-textarea",
                  placeholder="Enter your message...",
                  state=get_textarea_state("message-textarea"),
                  rows=4,
                  min_width=30.0,
                ),
              ],
              margin_y=0.5,
            ),
            // Submit button
            @c.row(
              [
                @c.hspace(9.0),
                @c.button(
                  "Submit",
                  id="submit-btn",
                  state=get_button_state("submit-btn"),
                  min_width=12.0,
                ),
              ],
              margin_y=1.0,
            ),
          ],
          padding=2.0,
        ),
        // Status bar
        @c.row(
          [
            @c.text(
              "Focus: " +
              (if focused_id.get() == "" { "none" } else { focused_id.get() }) +
              " | Tab: nav | Enter: edit | q: quit",
              fg=@tui.Color::rgb(100, 100, 100),
            ),
          ],
          justify=@style.Alignment::Center,
          margin_y=1.0,
        ),
      ],
      width=@types.Dimension::Length(width.to_double()),
      height=@types.Dimension::Length(height.to_double()),
      padding=1.0,
      border=Some(@tui.BorderChars::rounded()),
      border_color=@tui.Color::cyan(),
    )
  }

  // Focus navigation helpers
  fn focus_next() {
    let current = focused_id.get()
    if current == "" {
      focused_id.set(focusable_ids[0])
    } else {
      let idx = focusable_ids.search(current)
      match idx {
        Some(i) => {
          let next_idx = (i + 1) % focusable_ids.length()
          focused_id.set(focusable_ids[next_idx])
        }
        None => focused_id.set(focusable_ids[0])
      }
    }
  }

  fn focus_prev() {
    let current = focused_id.get()
    if current == "" {
      focused_id.set(focusable_ids[focusable_ids.length() - 1])
    } else {
      let idx = focusable_ids.search(current)
      match idx {
        Some(i) => {
          let prev_idx = if i == 0 { focusable_ids.length() - 1 } else { i - 1 }
          focused_id.set(focusable_ids[prev_idx])
        }
        None => focused_id.set(focusable_ids[focusable_ids.length() - 1])
      }
    }
  }

  // Render helper
  fn do_render() -> Unit {
    @tui.print_raw(app.render_frame(render_ui()))
  }

  // Handle keypress event
  fn handle_key(key : String) -> Unit {
    if key.length() == 0 {
      return
    }
    let event = @tui.parse_input(key)
    let mut need_render = true
    let mut start_edit_id = ""
    match event {
      @tui.InputEvent::Key(key_event) =>
        match key_event {
          // Quit on 'q' or Ctrl+C
          @tui.KeyEvent::Char('q', @tui.KeyModifier::None) => {
            running.set(false)
            @tui.stop_keypress_listener()
            @tui.print_raw(@tui.disable_mouse())
            @tui.cleanup_stdin()
            @tui.print_raw(@tui.App::restore_terminal())
          }
          @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => {
            running.set(false)
            @tui.stop_keypress_listener()
            @tui.print_raw(@tui.disable_mouse())
            @tui.cleanup_stdin()
            @tui.print_raw(@tui.App::restore_terminal())
          }
          // Tab navigation
          @tui.KeyEvent::Special(@tui.SpecialKey::Tab, @tui.KeyModifier::None) =>
            focus_next()
          @tui.KeyEvent::Special(
            @tui.SpecialKey::Tab
            | @tui.SpecialKey::BackTab,
            @tui.KeyModifier::Shift
          ) => focus_prev()
          @tui.KeyEvent::Special(
            @tui.SpecialKey::BackTab,
            @tui.KeyModifier::None
          ) => focus_prev()
          // Enter to start editing or submit
          @tui.KeyEvent::Special(@tui.SpecialKey::Enter, _) => {
            let focus = focused_id.get()
            if focus == "submit-btn" {
              // Handle submit
              running.set(false)
              @tui.stop_keypress_listener()
              @tui.print_raw(@tui.disable_mouse())
              @tui.cleanup_stdin()
              @tui.print_raw(@tui.App::restore_terminal())
              println("Form submitted!")
              println("Name: " + name.get())
              println("Email: " + email.get())
              println("Message: " + message.get())
            } else if focus != "" {
              start_edit_id = focus
              need_render = false
            }
          }
          // Escape to unfocus
          @tui.KeyEvent::Special(@tui.SpecialKey::Escape, _) =>
            focused_id.set("")
          // Arrow keys for navigation
          @tui.KeyEvent::Special(@tui.SpecialKey::Down, _) => focus_next()
          @tui.KeyEvent::Special(@tui.SpecialKey::Up, _) => focus_prev()
          _ => need_render = false
        }
      @tui.InputEvent::Mouse(mouse_event) =>
        match (mouse_event.event_type, mouse_event.button) {
          (@tui.MouseEventType::Press, @tui.MouseButton::Left) => {
            let x = mouse_event.x
            let y = mouse_event.y
            match app.hit_test(x, y) {
              Some(hit) =>
                if focusable_ids.contains(hit.id) {
                  focused_id.set(hit.id)
                }
              None => ()
            }
          }
          _ => need_render = false
        }
      _ => need_render = false
    }

    // Handle editing
    if start_edit_id != "" {
      start_editing(start_edit_id)
      return
    }

    // Re-render if needed
    if need_render && running.get() {
      do_render()
    }
  }

  // Start editing an input field (inline at field position)
  fn start_editing(id : String) -> Unit {
    // Stop listening for keypresses while editing
    @tui.stop_keypress_listener()

    // Get current value
    let current_value = if id == "name-input" {
      name.get()
    } else if id == "email-input" {
      email.get()
    } else if id == "message-textarea" {
      message.get()
    } else {
      ""
    }

    // Get the position and width of the input field
    let (input_row, input_col, input_width) = match app.find_by_id(id) {
      Some(result) => {
        // ANSI coordinates are 1-indexed, layout is 0-indexed
        // +1 for 0->1 indexing, +1 for border = +2
        (result.y + 2, result.x + 2, result.width - 2)
      }
      None => (10, 15, 30) // Fallback
    }

    // Stay in alt screen, prepare for inline input
    @tui.print_raw(@tui.disable_mouse())
    @tui.print_raw(@tui.ansi_move_to(input_row, input_col))

    // Clear placeholder area with spaces
    let spaces = " ".repeat(input_width)
    @tui.print_raw(spaces)
    @tui.print_raw(@tui.ansi_move_to(input_row, input_col))
    @tui.print_raw(@tui.ansi_show_cursor())

    // Start inline input session with current value pre-filled
    @tui.start_inline_input("", current_value, fn(result) {
      // Update value
      match result {
        @tui.InputResult::Confirmed(new_value) =>
          if id == "name-input" {
            name.set(new_value)
          } else if id == "email-input" {
            email.set(new_value)
          } else if id == "message-textarea" {
            message.set(new_value)
          }
        @tui.InputResult::Cancelled => ()
      }

      // Return to TUI mode
      @tui.print_raw(@tui.ansi_hide_cursor())
      @tui.print_raw(@tui.enable_mouse())
      app.clear_prev_buffer()
      do_render()

      // Resume keypress listening
      @tui.start_keypress_listener(handle_key)
    })
  }

  // Initialize terminal
  @tui.print_raw(@tui.App::init_terminal())
  @tui.print_raw(@tui.enable_mouse())

  // Initial render
  do_render()

  // Start event-driven keypress listener (this keeps the process alive)
  @tui.start_keypress_listener(handle_key)
}
