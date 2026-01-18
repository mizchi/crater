///|
/// Chat example - Claude Code-like chat UI
/// Top area shows scrollable message log, bottom has input field

///|
/// Message type for chat
enum MessageRole {
  User
  Assistant
} derive(Eq)

///|
struct Message {
  role : MessageRole
  content : String
}

///|
fn main {
  // Get terminal size
  let (cols, rows) = @tui.get_terminal_size()
  let width = cols
  let height = rows

  // Create reactive state
  let messages : @signals.Signal[Array[Message]] = @signals.signal([])
  let input_value = @signals.signal("")
  let is_editing = @signals.signal(false)
  let running = @signals.signal(true)

  // Scroll state using ScrollState component
  let scroll_state = @c.ScrollState::new()

  // Streaming state using StreamingState component
  let streaming = @c.StreamingState::new()

  // Create the app
  let app = @tui.App::new(width, height)

  // Calculate actual input rows based on content (no limit)
  fn calc_actual_rows(text : String, max_width : Int) -> Int {
    if text.length() == 0 {
      return 1
    }
    // Count newlines and wrapped lines
    let mut rows = 1
    let mut col = 0
    for c in text {
      if c == '\n' {
        rows = rows + 1
        col = 0
      } else {
        col = col + 1
        if col >= max_width {
          rows = rows + 1
          col = 0
        }
      }
    }
    rows
  }

  // Count lines in a string (including line wrapping)
  fn count_content_lines(text : String) -> Int {
    if text.length() == 0 {
      return 1
    }
    let mut lines = 1
    for c in text {
      if c == '\n' {
        lines = lines + 1
      }
    }
    lines
  }

  // Get total message lines (role + content lines + spacer per message)
  fn get_total_lines() -> Int {
    let msgs = messages.get()
    let mut total = 0
    for msg in msgs {
      total = total + 1 // role line
      total = total + count_content_lines(msg.content) // content lines
      total = total + 1 // spacer
    }
    // Add streaming message if in progress
    if streaming.is_streaming() {
      let partial = streaming.get_partial()
      total = total + 1 // role
      total = total + count_content_lines(partial) // partial content
      total = total + 1 // spacer
    }
    total
  }

  // Fixed layout dimensions
  let max_input_rows = 5
  let fixed_input_height = max_input_rows + 4
  let fixed_message_height = height - fixed_input_height - 1 // -1 for divider
  let visible_message_lines = fixed_message_height - 2 // -2 for padding

  // Add a message
  fn add_message(role : MessageRole, content : String) -> Unit {
    let current = messages.get()
    current.push({ role, content })
    messages.set(current)
    // Auto-scroll to bottom using ScrollState
    scroll_state.auto_scroll_to_bottom(get_total_lines(), visible_message_lines)
  }

  // Use @c.split_lines from streaming.mbt for string splitting

  // Build all message lines as flat array for scrolling
  fn build_message_lines() -> Array[@tui.Component] {
    let msgs = messages.get()
    let lines : Array[@tui.Component] = []
    for msg in msgs {
      let (icon, role_color) = match msg.role {
        User => ("◆", @tui.Color::cyan())
        Assistant => ("✦", @tui.Color::rgb(255, 150, 100)) // coral/salmon like Claude
      }
      // Role line with icon
      lines.push(
        @c.row([
          @c.text(icon + " ", fg=role_color, bold=true),
          @c.text(
            match msg.role {
              User => "You"
              Assistant => "Assistant"
            },
            fg=role_color,
            bold=true,
          ),
        ]),
      )
      // Content lines (split by newlines)
      let content_lines = @c.split_lines(msg.content)
      for line in content_lines {
        lines.push(
          @c.row([
            @c.hspace(2.0), // indent
            @c.text(line, fg=@tui.Color::rgb(220, 220, 220)),
          ]),
        )
      }
      lines.push(@c.vspace(1.0))
    }
    // Add streaming message if in progress
    if streaming.is_streaming() {
      let role_color = @tui.Color::rgb(255, 150, 100)
      // Role line
      lines.push(
        @c.row([
          @c.text("✦ ", fg=role_color, bold=true),
          @c.text("Assistant", fg=role_color, bold=true),
        ]),
      )
      // Partial content (split by newlines)
      let partial = streaming.get_partial()
      let partial_lines = @c.split_lines(partial)
      for i, line in partial_lines {
        let display = if i == partial_lines.length() - 1 {
          line + "▌" // cursor on last line
        } else {
          line
        }
        lines.push(
          @c.row([
            @c.hspace(2.0),
            @c.text(display, fg=@tui.Color::rgb(220, 220, 220)),
          ]),
        )
      }
      lines.push(@c.vspace(1.0))
    }
    lines
  }

  // Build input lines for multiline display
  fn build_input_lines(
    text : String,
    cursor : String,
    fg : @tui.Color
  ) -> Array[@tui.Component] {
    let lines : Array[@tui.Component] = []
    if text.length() == 0 {
      lines.push(@c.text(cursor, fg=fg))
      return lines
    }
    // Split by newlines
    let parts : Array[String] = []
    let mut current = StringBuilder::new()
    for c in text {
      if c == '\n' {
        parts.push(current.to_string())
        current = StringBuilder::new()
      } else {
        current.write_char(c)
      }
    }
    parts.push(current.to_string())
    // Build components for each line
    for i, part in parts {
      if i == parts.length() - 1 {
        // Last line gets the cursor
        lines.push(@c.text(part + cursor, fg=fg))
      } else {
        lines.push(@c.text(part, fg=fg))
      }
    }
    lines
  }

  // Render messages with scroll offset applied
  fn render_messages(visible_height : Int) -> Array[@tui.Component] {
    let all_lines = build_message_lines()
    if all_lines.is_empty() {
      return [
        @c.vspace(2.0),
        @c.row(
          [
            @c.text(
              "Start typing to begin a conversation...",
              fg=@tui.Color::rgb(100, 100, 100),
            ),
          ],
          justify=@style.Alignment::Center,
        ),
      ]
    }
    // Use ScrollState's scrollable_list helper
    @c.scrollable_list(all_lines, scroll_state, visible_height)
  }

  // Render function
  fn render_ui() -> @tui.Component {
    let editing = is_editing.get()
    let input_width = width - 4 // Account for padding
    let actual_rows = calc_actual_rows(input_value.get(), input_width)
    // Build input display text
    let input_text = input_value.get()
    let divider_color = @tui.Color::rgb(60, 60, 60)
    let active_divider = @tui.Color::rgb(100, 150, 255)
    // Show placeholder when empty and not editing
    let display_text = if input_text.length() == 0 && not(editing) {
      "Type a message... (press Enter to start)"
    } else {
      input_text
    }
    let cursor = if editing { "█" } else { "" }
    let input_fg = if input_text.length() == 0 && not(editing) {
      @tui.Color::rgb(100, 100, 100) // Placeholder color
    } else {
      @tui.Color::white()
    }
    // Build status text with line count
    let line_info = actual_rows.to_string() + "/" + max_input_rows.to_string() + " lines"
    let status_text = line_info + " · Enter: send · Alt+Enter: newline · Ctrl+C: quit"
    @c.column(
      [
        // Message area (fixed height)
        @c.column(
          render_messages(fixed_message_height - 2),
          height=@types.Dimension::Length(fixed_message_height.to_double()),
          padding=1.0,
        ),
        // Divider line (changes color when editing)
        @c.hdivider(char='─', fg=if editing { active_divider } else { divider_color }),
        // Input area (fixed height, no border)
        @c.column(
          [
            @c.column(
              build_input_lines(display_text, cursor, input_fg),
              id="chat-input",
              height=@types.Dimension::Length(max_input_rows.to_double()),
            ),
            // Status bar (right aligned)
            @c.row([
              @c.spacer(),
              @c.text(status_text, fg=@tui.Color::rgb(80, 80, 80)),
            ]),
          ],
          padding=1.0,
        ),
      ],
      width=@types.Dimension::Length(width.to_double()),
      height=@types.Dimension::Length(height.to_double()),
    )
  }

  // Render helper with synchronized output to prevent flickering
  // Uses direct ANSI output for consistent coordinates with render_message_area()
  fn do_render() -> Unit {
    let visible_height = fixed_message_height - 2 // -2 for padding
    let msgs = messages.get()

    // Build flat list of line data for messages
    let all_lines : Array[(Int, String, String)] = []

    for msg in msgs {
      let (icon, color_code) = match msg.role {
        User => ("◆", "\u001b[36m") // cyan
        Assistant => ("✦", "\u001b[38;2;255;150;100m") // coral
      }
      let role_name = match msg.role {
        User => "You"
        Assistant => "Assistant"
      }
      all_lines.push((0, icon + " " + role_name, color_code))
      let content_lines = @c.split_lines(msg.content)
      for line in content_lines {
        all_lines.push((1, line, "\u001b[38;2;220;220;220m"))
      }
      all_lines.push((2, "", ""))
    }

    // Add streaming message if in progress
    if streaming.has_content() {
      all_lines.push((0, "✦ Assistant", "\u001b[38;2;255;150;100m"))
      let partial = streaming.get_partial()
      let partial_lines = @c.split_lines(partial)
      for i, line in partial_lines {
        let display = if i == partial_lines.length() - 1 && streaming.is_streaming() {
          line + "▌"
        } else {
          line
        }
        all_lines.push((1, display, "\u001b[38;2;220;220;220m"))
      }
      all_lines.push((2, "", ""))
    }

    // Same logic as render_messages()
    let total = all_lines.length()
    let has_scroll = total > visible_height
    let content_height = if has_scroll { visible_height - 1 } else { visible_height }
    let offset = scroll_state.offset.get()

    // Start synchronized output
    @tui.print_raw("\u001b[?2026h")
    // Clear screen and move to home
    @tui.print_raw("\u001b[2J\u001b[H")

    // Row 1: padding (empty)
    @tui.print_raw("\u001b[1;1H\u001b[2K")

    // Rows 2 to fixed_message_height-1: message content
    let mut added = 0
    for i = 0; i < visible_height; i = i + 1 {
      let row = i + 2
      @tui.print_raw("\u001b[" + row.to_string() + ";1H\u001b[2K")

      if added < content_height {
        let line_idx = offset + added
        if line_idx < all_lines.length() {
          let (line_type, text, color_code) = all_lines[line_idx]
          match line_type {
            0 => @tui.print_raw(" " + color_code + "\u001b[1m" + text + "\u001b[0m")
            1 => @tui.print_raw("   " + color_code + text + "\u001b[0m")
            _ => ()
          }
        }
        added = added + 1
      } else if has_scroll && added == content_height {
        // Scroll indicator using ScrollState helper
        let indicator = scroll_state.get_indicator(total, visible_height)
        let text = @c.scroll_indicator_text(indicator)
        @tui.print_raw("\u001b[38;2;80;80;80m" + text + "\u001b[0m")
        added = added + 1
      }
    }

    // Row fixed_message_height: padding (empty)
    @tui.print_raw("\u001b[" + fixed_message_height.to_string() + ";1H\u001b[2K")

    // Row fixed_message_height+1: divider
    let divider_row = fixed_message_height + 1
    let editing = is_editing.get()
    let divider_color = if editing { "\u001b[38;2;100;150;255m" } else { "\u001b[38;2;60;60;60m" }
    @tui.print_raw("\u001b[" + divider_row.to_string() + ";1H\u001b[2K")
    @tui.print_raw(divider_color + "─".repeat(width) + "\u001b[0m")

    // Input area starts at row fixed_message_height+2
    let input_start_row = fixed_message_height + 2
    let input_text = input_value.get()
    let display_text = if input_text.length() == 0 && not(editing) {
      "Type a message... (press Enter to start)"
    } else {
      input_text
    }
    let cursor = if editing { "█" } else { "" }
    let input_color = if input_text.length() == 0 && not(editing) {
      "\u001b[38;2;100;100;100m"
    } else {
      "\u001b[37m"
    }

    // Row input_start_row: padding
    @tui.print_raw("\u001b[" + input_start_row.to_string() + ";1H\u001b[2K")

    // Rows for input content (max_input_rows)
    let input_lines = @c.split_lines(display_text)
    for i = 0; i < max_input_rows; i = i + 1 {
      let row = input_start_row + 1 + i
      @tui.print_raw("\u001b[" + row.to_string() + ";1H\u001b[2K")
      if i < input_lines.length() {
        let line = input_lines[i]
        let text = if i == input_lines.length() - 1 { line + cursor } else { line }
        @tui.print_raw(" " + input_color + text + "\u001b[0m")
      }
    }

    // Status bar
    let status_row = input_start_row + 1 + max_input_rows
    let input_width = width - 4
    let actual_rows = calc_actual_rows(input_value.get(), input_width)
    let line_info = actual_rows.to_string() + "/" + max_input_rows.to_string() + " lines"
    let status_text = line_info + " · Enter: send · Alt+Enter: newline · Ctrl+C: quit"
    @tui.print_raw("\u001b[" + status_row.to_string() + ";1H\u001b[2K")
    // Right align status
    let status_col = width - status_text.length()
    if status_col > 0 {
      @tui.print_raw("\u001b[" + status_row.to_string() + ";" + status_col.to_string() + "H")
    }
    @tui.print_raw("\u001b[38;2;80;80;80m" + status_text + "\u001b[0m")

    // End synchronized output
    @tui.print_raw("\u001b[?2026l")
  }

  // Render only message area (preserves input box during editing)
  fn render_message_area() -> Unit {
    // Use same dimensions as render_messages()
    let visible_height = fixed_message_height - 2 // -2 for padding
    let msgs = messages.get()

    // Build flat list of line data: (type, text, color_code)
    // type: 0=role, 1=content, 2=spacer
    let all_lines : Array[(Int, String, String)] = []

    for msg in msgs {
      let (icon, color_code) = match msg.role {
        User => ("◆", "\u001b[36m") // cyan
        Assistant => ("✦", "\u001b[38;2;255;150;100m") // coral
      }
      let role_name = match msg.role {
        User => "You"
        Assistant => "Assistant"
      }
      // Role line
      all_lines.push((0, icon + " " + role_name, color_code))
      // Content lines (split by newlines)
      let content_lines = @c.split_lines(msg.content)
      for line in content_lines {
        all_lines.push((1, line, "\u001b[38;2;220;220;220m"))
      }
      // Spacer
      all_lines.push((2, "", ""))
    }

    // Add streaming message if in progress
    if streaming.has_content() {
      // Role line
      all_lines.push((0, "✦ Assistant", "\u001b[38;2;255;150;100m"))
      // Partial content lines
      let partial = streaming.get_partial()
      let partial_lines = @c.split_lines(partial)
      for i, line in partial_lines {
        let display = if i == partial_lines.length() - 1 && streaming.is_streaming() {
          line + "▌" // cursor on last line
        } else {
          line
        }
        all_lines.push((1, display, "\u001b[38;2;220;220;220m"))
      }
      // Spacer
      all_lines.push((2, "", ""))
    }

    // Same logic as render_messages(): reserve 1 line for scroll indicator
    let total = all_lines.length()
    let has_scroll = total > visible_height
    let content_height = if has_scroll { visible_height - 1 } else { visible_height }
    let offset = scroll_state.offset.get()

    // Start synchronized output
    @tui.print_raw("\u001b[?2026h")
    // Save cursor position
    @tui.print_raw("\u001b[s")

    // Clear and redraw message area only (row 2 to row fixed_message_height-1)
    let mut added = 0
    for i = 0; i < visible_height; i = i + 1 {
      let row = i + 2 // Start from row 2 (after padding)
      // Move to row and clear it
      @tui.print_raw("\u001b[" + row.to_string() + ";1H\u001b[2K")

      if added < content_height {
        let line_idx = offset + added
        if line_idx < all_lines.length() {
          let (line_type, text, color_code) = all_lines[line_idx]
          match line_type {
            0 => {
              // Role line (bold)
              @tui.print_raw(" " + color_code + "\u001b[1m" + text + "\u001b[0m")
            }
            1 => {
              // Content line (with indent)
              @tui.print_raw("   " + color_code + text + "\u001b[0m")
            }
            _ => () // Spacer - leave empty
          }
        }
        added = added + 1
      } else if has_scroll && added == content_height {
        // Scroll indicator line using ScrollState helper
        let indicator = scroll_state.get_indicator(total, visible_height)
        let text = @c.scroll_indicator_text(indicator)
        @tui.print_raw("\u001b[38;2;80;80;80m" + text + "\u001b[0m")
        added = added + 1
      }
    }

    // Restore cursor position
    @tui.print_raw("\u001b[u")
    // End synchronized output
    @tui.print_raw("\u001b[?2026l")
  }

  // Quit helper
  fn do_quit() -> Unit {
    running.set(false)
    @tui.stop_keypress_listener()
    @tui.print_raw(@tui.disable_mouse())
    @tui.cleanup_stdin()
    @tui.print_raw(@tui.App::restore_terminal())
    println("Goodbye!")
  }

  // Complete streaming and add to messages
  fn finish_streaming() -> Unit {
    let text = streaming.take() // Get text and clear state
    if text.length() > 0 {
      add_message(Assistant, text)
    }
    // Auto-scroll to bottom using ScrollState
    scroll_state.auto_scroll_to_bottom(get_total_lines(), visible_message_lines)
  }

  // Start streaming response
  fn start_streaming(response : String) -> Unit {
    // Callbacks for streaming
    fn on_tick() {
      // Auto-scroll to bottom using ScrollState
      scroll_state.auto_scroll_to_bottom(get_total_lines(), visible_message_lines)
      // Use partial render during editing to preserve input box
      if is_editing.get() {
        render_message_area()
      } else {
        do_render()
      }
    }

    fn on_complete() {
      finish_streaming()
      // Use partial render during editing
      if is_editing.get() {
        render_message_area()
      } else {
        do_render()
      }
    }

    // Start streaming (200ms interval = 5 chars/sec)
    let started = streaming.start(response, 200, on_tick, on_complete)
    // If not started (already streaming or native mode fallback)
    if not(started) || streaming.ticker_id.val == 0 {
      // Fallback: add message immediately
      streaming.clear()
      add_message(Assistant, response)
    }
    do_render()
  }

  // Restore TUI and send message
  fn restore_tui_and_send() -> Unit {
    let raw = input_value.get()
    let text = raw.trim(chars=" \t\n\r").to_string()
    if text.length() > 0 {
      // Re-enable auto-scroll when sending a message
      scroll_state.auto_scroll.set(true)
      add_message(User, text)
      input_value.set("")
      // Start streaming assistant response
      let response = "You said: " + text + ". This is a simulated response."
      start_streaming(response)
    }
    is_editing.set(false)
    @tui.print_raw(@tui.ansi_full_reset())
    @tui.print_raw(@tui.enable_mouse())
    app.clear_prev_buffer()
    do_render()
    @tui.start_keypress_listener(handle_key)
  }

  // Start editing
  fn start_editing() -> Unit {
    is_editing.set(true)
    // Clear and re-render completely before entering edit mode
    do_render()

    // Calculate input area coordinates directly (same as do_render)
    let input_start_row = fixed_message_height + 2
    let row = input_start_row + 1 // After padding row
    let col = 2 // After left padding
    let content_width = width - 2
    let content_height = max_input_rows

    let signal = input_value
    let config = @c.form_edit_config(
      "Message",
      signal,
      on_edit_start=Some(fn() {
        @tui.stop_keypress_listener()
        @tui.print_raw(@tui.disable_mouse())
      }),
    )

    // Clear the content area
    for r = 0; r < content_height; r = r + 1 {
      @tui.print_raw(
        "\u001b[" +
        (row + r).to_string() +
        ";" +
        col.to_string() +
        "H" +
        " ".repeat(content_width),
      )
    }
    // Callback to dynamically resize based on line count
    let on_lines_change : (Int) -> Int = fn(line_count) {
      let min_h = 1
      let max_h = max_input_rows
      if line_count < min_h {
        min_h
      } else if line_count > max_h {
        max_h
      } else {
        line_count
      }
    }
    @c.start_edit_inplace(
      config,
      signal.get(),
      row,
      col,
      content_width,
      content_height,
      true, // multiline
      restore_tui_and_send,
      on_lines_change=Some(on_lines_change),
    )
  }

  // Handle keypress event
  fn handle_key(key : String) -> Unit {
    if key.length() == 0 {
      return
    }
    let event = @tui.parse_input(key)
    let mut need_render = true
    let mut should_edit = false
    match event {
      @tui.InputEvent::Key(key_event) =>
        match key_event {
          // Ctrl+C - quit
          @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => {
            do_quit()
            return
          }
          // Escape - quit
          @tui.KeyEvent::Special(@tui.SpecialKey::Escape, _) => {
            do_quit()
            return
          }
          // Enter - start editing or send
          @tui.KeyEvent::Special(@tui.SpecialKey::Enter, _) =>
            should_edit = true
          // Any printable character - start editing
          @tui.KeyEvent::Char(_, @tui.KeyModifier::None) => should_edit = true
          // Scroll up
          @tui.KeyEvent::Special(@tui.SpecialKey::Up, _)
          | @tui.KeyEvent::Special(@tui.SpecialKey::PageUp, _) =>
            ignore(scroll_state.scroll_up(1))
          // Scroll down
          @tui.KeyEvent::Special(@tui.SpecialKey::Down, _)
          | @tui.KeyEvent::Special(@tui.SpecialKey::PageDown, _) =>
            ignore(
              scroll_state.scroll_down(1, get_total_lines(), visible_message_lines),
            )
          _ => need_render = false
        }
      @tui.InputEvent::Mouse(mouse_event) =>
        match (mouse_event.event_type, mouse_event.button) {
          (@tui.MouseEventType::Press, @tui.MouseButton::Left) =>
            match app.hit_test(mouse_event.x, mouse_event.y) {
              Some(hit) => if hit.id == "chat-input" { should_edit = true }
              None => ()
            }
          (@tui.MouseEventType::Press, @tui.MouseButton::ScrollUp) =>
            ignore(scroll_state.scroll_up(3))
          (@tui.MouseEventType::Press, @tui.MouseButton::ScrollDown) =>
            ignore(
              scroll_state.scroll_down(3, get_total_lines(), visible_message_lines),
            )
          _ => need_render = false
        }
      _ => need_render = false
    }

    // Start editing if requested
    if should_edit {
      start_editing()
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
