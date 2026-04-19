///|
pub struct PipeRead {
  inner : @io.PipeRead
}

///|
pub struct PipeWrite {
  inner : @io.PipeWrite
}

///|
pub fn pipe() -> (PipeRead, PipeWrite) raise {
  let (r, w) = @io.pipe()
  (PipeRead::{ inner: r }, PipeWrite::{ inner: w })
}

///|
pub fn PipeRead::close(self : PipeRead) -> Unit {
  self.inner.close()
}

///|
pub fn PipeWrite::close(self : PipeWrite) -> Unit {
  self.inner.close()
}

///|
pub fn PipeRead::fd(self : PipeRead) -> Int {
  ignore(self)
  -1
}

///|
pub fn PipeWrite::fd(self : PipeWrite) -> Int {
  ignore(self)
  -1
}

///|
pub impl @io.Reader for PipeRead with _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @io.Reader for PipeRead with _direct_read(self, buf, offset~, max_len~) {
  @io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub impl @io.Writer for PipeWrite with write_once(self, buf, offset~, len~) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}
