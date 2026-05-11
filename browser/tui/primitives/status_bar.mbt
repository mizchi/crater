///|
/// Browser status bar widget.

///|
/// Draw a status bar at the top.
/// Shows focused link URL when a link is focused, otherwise shows current page URL.
pub fn draw_status_bar(
  buf : CharBuffer,
  y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
) -> Unit {
  // Status bar colors - slightly different for dark mode
  let (bg, fg) = if dark_mode {
    (@types.Color::rgb(40, 40, 50), @types.Color::rgb(180, 180, 180))
  } else {
    (@types.Color::rgb(50, 50, 50), @types.Color::rgb(200, 200, 200))
  }
  let highlight_fg = @types.Color::rgb(100, 200, 255) // Cyan for link URL
  let selection_fg = @types.Color::rgb(255, 200, 100) // Orange for selection mode
  let dark_mode_fg = @types.Color::rgb(150, 200, 150) // Green for dark mode indicator
  // Fill the entire row with background
  let fill : CharCell = {
    char: ' ',
    fg,
    bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, y, buf.width, 1, fill)
  // Build status text
  let style : TextStyle = { fg, bg, bold: false, underline: false }
  let selection_style : TextStyle = {
    fg: selection_fg,
    bg,
    bold: true,
    underline: false,
  }
  let dark_mode_style : TextStyle = {
    fg: dark_mode_fg,
    bg,
    bold: false,
    underline: false,
  }
  let mut col = 0
  // Show dark mode indicator if active
  if dark_mode {
    let mode_text = "[DARK] "
    col = buf.write_text(col, y, mode_text, dark_mode_style, buf.width)
  }
  // Show selection mode indicator if active
  if selection_mode {
    let mode_text = "[SELECT v:exit] "
    col = buf.write_text(col, y, mode_text, selection_style, buf.width - col)
  }
  // Determine display URL: show focused link URL if available
  let (display_url, is_link_url) = match focused_link_url {
    Some(link_url) => (link_url, true)
    None => (url, false)
  }
  let link_url_style : TextStyle = {
    fg: highlight_fg,
    bg,
    bold: false,
    underline: false,
  }
  // Write URL part (possibly highlighted if it's a link URL)
  let url_style = if is_link_url { link_url_style } else { style }
  let url_text = " " + display_url
  col = buf.write_text(col, y, url_text, url_style, buf.width - col)
  // Write the rest of the status (skip if selection mode to save space)
  if !selection_mode {
    let rest = " | Links: " +
      (focused_link + 1).to_string() +
      "/" +
      link_count.to_string() +
      " | d:dark v:select "
    let _ = buf.write_text(col, y, rest, style, buf.width - col)
  }
}
