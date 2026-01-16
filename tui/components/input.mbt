///|
/// Input - Single line text input component

///|
/// Input state for visual feedback
pub(all) enum InputState {
  Idle
  Focused
  Editing
  Disabled
}

///|
/// Create an input component
/// Set height for multi-line wrapping support
pub fn input(
  value : String,
  id? : String = "",
  placeholder? : String = "",
  state? : InputState = InputState::Idle,
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
  height? : @types.Dimension = @types.Dimension::Auto,
  min_width? : Double = 10.0,
  min_height? : Double = 1.0,
  padding_x? : Double = 0.0,
  padding_y? : Double = 0.0,
) -> @tui.Component {
  // Determine display text
  let display_text = if value.length() == 0 {
    match state {
      InputState::Editing => ""
      _ => placeholder
    }
  } else {
    value
  }

  // Determine colors based on state
  let (actual_fg, actual_bg, border_color) = match state {
    InputState::Idle =>
      (
        if value.length() == 0 {
          placeholder_fg
        } else {
          fg
        },
        bg,
        @tui.Color::rgb(80, 80, 80),
      )
    InputState::Focused =>
      (
        if value.length() == 0 {
          placeholder_fg
        } else {
          fg
        },
        bg,
        focus_border_color,
      )
    InputState::Editing => (fg, bg, edit_border_color)
    InputState::Disabled =>
      (disabled_fg, disabled_bg, @tui.Color::rgb(60, 60, 60))
  }

  // Add cursor indicator when editing
  let text_with_cursor = if state is InputState::Editing {
    display_text + "_"
  } else {
    display_text
  }

  // Build input field with border
  // Set text as direct content (not child) for proper wrapping support
  let component = column(
    [], // No children - text is set directly
    id~,
    fg=actual_fg,
    min_width=@types.Dimension::Length(min_width),
    min_height=@types.Dimension::Length(min_height),
    width~,
    height~,
    padding_x~,
    padding_y~,
    border=Some(@tui.BorderChars::rounded()),
    border_color~,
    bg=actual_bg,
  )
  // Set text content directly on the component for write_text_wrapped to handle
  component.texts.set(component.node.id, text_with_cursor)
  component
}

///|
/// Create an input field without border
pub fn input_plain(
  value : String,
  placeholder? : String = "",
  state? : InputState = InputState::Idle,
  fg? : @tui.Color = @tui.Color::white(),
  bg? : @tui.Color = @tui.Color::transparent(),
  placeholder_fg? : @tui.Color = @tui.Color::rgb(100, 100, 100),
  underline? : Bool = true,
) -> @tui.Component {
  let display_text = if value.length() == 0 {
    match state {
      InputState::Editing => ""
      _ => placeholder
    }
  } else {
    value
  }
  let actual_fg = if value.length() == 0 && not(state is InputState::Editing) {
    placeholder_fg
  } else {
    fg
  }
  let text_with_cursor = if state is InputState::Editing {
    display_text + "_"
  } else {
    display_text
  }
  text(text_with_cursor, fg=actual_fg, bg~, underline~)
}
