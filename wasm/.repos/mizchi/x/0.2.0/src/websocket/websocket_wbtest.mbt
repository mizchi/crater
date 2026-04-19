///|
test "close_code_from_int roundtrip - standard codes" {
  let codes = [
    (1000, Normal),
    (1001, GoingAway),
    (1002, CloseCode::ProtocolError),
    (1003, UnsupportedData),
    (1006, Abnormal),
    (1007, InvalidFramePayload),
    (1008, PolicyViolation),
    (1009, MessageTooBig),
    (1010, MissingExtension),
    (1011, InternalError),
  ]
  for pair in codes {
    let (int_val, expected) = pair
    let result = close_code_from_int(int_val)
    assert_eq(result, expected)
    let back = close_code_to_int(result)
    assert_eq(back, int_val)
  }
}

///|
test "close_code_from_int - custom code" {
  let code = close_code_from_int(4000)
  inspect(code, content="Other(4000)")
  assert_eq(close_code_to_int(code), 4000)
}

///|
test "close_code_from_int - unknown standard range" {
  let code = close_code_from_int(1005)
  inspect(code, content="Other(1005)")
}

///|
test "MessageKind show" {
  inspect(MessageKind::Text, content="Text")
  inspect(MessageKind::Binary, content="Binary")
}

///|
test "CloseCode equality" {
  assert_eq(CloseCode::Normal, CloseCode::Normal)
  assert_eq(CloseCode::Other(4001), CloseCode::Other(4001))
  assert_not_eq(CloseCode::Normal, CloseCode::GoingAway)
}

///|
test "WebSocketError show" {
  let err : WebSocketError = WebSocketError::ConnectionClosed(Normal, None)
  inspect(err, content="ConnectionClosed(Normal, None)")
  let err2 : WebSocketError = WebSocketError::ConnectionClosed(
    Normal,
    Some("bye"),
  )
  inspect(err2, content="ConnectionClosed(Normal, Some(\"bye\"))")
  let err3 : WebSocketError = WebSocketError::InvalidHandshake("bad handshake")
  inspect(err3, content="InvalidHandshake(\"bad handshake\")")
  let err4 : WebSocketError = WebSocketError::ProtocolError("invalid frame")
  inspect(err4, content="ProtocolError(\"invalid frame\")")
}

///|
test "Message construction" {
  let text_msg = Message::Text("hello")
  guard text_msg is Text(t) else { fail("expected Text") }
  assert_eq(t, "hello")
  let bin_msg = Message::Binary(Bytes::makei(3, fn(i) { (i + 65).to_byte() }))
  guard bin_msg is Binary(data) else { fail("expected Binary") }
  assert_eq(data.length(), 3)
}
