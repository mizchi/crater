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
let encoder_buffer_size = 4096

///|
pub struct Encoder[W] {
  priv inner : W
  priv buf : FixedArray[Byte]
  priv mut buf_len : Int
  priv core : @gzip_internal.Encoder

  fn[W] new(
    inner : W,
    mtime? : UInt,
    extra_flags? : Byte,
    operating_system? : Byte,
  ) -> Encoder[W]
}

///|
pub fn[W] Encoder::new(
  inner : W,
  mtime? : UInt = 0U,
  extra_flags? : Byte = b'\x00',
  operating_system? : Byte = b'\xff',
) -> Encoder[W] {
  let buf = FixedArray::make(encoder_buffer_size, b'\x00')
  {
    inner,
    buf,
    buf_len: 0,
    core: @gzip_internal.Encoder::new(mtime~, extra_flags~, operating_system~),
  }
}

///|
async fn[W : @io.Writer] Encoder::flush_output(self : Encoder[W]) -> Unit {
  if self.buf_len > 0 {
    self.inner.write(self.buf.unsafe_reinterpret_as_bytes()[:self.buf_len])
    self.buf_len = 0
  }
}

///|
pub async fn[W : @io.Writer] Encoder::flush(self : Encoder[W]) -> Unit {
  self.flush_output()
}

///|
pub async fn[W : @io.Writer] Encoder::end(self : Encoder[W]) -> Unit {
  if self.core.minimum_output_space(end=true) > self.buf.length() - self.buf_len {
    self.flush_output()
  }
  self.buf_len += self.core.end(
    self.buf,
    output_offset=self.buf_len,
    output_len=self.buf.length() - self.buf_len,
  )
  self.flush_output()
}

///|
pub impl[W : @io.Writer] @io.Writer for Encoder[W] with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  if self.core.minimum_output_space(end=false) >
    self.buf.length() - self.buf_len {
    self.flush_output()
  }
  let (written, produced) = self.core.write(
    buf,
    self.buf,
    input_offset=offset,
    input_len=len,
    output_offset=self.buf_len,
    output_len=self.buf.length() - self.buf_len,
  )
  self.buf_len += produced
  written
}
