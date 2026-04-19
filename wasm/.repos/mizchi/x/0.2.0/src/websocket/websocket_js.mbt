///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
priv struct JsConnResult {
  id : Int
}

///|
priv struct JsWsMessage {
  kind : Int
  text : String
  binary : Bytes
  close_code : Int
  close_reason : String
}

///|
extern "js" fn js_ws_connect(url : String) -> JsPromise[JsConnResult] =
  #| async (url) => {
  #|   if (!globalThis.__xws) globalThis.__xws = { conns: new Map(), nextId: 1 };
  #|   const s = globalThis.__xws;
  #|   return new Promise((resolve, reject) => {
  #|     const ws = new WebSocket(url);
  #|     const id = s.nextId++;
  #|     const c = { ws, q: [], w: null, closed: false, cc: 1000, cr: '' };
  #|     ws.binaryType = 'arraybuffer';
  #|     ws.onopen = () => { s.conns.set(id, c); resolve({ id }); };
  #|     ws.onerror = (e) => { if (!s.conns.has(id)) reject(e); };
  #|     ws.onmessage = (e) => {
  #|       const isText = typeof e.data === 'string';
  #|       const msg = isText
  #|         ? { kind: 0, text: e.data, binary: new Uint8Array(0), close_code: 0, close_reason: '' }
  #|         : { kind: 1, text: '', binary: new Uint8Array(e.data), close_code: 0, close_reason: '' };
  #|       if (c.w) { const r = c.w; c.w = null; r(msg); }
  #|       else c.q.push(msg);
  #|     };
  #|     ws.onclose = (e) => {
  #|       c.closed = true; c.cc = e.code; c.cr = e.reason || '';
  #|       const msg = { kind: 2, text: '', binary: new Uint8Array(0), close_code: e.code, close_reason: e.reason || '' };
  #|       if (c.w) { const r = c.w; c.w = null; r(msg); }
  #|       else c.q.push(msg);
  #|     };
  #|   });
  #| }

///|
extern "js" fn js_ws_recv(id : Int) -> JsPromise[JsWsMessage] =
  #| async (id) => {
  #|   const c = globalThis.__xws.conns.get(id);
  #|   if (!c) throw new Error('Connection not found');
  #|   if (c.q.length > 0) return c.q.shift();
  #|   if (c.closed) return { kind: 2, text: '', binary: new Uint8Array(0), close_code: c.cc, close_reason: c.cr };
  #|   return new Promise(r => { c.w = r; });
  #| }

///|
extern "js" fn js_ws_send_text(id : Int, text : String) -> JsPromise[Unit] =
  #| async (id, text) => {
  #|   const c = globalThis.__xws?.conns?.get(id);
  #|   if (!c || c.closed || c.ws.readyState !== 1) throw new Error('Connection not open');
  #|   c.ws.send(text);
  #| }

///|
extern "js" fn js_ws_send_binary(id : Int, data : Bytes) -> JsPromise[Unit] =
  #| async (id, data) => {
  #|   const c = globalThis.__xws?.conns?.get(id);
  #|   if (!c || c.closed || c.ws.readyState !== 1) throw new Error('Connection not open');
  #|   c.ws.send(data);
  #| }

///|
extern "js" fn js_ws_close(
  id : Int,
  code : Int,
  reason : String,
) -> JsPromise[Unit] =
  #| async (id, code, reason) => {
  #|   const s = globalThis.__xws;
  #|   const c = s.conns.get(id);
  #|   if (!c || c.closed) throw new Error('Connection not open');
  #|   c.ws.close(code, reason);
  #|   s.conns.delete(id);
  #| }

///|
extern "js" fn js_ws_force_close(id : Int, code : Int, reason : String) -> Unit =
  #| (id, code, reason) => {
  #|   const s = globalThis.__xws;
  #|   const c = s?.conns?.get(id);
  #|   if (c) {
  #|     try { c.ws.close(code, reason); } catch {}
  #|     s.conns.delete(id);
  #|   }
  #| }

///|
extern "js" fn js_ws_ping(id : Int) -> JsPromise[Unit] =
  #| async (id) => {
  #|   const c = globalThis.__xws?.conns?.get(id);
  #|   if (!c || c.closed || c.ws.readyState !== 1) throw new Error('Connection not open');
  #|   // Browser WebSocket API does not support control ping frames.
  #| }

// Public API

///|
pub struct Conn {
  id : Int
}

///|
pub async fn Conn::connect(
  url : String,
  headers? : Map[String, String],
) -> Conn raise WebSocketError {
  // Browser WebSocket API does not support custom headers
  ignore(headers)
  let promise = js_ws_connect(url)
  let result : JsConnResult = @js_async.run_promise(fn(_signal) {
    promise.cast()
  }) catch {
    err => raise WebSocketError::InvalidHandshake(err.to_string())
  }
  Conn::{ id: result.id }
}

///|
pub async fn Conn::recv(self : Conn) -> Message raise WebSocketError {
  let promise = js_ws_recv(self.id)
  let msg : JsWsMessage = @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
  match msg.kind {
    0 => Message::Text(msg.text)
    1 => Message::Binary(msg.binary)
    _ =>
      raise WebSocketError::ConnectionClosed(
        close_code_from_int(msg.close_code),
        if msg.close_reason == "" {
          None
        } else {
          Some(msg.close_reason)
        },
      )
  }
}

///|
pub async fn Conn::send_text(
  self : Conn,
  text : StringView,
) -> Unit raise WebSocketError {
  let promise = js_ws_send_text(self.id, text.to_string())
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub async fn Conn::send_binary(
  self : Conn,
  data : BytesView,
) -> Unit raise WebSocketError {
  let bytes = Bytes::makei(data.length(), fn(i) { data[i] })
  let promise = js_ws_send_binary(self.id, bytes)
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub async fn Conn::send_close(
  self : Conn,
  code? : CloseCode,
  reason? : String,
) -> Unit raise WebSocketError {
  let c = match code {
    Some(cc) => close_code_to_int(cc)
    None => 1000
  }
  let promise = js_ws_close(self.id, c, reason.unwrap_or(""))
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub fn Conn::close(self : Conn) -> Unit {
  js_ws_force_close(self.id, 1000, "")
}

///|
pub async fn Conn::ping(
  self : Conn,
  msg? : BytesView,
) -> Unit raise WebSocketError {
  ignore(msg)
  let promise = js_ws_ping(self.id)
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}
