///|
/// HTTP Response structure
pub(all) struct HttpResponse {
  status : Int
  headers : Map[String, String]
  body : String
}

///|
/// HTTP Error types
pub suberror HttpError {
  NetworkError(String)
  InvalidUrl(String)
  TimeoutError
}

///|
pub impl Show for HttpError with output(self, logger) {
  match self {
    NetworkError(msg) => logger.write_string("NetworkError: " + msg)
    InvalidUrl(url) => logger.write_string("InvalidUrl: " + url)
    TimeoutError => logger.write_string("TimeoutError")
  }
}

///|
/// Fetch options
pub(all) struct FetchOptions {
  http_method : String
  headers : Map[String, String]
  timeout_ms : Int
}

///|
pub fn FetchOptions::default() -> FetchOptions {
  { http_method: "GET", headers: {}, timeout_ms: 30000 }
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
