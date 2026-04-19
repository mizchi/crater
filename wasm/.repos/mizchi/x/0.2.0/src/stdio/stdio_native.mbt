///|
pub struct Input {
  inner : @async_stdio.Input
}

///|
pub struct Output {
  inner : @async_stdio.Output
}

///|
pub fn Input::fd(self : Input) -> Int {
  self.inner.fd()
}

///|
pub fn Output::fd(self : Output) -> Int {
  self.inner.fd()
}

///|
pub impl @io.Reader for Input with _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @io.Reader for Input with _direct_read(self, buf, offset~, max_len~) {
  @io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub impl @io.Writer for Output with write_once(self, buf, offset~, len~) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}

///|
pub let stdin : Input = Input::{ inner: @async_stdio.stdin }

///|
pub let stdout : Output = Output::{ inner: @async_stdio.stdout }

///|
pub let stderr : Output = Output::{ inner: @async_stdio.stderr }
