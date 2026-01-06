///|
/// CDP Target Domain
///
/// Manages browser contexts, targets, and sessions.
/// Required for Puppeteer compatibility.

///|
/// Target domain handler
pub struct TargetDomain {
  /// All browser contexts
  contexts : Map[String, CdpContext]
  /// Active browser context ID
  mut active_context_id : String?
  /// ID generators
  mut next_context_id : Int
  mut next_target_id : Int
  mut next_session_id : Int
  /// Auto-attach setting
  mut auto_attach : Bool
  /// Discover targets setting
  mut discover_targets : Bool
}

///|
/// Create new Target domain
pub fn TargetDomain::new() -> TargetDomain {
  {
    contexts: {},
    active_context_id: None,
    next_context_id: 1,
    next_target_id: 1,
    next_session_id: 1,
    auto_attach: false,
    discover_targets: false,
  }
}

///|
/// Target info structure (for CDP responses)
pub struct TargetInfo {
  target_id : String
  target_type : String // "page", "browser", etc.
  title : String
  url : String
  attached : Bool
  browser_context_id : String?
} derive(Show)

// =============================================================================
// Browser Context Management
// =============================================================================

///|
/// Target.createBrowserContext
pub fn TargetDomain::create_browser_context(
  self : TargetDomain,
) -> Result[String, CdpError] {
  // Generate context ID
  let id = "BID-" + self.next_context_id.to_string()
  self.next_context_id += 1
  // Create context
  let context = CdpContext::new(id)
  self.contexts[id] = context
  self.active_context_id = Some(id)
  Ok(id)
}

///|
/// Target.disposeBrowserContext
pub fn TargetDomain::dispose_browser_context(
  self : TargetDomain,
  browser_context_id : String,
) -> Result[Unit, CdpError] {
  match self.contexts.get(browser_context_id) {
    Some(_) => {
      self.contexts.remove(browser_context_id)
      if self.active_context_id == Some(browser_context_id) {
        self.active_context_id = None
      }
      Ok(())
    }
    None =>
      Err(
        CdpError::from_code(
          InvalidParams,
          "No browser context with the given id found",
        ),
      )
  }
}

///|
/// Target.getBrowserContexts
pub fn TargetDomain::get_browser_contexts(self : TargetDomain) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.contexts {
    ids.push(id)
  }
  ids
}

///|
/// Get active browser context
pub fn TargetDomain::get_active_context(self : TargetDomain) -> CdpContext? {
  match self.active_context_id {
    Some(id) => self.contexts.get(id)
    None => None
  }
}

///|
/// Get browser context by ID
pub fn TargetDomain::get_context(
  self : TargetDomain,
  id : String,
) -> CdpContext? {
  self.contexts.get(id)
}

// =============================================================================
// Target Management
// =============================================================================

///|
/// Target.createTarget
pub fn TargetDomain::create_target(
  self : TargetDomain,
  url : String,
  browser_context_id : String?,
) -> Result[String, CdpError] {
  // Get or create browser context
  let context_id : String = match browser_context_id {
    Some(id) =>
      match self.contexts.get(id) {
        Some(_) => id
        None =>
          return Err(
            CdpError::from_code(InvalidParams, "Unknown browser context id"),
          )
      }
    None =>
      // Create new context if none specified
      match self.active_context_id {
        Some(id) => id
        None =>
          match self.create_browser_context() {
            Ok(id) => id
            Err(e) => return Err(e)
          }
      }
  }
  // Get context
  let context = self.contexts.get(context_id).unwrap()
  // Check if target already exists
  match context.get_target_id() {
    Some(_) =>
      return Err(CdpError::from_code(InternalError, "Target already exists"))
    None => ()
  }
  // Generate target ID
  let target_id = "TID-" + self.next_target_id.to_string()
  self.next_target_id += 1
  context.set_target_id(target_id)
  // Navigate if URL provided
  if url != "about:blank" {
    let _ = context.navigate(url)

  }
  // Auto-attach if enabled
  if self.auto_attach {
    let session_id = "SID-" + self.next_session_id.to_string()
    self.next_session_id += 1
    context.set_session_id(session_id)
  }
  Ok(target_id)
}

///|
/// Target.closeTarget
pub fn TargetDomain::close_target(
  self : TargetDomain,
  target_id : String,
) -> Result[Unit, CdpError] {
  // Find context with this target
  for _, context in self.contexts {
    match context.get_target_id() {
      Some(tid) if tid == target_id => {
        context.clear_target()
        return Ok(())
      }
      _ => continue
    }
  }
  Err(CdpError::from_code(InvalidParams, "Unknown target id"))
}

///|
/// Target.attachToTarget
pub fn TargetDomain::attach_to_target(
  self : TargetDomain,
  target_id : String,
) -> Result[String, CdpError] {
  // Find context with this target
  for _, context in self.contexts {
    match context.get_target_id() {
      Some(tid) if tid == target_id => {
        // Generate session ID if not already attached
        let session_id = match context.get_session_id() {
          Some(sid) => sid
          None => {
            let sid = "SID-" + self.next_session_id.to_string()
            self.next_session_id += 1
            context.set_session_id(sid)
            sid
          }
        }
        return Ok(session_id)
      }
      _ => continue
    }
  }
  Err(CdpError::from_code(InvalidParams, "Unknown target id"))
}

///|
/// Target.detachFromTarget
pub fn TargetDomain::detach_from_target(
  self : TargetDomain,
  session_id : String?,
  target_id : String?,
) -> Result[Unit, CdpError] {
  // Find context with this session/target
  for _, context in self.contexts {
    let matches = match (session_id, target_id) {
      (Some(sid), _) => context.get_session_id() == Some(sid)
      (_, Some(tid)) => context.get_target_id() == Some(tid)
      _ => false
    }
    if matches {
      context.detach()
      return Ok(())
    }
  }
  Err(CdpError::from_code(InvalidParams, "Unknown session/target id"))
}

///|
/// Target.getTargets
pub fn TargetDomain::get_targets(self : TargetDomain) -> Array[TargetInfo] {
  let targets : Array[TargetInfo] = []
  for _, context in self.contexts {
    match context.get_target_id() {
      Some(target_id) =>
        targets.push({
          target_id,
          target_type: "page",
          title: context.get_title(),
          url: context.get_url(),
          attached: context.is_attached(),
          browser_context_id: Some(context.get_id()),
        })
      None => ()
    }
  }
  targets
}

///|
/// Target.getTargetInfo
pub fn TargetDomain::get_target_info(
  self : TargetDomain,
  target_id : String?,
) -> Result[TargetInfo, CdpError] {
  match target_id {
    Some(tid) => {
      // Find specific target
      for _, context in self.contexts {
        match context.get_target_id() {
          Some(t) if t == tid =>
            return Ok({
              target_id: tid,
              target_type: "page",
              title: context.get_title(),
              url: context.get_url(),
              attached: context.is_attached(),
              browser_context_id: Some(context.get_id()),
            })
          _ => continue
        }
      }
      Err(CdpError::from_code(InvalidParams, "Unknown target id"))
    }
    None =>
      // Return browser target info
      Ok({
        target_id: "TID-BROWSER",
        target_type: "browser",
        title: "about:blank",
        url: "about:blank",
        attached: true,
        browser_context_id: None,
      })
  }
}

// =============================================================================
// Settings
// =============================================================================

///|
/// Target.setAutoAttach
pub fn TargetDomain::set_auto_attach(
  self : TargetDomain,
  auto_attach : Bool,
  _wait_for_debugger_on_start : Bool,
) -> Unit {
  self.auto_attach = auto_attach
}

///|
/// Target.setDiscoverTargets
pub fn TargetDomain::set_discover_targets(
  self : TargetDomain,
  discover : Bool,
) -> Unit {
  self.discover_targets = discover
}

///|
/// Check if auto-attach is enabled
pub fn TargetDomain::is_auto_attach(self : TargetDomain) -> Bool {
  self.auto_attach
}
