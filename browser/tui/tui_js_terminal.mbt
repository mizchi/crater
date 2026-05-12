///|
/// JavaScript/Node.js terminal output and sizing implementation.

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
/// Enable raw mode (for resuming after text selection)
extern "js" fn js_enable_raw_mode() =
  #| () => {
  #|   if (typeof process !== 'undefined' && process.stdin.isTTY) {
  #|     process.stdin.setRawMode(true);
  #|     process.stdin.resume();
  #|   }
  #| }

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
/// Enable raw mode
pub fn enable_raw_mode() -> Unit {
  js_enable_raw_mode()
}

///|
/// Get terminal size in characters (columns, rows)
/// Returns (80, 24) as default if size cannot be determined
pub fn get_terminal_size() -> (Int, Int) {
  (js_get_terminal_columns(), js_get_terminal_rows())
}
