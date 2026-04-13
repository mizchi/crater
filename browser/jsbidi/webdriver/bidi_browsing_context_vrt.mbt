///|
/// BiDi handler for browsingContext.getCssRuleViewportMap
fn BidiProtocol::handle_get_css_rule_viewport_map(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_css_rule_viewport_map(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_get_css_rule_viewport_map(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    _ => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  let _session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(
        request_id,
        "no such frame",
        "Unknown context: " + ctx_id,
      )
      return None
    }
  }
  let viewport_widths : Array[Int] = match params.get("viewportWidths") {
    Some(Array(items)) => {
      let widths : Array[Int] = []
      for item in items {
        match item {
          Number(n, ..) => widths.push(n.to_int())
          _ => ()
        }
      }
      widths
    }
    None => [375, 640, 768, 1024, 1280, 1440]
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "viewportWidths must be an array of numbers",
      )
      return None
    }
  }
  let html = responsive_breakpoint_source_html("live-inline")
  let map = @css.discover_css_rule_viewport_map(html, viewport_widths)
  let rules_json : Array[Json] = []
  for entry in map.rules {
    let item : Map[String, Json] = {}
    item["selector"] = Json::string(entry.selector)
    item["properties"] = string_array_to_json(entry.properties)
    item["mediaCondition"] = Json::string(entry.media_condition)
    let active : Array[Json] = []
    for w in entry.active_at_widths {
      active.push(Json::number(w.to_double()))
    }
    item["activeAtWidths"] = Json::array(active)
    let inactive : Array[Json] = []
    for w in entry.inactive_at_widths {
      inactive.push(Json::number(w.to_double()))
    }
    item["inactiveAtWidths"] = Json::array(inactive)
    rules_json.push(make_object(item))
  }
  let result : Map[String, Json] = {}
  result["rules"] = Json::array(rules_json)
  Some(make_object(result))
}

///|
/// BiDi handler for browsingContext.getRequiredTestViewports
fn BidiProtocol::handle_get_required_test_viewports(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_required_test_viewports(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_get_required_test_viewports(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    _ => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  let _session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(
        request_id,
        "no such frame",
        "Unknown context: " + ctx_id,
      )
      return None
    }
  }
  let html = responsive_breakpoint_source_html("live-inline")
  let result = @css.discover_required_test_viewports(html)
  let viewports_json : Array[Json] = []
  for v in result.viewports {
    let item : Map[String, Json] = {}
    item["width"] = Json::number(v.width.to_double())
    item["reason"] = Json::string(v.reason)
    viewports_json.push(make_object(item))
  }
  let out : Map[String, Json] = {}
  out["viewports"] = Json::array(viewports_json)
  Some(make_object(out))
}

///|
/// BiDi handler for browsingContext.batchRender
fn BidiProtocol::handle_batch_render(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_batch_render(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_batch_render(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    _ => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  let _session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(
        request_id,
        "no such frame",
        "Unknown context: " + ctx_id,
      )
      return None
    }
  }
  let base_html = match params.get("baseHtml") {
    Some(String(html)) => html
    None => responsive_breakpoint_source_html("live-inline")
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "baseHtml must be a string",
      )
      return None
    }
  }
  let viewport_width = match params.get("viewport") {
    Some(Object(vp)) =>
      match vp.get("width") {
        Some(Number(w, ..)) => w
        _ => 1280.0
      }
    _ => 1280.0
  }
  let viewport_height = match params.get("viewport") {
    Some(Object(vp)) =>
      match vp.get("height") {
        Some(Number(h, ..)) => h
        _ => 900.0
      }
    _ => 900.0
  }
  let variants_json = match params.get("variants") {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "variants must be an array",
      )
      return None
    }
  }
  let variants : Array[@vrt.RenderVariant] = []
  for v in variants_json {
    match v {
      Object(obj) => {
        let id = match obj.get("id") {
          Some(String(s)) => s
          _ => ""
        }
        let mutations : Array[@vrt.CssMutation] = []
        match obj.get("mutations") {
          Some(Array(muts)) =>
            for m in muts {
              match m {
                Object(mobj) => {
                  let selector = match mobj.get("selector") {
                    Some(String(s)) => s
                    _ => continue
                  }
                  let property = match mobj.get("property") {
                    Some(String(s)) => s
                    _ => continue
                  }
                  let action = match mobj.get("action") {
                    Some(String("remove")) => @vrt.CssMutationAction::Remove
                    Some(Object(aobj)) =>
                      match aobj.get("override") {
                        Some(String(v)) =>
                          @vrt.CssMutationAction::Override(v)
                        _ => @vrt.CssMutationAction::Remove
                      }
                    _ => @vrt.CssMutationAction::Remove
                  }
                  mutations.push({ selector, property, action, })
                }
                _ => ()
              }
            }
          _ => ()
        }
        variants.push({ id, mutations, })
      }
      _ => ()
    }
  }
  let viewport = @types.Size::new(viewport_width, viewport_height)
  let results = @vrt.render_html_batch_variants(base_html, viewport, variants)
  let results_json : Array[Json] = []
  for r in results {
    let item : Map[String, Json] = {}
    item["id"] = Json::string(r.id)
    item["paintTree"] = @json.parse(r.paint_tree.to_json_string()) catch {
      _ => Json::null()
    }
    results_json.push(make_object(item))
  }
  let out : Map[String, Json] = {}
  out["results"] = Json::array(results_json)
  Some(make_object(out))
}

///|
/// BiDi handler for browsingContext.getComputedStylesWithState
fn BidiProtocol::handle_get_computed_styles_with_state(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_computed_styles_with_state(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_get_computed_styles_with_state(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    _ => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  let _session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(
        request_id,
        "no such frame",
        "Unknown context: " + ctx_id,
      )
      return None
    }
  }
  let selector = match params.get("selector") {
    Some(String(s)) => s
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        "selector must be a string",
      )
      return None
    }
  }
  // Parse forced states
  let mut hover = false
  let mut focus = false
  let mut active = false
  let mut focus_visible = false
  let mut focus_within = false
  match params.get("forcedStates") {
    Some(Array(states)) =>
      for state in states {
        match state {
          String("hover") => hover = true
          String("focus") => focus = true
          String("active") => active = true
          String("focus-visible") => focus_visible = true
          String("focus-within") => focus_within = true
          _ => ()
        }
      }
    _ => ()
  }
  let forced_state_names : Array[String] = []
  if hover { forced_state_names.push("hover") }
  if focus { forced_state_names.push("focus") }
  if active { forced_state_names.push("active") }
  if focus_visible { forced_state_names.push("focus-visible") }
  if focus_within { forced_state_names.push("focus-within") }
  // Parse properties to check
  let properties : Array[String] = []
  match params.get("properties") {
    Some(Array(props)) =>
      for prop in props {
        match prop {
          String(s) => properties.push(s)
          _ => ()
        }
      }
    _ => ()
  }
  let html = responsive_breakpoint_source_html("live-inline")
  let result = @css.discover_computed_styles_with_state_names(
    html, selector, forced_state_names, properties,
  )
  // Build JSON response
  let normal_json : Map[String, Json] = {}
  result.normal.each(fn(prop, val) {
    normal_json.set(prop, Json::string(val))
  })
  let forced_json : Map[String, Json] = {}
  result.forced.each(fn(prop, val) {
    forced_json.set(prop, Json::string(val))
  })
  let diff_json : Array[Json] = []
  for d in result.diff {
    diff_json.push(make_object({
      "property": Json::string(d.property),
      "normal": Json::string(d.normal),
      "forced": Json::string(d.forced),
    }))
  }
  let out : Map[String, Json] = {}
  out["normal"] = make_object(normal_json)
  out["forced"] = make_object(forced_json)
  out["diff"] = Json::array(diff_json)
  Some(make_object(out))
}
