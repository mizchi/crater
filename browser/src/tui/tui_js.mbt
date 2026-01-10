///|
/// TUI implementation for JavaScript/Node.js target

///|
/// Read a single key from stdin (keeps raw mode on for smooth rendering)
/// Also handles mouse events when mouse tracking is enabled
extern "js" fn js_read_key() -> @js_async.Promise[String] =
  #| async () => {
  #|   if (typeof process === 'undefined') return 'q';
  #|   if (!process.stdin.isTTY) {
  #|     // Not a TTY, wait a bit and return empty to allow event loop
  #|     await new Promise(r => setTimeout(r, 100));
  #|     return '';
  #|   }
  #|   return new Promise((resolve) => {
  #|     // Set raw mode and keep it on (don't turn off after key read)
  #|     process.stdin.setRawMode(true);
  #|     process.stdin.resume();
  #|     process.stdin.setEncoding('utf8');
  #|     const onData = (key) => {
  #|       // Don't turn off raw mode - keep it on for smooth rendering
  #|       process.stdin.removeListener('data', onData);
  #|       if (key === '\u0003') { resolve('q'); return; } // Ctrl+C
  #|       if (key === '\u0004') { resolve('Ctrl-D'); return; } // Ctrl+D
  #|       if (key === '\u001b[A') { resolve('ArrowUp'); return; }
  #|       if (key === '\u001b[B') { resolve('ArrowDown'); return; }
  #|       if (key === '\u001b[5~') { resolve('PageUp'); return; }
  #|       if (key === '\u001b[6~') { resolve('PageDown'); return; }
  #|       if (key === '\u001b[3~') { resolve('Delete'); return; }
  #|       if (key === '\u007f' || key === '\u0008') { resolve('Backspace'); return; }
  #|       if (key === '\r' || key === '\n') { resolve('Enter'); return; }
  #|       if (key === '\t') { resolve('Tab'); return; }
  #|       if (key === '\u001b[Z') { resolve('Shift-Tab'); return; }
  #|       if (key === '\u001b') { resolve('Escape'); return; }
  #|       // Mouse click: SGR mode \e[<btn;col;row;M (press) or m (release)
  #|       if (key.startsWith('\u001b[<')) {
  #|         const match = key.match(/\u001b\[<(\d+);(\d+);(\d+)([Mm])/);
  #|         if (match) {
  #|           const btn = parseInt(match[1]);
  #|           const col = parseInt(match[2]);
  #|           const row = parseInt(match[3]);
  #|           const pressed = match[4] === 'M';
  #|           if (btn === 0 && pressed) {
  #|             // Left click - return as Mouse:col,row
  #|             resolve('Mouse:' + col + ',' + row);
  #|             return;
  #|           }
  #|         }
  #|       }
  #|       resolve(key);
  #|     };
  #|     process.stdin.on('data', onData);
  #|   });
  #| }

///|
/// Read a line from stdin (for URL input)
extern "js" fn js_read_line(prompt : String) -> @js_async.Promise[String] =
  #| async (prompt) => {
  #|   if (typeof process === 'undefined') return '';
  #|   if (!process.stdin.isTTY) return '';
  #|   const readline = require('readline');
  #|   // Ensure raw mode is off for line input
  #|   if (process.stdin.setRawMode) process.stdin.setRawMode(false);
  #|   const rl = readline.createInterface({
  #|     input: process.stdin,
  #|     output: process.stdout
  #|   });
  #|   return new Promise((resolve) => {
  #|     rl.question(prompt, (answer) => {
  #|       rl.close();
  #|       resolve(answer);
  #|     });
  #|   });
  #| }

///|
/// Print to stdout
extern "js" fn js_print(s : String) =
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
/// Get command line arguments (after --)
extern "js" fn js_get_args() -> Array[String] =
  #| () => {
  #|   if (typeof process === 'undefined') return [];
  #|   const args = process.argv.slice(2);
  #|   const dashIndex = args.indexOf('--');
  #|   if (dashIndex >= 0) {
  #|     return args.slice(dashIndex + 1);
  #|   }
  #|   return args;
  #| }

///|
/// Get command line arguments
pub fn get_args() -> Array[String] {
  js_get_args()
}

///|
/// Read a key asynchronously
pub async fn read_key() -> String {
  @js_async.Promise::wait(js_read_key())
}

///|
/// Read a line with prompt
pub async fn read_line(prompt : String) -> String {
  @js_async.Promise::wait(js_read_line(prompt))
}

///|
/// Print string to stdout (no newline)
pub fn print_raw(s : String) -> Unit {
  js_print(s)
}

///|
/// Cleanup stdin state (turn off raw mode, pause)
pub fn cleanup_stdin() -> Unit {
  js_cleanup_stdin()
}

///|
/// Enable raw mode (for resuming after text selection)
extern "js" fn js_enable_raw_mode() =
  #| () => {
  #|   if (typeof process !== 'undefined' && process.stdin.isTTY) {
  #|     process.stdin.setRawMode(true);
  #|     process.stdin.resume();
  #|   }
  #| }

///|
/// Enable raw mode
pub fn enable_raw_mode() -> Unit {
  js_enable_raw_mode()
}

///|
/// Wait for Enter key without enabling raw mode (for selection mode)
extern "js" fn js_wait_for_enter() -> @js_async.Promise[Unit] =
  #| async () => {
  #|   if (typeof process === 'undefined') return;
  #|   if (!process.stdin.isTTY) return;
  #|   const readline = require('readline');
  #|   const rl = readline.createInterface({
  #|     input: process.stdin,
  #|     output: process.stdout
  #|   });
  #|   return new Promise((resolve) => {
  #|     rl.question('', () => {
  #|       rl.close();
  #|       resolve();
  #|     });
  #|   });
  #| }

///|
/// Wait for Enter key without raw mode
pub async fn wait_for_enter() -> Unit {
  @js_async.Promise::wait(js_wait_for_enter())
}

///|
/// Get terminal columns from process.stdout
extern "js" fn js_get_terminal_columns() -> Int =
  #| () => {
  #|   if (typeof process === 'undefined') return 80;
  #|   return process.stdout.columns || 80;
  #| }

///|
/// Get terminal rows from process.stdout
extern "js" fn js_get_terminal_rows() -> Int =
  #| () => {
  #|   if (typeof process === 'undefined') return 24;
  #|   return process.stdout.rows || 24;
  #| }

///|
/// Get terminal size in characters (columns, rows)
/// Returns (80, 24) as default if size cannot be determined
pub fn get_terminal_size() -> (Int, Int) {
  (js_get_terminal_columns(), js_get_terminal_rows())
}
