///|
/// JSON serialization for WebDriver protocol

///|
/// Serialize WebDriverResponse to JSON string
pub fn WebDriverResponse::to_json(self : WebDriverResponse) -> String {
  match self {
    Success(value) => "{\"value\":" + value.to_json() + "}"
    Error(err) => "{\"value\":" + err.to_json() + "}"
  }
}

///|
/// Serialize WebDriverValue to JSON string
pub fn WebDriverValue::to_json(self : WebDriverValue) -> String {
  match self {
    Null => "null"
    Bool(b) => if b { "true" } else { "false" }
    String(s) => "\"" + escape_json_string(s) + "\""
    Number(n) => n.to_string()
    Array(arr) => {
      let parts : Array[String] = []
      for item in arr {
        parts.push(item.to_json())
      }
      "[" +
      parts.iter().intersperse(",").fold(init="", fn(acc, s) { acc + s }) +
      "]"
    }
    Object(map) => {
      let parts : Array[String] = []
      for k, v in map {
        parts.push("\"" + escape_json_string(k) + "\":" + v.to_json())
      }
      "{" +
      parts.iter().intersperse(",").fold(init="", fn(acc, s) { acc + s }) +
      "}"
    }
    Element(element_id~) =>
      "{\"element-6066-11e4-a52e-4f735466cecf\":\"" +
      escape_json_string(element_id) +
      "\"}"
  }
}

///|
/// Serialize WebDriverError to JSON string
pub fn WebDriverError::to_json(self : WebDriverError) -> String {
  "{\"error\":\"" +
  escape_json_string(self.error.to_string()) +
  "\",\"message\":\"" +
  escape_json_string(self.message) +
  "\",\"stacktrace\":\"" +
  escape_json_string(self.stacktrace) +
  "\"}"
}

///|
/// Serialize Capabilities to JSON string
pub fn Capabilities::to_json(self : Capabilities) -> String {
  let mut json = "{"
  json = json +
    "\"browserName\":\"" +
    escape_json_string(self.browser_name) +
    "\""
  json = json +
    ",\"browserVersion\":\"" +
    escape_json_string(self.browser_version) +
    "\""
  json = json +
    ",\"platformName\":\"" +
    escape_json_string(self.platform_name) +
    "\""
  json = json +
    ",\"acceptInsecureCerts\":" +
    (if self.accept_insecure_certs { "true" } else { "false" })
  json = json +
    ",\"pageLoadStrategy\":\"" +
    self.page_load_strategy.to_json_string() +
    "\""
  json = json + ",\"timeouts\":" + self.timeouts.to_json()
  json = json + "}"
  json
}

///|
/// Serialize Timeouts to JSON string
pub fn Timeouts::to_json(self : Timeouts) -> String {
  "{\"script\":" +
  self.script.to_string() +
  ",\"pageLoad\":" +
  self.page_load.to_string() +
  ",\"implicit\":" +
  self.implicit.to_string() +
  "}"
}

///|
/// Page load strategy to JSON string value
pub fn PageLoadStrategy::to_json_string(self : PageLoadStrategy) -> String {
  match self {
    None => "none"
    Eager => "eager"
    Normal => "normal"
  }
}

///|
/// Serialize Session to JSON string
pub fn Session::to_json(self : Session) -> String {
  "{\"sessionId\":\"" +
  escape_json_string(self.id) +
  "\",\"capabilities\":" +
  self.capabilities.to_json() +
  "}"
}

///|
/// Serialize WindowRect to JSON string
pub fn WindowRect::to_json(self : WindowRect) -> String {
  "{\"x\":" +
  self.x.to_string() +
  ",\"y\":" +
  self.y.to_string() +
  ",\"width\":" +
  self.width.to_string() +
  ",\"height\":" +
  self.height.to_string() +
  "}"
}

///|
/// Serialize ElementRect to JSON string
pub fn ElementRect::to_json(self : ElementRect) -> String {
  "{\"x\":" +
  self.x.to_string() +
  ",\"y\":" +
  self.y.to_string() +
  ",\"width\":" +
  self.width.to_string() +
  ",\"height\":" +
  self.height.to_string() +
  "}"
}

///|
/// Escape string for JSON
fn escape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

// =============================================================================
// Helper constructors
// =============================================================================

///|
/// Create success response with null value
pub fn success_null() -> WebDriverResponse {
  Success(Null)
}

///|
/// Create success response with string value
pub fn success_string(s : String) -> WebDriverResponse {
  Success(String(s))
}

///|
/// Create success response with bool value
pub fn success_bool(b : Bool) -> WebDriverResponse {
  Success(Bool(b))
}

///|
/// Create success response with element reference
pub fn success_element(element_id : String) -> WebDriverResponse {
  Success(Element(element_id~))
}

///|
/// Create success response with object value
pub fn success_object(map : Map[String, WebDriverValue]) -> WebDriverResponse {
  Success(Object(map))
}

///|
/// Create error response
pub fn error_response(code : ErrorCode, message : String) -> WebDriverResponse {
  Error({ error: code, message, stacktrace: "" })
}
