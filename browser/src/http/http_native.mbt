///|
/// Native HTTP client using moonbitlang/async's @async_http.Client

///|
/// Fetch URL using native HTTP client
pub async fn fetch(
  url : String,
  options? : FetchOptions = FetchOptions::default(),
) -> HttpResponse raise HttpError {
  // Create HTTP client
  let client = @async_http.Client::new(url, headers=options.headers) catch {
    _ => raise InvalidUrl(url)
  }
  // Perform request based on method
  let response = try {
    match options.http_method {
      "GET" => client.get("/")
      "POST" => client.post("/", "")
      "PUT" => client.put("/", "")
      _ => client.get("/")
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
    headers[k] = v
  }
  { status: response.code, headers, body }
}
