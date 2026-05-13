///|
/// Dispatch input domain (partial implementation for automation primitives)
fn BidiProtocol::dispatch_input(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "performActions" =>
      if self.handle_input_perform_actions(request.id, request.params) {
        self.send_success(request.id, Some(make_object({})))
        Ok(())
      } else {
        Ok(())
      }
    "releaseActions" =>
      if self.handle_input_release_actions(request.id, request.params) {
        self.send_success(request.id, Some(make_object({})))
        Ok(())
      } else {
        Ok(())
      }
    "recordSyntheticEvents" => {
      self.handle_input_record_synthetic_events(request.id, request.params)
      Ok(())
    }
    "setFiles" => {
      self.handle_input_set_files(request.id, request.params)
      Ok(())
    }
    "isFileDialogCanceledForTest" => {
      self.handle_input_is_file_dialog_canceled_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown input method: " + action,
      )
      Ok(())
    }
  }
}
