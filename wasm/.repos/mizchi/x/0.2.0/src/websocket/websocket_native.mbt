///|
pub struct Conn {
  inner : @async_ws.Conn
}

///|
fn from_upstream_close_code(code : @async_ws.CloseCode) -> CloseCode {
  match code {
    @async_ws.Normal => Normal
    @async_ws.GoingAway => GoingAway
    @async_ws.CloseCode::ProtocolError => CloseCode::ProtocolError
    @async_ws.UnsupportedData => UnsupportedData
    @async_ws.Abnormal => Abnormal
    @async_ws.InvalidFramePayload => InvalidFramePayload
    @async_ws.PolicyViolation => PolicyViolation
    @async_ws.MessageTooBig => MessageTooBig
    @async_ws.MissingExtension => MissingExtension
    @async_ws.InternalError => InternalError
    @async_ws.Other(n) => Other(n)
  }
}

///|
fn to_upstream_close_code(code : CloseCode) -> @async_ws.CloseCode {
  match code {
    Normal => @async_ws.Normal
    GoingAway => @async_ws.GoingAway
    CloseCode::ProtocolError => @async_ws.CloseCode::ProtocolError
    UnsupportedData => @async_ws.UnsupportedData
    Abnormal => @async_ws.Abnormal
    InvalidFramePayload => @async_ws.InvalidFramePayload
    PolicyViolation => @async_ws.PolicyViolation
    MessageTooBig => @async_ws.MessageTooBig
    MissingExtension => @async_ws.MissingExtension
    InternalError => @async_ws.InternalError
    Other(n) => @async_ws.Other(n)
  }
}

///|
pub async fn Conn::connect(
  url : String,
  headers? : Map[String, String],
) -> Conn raise WebSocketError {
  let inner = @async_ws.Conn::connect(url, headers?) catch {
    err => raise WebSocketError::InvalidHandshake(err.to_string())
  }
  Conn::{ inner, }
}

///|
pub async fn Conn::recv(self : Conn) -> Message raise WebSocketError {
  let msg = self.inner.recv() catch {
    @async_ws.ConnectionClosed(code, reason) =>
      raise WebSocketError::ConnectionClosed(
        from_upstream_close_code(code),
        reason,
      )
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
  let data : &@io.Data = @io.Reader::read_all(msg) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
  match msg.kind {
    @async_ws.Text => Message::Text(data.text() catch { _ => "" })
    @async_ws.Binary => Message::Binary(data.binary())
  }
}

///|
pub async fn Conn::send_text(
  self : Conn,
  text : StringView,
) -> Unit raise WebSocketError {
  self.inner.send_text(text) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub async fn Conn::send_binary(
  self : Conn,
  data : BytesView,
) -> Unit raise WebSocketError {
  self.inner.send_binary(data) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub async fn Conn::send_close(
  self : Conn,
  code? : CloseCode,
  reason? : String,
) -> Unit raise WebSocketError {
  self.inner.send_close(code?=code.map(to_upstream_close_code), reason?) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub fn Conn::close(self : Conn) -> Unit {
  self.inner.close()
}

///|
pub async fn Conn::ping(
  self : Conn,
  msg? : BytesView,
) -> Unit raise WebSocketError {
  self.inner.ping(msg?) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}
