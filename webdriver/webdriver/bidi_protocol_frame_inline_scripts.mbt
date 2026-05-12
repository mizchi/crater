///|
/// Execute inline script tags in the context runtime.
fn BidiProtocol::execute_inline_scripts_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let scripts = self.collect_script_texts(ctx_id)
  if scripts.length() == 0 {
    return
  }
  let capture_console = self.should_capture_console(ctx_id)
  for script_source in scripts {
    if script_source.trim() == "" {
      continue
    }
    set_runtime_context(ctx_id)
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
    let eval_result_json = evaluate_js_with_console(
      script_source, capture_console, false, false, "{}",
    )
    let eval_result = @json.parse(eval_result_json) catch { _ => continue }
    let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
    if capture_console {
      self.process_console_entries(eval_result, ctx_id, realm_id)
    }
    match get_string_field(eval_result, "type") {
      Some("exception") => {
        let exception_details = get_field(eval_result, "exceptionDetails").unwrap_or(
          make_object({}),
        )
        let text = get_string_field(exception_details, "text").unwrap_or(
          "Error: script execution failed",
        )
        let stack_trace = match get_field(exception_details, "stackTrace") {
          Some(Object(_)) => get_field(exception_details, "stackTrace")
          _ => None
        }
        self.emit_javascript_log_entry(
          ctx_id,
          realm_id,
          "error",
          text,
          input_now_ms(),
          stack_trace,
        )
      }
      _ => ()
    }
    self.process_channel_messages(ctx_id, realm_id)
  }
}
