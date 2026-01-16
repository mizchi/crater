///|
/// Form example - demonstrates input components with IME support
/// Focus = Navigate, Enter = Edit (cooked mode with IME)

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

  // Focus order (inputs only, submit handled separately)
  let input_ids = ["name-input", "email-input", "message-textarea"]
  let focusable_ids = [
    "name-input", "email-input", "message-textarea", "submit-btn",
  ]

  // Create the app
  let app = @tui.App::new(width, height)

  // Field configurations for editing
  let field_configs : Map[String, (String, @signals.Signal[String])] = {
    "name-input": ("Name", name),
    "email-input": ("Email", email),
    "message-textarea": ("Message", message),
  }

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

  // Render function
  fn render_ui() -> @tui.Component {
    @c.column(
      [
        // Title
        @c.row(
          [
            @c.text(
              "Form Demo",
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
                  min_width=40.0,
                  min_height=3.0,
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
                  min_width=40.0,
                  min_height=3.0,
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
                  min_width=40.0,
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
              "Tab: next | Enter: edit/confirm | Esc: cancel | q: quit",
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

  // Restore TUI mode after editing
  fn restore_tui() -> Unit {
    @tui.print_raw(@tui.ansi_full_reset())
    @tui.print_raw(@tui.enable_mouse())
    app.clear_prev_buffer()
    do_render()
    @tui.start_keypress_listener(handle_key)
  }

  // Handle submit
  fn do_submit() -> Unit {
    running.set(false)
    @tui.stop_keypress_listener()
    @tui.print_raw(@tui.disable_mouse())
    @tui.cleanup_stdin()
    @tui.print_raw(@tui.App::restore_terminal())
    println("Form submitted!")
    println("Name: " + name.get())
    println("Email: " + email.get())
    println("Message: " + message.get())
  }

  // Start editing an input field using inplace editable API
  fn start_editing(id : String) -> Unit {
    match field_configs.get(id) {
      Some((field_name, signal)) => {
        // Get the element bounds for inplace editing
        match app.find_by_id(id) {
          Some(bounds) => {
            let config = @c.form_edit_config(
              field_name,
              signal,
              on_edit_start=Some(fn() {
                @tui.stop_keypress_listener()
                @tui.print_raw(@tui.disable_mouse())
              }),
            )
            // Calculate position for inplace editing
            // bounds.x/y are 0-indexed, ANSI coordinates are 1-indexed
            // +1 for 0-to-1 index conversion, +1 for border
            let row = bounds.y + 2 // +1 for 1-indexed, +1 for border
            let col = bounds.x + 2 // +1 for 1-indexed, +1 for border
            let content_width = bounds.width - 2 // Exclude left and right borders
            @c.start_edit_inplace(
              config,
              signal.get(),
              row,
              col,
              content_width,
              restore_tui,
            )
          }
          None => {
            // Fallback to cooked mode if bounds not found
            let config = @c.form_edit_config(
              field_name,
              signal,
              on_edit_start=Some(fn() {
                @tui.stop_keypress_listener()
                @tui.print_raw(@tui.disable_mouse())
              }),
            )
            @c.start_edit(config, signal.get(), restore_tui)
          }
        }
      }
      None => ()
    }
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
          // Ctrl+C - always quit
          @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => {
            running.set(false)
            @tui.stop_keypress_listener()
            @tui.print_raw(@tui.disable_mouse())
            @tui.cleanup_stdin()
            @tui.print_raw(@tui.App::restore_terminal())
          }
          // q to quit when not focused on input
          @tui.KeyEvent::Char('q', @tui.KeyModifier::None) =>
            if not(input_ids.contains(focused_id.get())) {
              running.set(false)
              @tui.stop_keypress_listener()
              @tui.print_raw(@tui.disable_mouse())
              @tui.cleanup_stdin()
              @tui.print_raw(@tui.App::restore_terminal())
            } else {
              need_render = false
            }
          // Tab - next focus
          @tui.KeyEvent::Special(@tui.SpecialKey::Tab, @tui.KeyModifier::None) =>
            focus_next()
          // Shift+Tab or BackTab - previous focus
          @tui.KeyEvent::Special(
            @tui.SpecialKey::Tab
            | @tui.SpecialKey::BackTab,
            @tui.KeyModifier::Shift
          ) => focus_prev()
          @tui.KeyEvent::Special(
            @tui.SpecialKey::BackTab,
            @tui.KeyModifier::None
          ) => focus_prev()
          // Escape - unfocus
          @tui.KeyEvent::Special(@tui.SpecialKey::Escape, _) =>
            focused_id.set("")
          // Enter - edit if on input, submit if on button
          @tui.KeyEvent::Special(@tui.SpecialKey::Enter, _) => {
            let focus = focused_id.get()
            if focus == "submit-btn" {
              do_submit()
              return
            } else if input_ids.contains(focus) {
              start_edit_id = focus
              need_render = false
            } else {
              focus_next()
            }
          }
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

  // Initialize terminal
  @tui.print_raw(@tui.App::init_terminal())
  @tui.print_raw(@tui.enable_mouse())

  // Initial render
  do_render()

  // Start event-driven keypress listener
  @tui.start_keypress_listener(handle_key)
}
