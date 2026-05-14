///|
fn synthetic_network_header_entries_from_object(
  raw_headers : Map[String, Json],
) -> Array[Json] {
  @crater_network.synthetic_network_header_entries_from_object(raw_headers)
}

///|
fn synthetic_network_merge_header_entries(headers : Array[Json]) -> Array[Json] {
  @crater_network.synthetic_network_merge_header_entries(headers)
}

///|
fn synthetic_network_header_entry_name(header : Json) -> String? {
  @crater_network.synthetic_network_header_entry_name(header)
}

///|
fn synthetic_network_header_entry_string_value(header : Json) -> String? {
  @crater_network.synthetic_network_header_entry_string_value(header)
}

///|
fn synthetic_network_is_valid_continue_url(url : String) -> Bool {
  @crater_network.synthetic_network_is_valid_continue_url(url)
}

///|
fn synthetic_network_cache_key(http_method : String, url : String) -> String {
  @crater_network.synthetic_network_cache_key(http_method, url)
}

///|
fn synthetic_network_request_path(url : String) -> String {
  @crater_network.synthetic_network_request_path(url)
}

///|
fn synthetic_network_first_query_value(url : String, key : String) -> String? {
  @crater_network.synthetic_network_first_query_value(url, key)
}

///|
fn synthetic_network_query_values(url : String, key : String) -> Array[String] {
  @crater_network.synthetic_network_query_values(url, key)
}

///|
fn synthetic_network_int_query_param(
  url : String,
  key : String,
  default_value : Int,
) -> Int {
  @crater_network.synthetic_network_int_query_param(url, key, default_value)
}

///|
fn synthetic_network_request_header_string_value(
  headers : Array[Json],
  name : String,
) -> String? {
  @crater_network.synthetic_network_request_header_string_value(headers, name)
}

///|
fn synthetic_network_header_string_entry(name : String, value : String) -> Json {
  @crater_network.synthetic_network_header_string_entry(name, value)
}

///|
fn synthetic_network_infer_mime_type(url : String, path : String) -> String {
  @crater_network.synthetic_network_infer_mime_type(url, path)
}

///|
fn synthetic_network_status_text_for_code(status : Int) -> String {
  @crater_network.synthetic_network_status_text_for_code(status)
}
