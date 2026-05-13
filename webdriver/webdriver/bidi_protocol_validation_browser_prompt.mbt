///|
/// Normalize unhandledPromptBehavior string handler.
fn normalize_unhandled_prompt_handler_name(raw_handler : String) -> String? {
  match raw_handler {
    "accept" => Some("accept")
    "accept and notify" => Some("accept")
    "dismiss" => Some("dismiss")
    "dismiss and notify" => Some("dismiss")
    "ignore" => Some("ignore")
    _ => None
  }
}

///|
/// Validate unhandledPromptBehavior object.
fn BidiProtocol::validate_browser_unhandled_prompt_behavior(
  self : BidiProtocol,
  request_id : Int,
  behavior : Map[String, Json],
) -> Unit? {
  for key, raw_value in behavior {
    if key != "alert" &&
      key != "beforeUnload" &&
      key != "confirm" &&
      key != "default" &&
      key != "file" &&
      key != "prompt" {
      self.send_error(
        request_id,
        "invalid argument",
        "unhandledPromptBehavior key is invalid: " + key,
      )
      return Some(())
    }

    match raw_value {
      String(handler) =>
        if handler != "accept" && handler != "dismiss" && handler != "ignore" {
          self.send_error(
            request_id, "invalid argument", "unhandledPromptBehavior handler is invalid",
          )
          return Some(())
        }
      _ => {
        self.send_error(
          request_id, "invalid argument", "unhandledPromptBehavior handler must be a string",
        )
        return Some(())
      }
    }
  }
  None
}
