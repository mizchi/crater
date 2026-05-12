///|
/// JavaScript/Node.js terminal input implementation.

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
  #|             finish('MouseDown:' + col + ',' + row);
  #|             return;
  #|           }
  #|           if (btn === 0 && !pressed) {
  #|             finish('MouseUp:' + col + ',' + row);
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
/// Wait for Enter key without raw mode
pub async fn wait_for_enter() -> Unit {
  @js_async.Promise::wait(js_wait_for_enter())
}
