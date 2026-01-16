///|
/// Simple readline example for native target
/// Demonstrates line-based input/output with ANSI colors

///|
async fn main {
  // Print welcome message with ANSI colors
  print_colored("Welcome to the Native Readline Example!", Color::Cyan, bold=true)
  println("")
  println("Type something and press Enter. Type 'quit' to exit.")
  println("")

  // Main loop
  for {
    // Print prompt
    print_colored("> ", Color::Green, bold=true)

    // Read a line from stdin
    let line = read_line_async()

    // Check for quit
    if line == "quit" || line == "exit" {
      print_colored("Goodbye!", Color::Yellow, bold=false)
      println("")
      break
    }

    // Echo back with some formatting
    if line.length() > 0 {
      print_colored("You said: ", Color::Blue, bold=false)
      print_colored(line, Color::White, bold=true)
      println("")

      // Show some info about the input
      print_colored("  Length: ", Color::Magenta, bold=false)
      println(line.length().to_string())
    } else {
      print_colored("(empty input)", Color::Red, bold=false)
      println("")
    }
  }
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
/// Print text with ANSI color (uses println since native doesn't have print)
fn print_colored(text : String, color : Color, bold~ : Bool = false) -> Unit {
  let bold_code = if bold { "1;" } else { "" }
  let ansi_start = "\u001b[" + bold_code + color_code(color).to_string() + "m"
  let ansi_end = "\u001b[0m"
  // Note: using println instead of print since native doesn't have print without newline
  // This will add extra newlines but it's a limitation of the native stub
  println(ansi_start + text + ansi_end)
}

///|
/// Read a line from stdin asynchronously
async fn read_line_async() -> String {
  let buf = FixedArray::make(1024, b'\x00')
  let n = @stdio.stdin.read(buf, offset=0, max_len=1024)
  if n <= 0 {
    return ""
  }
  // Convert bytes to string, trim trailing newline
  let bytes = Bytes::from_array(buf)
  let s = bytes.to_unchecked_string()
  let view = s[:n]
  view.to_string().trim_end(chars="\n\r").to_string()
}
