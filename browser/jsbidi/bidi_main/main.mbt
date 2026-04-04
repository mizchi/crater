///|
/// WebDriver BiDi Server Entry Point
///
/// Run with: deno run -A ../../jsbidi/_build/js/release/build/bidi_main/bidi_main.js
fn main {
  // Skip glyph warmup for now — pre-rasterize on first paint instead
  // @webdriver.warmup_glyph_cache()
  let config : @webdriver.BidiServerConfig = {
    host: "127.0.0.1",
    port: 9222,
    auth_token: @webdriver.generate_auth_token(),
  }
  let server = @webdriver.BidiServer::new(config~)
  let ws_url = if config.auth_token.is_empty() {
    "ws://\{config.host}:\{config.port}"
  } else {
    "ws://\{config.host}:\{config.port}/session/\{config.auth_token}"
  }
  println("Starting WebDriver BiDi server on \{ws_url}")
  server.start()
}
