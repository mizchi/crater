///|
/// browsingContext.diffPaintTree (#23): render two HTML variants and diff their
/// paint trees at the property/layout level, surfacing changes that a pixel
/// diff misses (e.g. a background color removed where the parent has the same
/// color, or a layout-affecting property that shifts boxes). Nodes are matched
/// positionally — the CSS-mutation use case keeps the same DOM structure and
/// only varies CSS.

///|
fn BidiProtocol::render_html_to_paint_node(
  self : BidiProtocol,
  html : String,
  width : Int,
  height : Int,
) -> @paint_model.PaintNode? {
  let _ = self
  let ctx = @browser_helpers.create_render_context(width, height, false)
  let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
  @tui_paint_viewport.from_node_and_layout_with_viewport_rect(
    node,
    layout,
    0.0,
    0.0,
    width.to_double(),
    height.to_double(),
    0.0,
    0.0,
  )
}

///|
fn paint_diff_push_change(
  changes : Array[Json],
  node_id : String,
  property : String,
  before : String,
  after : String,
) -> Unit {
  changes.push(
    make_object({
      "nodeSelector": Json::string(node_id),
      "property": Json::string(property),
      "before": Json::string(before),
      "after": Json::string(after),
    }),
  )
}

///|
fn paint_diff_color_change(
  changes : Array[Json],
  node_id : String,
  property : String,
  before : @types.Color,
  after : @types.Color,
) -> Unit {
  if before != after {
    paint_diff_push_change(
      changes,
      node_id,
      property,
      before.to_rgba_string(),
      after.to_rgba_string(),
    )
  }
}

///|
fn paint_diff_double_change(
  changes : Array[Json],
  node_id : String,
  property : String,
  before : Double,
  after : Double,
) -> Unit {
  if (before - after).abs() > 0.001 {
    paint_diff_push_change(
      changes,
      node_id,
      property,
      before.to_string(),
      after.to_string(),
    )
  }
}

///|
/// Walk two structurally-aligned paint trees, collecting property `changes`
/// and rect `layoutShifts`. Children are matched by index.
fn collect_paint_tree_diff(
  a : @paint_model.PaintNode,
  b : @paint_model.PaintNode,
  changes : Array[Json],
  shifts : Array[Json],
) -> Unit {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let dw = b.width - a.width
  let dh = b.height - a.height
  if dx.abs() > 0.001 ||
    dy.abs() > 0.001 ||
    dw.abs() > 0.001 ||
    dh.abs() > 0.001 {
    shifts.push(
      make_object({
        "nodeSelector": Json::string(b.id),
        "dx": Json::number(dx),
        "dy": Json::number(dy),
        "dw": Json::number(dw),
        "dh": Json::number(dh),
      }),
    )
  }
  paint_diff_color_change(changes, b.id, "color", a.paint.color, b.paint.color)
  paint_diff_color_change(
    changes,
    b.id,
    "background-color",
    a.paint.background_color,
    b.paint.background_color,
  )
  paint_diff_double_change(
    changes,
    b.id,
    "opacity",
    a.paint.opacity,
    b.paint.opacity,
  )
  paint_diff_double_change(
    changes,
    b.id,
    "font-size",
    a.paint.font_size,
    b.paint.font_size,
  )
  paint_diff_double_change(
    changes,
    b.id,
    "font-weight",
    a.paint.font_weight,
    b.paint.font_weight,
  )
  let n = if a.children.length() < b.children.length() {
    a.children.length()
  } else {
    b.children.length()
  }
  for i = 0; i < n; i = i + 1 {
    collect_paint_tree_diff(a.children[i], b.children[i], changes, shifts)
  }
}

///|
fn paint_diff_variant_html(params : Map[String, Json], key : String) -> String? {
  match params.get(key) {
    Some(Object(map)) =>
      match map.get("html") {
        Some(String(html)) => Some(html)
        _ => None
      }
    Some(String(html)) => Some(html)
    _ => None
  }
}

///|
fn BidiProtocol::handle_diff_paint_tree(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_diff_paint_tree(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_diff_paint_tree(
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
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let baseline_html = match paint_diff_variant_html(params, "baseline") {
    Some(html) => html
    None => {
      self.send_error(
        request_id, "invalid argument", "baseline.html must be a string",
      )
      return None
    }
  }
  let current_html = match paint_diff_variant_html(params, "current") {
    Some(html) => html
    None => {
      self.send_error(
        request_id, "invalid argument", "current.html must be a string",
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
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let width = self.resolve_effective_viewport_width(ctx_id)
  let height = self.resolve_effective_viewport_height(ctx_id)
  let baseline_node = match
    self.render_html_to_paint_node(baseline_html, width, height) {
    Some(node) => node
    None => {
      self.send_error(
        request_id, "unknown error", "Failed to build baseline paint tree",
      )
      return None
    }
  }
  let current_node = match
    self.render_html_to_paint_node(current_html, width, height) {
    Some(node) => node
    None => {
      self.send_error(
        request_id, "unknown error", "Failed to build current paint tree",
      )
      return None
    }
  }
  let changes : Array[Json] = []
  let shifts : Array[Json] = []
  collect_paint_tree_diff(baseline_node, current_node, changes, shifts)
  Some(
    make_object({
      "changes": Json::array(changes),
      "layoutShifts": Json::array(shifts),
    }),
  )
}

///|
fn paint_diff_string_field(map : Map[String, Json], key : String) -> String {
  match map.get(key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
/// Reject tokens that could break out of the injected `<style>` rule or
/// element. The mutation selector / property / value are concatenated raw into
/// `<sel>{<prop>:<val> !important;}`, so any of `{ } ; < > \` (or a control
/// character) in a token could terminate the rule, the declaration, or the
/// style element and mutate unintended nodes / inject markup. Legitimate CSS
/// values (`12px 24px`, `rgb(0, 0, 0)`, `red`) contain none of these, so
/// rejecting them is safe.
fn mutation_token_is_safe(token : String) -> Bool {
  for c in token {
    if c == '{' ||
      c == '}' ||
      c == ';' ||
      c == '<' ||
      c == '>' ||
      c == '\\' ||
      c.to_int() < 0x20 {
      return false
    }
  }
  true
}

///|
/// Build a `<style>` block of `!important` overrides from the mutation list.
/// `action: "set"` writes the given value; `action: "remove"` resets the
/// property to its initial value (an approximation of removal that matches
/// real removal for the layout-affecting properties this API targets).
/// Mutations whose selector / property / value contain CSS-breaking tokens are
/// skipped so they cannot escape the injected stylesheet.
fn build_mutation_override_css(mutations : Array[Json]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<style>")
  for mutation in mutations {
    match mutation {
      Object(map) => {
        let selector = paint_diff_string_field(map, "selector")
        let property = paint_diff_string_field(map, "property")
        if selector != "" && property != "" {
          let value = if paint_diff_string_field(map, "action") == "set" {
            paint_diff_string_field(map, "value")
          } else {
            "initial"
          }
          if mutation_token_is_safe(selector) &&
            mutation_token_is_safe(property) &&
            mutation_token_is_safe(value) {
            buf.write_string(selector)
            buf.write_string("{")
            buf.write_string(property)
            buf.write_string(":")
            buf.write_string(value)
            buf.write_string(" !important;}")
          }
        }
      }
      _ => ()
    }
  }
  buf.write_string("</style>")
  buf.to_string()
}

///|
fn paint_node_rect_json(node : @paint_model.PaintNode) -> Json {
  make_object({
    "x": Json::number(node.x),
    "y": Json::number(node.y),
    "width": Json::number(node.width),
    "height": Json::number(node.height),
  })
}

///|
fn paint_node_paint_changed(
  a : @paint_model.PaintNode,
  b : @paint_model.PaintNode,
) -> Bool {
  a.paint.color != b.paint.color ||
  a.paint.background_color != b.paint.background_color ||
  (a.paint.opacity - b.paint.opacity).abs() > 0.001 ||
  (a.paint.font_size - b.paint.font_size).abs() > 0.001 ||
  (a.paint.font_weight - b.paint.font_weight).abs() > 0.001
}

///|
fn collect_paint_mutation_changes(
  a : @paint_model.PaintNode,
  b : @paint_model.PaintNode,
  seen : Map[String, Bool],
  affected : Array[Json],
  layout_changes : Array[Json],
) -> Unit {
  let rect_changed = (a.x - b.x).abs() > 0.001 ||
    (a.y - b.y).abs() > 0.001 ||
    (a.width - b.width).abs() > 0.001 ||
    (a.height - b.height).abs() > 0.001
  if rect_changed {
    layout_changes.push(
      make_object({
        "selector": Json::string(b.id),
        "before": paint_node_rect_json(a),
        "after": paint_node_rect_json(b),
      }),
    )
  }
  if rect_changed || paint_node_paint_changed(a, b) {
    match seen.get(b.id) {
      Some(_) => ()
      None => {
        seen[b.id] = true
        affected.push(Json::string(b.id))
      }
    }
  }
  let n = if a.children.length() < b.children.length() {
    a.children.length()
  } else {
    b.children.length()
  }
  for i = 0; i < n; i = i + 1 {
    collect_paint_mutation_changes(
      a.children[i],
      b.children[i],
      seen,
      affected,
      layout_changes,
    )
  }
}

///|
fn BidiProtocol::handle_mutate_style(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_mutate_style(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
/// browsingContext.mutateStyle (#24): re-render the current page with CSS
/// property mutations applied (as injected !important overrides) and report
/// the affected nodes and their layout changes, for CSS impact / dead-code
/// analysis without editing the source.
fn BidiProtocol::resolve_mutate_style(
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
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let mutations = match params.get("mutations") {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id, "invalid argument", "mutations must be an array",
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
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let width = self.resolve_effective_viewport_width(ctx_id)
  let height = self.resolve_effective_viewport_height(ctx_id)
  let baseline_html = @protocol.extract_string_value_from_evaluate_result(
    evaluate_js(serialize_live_document_html_expr()),
  )
  let mutated_html = baseline_html + build_mutation_override_css(mutations)
  let baseline_node = match
    self.render_html_to_paint_node(baseline_html, width, height) {
    Some(node) => node
    None => {
      self.send_error(
        request_id, "unknown error", "Failed to build baseline paint tree",
      )
      return None
    }
  }
  let mutated_node = match
    self.render_html_to_paint_node(mutated_html, width, height) {
    Some(node) => node
    None => {
      self.send_error(
        request_id, "unknown error", "Failed to build mutated paint tree",
      )
      return None
    }
  }
  let seen : Map[String, Bool] = {}
  let affected : Array[Json] = []
  let layout_changes : Array[Json] = []
  collect_paint_mutation_changes(
    baseline_node, mutated_node, seen, affected, layout_changes,
  )
  Some(
    make_object({
      "affectedNodes": Json::array(affected),
      "layoutChanges": Json::array(layout_changes),
    }),
  )
}
