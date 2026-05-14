///|
fn js_utf8_byte_length(value : String) -> Int {
  @crater_network.utf8_byte_length(value)
}

///|
fn js_decode_query_component(value : String) -> String {
  @crater_network.decode_query_component(value)
}

///|
priv struct SyntheticNetworkSetCookieEntries {
  headers : Array[Json]
  cookies : Array[StoredCookie]
}
