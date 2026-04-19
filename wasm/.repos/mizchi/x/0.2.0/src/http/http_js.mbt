///|
extern "js" fn js_fetch_internal(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
) -> @js_async.Promise[String] =
  #| async (url, method, headersJson, body) => {
  #|   const headers = JSON.parse(headersJson);
  #|   try {
  #|     const options = { method, headers };
  #|     if (body && method !== 'GET' && method !== 'HEAD') {
  #|       options.body = body;
  #|     }
  #|     const res = await fetch(url, options);
  #|     const resBody = await res.text();
  #|     const resHeaders = {};
  #|     res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|     return JSON.stringify({
  #|       code: res.status,
  #|       reason: res.statusText,
  #|       headers: resHeaders,
  #|       body: resBody,
  #|     });
  #|   } catch (e) {
  #|     throw e;
  #|   }
  #| }

///|
fn parse_response_json(json_str : String) -> (Response, &@io.Data) {
  let parsed = @json.parse(json_str) catch {
    _ => return (Response::{ code: 0, reason: "", headers: {} }, "")
  }
  let code = match parsed {
    Object(map) =>
      match map.get("code") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
    _ => 0
  }
  let reason = match parsed {
    Object(map) =>
      match map.get("reason") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let body : String = match parsed {
    Object(map) =>
      match map.get("body") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let headers : Map[String, String] = {}
  match parsed {
    Object(map) =>
      match map.get("headers") {
        Some(Object(hmap)) =>
          hmap.each(fn(k, v) {
            match v {
              String(s) => headers[k.to_lower()] = s
              _ => ()
            }
          })
        _ => ()
      }
    _ => ()
  }
  (Response::{ code, reason, headers }, body)
}

// Streaming API

///|
priv struct JsStreamResult {
  id : Int
  code : Int
  reason : String
  headers_json : String
}

///|
priv struct JsStreamChunk {
  done : Bool
  data : Bytes
}

///|
extern "js" fn js_fetch_stream(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
) -> @js_async.Promise[JsStreamResult] =
  #| async (url, method, headersJson, body) => {
  #|   if (!globalThis.__xhs) globalThis.__xhs = { streams: new Map(), nextId: 1 };
  #|   const headers = JSON.parse(headersJson);
  #|   const options = { method, headers };
  #|   if (body && method !== 'GET' && method !== 'HEAD') {
  #|     options.body = body;
  #|   }
  #|   const res = await fetch(url, options);
  #|   const reader = res.body.getReader();
  #|   const id = globalThis.__xhs.nextId++;
  #|   globalThis.__xhs.streams.set(id, { reader });
  #|   const resHeaders = {};
  #|   res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|   return { id, code: res.status, reason: res.statusText, headers_json: JSON.stringify(resHeaders) };
  #| }

///|
extern "js" fn js_stream_read(id : Int) -> @js_async.Promise[JsStreamChunk] =
  #| async (id) => {
  #|   const s = globalThis.__xhs.streams.get(id);
  #|   if (!s) throw new Error('Stream not found');
  #|   const { done, value } = await s.reader.read();
  #|   return { done, data: done ? new Uint8Array(0) : value };
  #| }

///|
extern "js" fn js_stream_close(id : Int) -> Unit =
  #| (id) => {
  #|   const s = globalThis.__xhs;
  #|   const st = s.streams.get(id);
  #|   if (st) { st.reader.cancel().catch(() => {}); s.streams.delete(id); }
  #| }

///|
pub struct Stream {
  id : Int
}

///|
fn parse_headers_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  let parsed = @json.parse(json_str) catch { _ => return headers }
  match parsed {
    Object(map) =>
      map.each(fn(k, v) {
        match v {
          String(s) => headers[k.to_lower()] = s
          _ => ()
        }
      })
    _ => ()
  }
  headers
}

// Server API

///|
priv struct JsServeStart {
  id : Int
  port : Int
}

///|
priv struct JsServerAccept {
  conn_id : Int
  req_meth : String
  req_url : String
  headers_json : String
  client_host : String
  client_port : Int
}

///|
extern "js" fn js_server_new(
  host : String,
  port : Int,
  headers_json : String,
  max_request_body_bytes : Int,
  request_timeout_ms : Int,
  keep_alive_timeout_ms : Int,
  headers_timeout_ms : Int,
  accept_queue_limit : Int,
  trust_proxy : Bool,
) -> @js_async.Promise[JsServeStart] =
  #| async (host, port, headersJson, maxRequestBodyBytes, requestTimeoutMs, keepAliveTimeoutMs, headersTimeoutMs, acceptQueueLimit, trustProxy) => {
  #|   const http = await import('node:http');
  #|   if (!globalThis.__xhttpServer) {
  #|     globalThis.__xhttpServer = {
  #|       nextId: 1,
  #|       nextConnId: 1,
  #|       servers: new Map(),
  #|       conns: new Map(),
  #|     };
  #|   }
  #|   const state = globalThis.__xhttpServer;
  #|   const server = http.createServer();
  #|   const baseHeaders = JSON.parse(headersJson || '{}');
  #|   const normalizeClientHost = (rawHost) => {
  #|     if (!rawHost || rawHost.length === 0) return '127.0.0.1';
  #|     if (rawHost.startsWith('::ffff:')) return rawHost.slice(7);
  #|     return rawHost;
  #|   };
  #|   const id = state.nextId++;
  #|   const shouldLogHandlerError = typeof process !== 'undefined' &&
  #|     process?.env?.X_HTTP_LOG_HANDLER_ERRORS === '1';
  #|   const entry = {
  #|     server,
  #|     onRequest: null,
  #|     allowFailure: true,
  #|     maxConnections: 0,
  #|     inflight: 0,
  #|     maxRequestBodyBytes: Math.max(0, Number(maxRequestBodyBytes || 0)),
  #|     acceptQueueLimit: Math.max(1, Number(acceptQueueLimit || 128)),
  #|     trustProxy: !!trustProxy,
  #|     baseHeaders,
  #|     mode: 'idle',
  #|     runWaiters: [],
  #|     acceptWaiters: [],
  #|     acceptQueue: [],
  #|     sockets: new Set(),
  #|     closeGracefulPromise: null,
  #|     closing: false,
  #|     closed: false,
  #|   };
  #|   state.servers.set(id, entry);
  #|   if (requestTimeoutMs > 0) {
  #|     server.requestTimeout = requestTimeoutMs;
  #|   }
  #|   if (keepAliveTimeoutMs > 0) {
  #|     server.keepAliveTimeout = keepAliveTimeoutMs;
  #|   }
  #|   if (headersTimeoutMs > 0) {
  #|     server.headersTimeout = headersTimeoutMs;
  #|   }
  #|   server.on('connection', (socket) => {
  #|     entry.sockets.add(socket);
  #|     socket.once('close', () => { entry.sockets.delete(socket); });
  #|     if (entry.closing) {
  #|       try { socket.destroy(); } catch {}
  #|     }
  #|   });
  #|   const firstHeaderValue = (value) => {
  #|     if (Array.isArray(value)) {
  #|       return value.length > 0 ? String(value[0]) : '';
  #|     }
  #|     if (typeof value === 'string') return value;
  #|     if (value == null) return '';
  #|     return String(value);
  #|   };
  #|   const parseForwardedIp = (value) => {
  #|     const raw = firstHeaderValue(value);
  #|     if (!raw) return '';
  #|     let host = raw.split(',')[0].trim();
  #|     if (!host) return '';
  #|     if (host.startsWith('"') && host.endsWith('"') && host.length >= 2) {
  #|       host = host.slice(1, -1);
  #|     }
  #|     if (host.startsWith('[')) {
  #|       const end = host.indexOf(']');
  #|       if (end > 0) return host.slice(1, end);
  #|     }
  #|     const lastColon = host.lastIndexOf(':');
  #|     if (lastColon > 0 && host.indexOf(':') === lastColon) {
  #|       const maybePort = Number.parseInt(host.slice(lastColon + 1), 10);
  #|       if (Number.isFinite(maybePort)) {
  #|         host = host.slice(0, lastColon);
  #|       }
  #|     }
  #|     return host;
  #|   };
  #|   const parseForwardedPort = (value) => {
  #|     const raw = firstHeaderValue(value);
  #|     if (!raw) return 0;
  #|     const first = raw.split(',')[0].trim();
  #|     const parsed = Number.parseInt(first, 10);
  #|     if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 65535) return 0;
  #|     return parsed;
  #|   };
  #|   const parsePortFromHost = (value) => {
  #|     const raw = firstHeaderValue(value);
  #|     if (!raw) return 0;
  #|     const host = raw.split(',')[0].trim();
  #|     if (!host) return 0;
  #|     if (host.startsWith('[')) {
  #|       const end = host.indexOf(']');
  #|       if (end > 0 && host.length > end + 2 && host[end + 1] === ':') {
  #|         return parseForwardedPort(host.slice(end + 2));
  #|       }
  #|       return 0;
  #|     }
  #|     const lastColon = host.lastIndexOf(':');
  #|     if (lastColon <= 0 || host.indexOf(':') !== lastColon) return 0;
  #|     return parseForwardedPort(host.slice(lastColon + 1));
  #|   };
  #|   const resolveClientAddr = (req) => {
  #|     const headers = req?.headers || {};
  #|     let clientHost = normalizeClientHost(req?.socket?.remoteAddress || '');
  #|     let clientPort = Number(req?.socket?.remotePort || 0);
  #|     if (!entry.trustProxy) {
  #|       return { clientHost, clientPort };
  #|     }
  #|     const forwardedHost = parseForwardedIp(headers['x-forwarded-for']);
  #|     if (forwardedHost && forwardedHost.toLowerCase() !== 'unknown') {
  #|       clientHost = normalizeClientHost(forwardedHost);
  #|     }
  #|     const forwardedPort = parseForwardedPort(headers['x-forwarded-port']);
  #|     if (forwardedPort > 0) {
  #|       clientPort = forwardedPort;
  #|     } else {
  #|       const hostPort = parsePortFromHost(headers['x-forwarded-host']);
  #|       if (hostPort > 0) clientPort = hostPort;
  #|     }
  #|     return { clientHost, clientPort };
  #|   };
  #|   const requestReadHighWatermark = 1024 * 1024;
  #|   const requestReadLowWatermark = requestReadHighWatermark >> 1;
  #|   const socketReadHighWatermark = 1024 * 1024;
  #|   const socketReadLowWatermark = socketReadHighWatermark >> 1;
  #|   const socketReadMaxQueueBytes = 4 * 1024 * 1024;
  #|   const connWriteDrainTimeoutMs = 5000;
  #|   const copyChunk = (chunk) => {
  #|     if (chunk instanceof Uint8Array) {
  #|       if (typeof Buffer !== 'undefined' && Buffer.isBuffer?.(chunk)) {
  #|         return new Uint8Array(chunk.buffer, chunk.byteOffset, chunk.byteLength);
  #|       }
  #|       return chunk;
  #|     }
  #|     return new Uint8Array(Buffer.from(chunk));
  #|   };
  #|   const resolveRequestWaiters = (conn, value) => {
  #|     while (conn.requestReadWaiters.length > 0) {
  #|       conn.requestReadWaiters.shift()(value);
  #|     }
  #|   };
  #|   const maybeResumeRequest = (conn) => {
  #|     if (!conn.requestReadPaused) return;
  #|     if (conn.requestReadEnded || conn.requestReadSkipped || conn.closed) {
  #|       conn.requestReadPaused = false;
  #|       return;
  #|     }
  #|     if (conn.requestReadQueueBytes > conn.requestReadLowWatermark) return;
  #|     conn.requestReadPaused = false;
  #|     try { conn.req.resume(); } catch {}
  #|   };
  #|   const maybeResumeSocketRead = (conn) => {
  #|     if (!conn.socketReadPaused) return;
  #|     if (conn.socketReadEnded || conn.closed) {
  #|       conn.socketReadPaused = false;
  #|       return;
  #|     }
  #|     if (conn.socketReadQueueBytes > conn.socketReadLowWatermark) return;
  #|     conn.socketReadPaused = false;
  #|     try { conn.socket?.resume?.(); } catch {}
  #|   };
  #|   const detachRequestRead = (conn) => {
  #|     const req = conn?.req;
  #|     if (!req || !conn.requestReadAttached) return;
  #|     if (conn.requestReadOnData) {
  #|       try { req.off('data', conn.requestReadOnData); } catch {}
  #|     }
  #|     if (conn.requestReadOnEnd) {
  #|       try { req.off('end', conn.requestReadOnEnd); } catch {}
  #|     }
  #|     if (conn.requestReadOnClose) {
  #|       try { req.off('close', conn.requestReadOnClose); } catch {}
  #|     }
  #|     if (conn.requestReadOnError) {
  #|       try { req.off('error', conn.requestReadOnError); } catch {}
  #|     }
  #|     if (conn.requestReadOnAborted) {
  #|       try { req.off('aborted', conn.requestReadOnAborted); } catch {}
  #|     }
  #|     conn.requestReadAttached = false;
  #|     conn.requestReadOnData = null;
  #|     conn.requestReadOnEnd = null;
  #|     conn.requestReadOnClose = null;
  #|     conn.requestReadOnError = null;
  #|     conn.requestReadOnAborted = null;
  #|   };
  #|   const finishRequestRead = (conn) => {
  #|     if (conn.requestReadEnded) return;
  #|     conn.requestReadEnded = true;
  #|     conn.requestReadError = null;
  #|     resolveRequestWaiters(conn, new Uint8Array(0));
  #|   };
  #|   const failRequestRead = (conn, err) => {
  #|     if (conn.requestReadEnded) return;
  #|     conn.requestReadEnded = true;
  #|     conn.requestReadError = err;
  #|     resolveRequestWaiters(conn, new Uint8Array(0));
  #|   };
  #|   const closeBodyTooLarge = (conn) => {
  #|     if (!conn || conn.responseEnded || conn.closed) return;
  #|     conn.requestReadSkipped = true;
  #|     conn.requestReadQueue = [];
  #|     conn.requestReadCarry = null;
  #|     conn.requestReadQueueBytes = 0;
  #|     if (conn.requestReadPaused) {
  #|       conn.requestReadPaused = false;
  #|       try { conn.req.resume(); } catch {}
  #|     }
  #|     resolveRequestWaiters(conn, new Uint8Array(0));
  #|     const currentEntry = state.servers.get(conn.serverId);
  #|     try {
  #|       if (!conn.responseStarted && !conn.res.headersSent) {
  #|         conn.res.writeHead(413, currentEntry?.baseHeaders || {});
  #|         conn.responseStarted = true;
  #|       }
  #|       conn.res.end('request body too large');
  #|       conn.responseEnded = true;
  #|     } catch {}
  #|     conn.closed = true;
  #|   };
  #|   const makeConn = (req, res) => {
  #|     const connId = state.nextConnId++;
  #|     const resolved = resolveClientAddr(req);
  #|     const conn = {
  #|       id: connId,
  #|       serverId: id,
  #|       req,
  #|       res,
  #|       socket: req?.socket,
  #|       passthrough: false,
  #|       socketReadQueue: [],
  #|       socketReadQueueBytes: 0,
  #|       socketReadCarry: null,
  #|       socketReadWaiters: [],
  #|       socketReadAttached: false,
  #|       socketReadEnded: false,
  #|       socketReadPaused: false,
  #|       socketReadOnData: null,
  #|       socketReadOnEnd: null,
  #|       socketReadHighWatermark,
  #|       socketReadLowWatermark,
  #|       socketReadMaxQueueBytes,
  #|       requestReadQueue: [],
  #|       requestReadCarry: null,
  #|       requestReadQueueBytes: 0,
  #|       requestReadWaiters: [],
  #|       requestReadAttached: false,
  #|       requestReadEnded: false,
  #|       requestReadSkipped: false,
  #|       requestReadPaused: false,
  #|       requestReadError: null,
  #|       requestReadOnData: null,
  #|       requestReadOnEnd: null,
  #|       requestReadOnClose: null,
  #|       requestReadOnError: null,
  #|       requestReadOnAborted: null,
  #|       requestReadHighWatermark,
  #|       requestReadLowWatermark,
  #|       requestBytesTotal: 0,
  #|       responseStarted: false,
  #|       responseEnded: false,
  #|       closed: false,
  #|       clientHost: resolved.clientHost,
  #|       clientPort: resolved.clientPort,
  #|     };
  #|     state.conns.set(connId, conn);
  #|     const cleanupConn = () => {
  #|       const current = state.conns.get(connId);
  #|       if (!current) return;
  #|       if (current.socketReadAttached && current.socket) {
  #|         try { current.socket.off('data', current.socketReadOnData); } catch {}
  #|         try { current.socket.off('end', current.socketReadOnEnd); } catch {}
  #|         try { current.socket.off('close', current.socketReadOnEnd); } catch {}
  #|         current.socketReadAttached = false;
  #|       }
  #|       detachRequestRead(current);
  #|       current.requestReadQueue = [];
  #|       current.requestReadCarry = null;
  #|       current.requestReadQueueBytes = 0;
  #|       current.requestReadPaused = false;
  #|       current.socketReadQueue = [];
  #|       current.socketReadQueueBytes = 0;
  #|       current.socketReadPaused = false;
  #|       current.socketReadCarry = null;
  #|       while (current.requestReadWaiters.length > 0) {
  #|         current.requestReadWaiters.shift()(new Uint8Array(0));
  #|       }
  #|       while (current.socketReadWaiters.length > 0) {
  #|         current.socketReadWaiters.shift()(new Uint8Array(0));
  #|       }
  #|       current.closed = true;
  #|       current.responseEnded = true;
  #|       state.conns.delete(connId);
  #|     };
  #|     res.once('close', cleanupConn);
  #|     res.once('finish', cleanupConn);
  #|     return conn;
  #|   };
  #|   const attachRequestRead = (conn) => {
  #|     if (!conn || conn.requestReadAttached) return;
  #|     conn.requestReadAttached = true;
  #|     const onData = (chunk) => {
  #|       if (!conn || conn.requestReadEnded || conn.requestReadSkipped || conn.closed) return;
  #|       const copied = copyChunk(chunk);
  #|       conn.requestBytesTotal += copied.length;
  #|       if (entry.maxRequestBodyBytes > 0 && conn.requestBytesTotal > entry.maxRequestBodyBytes) {
  #|         const err = new Error('request body too large');
  #|         err.code = 'X_BODY_TOO_LARGE';
  #|         failRequestRead(conn, err);
  #|         closeBodyTooLarge(conn);
  #|         return;
  #|       }
  #|       const waiter = conn.requestReadWaiters.shift();
  #|       if (waiter) {
  #|         waiter(copied);
  #|         return;
  #|       }
  #|       conn.requestReadQueue.push(copied);
  #|       conn.requestReadQueueBytes += copied.length;
  #|       if (!conn.requestReadPaused && conn.requestReadQueueBytes > conn.requestReadHighWatermark) {
  #|         conn.requestReadPaused = true;
  #|         try { conn.req.pause(); } catch {}
  #|       }
  #|     };
  #|     const onEnd = () => {
  #|       finishRequestRead(conn);
  #|     };
  #|     const onClose = () => {
  #|       finishRequestRead(conn);
  #|     };
  #|     const onError = (err) => {
  #|       failRequestRead(conn, err || new Error('request body error'));
  #|     };
  #|     const onAborted = () => {
  #|       finishRequestRead(conn);
  #|     };
  #|     conn.requestReadOnData = onData;
  #|     conn.requestReadOnEnd = onEnd;
  #|     conn.requestReadOnClose = onClose;
  #|     conn.requestReadOnError = onError;
  #|     conn.requestReadOnAborted = onAborted;
  #|     conn.req.on('data', onData);
  #|     conn.req.on('end', onEnd);
  #|     conn.req.on('close', onClose);
  #|     conn.req.on('error', onError);
  #|     conn.req.on('aborted', onAborted);
  #|     if (conn.req.complete || conn.req.destroyed) {
  #|       finishRequestRead(conn);
  #|     } else {
  #|       maybeResumeRequest(conn);
  #|       try { conn.req.resume(); } catch {}
  #|     }
  #|   };
  #|   server.on('request', async (req, res) => {
  #|     if (entry.mode !== 'run' && entry.mode !== 'accept') {
  #|       res.statusCode = 503;
  #|       res.end('server not running');
  #|       return;
  #|     }
  #|     if (entry.mode === 'run' && !entry.onRequest) {
  #|       res.statusCode = 503;
  #|       res.end('server not running');
  #|       return;
  #|     }
  #|     if (entry.mode === 'accept' && entry.acceptWaiters.length === 0 && entry.acceptQueue.length >= entry.acceptQueueLimit) {
  #|       res.statusCode = 503;
  #|       res.end('accept queue full');
  #|       return;
  #|     }
  #|     if (entry.maxConnections > 0 && entry.inflight >= entry.maxConnections) {
  #|       res.statusCode = 503;
  #|       res.end('too many connections');
  #|       return;
  #|     }
  #|     entry.inflight++;
  #|     const conn = makeConn(req, res);
  #|     attachRequestRead(conn);
  #|     const reqHeaders = JSON.stringify(req.headers || {});
  #|     try {
  #|       if (entry.mode === 'accept') {
  #|         const accepted = {
  #|           conn_id: conn.id,
  #|           req_meth: req.method || 'GET',
  #|           req_url: req.url || '/',
  #|           headers_json: reqHeaders,
  #|           client_host: conn.clientHost,
  #|           client_port: conn.clientPort,
  #|         };
  #|         const waiter = entry.acceptWaiters.shift();
  #|         if (waiter) {
  #|           waiter.resolve(accepted);
  #|         } else {
  #|           entry.acceptQueue.push(accepted);
  #|         }
  #|       } else {
  #|         await entry.onRequest(
  #|           req.method || 'GET',
  #|           req.url || '/',
  #|           reqHeaders,
  #|           conn.id,
  #|           conn.clientHost,
  #|           conn.clientPort,
  #|         );
  #|       }
  #|     } catch (err) {
  #|       const current = state.conns.get(conn.id);
  #|       if (current && !current.responseEnded && !current.closed) {
  #|         try {
  #|           if (!current.responseStarted) {
  #|             current.res.writeHead(500, entry.baseHeaders || {});
  #|             current.responseStarted = true;
  #|           }
  #|           if (shouldLogHandlerError) {
  #|             try { console.error?.('[x/http] request handler failed', err); } catch {}
  #|           }
  #|           current.res.end('internal server error');
  #|           current.responseEnded = true;
  #|         } catch {}
  #|         state.conns.delete(conn.id);
  #|       }
  #|       if (!entry.allowFailure) {
  #|         entry.server.close();
  #|       }
  #|     } finally {
  #|       entry.inflight--;
  #|     }
  #|   });
  #|   server.on('close', () => {
  #|     if (entry.closed) return;
  #|     entry.closed = true;
  #|     entry.closing = true;
  #|     for (const [connId, conn] of state.conns.entries()) {
  #|       if (conn.serverId === id) {
  #|         try { conn.req.destroy(); } catch {}
  #|         try { conn.res.destroy(); } catch {}
  #|         state.conns.delete(connId);
  #|       }
  #|     }
  #|     for (const resolve of entry.runWaiters) resolve();
  #|     entry.runWaiters = [];
  #|     for (const waiter of entry.acceptWaiters) {
  #|       waiter.reject(new Error('Server closed'));
  #|     }
  #|     entry.acceptWaiters = [];
  #|     entry.acceptQueue = [];
  #|     state.servers.delete(id);
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onError = (err) => reject(err);
  #|     server.once('error', onError);
  #|     server.listen(port, host, () => {
  #|       server.off('error', onError);
  #|       resolve();
  #|     });
  #|   });
  #|   const addr = server.address();
  #|   const listenPort = typeof addr === 'object' && addr ? addr.port : port;
  #|   return { id, port: listenPort };
  #| }

///|
extern "js" fn js_server_run(
  id : Int,
  on_request : (String, String, String, Int, String, Int) -> @js_async.Promise[
    Unit,
  ],
  allow_failure : Bool,
  max_connections : Int,
) -> @js_async.Promise[Unit] =
  #| async (id, onRequest, allowFailure, maxConnections) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const entry = state?.servers.get(id);
  #|   if (!entry) throw new Error('Server not found');
  #|   if (entry.mode === 'accept') {
  #|     throw new Error('Server is in accept mode');
  #|   }
  #|   entry.mode = 'run';
  #|   entry.onRequest = onRequest;
  #|   entry.allowFailure = allowFailure;
  #|   entry.maxConnections = maxConnections;
  #|   if (entry.closed) return;
  #|   await new Promise((resolve) => { entry.runWaiters.push(resolve); });
  #| }

///|
extern "js" fn js_server_accept(id : Int) -> @js_async.Promise[JsServerAccept] =
  #| async (id) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const entry = state?.servers.get(id);
  #|   if (!entry) throw new Error('Server not found');
  #|   if (entry.mode === 'run') {
  #|     throw new Error('Server is in run_forever mode');
  #|   }
  #|   entry.mode = 'accept';
  #|   if (entry.closed) throw new Error('Server closed');
  #|   if (entry.acceptQueue.length > 0) {
  #|     return entry.acceptQueue.shift();
  #|   }
  #|   return await new Promise((resolve, reject) => {
  #|     entry.acceptWaiters.push({ resolve, reject });
  #|   });
  #| }

///|
extern "js" fn js_server_close(id : Int) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xhttpServer;
  #|   if (!state) return;
  #|   const entry = state.servers.get(id);
  #|   if (!entry) return;
  #|   entry.closing = true;
  #|   entry.server.close();
  #| }

///|
extern "js" fn js_server_close_graceful(
  id : Int,
  timeout_ms : Int,
) -> @js_async.Promise[Unit] =
  #| async (id, timeoutMs) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const entry = state?.servers.get(id);
  #|   if (!entry) return;
  #|   if (entry.closeGracefulPromise) {
  #|     await entry.closeGracefulPromise;
  #|     return;
  #|   }
  #|   entry.closeGracefulPromise = (async () => {
  #|     entry.closing = true;
  #|     entry.mode = 'idle';
  #|     entry.onRequest = null;
  #|     try { entry.server.closeIdleConnections?.(); } catch {}
  #|     const closePromise = new Promise((resolve) => {
  #|       try {
  #|         entry.server.close(() => resolve());
  #|       } catch {
  #|         resolve();
  #|       }
  #|     });
  #|     if (!(timeoutMs > 0)) {
  #|       await closePromise;
  #|       return;
  #|     }
  #|     let timedOut = false;
  #|     let timer = null;
  #|     const timeoutPromise = new Promise((resolve) => {
  #|       timer = setTimeout(() => {
  #|         timedOut = true;
  #|         for (const [connId, conn] of state.conns.entries()) {
  #|           if (conn.serverId !== id) continue;
  #|           if (!conn.closed && !conn.responseEnded && conn.responseStarted && !conn.passthrough) {
  #|             try { conn.res.end(); } catch {}
  #|             conn.responseEnded = true;
  #|           }
  #|           const current = state.conns.get(connId);
  #|           if (current && current.socket && !current.socket.destroyed) {
  #|             try { current.socket.destroy(); } catch {}
  #|           }
  #|         }
  #|         try { entry.server.closeAllConnections?.(); } catch {}
  #|         for (const socket of entry.sockets) {
  #|           try { socket.destroy(); } catch {}
  #|         }
  #|         resolve();
  #|       }, timeoutMs);
  #|     });
  #|     await Promise.race([closePromise, timeoutPromise]);
  #|     if (timer) {
  #|       clearTimeout(timer);
  #|     }
  #|     if (timedOut) {
  #|       await Promise.race([
  #|         closePromise,
  #|         new Promise((resolve) => setTimeout(resolve, 250)),
  #|       ]);
  #|       if (!entry.closed) {
  #|         entry.closed = true;
  #|         entry.closing = true;
  #|         for (const [connId, conn] of state.conns.entries()) {
  #|           if (conn.serverId !== id) continue;
  #|           try { conn.req.destroy(); } catch {}
  #|           try { conn.res.destroy(); } catch {}
  #|           state.conns.delete(connId);
  #|         }
  #|         for (const resolve of entry.runWaiters) resolve();
  #|         entry.runWaiters = [];
  #|         for (const waiter of entry.acceptWaiters) {
  #|           waiter.reject(new Error('Server closed'));
  #|         }
  #|         entry.acceptWaiters = [];
  #|         entry.acceptQueue = [];
  #|         state.servers.delete(id);
  #|       }
  #|     }
  #|   })();
  #|   try {
  #|     await entry.closeGracefulPromise;
  #|   } finally {
  #|     entry.closeGracefulPromise = null;
  #|   }
  #| }

///|
extern "js" fn js_conn_send_response(
  conn_id : Int,
  code : Int,
  reason : String,
  headers_json : String,
) -> Unit =
  #| (connId, code, reason, headersJson) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded || conn.responseStarted) return;
  #|   const entry = state.servers.get(conn.serverId);
  #|   const base = entry?.baseHeaders || {};
  #|   let extra = {};
  #|   if (headersJson && headersJson.length > 0) {
  #|     try { extra = JSON.parse(headersJson); } catch {}
  #|   }
  #|   const headers = { ...base, ...extra };
  #|   const status = typeof code === 'number' ? code : 200;
  #|   if (reason && reason.length > 0) {
  #|     conn.res.writeHead(status, reason, headers);
  #|   } else {
  #|     conn.res.writeHead(status, headers);
  #|   }
  #|   conn.responseStarted = true;
  #| }

///|
extern "js" fn js_conn_write(
  conn_id : Int,
  data : Bytes,
  offset : Int,
  len : Int,
) -> @js_async.Promise[Int] =
  #| async (connId, data, offset, len) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded) return 0;
  #|   const start = Math.max(0, offset | 0);
  #|   const maxLen = Math.max(0, len | 0);
  #|   const end = Math.min(data.length, start + maxLen);
  #|   if (end <= start) return 0;
  #|   const slice = data.subarray(start, end);
  #|   const target = conn.passthrough ? conn.socket : conn.res;
  #|   if (!target) return 0;
  #|   const isTargetClosed = () => {
  #|     return !!target.destroyed || !!target.closed || !!target.writableEnded;
  #|   };
  #|   if (isTargetClosed()) return 0;
  #|   if (!conn.passthrough && !conn.responseStarted) {
  #|     const entry = state.servers.get(conn.serverId);
  #|     conn.res.writeHead(200, entry?.baseHeaders || {});
  #|     conn.responseStarted = true;
  #|   }
  #|   let wrote = false;
  #|   try {
  #|     wrote = target.write(slice);
  #|   } catch {
  #|     return 0;
  #|   }
  #|   if (!wrote) {
  #|     const drained = await new Promise((resolve) => {
  #|       if (isTargetClosed()) {
  #|         resolve(false);
  #|         return;
  #|       }
  #|       let settled = false;
  #|       const onDrain = () => {
  #|         done(true);
  #|       };
  #|       const onError = () => {
  #|         done(false);
  #|       };
  #|       const done = (ok) => {
  #|         if (settled) return;
  #|         settled = true;
  #|         clearTimeout(timer);
  #|         target.off?.('drain', onDrain);
  #|         target.off?.('error', onError);
  #|         target.off?.('close', onError);
  #|         target.off?.('finish', onError);
  #|         resolve(ok);
  #|       };
  #|       const timer = setTimeout(() => done(false), connWriteDrainTimeoutMs);
  #|       target.once?.('drain', onDrain);
  #|       target.once?.('error', onError);
  #|       target.once?.('close', onError);
  #|       target.once?.('finish', onError);
  #|     });
  #|     if (!drained) {
  #|       conn.closed = true;
  #|       conn.responseEnded = true;
  #|       try { target.destroy?.(); } catch {}
  #|       return 0;
  #|     }
  #|   }
  #|   const current = state?.conns.get(connId);
  #|   if (!current || current.closed || current.responseEnded || isTargetClosed()) return 0;
  #|   return end - start;
  #| }

///|
extern "js" fn js_conn_flush(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded) return;
  #|   if (conn.passthrough) return;
  #|   if (!conn.responseStarted) {
  #|     const entry = state.servers.get(conn.serverId);
  #|     conn.res.writeHead(200, entry?.baseHeaders || {});
  #|     conn.responseStarted = true;
  #|   }
  #|   if (typeof conn.res.flushHeaders === 'function') {
  #|     conn.res.flushHeaders();
  #|   }
  #|   if (typeof conn.res.flush === 'function') {
  #|     try { conn.res.flush(); } catch {}
  #|   }
  #| }

///|
extern "js" fn js_conn_end(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded) return;
  #|   if (conn.passthrough) return;
  #|   if (!conn.responseStarted) {
  #|     const entry = state.servers.get(conn.serverId);
  #|     conn.res.writeHead(200, entry?.baseHeaders || {});
  #|     conn.responseStarted = true;
  #|   }
  #|   conn.res.end();
  #|   conn.responseEnded = true;
  #| }

///|
extern "js" fn js_conn_close(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn) return;
  #|   if (conn.requestReadAttached && conn.req) {
  #|     try { conn.req.off('data', conn.requestReadOnData); } catch {}
  #|     try { conn.req.off('end', conn.requestReadOnEnd); } catch {}
  #|     try { conn.req.off('close', conn.requestReadOnClose); } catch {}
  #|     try { conn.req.off('error', conn.requestReadOnError); } catch {}
  #|     try { conn.req.off('aborted', conn.requestReadOnAborted); } catch {}
  #|     conn.requestReadAttached = false;
  #|   }
  #|   conn.requestReadQueue = [];
  #|   conn.requestReadCarry = null;
  #|   conn.requestReadQueueBytes = 0;
  #|   conn.requestReadPaused = false;
  #|   conn.requestReadSkipped = true;
  #|   while (conn.requestReadWaiters.length > 0) {
  #|     conn.requestReadWaiters.shift()(new Uint8Array(0));
  #|   }
  #|   if (conn.socketReadAttached && conn.socket) {
  #|     try { conn.socket.off('data', conn.socketReadOnData); } catch {}
  #|     try { conn.socket.off('end', conn.socketReadOnEnd); } catch {}
  #|     try { conn.socket.off('close', conn.socketReadOnEnd); } catch {}
  #|     conn.socketReadAttached = false;
  #|   }
  #|   conn.socketReadQueue = [];
  #|   conn.socketReadQueueBytes = 0;
  #|   conn.socketReadPaused = false;
  #|   conn.socketReadCarry = null;
  #|   while (conn.socketReadWaiters.length > 0) {
  #|     conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|   }
  #|   conn.closed = true;
  #|   conn.responseEnded = true;
  #|   try { conn.req.destroy(); } catch {}
  #|   try { conn.res.destroy(); } catch {}
  #|   state.conns.delete(connId);
  #| }

///|
extern "js" fn js_conn_enter_passthrough(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed) return;
  #|   if (conn.responseStarted && !conn.responseEnded) {
  #|     throw new Error('cannot enter passthrough mode in middle of response');
  #|   }
  #|   if (!conn.socket || conn.socket.destroyed) {
  #|     throw new Error('socket is not available');
  #|   }
  #|   conn.passthrough = true;
  #|   conn.closed = false;
  #|   conn.responseEnded = false;
  #|   conn.socketReadQueue = [];
  #|   conn.socketReadQueueBytes = 0;
  #|   conn.socketReadPaused = false;
  #|   conn.socketReadEnded = false;
  #|   conn.socketReadCarry = null;
  #|   if (conn.socketReadAttached) return;
  #|   const onData = (chunk) => {
  #|     if (!conn || conn.closed || conn.socketReadEnded) return;
  #|     const data = copyChunk(chunk);
  #|     const waiter = conn.socketReadWaiters.shift();
  #|     if (waiter) {
  #|       waiter(data);
  #|     } else {
  #|       conn.socketReadQueue.push(data);
  #|       conn.socketReadQueueBytes += data.length;
  #|       if (conn.socketReadQueueBytes > conn.socketReadMaxQueueBytes) {
  #|         conn.socketReadQueue = [];
  #|         conn.socketReadCarry = null;
  #|         conn.socketReadQueueBytes = 0;
  #|         conn.socketReadEnded = true;
  #|         while (conn.socketReadWaiters.length > 0) {
  #|           conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|         }
  #|         try { conn.socket.destroy(); } catch {}
  #|         return;
  #|       }
  #|       if (!conn.socketReadPaused && conn.socketReadQueueBytes > conn.socketReadHighWatermark) {
  #|         conn.socketReadPaused = true;
  #|         try { conn.socket.pause(); } catch {}
  #|       }
  #|     }
  #|   };
  #|   const onEnd = () => {
  #|     if (conn.socketReadEnded) return;
  #|     conn.socketReadEnded = true;
  #|     while (conn.socketReadWaiters.length > 0) {
  #|       conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|     }
  #|   };
  #|   conn.socketReadOnData = onData;
  #|   conn.socketReadOnEnd = onEnd;
  #|   conn.socket.on('data', onData);
  #|   conn.socket.on('end', onEnd);
  #|   conn.socket.on('close', onEnd);
  #|   conn.socketReadAttached = true;
  #| }

///|
extern "js" fn js_conn_skip_request_body(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn) return;
  #|   conn.requestReadSkipped = true;
  #|   conn.requestReadQueue = [];
  #|   conn.requestReadCarry = null;
  #|   conn.requestReadQueueBytes = 0;
  #|   if (conn.requestReadPaused) {
  #|     conn.requestReadPaused = false;
  #|     try { conn.req.resume(); } catch {}
  #|   }
  #|   while (conn.requestReadWaiters.length > 0) {
  #|     conn.requestReadWaiters.shift()(new Uint8Array(0));
  #|   }
  #| }

///|
extern "js" fn js_conn_read_request(
  conn_id : Int,
  max_len : Int,
) -> @js_async.Promise[Bytes] =
  #| async (connId, maxLen) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed) return new Uint8Array(0);
  #|   const pullChunk = () => {
  #|     let chunk = conn.requestReadCarry;
  #|     if (chunk) {
  #|       conn.requestReadCarry = null;
  #|     } else {
  #|       if (conn.requestReadQueue.length === 0) return null;
  #|       chunk = conn.requestReadQueue.shift();
  #|     }
  #|     conn.requestReadQueueBytes = Math.max(0, conn.requestReadQueueBytes - chunk.length);
  #|     if (
  #|       conn.requestReadPaused &&
  #|       !conn.requestReadEnded &&
  #|       !conn.requestReadSkipped &&
  #|       conn.requestReadQueueBytes <= conn.requestReadLowWatermark
  #|     ) {
  #|       conn.requestReadPaused = false;
  #|       try { conn.req.resume(); } catch {}
  #|     }
  #|     if (!(maxLen > 0) || chunk.length <= maxLen) return chunk;
  #|     const head = chunk.subarray(0, maxLen);
  #|     const tail = chunk.subarray(maxLen);
  #|     if (tail.length > 0) {
  #|       conn.requestReadCarry = tail;
  #|       conn.requestReadQueueBytes += tail.length;
  #|       if (!conn.requestReadPaused && conn.requestReadQueueBytes > conn.requestReadHighWatermark) {
  #|         conn.requestReadPaused = true;
  #|         try { conn.req.pause(); } catch {}
  #|       }
  #|     }
  #|     return head;
  #|   };
  #|   const queued = pullChunk();
  #|   if (queued) return queued;
  #|   if (conn.requestReadEnded || conn.requestReadSkipped) {
  #|     return new Uint8Array(0);
  #|   }
  #|   const chunk = await new Promise((resolve) => {
  #|     conn.requestReadWaiters.push(resolve);
  #|   });
  #|   if (!(maxLen > 0) || chunk.length <= maxLen) return chunk;
  #|   const head = chunk.subarray(0, maxLen);
  #|   const tail = chunk.subarray(maxLen);
  #|   if (tail.length > 0) {
  #|     conn.requestReadCarry = tail;
  #|     conn.requestReadQueueBytes += tail.length;
  #|     if (!conn.requestReadPaused && conn.requestReadQueueBytes > conn.requestReadHighWatermark) {
  #|       conn.requestReadPaused = true;
  #|       try { conn.req.pause(); } catch {}
  #|     }
  #|   }
  #|   return head;
  #| }

///|
extern "js" fn js_conn_read(
  conn_id : Int,
  max_len : Int,
) -> @js_async.Promise[Bytes] =
  #| async (connId, maxLen) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || !conn.passthrough) return new Uint8Array(0);
  #|   const pullChunk = () => {
  #|     let chunk = conn.socketReadCarry;
  #|     if (chunk) {
  #|       conn.socketReadCarry = null;
  #|     } else {
  #|       if (conn.socketReadQueue.length === 0) return null;
  #|       chunk = conn.socketReadQueue.shift();
  #|     }
  #|     conn.socketReadQueueBytes = Math.max(0, conn.socketReadQueueBytes - chunk.length);
  #|     maybeResumeSocketRead(conn);
  #|     if (!(maxLen > 0) || chunk.length <= maxLen) return chunk;
  #|     const head = chunk.subarray(0, maxLen);
  #|     const tail = chunk.subarray(maxLen);
  #|     if (tail.length > 0) {
  #|       conn.socketReadCarry = tail;
  #|       conn.socketReadQueueBytes += tail.length;
  #|       if (conn.socketReadQueueBytes > conn.socketReadMaxQueueBytes) {
  #|         conn.socketReadCarry = null;
  #|         conn.socketReadQueue = [];
  #|         conn.socketReadQueueBytes = 0;
  #|         conn.socketReadEnded = true;
  #|         while (conn.socketReadWaiters.length > 0) {
  #|           conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|         }
  #|         try { conn.socket?.destroy?.(); } catch {}
  #|         return head;
  #|       }
  #|       if (!conn.socketReadPaused && conn.socketReadQueueBytes > conn.socketReadHighWatermark) {
  #|         conn.socketReadPaused = true;
  #|         try { conn.socket?.pause?.(); } catch {}
  #|       }
  #|     }
  #|     return head;
  #|   };
  #|   const queued = pullChunk();
  #|   if (queued) return queued;
  #|   if (conn.socketReadEnded) return new Uint8Array(0);
  #|   const chunk = await new Promise((resolve) => {
  #|     conn.socketReadWaiters.push(resolve);
  #|   });
  #|   if (!(maxLen > 0) || chunk.length <= maxLen) return chunk;
  #|   const head = chunk.subarray(0, maxLen);
  #|   const tail = chunk.subarray(maxLen);
  #|   if (tail.length > 0) {
  #|     conn.socketReadCarry = tail;
  #|     conn.socketReadQueueBytes += tail.length;
  #|     if (conn.socketReadQueueBytes > conn.socketReadMaxQueueBytes) {
  #|       conn.socketReadCarry = null;
  #|       conn.socketReadQueue = [];
  #|       conn.socketReadQueueBytes = 0;
  #|       conn.socketReadEnded = true;
  #|       while (conn.socketReadWaiters.length > 0) {
  #|         conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|       }
  #|       try { conn.socket?.destroy?.(); } catch {}
  #|       return head;
  #|     }
  #|     if (!conn.socketReadPaused && conn.socketReadQueueBytes > conn.socketReadHighWatermark) {
  #|       conn.socketReadPaused = true;
  #|       try { conn.socket?.pause?.(); } catch {}
  #|     }
  #|   }
  #|   return head;
  #| }

///|
fn parse_request_method(meth : String) -> RequestMethod {
  match meth {
    "HEAD" => RequestMethod::Head
    "POST" => RequestMethod::Post
    "PUT" => RequestMethod::Put
    "DELETE" => RequestMethod::Delete
    "CONNECT" => RequestMethod::Connect
    "OPTIONS" => RequestMethod::Options
    "TRACE" => RequestMethod::Trace
    "PATCH" => RequestMethod::Patch
    _ => RequestMethod::Get
  }
}

///|
fn path_from_url(url : String) -> String {
  if url == "" {
    "/"
  } else {
    url
  }
}

///|
fn to_addr(host : String, port : Int) -> Addr {
  let h = if host.contains(":") && !host.has_prefix("[") {
    "[" + host + "]"
  } else {
    host
  }
  Addr::{ text: "\{h}:\{port}", port }
}

///|
pub struct ServerConnection {
  request : Request
  mut request_body_drained : Bool
  conn_id : Int
  peer_addr : Addr
  mut read_carry : Bytes
  mut read_carry_offset : Int
  mut passthrough_mode : Bool
  mut response_started : Bool
  mut response_ended : Bool
  mut closed : Bool
}

///|
fn new_server_connection(
  request : Request,
  conn_id : Int,
  peer_addr : Addr,
) -> ServerConnection {
  ServerConnection::{
    request,
    request_body_drained: false,
    conn_id,
    peer_addr,
    read_carry: Bytes::new(0),
    read_carry_offset: 0,
    passthrough_mode: false,
    response_started: false,
    response_ended: false,
    closed: false,
  }
}

///|
fn read_prefetch_len(max_len : Int) -> Int {
  let min_prefetch = 16 * 1024
  let max_prefetch = 64 * 1024
  if max_len <= 0 {
    min_prefetch
  } else if max_len < min_prefetch {
    min_prefetch
  } else if max_len > max_prefetch {
    max_prefetch
  } else {
    max_len
  }
}

///|
fn ServerConnection::set_read_carry(
  self : ServerConnection,
  data : Bytes,
  offset : Int,
) -> Unit {
  let rest = data.length() - offset
  if rest <= 0 {
    self.read_carry = Bytes::new(0)
    self.read_carry_offset = 0
    return
  }
  self.read_carry = data
  self.read_carry_offset = offset
}

///|
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  if self.closed {
    return
  }
  self.read_carry = Bytes::new(0)
  self.read_carry_offset = 0
  js_conn_close(self.conn_id)
  self.response_ended = true
  self.closed = true
}

///|
pub fn ServerConnection::read_request(self : ServerConnection) -> Request {
  self.request
}

///|
pub fn ServerConnection::client_addr(self : ServerConnection) -> Addr {
  self.peer_addr
}

///|
pub fn ServerConnection::skip_request_body(self : ServerConnection) -> Unit {
  self.read_carry = Bytes::new(0)
  self.read_carry_offset = 0
  js_conn_skip_request_body(self.conn_id)
  self.request_body_drained = true
}

///|
pub fn ServerConnection::send_response(
  self : ServerConnection,
  code : Int,
  reason : String,
  extra_headers? : Map[String, String],
) -> Unit {
  if self.passthrough_mode {
    return
  }
  if self.closed || self.response_ended || self.response_started {
    return
  }
  js_conn_send_response(
    self.conn_id,
    code,
    reason,
    headers_to_json(extra_headers.unwrap_or({})),
  )
  self.response_started = true
}

///|
pub fn ServerConnection::flush(self : ServerConnection) -> Unit {
  if self.passthrough_mode {
    return
  }
  if self.closed || self.response_ended {
    return
  }
  self.response_started = true
  js_conn_flush(self.conn_id)
}

///|
pub fn ServerConnection::end_response(self : ServerConnection) -> Unit {
  if self.passthrough_mode {
    return
  }
  if self.closed || self.response_ended {
    return
  }
  self.response_started = true
  js_conn_end(self.conn_id)
  self.response_ended = true
  self.closed = true
}

///|
pub fn ServerConnection::enter_passthrough_mode(
  self : ServerConnection,
) -> Unit raise HttpError {
  if self.closed {
    raise HttpError::NetworkError("connection closed")
  }
  if self.response_started && !self.response_ended {
    raise HttpError::NetworkError(
      "cannot enter passthrough mode in middle of response",
    )
  }
  js_conn_enter_passthrough(self.conn_id)
  self.passthrough_mode = true
  self.closed = false
  self.response_ended = false
}

///|
pub impl @io.Reader for ServerConnection with _get_internal_buffer(self) {
  ignore(self)
  @io.ReaderBuffer::new()
}

///|
pub impl @io.Reader for ServerConnection with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  if max_len <= 0 {
    return 0
  }
  let carry_len = self.read_carry.length() - self.read_carry_offset
  if carry_len > 0 {
    let n = @cmp.minimum(max_len, carry_len)
    buf.blit_from_bytes(offset, self.read_carry, self.read_carry_offset, n)
    self.read_carry_offset += n
    if self.read_carry_offset >= self.read_carry.length() {
      self.read_carry = Bytes::new(0)
      self.read_carry_offset = 0
    }
    return n
  }
  if self.passthrough_mode {
    if !self.request_body_drained {
      let req_prefetch_len = read_prefetch_len(max_len)
      let req_promise = js_conn_read_request(self.conn_id, req_prefetch_len)
      let req_data = @js_async.Promise::wait(req_promise) catch {
        _ => Bytes::new(0)
      }
      let req_len = req_data.length()
      if req_len > 0 {
        let n = @cmp.minimum(max_len, req_len)
        buf.blit_from_bytes(offset, req_data, 0, n)
        self.set_read_carry(req_data, n)
        return n
      }
      self.request_body_drained = true
    }
    let prefetch_len = read_prefetch_len(max_len)
    let promise = js_conn_read(self.conn_id, prefetch_len)
    let data = @js_async.Promise::wait(promise) catch { _ => return 0 }
    let len = data.length()
    if len <= 0 {
      0
    } else {
      let n = @cmp.minimum(max_len, len)
      buf.blit_from_bytes(offset, data, 0, n)
      self.set_read_carry(data, n)
      n
    }
  } else {
    let req_prefetch_len = read_prefetch_len(max_len)
    let req_promise = js_conn_read_request(self.conn_id, req_prefetch_len)
    let req_data = @js_async.Promise::wait(req_promise) catch {
      _ => Bytes::new(0)
    }
    let req_len = req_data.length()
    if req_len <= 0 {
      0
    } else {
      let n = @cmp.minimum(max_len, req_len)
      buf.blit_from_bytes(offset, req_data, 0, n)
      self.set_read_carry(req_data, n)
      n
    }
  }
}

///|
pub impl @io.Writer for ServerConnection with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  if self.closed || self.response_ended {
    raise HttpError::NetworkError("connection closed")
  }
  if offset >= buf.length() {
    0
  } else {
    let n = @cmp.minimum(len, buf.length() - offset)
    if n <= 0 {
      0
    } else {
      let promise = js_conn_write(self.conn_id, buf, offset, n)
      let wrote = @js_async.Promise::wait(promise) catch {
        _ => raise HttpError::NetworkError("connection closed")
      }
      if wrote <= 0 {
        raise HttpError::NetworkError("connection closed")
      }
      self.response_started = !self.passthrough_mode
      wrote
    }
  }
}

///|
pub struct Server {
  id : Int
  port : Int
  addr : Addr
}

///|
pub async fn Server::new(
  host? : String,
  port? : Int,
  headers? : Map[String, String],
  dual_stack? : Bool,
  reuse_addr? : Bool,
  max_request_body_bytes? : Int,
  request_timeout_ms? : Int,
  keep_alive_timeout_ms? : Int,
  headers_timeout_ms? : Int,
  accept_queue_limit? : Int,
  trust_proxy? : Bool,
) -> Server raise HttpError {
  ignore(dual_stack)
  ignore(reuse_addr)
  let h = host.unwrap_or("127.0.0.1")
  let controller = @js_async.AbortController::new()
  let promise = js_server_new(
    h,
    port.unwrap_or(3000),
    headers_to_json(headers.unwrap_or({})),
    max_request_body_bytes.unwrap_or(0),
    request_timeout_ms.unwrap_or(0),
    keep_alive_timeout_ms.unwrap_or(0),
    headers_timeout_ms.unwrap_or(0),
    accept_queue_limit.unwrap_or(128),
    trust_proxy.unwrap_or(false),
  )
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
  Server::{ id: result.id, port: result.port, addr: to_addr(h, result.port) }
}

///|
pub fn Server::port(self : Server) -> Int {
  self.port
}

///|
pub fn Server::addr(self : Server) -> Addr {
  self.addr
}

///|
pub async fn Server::accept(
  self : Server,
) -> (ServerConnection, Addr) raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_server_accept(self.id)
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
  let request = Request::{
    meth: parse_request_method(result.req_meth),
    path: path_from_url(result.req_url),
    headers: parse_headers_json(result.headers_json),
  }
  let peer_addr = to_addr(result.client_host, result.client_port)
  let conn = new_server_connection(request, result.conn_id, peer_addr)
  (conn, peer_addr)
}

///|
pub async fn Server::run_forever(
  self : Server,
  f : async (Request, &@io.Reader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit raise HttpError {
  fn on_request(
    req_meth : String,
    req_url : String,
    headers_json : String,
    conn_id : Int,
    client_host : String,
    client_port : Int,
  ) -> @js_async.Promise[Unit] {
    @js_async.Promise::from_async(() => {
      let request = Request::{
        meth: parse_request_method(req_meth),
        path: path_from_url(req_url),
        headers: parse_headers_json(headers_json),
      }
      let conn = new_server_connection(
        request,
        conn_id,
        to_addr(client_host, client_port),
      )
      f(request, conn, conn)
      if !conn.response_ended {
        conn.end_response()
      }
    })
  }
  let controller = @js_async.AbortController::new()
  let promise = js_server_run(
    self.id,
    on_request,
    allow_failure.unwrap_or(true),
    max_connections.unwrap_or(0),
  )
  @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub fn Server::close(self : Server) -> Unit {
  js_server_close(self.id)
}

///|
pub async fn Server::close_graceful(
  self : Server,
  timeout_ms? : Int,
) -> Unit raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_server_close_graceful(self.id, timeout_ms.unwrap_or(30000))
  @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
async fn stream_request_internal_js(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, Stream) raise HttpError {
  let hjson = headers_to_json(headers)
  let body_str = body.text() catch { _ => "" }
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_stream(url, meth, hjson, body_str)
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
  let resp = Response::{
    code: result.code,
    reason: result.reason,
    headers: parse_headers_json(result.headers_json),
  }
  (resp, Stream::{ id: result.id })
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  let empty : String = ""
  stream_request_internal_js(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal_js(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal_js(url, "PUT", headers.unwrap_or({}), body)
}

///|
pub async fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_stream_read(self.id)
  let chunk = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
  if chunk.done {
    None
  } else {
    Some(chunk.data)
  }
}

///|
pub async fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  let chunks : Array[Bytes] = []
  let mut total = 0
  for ;; {
    match self.read_some() {
      Some(chunk) => {
        chunks.push(chunk)
        total = total + chunk.length()
      }
      None => break
    }
  }
  if chunks.length() == 1 {
    return chunks[0]
  }
  let flat : Array[Byte] = Array::new(capacity=total)
  for chunk in chunks {
    for i = 0; i < chunk.length(); i = i + 1 {
      flat.push(chunk[i])
    }
  }
  Bytes::makei(flat.length(), fn(i) { flat[i] })
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  js_stream_close(self.id)
}

// Non-streaming API

///|
async fn request_internal_js(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, &@io.Data) raise HttpError {
  let hjson = headers_to_json(headers)
  let body_str = body.text() catch { _ => "" }
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_internal(url, meth, hjson, body_str)
  let result_json = @js_async.Promise::wait(
    promise,
    abort_controller=controller,
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
  parse_response_json(result_json)
}

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  let empty : String = ""
  request_internal_js(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal_js(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal_js(url, "PUT", headers.unwrap_or({}), body)
}

// Native-compatible Client API

///|
priv struct JsClientNewResult {
  id : Int
  error : String
}

///|
priv struct JsClientResponse {
  code : Int
  reason : String
  headers_json : String
}

///|
extern "js" fn js_client_new(
  url : String,
  headers_json : String,
) -> @js_async.Promise[JsClientNewResult] =
  #| async (url, headersJson) => {
  #|   try {
  #|     if (!globalThis.__xhc) {
  #|       const hasHeader = (headers, key) => {
  #|         if (!headers) return false;
  #|         if (headers[key] != null) return true;
  #|         const low = key.toLowerCase();
  #|         const up = key.toUpperCase();
  #|         if (headers[low] != null || headers[up] != null) return true;
  #|         for (const k of Object.keys(headers)) {
  #|           if (k.toLowerCase() === low) return true;
  #|         }
  #|         return false;
  #|       };
  #|       const responseReadHighWatermark = 4 * 1024 * 1024;
  #|       const responseReadLowWatermark = responseReadHighWatermark >> 1;
  #|       const responseReadMaxQueueBytes = 16 * 1024 * 1024;
  #|       const tunnelReadHighWatermark = 1024 * 1024;
  #|       const tunnelReadLowWatermark = tunnelReadHighWatermark >> 1;
  #|       const tunnelReadMaxQueueBytes = 4 * 1024 * 1024;
  #|       const isAbsoluteRequestPath = (path) => {
  #|         if (!path || path.length === 0) return false;
  #|         if (path.startsWith('//')) return true;
  #|         return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(path);
  #|       };
  #|       const toResponseObject = (nodeRes) => {
  #|         const resHeaders = {};
  #|         for (const [k, v] of Object.entries(nodeRes.headers || {})) {
  #|           if (Array.isArray(v)) {
  #|             resHeaders[k] = v.join(', ');
  #|           } else if (typeof v === 'string') {
  #|             resHeaders[k] = v;
  #|           } else if (v != null) {
  #|             resHeaders[k] = String(v);
  #|           }
  #|         }
  #|         return {
  #|           code: Number(nodeRes.statusCode || 0),
  #|           reason: String(nodeRes.statusMessage || ''),
  #|           headers_json: JSON.stringify(resHeaders),
  #|         };
  #|       };
  #|       const clearTunnelWaiters = (client, value) => {
  #|         const waiters = client.tunnelWaiters || [];
  #|         while (waiters.length > 0) {
  #|           waiters.shift().resolve(value);
  #|         }
  #|       };
  #|       const rejectTunnelWaiters = (client, err) => {
  #|         const waiters = client.tunnelWaiters || [];
  #|         while (waiters.length > 0) {
  #|           waiters.shift().reject(err);
  #|         }
  #|       };
  #|       const detachTunnelHandlers = (client) => {
  #|         const socket = client?.tunnelSocket;
  #|         if (!socket) return;
  #|         if (client.tunnelOnData) {
  #|           try { socket.off('data', client.tunnelOnData); } catch {}
  #|         }
  #|         if (client.tunnelOnEnd) {
  #|           try { socket.off('end', client.tunnelOnEnd); } catch {}
  #|         }
  #|         if (client.tunnelOnClose) {
  #|           try { socket.off('close', client.tunnelOnClose); } catch {}
  #|         }
  #|         if (client.tunnelOnError) {
  #|           try { socket.off('error', client.tunnelOnError); } catch {}
  #|         }
  #|         client.tunnelOnData = null;
  #|         client.tunnelOnEnd = null;
  #|         client.tunnelOnClose = null;
  #|         client.tunnelOnError = null;
  #|         client.tunnelAttached = false;
  #|       };
  #|       const resetTunnel = (client, destroySocket) => {
  #|         const socket = client?.tunnelSocket;
  #|         detachTunnelHandlers(client);
  #|         if (socket && destroySocket && !socket.destroyed) {
  #|           try { socket.destroy(); } catch {}
  #|         }
  #|         client.tunnelSocket = null;
  #|         client.tunnelQueue = [];
  #|         client.tunnelQueueBytes = 0;
  #|         client.tunnelReadPaused = false;
  #|         client.tunnelWaiters = [];
  #|         client.tunnelError = null;
  #|         client.tunnelEnded = true;
  #|         client.passthrough = false;
  #|       };
  #|       const maybeResumeTunnel = (client) => {
  #|         if (!client.tunnelReadPaused) return;
  #|         if (client.tunnelEnded) {
  #|           client.tunnelReadPaused = false;
  #|           return;
  #|         }
  #|         if (client.tunnelQueueBytes > client.tunnelReadLowWatermark) return;
  #|         client.tunnelReadPaused = false;
  #|         try { client.tunnelSocket?.resume?.(); } catch {}
  #|       };
  #|       const attachTunnel = (client) => {
  #|         const socket = client?.tunnelSocket;
  #|         if (!socket) return;
  #|         if (client.tunnelAttached) return;
  #|         client.tunnelAttached = true;
  #|         const onData = (chunk) => {
  #|           const src = chunk instanceof Uint8Array
  #|             ? chunk
  #|             : new Uint8Array(chunk.buffer, chunk.byteOffset, chunk.byteLength);
  #|           const copied = new Uint8Array(src.length);
  #|           copied.set(src);
  #|           if (client.tunnelWaiters.length > 0) {
  #|             client.tunnelWaiters.shift().resolve(copied);
  #|           } else {
  #|             client.tunnelQueue.push(copied);
  #|             client.tunnelQueueBytes += copied.length;
  #|             if (client.tunnelQueueBytes > client.tunnelReadMaxQueueBytes) {
  #|               client.tunnelQueue = [];
  #|               client.tunnelQueueBytes = 0;
  #|               client.tunnelEnded = true;
  #|               clearTunnelWaiters(client, new Uint8Array(0));
  #|               try { socket.destroy(); } catch {}
  #|               return;
  #|             }
  #|             if (!client.tunnelReadPaused && client.tunnelQueueBytes > client.tunnelReadHighWatermark) {
  #|               client.tunnelReadPaused = true;
  #|               try { socket.pause(); } catch {}
  #|             }
  #|           }
  #|         };
  #|         const onEnd = () => {
  #|           client.tunnelEnded = true;
  #|           clearTunnelWaiters(client, new Uint8Array(0));
  #|         };
  #|         const onClose = () => {
  #|           client.tunnelEnded = true;
  #|           clearTunnelWaiters(client, new Uint8Array(0));
  #|         };
  #|         const onError = (err) => {
  #|           client.tunnelEnded = true;
  #|           client.tunnelError = err;
  #|           rejectTunnelWaiters(client, err);
  #|         };
  #|         client.tunnelOnData = onData;
  #|         client.tunnelOnEnd = onEnd;
  #|         client.tunnelOnClose = onClose;
  #|         client.tunnelOnError = onError;
  #|         try { socket.resume(); } catch {}
  #|         socket.on('data', onData);
  #|         socket.on('end', onEnd);
  #|         socket.on('close', onClose);
  #|         socket.on('error', onError);
  #|         if (socket.destroyed) {
  #|           client.tunnelEnded = true;
  #|         }
  #|       };
  #|       const setupResponseReader = (client, nodeRes) => {
  #|         const waiters = [];
  #|         client.responseQueue = [];
  #|         client.responseQueueBytes = 0;
  #|         client.responseReadPaused = false;
  #|         client.responseDone = false;
  #|         client.responseError = null;
  #|         client.responseNodeRes = nodeRes;
  #|         client.responseWaiters = waiters;
  #|         const maybeResumeResponse = () => {
  #|           if (!client.responseReadPaused) return;
  #|           if (client.responseDone) {
  #|             client.responseReadPaused = false;
  #|             return;
  #|           }
  #|           if (client.responseQueueBytes > client.responseReadLowWatermark) return;
  #|           client.responseReadPaused = false;
  #|           try { nodeRes.resume(); } catch {}
  #|         };
  #|         const resolveWaitersWithData = () => {
  #|           while (waiters.length > 0 && client.responseQueue.length > 0) {
  #|             const waiter = waiters.shift();
  #|             const chunk = client.responseQueue.shift();
  #|             client.responseQueueBytes = Math.max(0, client.responseQueueBytes - chunk.length);
  #|             maybeResumeResponse();
  #|             waiter.resolve({ done: false, value: chunk });
  #|           }
  #|         };
  #|         const resolveWaitersDone = () => {
  #|           while (waiters.length > 0) {
  #|             const waiter = waiters.shift();
  #|             waiter.resolve({ done: true, value: new Uint8Array(0) });
  #|           }
  #|         };
  #|         const rejectWaiters = (err) => {
  #|           while (waiters.length > 0) {
  #|             const waiter = waiters.shift();
  #|             waiter.reject(err);
  #|           }
  #|         };
  #|         nodeRes.on('data', (chunk) => {
  #|           const src = chunk instanceof Uint8Array
  #|             ? chunk
  #|             : new Uint8Array(chunk.buffer, chunk.byteOffset, chunk.byteLength);
  #|           const copied = new Uint8Array(src.length);
  #|           copied.set(src);
  #|           if (waiters.length > 0) {
  #|             waiters.shift().resolve({ done: false, value: copied });
  #|             return;
  #|           }
  #|           client.responseQueue.push(copied);
  #|           client.responseQueueBytes += copied.length;
  #|           if (client.responseQueueBytes > client.responseReadMaxQueueBytes) {
  #|             client.responseQueue = [];
  #|             client.responseQueueBytes = 0;
  #|             client.responseDone = true;
  #|             client.responseError = new Error('response queue overflow');
  #|             try { nodeRes.destroy(client.responseError); } catch {}
  #|             rejectWaiters(client.responseError);
  #|             return;
  #|           }
  #|           if (!client.responseReadPaused && client.responseQueueBytes > client.responseReadHighWatermark) {
  #|             client.responseReadPaused = true;
  #|             try { nodeRes.pause(); } catch {}
  #|           }
  #|           resolveWaitersWithData();
  #|         });
  #|         nodeRes.on('end', () => {
  #|           client.responseDone = true;
  #|           client.responseReadPaused = false;
  #|           resolveWaitersDone();
  #|         });
  #|         nodeRes.on('error', (err) => {
  #|           client.responseDone = true;
  #|           client.responseReadPaused = false;
  #|           client.responseError = err;
  #|           rejectWaiters(err);
  #|         });
  #|         client.responseReader = {
  #|           read: async () => {
  #|             if (client.responseQueue.length > 0) {
  #|               const queued = client.responseQueue.shift();
  #|               client.responseQueueBytes = Math.max(0, client.responseQueueBytes - queued.length);
  #|               maybeResumeResponse();
  #|               return { done: false, value: queued };
  #|             }
  #|             if (client.responseError) {
  #|               const err = client.responseError;
  #|               client.responseError = null;
  #|               throw err;
  #|             }
  #|             if (client.responseDone) {
  #|               return { done: true, value: new Uint8Array(0) };
  #|             }
  #|             return await new Promise((resolve, reject) => {
  #|               waiters.push({ resolve, reject });
  #|             });
  #|           },
  #|           cancel: async () => {
  #|             client.responseQueue = [];
  #|             client.responseQueueBytes = 0;
  #|             client.responseDone = true;
  #|             client.responseReadPaused = false;
  #|             client.responseError = null;
  #|             client.responseNodeRes = null;
  #|             try { nodeRes.destroy(); } catch {}
  #|             resolveWaitersDone();
  #|           },
  #|         };
  #|         return toResponseObject(nodeRes);
  #|       };
  #|       const flushPendingChunks = async (pending) => {
  #|         const req = pending?.request;
  #|         if (!req) return;
  #|         while (pending.bodyChunks.length > 0) {
  #|           const chunk = pending.bodyChunks.shift();
  #|           if (!chunk || chunk.length <= 0) continue;
  #|           const written = req.write(chunk);
  #|           pending.bodySize = Math.max(0, pending.bodySize - chunk.length);
  #|           if (!written) {
  #|             await new Promise((resolve, reject) => {
  #|               const onDrain = () => {
  #|                 cleanup();
  #|                 resolve();
  #|               };
  #|               const onError = (err) => {
  #|                 cleanup();
  #|                 reject(err);
  #|               };
  #|               const cleanup = () => {
  #|                 try { req.off('drain', onDrain); } catch {}
  #|                 try { req.off('error', onError); } catch {}
  #|               };
  #|               req.once('drain', onDrain);
  #|               req.once('error', onError);
  #|             });
  #|           }
  #|         }
  #|       };
  #|       const startPendingRequest = async (client, pending, withContentLength) => {
  #|         if (pending.started) return;
  #|         const base = new URL(client.baseUrl);
  #|         const method = pending.method || 'GET';
  #|         const isConnect = method === 'CONNECT';
  #|         const rawPath = String(pending.path || '/');
  #|         if (!isConnect && isAbsoluteRequestPath(rawPath)) {
  #|           throw new Error('request path must be relative');
  #|         }
  #|         const target = isConnect
  #|           ? base
  #|           : new URL(rawPath, client.baseUrl);
  #|         const requestPath = isConnect
  #|           ? rawPath
  #|           : ((target.pathname || '/') + (target.search || ''));
  #|         const headers = { ...(client.baseHeaders || {}), ...(pending.headers || {}) };
  #|         if (
  #|           withContentLength &&
  #|           pending.bodySize > 0 &&
  #|           !hasHeader(headers, 'content-length') &&
  #|           !hasHeader(headers, 'transfer-encoding')
  #|         ) {
  #|           headers['content-length'] = String(pending.bodySize);
  #|         }
  #|         let resolveResponse = null;
  #|         let rejectResponse = null;
  #|         pending.responsePromise = new Promise((resolve, reject) => {
  #|           resolveResponse = resolve;
  #|           rejectResponse = reject;
  #|         });
  #|         // Avoid unhandled rejection when caller closes before awaiting end_request.
  #|         pending.responsePromise.catch(() => {});
  #|         pending.resolveResponse = resolveResponse;
  #|         pending.rejectResponse = rejectResponse;
  #|         pending.responseResolved = false;
  #|         const transport =
  #|           target.protocol === 'https:' ? await import('node:https') : await import('node:http');
  #|         const options = {
  #|           protocol: target.protocol,
  #|           hostname: target.hostname,
  #|           port: target.port
  #|             ? Number(target.port)
  #|             : (target.protocol === 'https:' ? 443 : 80),
  #|           method,
  #|           path: requestPath,
  #|           headers,
  #|         };
  #|         const nodeReq = transport.request(options, (nodeRes) => {
  #|           pending.response = nodeRes;
  #|           const response = setupResponseReader(client, nodeRes);
  #|           if (!pending.responseResolved) {
  #|             pending.responseResolved = true;
  #|             pending.resolveResponse(response);
  #|           }
  #|         });
  #|         nodeReq.on('connect', (nodeRes, socket, head) => {
  #|           const copiedHead =
  #|             head && head.length > 0 ? new Uint8Array(head) : new Uint8Array(0);
  #|           pending.connectSocket = socket;
  #|           pending.connectHead = copiedHead;
  #|           if (!pending.responseResolved) {
  #|             pending.responseResolved = true;
  #|             pending.resolveResponse(toResponseObject(nodeRes));
  #|           }
  #|         });
  #|         nodeReq.on('error', (err) => {
  #|           if (!pending.responseResolved && pending.rejectResponse) {
  #|             pending.responseResolved = true;
  #|             pending.rejectResponse(err);
  #|           } else {
  #|             client.responseDone = true;
  #|             client.responseError = err;
  #|             const waiters = client.responseWaiters || [];
  #|             while (waiters.length > 0) {
  #|               waiters.shift().reject(err);
  #|             }
  #|           }
  #|         });
  #|         pending.request = nodeReq;
  #|         pending.started = true;
  #|       };
  #|       globalThis.__xhc = {
  #|         nextId: 1,
  #|         clients: new Map(),
  #|         responseReadHighWatermark,
  #|         responseReadLowWatermark,
  #|         responseReadMaxQueueBytes,
  #|         tunnelReadHighWatermark,
  #|         tunnelReadLowWatermark,
  #|         tunnelReadMaxQueueBytes,
  #|         flushPendingChunks,
  #|         startPendingRequest,
  #|         attachTunnel,
  #|         resetTunnel,
  #|         isAbsoluteRequestPath,
  #|         maybeResumeTunnel,
  #|       };
  #|     }
  #|     const state = globalThis.__xhc;
  #|     const parsed = new URL(url);
  #|     if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
  #|       throw new Error(`unsupported protocol: ${parsed.protocol}`);
  #|     }
  #|     if ((parsed.pathname && parsed.pathname !== '/') || parsed.search || parsed.hash) {
  #|       throw new Error('client url must not include path/query/hash');
  #|     }
  #|     const id = state.nextId++;
  #|     const baseHeaders = JSON.parse(headersJson || '{}');
  #|     state.clients.set(id, {
  #|       baseUrl: parsed.origin,
  #|       baseHeaders,
  #|       pending: null,
  #|       responseReader: null,
  #|       responseNodeRes: null,
  #|       responseQueue: [],
  #|       responseQueueBytes: 0,
  #|       responseReadPaused: false,
  #|       responseReadHighWatermark: state.responseReadHighWatermark,
  #|       responseReadLowWatermark: state.responseReadLowWatermark,
  #|       responseReadMaxQueueBytes: state.responseReadMaxQueueBytes,
  #|       responseDone: true,
  #|       responseError: null,
  #|       responseWaiters: [],
  #|       tunnelSocket: null,
  #|       tunnelQueue: [],
  #|       tunnelQueueBytes: 0,
  #|       tunnelReadPaused: false,
  #|       tunnelReadHighWatermark: state.tunnelReadHighWatermark,
  #|       tunnelReadLowWatermark: state.tunnelReadLowWatermark,
  #|       tunnelReadMaxQueueBytes: state.tunnelReadMaxQueueBytes,
  #|       tunnelWaiters: [],
  #|       tunnelError: null,
  #|       tunnelEnded: true,
  #|       tunnelOnData: null,
  #|       tunnelOnEnd: null,
  #|       tunnelOnClose: null,
  #|       tunnelOnError: null,
  #|       tunnelAttached: false,
  #|       passthrough: false,
  #|       closed: false,
  #|     });
  #|     return { id, error: '' };
  #|   } catch (err) {
  #|     return { id: 0, error: String(err?.message || err || 'invalid url') };
  #|   }
  #| }

///|
extern "js" fn js_client_close(id : Int) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client) return;
  #|   client.closed = true;
  #|   try { state.resetTunnel(client, true); } catch {}
  #|   const pending = client.pending;
  #|   if (pending?.request) {
  #|     try { pending.request.destroy(); } catch {}
  #|   }
  #|   if (!pending?.responseResolved && pending?.rejectResponse) {
  #|     pending.responseResolved = true;
  #|     try { pending.rejectResponse(new Error('client closed')); } catch {}
  #|   }
  #|   client.pending = null;
  #|   client.responseQueue = [];
  #|   client.responseQueueBytes = 0;
  #|   client.responseReadPaused = false;
  #|   client.responseNodeRes = null;
  #|   if (client.responseReader) {
  #|     try { client.responseReader.cancel().catch(() => {}); } catch {}
  #|   }
  #|   client.responseWaiters = [];
  #|   client.responseError = null;
  #|   state.clients.delete(id);
  #| }

///|
extern "js" fn js_client_request_begin(
  id : Int,
  meth : String,
  path : String,
  extra_headers_json : String,
) -> @js_async.Promise[String] =
  #| async (id, meth, path, extraHeadersJson) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) return 'Client not found';
  #|   if (client.passthrough) return 'client is in passthrough mode';
  #|   if (client.tunnelSocket) return 'client has active tunnel socket';
  #|   if (client.pending) return 'request already started';
  #|   if (client.responseReader) {
  #|     try { client.responseReader.cancel().catch(() => {}); } catch {}
  #|   }
  #|   client.responseReader = null;
  #|   client.responseQueue = [];
  #|   client.responseQueueBytes = 0;
  #|   client.responseReadPaused = false;
  #|   client.responseNodeRes = null;
  #|   client.responseDone = true;
  #|   client.responseError = null;
  #|   client.responseWaiters = [];
  #|   const method = String(meth || 'GET').toUpperCase();
  #|   const reqPath = String(path || '/');
  #|   if (method !== 'CONNECT' && state.isAbsoluteRequestPath(reqPath)) {
  #|     return 'request path must be relative';
  #|   }
  #|   let headers = {};
  #|   if (extraHeadersJson && extraHeadersJson.length > 0) {
  #|     try { headers = JSON.parse(extraHeadersJson); } catch {}
  #|   }
  #|   client.pending = {
  #|     method,
  #|     path: reqPath,
  #|     headers,
  #|     bodyChunks: [],
  #|     bodySize: 0,
  #|     started: false,
  #|     ended: false,
  #|     request: null,
  #|     response: null,
  #|     responsePromise: null,
  #|     resolveResponse: null,
  #|     rejectResponse: null,
  #|     responseResolved: false,
  #|     connectSocket: null,
  #|     connectHead: null,
  #|   };
  #|   return '';
  #| }

///|
extern "js" fn js_client_request_append_body(
  id : Int,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Int =
  #| (id, data, offset, len) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) return 0;
  #|   const req = client.pending;
  #|   if (!req || req.ended) return 0;
  #|   const start = Math.max(0, offset | 0);
  #|   const maxLen = Math.max(0, len | 0);
  #|   const end = Math.min(data.length, start + maxLen);
  #|   if (end <= start) return 0;
  #|   const part = data.subarray(start, end);
  #|   const copied = new Uint8Array(part.length);
  #|   copied.set(part);
  #|   req.bodyChunks.push(copied);
  #|   req.bodySize += copied.length;
  #|   return copied.length;
  #| }

///|
extern "js" fn js_client_request_flush(id : Int) -> @js_async.Promise[String] =
  #| async (id) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) return 'Client not found';
  #|   if (client.passthrough) return 'client is in passthrough mode';
  #|   const pending = client.pending;
  #|   if (!pending) return 'no pending request';
  #|   if (pending.ended) return 'request already ended';
  #|   try {
  #|     if (!pending.started && pending.bodySize <= 0) {
  #|       return '';
  #|     }
  #|     if (!pending.started) {
  #|       await state.startPendingRequest(client, pending, false);
  #|     }
  #|     await state.flushPendingChunks(pending);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message || err || 'network error');
  #|   }
  #| }

///|
extern "js" fn js_client_end_request(
  id : Int,
) -> @js_async.Promise[JsClientResponse] =
  #| async (id) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) throw new Error('Client not found');
  #|   if (client.passthrough) throw new Error('client is in passthrough mode');
  #|   const pending = client.pending;
  #|   if (!pending) throw new Error('no pending request');
  #|   if (pending.ended) throw new Error('request already ended');
  #|   try {
  #|     if (!pending.started) {
  #|       await state.startPendingRequest(client, pending, true);
  #|     }
  #|     await state.flushPendingChunks(pending);
  #|     pending.ended = true;
  #|     pending.request.end();
  #|     const response = await pending.responsePromise;
  #|     if (pending.connectSocket) {
  #|       try { state.resetTunnel(client, true); } catch {}
  #|       client.tunnelSocket = pending.connectSocket;
  #|       client.tunnelQueue = [];
  #|       client.tunnelQueueBytes = 0;
  #|       client.tunnelReadPaused = false;
  #|       client.tunnelWaiters = [];
  #|       client.tunnelError = null;
  #|       client.tunnelEnded = pending.connectSocket.destroyed ? true : false;
  #|       client.tunnelAttached = false;
  #|       client.passthrough = false;
  #|       if (pending.connectHead && pending.connectHead.length > 0) {
  #|         client.tunnelQueue.push(pending.connectHead);
  #|         client.tunnelQueueBytes += pending.connectHead.length;
  #|       }
  #|     }
  #|     client.pending = null;
  #|     return response;
  #|   } catch (err) {
  #|     if (pending.request) {
  #|       try { pending.request.destroy(); } catch {}
  #|     }
  #|     client.pending = null;
  #|     throw err;
  #|   }
  #| }

///|
extern "js" fn js_client_read(
  id : Int,
  max_len : Int,
) -> @js_async.Promise[Bytes] =
  #| async (id, maxLen) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) return new Uint8Array(0);
  #|   const limit = Math.max(0, Number(maxLen || 0));
  #|   const pull = () => {
  #|     if (client.responseQueue.length === 0) return null;
  #|     const chunk = client.responseQueue.shift();
  #|     client.responseQueueBytes = Math.max(0, client.responseQueueBytes - chunk.length);
  #|     if (
  #|       client.responseReadPaused &&
  #|       !client.responseDone &&
  #|       client.responseQueueBytes <= client.responseReadLowWatermark
  #|     ) {
  #|       client.responseReadPaused = false;
  #|       try { client.responseNodeRes?.resume?.(); } catch {}
  #|     }
  #|     if (!(limit > 0) || chunk.length <= limit) return chunk;
  #|     const head = chunk.subarray(0, limit);
  #|     const tail = chunk.subarray(limit);
  #|     if (tail.length > 0) {
  #|       client.responseQueue.unshift(tail);
  #|       client.responseQueueBytes += tail.length;
  #|       if (client.responseQueueBytes > client.responseReadMaxQueueBytes) {
  #|         client.responseQueue = [];
  #|         client.responseQueueBytes = 0;
  #|         client.responseDone = true;
  #|         client.responseError = new Error('response queue overflow');
  #|         try { client.responseNodeRes?.destroy?.(client.responseError); } catch {}
  #|         return head;
  #|       }
  #|       if (!client.responseReadPaused && client.responseQueueBytes > client.responseReadHighWatermark) {
  #|         client.responseReadPaused = true;
  #|         try { client.responseNodeRes?.pause?.(); } catch {}
  #|       }
  #|     }
  #|     return head;
  #|   };
  #|   const queued = pull();
  #|   if (queued) return queued;
  #|   if (client.responseDone || !client.responseReader) return new Uint8Array(0);
  #|   const { done, value } = await client.responseReader.read();
  #|   if (done) {
  #|     client.responseDone = true;
  #|     return new Uint8Array(0);
  #|   }
  #|   const chunk = value instanceof Uint8Array ? value : new Uint8Array(value);
  #|   if (!(limit > 0) || chunk.length <= limit) return chunk;
  #|   const head = chunk.subarray(0, limit);
  #|   const tail = chunk.subarray(limit);
  #|   if (tail.length > 0) {
  #|     client.responseQueue.unshift(tail);
  #|     client.responseQueueBytes += tail.length;
  #|     if (client.responseQueueBytes > client.responseReadMaxQueueBytes) {
  #|       client.responseQueue = [];
  #|       client.responseQueueBytes = 0;
  #|       client.responseDone = true;
  #|       client.responseError = new Error('response queue overflow');
  #|       try { client.responseNodeRes?.destroy?.(client.responseError); } catch {}
  #|       return head;
  #|     }
  #|     if (!client.responseReadPaused && client.responseQueueBytes > client.responseReadHighWatermark) {
  #|       client.responseReadPaused = true;
  #|       try { client.responseNodeRes?.pause?.(); } catch {}
  #|     }
  #|   }
  #|   return head;
  #| }

///|
extern "js" fn js_client_skip_response_body(
  id : Int,
) -> @js_async.Promise[Unit] =
  #| async (id) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) return;
  #|   client.responseQueue = [];
  #|   client.responseQueueBytes = 0;
  #|   client.responseReadPaused = false;
  #|   if (client.responseReader) {
  #|     try { await client.responseReader.cancel(); } catch {}
  #|   }
  #|   client.responseReader = null;
  #|   client.responseNodeRes = null;
  #|   client.responseDone = true;
  #|   client.responseError = null;
  #|   client.responseWaiters = [];
  #| }

///|
extern "js" fn js_client_enter_passthrough(
  id : Int,
) -> @js_async.Promise[String] =
  #| async (id) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed) return 'Client not found';
  #|   if (client.pending) return 'request not completed';
  #|   if (!client.tunnelSocket) return 'no tunnel available';
  #|   if (client.responseReader) {
  #|     try { client.responseReader.cancel().catch(() => {}); } catch {}
  #|   }
  #|   client.responseReader = null;
  #|   client.responseQueue = [];
  #|   client.responseQueueBytes = 0;
  #|   client.responseReadPaused = false;
  #|   client.responseNodeRes = null;
  #|   client.responseDone = true;
  #|   client.responseError = null;
  #|   client.responseWaiters = [];
  #|   state.attachTunnel(client);
  #|   client.passthrough = true;
  #|   return '';
  #| }

///|
extern "js" fn js_client_tunnel_read(
  id : Int,
  max_len : Int,
) -> @js_async.Promise[Bytes] =
  #| async (id, maxLen) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed || !client.passthrough) return new Uint8Array(0);
  #|   if (!client.tunnelSocket) return new Uint8Array(0);
  #|   state.attachTunnel(client);
  #|   const limit = Math.max(0, Number(maxLen || 0));
  #|   const pull = () => {
  #|     if (client.tunnelQueue.length === 0) return null;
  #|     const chunk = client.tunnelQueue.shift();
  #|     client.tunnelQueueBytes = Math.max(0, client.tunnelQueueBytes - chunk.length);
  #|     state.maybeResumeTunnel(client);
  #|     if (!(limit > 0) || chunk.length <= limit) return chunk;
  #|     const head = chunk.subarray(0, limit);
  #|     const tail = chunk.subarray(limit);
  #|     if (tail.length > 0) {
  #|       client.tunnelQueue.unshift(tail);
  #|       client.tunnelQueueBytes += tail.length;
  #|       if (client.tunnelQueueBytes > client.tunnelReadMaxQueueBytes) {
  #|         client.tunnelQueue = [];
  #|         client.tunnelQueueBytes = 0;
  #|         client.tunnelEnded = true;
  #|         try { client.tunnelSocket?.destroy?.(); } catch {}
  #|         return head;
  #|       }
  #|       if (!client.tunnelReadPaused && client.tunnelQueueBytes > client.tunnelReadHighWatermark) {
  #|         client.tunnelReadPaused = true;
  #|         try { client.tunnelSocket?.pause?.(); } catch {}
  #|       }
  #|     }
  #|     return head;
  #|   };
  #|   const queued = pull();
  #|   if (queued) return queued;
  #|   if (client.tunnelError) {
  #|     const err = client.tunnelError;
  #|     client.tunnelError = null;
  #|     throw err;
  #|   }
  #|   if (client.tunnelEnded) return new Uint8Array(0);
  #|   const chunk = await new Promise((resolve, reject) => {
  #|     client.tunnelWaiters.push({ resolve, reject });
  #|   });
  #|   if (!chunk || chunk.length <= 0) return new Uint8Array(0);
  #|   if (!(limit > 0) || chunk.length <= limit) return chunk;
  #|   const head = chunk.subarray(0, limit);
  #|   const tail = chunk.subarray(limit);
  #|   if (tail.length > 0) {
  #|     client.tunnelQueue.unshift(tail);
  #|     client.tunnelQueueBytes += tail.length;
  #|     if (client.tunnelQueueBytes > client.tunnelReadMaxQueueBytes) {
  #|       client.tunnelQueue = [];
  #|       client.tunnelQueueBytes = 0;
  #|       client.tunnelEnded = true;
  #|       try { client.tunnelSocket?.destroy?.(); } catch {}
  #|       return head;
  #|     }
  #|     if (!client.tunnelReadPaused && client.tunnelQueueBytes > client.tunnelReadHighWatermark) {
  #|       client.tunnelReadPaused = true;
  #|       try { client.tunnelSocket?.pause?.(); } catch {}
  #|     }
  #|   }
  #|   return head;
  #| }

///|
extern "js" fn js_client_tunnel_write(
  id : Int,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Int =
  #| (id, data, offset, len) => {
  #|   const state = globalThis.__xhc;
  #|   const client = state?.clients.get(id);
  #|   if (!client || client.closed || !client.passthrough) return 0;
  #|   const socket = client.tunnelSocket;
  #|   if (!socket || socket.destroyed) return 0;
  #|   const start = Math.max(0, offset | 0);
  #|   const maxLen = Math.max(0, len | 0);
  #|   const end = Math.min(data.length, start + maxLen);
  #|   if (end <= start) return 0;
  #|   const part = data.subarray(start, end);
  #|   try {
  #|     socket.write(part);
  #|     return part.length;
  #|   } catch {
  #|     return 0;
  #|   }
  #| }

///|
fn request_method_to_string(meth : RequestMethod) -> String {
  match meth {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
pub struct Client {
  id : Int
  mut closed : Bool
  mut passthrough_mode : Bool
}

///|
pub async fn Client::new(
  url : String,
  headers? : Map[String, String],
) -> Client raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_client_new(url, headers_to_json(headers.unwrap_or({})))
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
  if result.error != "" {
    raise HttpError::InvalidUrl(url)
  }
  Client::{ id: result.id, closed: false, passthrough_mode: false }
}

///|
pub fn Client::close(self : Client) -> Unit {
  if self.closed {
    return
  }
  js_client_close(self.id)
  self.closed = true
  self.passthrough_mode = false
}

///|
pub async fn Client::request(
  self : Client,
  meth : RequestMethod,
  path : String,
  extra_headers? : Map[String, String],
) -> Unit raise HttpError {
  if self.closed {
    raise HttpError::NetworkError("client closed")
  }
  if self.passthrough_mode {
    raise HttpError::NetworkError("client is in passthrough mode")
  }
  let controller = @js_async.AbortController::new()
  let promise = js_client_request_begin(
    self.id,
    request_method_to_string(meth),
    path,
    headers_to_json(extra_headers.unwrap_or({})),
  )
  let err = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    e => raise classify_http_error(e.to_string())
  }
  if err != "" {
    raise classify_http_error(err)
  }
}

///|
pub async fn Client::end_request(self : Client) -> Response raise HttpError {
  if self.closed {
    raise HttpError::NetworkError("client closed")
  }
  if self.passthrough_mode {
    raise HttpError::NetworkError("client is in passthrough mode")
  }
  let controller = @js_async.AbortController::new()
  let promise = js_client_end_request(self.id)
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
  Response::{
    code: result.code,
    reason: result.reason,
    headers: parse_headers_json(result.headers_json),
  }
}

///|
pub async fn Client::flush(self : Client) -> Unit raise HttpError {
  if self.closed {
    raise HttpError::NetworkError("client closed")
  }
  if self.passthrough_mode {
    raise HttpError::NetworkError("client is in passthrough mode")
  }
  let controller = @js_async.AbortController::new()
  let promise = js_client_request_flush(self.id)
  let err = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    e => raise classify_http_error(e.to_string())
  }
  if err != "" {
    raise classify_http_error(err)
  }
}

///|
pub async fn Client::skip_response_body(self : Client) -> Unit raise HttpError {
  if self.closed {
    return
  }
  if self.passthrough_mode {
    raise HttpError::NetworkError("client is in passthrough mode")
  }
  let controller = @js_async.AbortController::new()
  let promise = js_client_skip_response_body(self.id)
  @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::enter_passthrough_mode(
  self : Client,
) -> Unit raise HttpError {
  if self.closed {
    raise HttpError::NetworkError("client closed")
  }
  if self.passthrough_mode {
    return
  }
  let controller = @js_async.AbortController::new()
  let promise = js_client_enter_passthrough(self.id)
  let err = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    e => raise classify_http_error(e.to_string())
  }
  if err != "" {
    raise classify_http_error(err)
  }
  self.passthrough_mode = true
}

///|
pub async fn Client::get(
  self : Client,
  path : String,
  extra_headers? : Map[String, String],
  body? : &@io.Data,
) -> Response raise HttpError {
  self.request(Get, path, extra_headers=extra_headers.unwrap_or({}))
  match body {
    Some(data) =>
      ignore(
        self.write(data) catch {
          err => raise classify_http_error(err.to_string())
        },
      )
    None => ()
  }
  self.end_request()
}

///|
pub async fn Client::post(
  self : Client,
  path : String,
  body : &@io.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  self.request(Post, path, extra_headers=extra_headers.unwrap_or({}))
  ignore(
    self.write(body) catch {
      err => raise classify_http_error(err.to_string())
    },
  )
  self.end_request()
}

///|
pub async fn Client::put(
  self : Client,
  path : String,
  body : &@io.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  self.request(Put, path, extra_headers=extra_headers.unwrap_or({}))
  ignore(
    self.write(body) catch {
      err => raise classify_http_error(err.to_string())
    },
  )
  self.end_request()
}

///|
pub impl @io.Reader for Client with _get_internal_buffer(self) {
  ignore(self)
  @io.ReaderBuffer::new()
}

///|
pub impl @io.Reader for Client with _direct_read(self, _buf, offset~, max_len~) {
  if self.closed {
    0
  } else {
    let controller = @js_async.AbortController::new()
    let promise = if self.passthrough_mode {
      js_client_tunnel_read(self.id, max_len)
    } else {
      js_client_read(self.id, max_len)
    }
    let data = @js_async.Promise::wait(promise, abort_controller=controller) catch {
      _ => return 0
    }
    let len = data.length()
    if len <= 0 {
      0
    } else {
      let n = @cmp.minimum(max_len, len)
      _buf.blit_from_bytes(offset, data, 0, n)
      n
    }
  }
}

///|
pub impl @io.Writer for Client with write_once(self, _buf, offset~, len~) {
  if self.closed || offset >= _buf.length() {
    0
  } else {
    let n = @cmp.minimum(len, _buf.length() - offset)
    if n <= 0 {
      0
    } else if self.passthrough_mode {
      js_client_tunnel_write(self.id, _buf, offset, n)
    } else {
      js_client_request_append_body(self.id, _buf, offset, n)
    }
  }
}
