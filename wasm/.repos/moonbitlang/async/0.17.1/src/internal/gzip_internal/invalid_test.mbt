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
test "decoder rejects invalid gzip header" {
  let result = try? decode(
    b"\x1f\x8b\x08\x02\x00\x00\x00\x00\x00\x00\x1d\x26\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    expected_len=0,
  )
  assert_true(result is Err(_))
}

///|
test "decoder verifies trailer automatically" {
  let encoded = encode(b"\x00")
  let corrupted = encoded[:encoded.length() - 8].to_bytes() +
    b"\x00\x00\x00\x00\x01\x00\x00\x00"
  let result = try? decode(corrupted, expected_len=1)
  assert_true(result is Err(_))
}
