///|
fn extract_string_value_from_evaluate_result(json_str : String) -> String {
  let parsed = try {
    @json.parse(json_str)
  } catch {
    _ => return ""
  }
  match parsed {
    Object(map) =>
      match map.get("result") {
        Some(Object(result_map)) =>
          match result_map.get("value") {
            Some(String(val)) => val
            _ => ""
          }
        _ => ""
      }
    _ => ""
  }
}

///|
/// Test-only actual paint capture for VRT.
fn BidiProtocol::handle_capture_paint_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_capture_paint_data(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_capture_paint_data(
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

  match params.get("origin") {
    None | Some(String("viewport")) => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "unsupported operation", "capturePaintData currently supports only origin='viewport'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport'",
      )
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

  let width = self.resolve_effective_viewport_width(ctx_id)
  let height = self.resolve_effective_viewport_height(ctx_id)
  // Serialize the JS mock DOM to HTML (the MoonBit DomTree is not
  // updated by __loadHTML, so we must read back from JavaScript).
  let serialize_expr =
    #|(() => { const doc = globalThis.document; if (!doc) return ''; const serNode = (n) => { if (!n) return ''; if (n.nodeType === 3) return (n._textContent || n.textContent || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); if (n.nodeType === 8) return '<!--'+(n._textContent||'')+'-->'; if (n.nodeType !== 1) return ''; const tag = (n.tagName || n._tagName || '').toLowerCase(); let h = '<'+tag; const attrs = n._attrs || {}; for (const [k,v] of Object.entries(attrs)) h+=' '+k+'="'+String(v).replace(/&/g,'&amp;').replace(/"/g,'&quot;')+'"'; h+='>'; const voids = new Set(['area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr']); if (voids.has(tag)) return h; const children = n._children || []; for (const c of children) h += serNode(c); h += '</'+tag+'>'; return h; }; const head = doc.head; const body = doc.body; let r = '<html><head>'; if (head) for (const c of (head._children||[])) r += serNode(c); r += '</head><body'; if (body && body._attrs) for (const [k,v] of Object.entries(body._attrs)) r += ' '+k+'="'+v+'"'; r += '>'; if (body) for (const c of (body._children||[])) r += serNode(c); r += '</body></html>'; return r; })()
  let html_json = evaluate_js(serialize_expr)
  let html = extract_string_value_from_evaluate_result(html_json)
  let ctx = @browser_contract.create_render_context(width, height, false)
  let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
  let paint_node = match
    @paint.from_node_and_layout_with_viewport(
      node,
      layout,
      0.0,
      height.to_double(),
      0.0,
    ) {
    Some(node) => node
    None => {
      self.send_error(
        request_id, "unknown error", "Failed to build paint tree for current context",
      )
      return None
    }
  }
  let fb = @sixel.Framebuffer::new(width, height)
  let palette = @sixel.DynamicPalette::new()
  @sixel.render_paint_node_to_framebuffer(paint_node, fb, palette)
  Some(
    make_object({
      "width": Json::number(width.to_double()),
      "height": Json::number(height.to_double()),
      "data": Json::string(@sixel.framebuffer_to_rgba_base64(fb, palette)),
    }),
  )
}
