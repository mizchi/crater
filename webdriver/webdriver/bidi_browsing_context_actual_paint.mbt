///|
/// Check if JS-side text metrics provider is available
extern "js" fn has_paint_text_provider() -> Bool =
  #|() => typeof globalThis.__craterMeasureTextIntrinsic === "function"

///|
/// Call font-family-aware text metrics provider
extern "js" fn call_font_aware_text_provider(
  text : String,
  font_size : Double,
  line_height : Double,
  white_space : String,
  writing_mode : String,
  available_width : Double,
  available_height : Double,
  font_family : String,
  is_bold : Bool,
) -> String =
  #|(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight, fontFamily, isBold) => {
  #|  // Try multi-font provider first
  #|  const multiFn = globalThis.__craterMeasureTextIntrinsicMultiFull;
  #|  if (typeof multiFn === "function") {
  #|    try {
  #|      const result = multiFn(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight, fontFamily, isBold);
  #|      if (result) {
  #|        const mw = Number(result.minWidth ?? result.min_width);
  #|        const xw = Number(result.maxWidth ?? result.max_width);
  #|        const mh = Number(result.minHeight ?? result.min_height);
  #|        const xh = Number(result.maxHeight ?? result.max_height);
  #|        if (Number.isFinite(mw) && Number.isFinite(xw) && Number.isFinite(mh) && Number.isFinite(xh))
  #|          return `${mw},${xw},${mh},${xh}`;
  #|      }
  #|    } catch {}
  #|  }
  #|  // Fallback to default provider
  #|  const fn = isBold ? (globalThis.__craterMeasureTextIntrinsicBold || globalThis.__craterMeasureTextIntrinsic) : globalThis.__craterMeasureTextIntrinsic;
  #|  if (typeof fn !== "function") return "";
  #|  try {
  #|    const result = fn(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight);
  #|    let minWidth, maxWidth, minHeight, maxHeight;
  #|    if (result && typeof result === "object") {
  #|      minWidth = Number(result.minWidth ?? result.min_width);
  #|      maxWidth = Number(result.maxWidth ?? result.max_width);
  #|      minHeight = Number(result.minHeight ?? result.min_height);
  #|      maxHeight = Number(result.maxHeight ?? result.max_height);
  #|    } else return "";
  #|    if (!Number.isFinite(minWidth) || !Number.isFinite(maxWidth)) return "";
  #|    return `${minWidth},${maxWidth},${minHeight},${maxHeight}`;
  #|  } catch { return ""; }
  #|}

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
/// Check if JS-side outline commands provider is available (avoids SVG string roundtrip)
extern "js" fn has_outline_commands() -> Bool =
  #|() => typeof globalThis.__craterGlyphOutlineCommands === "function"

///|
/// Get glyph outline commands as JSON string: [[type, ...args], ...]
extern "js" fn js_glyph_outline_commands(
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> String =
  #|(cp, fs, bold) => {
  #|  const fn = bold ? (globalThis.__craterGlyphOutlineCommandsBold || globalThis.__craterGlyphOutlineCommands) : globalThis.__craterGlyphOutlineCommands;
  #|  if (typeof fn !== "function") return "";
  #|  try { return String(fn(cp, fs) || ""); } catch { return ""; }
  #|}

///|
/// Get glyph outline commands for a specific font family as JSON string
extern "js" fn js_outline_commands_for_family(
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
) -> String =
  #|(cp, fs, bold, ff) => {
  #|  const fn = globalThis.__craterOutlineCommandsForFamily;
  #|  if (typeof fn !== "function") return "";
  #|  try { return String(fn(cp, fs, bold, ff) || ""); } catch { return ""; }
  #|}

///|
/// Check if JS-side glyph functions are available (mizchi/font loaded)
extern "js" fn has_glyph_functions() -> Bool =
  #|() => typeof globalThis.__craterGlyphToSvgPath === "function"

///|
/// Get SVG path string for a glyph
extern "js" fn js_glyph_to_svg_path(
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> String =
  #|(cp, fs, bold) => {
  #|  const fn = bold ? (globalThis.__craterGlyphToSvgPathBold || globalThis.__craterGlyphToSvgPath) : globalThis.__craterGlyphToSvgPath;
  #|  if (typeof fn !== "function") return "";
  #|  try { return String(fn(cp, fs) || ""); } catch { return ""; }
  #|}

///|
/// Get advance width for a glyph
extern "js" fn js_glyph_advance(
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> Double =
  #|(cp, fs, bold) => {
  #|  const fn = bold ? (globalThis.__craterGlyphAdvanceBold || globalThis.__craterGlyphAdvance) : globalThis.__craterGlyphAdvance;
  #|  if (typeof fn !== "function") return fs * 0.5;
  #|  try { const v = Number(fn(cp, fs)); return Number.isFinite(v) ? v : fs * 0.5; } catch { return fs * 0.5; }
  #|}

///|
/// Get kerning between two codepoints
extern "js" fn js_kern_advance(
  cp1 : Int,
  cp2 : Int,
  font_size : Double,
  is_bold : Bool,
) -> Double =
  #|(cp1, cp2, fs, bold) => {
  #|  const fn = bold ? (globalThis.__craterKernAdvanceBold || globalThis.__craterKernAdvance) : globalThis.__craterKernAdvance;
  #|  if (typeof fn !== "function") return 0;
  #|  try { const v = Number(fn(cp1, cp2, fs)); return Number.isFinite(v) ? v : 0; } catch { return 0; }
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
/// Multi-font glyph: get SVG path for a codepoint using font_family
extern "js" fn js_glyph_for_family(
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
) -> String =
  #|(cp, fs, bold, ff) => {
  #|  const fn = globalThis.__craterGlyphForFamily;
  #|  if (typeof fn !== "function") return "";
  #|  try { return String(fn(cp, fs, bold, ff) || ""); } catch { return ""; }
  #|}

///|
extern "js" fn js_advance_for_family(
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
) -> Double =
  #|(cp, fs, bold, ff) => {
  #|  const fn = globalThis.__craterAdvanceForFamily;
  #|  if (typeof fn !== "function") return fs * 0.5;
  #|  try { const v = Number(fn(cp, fs, bold, ff)); return Number.isFinite(v) ? v : fs * 0.5; } catch { return fs * 0.5; }
  #|}

///|
extern "js" fn js_kern_for_family(
  cp1 : Int,
  cp2 : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
) -> Double =
  #|(cp1, cp2, fs, bold, ff) => {
  #|  const fn = globalThis.__craterKernForFamily;
  #|  if (typeof fn !== "function") return 0;
  #|  try { const v = Number(fn(cp1, cp2, fs, bold, ff)); return Number.isFinite(v) ? v : 0; } catch { return 0; }
  #|}

///|
extern "js" fn js_ascent_for_family(font_family : String) -> Double =
  #|(ff) => {
  #|  const fn = globalThis.__craterAscentForFamily;
  #|  if (typeof fn !== "function") return 0.8;
  #|  try { const v = Number(fn(ff)); return Number.isFinite(v) ? v : 0.8; } catch { return 0.8; }
  #|}

///|
extern "js" fn has_bold_text_provider() -> Bool =
  #|() => typeof globalThis.__craterMeasureTextIntrinsicBold === "function"

///|
extern "js" fn call_bold_text_provider(
  text : String,
  font_size : Double,
  line_height : Double,
  white_space : String,
  writing_mode : String,
  available_width : Double,
  available_height : Double,
) -> String =
  #|(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight) => {
  #|  const fn = globalThis.__craterMeasureTextIntrinsicBold;
  #|  if (typeof fn !== "function") return "";
  #|  try {
  #|    const result = fn(text, fontSize, lineHeight, whiteSpace, writingMode, availableWidth, availableHeight);
  #|    let minWidth, maxWidth, minHeight, maxHeight;
  #|    if (result && typeof result === "object") {
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
fn ensure_paint_text_provider() -> Unit {
  if has_paint_text_provider() {
    let provider = @renderer.TextMetricsProvider::new(fn(
      text,
      font_size,
      line_height,
      white_space,
      writing_mode,
      font_weight,
      font_family,
    ) {
      let ws = white_space.to_string()
      let wm = writing_mode.to_string()
      let is_bold = font_weight >= 600.0
      let ff = font_family
      {
        func: fn(available_width, available_height) {
          let payload = if @rendering.should_use_font_aware_text_provider(ff) {
            let multi = call_font_aware_text_provider(
              text, font_size, line_height, ws, wm, available_width, available_height,
              ff, is_bold,
            )
            if multi.length() > 0 {
              multi
            } else if is_bold && has_bold_text_provider() {
              call_bold_text_provider(
                text, font_size, line_height, ws, wm, available_width, available_height,
              )
            } else {
              call_paint_text_provider(
                text, font_size, line_height, ws, wm, available_width, available_height,
              )
            }
          } else if is_bold && has_bold_text_provider() {
            call_bold_text_provider(
              text, font_size, line_height, ws, wm, available_width, available_height,
            )
          } else {
            call_paint_text_provider(
              text, font_size, line_height, ws, wm, available_width, available_height,
            )
          }
          match @rendering.parse_text_metrics_quad(payload) {
            Some((min_w, max_w, min_h, max_h)) =>
              {
                min_width: min_w,
                max_width: max_w,
                min_height: min_h,
                max_height: max_h,
              }
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
/// Reset paint provider state on new WebSocket session.
/// Must be called when JS runtime is reset to avoid stale glyph provider.
pub fn reset_paint_provider() -> Unit {
  paint_provider_initialized.val = false
  @raster.clear_glyph_provider()
  @renderer.clear_text_metrics_provider()
}

///|
extern "js" fn js_now_ms() -> Int =
  #|() => Date.now()

///|
extern "js" fn js_log_stderr(msg : String) -> Unit =
  #|(msg) => { console.error("[paint] " + msg); }

///|
priv struct PaintCaptureFrame {
  width : Int
  height : Int
  framebuffer : @tui_paint_export.Framebuffer
  palette : @tui_paint_export.DynamicPalette
  timing : @rendering.PaintCaptureTiming
  visual : @tui_paint_export.VisualStats?
}

///|
/// Set up MoonBit TextMetricsProvider from JS globalThis.__craterMeasureTextIntrinsic.
/// The JS-side provider is set up by start-with-font.ts at BiDi server startup.
fn ensure_paint_provider_initialized() -> Unit {
  if paint_provider_initialized.val {
    return
  }
  paint_provider_initialized.val = true
  let has_provider = has_paint_text_provider()
  js_log_stderr("has_paint_text_provider=" + has_provider.to_string())
  ensure_paint_text_provider()
  // Set up glyph provider for text rendering
  // Prefer outline commands (JSON array) over SVG string to avoid parse_path roundtrip
  let use_outline_commands = has_outline_commands()
  if use_outline_commands || has_glyph_functions() {
    if use_outline_commands {
      js_log_stderr(
        "Installing glyph provider (outline commands, no SVG roundtrip)",
      )
    } else {
      js_log_stderr("Installing glyph provider (SVG string fallback)")
    }
    let ascent_ratio = js_font_ascent_ratio()
    js_log_stderr("ascent_ratio=" + ascent_ratio.to_string())
    let glyph_provider : @raster.GlyphProvider = {
      ascent_ratio,
      get_kern: fn(cp1, cp2, font_size, is_bold) {
        js_kern_advance(cp1, cp2, font_size, is_bold)
      },
      get_glyph: fn(codepoint, font_size, is_bold) {
        resolve_js_glyph_commands(
          use_outline_commands, codepoint, font_size, is_bold,
        )
      },
      get_glyph_by_weight: Some(fn(codepoint, font_size, font_weight) {
        let is_bold = font_weight >= 600.0
        resolve_js_glyph_commands(
          use_outline_commands, codepoint, font_size, is_bold,
        )
      }),
      get_kern_by_weight: Some(fn(cp1, cp2, font_size, font_weight) {
        js_kern_advance(cp1, cp2, font_size, font_weight >= 600.0)
      }),
      get_glyph_for_family: Some(fn(
        codepoint,
        font_size,
        is_bold,
        font_family,
      ) {
        resolve_js_family_glyph_commands(
          use_outline_commands, codepoint, font_size, is_bold, font_family,
        )
      }),
      get_kern_for_family: Some(fn(cp1, cp2, font_size, is_bold, font_family) {
        js_kern_for_family(cp1, cp2, font_size, is_bold, font_family)
      }),
      get_glyph_for_family_by_weight: Some(fn(
        codepoint,
        font_size,
        font_weight,
        font_family,
      ) {
        let is_bold = font_weight >= 600.0
        resolve_js_family_glyph_commands(
          use_outline_commands, codepoint, font_size, is_bold, font_family,
        )
      }),
      get_kern_for_family_by_weight: Some(fn(
        cp1,
        cp2,
        font_size,
        font_weight,
        font_family,
      ) {
        js_kern_for_family(
          cp1,
          cp2,
          font_size,
          font_weight >= 600.0,
          font_family,
        )
      }),
      get_ascent_for_family: Some(fn(font_family) {
        js_ascent_for_family(font_family)
      }),
    }
    @raster.set_glyph_provider(glyph_provider)
  }
}

///|
fn resolve_js_glyph_commands(
  use_outline_commands : Bool,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> (Array[@svg.PathCommand], Double) {
  let advance = js_glyph_advance(codepoint, font_size, is_bold)
  if use_outline_commands {
    let json = js_glyph_outline_commands(codepoint, font_size, is_bold)
    if json.length() == 0 || json == "[]" {
      return ([], advance)
    }
    let commands = @rendering.parse_glyph_outline_commands_json(json)
    (commands, advance)
  } else {
    let svg_path = js_glyph_to_svg_path(codepoint, font_size, is_bold)
    if svg_path.length() == 0 {
      return ([], advance)
    }
    let commands = @svg.parse_path(svg_path)
    (commands, advance)
  }
}

///|
fn resolve_js_family_glyph_commands(
  use_outline_commands : Bool,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
) -> (Array[@svg.PathCommand], Double)? {
  let advance = js_advance_for_family(
    codepoint, font_size, is_bold, font_family,
  )
  if use_outline_commands {
    let json = js_outline_commands_for_family(
      codepoint, font_size, is_bold, font_family,
    )
    if json.length() == 0 || json == "[]" {
      return None
    }
    let commands = @rendering.parse_glyph_outline_commands_json(json)
    Some((commands, advance))
  } else {
    let svg_path = js_glyph_for_family(
      codepoint, font_size, is_bold, font_family,
    )
    if svg_path.length() == 0 {
      return None
    }
    let commands = @svg.parse_path(svg_path)
    Some((commands, advance))
  }
}

///|
fn capture_current_paint_html() -> String {
  let html_json = evaluate_js(capture_paint_source_html_expr())
  @protocol.extract_string_value_from_evaluate_result(html_json)
}

///|
fn BidiProtocol::resolve_actual_paint_viewport_dimensions(
  self : BidiProtocol,
  ctx_id : String,
) -> (Int, Int) {
  let viewport_width = self.resolve_effective_viewport_width(ctx_id)
  let viewport_height = self.resolve_effective_viewport_height(ctx_id)
  (viewport_width, viewport_height)
}

///|
fn BidiProtocol::build_actual_paint_frame(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  html : String,
  origin? : String = "viewport",
  send_errors? : Bool = true,
  measure_visual? : Bool = false,
) -> PaintCaptureFrame? {
  ensure_paint_provider_initialized()
  let (viewport_width, viewport_height) = self.resolve_actual_paint_viewport_dimensions(
    ctx_id,
  )
  let ctx = @browser_contract.create_render_context(
    viewport_width, viewport_height, false,
  )
  let t0 = js_now_ms()
  let (node, layout) = if origin == "document" {
    @renderer.render_to_node_and_layout_full_document(html, ctx)
  } else {
    @renderer.render_to_node_and_layout(html, ctx)
  }
  let t1 = js_now_ms()
  let (width, height) = if origin == "document" {
    @rendering.actual_paint_document_dimensions_from_node_and_layout(
      node, layout, viewport_width, viewport_height,
    )
  } else {
    (viewport_width, viewport_height)
  }
  let paint_node = match
    @tui_paint_viewport.from_node_and_layout_with_viewport_rect(
      node,
      layout,
      0.0,
      0.0,
      width.to_double(),
      height.to_double(),
      0.0,
      0.0,
    ) {
    Some(node) => node
    None => {
      if send_errors {
        self.send_error(
          request_id, "unknown error", "Failed to build paint tree for current context",
        )
      }
      return None
    }
  }
  let t2 = js_now_ms()
  let (fb, palette) = @tui_paint_export.raster_to_framebuffer(
    paint_node, width, height,
  )
  let visual = if measure_visual {
    Some(@tui_paint_export.framebuffer_visual_stats(fb, palette))
  } else {
    None
  }
  let t3 = js_now_ms()
  Some({
    width,
    height,
    framebuffer: fb,
    palette,
    timing: {
      node_layout_ms: t1 - t0,
      paint_tree_ms: t2 - t1,
      raster_ms: t3 - t2,
      png_encode_ms: 0,
      rgba_encode_ms: 0,
      total_ms: t3 - t0,
    },
    visual,
  })
}

///|
/// Pre-rasterize common ASCII glyphs. Initializes providers if needed.
pub fn warmup_glyph_cache() -> Unit {
  ensure_paint_provider_initialized()
  let t_pre = js_now_ms()
  let common_sizes : Array[Double] = [
    13.33, // 10pt (most common body text)
     16.0, // 16px (browser default)
  ]
  let n = @raster.pre_rasterize_glyphs(common_sizes)
  let t_pre_done = js_now_ms()
  js_log_stderr(
    "Pre-rasterized " +
    n.to_string() +
    " glyphs in " +
    (t_pre_done - t_pre).to_string() +
    "ms",
  )
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
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  let html = capture_current_paint_html()
  let frame = match
    self.build_actual_paint_frame(
      request_id,
      ctx_id,
      html,
      send_errors=true,
      measure_visual=true,
    ) {
    Some(frame) => frame
    None => return None
  }
  let visual = match frame.visual {
    Some(visual) => visual
    None =>
      @tui_paint_export.framebuffer_visual_stats(
        frame.framebuffer,
        frame.palette,
      )
  }
  let t_encode0 = js_now_ms()
  let data = @tui_paint_export.framebuffer_to_rgba_base64(
    frame.framebuffer,
    frame.palette,
  )
  let t_encode1 = js_now_ms()
  let timing : @rendering.PaintCaptureTiming = {
    ..frame.timing,
    rgba_encode_ms: t_encode1 - t_encode0,
    total_ms: frame.timing.total_ms + (t_encode1 - t_encode0),
  }
  js_log_stderr(
    "capturePaintData: node_layout=" +
    timing.node_layout_ms.to_string() +
    "ms paint_tree=" +
    timing.paint_tree_ms.to_string() +
    "ms raster=" +
    timing.raster_ms.to_string() +
    "ms rgba_encode=" +
    timing.rgba_encode_ms.to_string() +
    "ms total=" +
    timing.total_ms.to_string() +
    "ms non_white=" +
    visual.non_white_pixels.to_string() +
    " distinct=" +
    visual.distinct_colors.to_string(),
  )
  Some(
    make_object({
      "width": Json::number(frame.width.to_double()),
      "height": Json::number(frame.height.to_double()),
      "data": Json::string(data),
      "timing": @rendering.capture_timing_to_json(timing),
      "visual": @rendering.capture_visual_to_json(visual),
    }),
  )
}

///|
fn BidiProtocol::try_resolve_actual_capture_screenshot_data(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  params : Map[String, Json],
) -> String? {
  if !@rendering.can_use_actual_paint_for_screenshot_data(params) {
    return None
  }
  let html = capture_current_paint_html()
  if html.trim().length() == 0 {
    return None
  }
  let origin = match params.get("origin") {
    Some(String("document")) => "document"
    _ => "viewport"
  }
  let frame = match
    self.build_actual_paint_frame(
      request_id,
      ctx_id,
      html,
      origin~,
      send_errors=false,
      measure_visual=false,
    ) {
    Some(frame) => frame
    None => return None
  }
  let t_encode0 = js_now_ms()
  let data = @tui_paint_png.framebuffer_to_png_base64(
    frame.framebuffer,
    frame.palette,
  )
  let t_encode1 = js_now_ms()
  let timing : @rendering.PaintCaptureTiming = {
    ..frame.timing,
    png_encode_ms: t_encode1 - t_encode0,
    total_ms: frame.timing.total_ms + (t_encode1 - t_encode0),
  }
  js_log_stderr(
    "captureScreenshotData: node_layout=" +
    timing.node_layout_ms.to_string() +
    "ms paint_tree=" +
    timing.paint_tree_ms.to_string() +
    "ms raster=" +
    timing.raster_ms.to_string() +
    "ms png_encode=" +
    timing.png_encode_ms.to_string() +
    "ms total=" +
    timing.total_ms.to_string() +
    "ms",
  )
  Some(data)
}

///|
fn capture_paint_source_html_expr() -> String {
  (
    #|(() => {
    #|  const ctxId = String(globalThis.__bidiCurrentContext || "default-context");
    #|  const ctxWindow = globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)
    #|    ? globalThis.__bidiContextWindows.get(ctxId)
    #|    : null;
    #|  const captureSource = ctxWindow && ctxWindow.__craterPaintCaptureSource
    #|    ? ctxWindow.__craterPaintCaptureSource
    #|    : globalThis.__craterPaintCaptureSource;
    #|  if (captureSource === "live") {
    #|    const live =
  ) +
  serialize_live_document_html_expr() +
  (
    #|;
    #|    if (live) return live;
    #|  }
    #|  if (ctxWindow && typeof ctxWindow.__lastHTML === "string") {
    #|    return ctxWindow.__lastHTML;
    #|  }
    #|  return globalThis.__lastHTML || '';
    #|})()
  )
}

///|
/// Return PaintNode tree as JSON for native paint rendering.
fn BidiProtocol::handle_capture_paint_tree(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_capture_paint_tree(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_capture_paint_tree(
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
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let origin = match params.get("origin") {
    None | Some(String("viewport")) => "viewport"
    Some(String("document")) => "document"
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport' or 'document'",
      )
      return None
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "origin must be a string")
      return None
    }
  }
  let width = self.resolve_effective_viewport_width(ctx_id)
  let height = self.resolve_effective_viewport_height(ctx_id)
  let html_json = evaluate_js(serialize_live_document_html_expr())
  let html = @protocol.extract_string_value_from_evaluate_result(html_json)
  let ctx = @browser_contract.create_render_context(width, height, false)
  let (node, layout) = if origin == "document" {
    @renderer.render_to_node_and_layout_full_document(html, ctx)
  } else {
    @renderer.render_to_node_and_layout(html, ctx)
  }
  let (paint_width, paint_height) = if origin == "document" {
    @rendering.actual_paint_document_dimensions_from_node_and_layout(
      node, layout, width, height,
    )
  } else {
    (width, height)
  }
  let paint_node = match
    @tui_paint_viewport.from_node_and_layout_with_viewport_rect(
      node,
      layout,
      0.0,
      0.0,
      paint_width.to_double(),
      paint_height.to_double(),
      0.0,
      0.0,
    ) {
    Some(node) => node
    None => {
      self.send_error(request_id, "unknown error", "Failed to build paint tree")
      return None
    }
  }
  let json_str = @tui_paint_export.to_json_string(paint_node)
  Some(
    make_object({
      "width": Json::number(paint_width.to_double()),
      "height": Json::number(paint_height.to_double()),
      "paintTree": Json::string(json_str),
    }),
  )
}
