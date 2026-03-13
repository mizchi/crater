///|
/// TUI implementation for JavaScript/Node.js target

///|
/// Read a single key from stdin (keeps raw mode on for smooth rendering)
/// Also handles mouse events when mouse tracking is enabled
extern "js" fn js_read_key_with_timeout(
  timeout_ms : Int,
) -> @js_async.Promise[String] =
  #| async (timeout_ms) => {
  #|   const timeoutMs = timeout_ms;
  #|   if (typeof process === 'undefined') return '';
  #|   if (!process.stdin.isTTY) {
  #|     const waitMs = timeoutMs >= 0 ? timeoutMs : 100;
  #|     await new Promise(r => setTimeout(r, waitMs));
  #|     return '';
  #|   }
  #|   return new Promise((resolve) => {
  #|     process.stdin.setRawMode(true);
  #|     process.stdin.resume();
  #|     process.stdin.setEncoding('utf8');
  #|     let settled = false;
  #|     let timer = null;
  #|     const cleanup = () => {
  #|       process.stdin.removeListener('data', onData);
  #|       if (timer !== null) clearTimeout(timer);
  #|     };
  #|     const finish = (value) => {
  #|       if (settled) return;
  #|       settled = true;
  #|       cleanup();
  #|       resolve(value);
  #|     };
  #|     const onData = (key) => {
  #|       if (key === '\u0003') { finish('q'); return; } // Ctrl+C
  #|       if (key === '\u0004') { finish('Ctrl-D'); return; } // Ctrl+D
  #|       if (key === '\u001b[A') { finish('ArrowUp'); return; }
  #|       if (key === '\u001b[B') { finish('ArrowDown'); return; }
  #|       if (key === '\u001b[5~') { finish('PageUp'); return; }
  #|       if (key === '\u001b[6~') { finish('PageDown'); return; }
  #|       if (key === '\u001b[3~') { finish('Delete'); return; }
  #|       if (key === '\u007f' || key === '\u0008') { finish('Backspace'); return; }
  #|       if (key === '\r' || key === '\n') { finish('Enter'); return; }
  #|       if (key === '\t') { finish('Tab'); return; }
  #|       if (key === '\u001b[Z') { finish('Shift-Tab'); return; }
  #|       if (key === '\u001b') { finish('Escape'); return; }
  #|       if (key === '\u0015') { finish('Ctrl-U'); return; } // Ctrl+U
  #|       // Mouse events: SGR mode \e[<btn;col;row;M (press) or m (release)
  #|       if (key.startsWith('\u001b[<')) {
  #|         const match = key.match(/\u001b\[<(\d+);(\d+);(\d+)([Mm])/);
  #|         if (match) {
  #|           const btn = parseInt(match[1]);
  #|           const col = parseInt(match[2]);
  #|           const row = parseInt(match[3]);
  #|           const pressed = match[4] === 'M';
  #|           if (btn === 0 && pressed) {
  #|             finish('Mouse:' + col + ',' + row);
  #|             return;
  #|           }
  #|           if (btn === 64) {
  #|             finish('MouseScrollUp:' + col + ',' + row);
  #|             return;
  #|           }
  #|           if (btn === 65) {
  #|             finish('MouseScrollDown:' + col + ',' + row);
  #|             return;
  #|           }
  #|           if (pressed && btn >= 32) {
  #|             finish('MouseMove:' + col + ',' + row);
  #|             return;
  #|           }
  #|         }
  #|       }
  #|       finish(key);
  #|     };
  #|     if (timeoutMs >= 0) {
  #|       timer = setTimeout(() => finish(''), timeoutMs);
  #|     }
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
  @js_async.Promise::wait(js_read_key_with_timeout(-1))
}

///|
/// Read a key asynchronously, returning empty string on timeout
pub async fn read_key_with_timeout(timeout_ms : Int) -> String {
  @js_async.Promise::wait(js_read_key_with_timeout(timeout_ms))
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
  #|   if (process.stdout.columns) return process.stdout.columns;
  #|   if (process.stderr.columns) return process.stderr.columns;
  #|   if (process.env && process.env.COLUMNS) {
  #|     const c = parseInt(process.env.COLUMNS, 10);
  #|     if (c > 0) return c;
  #|   }
  #|   try {
  #|     const { execSync } = require('child_process');
  #|     const cols = parseInt(execSync('tput cols', { stdio: ['pipe', 'pipe', 'pipe'], encoding: 'utf8' }).trim(), 10);
  #|     if (cols > 0) return cols;
  #|   } catch {}
  #|   return 80;
  #| }

///|
/// Get terminal rows from process.stdout
extern "js" fn js_get_terminal_rows() -> Int =
  #| () => {
  #|   if (typeof process === 'undefined') return 24;
  #|   if (process.stdout.rows) return process.stdout.rows;
  #|   if (process.stderr.rows) return process.stderr.rows;
  #|   if (process.env && process.env.LINES) {
  #|     const r = parseInt(process.env.LINES, 10);
  #|     if (r > 0) return r;
  #|   }
  #|   try {
  #|     const { execSync } = require('child_process');
  #|     const rows = parseInt(execSync('tput lines', { stdio: ['pipe', 'pipe', 'pipe'], encoding: 'utf8' }).trim(), 10);
  #|     if (rows > 0) return rows;
  #|   } catch {}
  #|   return 24;
  #| }

///|
/// Get terminal size in characters (columns, rows)
/// Returns (80, 24) as default if size cannot be determined
pub fn get_terminal_size() -> (Int, Int) {
  (js_get_terminal_columns(), js_get_terminal_rows())
}
