///|
test "CharBuffer::new creates buffer of correct size" {
  let buf = CharBuffer::new(80, 24)
  inspect(buf.width, content="80")
  inspect(buf.height, content="24")
  inspect(buf.cells.length(), content="1920")
}

///|
test "CharBuffer::set_cell and get_cell" {
  let buf = CharBuffer::new(10, 5)
  let cell : CharCell = {
    char: 'X',
    fg: @types.Color::rgb(255, 0, 0),
    bg: @types.Color::transparent(),
    bold: true,
    underline: false,
    reverse: false,
  }
  buf.set_cell(3, 2, cell)
  let retrieved = buf.get_cell(3, 2)
  inspect(retrieved.char, content="X")
  inspect(retrieved.bold, content="true")
}

///|
test "CharBuffer::set_cell bounds check" {
  let buf = CharBuffer::new(10, 5)
  let cell = CharCell::from_char('X')
  // These should not crash - they're silently ignored
  buf.set_cell(-1, 0, cell)
  buf.set_cell(0, -1, cell)
  buf.set_cell(10, 0, cell)
  buf.set_cell(0, 5, cell)
  // Buffer should still have default cells
  let default_cell = buf.get_cell(0, 0)
  inspect(default_cell.char, content=" ")
}

///|
test "CharBuffer::fill_rect" {
  let buf = CharBuffer::new(10, 5)
  let cell : CharCell = {
    char: '#',
    fg: @types.Color::white(),
    bg: @types.Color::rgb(0, 0, 255),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(2, 1, 3, 2, cell)
  // Check filled area
  inspect(buf.get_cell(2, 1).char, content="#")
  inspect(buf.get_cell(3, 1).char, content="#")
  inspect(buf.get_cell(4, 1).char, content="#")
  inspect(buf.get_cell(2, 2).char, content="#")
  // Check outside area
  inspect(buf.get_cell(1, 1).char, content=" ")
  inspect(buf.get_cell(5, 1).char, content=" ")
}

///|
test "CharBuffer::write_text simple" {
  let buf = CharBuffer::new(20, 5)
  let style = TextStyle::default()
  let written = buf.write_text(0, 0, "Hello", style, 20)
  inspect(written, content="5")
  inspect(buf.get_cell(0, 0).char, content="H")
  inspect(buf.get_cell(1, 0).char, content="e")
  inspect(buf.get_cell(4, 0).char, content="o")
  inspect(buf.get_cell(5, 0).char, content=" ")
}

///|
test "CharBuffer::write_text respects max_width" {
  let buf = CharBuffer::new(20, 5)
  let style = TextStyle::default()
  let written = buf.write_text(0, 0, "Hello World", style, 5)
  inspect(written, content="5")
  inspect(buf.get_cell(4, 0).char, content="o")
  inspect(buf.get_cell(5, 0).char, content=" ") // Not written
}

///|
test "char_display_width for ASCII" {
  inspect(char_display_width('A'), content="1")
  inspect(char_display_width('z'), content="1")
  inspect(char_display_width(' '), content="1")
}

///|
test "char_display_width for CJK" {
  inspect(char_display_width('日'), content="2")
  inspect(char_display_width('本'), content="2")
  inspect(char_display_width('あ'), content="2")
  inspect(char_display_width('ア'), content="2")
}

///|
test "CharBuffer::write_text with CJK" {
  let buf = CharBuffer::new(20, 5)
  let style = TextStyle::default()
  let written = buf.write_text(0, 0, "日本", style, 20)
  // 日=2, 本=2 → 4 columns
  inspect(written, content="4")
  inspect(buf.get_cell(0, 0).char, content="日")
  // Position 1 should be placeholder for wide char
  inspect(buf.get_cell(1, 0).char, content="\u0000")
  inspect(buf.get_cell(2, 0).char, content="本")
}

///|
test "CharCell::default" {
  let cell = CharCell::default()
  inspect(cell.char, content=" ")
  inspect(cell.bold, content="false")
  inspect(cell.underline, content="false")
}

///|
test "TextStyle::default" {
  let style = TextStyle::default()
  inspect(style.bold, content="false")
  inspect(style.underline, content="false")
}

///|
test "buffer_to_plain with underline" {
  let buf = CharBuffer::new(10, 1)
  // Write underlined text
  let style : TextStyle = {
    fg: @types.Color::white(),
    bg: @types.Color::transparent(),
    bold: false,
    underline: true,
  }
  let _ = buf.write_text(2, 0, "Link", style, 10)
  let output = buffer_to_plain(buf)
  // Should contain underline escape sequence
  inspect(output.contains("\u001b[4m"), content="true")
  inspect(output.contains("Link"), content="true")
}

///|
test "buffer_to_plain_with_links generates OSC 8" {
  let buf = CharBuffer::new(20, 1)
  // Write underlined text
  let style : TextStyle = {
    fg: @types.Color::white(),
    bg: @types.Color::transparent(),
    bold: false,
    underline: true,
  }
  let _ = buf.write_text(2, 0, "Click", style, 20)
  let links : Array[PlainLink] = [
    { col: 2, row: 0, width: 5, url: "https://example.com" },
  ]
  let output = buffer_to_plain_with_links(buf, links)
  // Debug: print escape sequences in hex for verification
  println("Output length: " + output.length().to_string())
  println("Contains OSC start: " + output.contains("\u001b]8;;").to_string())
  println("Contains URL: " + output.contains("https://example.com").to_string())
  // Check OSC 8 end sequence (ESC ] 8 ; ; BEL)
  let osc_end = "\u001b]8;;\u0007"
  println("Contains OSC end: " + output.contains(osc_end).to_string())
  // Print full output as hex bytes for debugging
  let hex = StringBuilder::new()
  for c in output {
    let code = c.to_int()
    if code < 32 || code > 126 {
      hex.write_string("<")
      hex.write_string(code.to_string())
      hex.write_string(">")
    } else {
      hex.write_char(c)
    }
  }
  println("Full output: " + hex.to_string())
  // Should contain OSC 8 hyperlink sequences
  inspect(output.contains("\u001b]8;;https://example.com"), content="true")
  inspect(output.contains("Click"), content="true")
  // Verify link is properly closed
  inspect(output.contains(osc_end), content="true")
}

///|
test "OSC 8 escape sequence format" {
  // Verify the escape sequence format is correct
  let start = ansi_hyperlink_start("https://test.com")
  let end = ansi_hyperlink_end()
  // Build byte string for debugging
  let start_bytes = StringBuilder::new()
  for c in start {
    start_bytes.write_string(c.to_int().to_string())
    start_bytes.write_string(" ")
  }
  println("Start sequence bytes: " + start_bytes.to_string())
  let end_bytes = StringBuilder::new()
  for c in end {
    end_bytes.write_string(c.to_int().to_string())
    end_bytes.write_string(" ")
  }
  println("End sequence bytes: " + end_bytes.to_string())
  // ESC = 27, ] = 93, 8 = 56, ; = 59, BEL = 7
  // Expected start: ESC ] 8 ; ; URL BEL
  // Expected end: ESC ] 8 ; ; BEL
  inspect(start.has_prefix("\u001b]8;;"), content="true")
  inspect(end == "\u001b]8;;\u0007", content="true")
}
