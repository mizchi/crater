///|
/// Simple key input example for native target
/// Demonstrates raw mode key reading with ANSI colors

///|
fn main {
  // Print welcome message with ANSI colors
  print_colored("Welcome to the Native Key Input Example!", Color::Cyan, bold=true)
  println("")
  println("Press keys to see them. Press 'q' to quit.")
  println("")

  // Enable raw mode for character-by-character input
  @tui.enable_raw_mode()

  // Main loop
  for {
    let key = @tui.read_key()
    if key.length() == 0 {
      // No key available, sleep a bit
      @tui.sleep(50)
      continue
    }

    // Check for quit
    if key == "q" || key == "Q" {
      break
    }

    // Handle special keys
    if key == "\u001b[A" {
      @tui.print_raw("[Up Arrow]\r\n")
    } else if key == "\u001b[B" {
      @tui.print_raw("[Down Arrow]\r\n")
    } else if key == "\u001b[C" {
      @tui.print_raw("[Right Arrow]\r\n")
    } else if key == "\u001b[D" {
      @tui.print_raw("[Left Arrow]\r\n")
    } else if key == "\u001b" {
      @tui.print_raw("[Escape]\r\n")
    } else if key == "\r" || key == "\n" {
      @tui.print_raw("[Enter]\r\n")
    } else if key == "\u007f" {
      @tui.print_raw("[Backspace]\r\n")
    } else if key == "\t" {
      @tui.print_raw("[Tab]\r\n")
    } else if key.length() == 1 {
      let code = key[0].to_int()
      if code < 32 {
        // Control character
        @tui.print_raw("[Ctrl+")
        @tui.print_raw((code + 64).to_string())
        @tui.print_raw("]\r\n")
      } else {
        // Regular character
        @tui.print_raw("Key: '")
        @tui.print_raw(key)
        @tui.print_raw("'\r\n")
      }
    } else {
      // Multi-byte character (UTF-8 or escape sequence)
      @tui.print_raw("Sequence: [")
      for i = 0; i < key.length(); i = i + 1 {
        let c = key[i]
        @tui.print_raw("0x")
        @tui.print_raw(c.to_int().to_string())
        if i < key.length() - 1 {
          @tui.print_raw(" ")
        }
      }
      @tui.print_raw("]\r\n")
    }
  }

  // Restore terminal settings
  @tui.cleanup_stdin()

  println("")
  print_colored("Goodbye!", Color::Yellow, bold=false)
  println("")
}

///|
/// ANSI color codes
enum Color {
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
}

///|
fn color_code(color : Color) -> Int {
  match color {
    Black => 30
    Red => 31
    Green => 32
    Yellow => 33
    Blue => 34
    Magenta => 35
    Cyan => 36
    White => 37
  }
}

///|
/// Print text with ANSI color
fn print_colored(text : String, color : Color, bold~ : Bool = false) -> Unit {
  let bold_code = if bold { "1;" } else { "" }
  let ansi_start = "\u001b[" + bold_code + color_code(color).to_string() + "m"
  let ansi_end = "\u001b[0m"
  println(ansi_start + text + ansi_end)
}
