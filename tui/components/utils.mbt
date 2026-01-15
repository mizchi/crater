///|
/// Utility components - Text, Spacer, Divider, etc.

///|
/// Text with color
pub fn text(
  content : String,
  fg? : @tui.Color = @tui.Color::white(),
  bg? : @tui.Color = @tui.Color::transparent(),
  bold? : Bool = false,
  underline? : Bool = false,
) -> @tui.Component {
  @tui.styled_text(content, fg~, bg~, bold~, underline~)
}

///|
/// Plain text
pub fn text_(content : String) -> @tui.Component {
  @tui.text_(content)
}

///|
/// Bold text
pub fn bold(content : String) -> @tui.Component {
  @tui.styled_text(content, bold=true)
}

///|
/// Colored text
pub fn colored(content : String, fg : @tui.Color) -> @tui.Component {
  @tui.styled_text(content, fg~)
}

///|
/// Flexible spacer
pub fn spacer(flex_grow? : Double = 1.0) -> @tui.Component {
  @tui.spacer(flex_grow~)
}

///|
/// Fixed-width horizontal spacer
pub fn hspace(width : Double) -> @tui.Component {
  @tui.box_(
    { ..@tui.BoxOptions::default(), width: @types.Dimension::Length(width) },
    [],
  )
}

///|
/// Fixed-height vertical spacer
pub fn vspace(height : Double) -> @tui.Component {
  @tui.box_(
    { ..@tui.BoxOptions::default(), height: @types.Dimension::Length(height) },
    [],
  )
}

///|
/// Horizontal divider line
pub fn hdivider(
  char? : Char = '-',
  fg? : @tui.Color = @tui.Color::white(),
) -> @tui.Component {
  // Create a box that stretches horizontally with a border
  @tui.box_(
    {
      ..@tui.BoxOptions::default(),
      flex_grow: 1.0,
      height: @types.Dimension::Length(1.0),
      border: Some({
        top_left: char,
        top_right: char,
        bottom_left: char,
        bottom_right: char,
        horizontal: char,
        vertical: char,
      }),
      border_color: fg,
    },
    [],
  )
}

///|
/// Vertical divider line
pub fn vdivider(
  char? : Char = '|',
  fg? : @tui.Color = @tui.Color::white(),
) -> @tui.Component {
  @tui.box_(
    {
      ..@tui.BoxOptions::default(),
      flex_grow: 1.0,
      width: @types.Dimension::Length(1.0),
      border: Some({
        top_left: char,
        top_right: char,
        bottom_left: char,
        bottom_right: char,
        horizontal: char,
        vertical: char,
      }),
      border_color: fg,
    },
    [],
  )
}

///|
/// Box with border
pub fn bordered(
  children : Array[@tui.Component],
  style? : @tui.BorderChars = @tui.BorderChars::single(),
  color? : @tui.Color = @tui.Color::white(),
) -> @tui.Component {
  @tui.box_(
    { ..@tui.BoxOptions::default(), border: Some(style), border_color: color },
    children,
  )
}

///|
/// Box with padding
pub fn padded(
  padding : Double,
  children : Array[@tui.Component],
) -> @tui.Component {
  @tui.box_({ ..@tui.BoxOptions::default(), padding, }, children)
}

///|
/// Center content
pub fn center(children : Array[@tui.Component]) -> @tui.Component {
  @tui.box_(
    {
      ..@tui.BoxOptions::default(),
      justify_content: @style.Alignment::Center,
      align_items: @style.Alignment::Center,
    },
    children,
  )
}

///|
/// Fill available space
pub fn fill(children : Array[@tui.Component]) -> @tui.Component {
  @tui.box_({ ..@tui.BoxOptions::default(), flex_grow: 1.0 }, children)
}
