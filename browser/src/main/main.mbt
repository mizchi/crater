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
}

///|
/// Render and display the current page
fn render_page(browser : @browser.Browser, options : Options) -> Unit {
  if options.sixel {
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
    @tui.print_raw(@tui.clear_screen())
    @tui.print_raw(text_output)
  } else if options.debug {
    // Debug mode: print layout tree
    browser.debug_layout()
  } else {
    println("Page loaded. Use --sixel, --text, or --debug to render.")
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
  for arg in args {
    if arg == "--sixel" {
      sixel = true
    } else if arg == "--text" {
      text = true
    } else if arg == "--debug" {
      debug = true
    } else if not(arg.has_prefix("--")) {
      url = arg
    }
  }
  if url.length() == 0 {
    None
  } else {
    Some({ url, sixel, text, debug })
  }
}

///|
/// Entry point - async main
async fn main {
  let options = match parse_args() {
    Some(opts) => opts
    None => {
      println(
        "Usage: moon run src/main --target js -- <URL> [--sixel|--text] [--debug]",
      )
      println(
        "Example: moon run src/main --target js -- https://example.com --text",
      )
      println("")
      println("Options:")
      println(
        "  --sixel  Render page as Sixel graphics (requires Sixel-capable terminal)",
      )
      println("  --text   Render page as ANSI text (works in any terminal)")
      println("  --debug  Print layout tree for debugging")
      return
    }
  }
  // Calculate viewport size based on mode (TUI uses terminal size)
  let (viewport_width, viewport_height) = calculate_viewport(options.text)
  let browser = @browser.Browser::new(viewport_width, viewport_height)
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
  try {
    let _ = browser.navigate(options.url)
    render_page(browser, options)
  } catch {
    err => {
      // Cleanup before exit on error
      if options.sixel || options.text {
        @tui.cleanup_stdin()
        @tui.print_raw(@tui.disable_mouse())
        @tui.print_raw(@tui.show_cursor())
        @tui.print_raw(@tui.exit_alt_screen())
      }
      println("Error loading page: " + Show::to_string(err))
      return
    }
  }
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
            try {
              let _ = browser.navigate(url)
              render_page(browser, options)
            } catch {
              err => println("Error: " + Show::to_string(err))
            }
          }
          None => ()
        }
      Some(@tui.GoToUrl(_)) => {
        @tui.print_raw(@tui.show_cursor())
        let url = @tui.read_line("Enter URL: ")
        @tui.print_raw(@tui.hide_cursor())
        if url.length() > 0 {
          println("Navigating to: " + url)
          try {
            let _ = browser.navigate(url)
            render_page(browser, options)
          } catch {
            err => println("Error: " + Show::to_string(err))
          }
        }
      }
      Some(@tui.Refresh) => {
        println("Refreshing...")
        try {
          let _ = browser.navigate(browser.current_url)
          render_page(browser, options)
        } catch {
          err => println("Error: " + Show::to_string(err))
        }
      }
      Some(@tui.Back) => {
        try {
          match browser.go_back() {
            Some(url) => {
              println("Going back to: " + url)
              render_page(browser, options)
            }
            None => ()
          }
        } catch {
          err => println("Error: " + Show::to_string(err))
        }
      }
      Some(@tui.MouseClick(col, row)) =>
        // Handle mouse click - check for link at position
        match browser.get_link_at(col, row) {
          Some(url) => {
            println("Clicking link: " + url)
            try {
              let _ = browser.navigate(url)
              render_page(browser, options)
            } catch {
              err => println("Error: " + Show::to_string(err))
            }
          }
          None => ()
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
            try {
              let _ = browser.navigate(url)
              render_page(browser, options)
            } catch {
              err => println("Error: " + Show::to_string(err))
            }
          }
          None =>
            // Re-render to show updated hint input
            render_page(browser, options)
        }
      None => ()
    }
  }
}
