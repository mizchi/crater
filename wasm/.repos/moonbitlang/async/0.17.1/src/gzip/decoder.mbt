// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
let decoder_buffer_size = 4096

///|
fn @io.ReaderBuffer::repr(buf : Self) -> @io_buffer.Buffer = "%identity"

///|
pub struct Decoder[R] {
  priv inner : R
  priv core : @gzip_internal.Decoder
  priv read_buf : @io.ReaderBuffer

  fn[R : @io.Reader] new(inner : R) -> Decoder[R]
}

///|
pub fn[R : @io.Reader] Decoder::new(inner : R) -> Decoder[R] {
  let decoder = {
    inner,
    core: @gzip_internal.Decoder::new(),
    read_buf: @io.ReaderBuffer::new(),
  }
  decoder.inner._get_internal_buffer().repr().enlarge_to(decoder_buffer_size)
  decoder
}

///|
async fn[R : @io.Reader] Decoder::read_more_input(self : Decoder[R]) -> Unit {
  let input = self.inner._get_internal_buffer().repr()
  let need = @cmp.maximum(self.core.minimum_input_size(), 1)
  input.enlarge_to(input.len + @cmp.maximum(need, decoder_buffer_size))
  let end = input.start + input.len
  let max_len = input.buf.length() - end
  let n = self.inner._direct_read(input.buf, offset=end, max_len~)
  guard n > 0 else { raise @io.ReaderClosed }
  input.len += n
}

///|
pub impl[R : @io.Reader] @io.Reader for Decoder[R] with _get_internal_buffer(
  self,
) {
  self.read_buf
}

///|
pub impl[R : @io.Reader] @io.Reader for Decoder[R] with _direct_read(
  self,
  dst,
  offset~,
  max_len~,
) {
  let input = self.inner._get_internal_buffer().repr()
  while !self.core.is_finished() {
    while input.len < self.core.minimum_input_size() {
      self.read_more_input()
    }
    let (consumed, produced) = self.core.write(
      input.buf.unsafe_reinterpret_as_bytes(),
      dst,
      input_offset=input.start,
      input_len=input.len,
      output_offset=offset,
      output_len=max_len,
    )
    input.drop(consumed)
    if produced > 0 {
      return produced
    }
  } nobreak {
    0
  }
}
