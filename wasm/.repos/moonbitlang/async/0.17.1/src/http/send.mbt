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
priv enum SenderMode {
  SendingHeader
  WaitingBody
  SendingBody
  SendingFixed(mut remaining~ : Int64)
  PassThrough
}

///|
/// Provide send buffering & chunked encoding handling for sending HTTP request/response.
priv struct Sender {
  writer : &@io.Writer
  mut mode : SenderMode
  mut send_buf : FixedArray[Byte]
  mut send_len : Int
  headers : Bytes
  has_accept_encoding : Bool
}

///|
let forbidden_headers : Set[String] = Set::from_array([
  "content-length", "content-encoding",
])

///|
fn[W : @io.Writer] Sender::new(
  w : W,
  headers? : Map[String, String] = {},
) -> Sender {
  let header_text = @buffer.new()
  let mut has_accept_encoding = false
  for k, v in headers {
    let k_lower = k.to_lower()
    if !forbidden_headers.contains(k_lower) {
      if k_lower is "accept-encoding" {
        has_accept_encoding = true
      }
      header_text.write_string_utf8("\{k}: \{v}\r\n")
    }
  }
  {
    writer: w,
    mode: SendingHeader,
    send_buf: FixedArray::make(1024, 0),
    send_len: 0,
    headers: header_text.contents(),
    has_accept_encoding,
  }
}

///|
async fn Sender::flush(self : Sender) -> Unit {
  if self.send_len > 0 {
    self.writer.write(
      self.send_buf.unsafe_reinterpret_as_bytes()[:self.send_len],
    )
    self.send_len = 0
  }
}

///|
const NON_EMPTY_MESSAGE_HEADER_END : Bytes = "Transfer-Encoding: chunked\r\n\r\n"

///|
const EMPTY_MESSAGE_HEADER_END : Bytes = "Content-Length: 0\r\n\r\n"

///|
pub suberror IncorrectBodyLength derive(Debug, ToJson)

///|
impl @io.Writer for Sender with write_once(self, buf, offset~, len~) {
  match self.mode {
    SendingHeader => {
      if self.send_len >= self.send_buf.length() {
        self.flush()
      }
      let len = @cmp.minimum(len, self.send_buf.length() - self.send_len)
      self.send_buf.blit_from_bytes(self.send_len, buf, offset, len)
      self.send_len += len
      len
    }
    SendingFixed(remaining~) as mode => {
      guard len.to_int64() <= remaining else { raise IncorrectBodyLength }
      if self.send_len >= self.send_buf.length() {
        self.flush()
      }
      let len = @cmp.minimum(self.send_buf.length() - self.send_len, len)
      self.send_buf.blit_from_bytes(self.send_len, buf, offset, len)
      self.send_len += len
      mode.remaining -= len.to_int64()
      len
    }
    WaitingBody => {
      if self.send_len + NON_EMPTY_MESSAGE_HEADER_END.length() >
        self.send_buf.length() {
        self.flush()
      }
      self.send_buf.blit_from_bytes(
        self.send_len,
        NON_EMPTY_MESSAGE_HEADER_END,
        0,
        NON_EMPTY_MESSAGE_HEADER_END.length(),
      )
      self.send_len += NON_EMPTY_MESSAGE_HEADER_END.length()
      self.mode = SendingBody
      self.write_once(buf, offset~, len~)
    }
    SendingBody => {
      // Reserve enough space for chunk length and '\r\n' in the buffer,
      // so that we can commit the whole chunk in a single write to avoid small writes
      if self.send_len + 7 >= self.send_buf.length() {
        self.flush()
      }
      let max_len = self.send_buf.length() - self.send_len - 7
      let len = @cmp.minimum(max_len, len)
      let len_str = encode_int(len, base=16)
      let len_str_len = len_str.length()
      self.send_buf.blit_from_bytes(self.send_len, len_str, 0, len_str_len)
      let curr_len = self.send_len + len_str_len
      self.send_buf[curr_len] = '\r'
      self.send_buf[curr_len + 1] = '\n'
      let curr_len = curr_len + 2
      self.send_buf.blit_from_bytes(curr_len, buf, offset, len)
      let curr_len = curr_len + len
      self.send_buf[curr_len] = '\r'
      self.send_buf[curr_len + 1] = '\n'
      self.send_len = curr_len + 2
      len
    }
    PassThrough => self.writer.write_once(buf, offset~, len~)
  }
}

///|
impl @io.Writer for Sender with write_reader(self, reader) {
  match self.mode {
    SendingHeader =>
      for ;; {
        if self.send_len >= self.send_buf.length() {
          self.flush()
        }
        let n = reader.read(self.send_buf, offset=self.send_len)
        if n == 0 {
          break
        }
      }
    SendingFixed(remaining~) as mode =>
      for remaining = remaining {
        if self.send_len >= self.send_buf.length() {
          self.flush()
        }
        let n = reader.read(self.send_buf, offset=self.send_len)
        if n == 0 {
          mode.remaining = remaining
          break
        }
        let remaining = remaining - n.to_int64()
        if remaining < 0 {
          raise IncorrectBodyLength
        }
        self.send_len += n
        self.flush()
        continue remaining
      }
    WaitingBody => {
      if self.send_len + NON_EMPTY_MESSAGE_HEADER_END.length() >
        self.send_buf.length() {
        self.flush()
      }
      self.send_buf.blit_from_bytes(
        self.send_len,
        NON_EMPTY_MESSAGE_HEADER_END,
        0,
        NON_EMPTY_MESSAGE_HEADER_END.length(),
      )
      self.send_len += NON_EMPTY_MESSAGE_HEADER_END.length()
      self.mode = SendingBody
      self.write_reader(reader)
    }
    SendingBody => {
      self.flush()
      self.send_buf[3] = '\r'
      self.send_buf[4] = '\n'
      let max_len = self.send_buf.length() - 7
      for ;; {
        let len = reader.read(self.send_buf, offset=5, max_len~)
        if len == 0 {
          break
        }
        self.send_buf[5 + len] = '\r'
        self.send_buf[6 + len] = '\n'
        let len_str = encode_int(len, base=16)
        let start = 3 - len_str.length()
        self.send_buf.blit_from_bytes(start, len_str, 0, len_str.length())
        self.writer.write(
          self.send_buf.unsafe_reinterpret_as_bytes()[start:len + 7],
        )
      }
    }
    PassThrough => self.writer.write_reader(reader)
  }
}

///|
async fn Sender::end_body(self : Sender) -> Unit {
  match self.mode {
    SendingHeader | PassThrough =>
      abort("`end_body()` called outside a HTTP message")
    SendingFixed(remaining=0) => self.flush()
    SendingFixed(_) => raise IncorrectBodyLength
    WaitingBody =>
      if self.send_len + EMPTY_MESSAGE_HEADER_END.length() >
        self.send_buf.length() {
        self.flush()
        self.writer.write(EMPTY_MESSAGE_HEADER_END)
      } else {
        self.send_buf.blit_from_bytes(
          self.send_len,
          EMPTY_MESSAGE_HEADER_END,
          0,
          EMPTY_MESSAGE_HEADER_END.length(),
        )
        self.send_len += EMPTY_MESSAGE_HEADER_END.length()
        self.flush()
      }
    SendingBody =>
      if self.send_len + 5 > self.send_buf.length() {
        self.flush()
        self.writer.write("0\r\n\r\n")
      } else {
        self.send_buf.blit_from_bytes(self.send_len, "0\r\n\r\n", 0, 5)
        self.send_len += 5
        self.flush()
      }
  }
  self.mode = SendingHeader
}

///|
async fn Sender::send_headers(
  self : Sender,
  headers : Map[String, String],
) -> Int64? {
  let mut content_length = None
  for pair in headers.to_array() {
    let (k, v) = pair
    let k_lower = k.to_lower()
    if k_lower is "content-length" {
      let len = @string.parse_int64(v.trim(), base=10)
      content_length = Some(len)
    } else if forbidden_headers.contains(k_lower) {
      continue
    }
    self..write(k)..write(": ")..write(v).write("\r\n")
  }
  content_length
}

///|
/// Return value indicate if automatic decompression should be enabled for the response of this request
async fn Sender::send_request(
  self : Sender,
  meth : RequestMethod,
  path : String,
  extra_headers~ : Map[String, String],
) -> Bool {
  guard self.mode is SendingHeader
  match meth {
    Get => self.write("GET ")
    Head => self.write("HEAD ")
    Post => self.write("POST ")
    Put => self.write("PUT ")
    Delete => self.write("DELETE ")
    Connect => self.write("CONNECT ")
    Options => self.write("OPTIONS ")
    Trace => self.write("TRACE ")
    Patch => self.write("PATCH ")
  }
  let content_length = self
    ..write(path)
    ..write(" HTTP/1.1\r\n")
    ..write(self.headers)
    .send_headers(extra_headers)
  let auto_decompress = !self.has_accept_encoding &&
    extra_headers.keys().find_first(k => k.to_lower() is "accept-encoding")
    is None
  if auto_decompress {
    self.write("Accept-Encoding: gzip,identity\r\n")
  }
  if content_length is Some(len) {
    self.write("\r\n")
    self.mode = SendingFixed(remaining=len)
  } else {
    self.mode = WaitingBody
  }
  auto_decompress
}

///|
async fn Sender::send_response(
  self : Sender,
  code : Int,
  reason : String,
  extra_headers~ : Map[String, String],
) -> Unit {
  guard self.mode is SendingHeader
  let content_length = self
    ..write("HTTP/1.1 ")
    ..write(encode_int(code, base=10))
    ..write(" ")
    ..write(reason)
    ..write("\r\n")
    ..write(self.headers)
    .send_headers(extra_headers)
  if content_length is Some(len) {
    self.write("\r\n")
    self.mode = SendingFixed(remaining=len)
  } else {
    self.mode = WaitingBody
  }
}

///|
fn Sender::enter_passthrough_mode(self : Sender) -> Unit {
  self.send_buf = []
  self.send_len = 0
  self.mode = PassThrough
}
