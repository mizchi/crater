///|
pub(all) struct Response {
  code : Int
  reason : String
  headers : Map[String, String]
}

///|
pub(all) struct Addr {
  text : String
  port : Int
}

///|
pub(all) enum RequestMethod {
  Get
  Head
  Post
  Put
  Delete
  Connect
  Options
  Trace
  Patch
} derive(Eq, Compare, Hash, @debug.Debug)

///|
pub impl Show for RequestMethod with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub(all) struct Request {
  meth : RequestMethod
  path : String
  headers : Map[String, String]
}

///|
pub suberror HttpError {
  NetworkError(String)
  InvalidUrl(String)
  TimeoutError
  NotSupported
} derive(@debug.Debug)

///|
pub impl Show for HttpError with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
fn classify_http_error(message : String) -> HttpError {
  let lower = message.to_lower()
  if lower.contains("timeout") {
    TimeoutError
  } else if lower.contains("not supported") || lower.contains("unsupported") {
    NotSupported
  } else {
    NetworkError(message)
  }
}

///|
fn headers_to_json(headers : Map[String, String]) -> String {
  let entries : Map[String, Json] = {}
  for k, v in headers {
    entries[k] = Json::string(v)
  }
  Json::object(entries).stringify()
}
