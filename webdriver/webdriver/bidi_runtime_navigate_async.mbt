///|
/// FFI: Navigate to URL asynchronously, send BiDi success/error response when
/// the runtime document load (__loadPageWithScripts / __loadPage) settles.
///
/// Mirrors the pattern of js_eval_and_send_async: the MoonBit caller hands
/// over the socket + request id, the JS async body awaits the load and emits
/// the response itself via socket.send(). This is the fix for
/// bug.bidi.navigate-wait-complete-returns-early — the previous sync path
/// (sync_runtime_page -> js_await_promise) returned before the load had any
/// chance to complete because MoonBit's sync caller cannot await a JS Promise
/// across the FFI boundary.
extern "js" fn js_navigate_and_send_async(
  socket : @core.Any,
  request_id : Int,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit =
  #| async (socket, requestId, ctxId, url, navigationId) => {
  #|   const currentCtx = String(globalThis.__bidiCurrentContext || ctxId || "default-context");
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
  #|
  #|   let success = false;
  #|   let errorMsg = "";
  #|   if (typeof globalThis.__loadPageWithScripts === "function") {
  #|     try {
  #|       await globalThis.__loadPageWithScripts(url, { executeScripts: true });
  #|       bindContextWindow();
  #|       persistContextRuntime();
  #|       success = true;
  #|     } catch (e) {
  #|       errorMsg = "load failed: " + ((e && e.message) ? e.message : String(e));
  #|     }
  #|   } else if (typeof globalThis.__loadPage === "function") {
  #|     try {
  #|       await globalThis.__loadPage(url);
  #|       bindContextWindow();
  #|       persistContextRuntime();
  #|       success = true;
  #|     } catch (e) {
  #|       errorMsg = "load failed: " + ((e && e.message) ? e.message : String(e));
  #|     }
  #|   } else {
  #|     // No loader available — surface an error so this class of bug fails
  #|     // loudly. Previously this branch silently returned success=true, which
  #|     // masked the navigate-http-url-not-parsed bug: the FFI appeared to
  #|     // succeed but no page was loaded. Now we set success=false so the BiDi
  #|     // response carries an explicit error and callers can detect the failure.
  #|     globalThis.__pageUrl = url;
  #|     persistContextRuntime();
  #|     errorMsg = "runtime loader missing: __loadPageWithScripts and __loadPage are not installed";
  #|     success = false;
  #|   }
  #|
  #|   const response = success
  #|     ? {
  #|         id: requestId,
  #|         type: "success",
  #|         result: { navigation: navigationId, url }
  #|       }
  #|     : {
  #|         id: requestId,
  #|         type: "error",
  #|         error: "unknown error",
  #|         message: errorMsg
  #|       };
  #|   const payload = JSON.stringify(response);
  #|   if (socket && typeof socket.send === "function") {
  #|     try { socket.send(payload); } catch (_e) { /* swallow */ }
  #|   } else if (typeof globalThis.__bidiSend === "function") {
  #|     try { globalThis.__bidiSend(payload); } catch (_e) { /* swallow */ }
  #|   }
  #| }

///|
/// MoonBit wrapper around js_navigate_and_send_async. Used by the navigate
/// dispatch when wait=complete is requested for an http(s) URL — instead of
/// the broken sync sync_runtime_page() path, the JS body awaits the page
/// load and emits the BiDi response via socket once the load resolves.
pub fn navigate_and_send_async(
  socket : @core.Any,
  request_id : Int,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  // Prime runtime helpers; mirrors sync_runtime_page (bidi_runtime_document.mbt:125-129).
  // Without this, the first navigate after reset_runtime_js_state runs before
  // __loadPageWithScripts is installed (it lives behind js_evaluate_expression's
  // setup), so the FFI silently falls into the "missing-loader" branch and
  // returns success without actually fetching the page.
  // See bug.bidi.navigate-http-url-not-parsed.
  let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
  js_navigate_and_send_async(socket, request_id, ctx_id, url, navigation_id)
}
