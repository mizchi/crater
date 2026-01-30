///|
/// TUI Browser - Main entry point

///|
/// Character size constants for TUI mode (monospace font)
let char_width : Int = 8 // Width of one character in pixels

///|
let char_height : Int = 16 // Height of one character in pixels

///|
/// Default viewport size (used when terminal size not available)
let default_viewport_width : Int = 640 // 80 columns * 8px

///|
let default_viewport_height : Int = 384 // 24 rows * 16px

///|
/// Calculate viewport size from terminal dimensions
fn calculate_viewport(text_mode : Bool) -> (Int, Int) {
  if text_mode {
    // TUI text mode: use terminal size
    let (cols, rows) = @tui.get_terminal_size()
    let width = cols * char_width
    let height = rows * char_height
    (width, height)
  } else {
    // Sixel/debug mode: use default size
    (default_viewport_width, default_viewport_height)
  }
}

///|
/// Command line options
struct Options {
  url : String
  sixel : Bool
  text : Bool // New: TUI text mode
  debug : Bool
  json : Bool // AOM JSON output for AI scraping
  aom : Bool // AOM YAML snapshot output
  arc90 : Bool // Arc90 content extraction
  grounding : Bool // Visual grounding demo
  dark : Bool // Start in dark mode
  no_color : Bool // Disable color output (text layout only)
  extract_main : Bool // Extract main content text only
}

///|
/// Render and display the current page
fn render_page(browser : @shell.Browser, options : Options) -> Unit {
  if options.json {
    // AOM JSON output for AI scraping
    let json_output = browser.render_json()
    println(json_output)
  } else if options.aom {
    // AOM YAML snapshot output (Playwright-compatible)
    let aom_output = browser.render_aom()
    println(aom_output)
  } else if options.extract_main {
    // Extract main content text only
    let main_text = browser.render_extract_main()
    println(main_text)
  } else if options.arc90 {
    // Arc90 content extraction
    let arc90_output = browser.render_arc90()
    println(arc90_output)
  } else if options.grounding {
    // Visual grounding demo
    let grounding_output = browser.render_grounding()
    println(grounding_output)
  } else if options.sixel {
    let sixel = browser.render()
    @tui.print_raw(@tui.clear_screen())
    @tui.print_raw(sixel)
    println("")
    println(
      @tui.format_status_bar(
        browser.current_url,
        browser.links.length(),
        browser.focused_link,
      ),
    )
  } else if options.text {
    // TUI text mode: character-based rendering
    let text_output = browser.render_text()
    @tui.print_raw(text_output)
  } else if options.debug {
    // Debug mode: print layout tree
    browser.debug_layout()
  } else {
    println(
      "Page loaded. Use --sixel, --text, --json, --aom, or --debug to render.",
    )
  }
}

///|
/// Parse command line arguments
fn parse_args() -> Options? {
  let args = @tui.get_args()
  if args.length() == 0 {
    return None
  }
  let mut url = ""
  let mut sixel = false
  let mut text = false
  let mut debug = false
  let mut json = false
  let mut aom = false
  let mut arc90 = false
  let mut grounding = false
  let mut dark = false
  let mut no_color = false
  let mut extract_main = false
  for arg in args {
    if arg == "--sixel" {
      sixel = true
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
    } else if not(arg.has_prefix("--")) {
      url = arg
    }
  }
  if url.length() == 0 {
    None
  } else {
    // Default to text mode if no output mode is specified
    let text = if not(sixel) &&
      not(text) &&
      not(debug) &&
      not(json) &&
      not(aom) &&
      not(arc90) &&
      not(grounding) {
      true
    } else {
      text
    }
    Some({
      url,
      sixel,
      text,
      debug,
      json,
      aom,
      arc90,
      grounding,
      dark,
      no_color,
      extract_main,
    })
  }
}

///|
/// Entry point - async main
async fn main {
  let options = match parse_args() {
    Some(opts) => opts
    None => {
      println("Usage: npx @mizchi/crater-browser <URL> [options]")
      println(
        "Example: npx @mizchi/crater-browser https://www.cnn.co.jp/fringe/35129835.html",
      )
      println("")
      println("Options:")
      println("  --text   Render page as ANSI text (default)")
      println(
        "  --sixel  Render page as Sixel graphics (requires Sixel-capable terminal)",
      )
      println(
        "  --json      Output accessibility tree as JSON (for AI scraping)",
      )
      println(
        "  --aom       Output accessibility tree as YAML (Playwright format)",
      )
      println(
        "  --arc90     Run Arc90 content extraction (detect main content)",
      )
      println(
        "  --grounding Run visual grounding demo (spatial element queries)",
      )
      println("  --debug     Print layout tree for debugging")
      println(
        "  --dark      Start in dark mode (use prefers-color-scheme: dark)",
      )
      println("  --no-color  Disable color output (text layout only)")
      println("  --extract-main  Extract main content text only")
      return
    }
  }
  // Calculate viewport size based on mode (TUI uses terminal size)
  let (viewport_width, viewport_height) = calculate_viewport(options.text)
  let browser = @shell.Browser::new(viewport_width, viewport_height)
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
    let _ = browser.navigate_lightweight(options.url)
    render_page(browser, options)
    return
  }
  // For Arc90/Grounding/ExtractMain modes, still need full rendering for bounds info
  if options.arc90 || options.grounding || options.extract_main {
    let _ = browser.navigate(options.url)
    render_page(browser, options)
    return
  }
  // Enter TUI mode
  if options.sixel || options.text {
    // Enter alternate screen buffer (like vim/less) for clean display
    @tui.print_raw(@tui.enter_alt_screen())
    @tui.print_raw(@tui.hide_cursor())
    @tui.print_raw(@tui.enable_mouse()) // Enable mouse tracking
    @tui.print_raw(@tui.clear_screen())
  }
  // Show loading message (will be cleared when page renders)
  println("Loading " + options.url + "...")
  // Navigate to initial URL
  let _ = browser.navigate(options.url)
  render_page(browser, options)
  // Only enter interactive mode for sixel or text mode
  if not(options.sixel) && not(options.text) {
    return
  }
  // Main event loop
  let mut running = true
  while running {
    let key = @tui.read_key()
    // Use different key handling based on hint mode
    let action = if browser.hint_mode {
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
        browser.scroll_down(browser.viewport_height - 50)
        render_page(browser, options)
      }
      Some(@tui.PageUp) => {
        browser.scroll_up(browser.viewport_height - 50)
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
      Some(@tui.ActivateLink) =>
        match browser.get_focused_link_url() {
          Some(url) => {
            println("Navigating to: " + url)
            let _ = browser.navigate(url)
            render_page(browser, options)
          }
          None => ()
        }
      Some(@tui.GoToUrl(_)) => {
        @tui.print_raw(@tui.show_cursor())
        let url = @tui.read_line("Enter URL: ")
        @tui.print_raw(@tui.hide_cursor())
        if url.length() > 0 {
          println("Navigating to: " + url)
          let _ = browser.navigate(url)
          render_page(browser, options)
        }
      }
      Some(@tui.Refresh) => {
        println("Refreshing...")
        let _ = browser.navigate(browser.current_url)
        render_page(browser, options)
      }
      Some(@tui.Back) =>
        match browser.go_back() {
          Some(url) => {
            println("Going back to: " + url)
            render_page(browser, options)
          }
          None => ()
        }
      Some(@tui.Forward) =>
        match browser.go_forward() {
          Some(url) => {
            println("Going forward to: " + url)
            render_page(browser, options)
          }
          None => ()
        }
      Some(@tui.MouseClick(col, row)) =>
        // Handle mouse click - check for link at position
        match browser.get_link_at(col, row) {
          Some(url) => {
            println("Clicking link: " + url)
            let _ = browser.navigate(url)
            render_page(browser, options)
          }
          None => ()
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
            let _ = browser.navigate(url)
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
