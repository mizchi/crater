///|
/// Test: Raw mode key read then readline (callback-based)

///|
async fn main {
  println("=== MoonBit Raw Mode → Readline Test (Callback) ===")
  println("isTTY: (assuming true)")
  println("")
  println("Press any key to continue (raw mode)...")

  // Read one key in raw mode (simulating TUI event loop)
  @tui.enable_raw_mode()
  let key = @tui.read_key()
  println("Got key: \"" + key + "\"")

  // Check for Ctrl+C
  if key.length() > 0 && key[0] == 3 {
    println("Ctrl+C pressed, exiting")
    return
  }
  println("")
  println("Now trying readline after raw mode...")
  println("Type something and press Enter:")
  println("[DEBUG] About to call start_input_session_cb...")

  // Use callback-based API (non-blocking)
  @tui.start_input_session_cb("", fn(result) {
    println("")
    match result {
      @tui.InputResult::Confirmed(value) =>
        println("You entered: \"" + value + "\"")
      @tui.InputResult::Cancelled => println("Input was cancelled")
    }
    println("")
    println("Test complete!")
    @tui.cleanup_stdin()
  })
  println("[DEBUG] start_input_session_cb returned, waiting for input...")

  // Keep the process alive without blocking the event loop
  @tui.keep_alive_nonblocking(60000)
}
