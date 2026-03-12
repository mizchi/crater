///|
/// TUI Browser - Main entry point

///|
let char_width : Int = 8 // Width of one character in pixels

///|
let char_height : Int = 16 // Height of one character in pixels

///|
let default_viewport_height : Int = 384 // 24 rows * 16px

///|
/// Parse a simple integer from string (returns 0 on failure)
fn parse_int_simple(s : String) -> Int {
  let mut result = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return 0
    }
  }
  result
}

///|
/// Calculate viewport size and terminal columns from terminal dimensions
/// Returns (viewport_width_px, viewport_height_px, terminal_cols)
fn calculate_viewport(text_mode : Bool, override_cols : Int) -> (Int, Int, Int) {
  let (detected_cols, rows) = @tui.get_terminal_size()
  let cols = if override_cols > 0 { override_cols } else { detected_cols }
  let height = if text_mode {
    rows * char_height
  } else {
    default_viewport_height
  }
  let width = cols * char_width
  (width, height, cols)
}

///|
/// Headless mode type
enum HeadlessMode {
  Off // Interactive mode
  Full // Render full page content
  Viewport // Render viewport only
}

///|
/// Command line options
struct Options {
  url : String
  sixel : Bool
  kitty : Bool
  text : Bool // New: TUI text mode
  debug : Bool
  json : Bool // AOM JSON output for AI scraping
  aom : Bool // AOM YAML snapshot output
  arc90 : Bool // Arc90 content extraction
  grounding : Bool // Visual grounding demo
  dark : Bool // Start in dark mode
  no_color : Bool // Disable color output (text layout only)
  extract_main : Bool // Extract main content text only
  headless : HeadlessMode // Headless rendering mode
  show_help : Bool // Show help message
  width : Int // Override viewport width in columns (0 = auto-detect)
}

///|
/// Navigate with error handling
async fn safe_navigate(browser : @shell.Browser, url : String) -> Unit {
  try {
    let _ = browser.navigate(url)
  } catch {
    err => println("Navigation error: \{err}")
  }
}

///|
async fn write_stdout_io(s : String) -> Unit {
  @stdio.stdout.write(s) catch {
    _ => ()
  }
}

///|
/// Render and display the current page
async fn render_page(browser : @shell.Browser, options : Options) -> Unit {
  if options.json {
    // AOM JSON output for AI scraping
    let json_output = browser.render_output(@shell.OutputMode::Json)
    println(json_output)
  } else if options.aom {
    // AOM YAML snapshot output (Playwright-compatible)
    let aom_output = browser.render_output(@shell.OutputMode::Aom)
    println(aom_output)
  } else if options.extract_main {
    // Extract main content text only
    let main_text = browser.render_output(@shell.OutputMode::ExtractMain)
    println(main_text)
  } else if options.arc90 {
    // Arc90 content extraction
    let arc90_output = browser.render_output(@shell.OutputMode::Arc90)
    println(arc90_output)
  } else if options.grounding {
    // Visual grounding demo
    let grounding_output = browser.render_output(@shell.OutputMode::Grounding)
    println(grounding_output)
  } else if options.sixel {
    let sixel = browser.render_output(@shell.OutputMode::Sixel)
    @tui.print_raw(@tui.clear_screen())
    @tui.print_raw(sixel)
    println("")
    println(
      @tui.format_status_bar(
        browser.get_current_url(),
        browser.get_link_count(),
        browser.get_focused_link_index(),
      ),
    )
  } else if options.kitty {
    write_stdout_io(@tui.clear_screen())
    browser.write_output(@shell.OutputMode::Kitty, @stdio.stdout)
    println("")
    println(
      @tui.format_status_bar(
        browser.get_current_url(),
        browser.get_link_count(),
        browser.get_focused_link_index(),
      ),
    )
  } else if options.text {
    // TUI text mode: character-based rendering
    let text_output = browser.render_output(@shell.OutputMode::Text)
    @tui.print_raw(text_output)
  } else if options.debug {
    // Debug mode: print layout tree
    browser.debug_layout()
  } else {
    println(
      "Page loaded. Use --sixel, --kitty, --text, --json, --aom, or --debug to render.",
    )
  }
}

///|
/// Print help message
fn print_help() -> Unit {
  println("crater-browser - A terminal-based web browser")
  println("")
  println("USAGE:")
  println("  npx @mizchi/crater-browser [OPTIONS] <URL>")
  println("")
  println("ARGUMENTS:")
  println("  <URL>    The URL to navigate to")
  println("")
  println("OPTIONS:")
  println("  -h, --help          Show this help message and exit")
  println("")
  println("  Output Modes (mutually exclusive):")
  println("    --text            Render page as ANSI text (default)")
  println("    --sixel           Render page as Sixel graphics")
  println("    --kitty           Render page with Kitty graphics protocol")
  println("    --json            Output accessibility tree as JSON")
  println(
    "    --aom             Output accessibility tree as YAML (Playwright format)",
  )
  println("    --arc90           Run Arc90 content extraction")
  println("    --grounding       Run visual grounding demo")
  println("    --extract-main    Extract main content text only")
  println("    --debug           Print layout tree for debugging")
  println("")
  println("  Headless Mode:")
  println("    --headless=full      Render full page and exit (no interaction)")
  println("    --headless=viewport  Render viewport only and exit")
  println("")
  println("  Display Options:")
  println(
    "    --dark            Start in dark mode (prefers-color-scheme: dark)",
  )
  println("    --no-color        Disable color output (underline links only)")
  println("    --width=N         Override viewport width in columns")
  println("")
  println("EXAMPLES:")
  println("  npx @mizchi/crater-browser https://example.com")
  println(
    "  npx @mizchi/crater-browser --headless=viewport https://example.com",
  )
  println("  npx @mizchi/crater-browser --json https://example.com")
  println("  npx @mizchi/crater-browser --dark --no-color https://example.com")
  println("")
  println("KEYBINDINGS (Interactive Mode):")
  println("  j/k, Arrow keys     Scroll up/down")
  println("  Ctrl-D/U, Space     Page down/up")
  println("  Tab, n              Focus next link")
  println("  Shift-Tab, p        Focus previous link")
  println("  Enter               Activate focused link")
  println("  f                   Enter hint mode (hit-a-hint)")
  println("  g                   Go to URL")
  println("  r                   Refresh page")
  println("  H, Backspace        Go back")
  println("  L                   Go forward")
  println("  d                   Toggle dark mode")
  println("  v                   Toggle selection mode (for copy)")
  println("  q                   Quit")
}

///|
/// Parse command line arguments
fn parse_args() -> Options {
  parse_args_list(@tui.get_args())
}

///|
fn parse_args_list(args : Array[String]) -> Options {
  let mut url = ""
  let mut sixel = false
  let mut kitty = false
  let mut text = false
  let mut debug = false
  let mut json = false
  let mut aom = false
  let mut arc90 = false
  let mut grounding = false
  let mut dark = false
  let mut no_color = false
  let mut extract_main = false
  let mut headless : HeadlessMode = Off
  let mut show_help = false
  let mut width = 0
  for arg in args {
    if arg == "-h" || arg == "--help" {
      show_help = true
    } else if arg.has_prefix("--width=") {
      let val = arg[8:].to_string()
      width = parse_int_simple(val)
    } else if arg == "--sixel" {
      sixel = true
    } else if arg == "--kitty" {
      kitty = true
    } else if arg == "--text" {
      text = true
    } else if arg == "--debug" {
      debug = true
    } else if arg == "--arc90" {
      arc90 = true
    } else if arg == "--grounding" {
      grounding = true
    } else if arg == "--json" {
      json = true
    } else if arg == "--aom" {
      aom = true
    } else if arg == "--dark" {
      dark = true
    } else if arg == "--no-color" {
      no_color = true
    } else if arg == "--extract-main" {
      extract_main = true
    } else if arg == "--headless" || arg == "--headless=viewport" {
      headless = Viewport
    } else if arg == "--headless=full" {
      headless = Full
    } else if not(arg.has_prefix("-")) {
      url = arg
    }
  }
  // Default to text mode if no output mode is specified
  let text = if not(sixel) &&
    not(kitty) &&
    not(text) &&
    not(debug) &&
    not(json) &&
    not(aom) &&
    not(arc90) &&
    not(grounding) &&
    not(extract_main) {
    true
  } else {
    text
  }
  {
    url,
    sixel,
    kitty,
    text,
    debug,
    json,
    aom,
    arc90,
    grounding,
    dark,
    no_color,
    extract_main,
    headless,
    show_help,
    width,
  }
}

///|
/// Entry point - async main
async fn main {
  let options = parse_args()
  // Show help if requested or no URL provided
  if options.show_help {
    print_help()
    return
  }
  if options.url.length() == 0 {
    println("Error: URL is required")
    println("")
    println("Usage: npx @mizchi/crater-browser [OPTIONS] <URL>")
    println("")
    println("Run with -h or --help for more information.")
    return
  }
  // Calculate viewport size based on mode (TUI uses terminal size)
  let (viewport_width, viewport_height, terminal_cols) = calculate_viewport(
    options.text,
    options.width,
  )
  let browser = @shell.Browser::new(
    viewport_width,
    viewport_height,
    terminal_cols~,
  )
  // Set dark mode if requested
  if options.dark {
    browser.set_dark_mode(true)
  }
  // Set no-color mode if requested
  if options.no_color {
    browser.set_no_color(true)
  }
  // For JSON/AOM modes, use lightweight navigation (skip CSS cascade and layout)
  if options.json || options.aom {
    try {
      let _ = browser.navigate_lightweight(options.url)
    } catch {
      err => println("Navigation error: \{err}")
    }
    render_page(browser, options)
    return
  }
  // For Arc90/Grounding/ExtractMain modes, still need full rendering for bounds info
  if options.arc90 || options.grounding || options.extract_main {
    try {
      let _ = browser.navigate(options.url)
    } catch {
      err => println("Navigation error: \{err}")
    }
    render_page(browser, options)
    return
  }
  // Headless mode: render and exit without interaction
  match options.headless {
    Full => {
      // Render full page content
      try {
        let _ = browser.navigate(options.url)
      } catch {
        err => println("Navigation error: \{err}")
      }
      // For full mode, we need to scroll through entire content
      // For now, just render the initial viewport
      // TODO: Implement full page rendering by scrolling through content
      let text_output = browser.render_output(@shell.OutputMode::Text)
      @tui.print_raw(text_output)
      return
    }
    Viewport => {
      // Render viewport only
      try {
        let _ = browser.navigate(options.url)
      } catch {
        err => println("Navigation error: \{err}")
      }
      let text_output = browser.render_output(@shell.OutputMode::Text)
      @tui.print_raw(text_output)
      return
    }
    Off => ()
  }
  // Enter TUI mode
  if options.sixel || options.kitty || options.text {
    // Enter alternate screen buffer (like vim/less) for clean display
    @tui.print_raw(@tui.enter_alt_screen())
    @tui.print_raw(@tui.hide_cursor())
    @tui.print_raw(@tui.enable_mouse()) // Enable mouse tracking
    @tui.print_raw(@tui.clear_screen())
  }
  // Show loading message (will be cleared when page renders)
  println("Loading " + options.url + "...")
  // Navigate to initial URL
  try {
    let _ = browser.navigate(options.url)
  } catch {
    err => println("Navigation error: \{err}")
  }
  render_page(browser, options)
  // Only enter interactive mode for sixel or text mode
  if not(options.sixel) && not(options.kitty) && not(options.text) {
    return
  }
  // Main event loop
  let mut running = true
  while running {
    let key = @tui.read_key_with_timeout(16)
    if key.length() == 0 {
      if browser.tick_js() {
        render_page(browser, options)
      }
      continue
    }
    // Use different key handling based on hint mode
    let action = if browser.is_hint_mode() {
      @tui.key_to_hint_action(key)
    } else {
      @tui.key_to_action(key)
    }
    match action {
      Some(@tui.Quit) => {
        @tui.cleanup_stdin()
        @tui.print_raw(@tui.disable_mouse())
        @tui.print_raw(@tui.show_cursor())
        @tui.print_raw(@tui.exit_alt_screen())
        println("Goodbye!")
        running = false
      }
      Some(@tui.ScrollDown) => {
        browser.scroll_down(50)
        render_page(browser, options)
      }
      Some(@tui.ScrollUp) => {
        browser.scroll_up(50)
        render_page(browser, options)
      }
      Some(@tui.PageDown) => {
        // Scroll by viewport height (minus some overlap)
        browser.scroll_down(browser.get_viewport_height() - 50)
        render_page(browser, options)
      }
      Some(@tui.PageUp) => {
        browser.scroll_up(browser.get_viewport_height() - 50)
        render_page(browser, options)
      }
      Some(@tui.NextLink) => {
        browser.next_link()
        render_page(browser, options)
      }
      Some(@tui.PrevLink) => {
        browser.prev_link()
        render_page(browser, options)
      }
      Some(@tui.ActivateLink) => {
        let activated = browser.activate_focused_link() catch { _ => false }
        if activated {
          render_page(browser, options)
        }
      }
      Some(@tui.GoToUrl(_)) => {
        @tui.print_raw(@tui.show_cursor())
        let url = @tui.read_line("Enter URL: ")
        @tui.print_raw(@tui.hide_cursor())
        if url.length() > 0 {
          println("Navigating to: " + url)
          safe_navigate(browser, url)
          render_page(browser, options)
        }
      }
      Some(@tui.Refresh) => {
        println("Refreshing...")
        safe_navigate(browser, browser.get_current_url())
        render_page(browser, options)
      }
      Some(@tui.Back) => {
        let back_url : String? = browser.go_back() catch { _ => None }
        match back_url {
          Some(url) => {
            println("Going back to: " + url)
            render_page(browser, options)
          }
          None => ()
        }
      }
      Some(@tui.Forward) => {
        let fwd_url : String? = browser.go_forward() catch { _ => None }
        match fwd_url {
          Some(url) => {
            println("Going forward to: " + url)
            render_page(browser, options)
          }
          None => ()
        }
      }
      Some(@tui.MouseClick(col, row)) => {
        let activated = browser.activate_link_at(col, row) catch { _ => false }
        if activated {
          render_page(browser, options)
        }
      }
      Some(@tui.MouseScrollUp(_, _)) => {
        // Mouse wheel scroll up - scroll page up
        browser.scroll_up(48) // 3 lines * 16px
        render_page(browser, options)
      }
      Some(@tui.MouseScrollDown(_, _)) => {
        // Mouse wheel scroll down - scroll page down
        browser.scroll_down(48) // 3 lines * 16px
        render_page(browser, options)
      }
      Some(@tui.EnterHintMode) => {
        browser.enter_hint_mode()
        render_page(browser, options)
      }
      Some(@tui.ExitHintMode) => {
        browser.exit_hint_mode()
        render_page(browser, options)
      }
      Some(@tui.HintChar(c)) =>
        // Process hint character and navigate if matched
        match browser.process_hint_char(c) {
          Some(url) => {
            safe_navigate(browser, url)
            render_page(browser, options)
          }
          None =>
            // Re-render to show updated hint input
            render_page(browser, options)
        }
      Some(@tui.ToggleRawMode) => {
        let entering = browser.toggle_selection_mode()
        if entering {
          // Entering selection mode - disable raw mode for text selection
          @tui.cleanup_stdin()
          @tui.print_raw(@tui.disable_mouse())
          @tui.print_raw(@tui.show_cursor())
        } else {
          // Exiting selection mode - re-enable raw mode
          @tui.enable_raw_mode()
          @tui.print_raw(@tui.hide_cursor())
          @tui.print_raw(@tui.enable_mouse())
        }
        render_page(browser, options)
      }
      Some(@tui.ToggleDarkMode) => {
        browser.toggle_dark_mode()
        render_page(browser, options)
      }
      None => ()
    }
  }
}
