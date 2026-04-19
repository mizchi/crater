///|
pub struct Conn {}

///|
pub async fn Conn::connect(
  _url : String,
  headers? : Map[String, String],
) -> Conn raise WebSocketError {
  ignore(headers)
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm-gc target",
  )
}

///|
pub async fn Conn::recv(_self : Conn) -> Message raise WebSocketError {
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm-gc target",
  )
}

///|
pub async fn Conn::send_text(
  _self : Conn,
  _text : StringView,
) -> Unit raise WebSocketError {
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm-gc target",
  )
}

///|
pub async fn Conn::send_binary(
  _self : Conn,
  _data : BytesView,
) -> Unit raise WebSocketError {
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm-gc target",
  )
}

///|
pub async fn Conn::send_close(
  _self : Conn,
  code? : CloseCode,
  reason? : String,
) -> Unit raise WebSocketError {
  ignore(code)
  ignore(reason)
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm-gc target",
  )
}

///|
pub fn Conn::close(_self : Conn) -> Unit {
  abort("WebSocket is not supported on wasm-gc target")
}

///|
pub async fn Conn::ping(
  _self : Conn,
  msg? : BytesView,
) -> Unit raise WebSocketError {
  ignore(msg)
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm-gc target",
  )
}
