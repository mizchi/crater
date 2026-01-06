///|
/// CDP Target Domain Tests
///
/// Tests for Target domain operations.

///|
test "Target.createBrowserContext creates new context" {
  let target = TargetDomain::new()
  let result = target.create_browser_context()
  inspect(result is Ok(_), content="true")
  let context_id = result.unwrap()
  inspect(context_id.has_prefix("BID-"), content="true")
  // Context should be retrievable
  let ctx = target.get_context(context_id)
  inspect(ctx is Some(_), content="true")
}

///|
test "Target.getBrowserContexts returns all contexts" {
  let target = TargetDomain::new()
  // Initially empty
  let contexts = target.get_browser_contexts()
  inspect(contexts.length(), content="0")
  // Create one
  let _ = target.create_browser_context()
  let contexts2 = target.get_browser_contexts()
  inspect(contexts2.length(), content="1")
  // Create another
  let _ = target.create_browser_context()
  let contexts3 = target.get_browser_contexts()
  inspect(contexts3.length(), content="2")
}

///|
test "Target.disposeBrowserContext removes context" {
  let target = TargetDomain::new()
  let result = target.create_browser_context()
  let context_id = result.unwrap()
  // Dispose
  let dispose_result = target.dispose_browser_context(context_id)
  inspect(dispose_result is Ok(_), content="true")
  // Should no longer exist
  let ctx = target.get_context(context_id)
  inspect(ctx is None, content="true")
}

///|
test "Target.disposeBrowserContext fails for unknown context" {
  let target = TargetDomain::new()
  let result = target.dispose_browser_context("unknown-id")
  inspect(result is Err(_), content="true")
}

///|
test "Target.createTarget creates target in context" {
  let target = TargetDomain::new()
  let result = target.create_target("about:blank", None)
  inspect(result is Ok(_), content="true")
  let target_id = result.unwrap()
  inspect(target_id.has_prefix("TID-"), content="true")
}

///|
test "Target.createTarget with explicit context" {
  let target = TargetDomain::new()
  // Create context first
  let ctx_result = target.create_browser_context()
  let context_id = ctx_result.unwrap()
  // Create target in that context
  let result = target.create_target("about:blank", Some(context_id))
  inspect(result is Ok(_), content="true")
}

///|
test "Target.createTarget fails for unknown context" {
  let target = TargetDomain::new()
  let result = target.create_target("about:blank", Some("unknown-context"))
  inspect(result is Err(_), content="true")
}

///|
test "Target.createTarget fails if target already exists" {
  let target = TargetDomain::new()
  // Create first target
  let _ = target.create_target("about:blank", None)
  // Try to create another in same context
  let ctx = target.get_active_context().unwrap()
  let result = target.create_target("about:blank", Some(ctx.get_id()))
  inspect(result is Err(_), content="true")
}

///|
test "Target.closeTarget removes target" {
  let target = TargetDomain::new()
  let create_result = target.create_target("about:blank", None)
  let target_id = create_result.unwrap()
  // Close
  let close_result = target.close_target(target_id)
  inspect(close_result is Ok(_), content="true")
  // Context should still exist but target should be gone
  let ctx = target.get_active_context().unwrap()
  inspect(ctx.get_target_id() is None, content="true")
}

///|
test "Target.closeTarget fails for unknown target" {
  let target = TargetDomain::new()
  let result = target.close_target("unknown-target")
  inspect(result is Err(_), content="true")
}

///|
test "Target.attachToTarget returns session id" {
  let target = TargetDomain::new()
  let create_result = target.create_target("about:blank", None)
  let target_id = create_result.unwrap()
  // Attach
  let attach_result = target.attach_to_target(target_id)
  inspect(attach_result is Ok(_), content="true")
  let session_id = attach_result.unwrap()
  inspect(session_id.has_prefix("SID-"), content="true")
}

///|
test "Target.attachToTarget returns same session if already attached" {
  let target = TargetDomain::new()
  let create_result = target.create_target("about:blank", None)
  let target_id = create_result.unwrap()
  // Attach twice
  let attach1 = target.attach_to_target(target_id)
  let attach2 = target.attach_to_target(target_id)
  inspect(attach1.unwrap() == attach2.unwrap(), content="true")
}

///|
test "Target.detachFromTarget detaches session" {
  let target = TargetDomain::new()
  let create_result = target.create_target("about:blank", None)
  let target_id = create_result.unwrap()
  let attach_result = target.attach_to_target(target_id)
  let session_id = attach_result.unwrap()
  // Detach
  let detach_result = target.detach_from_target(Some(session_id), None)
  inspect(detach_result is Ok(_), content="true")
  // Should no longer be attached
  let ctx = target.get_active_context().unwrap()
  inspect(ctx.is_attached(), content="false")
}

///|
test "Target.getTargets returns all targets" {
  let target = TargetDomain::new()
  // Initially empty
  let targets = target.get_targets()
  inspect(targets.length(), content="0")
  // Create target
  let _ = target.create_target("about:blank", None)
  let targets2 = target.get_targets()
  inspect(targets2.length(), content="1")
}

///|
test "Target.getTargetInfo returns target info" {
  let target = TargetDomain::new()
  let create_result = target.create_target("about:blank", None)
  let target_id = create_result.unwrap()
  // Get info
  let info_result = target.get_target_info(Some(target_id))
  inspect(info_result is Ok(_), content="true")
  let info = info_result.unwrap()
  inspect(info.target_type, content="page")
  inspect(info.url, content="about:blank")
}

///|
test "Target.getTargetInfo returns browser info when no target specified" {
  let target = TargetDomain::new()
  let info_result = target.get_target_info(None)
  inspect(info_result is Ok(_), content="true")
  let info = info_result.unwrap()
  inspect(info.target_type, content="browser")
}

///|
test "Target.setAutoAttach enables auto-attach" {
  let target = TargetDomain::new()
  inspect(target.is_auto_attach(), content="false")
  target.set_auto_attach(true, false)
  inspect(target.is_auto_attach(), content="true")
}

///|
test "Target.createTarget with auto-attach creates session" {
  let target = TargetDomain::new()
  target.set_auto_attach(true, false)
  // Create target - should auto-attach
  let _ = target.create_target("about:blank", None)
  let ctx = target.get_active_context().unwrap()
  inspect(ctx.is_attached(), content="true")
}
