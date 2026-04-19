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
fn CloseCode::write_show(self : CloseCode, logger : &Logger) -> Unit {
  match self {
    Normal => logger.write_string("Normal")
    GoingAway => logger.write_string("GoingAway")
    ProtocolError => logger.write_string("ProtocolError")
    UnsupportedData => logger.write_string("UnsupportedData")
    Abnormal => logger.write_string("Abnormal")
    InvalidFramePayload => logger.write_string("InvalidFramePayload")
    PolicyViolation => logger.write_string("PolicyViolation")
    MessageTooBig => logger.write_string("MessageTooBig")
    MissingExtension => logger.write_string("MissingExtension")
    InternalError => logger.write_string("InternalError")
    Other(code) =>
      logger..write_string("Other(")..write_object(code).write_string(")")
  }
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for MessageKind

///|
pub impl Show for MessageKind with output(self, logger) {
  match self {
    Binary => logger.write_string("Binary")
    Text => logger.write_string("Text")
  }
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for CloseCode

///|
pub impl Show for CloseCode with output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for WebSocketError

///|
pub impl Show for WebSocketError with output(self, logger) {
  match self {
    ConnectionClosed(close_code, msg) => {
      logger.write_string("ConnectionClosed(")
      close_code.write_show(logger)
      logger..write_string(", ")..write_object(msg).write_string(")")
    }
    InvalidHandshake(msg) =>
      logger
      ..write_string("InvalidHandshake(")
      ..write_object(msg)
      .write_string(")")
    ProtocolError(msg) =>
      logger
      ..write_string("ProtocolError(")
      ..write_object(msg)
      .write_string(")")
  }
}
