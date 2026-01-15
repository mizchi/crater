///|
/// Button - Interactive clickable component

///|
/// Button state for visual feedback
pub(all) enum ButtonState {
  Normal
  Hover
  Pressed
  Disabled
}

///|
/// Create a button component
pub fn button(
  label : String,
  id? : String = "",
  state? : ButtonState = ButtonState::Normal,
  // Style
  fg? : @tui.Color = @tui.Color::white(),
  bg? : @tui.Color = @tui.Color::rgb(60, 60, 80),
  hover_bg? : @tui.Color = @tui.Color::rgb(80, 80, 100),
  pressed_bg? : @tui.Color = @tui.Color::rgb(40, 40, 60),
  disabled_fg? : @tui.Color = @tui.Color::rgb(100, 100, 100),
  border_color? : @tui.Color = @tui.Color::cyan(),
  // Size
  min_width? : Double = 0.0,
  padding_x? : Double = 2.0,
  padding_y? : Double = 0.0,
) -> @tui.Component {
  // Determine colors based on state
  let (actual_fg, actual_bg) = match state {
    ButtonState::Normal => (fg, bg)
    ButtonState::Hover => (fg, hover_bg)
    ButtonState::Pressed => (fg, pressed_bg)
    ButtonState::Disabled => (disabled_fg, bg)
  }

  // Build button with border
  row(
    [text(label, fg=actual_fg)],
    min_width=@types.Dimension::Length(min_width),
    padding_x~,
    padding_y~,
    justify=@style.Alignment::Center,
    align=@style.Alignment::Center,
    border=Some(@tui.BorderChars::rounded()),
    border_color~,
    bg=actual_bg,
  )
}

///|
/// Simple text button (no border)
pub fn text_button(
  label : String,
  state? : ButtonState = ButtonState::Normal,
  fg? : @tui.Color = @tui.Color::cyan(),
  hover_fg? : @tui.Color = @tui.Color::yellow(),
  pressed_fg? : @tui.Color = @tui.Color::green(),
  disabled_fg? : @tui.Color = @tui.Color::rgb(100, 100, 100),
  underline? : Bool = true,
) -> @tui.Component {
  let actual_fg = match state {
    ButtonState::Normal => fg
    ButtonState::Hover => hover_fg
    ButtonState::Pressed => pressed_fg
    ButtonState::Disabled => disabled_fg
  }
  text(label, fg=actual_fg, underline~)
}

///|
/// Icon button (single character or emoji)
pub fn icon_button(
  icon : String,
  state? : ButtonState = ButtonState::Normal,
  fg? : @tui.Color = @tui.Color::white(),
  bg? : @tui.Color = @tui.Color::transparent(),
  hover_bg? : @tui.Color = @tui.Color::rgb(60, 60, 80),
  pressed_bg? : @tui.Color = @tui.Color::rgb(40, 40, 60),
) -> @tui.Component {
  let actual_bg = match state {
    ButtonState::Normal => bg
    ButtonState::Hover => hover_bg
    ButtonState::Pressed => pressed_bg
    ButtonState::Disabled => bg
  }
  row([text(icon, fg~)], padding_x=1.0, bg=actual_bg)
}
