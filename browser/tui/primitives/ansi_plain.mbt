///|
/// Plain terminal serialization helpers for character buffers.

///|
/// Convert CharBuffer to plain text string (no ANSI color codes)
/// Used for --no-color mode
/// Preserves underline attribute for links
pub fn buffer_to_plain(buf : CharBuffer) -> String {
  let sb = StringBuilder::new()
  let style_state = PlainStyleState::new()
  for row = 0; row < buf.height; row = row + 1 {
    // Move to start of row (1-indexed)
    sb.write_string(ansi_move_to(row + 1, 1))
    for col = 0; col < buf.width; col = col + 1 {
      style_state.write_cell(sb, buf.get_cell(col, row))
    }
    style_state.reset_underline(sb)
  }
  sb.to_string()
}

///|
/// Link info for plain mode hyperlinks
pub(all) struct PlainLink {
  col : Int
  row : Int
  width : Int
  url : String
}

///|
priv struct PlainStyleState {
  mut underline : Bool
}

///|
fn PlainStyleState::new() -> PlainStyleState {
  { underline: false }
}

///|
fn PlainStyleState::reset_underline(
  self : PlainStyleState,
  sb : StringBuilder,
) -> Unit {
  if self.underline {
    sb.write_string(ansi_reset())
    self.underline = false
  }
}

///|
fn PlainStyleState::write_cell(
  self : PlainStyleState,
  sb : StringBuilder,
  cell : CharCell,
) -> Unit {
  // Skip wide char placeholder
  if cell.char == '\u0000' {
    return
  }
  // Handle underline toggle (for links)
  if cell.underline && !self.underline {
    sb.write_string(ansi_underline())
    self.underline = true
  } else if !cell.underline && self.underline {
    sb.write_string(ansi_reset())
    self.underline = false
  }
  // Write the character (no color codes)
  sb.write_char(cell.char)
}

///|
/// Convert CharBuffer to plain text with clickable hyperlinks
/// Uses OSC 8 escape sequences for terminal hyperlinks
/// Preserves underline attribute for links
pub fn buffer_to_plain_with_links(
  buf : CharBuffer,
  links : Array[PlainLink],
) -> String {
  // Build a map of link start positions for quick lookup
  let link_starts : Map[Int, PlainLink] = {}
  let link_ends : Map[Int, Bool] = {}
  for link in links {
    let start_key = link.row * buf.width + link.col
    link_starts.set(start_key, link)
    let end_key = link.row * buf.width + link.col + link.width
    link_ends.set(end_key, true)
  }
  let sb = StringBuilder::new()
  let style_state = PlainStyleState::new()
  let mut in_hyperlink = false
  for row = 0; row < buf.height; row = row + 1 {
    // Move to start of row (1-indexed)
    sb.write_string(ansi_move_to(row + 1, 1))
    for col = 0; col < buf.width; col = col + 1 {
      let cell = buf.get_cell(col, row)
      let pos_key = row * buf.width + col
      // Check for link end (before processing current cell)
      if link_ends.contains(pos_key) && in_hyperlink {
        sb.write_string(ansi_hyperlink_end())
        in_hyperlink = false
      }
      // Check for link start
      match link_starts.get(pos_key) {
        Some(link) => {
          sb.write_string(ansi_hyperlink_start(link.url))
          in_hyperlink = true
        }
        None => ()
      }
      style_state.write_cell(sb, cell)
    }
    // End hyperlink at end of row if still active
    if in_hyperlink {
      sb.write_string(ansi_hyperlink_end())
      in_hyperlink = false
    }
    style_state.reset_underline(sb)
  }
  sb.to_string()
}
