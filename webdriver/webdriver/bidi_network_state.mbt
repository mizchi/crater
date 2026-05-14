///|
fn BidiProtocol::handle_network_allocate_request_id(
  self : BidiProtocol,
  request_id : Int,
  _params : Json?,
) -> Unit {
  self.send_success(
    request_id,
    Some(
      make_object({
        "request": Json::string(self.next_synthetic_network_request_id()),
      }),
    ),
  )
}

///|
fn BidiProtocol::next_synthetic_network_request_id(
  self : BidiProtocol,
) -> String {
  let request_id = "request-" +
    self.network_state.next_network_request_id.to_string()
  self.network_state.next_network_request_id += 1
  request_id
}
