///|
/// Validate awaitPromise parameter (must be boolean)
fn BidiProtocol::validate_await_promise(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw_with_alias(params, "awaitPromise", "await_promise") {
    Some(True) | Some(False) => ()
    None => () // Optional, defaults to false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "awaitPromise must be a boolean",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate resultOwnership parameter (must be "root" or "none")
fn BidiProtocol::validate_result_ownership(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match
    get_param_raw_with_alias(params, "resultOwnership", "result_ownership") {
    Some(String(s)) =>
      if s != "root" && s != "none" {
        self.send_error(
          request_id, "invalid argument", "resultOwnership must be 'root' or 'none'",
        )
        return Some(())
      }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "resultOwnership must be a string",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate serializationOptions parameter
fn BidiProtocol::validate_serialization_options(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match
    get_param_raw_with_alias(
      params, "serializationOptions", "serialization_options",
    ) {
    Some(Object(opts)) =>
      return self.validate_serialization_options_map(
        request_id,
        canonicalize_serialization_options_map(opts),
      )
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serializationOptions must be an object",
      )
      return Some(())
    }
  }
  None
}

///|
fn BidiProtocol::validate_serialization_options_map(
  self : BidiProtocol,
  request_id : Int,
  opts : Map[String, Json],
) -> Unit? {
  match opts.get("maxDomDepth") {
    Some(Number(n, ..)) =>
      if n < 0.0 || n != n.to_int64().to_double() {
        self.send_error(
          request_id, "invalid argument", "maxDomDepth must be a non-negative integer",
        )
        return Some(())
      }
    Some(Null) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "maxDomDepth must be a non-negative integer",
      )
      return Some(())
    }
    None => ()
  }
  match opts.get("maxObjectDepth") {
    Some(Number(n, ..)) =>
      if n < 0.0 || n != n.to_int64().to_double() {
        self.send_error(
          request_id, "invalid argument", "maxObjectDepth must be a non-negative integer",
        )
        return Some(())
      }
    Some(Null) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "maxObjectDepth must be a non-negative integer",
      )
      return Some(())
    }
    None => ()
  }
  match opts.get("includeShadowTree") {
    Some(String(s)) =>
      if s != "none" && s != "open" && s != "all" {
        self.send_error(
          request_id, "invalid argument", "includeShadowTree must be 'none', 'open', or 'all'",
        )
        return Some(())
      }
    Some(Null) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "includeShadowTree must be a string",
      )
      return Some(())
    }
    None => ()
  }
  None
}

///|
/// Validate userActivation parameter (must be boolean)
fn BidiProtocol::validate_user_activation(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw_with_alias(params, "userActivation", "user_activation") {
    Some(True) | Some(False) => ()
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userActivation must be a boolean",
      )
      return Some(())
    }
  }
  None
}

///|
/// Extract userActivation parameter with default false.
fn get_user_activation_value(params : Json?) -> Bool {
  match get_param_raw_with_alias(params, "userActivation", "user_activation") {
    Some(True) => true
    _ => false
  }
}
