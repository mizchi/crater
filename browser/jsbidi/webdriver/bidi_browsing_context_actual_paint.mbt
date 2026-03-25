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
/// Check if JS-side text metrics provider is available
extern "js" fn has_paint_text_provider() -> Bool =
  #|() => typeof globalThis.__craterMeasureTextIntrinsic === "function"

///|
/// Call JS-side text metrics provider (returns CSV: "minWidth,maxWidth,minHeight,maxHeight")
extern "js" fn call_paint_text_provider(
  text : String,
  font_size : Double,
  line_height : Double,
  white_space : String,
  writing_mode : String,
  available_width : Double,
  available_height : Double,
) -> String =
  #|(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight) => {
  #|  const fn = globalThis.__craterMeasureTextIntrinsic;
  #|  if (typeof fn !== "function") return "";
  #|  try {
  #|    const result = fn(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight);
  #|    let minWidth, maxWidth, minHeight, maxHeight;
  #|    if (Array.isArray(result) && result.length >= 4) {
  #|      minWidth = Number(result[0]); maxWidth = Number(result[1]);
  #|      minHeight = Number(result[2]); maxHeight = Number(result[3]);
  #|    } else if (result && typeof result === "object") {
  #|      minWidth = Number(result.minWidth ?? result.min_width);
  #|      maxWidth = Number(result.maxWidth ?? result.max_width ?? minWidth);
  #|      minHeight = Number(result.minHeight ?? result.min_height);
  #|      maxHeight = Number(result.maxHeight ?? result.max_height ?? minHeight);
  #|    } else { return ""; }
  #|    if (!Number.isFinite(minWidth) || !Number.isFinite(maxWidth) || !Number.isFinite(minHeight) || !Number.isFinite(maxHeight)) return "";
  #|    return `${minWidth},${maxWidth},${minHeight},${maxHeight}`;
  #|  } catch { return ""; }
  #|}

///|
/// Check if JS-side glyph functions are available (mizchi/font loaded)
extern "js" fn has_glyph_functions() -> Bool =
  #|() => typeof globalThis.__craterGlyphToSvgPath === "function"

///|
/// Get SVG path string for a glyph
extern "js" fn js_glyph_to_svg_path(codepoint : Int, font_size : Double, is_bold : Bool) -> String =
  #|(cp, fs, bold) => {
  #|  const fn = bold ? (globalThis.__craterGlyphToSvgPathBold || globalThis.__craterGlyphToSvgPath) : globalThis.__craterGlyphToSvgPath;
  #|  if (typeof fn !== "function") return "";
  #|  try { return String(fn(cp, fs) || ""); } catch { return ""; }
  #|}

///|
/// Get advance width for a glyph
extern "js" fn js_glyph_advance(codepoint : Int, font_size : Double, is_bold : Bool) -> Double =
  #|(cp, fs, bold) => {
  #|  const fn = bold ? (globalThis.__craterGlyphAdvanceBold || globalThis.__craterGlyphAdvance) : globalThis.__craterGlyphAdvance;
  #|  if (typeof fn !== "function") return fs * 0.5;
  #|  try { const v = Number(fn(cp, fs)); return Number.isFinite(v) ? v : fs * 0.5; } catch { return fs * 0.5; }
  #|}

///|
/// Get font ascent ratio (ascent / unitsPerEm)
extern "js" fn js_font_ascent_ratio() -> Double =
  #|() => {
  #|  const fn = globalThis.__craterFontAscentRatio;
  #|  if (typeof fn === "function") { const v = Number(fn()); return Number.isFinite(v) ? v : 0.8; }
  #|  return 0.8;
  #|}

///|
fn parse_csv_quad(s : String) -> (Double, Double, Double, Double)? {
  let parts = s.split(",").collect()
  if parts.length() < 4 {
    return None
  }
  let a = @strconv.parse_double(parts[0]) catch { _ => return None }
  let b = @strconv.parse_double(parts[1]) catch { _ => return None }
  let c = @strconv.parse_double(parts[2]) catch { _ => return None }
  let d = @strconv.parse_double(parts[3]) catch { _ => return None }
  Some((a, b, c, d))
}

///|
fn ensure_paint_text_provider() -> Unit {
  if has_paint_text_provider() {
    let provider = @renderer.TextMetricsProvider::new(fn(
      text,
      font_size,
      line_height,
      white_space,
      writing_mode,
    ) {
      let ws = white_space.to_string()
      let wm = writing_mode.to_string()
      {
        func: fn(available_width, available_height) {
          let payload = call_paint_text_provider(
            text, font_size, line_height, ws, wm, available_width,
            available_height,
          )
          match parse_csv_quad(payload) {
            Some((min_w, max_w, min_h, max_h)) =>
              { min_width: min_w, max_width: max_w, min_height: min_h, max_height: max_h }
            None => {
              let mut cols = 0
              for _ in text.iter() {
                cols = cols + 1
              }
              let cw = if font_size > 0.0 { font_size * 0.5 } else { 8.0 }
              let w = cols.to_double() * cw
              let h = if line_height > 0.0 {
                line_height
              } else if font_size > 0.0 {
                font_size
              } else {
                16.0
              }
              { min_width: w, max_width: w, min_height: h, max_height: h }
            }
          }
        },
      }
    })
    @renderer.set_text_metrics_provider(provider)
  }
}

///|
let paint_provider_initialized : Ref[Bool] = { val: false }

///|
extern "js" fn js_log_stderr(msg : String) -> Unit =
  #|(msg) => { console.error("[paint] " + msg); }

///|
/// Set up MoonBit TextMetricsProvider from JS globalThis.__craterMeasureTextIntrinsic.
/// The JS-side provider is set up by start-with-font.ts at BiDi server startup.
fn ensure_paint_provider_initialized() -> Unit {
  if paint_provider_initialized.val {
    return
  }
  paint_provider_initialized.val = true
  let has_provider = has_paint_text_provider()
  js_log_stderr(
    "has_paint_text_provider=" + has_provider.to_string(),
  )
  ensure_paint_text_provider()
  // Set up glyph provider for SVG-based text rendering
  if has_glyph_functions() {
    js_log_stderr("Installing glyph provider")
    let ascent_ratio = js_font_ascent_ratio()
    js_log_stderr("ascent_ratio=" + ascent_ratio.to_string())
    let glyph_provider : @sixel.GlyphProvider = {
      ascent_ratio,
      get_glyph: fn(codepoint, font_size, is_bold) {
        let svg_path = js_glyph_to_svg_path(codepoint, font_size, is_bold)
        let advance = js_glyph_advance(codepoint, font_size, is_bold)
        if svg_path.length() == 0 {
          return ([], advance)
        }
        let commands = @svg.parse_path(svg_path)
        (commands, advance)
      },
    }
    @sixel.set_glyph_provider(glyph_provider)
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

  // Set up MoonBit-side text metrics provider if JS-side is available (lazy init)
  ensure_paint_provider_initialized()

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
