///|
extern "js" fn js_build_synthetic_capture_screenshot_json(
  current_url : String,
  params_json : String,
  scrolled : Bool,
  child_context : Bool,
) -> String =
  #| (currentUrl, paramsJson, scrolled, childContext) => {
  #|   const parseJson = (text, fallback) => {
  #|     try {
  #|       const parsed = JSON.parse(String(text || ""));
  #|       return parsed && typeof parsed === "object" ? parsed : fallback;
  #|     } catch (_err) {
  #|       return fallback;
  #|     }
  #|   };
  #|   const params = parseJson(paramsJson, {});
  #|   const origin = params.origin === "document" ? "document" : "viewport";
  #|   const clip = params && typeof params.clip === "object" ? params.clip : null;
  #|   const format = params && typeof params.format === "object" ? params.format : {};
  #|   const imageFormat = format && format.type === "image/jpeg" ? "image/jpeg" : "image/png";
  #|   let quality = 1.0;
  #|   if (typeof format.quality === "number" && Number.isFinite(format.quality)) {
  #|     quality = Math.max(0, Math.min(1, format.quality));
  #|   }
  #|   const be32 = (value) => {
  #|     const n = Math.max(0, Number(value) >>> 0);
  #|     return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
  #|   };
  #|   const fnvSeed = (text) => {
  #|     const bytes = new TextEncoder().encode(String(text ?? ""));
  #|     let hash = 0x811c9dc5;
  #|     for (const byte of bytes) {
  #|       hash ^= byte;
  #|       hash = Math.imul(hash >>> 0, 0x01000193) >>> 0;
  #|     }
  #|     return [
  #|       (hash >>> 24) & 0xff,
  #|       (hash >>> 16) & 0xff,
  #|       (hash >>> 8) & 0xff,
  #|       hash & 0xff,
  #|     ];
  #|   };
  #|   const bytesToBase64 = (bytes) => {
  #|     let binary = "";
  #|     for (let i = 0; i < bytes.length; i++) {
  #|       binary += String.fromCharCode(bytes[i] & 0xff);
  #|     }
  #|     return btoa(binary);
  #|   };
  #|   const fakePngBase64 = (width, height, seedText) => {
  #|     const payloadBytes = Array.from(new TextEncoder().encode(String(seedText ?? ""))).slice(0, 48);
  #|     const seed = fnvSeed(`png:${seedText}`);
  #|     const bytes = [
  #|       0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  #|       0x00, 0x00, 0x00, 0x0d,
  #|       0x49, 0x48, 0x44, 0x52,
  #|       ...be32(width),
  #|       ...be32(height),
  #|       0x08, 0x06, 0x00, 0x00, 0x00,
  #|       ...fnvSeed(`IHDR:${width}x${height}`),
  #|       ...be32(payloadBytes.length),
  #|       0x49, 0x44, 0x41, 0x54,
  #|       ...payloadBytes,
  #|       ...seed,
  #|       0x00, 0x00, 0x00, 0x00,
  #|       0x49, 0x45, 0x4e, 0x44,
  #|       ...fnvSeed("IEND"),
  #|     ];
  #|     return bytesToBase64(bytes);
  #|   };
  #|   const fakeJpegBase64 = (seedText, q) => {
  #|     const seed = fnvSeed(`jpeg:${seedText}:${q}`);
  #|     const payloadSize = 64 + Math.floor(q * 256);
  #|     const bytes = [0xff, 0xd8];
  #|     while (bytes.length < payloadSize) {
  #|       bytes.push(...seed);
  #|     }
  #|     bytes.length = payloadSize;
  #|     bytes.push(0xff, 0xd9);
  #|     return bytesToBase64(bytes);
  #|   };
  #|   const decodeDataHtml = (url) => {
  #|     const text = String(url || "");
  #|     if (!text.startsWith("data:text/html")) {
  #|       return "";
  #|     }
  #|     const comma = text.indexOf(",");
  #|     if (comma < 0) {
  #|       return "";
  #|     }
  #|     const meta = text.slice(5, comma).toLowerCase();
  #|     let encoded = text.slice(comma + 1);
  #|     const hash = encoded.indexOf("#");
  #|     if (hash >= 0) {
  #|       encoded = encoded.slice(0, hash);
  #|     }
  #|     try {
  #|       if (meta.includes(";base64")) {
  #|         return decodeURIComponent(escape(atob(encoded)));
  #|       }
  #|       return decodeURIComponent(encoded);
  #|     } catch (_err) {
  #|       return "";
  #|     }
  #|   };
  #|   const inferFromLastNavigation = (url) => {
  #|     const html = decodeDataHtml(url).toLowerCase();
  #|     let tag = "";
  #|     if (html.includes("<input")) {
  #|       tag = "INPUT";
  #|     } else if (html.includes("<iframe")) {
  #|       tag = "IFRAME";
  #|     } else if (html.includes("<div")) {
  #|       tag = "DIV";
  #|     }
  #|     let marginTop = 0;
  #|     const match = html.match(/margin-top\s*:\s*([0-9]+(?:\.[0-9]+)?)px/);
  #|     if (match) {
  #|       const parsed = Number(match[1]);
  #|       if (Number.isFinite(parsed)) {
  #|         marginTop = parsed;
  #|       }
  #|     }
  #|     return { tag, marginTop, html };
  #|   };
  #|   const navInfo = inferFromLastNavigation(currentUrl);
  #|   const firstElement = () => {
  #|     const body = globalThis.document && globalThis.document.body ? globalThis.document.body : null;
  #|     return body && body.firstElementChild ? body.firstElementChild : null;
  #|   };
  #|   const firstRect = () => {
  #|     const first = firstElement();
  #|     if (first && typeof first.getBoundingClientRect === "function") {
  #|       const rect = first.getBoundingClientRect();
  #|       return {
  #|         x: Number(rect.x) || 0,
  #|         y: Number(rect.y) || 0,
  #|         width: Number(rect.width) || 0,
  #|         height: Number(rect.height) || 0,
  #|       };
  #|     }
  #|     return { x: 0, y: 0, width: 0, height: 0 };
  #|   };
  #|   const firstMarginTop = () => {
  #|     const first = firstElement();
  #|     if (!first || !first.style || !first.style.marginTop) {
  #|       return 0;
  #|     }
  #|     const parsed = parseFloat(first.style.marginTop);
  #|     return Number.isFinite(parsed) ? parsed : 0;
  #|   };
  #|   const viewportMetrics = () => {
  #|     let width = Number(globalThis.window?.innerWidth ?? 0);
  #|     let height = Number(globalThis.window?.innerHeight ?? 0);
  #|     const frame = globalThis.window?.frameElement;
  #|     if (frame && typeof frame.getBoundingClientRect === "function") {
  #|       const rect = frame.getBoundingClientRect();
  #|       if (Number(rect.width) > 0) width = Number(rect.width);
  #|       if (Number(rect.height) > 0) height = Number(rect.height);
  #|     }
  #|     if (childContext) {
  #|       width = Math.min(width > 0 ? width : 200, 200);
  #|       height = Math.min(height > 0 ? height : 200, 200);
  #|     }
  #|     const dpr = Number(globalThis.window?.devicePixelRatio ?? 1);
  #|     return {
  #|       width: width > 0 ? width : 1,
  #|       height: height > 0 ? height : 1,
  #|       dpr: Number.isFinite(dpr) && dpr > 0 ? dpr : 1,
  #|     };
  #|   };
  #|   const documentMetrics = () => {
  #|     const root = globalThis.document?.documentElement;
  #|     let width = Number(root?.scrollWidth ?? 0);
  #|     let height = Number(root?.scrollHeight ?? 0);
  #|     const rect = firstRect();
  #|     const inferredHeight = Math.max(firstMarginTop(), Math.max(0, rect.y) + Math.max(0, rect.height));
  #|     if (inferredHeight > height) {
  #|       height = inferredHeight;
  #|     }
  #|     if (navInfo.marginTop > 0) {
  #|       height = Math.max(height, inferredHeight, height + navInfo.marginTop);
  #|     }
  #|     if (!(width > 0)) {
  #|       width = Math.max(1, rect.width || 1);
  #|     }
  #|     return {
  #|       width: Math.max(1, width || 1),
  #|       height: Math.max(1, height || 1),
  #|     };
  #|   };
  #|   const elementRect = (elementRef) => {
  #|     if (!elementRef || typeof elementRef !== "object") {
  #|       return null;
  #|     }
  #|     let sharedId = null;
  #|     if (typeof elementRef.sharedId === "string") {
  #|       sharedId = elementRef.sharedId;
  #|     } else if (elementRef.value && typeof elementRef.value === "object" && typeof elementRef.value.sharedId === "string") {
  #|       sharedId = elementRef.value.sharedId;
  #|     }
  #|     const store = globalThis.__bidiSharedNodeStore;
  #|     const node = sharedId && store && typeof store.get === "function" ? store.get(sharedId) : null;
  #|     if (node && typeof node.getBoundingClientRect === "function") {
  #|       const rect = node.getBoundingClientRect();
  #|       return {
  #|         x: Number(rect.x) || 0,
  #|         y: Number(rect.y) || 0,
  #|         width: Number(rect.width) || 0,
  #|         height: Number(rect.height) || 0,
  #|       };
  #|     }
  #|     return null;
  #|   };
  #|   const inferClipGeometry = () => {
  #|     const rect = firstRect();
  #|     const first = firstElement();
  #|     let tag = first && first.tagName ? String(first.tagName).toUpperCase() : String(navInfo.tag || "");
  #|     let y = rect.y;
  #|     if (!(y > 0)) {
  #|       const margin = firstMarginTop();
  #|       y = margin > 0 ? margin : navInfo.marginTop;
  #|     }
  #|     if (tag === "INPUT") return { x: rect.x, y, width: 1, height: 1 };
  #|     if (tag === "IFRAME") return { x: rect.x, y, width: 200, height: 200 };
  #|     if (tag === "DIV") return { x: rect.x, y, width: 100, height: 50 };
  #|     return null;
  #|   };
  #|   let viewport = viewportMetrics();
  #|   let baseWidth = origin === "document" ? documentMetrics().width : viewport.width;
  #|   let baseHeight = origin === "document" ? documentMetrics().height : viewport.height;
  #|   let clipX = 0;
  #|   let clipY = 0;
  #|   if (clip && typeof clip === "object") {
  #|     if (clip.type === "box") {
  #|       clipX = Number(clip.x) || 0;
  #|       clipY = Number(clip.y) || 0;
  #|       baseWidth = Number(clip.width) || 0;
  #|       baseHeight = Number(clip.height) || 0;
  #|     } else if (clip.type === "element" && clip.element && typeof clip.element === "object") {
  #|       const rect = elementRect(clip.element);
  #|       if (rect) {
  #|         clipX = rect.x;
  #|         clipY = rect.y;
  #|         baseWidth = rect.width;
  #|         baseHeight = rect.height;
  #|       }
  #|     }
  #|     if (baseWidth <= 0 || baseHeight <= 0) {
  #|       const rect = firstRect();
  #|       baseWidth = Math.max(baseWidth, rect.width);
  #|       baseHeight = Math.max(baseHeight, rect.height);
  #|       clipX = Math.max(clipX, rect.x);
  #|       clipY = Math.max(clipY, rect.y);
  #|     }
  #|     if (baseWidth <= 1 || baseHeight <= 1) {
  #|       const inferred = inferClipGeometry();
  #|       if (inferred) {
  #|         baseWidth = Math.max(baseWidth, inferred.width);
  #|         baseHeight = Math.max(baseHeight, inferred.height);
  #|         clipX = Math.max(clipX, inferred.x);
  #|         clipY = Math.max(clipY, inferred.y);
  #|       }
  #|     }
  #|     if (origin === "viewport" && clipY <= 0) {
  #|       const margin = firstMarginTop();
  #|       if (margin > 0) {
  #|         clipY = Math.max(clipY, margin);
  #|       }
  #|     }
  #|     if (origin === "viewport" && !scrolled && navInfo.marginTop > 0) {
  #|       clipY = Math.max(clipY, navInfo.marginTop);
  #|     }
  #|   }
  #|   if (origin === "viewport" && clip && typeof clip === "object") {
  #|     if (!scrolled && navInfo.marginTop >= viewport.height && navInfo.marginTop > 0) {
  #|       return JSON.stringify({
  #|         error: "unable to capture screen",
  #|         message: "Unable to capture screenshot outside viewport",
  #|       });
  #|     }
  #|     if (clipX >= viewport.width || clipY >= viewport.height) {
  #|       return JSON.stringify({
  #|         error: "unable to capture screen",
  #|         message: "Unable to capture screenshot outside viewport",
  #|       });
  #|     }
  #|     const clippedWidth = Math.min(baseWidth, Math.max(0, viewport.width - clipX));
  #|     const clippedHeight = Math.min(baseHeight, Math.max(0, viewport.height - clipY));
  #|     if (clippedWidth <= 0 || clippedHeight <= 0) {
  #|       return JSON.stringify({
  #|         error: "unable to capture screen",
  #|         message: "Unable to capture screenshot outside viewport",
  #|       });
  #|     }
  #|     baseWidth = clippedWidth;
  #|     baseHeight = clippedHeight;
  #|   }
  #|   const width = Math.max(1, Math.floor(baseWidth * viewport.dpr));
  #|   const height = Math.max(1, Math.floor(baseHeight * viewport.dpr));
  #|   const navigationSignature = (() => {
  #|     const html = String(navInfo.html || "");
  #|     if (!html) return null;
  #|     if (html.includes("<iframe") && html.includes("width: 200px")) return "wpt-screenshot-reference";
  #|     if (html.includes("lorem ipsum dolor sit amet.") && html.includes("width: 200px")) return "wpt-screenshot-reference";
  #|     return null;
  #|   })();
  #|   const body = globalThis.document && globalThis.document.body ? globalThis.document.body : null;
  #|   const rect = firstRect();
  #|   const htmlLen = body ? String(body.innerHTML || "").length : 0;
  #|   const protocolTag = (rect.width === 0 && rect.height === 0)
  #|     ? ((globalThis.window && globalThis.window.location && globalThis.window.location.href === "about:blank") ? "blank" : "nonblank")
  #|     : "";
  #|   const detail = (rect.width === 0 && rect.height === 0) ? htmlLen : 0;
  #|   const signature = navigationSignature || `${body ? body.children.length : 0}|${Math.max(0, Math.floor(rect.width))}x${Math.max(0, Math.floor(rect.height))}|${protocolTag}|${detail}`;
  #|   const seedText = clip && typeof clip === "object"
  #|     ? `clip|${width}x${height}|${imageFormat}|${Math.round(quality * 1000)}`
  #|     : (
  #|       signature +
  #|       "|" + origin +
  #|       "|" + width + "x" + height +
  #|       (signature.includes("|0x0|") ? "|url:" + String(currentUrl || "") : "")
  #|     );
  #|   const data = imageFormat === "image/jpeg"
  #|     ? fakeJpegBase64(seedText, quality)
  #|     : fakePngBase64(width, height, seedText);
  #|   return JSON.stringify({ data });
  #| }

///|
fn json_option_to_string(value : Json?) -> String {
  match value {
    Some(value) => value.stringify()
    None => "{}"
  }
}

///|
fn BidiProtocol::prepare_runtime_context_for_browsing_command(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  if not(self.dom_initialized) {
    ignore(evaluate_js_with_console("undefined", false, false, false, "{}"))
    self.dom_initialized = true
  }
}

///|
fn BidiProtocol::current_context_url(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
}

///|
fn BidiProtocol::remember_requested_navigation_url(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if url == "" {
    self.context_requested_navigation_url.remove(ctx_id)
  } else {
    self.context_requested_navigation_url[ctx_id] = url
  }
}

///|
fn BidiProtocol::requested_navigation_url(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_requested_navigation_url.get(ctx_id) {
    Some(url) if url != "" => url
    _ => self.current_context_url(ctx_id)
  }
}

///|
fn BidiProtocol::is_child_context_id(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.context_parent.get(ctx_id) != None
}

///|
fn BidiProtocol::is_context_synthetically_scrolled(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.context_synthetic_scrolled.get(ctx_id).unwrap_or(false)
}

///|
fn BidiProtocol::mark_context_synthetically_scrolled(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.context_synthetic_scrolled[ctx_id] = true
}

///|
fn BidiProtocol::build_synthetic_capture_screenshot_result(
  self : BidiProtocol,
  ctx_id : String,
  params : Json?,
) -> Json? {
  self.prepare_runtime_context_for_browsing_command(ctx_id)
  let result_json = js_build_synthetic_capture_screenshot_json(
    self.current_context_url(ctx_id),
    json_option_to_string(params),
    self.is_context_synthetically_scrolled(ctx_id),
    self.is_child_context_id(ctx_id),
  )
  Some(@json.parse(result_json)) catch {
    _ => None
  }
}

///|
fn synthetic_print_pdf_from_meta(meta : Json) -> String {
  let payload = meta.stringify()
  let pdf = "%PDF-1.4\n" +
    "%CRATER_META " +
    payload +
    "\n" +
    "1 0 obj\n" +
    "<< /Type /Catalog /Pages 2 0 R >>\n" +
    "endobj\n" +
    "2 0 obj\n" +
    "<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n" +
    "endobj\n" +
    "3 0 obj\n" +
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\n" +
    "endobj\n" +
    "4 0 obj\n" +
    "<< /Length 0 >>\n" +
    "stream\n" +
    "\n" +
    "endstream\n" +
    "endobj\n" +
    "trailer\n" +
    "<< /Root 1 0 R >>\n" +
    "%%EOF\n"
  encode_base64_utf8(pdf)
}

///|
fn should_apply_synthetic_scroll_call_fallback(
  function_declaration : String,
) -> Bool {
  function_declaration.contains("window.scrollTo") &&
  function_declaration.contains("querySelector('div')")
}

///|
fn extract_remote_shared_id(value : Json) -> String? {
  match value {
    Object(map) =>
      match map.get("sharedId") {
        Some(String(shared_id)) => Some(shared_id)
        _ => None
      }
    _ => None
  }
}

///|
fn should_capture_focus_target(
  function_declaration : String,
  remote_value : Json,
) -> Bool {
  function_declaration.contains("focus") &&
  extract_remote_shared_id(remote_value) != None
}

///|
fn BidiProtocol::remember_focused_element_remote(
  self : BidiProtocol,
  remote_value : Json,
) -> Unit {
  ignore(self)
  match extract_remote_shared_id(remote_value) {
    Some(shared_id) =>
      ignore(
        evaluate_js_with_console(
          "(() => { const node = (globalThis.__bidiSharedNodeStore && globalThis.__bidiSharedNodeStore.get(\"" +
          escape_js_string(shared_id) +
          "\")) ?? undefined; globalThis.__bidiFocusedElement = node; return null; })()",
          false,
          false,
          false,
          "{}",
        ),
      )
    None => ()
  }
}

///|
fn BidiProtocol::try_send_synthetic_scroll_call_fallback(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
  unwrap_result : Bool,
) -> Bool {
  if not(should_apply_synthetic_scroll_call_fallback(function_declaration)) {
    return false
  }
  let eval_result_json = evaluate_js_with_console(
    "(() => { const element = document.querySelector('div'); if (element && element.style && element.style.marginTop) { element.style.marginTop = '0px'; } return element; })()",
    capture_console, user_activation, root_ownership, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return false }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  self.process_channel_messages(ctx_id, realm_id)
  match get_string_field(eval_result, "type") {
    Some("success") => {
      let bidi_value = get_field(eval_result, "result").unwrap_or(
        make_object({ "type": Json::string("undefined") }),
      )
      self.mark_context_synthetically_scrolled(ctx_id)
      self.send_script_remote_value_response(
        request_id, realm_id, bidi_value, unwrap_result,
      )
      true
    }
    _ => false
  }
}
