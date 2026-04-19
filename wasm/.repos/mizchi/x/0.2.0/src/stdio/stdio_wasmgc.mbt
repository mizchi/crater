///|
pub struct Input {}

///|
pub struct Output {}

///|
pub fn Input::fd(self : Input) -> Int {
  ignore(self)
  abort("stdio not supported on wasm-gc target")
}

///|
pub fn Output::fd(self : Output) -> Int {
  ignore(self)
  abort("stdio not supported on wasm-gc target")
}

///|
pub impl @io.Reader for Input with _get_internal_buffer(self) {
  ignore(self)
  abort("stdio not supported on wasm-gc target")
}

///|
pub impl @io.Reader for Input with _direct_read(self, buf, offset~, max_len~) {
  ignore((self, buf, offset, max_len))
  abort("stdio not supported on wasm-gc target")
}

///|
pub impl @io.Writer for Output with write_once(self, buf, offset~, len~) {
  ignore((self, buf, offset, len))
  abort("stdio not supported on wasm-gc target")
}

///|
pub let stdin : Input = Input::{  }

///|
pub let stdout : Output = Output::{  }

///|
pub let stderr : Output = Output::{  }
