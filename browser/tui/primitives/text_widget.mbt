///|
/// Text-oriented TUI widgets.

///|
/// Draw a link with optional focus highlight.
pub fn draw_link(
  buf : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  focused : Bool,
) -> Int {
  let style : TextStyle = if focused {
    {
      fg: @types.Color::black(),
      bg: @types.Color::rgb(100, 149, 237), // Cornflower blue
      bold: true,
      underline: false,
    }
  } else {
    {
      fg: @types.Color::rgb(100, 149, 237), // Cornflower blue
      bg: @types.Color::transparent(),
      bold: false,
      underline: true,
    }
  }
  buf.write_text(x, y, text, style, max_width)
}

///|
/// Draw a heading with level-based emphasis.
pub fn draw_heading(
  buf : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  level : Int,
) -> Int {
  let fg = match level {
    1 => @types.Color::rgb(255, 255, 255) // White for h1
    2 => @types.Color::rgb(200, 200, 200) // Light gray for h2
    _ => @types.Color::rgb(180, 180, 180) // Lighter gray for h3+
  }
  let style : TextStyle = {
    fg,
    bg: @types.Color::transparent(),
    bold: true,
    underline: false,
  }
  buf.write_text(x, y, text, style, max_width)
}
