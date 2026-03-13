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

  let session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
      return None
    }
  }

  let width = self.resolve_effective_viewport_width(ctx_id)
  let height = self.resolve_effective_viewport_height(ctx_id)
  let html = @js.serialize_dom_to_html(session.get_tree())
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
