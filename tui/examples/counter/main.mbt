///|
/// Counter example - demonstrates reactive TUI with async event loop

///|
async fn main {
  // Get terminal size
  let (cols, rows) = @tui.get_terminal_size()
  let width = cols
  let height = rows

  // Create reactive state
  let count = @signals.signal(0)

  // Create the app
  let app = @tui.App::new(width, height)

  // Render function that creates the component tree
  fn render_ui() -> @tui.Component {
    let current_count = count.get()
    @c.column(
      [
        // Title
        @c.row(
          [@c.text("Counter Demo", fg=@tui.Color::yellow(), bold=true)],
          justify=@style.Alignment::Center,
          margin_y=1.0,
        ),
        // Count display
        @c.column(
          [
            @c.text("Count:"),
            @c.spacer(),
            @c.text(
              current_count.to_string(),
              fg=if current_count >= 0 {
                @tui.Color::green()
              } else {
                @tui.Color::red()
              },
              bold=true,
            ),
          ],
          flex_grow=1.0,
          justify=@style.Alignment::Center,
          align=@style.Alignment::Center,
        ),
        // Buttons row
        @c.row(
          [
            @c.button(" - ", min_width=7.0, bg=@tui.Color::rgb(100, 50, 50)),
            @c.hspace(2.0),
            @c.button("Reset", min_width=9.0, bg=@tui.Color::rgb(60, 60, 60)),
            @c.hspace(2.0),
            @c.button(" + ", min_width=7.0, bg=@tui.Color::rgb(50, 100, 50)),
          ],
          justify=@style.Alignment::Center,
        ),
        // Instructions
        @c.row(
          [
            @c.text(
              "Click buttons or: q=quit | +/-=count | r=reset",
              fg=@tui.Color::rgb(128, 128, 128),
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

  // Initialize terminal
  @tui.print_raw(@tui.App::init_terminal())
  @tui.enable_raw_mode()
  @tui.print_raw(@tui.enable_mouse())

  // Initial render
  @tui.print_raw(app.render_frame(render_ui()))

  // Event loop
  let mut running = true
  while running {
    let key = @tui.read_key()
    // Skip empty input
    if key.length() == 0 {
      continue
    }
    let event = @tui.parse_input(key)
    let mut need_render = true
    match event {
      @tui.InputEvent::Key(key_event) =>
        match key_event {
          // Quit on 'q' or Ctrl+C or Escape
          @tui.KeyEvent::Char('q', @tui.KeyModifier::None) => running = false
          @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => running = false
          @tui.KeyEvent::Special(@tui.SpecialKey::Escape, _) => running = false
          // Increment
          @tui.KeyEvent::Char('+', _) => count.set(count.get() + 1)
          @tui.KeyEvent::Char('=', _) => count.set(count.get() + 1)
          @tui.KeyEvent::Char('k', @tui.KeyModifier::None) =>
            count.set(count.get() + 1)
          @tui.KeyEvent::Special(@tui.SpecialKey::Up, _) =>
            count.set(count.get() + 1)
          // Decrement
          @tui.KeyEvent::Char('-', _) => count.set(count.get() - 1)
          @tui.KeyEvent::Char('_', _) => count.set(count.get() - 1)
          @tui.KeyEvent::Char('j', @tui.KeyModifier::None) =>
            count.set(count.get() - 1)
          @tui.KeyEvent::Special(@tui.SpecialKey::Down, _) =>
            count.set(count.get() - 1)
          // Reset
          @tui.KeyEvent::Char('r', @tui.KeyModifier::None) => count.set(0)
          _ => need_render = false
        }
      @tui.InputEvent::Mouse(mouse_event) =>
        match (mouse_event.event_type, mouse_event.button) {
          (@tui.MouseEventType::Press, @tui.MouseButton::Left) => {
            let x = mouse_event.x
            let y = mouse_event.y
            // Use hit_test to find clicked component
            match app.hit_test(x, y) {
              Some(hit) => {
                // Detect button by examining hit result position
                let hit_center_x = hit.x + hit.width / 2
                let screen_center_x = width / 2
                // Button has border (height ~7) and reasonable width
                if hit.width >= 5 && hit.width <= 12 && hit.height >= 3 {
                  // Looks like a button - determine which one by position
                  if hit_center_x < screen_center_x - 8 {
                    count.set(count.get() - 1) // Left button: decrement
                  } else if hit_center_x > screen_center_x + 8 {
                    count.set(count.get() + 1) // Right button: increment
                  } else {
                    count.set(0) // Center button: reset
                  }
                }
              }
              None => ()
            }
          }
          _ => need_render = false
        }
      _ => need_render = false
    }
    // Re-render only when state changed
    if need_render && running {
      @tui.print_raw(app.render_frame(render_ui()))
    }
  }

  // Restore terminal
  @tui.print_raw(@tui.disable_mouse())
  @tui.cleanup_stdin()
  @tui.print_raw(@tui.App::restore_terminal())
  println("Goodbye! Final count: " + count.get().to_string())
}
