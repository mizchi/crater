///|
fn extract_host_url(url : String) -> String {
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    url
  } else {
    url[:path_start].to_string()
  }
}

///|
fn extract_path_from_url(url : String) -> String {
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    "/"
  } else {
    url[path_start:].to_string()
  }
}

///|
fn to_response(resp : @async_http.Response) -> Response {
  let headers : Map[String, String] = {}
  for k, v in resp.headers {
    headers[k.to_lower()] = v
  }
  Response::{ code: resp.code, reason: resp.reason, headers }
}

///|
fn from_request_method(meth : RequestMethod) -> @async_http.RequestMethod {
  match meth {
    Get => @async_http.RequestMethod::Get
    Head => @async_http.RequestMethod::Head
    Post => @async_http.RequestMethod::Post
    Put => @async_http.RequestMethod::Put
    Delete => @async_http.RequestMethod::Delete
    Connect => @async_http.RequestMethod::Connect
    Options => @async_http.RequestMethod::Options
    Trace => @async_http.RequestMethod::Trace
    Patch => @async_http.RequestMethod::Patch
  }
}

///|
pub struct Client {
  inner : @async_http.Client
}

///|
pub async fn Client::new(
  url : String,
  headers? : Map[String, String],
) -> Client raise HttpError {
  let client = @async_http.Client::new(url, headers=headers.unwrap_or({})) catch {
    _ => raise HttpError::InvalidUrl(url)
  }
  Client::{ inner: client }
}

///|
pub fn Client::close(self : Client) -> Unit {
  self.inner.close()
}

///|
pub async fn Client::request(
  self : Client,
  meth : RequestMethod,
  path : String,
  extra_headers? : Map[String, String],
) -> Unit raise HttpError {
  self.inner.request(
    from_request_method(meth),
    path,
    extra_headers=extra_headers.unwrap_or({}),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::end_request(self : Client) -> Response raise HttpError {
  let response = self.inner.end_request() catch {
    err => raise classify_http_error(err.to_string())
  }
  to_response(response)
}

///|
pub async fn Client::flush(self : Client) -> Unit raise HttpError {
  self.inner.flush() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::skip_response_body(self : Client) -> Unit raise HttpError {
  self.inner.skip_response_body() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::enter_passthrough_mode(
  self : Client,
) -> Unit raise HttpError {
  self.inner.enter_passthrough_mode() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::get(
  self : Client,
  path : String,
  extra_headers? : Map[String, String],
  body? : &@io.Data,
) -> Response raise HttpError {
  let response = self.inner.get(
    path,
    extra_headers=extra_headers.unwrap_or({}),
    body?,
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
  to_response(response)
}

///|
pub async fn Client::post(
  self : Client,
  path : String,
  body : &@io.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  let response = self.inner.post(
    path,
    body,
    extra_headers=extra_headers.unwrap_or({}),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
  to_response(response)
}

///|
pub async fn Client::put(
  self : Client,
  path : String,
  body : &@io.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  let response = self.inner.put(
    path,
    body,
    extra_headers=extra_headers.unwrap_or({}),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
  to_response(response)
}

///|
pub impl @io.Reader for Client with _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @io.Reader for Client with _direct_read(self, buf, offset~, max_len~) {
  @io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub impl @io.Writer for Client with write_once(self, buf, offset~, len~) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}

///|
async fn request_internal(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, &@io.Data) raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = @async_http.Client::new(host_url, headers~) catch {
    _ => raise HttpError::InvalidUrl(url)
  }
  let resp = try {
    match meth {
      "POST" => client.post(path, body)
      "PUT" => client.put(path, body)
      _ => client.get(path)
    }
  } catch {
    err => {
      client.close()
      raise classify_http_error(err.to_string())
    }
  }
  let body_data : &@io.Data = @io.Reader::read_all(client) catch {
    err => {
      client.close()
      raise classify_http_error(err.to_string())
    }
  }
  client.close()
  (to_response(resp), body_data)
}

// Streaming API

///|
pub struct Stream {
  inner : @async_http.Client
}

///|
async fn stream_request_internal(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, Stream) raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = @async_http.Client::new(host_url, headers~) catch {
    _ => raise HttpError::InvalidUrl(url)
  }
  let resp = try {
    match meth {
      "POST" => client.post(path, body)
      "PUT" => client.put(path, body)
      _ => client.get(path)
    }
  } catch {
    err => {
      client.close()
      raise classify_http_error(err.to_string())
    }
  }
  (to_response(resp), Stream::{ inner: client })
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  let empty : String = ""
  stream_request_internal(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal(url, "PUT", headers.unwrap_or({}), body)
}

///|
pub async fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  self.inner.read_some() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  let data : &@io.Data = @io.Reader::read_all(self.inner) catch {
    err => raise classify_http_error(err.to_string())
  }
  data.binary()
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  self.inner.close()
}

// Non-streaming API

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  let empty : String = ""
  request_internal(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal(url, "PUT", headers.unwrap_or({}), body)
}

// Server API

///|
pub struct Server {
  inner : @async_http.Server
}

///|
pub struct ServerConnection {
  inner : @async_http.ServerConnection
}

///|
fn to_request_method(meth : @async_http.RequestMethod) -> RequestMethod {
  match meth {
    Get => RequestMethod::Get
    Head => RequestMethod::Head
    Post => RequestMethod::Post
    Put => RequestMethod::Put
    Delete => RequestMethod::Delete
    Connect => RequestMethod::Connect
    Options => RequestMethod::Options
    Trace => RequestMethod::Trace
    Patch => RequestMethod::Patch
  }
}

///|
fn to_request(req : @async_http.Request) -> Request {
  let headers : Map[String, String] = {}
  for k, v in req.headers {
    headers[k.to_lower()] = v
  }
  Request::{ meth: to_request_method(req.meth), path: req.path, headers }
}

///|
fn to_addr(addr : @socket.Addr) -> Addr {
  Addr::{ text: addr.to_string(), port: addr.port() }
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
  ignore(max_request_body_bytes)
  ignore(request_timeout_ms)
  ignore(keep_alive_timeout_ms)
  ignore(headers_timeout_ms)
  ignore(accept_queue_limit)
  ignore(trust_proxy)
  let h = host.unwrap_or("127.0.0.1")
  let p = port.unwrap_or(3000)
  let addr = @socket.Addr::parse("\{h}:\{p}") catch {
    _ => raise HttpError::InvalidUrl("\{h}:\{p}")
  }
  let server = @async_http.Server::new(
    addr,
    dual_stack?,
    reuse_addr?,
    headers=headers.unwrap_or({}),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
  Server::{ inner: server }
}

///|
pub fn Server::port(self : Server) -> Int {
  self.inner.addr.port()
}

///|
pub fn Server::addr(self : Server) -> Addr {
  to_addr(self.inner.addr)
}

///|
pub fn Server::close(self : Server) -> Unit {
  self.inner.close()
}

///|
pub async fn Server::close_graceful(
  self : Server,
  timeout_ms? : Int,
) -> Unit raise HttpError {
  let timeout = timeout_ms.unwrap_or(30000)
  if timeout < 0 {
    raise HttpError::NetworkError("timeout_ms must be >= 0")
  }
  @async.sleep(0) catch {
    err => raise classify_http_error(err.to_string())
  }
  self.close()
}

///|
pub async fn Server::accept(
  self : Server,
) -> (ServerConnection, Addr) raise HttpError {
  let (conn, addr) = self.inner.accept() catch {
    err => raise classify_http_error(err.to_string())
  }
  (ServerConnection::{ inner: conn }, to_addr(addr))
}

///|
pub async fn Server::run_forever(
  self : Server,
  f : async (Request, &@io.Reader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit raise HttpError {
  self.inner.run_forever(
    (req, body, conn) => {
      let wrapped = ServerConnection::{ inner: conn }
      f(to_request(req), body, wrapped)
    },
    allow_failure?,
    max_connections?,
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  self.inner.close()
}

///|
pub fn ServerConnection::client_addr(self : ServerConnection) -> Addr {
  to_addr(self.inner.client_addr())
}

///|
pub async fn ServerConnection::read_request(
  self : ServerConnection,
) -> Request raise HttpError {
  let req = self.inner.read_request() catch {
    err => raise classify_http_error(err.to_string())
  }
  to_request(req)
}

///|
pub async fn ServerConnection::skip_request_body(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.inner.skip_request_body() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::send_response(
  self : ServerConnection,
  code : Int,
  reason : String,
  extra_headers? : Map[String, String],
) -> Unit raise HttpError {
  self.inner.send_response(
    code,
    reason,
    extra_headers=extra_headers.unwrap_or({}),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::flush(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.inner.flush() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::end_response(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.inner.end_response() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::enter_passthrough_mode(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.inner.enter_passthrough_mode() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub impl @io.Reader for ServerConnection with _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @io.Reader for ServerConnection with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  @io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub impl @io.Writer for ServerConnection with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}
