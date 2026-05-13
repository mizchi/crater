///|
/// Validate arguments parameter for callFunction (must be array of serialized values)
fn BidiProtocol::validate_arguments_param(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "arguments") {
    Some(Array(args)) =>
      // Each argument must be a serialized value (object)
      for arg in args {
        match arg {
          Object(arg_map) => {
            if !is_valid_serialized_value_map(arg_map) {
              self.send_error(
                request_id, "invalid argument", "arguments entries must be serialized values",
              )
              return Some(())
            }
            match self.validate_channel_argument_value(request_id, arg_map) {
              Some(_) => return Some(())
              None => ()
            }
            match
              self.validate_serialized_reference_fields(request_id, arg_map) {
              Some(_) => return Some(())
              None => ()
            }
          }
          _ => {
            self.send_error(
              request_id, "invalid argument", "arguments entries must be serialized values",
            )
            return Some(())
          }
        }
      }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "arguments must be an array",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate channel-specific serialized argument fields.
fn BidiProtocol::validate_channel_argument_value(
  self : BidiProtocol,
  request_id : Int,
  arg_map : Map[String, Json],
) -> Unit? {
  match arg_map.get("type") {
    Some(String("channel")) =>
      match arg_map.get("value") {
        Some(Object(channel_val)) =>
          self.validate_channel_argument_options(request_id, channel_val)
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "channel value must be an object",
          )
          Some(())
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "channel type requires value",
          )
          Some(())
        }
      }
    _ => None
  }
}

///|
/// Validate channel argument options.
fn BidiProtocol::validate_channel_argument_options(
  self : BidiProtocol,
  request_id : Int,
  channel_val : Map[String, Json],
) -> Unit? {
  match channel_val.get("channel") {
    Some(String(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "channel.channel must be a string",
      )
      return Some(())
    }
    None => () // May be omitted
  }
  match channel_val.get("ownership") {
    Some(String(s)) =>
      if s != "root" && s != "none" {
        self.send_error(
          request_id, "invalid argument", "channel.ownership must be 'root' or 'none'",
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "channel.ownership must be a string",
      )
      return Some(())
    }
    None => ()
  }
  match channel_val.get("serializationOptions") {
    Some(Object(ser_opts)) =>
      match
        self.validate_serialization_options_map(
          request_id,
          canonicalize_serialization_options_map(ser_opts),
        ) {
        Some(_) => return Some(())
        None => ()
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serializationOptions must be an object",
      )
      return Some(())
    }
    None => ()
  }
  None
}
