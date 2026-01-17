///|
/// Form example for native target - demonstrates input components with polling
/// Uses raw mode for navigation, blocks during editing

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
  let input_ids = ["name-input", "email-input", "message-textarea"]

  // Create the app
  let app = @tui.App::new(width, height)

  // Field configurations for editing
  let field_configs : Map[String, (String, @signals.Signal[String], Bool)] = {
    "name-input": ("Name", name, false),
    "email-input": ("Email", email, false),
    "message-textarea": ("Message", message, true), // multiline
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

  // Focus navigation
  fn focus_next() -> Unit {
    let current = focused_id.get()
    if current == "" {
      focused_id.set(focusable_ids[0])
      return
    }
    for i = 0; i < focusable_ids.length(); i = i + 1 {
      if focusable_ids[i] == current {
        let next_idx = (i + 1) % focusable_ids.length()
        focused_id.set(focusable_ids[next_idx])
        return
      }
    }
    focused_id.set(focusable_ids[0])
  }

  fn focus_prev() -> Unit {
    let current = focused_id.get()
    if current == "" {
      focused_id.set(focusable_ids[focusable_ids.length() - 1])
      return
    }
    for i = 0; i < focusable_ids.length(); i = i + 1 {
      if focusable_ids[i] == current {
        let prev_idx = if i == 0 { focusable_ids.length() - 1 } else { i - 1 }
        focused_id.set(focusable_ids[prev_idx])
        return
      }
    }
    focused_id.set(focusable_ids[focusable_ids.length() - 1])
  }

  // Render function
  fn render_ui() -> @tui.Component {
    @c.column(
      [
        // Title
        @c.row(
          [
            @c.text(
              "Form Demo (Native)",
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
                  rows=2,
                  state=get_textarea_state("message-textarea"),
                  min_width=40.0,
                ),
              ],
              margin_y=0.5,
            ),
            // Submit button
            @c.row(
              [
                @c.text("          "),
                @c.button("Submit", state=get_button_state("submit-btn"), id="submit-btn"),
              ],
              margin_y=1.0,
            ),
            // Instructions
            @c.row(
              [
                @c.text(
                  "Tab/Arrows: Navigate | Enter: Edit/Confirm | Ctrl+J: Newline | Esc: Cancel | q: Quit",
                  fg=@tui.Color::rgb(100, 100, 100),
                ),
              ],
              justify=@style.Alignment::Center,
              margin_y=1.0,
            ),
          ],
          padding=3.0,
        ),
      ],
      border=Some(@tui.BorderChars::rounded()),
      border_color=@tui.Color::cyan(),
      width=@types.Dimension::Length(width.to_double()),
      height=@types.Dimension::Length(height.to_double()),
    )
  }

  // Render the UI (cursor is hidden during navigation, shown only during editing)
  fn do_render() -> Unit {
    let component = render_ui()
    let output = app.render(component)
    @tui.print_raw(output)
    // Always hide cursor in navigation mode
    // Cursor is only visible inside start_inplace_input during editing
    @tui.print_raw(@tui.ansi_hide_cursor())
  }

  // Start editing an input field
  fn start_editing(id : String) -> Unit {
    match field_configs.get(id) {
      Some((field_name, signal, multiline)) => {
        match app.find_by_id(id) {
          Some(bounds) => {
            let row = bounds.y + 2
            let col = bounds.x + 2
            let content_width = bounds.width - 2
            let content_height = bounds.height - 2

            // start_inplace_input blocks until edit is complete
            @tui.start_inplace_input(
              row,
              col,
              content_width,
              content_height,
              multiline,
              signal.get(),
              fn(result) {
                match result {
                  @tui.InputResult::Confirmed(new_value) => signal.set(new_value)
                  @tui.InputResult::TabNext(new_value) => {
                    signal.set(new_value)
                    focus_next()
                  }
                  @tui.InputResult::TabPrev(new_value) => {
                    signal.set(new_value)
                    focus_prev()
                  }
                  @tui.InputResult::Cancelled => ()
                }
              },
            )
          }
          None => {
            // Bounds not found, ignore
            let _ = field_name
          }
        }
      }
      None => ()
    }
  }

  // Handle submit
  fn do_submit() -> Unit {
    running.set(false)
  }

  // Initialize terminal
  @tui.print_raw(@tui.App::init_terminal())
  @tui.enable_raw_mode()

  // Initial focus
  focused_id.set("name-input")

  // Initial render
  do_render()

  // Main polling loop
  while running.get() {
    let key = @tui.read_key()
    if key.length() == 0 {
      @tui.sleep(10)
      continue
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
            need_render = false
          }
          // q to quit when not focused on input
          @tui.KeyEvent::Char('q', @tui.KeyModifier::None) =>
            if not(input_ids.contains(focused_id.get())) {
              running.set(false)
              need_render = false
            } else {
              need_render = false
            }
          // Tab - next focus
          @tui.KeyEvent::Special(@tui.SpecialKey::Tab, @tui.KeyModifier::None) => {
            focus_next()
            need_render = true
          }
          // Shift+Tab or BackTab - previous focus
          @tui.KeyEvent::Special(
            @tui.SpecialKey::Tab
            | @tui.SpecialKey::BackTab,
            @tui.KeyModifier::Shift
          ) => {
            focus_prev()
            need_render = true
          }
          @tui.KeyEvent::Special(
            @tui.SpecialKey::BackTab,
            @tui.KeyModifier::None
          ) => {
            focus_prev()
            need_render = true
          }
          // Escape - unfocus
          @tui.KeyEvent::Special(@tui.SpecialKey::Escape, _) => {
            focused_id.set("")
            need_render = true
          }
          // Enter - edit if on input, submit if on button
          @tui.KeyEvent::Special(@tui.SpecialKey::Enter, _) => {
            let focus = focused_id.get()
            if focus == "submit-btn" {
              do_submit()
              need_render = false
            } else if input_ids.contains(focus) {
              start_edit_id = focus
              need_render = false
            } else {
              focus_next()
              need_render = true
            }
          }
          // Arrow keys for navigation
          @tui.KeyEvent::Special(@tui.SpecialKey::Down, _) => {
            focus_next()
            need_render = true
          }
          @tui.KeyEvent::Special(@tui.SpecialKey::Up, _) => {
            focus_prev()
            need_render = true
          }
          _ => need_render = false
        }
      @tui.InputEvent::Mouse(_) => need_render = false
      @tui.InputEvent::Resize(_, _) => need_render = true
      @tui.InputEvent::Unknown(_) => need_render = false
    }

    if need_render {
      do_render()
    }

    // Start editing if requested (after render)
    if start_edit_id != "" {
      start_editing(start_edit_id)
      // After editing, re-render
      do_render()
    }
  }

  // Cleanup and show results
  @tui.cleanup_stdin()
  @tui.print_raw(@tui.App::restore_terminal())

  println("Form submitted!")
  println("Name: " + name.get())
  println("Email: " + email.get())
  println("Message: " + message.get())
}
