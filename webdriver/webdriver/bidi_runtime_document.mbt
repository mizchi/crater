///|
/// FFI: Synchronize HTML content into JS runtime document used by script.evaluate.
extern "js" fn js_sync_runtime_html_async(
  html : String,
  base_url : String,
  execute_scripts : Bool,
) -> @core.Any =
  #| async (html, baseUrl, executeScripts) => {
  #|   const currentCtx = String(globalThis.__bidiCurrentContext || "default-context");
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   if (!globalThis.__bidiContextWindows.has(currentCtx)) {
  #|     const win = { __bidiContextId: currentCtx };
  #|     win.window = win;
  #|     globalThis.__bidiContextWindows.set(currentCtx, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(currentCtx);
  #|   const bindContextWindow = () => {
  #|     if (!contextWindow || typeof contextWindow !== "object") return;
  #|     contextWindow.window = contextWindow;
  #|     const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|     globalThis.window = contextWindow;
  #|     globalThis.frames = frameWindows;
  #|     globalThis.self = contextWindow;
  #|     globalThis.parent = contextWindow;
  #|     globalThis.top = contextWindow;
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(contextWindow);
  #|     }
  #|   };
  #|   if (typeof globalThis.__loadHTML !== "function") {
  #|     return "missing-loader";
  #|   }
  #|   globalThis.__loadHTML(html);
  #|   globalThis.__pageUrl = baseUrl;
  #|   if (globalThis.location && typeof globalThis.location === "object") {
  #|     try { globalThis.location.href = String(baseUrl); } catch (_e) {}
  #|   }
  #|   bindContextWindow();
  #|   if (executeScripts && typeof globalThis.__executeScripts === "function") {
  #|     try {
  #|       await globalThis.__executeScripts({ baseUrl });
  #|     } catch (_e) {}
  #|   }
  #|   bindContextWindow();
  #|   if (contextWindow && typeof contextWindow === "object") {
  #|     contextWindow.window = contextWindow;
  #|     if (globalThis.document && typeof globalThis.document === "object") {
  #|       contextWindow.document = globalThis.document;
  #|     }
  #|     if (globalThis.location && typeof globalThis.location === "object") {
  #|       contextWindow.location = globalThis.location;
  #|     }
  #|   }
  #|   return "ok";
  #| }

///|
/// FFI: Synchronize runtime document by fetching and loading a URL.
extern "js" fn js_sync_runtime_page_async(url : String) -> @core.Any =
  #| async (url) => {
  #|   const currentCtx = String(globalThis.__bidiCurrentContext || "default-context");
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   const ensureContextWindow = () => {
  #|     if (!globalThis.__bidiContextWindows.has(currentCtx)) {
  #|       const win = { __bidiContextId: currentCtx };
  #|       win.window = win;
  #|       globalThis.__bidiContextWindows.set(currentCtx, win);
  #|     }
  #|     return globalThis.__bidiContextWindows.get(currentCtx);
  #|   };
  #|   const bindContextWindow = () => {
  #|     const contextWindow = ensureContextWindow();
  #|     if (!contextWindow || typeof contextWindow !== "object") return;
  #|     contextWindow.window = contextWindow;
  #|     const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|     globalThis.window = contextWindow;
  #|     globalThis.frames = frameWindows;
  #|     globalThis.self = contextWindow;
  #|     globalThis.parent = contextWindow;
  #|     globalThis.top = contextWindow;
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(contextWindow);
  #|     }
  #|   };
  #|   const persistContextRuntime = () => {
  #|     const contextWindow = ensureContextWindow();
  #|     if (contextWindow && typeof contextWindow === "object") {
  #|       contextWindow.window = contextWindow;
  #|       if (globalThis.document && typeof globalThis.document === "object") {
  #|         contextWindow.document = globalThis.document;
  #|       }
  #|       if (globalThis.location && typeof globalThis.location === "object") {
  #|         contextWindow.location = globalThis.location;
  #|       }
  #|     }
  #|   };
  #|   bindContextWindow();
  #|   if (typeof globalThis.__loadPageWithScripts === "function") {
  #|     try {
  #|       await globalThis.__loadPageWithScripts(url, { executeScripts: true });
  #|       bindContextWindow();
  #|       persistContextRuntime();
  #|       return "ok";
  #|     } catch (_e) {
  #|       return "load-failed";
  #|     }
  #|   }
  #|   if (typeof globalThis.__loadPage === "function") {
  #|     try {
  #|       await globalThis.__loadPage(url);
  #|       bindContextWindow();
  #|       persistContextRuntime();
  #|       return "ok";
  #|     } catch (_e) {
  #|       return "load-failed";
  #|     }
  #|   }
  #|   globalThis.__pageUrl = url;
  #|   persistContextRuntime();
  #|   return "missing-loader";
  #| }

///|
/// Synchronize runtime page by URL.
pub fn sync_runtime_page(url : String) -> Unit {
  let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
  let promise = js_sync_runtime_page_async(url)
  let _ = js_await_promise(promise)
}

///|
/// Synchronize HTML content into the JS runtime document.
pub fn sync_runtime_html(
  html : String,
  base_url : String,
  execute_scripts : Bool,
) -> Unit {
  // Ensure runtime helpers are initialized.
  let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
  let promise = js_sync_runtime_html_async(html, base_url, execute_scripts)
  let _ = js_await_promise(promise)
}

// =============================================================================
// Data URL Support
// =============================================================================

///|
/// FFI: Decode base64 string
extern "js" fn js_decode_base64(base64 : String) -> String =
  #| (base64) => {
  #|   try {
  #|     return atob(base64);
  #|   } catch (e) {
  #|     return "";
  #|   }
  #| }

///|
/// Decode base64 string
pub fn decode_base64(base64 : String) -> String {
  js_decode_base64(base64)
}

///|
/// Parse data URL and return decoded content
/// Returns (content_type, content) or None if invalid
pub fn parse_data_url(url : String) -> (String, String)? {
  // data:[<mediatype>][;base64],<data>
  if !url.has_prefix("data:") {
    return None
  }
  let chars = url.to_array()
  // Find comma (start after "data:")
  let mut comma_idx = -1
  for i = 5; i < chars.length(); i = i + 1 {
    if chars[i] == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  // Build header string (from index 5 to comma)
  let header = make_substr(chars, 5, comma_idx)
  // Build data string (from comma+1 to end)
  let raw_data = make_substr(chars, comma_idx + 1, chars.length())
  // Ignore URL fragment (e.g. #domain=alt) in payload.
  let data_chars = raw_data.to_array()
  let mut hash_idx = -1
  for i = 0; i < data_chars.length(); i = i + 1 {
    if data_chars[i] == '#' {
      hash_idx = i
      break
    }
  }
  let data = if hash_idx >= 0 {
    make_substr(data_chars, 0, hash_idx)
  } else {
    raw_data
  }
  // Check if base64
  let is_base64 = header.contains(";base64")
  let content_type = if is_base64 {
    make_substr(header.to_array(), 0, header.length() - 7)
  } else {
    header
  }
  let content = if is_base64 { decode_base64(data) } else { data }
  Some((content_type, content))
}

///|
fn make_substr(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}
