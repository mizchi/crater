///|
/// Dispatch log domain (event-only, no commands)
fn BidiProtocol::dispatch_log(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  // Log module has no commands - it's event-driven via log.entryAdded
  self.send_error(
    request.id,
    "unknown command",
    "Unknown log method: " + action,
  )
  Ok(())
}
