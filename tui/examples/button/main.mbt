///|
/// Button example - demonstrates interactive buttons with mouse support

///|
async fn main {
  let (cols, rows) = @tui.get_terminal_size()
  let width = cols
  let height = rows

  // Create reactive state
  let count = @signals.signal(0)
  let message = @signals.signal("Click a button!")

  // Create the app
  let app = @tui.App::new(width, height)

  // Render function
  fn render_ui() -> @tui.Component {
    let current_count = count.get()
    let current_message = message.get()
    @c.column(
      [
        // Title
        @c.row(
          [@c.text("Button Demo", fg=@tui.Color::yellow(), bold=true)],
          justify=@style.Alignment::Center,
          margin_y=1.0,
        ),
        // Message display
        @c.row(
          [@c.text(current_message, fg=@tui.Color::cyan())],
          justify=@style.Alignment::Center,
        ),
        // Count display
        @c.row(
          [
            @c.text("Count: "),
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
          justify=@style.Alignment::Center,
          margin_y=1.0,
        ),
        // Buttons row
        @c.row(
          [
            @c.button("[ - ]", bg=@tui.Color::rgb(80, 40, 40)),
            @c.hspace(2.0),
            @c.button("[ Reset ]", bg=@tui.Color::rgb(60, 60, 60)),
            @c.hspace(2.0),
            @c.button("[ + ]", bg=@tui.Color::rgb(40, 80, 40)),
          ],
          justify=@style.Alignment::Center,
        ),
        // Spacer
        @c.spacer(),
        // Instructions
        @c.row(
          [
            @c.text(
              "Click buttons or use: +/- keys | r: reset | q: quit",
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
    if key.length() == 0 {
      continue
    }
    let event = @tui.parse_input(key)
    let mut need_render = true
    match event {
      @tui.InputEvent::Key(key_event) =>
        match key_event {
          @tui.KeyEvent::Char('q', @tui.KeyModifier::None) => running = false
          @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => running = false
          @tui.KeyEvent::Special(@tui.SpecialKey::Escape, _) => running = false
          @tui.KeyEvent::Char('+', _) => {
            count.set(count.get() + 1)
            message.set("Incremented!")
          }
          @tui.KeyEvent::Char('-', _) => {
            count.set(count.get() - 1)
            message.set("Decremented!")
          }
          @tui.KeyEvent::Char('r', @tui.KeyModifier::None) => {
            count.set(0)
            message.set("Reset!")
          }
          _ => need_render = false
        }
      @tui.InputEvent::Mouse(mouse_event) =>
        match (mouse_event.event_type, mouse_event.button) {
          (@tui.MouseEventType::Press, @tui.MouseButton::Left) =>
            // Perform hit test
            match app.hit_test(mouse_event.x, mouse_event.y) {
              Some(hit) =>
                message.set(
                  "Clicked at (" +
                  mouse_event.x.to_string() +
                  "," +
                  mouse_event.y.to_string() +
                  ") on " +
                  hit.id,
                )
              None =>
                message.set(
                  "Clicked at (" +
                  mouse_event.x.to_string() +
                  "," +
                  mouse_event.y.to_string() +
                  ")",
                )
            }
          _ => need_render = false
        }
      _ => need_render = false
    }
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
