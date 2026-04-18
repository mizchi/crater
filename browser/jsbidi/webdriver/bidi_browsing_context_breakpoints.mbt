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
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
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
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
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
            request_id, "invalid argument", "mode must be 'live-inline' or 'html-inline'",
          )
          return None
        }
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "mode must be a string")
      return None
    }
  }

  match params.get("axis") {
    None | Some(String("width")) => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "unsupported operation", "getResponsiveBreakpoints currently supports only axis='width'",
      )
      return None
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "axis must be a string")
      return None
    }
  }

  let include_diagnostics = match params.get("includeDiagnostics") {
    None => true
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "includeDiagnostics must be a boolean",
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
fn responsive_breakpoint_source_html_with_shared_node_marker(
  shared_id : String,
) -> String {
  let html_json = evaluate_js(
    serialize_live_document_html_with_target_resolver_expr(
      (
        #|    const sharedId =
      ) +
      Json::string(shared_id).stringify() +
      (
        #|;
        #|    const store = globalThis.__bidiSharedNodeStore;
        #|    return (store && store.get(sharedId)) || null;
      ),
    ),
  )
  extract_string_value_from_evaluate_result(html_json)
}

///|
fn responsive_breakpoint_source_html_with_element_id_marker(
  element_id : String,
) -> String {
  let html_json = evaluate_js(
    serialize_live_document_html_with_target_resolver_expr(
      (
        #|    const elementId =
      ) +
      Json::string(element_id).stringify() +
      (
        #|;
        #|    if (typeof doc.getElementById !== "function") return null;
        #|    return doc.getElementById(elementId);
      ),
    ),
  )
  extract_string_value_from_evaluate_result(html_json)
}

///|
fn serialize_live_document_html_expr() -> String {
  let target_resolver =
    #|    return null;
  serialize_live_document_html_with_target_resolver_expr(target_resolver)
}

///|
fn serialize_live_document_html_with_target_resolver_expr(
  target_resolver_js : String,
) -> String {
  (
    #|(() => {
    #|  const doc = globalThis.document;
    #|  if (!doc) return '';
    #|  const markerAttrName =
  ) +
  Json::string(computed_styles_target_marker_attribute_name()).stringify() +
  (
    #|;
    #|  const markerAttrValue = "1";
    #|  const targetNode = (() => {
  ) +
  target_resolver_js +
  (
    #|  })();
    #|  const voids = new Set(['area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr']);
    #|  const escapeText = (value) => String(value ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    #|  const escapeAttr = (value) => String(value ?? '').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    #|  const appendAttrs = (node, rawAttrs) => {
    #|    const attrs = { ...(rawAttrs || {}) };
    #|    if (node && node === targetNode) attrs[markerAttrName] = markerAttrValue;
    #|    let html = '';
    #|    for (const [k, v] of Object.entries(attrs)) html += ' ' + k + '="' + escapeAttr(v) + '"';
    #|    return html;
    #|  };
    #|  const getChildren = (node) => {
    #|    if (!node) return [];
    #|    const shadowRoot = node.shadowRoot;
    #|    if (shadowRoot && Array.isArray(shadowRoot._children)) return shadowRoot._children;
    #|    if (Array.isArray(node._children)) return node._children;
    #|    if (Array.isArray(node.children)) return Array.from(node.children);
    #|    if (Array.isArray(node.childNodes)) return Array.from(node.childNodes);
    #|    return [];
    #|  };
    #|  const serNode = (node) => {
    #|    if (!node) return '';
    #|    if (node.nodeType === 3) return escapeText(node._textContent || node.textContent || '');
    #|    if (node.nodeType === 8) return '<!--' + (node._textContent || '') + '-->';
    #|    if (node.nodeType === 11) {
    #|      let html = '';
    #|      for (const child of getChildren(node)) html += serNode(child);
    #|      return html;
    #|    }
    #|    if (node.nodeType !== 1) return '';
    #|    const tag = (node.tagName || node._tagName || '').toLowerCase();
    #|    let html = '<' + tag;
    #|    html += appendAttrs(node, node._attrs);
    #|    html += '>';
    #|    if (voids.has(tag)) return html;
    #|    for (const child of getChildren(node)) html += serNode(child);
    #|    html += '</' + tag + '>';
    #|    return html;
    #|  };
    #|  let html = '<html';
    #|  const htmlEl = doc.documentElement;
    #|  html += appendAttrs(htmlEl, htmlEl && htmlEl._attrs);
    #|  html += '><head';
    #|  html += appendAttrs(doc.head, doc.head && doc.head._attrs);
    #|  html += '>';
    #|  if (doc.head) for (const child of getChildren(doc.head)) html += serNode(child);
    #|  html += '</head><body';
    #|  html += appendAttrs(doc.body, doc.body && doc.body._attrs);
    #|  html += '>';
    #|  if (doc.body) for (const child of getChildren(doc.body)) html += serNode(child);
    #|  html += '</body></html>';
    #|  return html;
    #|})()
  )
}

///|
fn computed_styles_target_marker_attribute_name() -> String {
  "data-crater-computed-style-target"
}

///|
fn computed_styles_target_marker_selector() -> String {
  "[" + computed_styles_target_marker_attribute_name() + "=\"1\"]"
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
  object["ignoredQueries"] = string_array_to_json(diagnostics.ignored_queries)
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
