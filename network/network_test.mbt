///|
test "network state defaults" {
  let state = BidiNetworkState::new()
  inspect(state.next_network_intercept_id, content="1")
  inspect(state.next_network_request_id, content="1")
  inspect(state.network_cache_behavior_global, content="default")
  inspect(state.network_intercepts.length(), content="0")
  inspect(state.network_extra_headers_global.length(), content="0")
}

///|
test "network encoding helpers" {
  inspect(utf8_byte_length("abc"), content="3")
  inspect(utf8_byte_length("あ"), content="3")
  inspect(base64_byte_length("YQ=="), content="1")
  inspect(decode_query_component("a+b%20c"), content="a b c")
}
