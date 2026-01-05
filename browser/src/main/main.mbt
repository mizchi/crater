///|
/// TUI Browser - Main entry point

///|
/// Default URL to load
let default_url : String = "https://example.com"

///|
/// Default viewport size
let viewport_width : Int = 375

///|
let viewport_height : Int = 450

///|
/// Render and display the current page
fn render_page(browser : @browser.Browser) -> Unit {
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
}

///|
/// Entry point - async main
async fn main {
  let browser = @browser.Browser::new(viewport_width, viewport_height)
  // Print welcome message
  @tui.print_raw(@tui.clear_screen())
  @tui.print_raw(@tui.hide_cursor())
  println("TUI Browser MVP")
  println("Loading " + default_url + "...")
  println("")
  // Navigate to default URL
  try {
    let _ = browser.navigate(default_url)
    render_page(browser)
  } catch {
    err => {
      println("Error loading page: " + Show::to_string(err))
      return
    }
  }
  // Main event loop
  let mut running = true
  while running {
    let key = @tui.read_key()
    match @tui.key_to_action(key) {
      Some(@tui.Quit) => {
        @tui.print_raw(@tui.show_cursor())
        println("Goodbye!")
        running = false
      }
      Some(@tui.ScrollDown) => {
        browser.scroll_down(50)
        render_page(browser)
      }
      Some(@tui.ScrollUp) => {
        browser.scroll_up(50)
        render_page(browser)
      }
      Some(@tui.NextLink) => {
        browser.next_link()
        render_page(browser)
      }
      Some(@tui.PrevLink) => {
        browser.prev_link()
        render_page(browser)
      }
      Some(@tui.ActivateLink) =>
        match browser.get_focused_link_url() {
          Some(url) => {
            println("Navigating to: " + url)
            try {
              let _ = browser.navigate(url)
              render_page(browser)
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
            render_page(browser)
          } catch {
            err => println("Error: " + Show::to_string(err))
          }
        }
      }
      Some(@tui.Refresh) => {
        println("Refreshing...")
        try {
          let _ = browser.navigate(browser.current_url)
          render_page(browser)
        } catch {
          err => println("Error: " + Show::to_string(err))
        }
      }
      None => ()
    }
  }
}
