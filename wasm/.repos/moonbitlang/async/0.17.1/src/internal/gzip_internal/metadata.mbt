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
priv suberror FormatError {
  InvalidHeader(String)
  InvalidTrailer(String)
  InvalidBlock(String)
} derive(Debug, ToJson)

///|
pub const HEADER_SIZE : Int = 10

///|
priv struct Header {
  mtime : UInt
  extra_flags : Byte
  operating_system : Byte
}

///|
fn Header::new(
  mtime? : UInt = 0U,
  extra_flags? : Byte = b'\x00',
  operating_system? : Byte = b'\xff',
) -> Header {
  { mtime, extra_flags, operating_system }
}

///|
fn Header::to_bytes(self : Header) -> Bytes {
  let buf = FixedArray::make(10, b'\x00')
  buf[0] = b'\x1f'
  buf[1] = b'\x8b'
  buf[2] = b'\x08'
  buf[3] = b'\x00'
  buf.unsafe_write_uint32_le(4, self.mtime)
  buf[8] = self.extra_flags
  buf[9] = self.operating_system
  buf.unsafe_reinterpret_as_bytes()
}

///|
fn Header::from_bytes(buf : BytesView) -> Header raise {
  guard buf
    is [
      '\x1f',
      '\x8b',
      compression_method,
      flags,
      u32le(mtime),
      extra_flags,
      operating_system,
    ] else {
    raise InvalidHeader("invalid gzip magic")
  }
  guard compression_method is '\x08' else {
    raise InvalidHeader("unsupported compression method")
  }
  guard flags is '\x00' else {
    raise InvalidHeader("gzip optional header fields are not supported")
  }
  { mtime, extra_flags, operating_system }
}

///|
priv struct Trailer {
  crc32 : UInt
  input_size : UInt
}

///|
fn Trailer::new(crc32 : UInt, input_size : UInt) -> Trailer {
  { crc32, input_size }
}

///|
fn Trailer::to_bytes(self : Trailer) -> Bytes {
  let buf = FixedArray::make(8, b'\x00')
  buf.unsafe_write_uint32_le(0, self.crc32)
  buf.unsafe_write_uint32_le(4, self.input_size)
  buf.unsafe_reinterpret_as_bytes()
}

///|
priv struct TrailerState {
  mut crc32 : UInt
  mut input_size : UInt
}

///|
fn TrailerState::new(
  crc32? : UInt = 0xffffffffU,
  input_size? : UInt = 0U,
) -> TrailerState {
  { crc32, input_size }
}

///|
fn TrailerState::update(self : TrailerState, chunk : BytesView) -> Unit {
  self.crc32 = crc32_update(self.crc32, chunk)
  self.input_size += chunk.length().reinterpret_as_uint()
}

///|
fn TrailerState::snapshot(self : TrailerState) -> Trailer {
  { crc32: self.crc32 ^ 0xffffffffU, input_size: self.input_size }
}
