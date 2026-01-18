///|
/// Textarea - Multi-line text input component

///|
/// Textarea state for visual feedback
pub(all) enum TextareaState {
  Idle
  Focused
  Editing
  Disabled
}

///|
/// Create a textarea component
pub fn textarea(
  value : String,
  id? : String = "",
  rows? : Int = 3,
  placeholder? : String = "",
  state? : TextareaState = TextareaState::Idle,
  // Style
  fg? : @tui.Color = @tui.Color::white(),
  bg? : @tui.Color = @tui.Color::rgb(40, 40, 50),
  placeholder_fg? : @tui.Color = @tui.Color::rgb(100, 100, 100),
  focus_border_color? : @tui.Color = @tui.Color::cyan(),
  edit_border_color? : @tui.Color = @tui.Color::green(),
  disabled_fg? : @tui.Color = @tui.Color::rgb(80, 80, 80),
  disabled_bg? : @tui.Color = @tui.Color::rgb(30, 30, 35),
  // Size
  width? : @types.Dimension = @types.Dimension::Auto,
  min_width? : Double = 20.0,
  padding_x? : Double = 1.0,
  padding_y? : Double = 0.0,
) -> @tui.Component {
  // Split value into lines
  let lines = split_lines(value)

  // Determine display content
  let display_lines : Array[String] = if lines.length() == 0 ||
    (lines.length() == 1 && lines[0] == "") {
    match state {
      TextareaState::Editing => [""]
      _ => [placeholder]
    }
  } else {
    lines
  }

  // Determine colors based on state
  let (actual_fg, actual_bg, border_color) = match state {
    TextareaState::Idle =>
      (
        if value.length() == 0 {
          placeholder_fg
        } else {
          fg
        },
        bg,
        @tui.Color::rgb(80, 80, 80),
      )
    TextareaState::Focused =>
      (
        if value.length() == 0 {
          placeholder_fg
        } else {
          fg
        },
        bg,
        focus_border_color,
      )
    TextareaState::Editing => (fg, bg, edit_border_color)
    TextareaState::Disabled =>
      (disabled_fg, disabled_bg, @tui.Color::rgb(60, 60, 60))
  }

  // Build text lines (show cursor on last line when editing)
  let text_components : Array[@tui.Component] = []
  for i, line in display_lines {
    let is_last = i == display_lines.length() - 1
    let line_text = if is_last && state is TextareaState::Editing {
      line + "_"
    } else {
      line
    }
    text_components.push(text(line_text, fg=actual_fg))
  }

  // Pad with empty lines to reach minimum rows
  let remaining_rows = rows - text_components.length()
  for _ in 0..<remaining_rows {
    text_components.push(text("", fg=actual_fg))
  }

  // Build textarea with border
  column(
    text_components,
    id~,
    min_width=@types.Dimension::Length(min_width),
    width~,
    height=@types.Dimension::Length(rows.to_double()),
    padding_x~,
    padding_y~,
    justify=@style.Alignment::Start,
    align=@style.Alignment::Start,
    border=Some(@tui.BorderChars::rounded()),
    border_color~,
    bg=actual_bg,
  )
}

// split_lines is now defined in streaming.mbt
