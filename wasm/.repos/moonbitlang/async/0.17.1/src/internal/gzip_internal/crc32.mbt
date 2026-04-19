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
let crc32_table : FixedArray[UInt] = FixedArray::makei(256, i => {
  let mut crc = i.reinterpret_as_uint()
  for _ in 0..<8 {
    crc = if (crc & 1U) == 0U { crc >> 1 } else { (crc >> 1) ^ 0xedb88320U }
  }
  crc
})

///|
fn crc32_update(current : UInt, chunk : BytesView) -> UInt {
  for byte in chunk; crc = current {
    let index = ((crc ^ byte.to_uint()) & 0xffU).reinterpret_as_int()
    continue crc32_table[index] ^ (crc >> 8)
  } nobreak {
    crc
  }
}
