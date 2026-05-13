///|
/// Handle network.setExtraHeaders
fn BidiProtocol::handle_network_set_extra_headers(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.validate_network_set_extra_headers_params(request_id, params) {
    Some(options) => {
      self.apply_network_extra_headers_options(options)
      self.send_success(request_id, Some(make_object({})))
    }
    None => ()
  }
}
