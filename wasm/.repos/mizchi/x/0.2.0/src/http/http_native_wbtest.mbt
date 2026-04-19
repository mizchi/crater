///|
test "extract_host_url - http with path" {
  assert_eq(
    extract_host_url("http://www.example.org/path/to"),
    "http://www.example.org",
  )
}

///|
test "extract_host_url - http without path" {
  assert_eq(
    extract_host_url("http://www.example.org"),
    "http://www.example.org",
  )
}

///|
test "extract_host_url - https with path and query" {
  assert_eq(
    extract_host_url("https://www.example.org/path/to?search=q"),
    "https://www.example.org",
  )
}

///|
test "extract_host_url - with port" {
  assert_eq(
    extract_host_url("http://www.example.org:10042/path"),
    "http://www.example.org:10042",
  )
}

///|
test "extract_host_url - with port no path" {
  assert_eq(
    extract_host_url("http://www.example.org:10042"),
    "http://www.example.org:10042",
  )
}

///|
test "extract_path_from_url - with path" {
  assert_eq(extract_path_from_url("http://www.example.org/path/to"), "/path/to")
}

///|
test "extract_path_from_url - no path" {
  assert_eq(extract_path_from_url("http://www.example.org"), "/")
}

///|
test "extract_path_from_url - root path" {
  assert_eq(extract_path_from_url("http://www.example.org/"), "/")
}

///|
test "extract_path_from_url - with query" {
  assert_eq(
    extract_path_from_url("https://www.example.org/path/to?search=q"),
    "/path/to?search=q",
  )
}

///|
test "extract_path_from_url - with port" {
  assert_eq(extract_path_from_url("http://www.example.org:10042/path"), "/path")
}

///|
test "extract_path_from_url - with port no path" {
  assert_eq(extract_path_from_url("http://www.example.org:10042"), "/")
}
