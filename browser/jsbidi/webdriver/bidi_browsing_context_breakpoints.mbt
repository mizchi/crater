///|
/// Return canonical responsive breakpoints for the current browsing context.
fn BidiProtocol::handle_get_responsive_breakpoints(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_responsive_breakpoints(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_get_responsive_breakpoints(
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
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "context must be a string",
      )
      return None
    }
    None => {
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

  let mode = match params.get("mode") {
    None => "live-inline"
    Some(String(value)) =>
      match value {
        "live-inline" | "html-inline" => value
        _ => {
          self.send_error(
            request_id,
            "invalid argument",
            "mode must be 'live-inline' or 'html-inline'",
          )
          return None
        }
      }
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "mode must be a string",
      )
      return None
    }
  }

  match params.get("axis") {
    None | Some(String("width")) => ()
    Some(String(_)) => {
      self.send_error(
        request_id,
        "unsupported operation",
        "getResponsiveBreakpoints currently supports only axis='width'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "axis must be a string",
      )
      return None
    }
  }

  let include_diagnostics = match params.get("includeDiagnostics") {
    None => true
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "includeDiagnostics must be a boolean",
      )
      return None
    }
  }

  let html = responsive_breakpoint_source_html(mode)
  let discovery = @css.discover_responsive_breakpoints(html)
  let result : Map[String, Json] = {}
  result["breakpoints"] = responsive_breakpoints_to_json(discovery.breakpoints)
  if include_diagnostics {
    result["diagnostics"] = responsive_diagnostics_to_json(
      discovery.diagnostics,
    )
  }
  Some(make_object(result))
}

///|
fn responsive_breakpoint_source_html(mode : String) -> String {
  let html_json = match mode {
    "html-inline" => evaluate_js("globalThis.__lastHTML || ''")
    _ => evaluate_js(serialize_live_document_html_expr())
  }
  extract_string_value_from_evaluate_result(html_json)
}

///|
fn serialize_live_document_html_expr() -> String {
  #|(() => { const doc = globalThis.document; if (!doc) return ''; const serNode = (n) => { if (!n) return ''; if (n.nodeType === 3) return (n._textContent || n.textContent || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); if (n.nodeType === 8) return '<!--'+(n._textContent||'')+'-->'; if (n.nodeType !== 1) return ''; const tag = (n.tagName || n._tagName || '').toLowerCase(); let h = '<'+tag; const attrs = n._attrs || {}; for (const [k,v] of Object.entries(attrs)) h+=' '+k+'="'+String(v).replace(/&/g,'&amp;').replace(/"/g,'&quot;')+'"'; h+='>'; const voids = new Set(['area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr']); if (voids.has(tag)) return h; const children = n._children || []; for (const c of children) h += serNode(c); h += '</'+tag+'>'; return h; }; const head = doc.head; const body = doc.body; let r = '<html'; const htmlEl = doc.documentElement; if (htmlEl && htmlEl._attrs) for (const [k,v] of Object.entries(htmlEl._attrs)) r += ' '+k+'="'+String(v).replace(/&/g,'&amp;').replace(/"/g,'&quot;')+'"'; r += '><head>'; if (head) for (const c of (head._children||[])) r += serNode(c); r += '</head><body'; if (body && body._attrs) for (const [k,v] of Object.entries(body._attrs)) r += ' '+k+'="'+v+'"'; r += '>'; if (body) for (const c of (body._children||[])) r += serNode(c); r += '</body></html>'; return r; })()
}

///|
fn responsive_breakpoints_to_json(
  breakpoints : Array[@css.ResponsiveBreakpoint],
) -> Json {
  let items : Array[Json] = []
  for breakpoint in breakpoints {
    let item : Map[String, Json] = {}
    item["axis"] = Json::string(breakpoint.axis)
    item["op"] = Json::string(breakpoint.op)
    item["valuePx"] = Json::number(breakpoint.value_px.to_double())
    item["raw"] = Json::string(breakpoint.raw)
    item["normalized"] = Json::string(breakpoint.normalized)
    let guards : Array[Json] = []
    for guard_text in breakpoint.guards {
      guards.push(Json::string(guard_text))
    }
    item["guards"] = Json::array(guards)
    item["ruleCount"] = Json::number(breakpoint.rule_count.to_double())
    items.push(make_object(item))
  }
  Json::array(items)
}

///|
fn responsive_diagnostics_to_json(
  diagnostics : @css.BreakpointDiscoveryDiagnostics,
) -> Json {
  let object : Map[String, Json] = {}
  object["stylesheetCount"] = Json::number(
    diagnostics.stylesheet_count.to_double(),
  )
  object["ruleCount"] = Json::number(diagnostics.rule_count.to_double())
  object["externalStylesheetLinks"] = string_array_to_json(
    diagnostics.external_stylesheet_links,
  )
  object["ignoredQueries"] = string_array_to_json(
    diagnostics.ignored_queries,
  )
  object["unsupportedQueries"] = string_array_to_json(
    diagnostics.unsupported_queries,
  )
  make_object(object)
}

///|
fn string_array_to_json(values : Array[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}
