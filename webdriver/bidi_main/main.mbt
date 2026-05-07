///|
/// WebDriver BiDi Server Entry Point
///
/// Run with: deno run -A ../../webdriver/_build/js/release/build/bidi_main/bidi_main.js

///|
extern "js" fn js_env_string_or_default(
  name : String,
  fallback : String,
) -> String =
  #| (name, fallback) => {
  #|   try {
  #|     const value = typeof Deno !== "undefined" ? Deno.env.get(name) : undefined;
  #|     return value && String(value).length > 0 ? String(value) : fallback;
  #|   } catch (_e) {
  #|     return fallback;
  #|   }
  #| }

///|
extern "js" fn js_env_port_or_default(name : String, fallback : Int) -> Int =
  #| (name, fallback) => {
  #|   try {
  #|     const value = typeof Deno !== "undefined" ? Deno.env.get(name) : undefined;
  #|     const port = Number(value);
  #|     return Number.isInteger(port) && port > 0 && port <= 65535 ? port : fallback;
  #|   } catch (_e) {
  #|     return fallback;
  #|   }
  #| }

///|
fn main {
  // Skip glyph warmup for now — pre-rasterize on first paint instead
  // @webdriver.warmup_glyph_cache()
  let config : @webdriver.BidiServerConfig = {
    host: js_env_string_or_default("CRATER_BIDI_HOST", "127.0.0.1"),
    port: js_env_port_or_default("CRATER_BIDI_PORT", 9222),
    auth_token: @webdriver.generate_auth_token(),
  }
  let server = @webdriver.BidiServer::new(config~)
  let ws_url = config.web_socket_url()
  println("Starting WebDriver BiDi server on \{ws_url}")
  server.start()
}
