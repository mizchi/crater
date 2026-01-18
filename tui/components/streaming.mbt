///|
/// StreamingText - Component for streaming text display with typing animation

///|
/// Streaming state for managing streaming text display
pub(all) struct StreamingState {
  /// Full text to be streamed
  full_text : @signals.Signal[String]
  /// Current display position (0 to full_text.length)
  position : @signals.Signal[Int]
  /// Ticker ID for animation (0 = not running)
  ticker_id : Ref[Int]
}

///|
/// Create a new streaming state
pub fn StreamingState::new() -> StreamingState {
  {
    full_text: @signals.signal(""),
    position: @signals.signal(0),
    ticker_id: { val: 0 },
  }
}

///|
/// Check if streaming is in progress
pub fn StreamingState::is_streaming(self : StreamingState) -> Bool {
  let full = self.full_text.get()
  let pos = self.position.get()
  full.length() > 0 && pos < full.length()
}

///|
/// Check if streaming has content (either in progress or completed but not cleared)
pub fn StreamingState::has_content(self : StreamingState) -> Bool {
  self.position.get() > 0
}

///|
/// Get the partial text (up to current position)
pub fn StreamingState::get_partial(self : StreamingState) -> String {
  let full = self.full_text.get()
  let pos = self.position.get()
  get_substring(full, 0, pos)
}

///|
/// Get the partial text with cursor
pub fn StreamingState::get_partial_with_cursor(
  self : StreamingState,
  cursor? : String = "▌"
) -> String {
  self.get_partial() + cursor
}

///|
/// Get progress as (current, total)
pub fn StreamingState::get_progress(self : StreamingState) -> (Int, Int) {
  (self.position.get(), self.full_text.get().length())
}

///|
/// Get progress as percentage (0.0 to 1.0)
pub fn StreamingState::get_progress_ratio(self : StreamingState) -> Double {
  let total = self.full_text.get().length()
  if total == 0 {
    0.0
  } else {
    self.position.get().to_double() / total.to_double()
  }
}

///|
/// Start streaming text with given interval
/// Returns true if streaming started, false if already streaming
/// on_tick is called after each character advance
/// on_complete is called when streaming finishes
pub fn StreamingState::start(
  self : StreamingState,
  text : String,
  interval_ms : Int,
  on_tick : () -> Unit,
  on_complete : () -> Unit
) -> Bool {
  // Don't start if already streaming
  if self.ticker_id.val != 0 {
    return false
  }
  self.full_text.set(text)
  self.position.set(0)
  // Create tick function that advances position
  fn tick() {
    let full = self.full_text.get()
    let pos = self.position.get()
    if pos < full.length() {
      self.position.set(pos + 1)
      on_tick()
    } else {
      // Done streaming
      self.stop()
      on_complete()
    }
  }

  let ticker_id = @tui.start_render_ticker(interval_ms, tick)
  self.ticker_id.val = ticker_id
  // If ticker_id is 0, native mode doesn't support tickers
  // Complete immediately in this case
  if ticker_id == 0 {
    self.position.set(text.length())
    on_complete()
  }
  true
}

///|
/// Stop streaming and clear the ticker
pub fn StreamingState::stop(self : StreamingState) -> Unit {
  if self.ticker_id.val != 0 {
    @tui.stop_render_ticker(self.ticker_id.val)
    self.ticker_id.val = 0
  }
}

///|
/// Clear streaming state (stop and reset)
pub fn StreamingState::clear(self : StreamingState) -> Unit {
  self.stop()
  self.full_text.set("")
  self.position.set(0)
}

///|
/// Get the full text and clear the state
/// Useful for adding completed text to a message list
pub fn StreamingState::take(self : StreamingState) -> String {
  let text = self.full_text.get()
  self.clear()
  text
}

///|
/// Complete streaming immediately (show all text)
pub fn StreamingState::complete(self : StreamingState) -> Unit {
  self.stop()
  let full = self.full_text.get()
  self.position.set(full.length())
}

// Helper function to get substring by iterating characters
fn get_substring(s : String, start : Int, end : Int) -> String {
  let sb = StringBuilder::new()
  let mut idx = 0
  for c in s {
    if idx >= start && idx < end {
      sb.write_char(c)
    }
    idx = idx + 1
  }
  sb.to_string()
}

///|
/// Split string by newlines (useful for multi-line streaming content)
pub fn split_lines(text : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = StringBuilder::new()
  for c in text {
    if c == '\n' {
      result.push(current.to_string())
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  result.push(current.to_string())
  result
}

///|
/// Count lines in text
pub fn count_lines(text : String) -> Int {
  if text.length() == 0 {
    return 1
  }
  let mut lines = 1
  for c in text {
    if c == '\n' {
      lines = lines + 1
    }
  }
  lines
}
