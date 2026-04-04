///|
/// WebDriver BiDi Server Entry Point
///
/// Run with: deno run -A ../../jsbidi/_build/js/release/build/bidi_main/bidi_main.js
fn main {
  // Skip glyph warmup for now — pre-rasterize on first paint instead
  // @webdriver.warmup_glyph_cache()
  let config : @webdriver.BidiServerConfig = { host: "127.0.0.1", port: 9222 }
  let server = @webdriver.BidiServer::new(config~)
  println(
    "Starting WebDriver BiDi server on ws://\{config.host}:\{config.port}",
  )
  server.start()
}
