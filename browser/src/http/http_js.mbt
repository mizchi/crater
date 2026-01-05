///|
/// JavaScript fetch() wrapper for JS target

///|
/// Internal: fetch response as JSON string
extern "js" fn js_fetch_internal(
  url : String,
  http_method : String,
  headers_json : String,
  timeout_ms : Int,
) -> @js_async.Promise[String] =
  #| async (url, method, headersJson, timeoutMs) => {
  #|   const headers = JSON.parse(headersJson);
  #|   const controller = new AbortController();
  #|   const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  #|   try {
  #|     const res = await fetch(url, { method, headers, signal: controller.signal });
  #|     clearTimeout(timeoutId);
  #|     const body = await res.text();
  #|     const resHeaders = {};
  #|     res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|     return JSON.stringify({ status: res.status, headers: resHeaders, body });
  #|   } catch (e) {
  #|     clearTimeout(timeoutId);
  #|     if (e.name === 'AbortError') {
  #|       throw new Error('TIMEOUT');
  #|     }
  #|     throw e;
  #|   }
  #| }

///|
/// Parse JSON response into HttpResponse
fn parse_response_json(json : String) -> HttpResponse raise HttpError {
  // Simple JSON parsing for response
  // Format: {"status":200,"headers":{"key":"value"},"body":"..."}
  let status = extract_json_int(json, "status")
  let body = extract_json_string(json, "body")
  let headers : Map[String, String] = {}
  // For simplicity, we skip header parsing in MVP
  { status, headers, body }
}

///|
/// Extract integer value from JSON by key
fn extract_json_int(json : String, key : String) -> Int {
  let pattern = "\"" + key + "\":"
  match json.find(pattern) {
    Some(idx) => {
      let start = idx + pattern.length()
      let mut end = start
      let chars = json.to_array()
      while end < chars.length() && chars[end] >= '0' && chars[end] <= '9' {
        end = end + 1
      }
      try {
        let num_str = json[start:end].to_string()
        @strconv.parse_int(num_str)
      } catch {
        _ => 0
      }
    }
    None => 0
  }
}

///|
/// Extract string value from JSON by key
fn extract_json_string(json : String, key : String) -> String {
  let pattern = "\"" + key + "\":\""
  match json.find(pattern) {
    Some(idx) => {
      let start = idx + pattern.length()
      let mut end = start
      let chars = json.to_array()
      while end < chars.length() {
        if chars[end] == '"' && (end == start || chars[end - 1] != '\\') {
          break
        }
        end = end + 1
      }
      unescape_json_string(json[start:end].to_string()) catch {
        _ => ""
      }
    }
    None => ""
  }
}

///|
/// Unescape JSON string
fn unescape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      match chars[i + 1] {
        'n' => buf.write_char('\n')
        'r' => buf.write_char('\r')
        't' => buf.write_char('\t')
        '"' => buf.write_char('"')
        '\\' => buf.write_char('\\')
        c => {
          buf.write_char('\\')
          buf.write_char(c)
        }
      }
      i = i + 2
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
/// Fetch URL using JavaScript fetch() API
pub async fn fetch(
  url : String,
  options? : FetchOptions = FetchOptions::default(),
) -> HttpResponse raise HttpError {
  let headers_json = headers_to_json(options.headers)
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_internal(
    url,
    options.http_method,
    headers_json,
    options.timeout_ms,
  )
  let result_json = @js_async.Promise::wait(
    promise,
    abort_controller=controller,
  ) catch {
    err => {
      let msg = err.to_string()
      if msg.contains("TIMEOUT") {
        raise TimeoutError
      }
      raise NetworkError(msg)
    }
  }
  parse_response_json(result_json)
}
