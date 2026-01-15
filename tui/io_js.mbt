///|
/// I/O implementation for JavaScript/Node.js target

///|
/// Read a single key from stdin (raw mode)
extern "js" fn js_read_key() -> @js_async.Promise[String] =
  #| async () => {
  #|   if (typeof process === 'undefined') return 'q';
  #|   const { emitKeypressEvents } = await import('node:readline');
  #|
  #|   // Setup keypress events if not already done
  #|   if (!process.stdin.__keypressSetup) {
  #|     emitKeypressEvents(process.stdin);
  #|     process.stdin.__keypressSetup = true;
  #|   }
  #|
  #|   if (process.stdin.isTTY) {
  #|     process.stdin.setRawMode(true);
  #|   }
  #|   process.stdin.resume();
  #|
  #|   return new Promise((resolve) => {
  #|     const onKeypress = (str, key) => {
  #|       process.stdin.removeListener('keypress', onKeypress);
  #|       // Return the string, or construct from key info
  #|       if (str) {
  #|         resolve(str);
  #|       } else if (key && key.sequence) {
  #|         resolve(key.sequence);
  #|       } else {
  #|         resolve('');
  #|       }
  #|     };
  #|     process.stdin.on('keypress', onKeypress);
  #|   });
  #| }

///|
/// Print to stdout without newline
extern "js" fn js_print_raw(s : String) =
  #| (s) => process.stdout.write(s)

///|
/// Cleanup stdin (turn off raw mode)
extern "js" fn js_cleanup_stdin() =
  #| () => {
  #|   if (typeof process !== 'undefined' && process.stdin.isTTY) {
  #|     process.stdin.setRawMode(false);
  #|     process.stdin.pause();
  #|   }
  #| }

///|
/// Enable raw mode
extern "js" fn js_enable_raw_mode() =
  #| () => {
  #|   if (typeof process !== 'undefined' && process.stdin.isTTY) {
  #|     process.stdin.setRawMode(true);
  #|     process.stdin.resume();
  #|   }
  #| }

///|
/// Get terminal columns
extern "js" fn js_get_terminal_columns() -> Int =
  #| () => {
  #|   if (typeof process === 'undefined') return 80;
  #|   return process.stdout.columns || 80;
  #| }

///|
/// Get terminal rows
extern "js" fn js_get_terminal_rows() -> Int =
  #| () => {
  #|   if (typeof process === 'undefined') return 24;
  #|   return process.stdout.rows || 24;
  #| }

///|
/// Sleep for milliseconds
extern "js" fn js_sleep(ms : Int) -> @js_async.Promise[Unit] =
  #| (ms) => new Promise(r => setTimeout(r, ms))

///|
/// Keep the process alive without blocking (non-blocking)
/// This schedules a timeout but doesn't wait - keeps event loop active
extern "js" fn js_keep_alive_nonblocking(ms : Int) =
  #| (ms) => {
  #|   // Simple timer keeps the process alive
  #|   setTimeout(() => {}, ms);
  #| }

///|
/// Keep process alive without blocking the event loop
pub fn keep_alive_nonblocking(ms : Int) -> Unit {
  js_keep_alive_nonblocking(ms)
}

///|
/// Start a keypress listener (event-driven, non-blocking)
/// Uses raw data events for reliability (emitKeypressEvents has issues after removal)
extern "js" fn js_start_keypress_listener(callback : (String) -> Unit) =
  #| async (callback) => {
  #|   const { stdin } = await import('node:process');
  #|
  #|   // Clean up any existing listeners
  #|   stdin.removeAllListeners('keypress');
  #|   stdin.removeAllListeners('data');
  #|
  #|   if (stdin.isTTY) {
  #|     stdin.setRawMode(true);
  #|   }
  #|   stdin.resume();
  #|   stdin.setEncoding('utf8');
  #|
  #|   const onData = (data) => {
  #|     // In raw mode, we get data character by character (or escape sequences)
  #|     callback(data);
  #|   };
  #|
  #|   // Store handler for later removal
  #|   stdin.__dataHandler = onData;
  #|   stdin.on('data', onData);
  #| }

///|
/// Stop the keypress listener
extern "js" fn js_stop_keypress_listener() =
  #| async () => {
  #|   const { stdin } = await import('node:process');
  #|   if (stdin.__dataHandler) {
  #|     stdin.removeListener('data', stdin.__dataHandler);
  #|     stdin.__dataHandler = null;
  #|   }
  #|   if (stdin.isTTY) {
  #|     stdin.setRawMode(false);
  #|   }
  #|   stdin.pause();
  #| }

///|
/// Start listening for keypresses (event-driven)
pub fn start_keypress_listener(callback : (String) -> Unit) -> Unit {
  js_start_keypress_listener(callback)
}

///|
/// Stop listening for keypresses
pub fn stop_keypress_listener() -> Unit {
  js_stop_keypress_listener()
}

///|
/// Start an inline input session (stays in current screen)
/// Uses raw mode for reliable input handling
/// Enter confirms, Escape cancels, Backspace deletes
extern "js" fn js_start_inline_input(
  label : String,
  initial : String,
  on_confirmed : (String) -> Unit,
  on_cancelled : () -> Unit,
) -> Unit =
  #| async (label, initial, onConfirmed, onCancelled) => {
  #|   const { stdin, stdout } = await import('node:process');
  #|
  #|   // Helper to get display width of a character (1 for half-width, 2 for full-width)
  #|   const getCharWidth = (char) => {
  #|     const code = char.codePointAt(0);
  #|     // Full-width characters: CJK, Hiragana, Katakana, full-width forms, etc.
  #|     if (code >= 0x1100 && (
  #|       code <= 0x115F || // Hangul Jamo
  #|       code === 0x2329 || code === 0x232A ||
  #|       (code >= 0x2E80 && code <= 0x303E) || // CJK Radicals, Kangxi, etc.
  #|       (code >= 0x3040 && code <= 0x33FF) || // Hiragana, Katakana, CJK Compatibility
  #|       (code >= 0x3400 && code <= 0x4DBF) || // CJK Extension A
  #|       (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified Ideographs
  #|       (code >= 0xAC00 && code <= 0xD7A3) || // Hangul Syllables
  #|       (code >= 0xF900 && code <= 0xFAFF) || // CJK Compatibility Ideographs
  #|       (code >= 0xFE10 && code <= 0xFE1F) || // Vertical Forms
  #|       (code >= 0xFE30 && code <= 0xFE6F) || // CJK Compatibility Forms
  #|       (code >= 0xFF00 && code <= 0xFF60) || // Full-width ASCII
  #|       (code >= 0xFFE0 && code <= 0xFFE6) || // Full-width symbols
  #|       (code >= 0x20000 && code <= 0x2FFFF) // CJK Extension B-F
  #|     )) {
  #|       return 2;
  #|     }
  #|     return 1;
  #|   };
  #|
  #|   // Clear all listeners for clean state
  #|   stdin.removeAllListeners('keypress');
  #|   stdin.removeAllListeners('data');
  #|   stdin.__dataHandler = null;
  #|
  #|   // Use raw mode for character-by-character input
  #|   if (stdin.isTTY) {
  #|     stdin.setRawMode(true);
  #|   }
  #|   stdin.resume();
  #|   stdin.setEncoding('utf8');
  #|
  #|   // Display initial value
  #|   let buffer = initial || '';
  #|   stdout.write(buffer);
  #|
  #|   let done = false;
  #|
  #|   const cleanup = () => {
  #|     if (done) return;
  #|     done = true;
  #|     stdin.removeListener('data', onData);
  #|   };
  #|
  #|   const onData = (chunk) => {
  #|     if (done) return;
  #|
  #|     for (const char of chunk) {
  #|       const code = char.charCodeAt(0);
  #|
  #|       if (code === 27) {
  #|         // Escape - cancel
  #|         cleanup();
  #|         onCancelled();
  #|         return;
  #|       } else if (code === 13) {
  #|         // Enter - confirm
  #|         cleanup();
  #|         onConfirmed(buffer);
  #|         return;
  #|       } else if (code === 3) {
  #|         // Ctrl+C - cancel
  #|         cleanup();
  #|         onCancelled();
  #|         return;
  #|       } else if (code === 127 || code === 8) {
  #|         // Backspace - delete last character
  #|         if (buffer.length > 0) {
  #|           const chars = [...buffer];
  #|           const deleted = chars.pop();
  #|           buffer = chars.join('');
  #|           // Erase based on character width
  #|           const width = getCharWidth(deleted);
  #|           if (width === 2) {
  #|             stdout.write('\b\b  \b\b'); // Full-width: 2 columns
  #|           } else {
  #|             stdout.write('\b \b'); // Half-width: 1 column
  #|           }
  #|         }
  #|       } else if (code >= 32) {
  #|         // Printable character
  #|         buffer += char;
  #|         stdout.write(char);
  #|       }
  #|     }
  #|   };
  #|
  #|   stdin.on('data', onData);
  #| }

///|
/// Start an inline input session (for editing in place)
pub fn start_inline_input(
  label : String,
  initial : String,
  on_result : (InputResult) -> Unit,
) -> Unit {
  js_start_inline_input(
    label,
    initial,
    fn(value) { on_result(InputResult::Confirmed(value)) },
    fn() { on_result(InputResult::Cancelled) },
  )
}

///|
/// Read a key asynchronously
pub async fn read_key() -> String {
  @js_async.Promise::wait(js_read_key())
}

///|
/// Print string to stdout (no newline)
pub fn print_raw(s : String) -> Unit {
  js_print_raw(s)
}

///|
/// Cleanup stdin state
pub fn cleanup_stdin() -> Unit {
  js_cleanup_stdin()
}

///|
/// Enable raw mode
pub fn enable_raw_mode() -> Unit {
  js_enable_raw_mode()
}

///|
/// Get terminal size (columns, rows)
pub fn get_terminal_size() -> (Int, Int) {
  (js_get_terminal_columns(), js_get_terminal_rows())
}

///|
/// Sleep for milliseconds
pub async fn sleep(ms : Int) -> Unit {
  @js_async.Promise::wait(js_sleep(ms))
}

// --- Input Session for IME support ---

///|
/// Result of an input session
pub(all) enum InputResult {
  Confirmed(String)
  Cancelled
}

///|
/// Start an input session with callback (non-blocking)
extern "js" fn js_start_input_session_callback(
  initial : String,
  on_confirmed : (String) -> Unit,
  on_cancelled : () -> Unit,
) -> Unit =
  #| async (initial, onConfirmed, onCancelled) => {
  #|   const rl = await import('node:readline/promises');
  #|   const { stdin, stdout } = await import('node:process');
  #|
  #|   // Show cursor
  #|   stdout.write('\x1b[?25h');
  #|
  #|   // Reset stdin state for readline
  #|   stdin.removeAllListeners('keypress');
  #|   if (stdin.isTTY) {
  #|     stdin.setRawMode(false);
  #|   }
  #|
  #|   const readline = rl.createInterface({
  #|     input: stdin,
  #|     output: stdout,
  #|   });
  #|
  #|   try {
  #|     // Pre-fill and get answer
  #|     const answer = await readline.question('> ' + initial);
  #|     readline.close();
  #|     onConfirmed(answer);
  #|   } catch (err) {
  #|     readline.close();
  #|     onCancelled();
  #|   }
  #| }

///|
/// Legacy Promise-based version (kept for reference, may not work properly)
extern "js" fn js_start_input_session(
  x : Int,
  y : Int,
  initial : String,
) -> @js_async.Promise[String] =
  #| async (x, y, initial) => {
  #|   return new Promise((resolve) => {
  #|     // This version may block the event loop - use callback version instead
  #|     resolve('cancelled:');
  #|   });
  #| }

///|
/// Abort the current input session
extern "js" fn js_abort_input_session() =
  #| () => {
  #|   if (globalThis.__inputSession && globalThis.__inputSession.active) {
  #|     globalThis.__inputSession.active = false;
  #|     if (globalThis.__inputSession.rl) {
  #|       globalThis.__inputSession.rl.close();
  #|     }
  #|     if (globalThis.__inputSession.resolve) {
  #|       globalThis.__inputSession.resolve('cancelled:');
  #|     }
  #|   }
  #| }

///|
/// Start a render ticker (setInterval)
extern "js" fn js_start_render_ticker(ms : Int, callback : () -> Unit) -> Int =
  #| (ms, cb) => setInterval(cb, ms)

///|
/// Stop a render ticker
extern "js" fn js_stop_render_ticker(ticker_id : Int) =
  #| (id) => clearInterval(id)

///|
/// Start an input session (callback-based, non-blocking)
/// This is the recommended way to read input - it doesn't block the event loop
pub fn start_input_session_cb(
  initial : String,
  on_result : (InputResult) -> Unit,
) -> Unit {
  js_start_input_session_callback(
    initial,
    fn(value) { on_result(InputResult::Confirmed(value)) },
    fn() { on_result(InputResult::Cancelled) },
  )
}

///|
/// Start an input session that returns a Promise (for async/await)
/// This wraps the callback-based API in a Promise created on the JS side
extern "js" fn js_start_input_session_promise(
  initial : String,
) -> @js_async.Promise[InputResult] =
  #| async (initial) => {
  #|   const rl = await import('node:readline/promises');
  #|   const { stdin, stdout } = await import('node:process');
  #|
  #|   // Show cursor
  #|   stdout.write('\x1b[?25h');
  #|
  #|   // Reset stdin state for readline
  #|   stdin.removeAllListeners('keypress');
  #|   if (stdin.isTTY) {
  #|     stdin.setRawMode(false);
  #|   }
  #|
  #|   const readline = rl.createInterface({
  #|     input: stdin,
  #|     output: stdout,
  #|   });
  #|
  #|   try {
  #|     const answer = await readline.question('> ' + initial);
  #|     readline.close();
  #|     return { $tag: "Confirmed", _0: answer };
  #|   } catch (err) {
  #|     readline.close();
  #|     return { $tag: "Cancelled" };
  #|   }
  #| }

///|
/// Start an input session that returns a Promise (for async/await)
/// Use with @js_async.Promise::wait() in async functions
pub fn start_input_session_promise(
  initial : String,
) -> @js_async.Promise[InputResult] {
  js_start_input_session_promise(initial)
}

///|
/// Start an input session (async version - may not work with raw mode)
/// WARNING: This uses Promise::wait which can block the Node.js event loop
/// Use start_input_session_cb instead for reliable operation
pub async fn start_input_session(
  x : Int,
  y : Int,
  initial : String,
) -> InputResult {
  // This version doesn't work properly after raw mode - returns cancelled immediately
  let result = @js_async.Promise::wait(js_start_input_session(x, y, initial))
  if result.has_prefix("confirmed:") {
    InputResult::Confirmed(result[10:].to_string())
  } else {
    InputResult::Cancelled
  }
}

///|
/// Abort the current input session
pub fn abort_input_session() -> Unit {
  js_abort_input_session()
}

///|
/// Start a render ticker that calls the callback every `ms` milliseconds
pub fn start_render_ticker(ms : Int, callback : () -> Unit) -> Int {
  js_start_render_ticker(ms, callback)
}

///|
/// Stop a render ticker
pub fn stop_render_ticker(ticker_id : Int) -> Unit {
  js_stop_render_ticker(ticker_id)
}
