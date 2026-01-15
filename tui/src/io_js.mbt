///|
/// I/O implementation for JavaScript/Node.js target

///|
/// Read a single key from stdin (raw mode)
extern "js" fn js_read_key() -> @js_async.Promise[String] =
  #| async () => {
  #|   if (typeof process === 'undefined') return 'q';
  #|   if (!process.stdin.isTTY) {
  #|     await new Promise(r => setTimeout(r, 100));
  #|     return '';
  #|   }
  #|   return new Promise((resolve) => {
  #|     process.stdin.setRawMode(true);
  #|     process.stdin.resume();
  #|     process.stdin.setEncoding('utf8');
  #|     const onData = (key) => {
  #|       process.stdin.removeListener('data', onData);
  #|       resolve(key);
  #|     };
  #|     process.stdin.on('data', onData);
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
