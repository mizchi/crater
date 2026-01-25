///|
/// Native HTTP client using moonbitlang/async's @async_http.Client

///|
/// Extract host URL (without path) from full URL
/// e.g., "https://example.com/foo/bar" -> "https://example.com"
fn extract_host_url(url : String) -> String {
  // Skip protocol (http:// or https://)
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  // Find the first slash after the host
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    url // No path, return as-is
  } else {
    url[:path_start].to_string() catch {
      _ => url
    }
  }
}

///|
/// Extract path from URL (e.g., "https://example.com/foo/bar" -> "/foo/bar")
fn extract_path_from_url(url : String) -> String {
  // Skip protocol (http:// or https://)
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  // Find the first slash after the host
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    "/" // No path, use root
  } else {
    url[path_start:].to_string() catch {
      _ => "/"
    }
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
      "POST" => client.post(path, "")
      "PUT" => client.put(path, "")
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
