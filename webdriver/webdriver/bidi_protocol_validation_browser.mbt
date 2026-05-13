///|
/// Validate browser.createUserContext parameters.
fn BidiProtocol::validate_browser_create_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match params {
    None => ()
    Some(Object(map)) => {
      match
        get_map_field_with_alias(
          map, "acceptInsecureCerts", "accept_insecure_certs",
        ) {
        Some(True) | Some(False) => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "acceptInsecureCerts must be a boolean",
          )
          return Some(())
        }
        None => ()
      }

      match map.get("proxy") {
        Some(Object(proxy)) =>
          match self.validate_browser_proxy_config(request_id, proxy) {
            Some(_) => return Some(())
            None => ()
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "proxy must be an object",
          )
          return Some(())
        }
        None => ()
      }

      match
        get_map_field_with_alias(
          map, "unhandledPromptBehavior", "unhandled_prompt_behavior",
        ) {
        Some(Object(behavior)) =>
          match
            self.validate_browser_unhandled_prompt_behavior(
              request_id, behavior,
            ) {
            Some(_) => return Some(())
            None => ()
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "unhandledPromptBehavior must be an object",
          )
          return Some(())
        }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  None
}
