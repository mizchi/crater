///|
pub struct Input {
  buf : @io.ReaderBuffer
}

///|
pub struct Output {
  target : Int // 1 = stdout, 2 = stderr
}

///|
pub fn Input::fd(self : Input) -> Int {
  ignore(self)
  0
}

///|
pub fn Output::fd(self : Output) -> Int {
  self.target
}

///|
extern "js" fn js_stdin_read(max_len : Int) -> @js_async.Promise[Bytes] =
  #| async (maxLen) => {
  #|   const { stdin } = process;
  #|   return new Promise((resolve) => {
  #|     if (stdin.readableEnded || stdin.destroyed) {
  #|       resolve(new Uint8Array(0));
  #|       return;
  #|     }
  #|     const tryRead = () => {
  #|       const chunk = stdin.read(Math.min(maxLen, stdin.readableLength || maxLen));
  #|       if (chunk !== null) {
  #|         resolve(new Uint8Array(chunk));
  #|         return true;
  #|       }
  #|       return false;
  #|     };
  #|     if (tryRead()) return;
  #|     const onReadable = () => {
  #|       if (tryRead()) {
  #|         stdin.removeListener('readable', onReadable);
  #|         stdin.removeListener('end', onEnd);
  #|       }
  #|     };
  #|     const onEnd = () => {
  #|       stdin.removeListener('readable', onReadable);
  #|       resolve(new Uint8Array(0));
  #|     };
  #|     stdin.on('readable', onReadable);
  #|     stdin.once('end', onEnd);
  #|   });
  #| }

///|
extern "js" fn js_write(
  target : Int,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Unit =
  #| (target, data, offset, len) => {
  #|   const slice = data.subarray(offset, offset + len);
  #|   (target === 1 ? process.stdout : process.stderr).write(slice);
  #| }

///|
pub impl @io.Reader for Input with _get_internal_buffer(self) {
  self.buf
}

///|
pub impl @io.Reader for Input with _direct_read(self, buf, offset~, max_len~) {
  ignore(self)
  let controller = @js_async.AbortController::new()
  let promise = js_stdin_read(max_len)
  let data = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    _ => return 0
  }
  let len = data.length()
  if len == 0 {
    return 0
  }
  let actual = if len < max_len { len } else { max_len }
  for i = 0; i < actual; i = i + 1 {
    buf[offset + i] = data[i]
  }
  actual
}

///|
pub impl @io.Writer for Output with write_once(self, buf, offset~, len~) {
  js_write(self.target, buf, offset, len)
  len
}

///|
pub let stdin : Input = Input::{ buf: @io.ReaderBuffer::new() }

///|
pub let stdout : Output = Output::{ target: 1 }

///|
pub let stderr : Output = Output::{ target: 2 }
