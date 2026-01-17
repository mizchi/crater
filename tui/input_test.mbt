///|
/// Tests for input parsing

///|
test "parse_input: SGR mouse press format" {
  // ESC[<0;51;13M - Left click at (51, 13)
  let input = "\u001b[<0;51;13M"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="Left")
      inspect(mouse.event_type, content="Press")
      inspect(mouse.x, content="51")
      inspect(mouse.y, content="13")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: SGR mouse release format" {
  // ESC[<0;10;20m - Left release at (10, 20)
  let input = "\u001b[<0;10;20m"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="Left")
      inspect(mouse.event_type, content="Release")
      inspect(mouse.x, content="10")
      inspect(mouse.y, content="20")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: SGR mouse right click" {
  // ESC[<2;30;15M - Right click at (30, 15)
  let input = "\u001b[<2;30;15M"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="Right")
      inspect(mouse.event_type, content="Press")
      inspect(mouse.x, content="30")
      inspect(mouse.y, content="15")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: SGR mouse middle click" {
  // ESC[<1;5;5M - Middle click at (5, 5)
  let input = "\u001b[<1;5;5M"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="Middle")
      inspect(mouse.event_type, content="Press")
      inspect(mouse.x, content="5")
      inspect(mouse.y, content="5")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: SGR mouse scroll up" {
  // ESC[<64;20;10M - Scroll up at (20, 10)
  let input = "\u001b[<64;20;10M"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="ScrollUp")
      inspect(mouse.x, content="20")
      inspect(mouse.y, content="10")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: SGR mouse scroll down" {
  // ESC[<65;20;10M - Scroll down at (20, 10)
  let input = "\u001b[<65;20;10M"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="ScrollDown")
      inspect(mouse.x, content="20")
      inspect(mouse.y, content="10")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: SGR mouse drag" {
  // ESC[<32;25;30M - Left drag at (25, 30) (bit 32 set)
  let input = "\u001b[<32;25;30M"
  let event = parse_input(input)
  match event {
    InputEvent::Mouse(mouse) => {
      inspect(mouse.button, content="Left")
      inspect(mouse.event_type, content="Drag")
      inspect(mouse.x, content="25")
      inspect(mouse.y, content="30")
    }
    _ => fail("Expected Mouse event")
  }
}

///|
test "parse_input: arrow keys" {
  inspect(parse_input("\u001b[A"), content="Key(Special(Up, None))")
  inspect(parse_input("\u001b[B"), content="Key(Special(Down, None))")
  inspect(parse_input("\u001b[C"), content="Key(Special(Right, None))")
  inspect(parse_input("\u001b[D"), content="Key(Special(Left, None))")
}

///|
test "parse_input: printable characters" {
  let event = parse_input("a")
  inspect(event, content="Key(Char('a', None))")
  let event2 = parse_input("Z")
  inspect(event2, content="Key(Char('Z', None))")
}

///|
test "parse_input: control characters" {
  // Ctrl+C
  let event = parse_input("\u0003")
  inspect(event, content="Key(Char('c', Ctrl))")
  // Enter
  let event2 = parse_input("\r")
  inspect(event2, content="Key(Special(Enter, None))")
  // Escape
  let event3 = parse_input("\u001b")
  inspect(event3, content="Key(Special(Escape, None))")
}

///|
test "parse_input: Tab and BackTab" {
  // Tab
  let event = parse_input("\t")
  inspect(event, content="Key(Special(Tab, None))")
  // Shift+Tab (BackTab)
  let event2 = parse_input("\u001b[Z")
  inspect(event2, content="Key(Special(BackTab, Shift))")
}

///|
test "parse_input: Backspace and Delete" {
  // Backspace (DEL)
  let event = parse_input("\u007f")
  inspect(event, content="Key(Special(Backspace, None))")
  // Delete key
  let event2 = parse_input("\u001b[3~")
  inspect(event2, content="Key(Special(Delete, None))")
}

///|
test "parse_input: Home and End" {
  // Home
  let event = parse_input("\u001b[H")
  inspect(event, content="Key(Special(Home, None))")
  // End
  let event2 = parse_input("\u001b[F")
  inspect(event2, content="Key(Special(End, None))")
}

///|
test "parse_input: Function keys" {
  // F1 - F4 use SS3 format
  inspect(parse_input("\u001bOP"), content="Key(Special(F(1), None))")
  inspect(parse_input("\u001bOQ"), content="Key(Special(F(2), None))")
  inspect(parse_input("\u001bOR"), content="Key(Special(F(3), None))")
  inspect(parse_input("\u001bOS"), content="Key(Special(F(4), None))")
}

///|
test "parse_input: Page Up/Down" {
  inspect(parse_input("\u001b[5~"), content="Key(Special(PageUp, None))")
  inspect(parse_input("\u001b[6~"), content="Key(Special(PageDown, None))")
}

///|
test "parse_input: unknown sequences" {
  // Unknown CSI sequence
  let event = parse_input("\u001b[999X")
  match event {
    InputEvent::Unknown(_) => ()
    _ => fail("Expected Unknown event")
  }
}
