///|
/// Handle browsingContext.print with WPT-focused validation.
fn BidiProtocol::handle_print(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  match self.resolve_print_data(request.id, request.params) {
    Some(data) => {
      let result = make_object({ "data": Json::string(data) })
      self.send_success(request.id, Some(result))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_print_data(request_id, params) {
    Some(data) => self.send_success(request_id, Some(Json::string(data)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }

  let print_options = match @rendering.normalize_print_options(params) {
    Ok(options) => options
    Err(error) => {
      self.send_error(request_id, error.name(), error.message())
      return None
    }
  }
  let synthetic_details = self.resolve_synthetic_print_details(
    ctx_id,
    params,
    print_options.printable_width_cm,
    print_options.printable_height_cm,
  )
  let signature = match synthetic_details.get("signature") {
    Some(String(value)) if value != "" => value
    _ => self.current_context_url(ctx_id)
  }
  let pages = match synthetic_details.get("pages") {
    Some(Array(values)) => values
    _ => []
  }
  let meta = make_object({
    "kind": Json::string("crater.synthetic.print"),
    "orientation": Json::string(print_options.orientation),
    "pageWidthCm": Json::number(print_options.printable_width_cm),
    "pageHeightCm": Json::number(print_options.printable_height_cm),
    "background": Json::boolean(print_options.background),
    "signature": Json::string(signature),
    "pages": Json::array(pages),
  })
  Some(synthetic_print_pdf_from_meta(meta))
}
