///|
pub struct PipeRead {
  inner : @async_pipe.PipeRead
}

///|
pub struct PipeWrite {
  inner : @async_pipe.PipeWrite
}

///|
pub fn pipe() -> (PipeRead, PipeWrite) raise {
  let (r, w) = @async_pipe.pipe()
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
  self.inner.fd()
}

///|
pub fn PipeWrite::fd(self : PipeWrite) -> Int {
  self.inner.fd()
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
