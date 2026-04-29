///|
/// Native HTTP client using moonbitlang/async's @async_http.Client

///|
fn find_path_start(url : String) -> Int? {
  // Skip protocol (http:// or https://)
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  // Find the first slash after the host
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      return Some(i)
    }
  }
  None
}

///|
/// Extract host URL (without path) from full URL
/// e.g., "https://example.com/foo/bar" -> "https://example.com"
fn extract_host_url(url : String) -> String {
  match find_path_start(url) {
    Some(path_start) => url.unsafe_substring(start=0, end=path_start)
    None => url
  }
}

///|
/// Extract path from URL (e.g., "https://example.com/foo/bar" -> "/foo/bar")
fn extract_path_from_url(url : String) -> String {
  match find_path_start(url) {
    Some(path_start) => url.unsafe_substring(start=path_start, end=url.length())
    None => "/" // No path, use root
  }
}

///|
/// Fetch URL using native HTTP client
pub async fn fetch(
  url : String,
  options? : FetchOptions = FetchOptions::default(),
) -> HttpResponse raise HttpError {
  let prepared = prepare_fetch_options(url, options)
  // Extract host URL (without path) and path separately
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  // Create HTTP client with just the host
  let client = @async_http.Client::new(host_url, headers=prepared.headers) catch {
    _ => raise InvalidUrl(url)
  }
  // Perform request based on method
  let response = try {
    match prepared.http_method {
      "GET" => client.get(path)
      "POST" => client.post(path, prepared.body)
      "PUT" => client.put(path, prepared.body)
      _ => client.get(path)
    }
  } catch {
    err => {
      client.close()
      raise NetworkError(err.to_string())
    }
  }
  // Read response body using Reader trait method
  let body_data = @async_io.Reader::read_all(client) catch {
    err => {
      client.close()
      raise NetworkError(err.to_string())
    }
  }
  let body = body_data.text() catch { _ => "" }
  client.close()
  // Convert headers
  let headers : Map[String, String] = {}
  for k, v in response.headers {
    headers[k.to_lower()] = v
  }
  let result = { status: response.code, headers, body }
  enforce_cors_response(url, prepared, result)
}
