///|
pub struct PipeRead {}

///|
pub struct PipeWrite {}

///|
pub fn pipe() -> (PipeRead, PipeWrite) raise {
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeRead::close(self : PipeRead) -> Unit {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeWrite::close(self : PipeWrite) -> Unit {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeRead::fd(self : PipeRead) -> Int {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub fn PipeWrite::fd(self : PipeWrite) -> Int {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub impl @io.Reader for PipeRead with _get_internal_buffer(self) {
  ignore(self)
  abort("pipe not supported on wasm-gc target")
}

///|
pub impl @io.Reader for PipeRead with _direct_read(self, buf, offset~, max_len~) {
  ignore((self, buf, offset, max_len))
  abort("pipe not supported on wasm-gc target")
}

///|
pub impl @io.Writer for PipeWrite with write_once(self, buf, offset~, len~) {
  ignore((self, buf, offset, len))
  abort("pipe not supported on wasm-gc target")
}
