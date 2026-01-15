///|
/// Counter example - demonstrates reactive TUI with async event loop

///|
async fn main {
  // Get terminal size
  let (cols, rows) = @src.get_terminal_size()
  let width = cols
  let height = rows

  // Create reactive state
  let count = @signals.signal(0)

  // Create the app
  let app = @src.App::new(width, height)

  // Render function that creates the component tree
  fn render_ui() -> @src.Component {
    let current_count = count.get()
    @src.box_(
      {
        ..@src.BoxOptions::default(),
        flex_direction: @style.FlexDirection::Column,
        width: @types.Dimension::Length(width.to_double()),
        height: @types.Dimension::Length(height.to_double()),
        padding: 1.0,
        border: Some(@src.BorderChars::rounded()),
        border_color: @src.Color::cyan(),
      },
      [
        // Title
        @src.box_(
          {
            ..@src.BoxOptions::default(),
            justify_content: @style.Alignment::Center,
            margin_y: 1.0,
          },
          [@src.styled_text("Counter Demo", fg=@src.Color::yellow(), bold=true)],
        ),
        // Count display
        @src.box_(
          {
            ..@src.BoxOptions::default(),
            flex_direction: @style.FlexDirection::Column,
            align_items: @style.Alignment::Center,
            flex_grow: 1.0,
            justify_content: @style.Alignment::Center,
          },
          [
            @src.text_("Count:"),
            @src.spacer(),
            @src.styled_text(
              current_count.to_string(),
              fg=if current_count >= 0 {
                @src.Color::green()
              } else {
                @src.Color::red()
              },
              bold=true,
            ),
          ],
        ),
        // Instructions
        @src.box_(
          {
            ..@src.BoxOptions::default(),
            justify_content: @style.Alignment::Center,
            margin_y: 1.0,
          },
          [
            @src.styled_text(
              "q: quit | +/k: increment | -/j: decrement | r: reset",
              fg=@src.Color::rgb(128, 128, 128),
            ),
          ],
        ),
      ],
    )
  }

  // Initialize terminal
  @src.print_raw(@src.App::init_terminal())
  @src.enable_raw_mode()
  @src.print_raw(@src.enable_mouse())

  // Initial render
  @src.print_raw(app.render_frame(render_ui()))

  // Event loop
  let mut running = true
  while running {
    let key = @src.read_key()
    // Skip empty input
    if key.length() == 0 {
      continue
    }
    let event = @src.parse_input(key)
    let mut need_render = true
    match event {
      @src.InputEvent::Key(key_event) =>
        match key_event {
          // Quit on 'q' or Ctrl+C or Escape
          @src.KeyEvent::Char('q', @src.KeyModifier::None) => running = false
          @src.KeyEvent::Char('c', @src.KeyModifier::Ctrl) => running = false
          @src.KeyEvent::Special(@src.SpecialKey::Escape, _) => running = false
          // Increment
          @src.KeyEvent::Char('+', _) => count.set(count.get() + 1)
          @src.KeyEvent::Char('=', _) => count.set(count.get() + 1)
          @src.KeyEvent::Char('k', @src.KeyModifier::None) =>
            count.set(count.get() + 1)
          @src.KeyEvent::Special(@src.SpecialKey::Up, _) =>
            count.set(count.get() + 1)
          // Decrement
          @src.KeyEvent::Char('-', _) => count.set(count.get() - 1)
          @src.KeyEvent::Char('_', _) => count.set(count.get() - 1)
          @src.KeyEvent::Char('j', @src.KeyModifier::None) =>
            count.set(count.get() - 1)
          @src.KeyEvent::Special(@src.SpecialKey::Down, _) =>
            count.set(count.get() - 1)
          // Reset
          @src.KeyEvent::Char('r', @src.KeyModifier::None) => count.set(0)
          _ => need_render = false
        }
      _ => need_render = false
    }
    // Re-render only when state changed
    if need_render && running {
      @src.print_raw(app.render_frame(render_ui()))
    }
  }

  // Restore terminal
  @src.print_raw(@src.disable_mouse())
  @src.cleanup_stdin()
  @src.print_raw(@src.App::restore_terminal())
  println("Goodbye! Final count: " + count.get().to_string())
}
