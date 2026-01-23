///|
/// WebDriver BiDi Server Entry Point
///
/// Run with: deno run -A target/js/release/build/bidi_main/bidi_main.js
fn main {
  let config : @webdriver.BidiServerConfig = { host: "127.0.0.1", port: 9222 }
  let server = @webdriver.BidiServer::new(config~)
  println(
    "Starting WebDriver BiDi server on ws://\{config.host}:\{config.port}",
  )
  server.start()
}
