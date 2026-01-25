///|
/// HTTP Response structure
pub(all) struct HttpResponse {
  status : Int
  headers : Map[String, String]
  body : String
}

///|
/// HTTP Error types
#warnings("-unused_constructor")
pub suberror HttpError {
  NetworkError(String)
  InvalidUrl(String)
  TimeoutError
  CorsError(String)
  SandboxError(String)
}

///|
pub impl Show for HttpError with output(self, logger) {
  match self {
    NetworkError(msg) => logger.write_string("NetworkError: " + msg)
    InvalidUrl(url) => logger.write_string("InvalidUrl: " + url)
    TimeoutError => logger.write_string("TimeoutError")
    CorsError(msg) => logger.write_string("CorsError: " + msg)
    SandboxError(msg) => logger.write_string("SandboxError: " + msg)
  }
}

///|
/// Request mode (subset of Fetch spec)
pub(all) enum RequestMode {
  Navigate
  SameOrigin
  NoCors
  Cors
} derive(Eq, Show)

///|
/// Credentials mode for CORS checks
pub(all) enum CredentialsMode {
  Omit
  SameOrigin
  Include
} derive(Eq, Show)

///|
/// Request sandbox policy
pub(all) enum RequestSandbox {
  Open
  SameOrigin
  Allowlist(Array[String])
} derive(Show)

///|
/// Fetch options
pub(all) struct FetchOptions {
  http_method : String
  headers : Map[String, String]
  timeout_ms : Int
  mode : RequestMode
  credentials : CredentialsMode
  origin : String
  sandbox : RequestSandbox
}

///|
pub fn FetchOptions::default() -> FetchOptions {
  {
    http_method: "GET",
    headers: {},
    timeout_ms: 30000,
    mode: Cors,
    credentials: Omit,
    origin: "",
    sandbox: Open,
  }
}

///|
/// Convert headers map to JSON string
pub fn headers_to_json(headers : Map[String, String]) -> String {
  let buf = StringBuilder::new()
  buf.write_char('{')
  let mut first = true
  for k, v in headers {
    if not(first) {
      buf.write_char(',')
    }
    first = false
    buf.write_char('"')
    buf.write_string(k)
    buf.write_string("\":\"")
    buf.write_string(v)
    buf.write_char('"')
  }
  buf.write_char('}')
  buf.to_string()
}

///|
/// Extract origin from URL (scheme://host[:port])
fn extract_origin(url : String) -> String {
  match url.find("://") {
    Some(i) => {
      let after_protocol = url[i + 3:].to_string() catch { _ => return url }
      match after_protocol.find("/") {
        Some(j) => url[:i + 3 + j].to_string() catch { _ => url }
        None => url
      }
    }
    None => ""
  }
}

///|
/// Normalize origin or URL into origin string
fn normalize_origin(origin : String) -> String {
  if origin.length() == 0 {
    return ""
  }
  if origin.contains("://") {
    extract_origin(origin)
  } else {
    origin
  }
}

///|
/// Resolve request origin from URL and caller origin
fn resolve_request_origin(url : String, caller_origin : String) -> String {
  if url.contains("://") {
    extract_origin(url)
  } else if url.has_prefix("//") {
    let scheme = if caller_origin.has_prefix("https://") {
      "https:"
    } else if caller_origin.has_prefix("http://") {
      "http:"
    } else {
      ""
    }
    if scheme.length() == 0 {
      ""
    } else {
      extract_origin(scheme + url)
    }
  } else {
    caller_origin
  }
}

///|
fn is_cross_origin(request_origin : String, caller_origin : String) -> Bool {
  if request_origin.length() == 0 || caller_origin.length() == 0 {
    return false
  }
  request_origin != caller_origin
}

///|
fn sandbox_allows(
  sandbox : RequestSandbox,
  request_origin : String,
  caller_origin : String,
) -> Bool {
  match sandbox {
    Open => true
    SameOrigin =>
      if caller_origin.length() == 0 {
        true
      } else {
        request_origin == caller_origin
      }
    Allowlist(list) =>
      if request_origin.length() == 0 {
        true
      } else if request_origin == caller_origin {
        true
      } else {
        list.contains(request_origin)
      }
  }
}

///|
/// Prepare fetch options (sandbox checks + Origin header injection)
fn prepare_fetch_options(
  url : String,
  options : FetchOptions,
) -> FetchOptions raise HttpError {
  let caller_origin = normalize_origin(options.origin)
  let request_origin = resolve_request_origin(url, caller_origin)
  if not(sandbox_allows(options.sandbox, request_origin, caller_origin)) {
    raise SandboxError("Blocked by request sandbox: " + request_origin)
  }
  if options.mode == SameOrigin &&
    is_cross_origin(request_origin, caller_origin) {
    raise CorsError("Blocked by same-origin policy: " + request_origin)
  }
  if (options.mode == Cors || options.mode == SameOrigin) &&
    is_cross_origin(request_origin, caller_origin) {
    if not(options.headers.contains("Origin")) &&
      not(options.headers.contains("origin")) {
      let headers : Map[String, String] = {}
      for k, v in options.headers {
        headers[k] = v
      }
      headers["Origin"] = caller_origin
      { ..options, headers, }
    } else {
      options
    }
  } else {
    options
  }
}

///|
fn get_header(headers : Map[String, String], name : String) -> String? {
  let key = name.to_lower()
  if headers.contains(key) {
    headers.get(key)
  } else if headers.contains(name) {
    headers.get(name)
  } else {
    None
  }
}

///|
/// Enforce CORS based on response headers
fn enforce_cors_response(
  url : String,
  options : FetchOptions,
  response : HttpResponse,
) -> HttpResponse raise HttpError {
  let caller_origin = normalize_origin(options.origin)
  let request_origin = resolve_request_origin(url, caller_origin)
  if options.mode == SameOrigin &&
    is_cross_origin(request_origin, caller_origin) {
    raise CorsError("Blocked by same-origin policy: " + request_origin)
  }
  if options.mode == Cors && is_cross_origin(request_origin, caller_origin) {
    let allow_origin = get_header(
      response.headers,
      "access-control-allow-origin",
    )
    match allow_origin {
      None => raise CorsError("CORS header missing")
      Some(value) => {
        let ok = value == "*" || value == caller_origin
        if not(ok) {
          raise CorsError("CORS origin mismatch: " + value)
        }
        if options.credentials == Include {
          let allow_creds = get_header(
            response.headers,
            "access-control-allow-credentials",
          )
          if value == "*" {
            raise CorsError("CORS credentials disallowed with wildcard")
          }
          match allow_creds {
            Some(v) if v.to_lower() == "true" => ()
            _ => raise CorsError("CORS credentials not allowed")
          }
        }
      }
    }
  }
  response
}
