///|
/// QuickJS Runtime for BiDi Script Execution
///
/// Uses quickjs-emscripten with ASYNCIFY for sandboxed JavaScript execution
/// with ES Modules support and network fetch capability.

///|
/// Global QuickJS state
priv struct QuickJSState {
  mut initialized : Bool
  mut pending_init : Bool
}

///|
let quickjs_state : QuickJSState = { initialized: false, pending_init: false }

///|
/// FFI: Initialize QuickJS ASYNCIFY runtime
/// Returns a Promise that resolves when initialization is complete
extern "js" fn quickjs_init_runtime() -> @core.Any =
  #| async () => {
  #|   if (globalThis.__quickjs_runtime) {
  #|     return globalThis.__quickjs_runtime;
  #|   }
  #|
  #|   // Import quickjs-emscripten
  #|   const { newQuickJSAsyncWASMModuleFromVariant } = await import("npm:quickjs-emscripten");
  #|   const releaseVariant = (await import("npm:@jitl/quickjs-wasmfile-release-asyncify")).default;
  #|
  #|   console.log("[QuickJS] Loading ASYNCIFY variant...");
  #|   const QuickJS = await newQuickJSAsyncWASMModuleFromVariant(releaseVariant);
  #|   console.log("[QuickJS] Runtime loaded");
  #|
  #|   const runtime = QuickJS.newRuntime();
  #|   const vm = runtime.newContext();
  #|
  #|   // Set up async module loader with fetch support
  #|   runtime.setModuleLoader(async (moduleName, ctx) => {
  #|     let url = moduleName;
  #|
  #|     // Resolve URLs
  #|     if (moduleName.startsWith("https://") || moduleName.startsWith("http://")) {
  #|       url = moduleName;
  #|     } else if (moduleName.startsWith("/")) {
  #|       // Root-relative URLs (from esm.sh redirects)
  #|       url = "https://esm.sh" + moduleName;
  #|     } else {
  #|       // Bare specifiers
  #|       url = "https://esm.sh/" + moduleName;
  #|     }
  #|
  #|     console.log("[QuickJS] Loading module:", url);
  #|
  #|     try {
  #|       const res = await fetch(url);
  #|       if (!res.ok) {
  #|         return { error: new Error("HTTP " + res.status + ": " + url) };
  #|       }
  #|       const code = await res.text();
  #|       return { value: code };
  #|     } catch (e) {
  #|       return { error: new Error("Fetch failed: " + e.message) };
  #|     }
  #|   });
  #|
  #|   // Store globally
  #|   globalThis.__quickjs_runtime = { QuickJS, runtime, vm };
  #|
  #|   // Setup Mock DOM in QuickJS context
  #|   await setupQuickJSMockDOM(vm);
  #|
  #|   return globalThis.__quickjs_runtime;
  #| }

///|
/// FFI: Evaluate expression in QuickJS context (sync version)
/// Returns BiDi-formatted result JSON with console entries
extern "js" fn quickjs_evaluate_sync(expression : String) -> String =
  #| (expression) => {
  #|   if (!globalThis.__quickjs_runtime) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         text: "QuickJS not initialized",
  #|         exception: { type: "error" }
  #|       },
  #|       consoleEntries: []
  #|     });
  #|   }
  #|
  #|   // Note: sync evaluation with ASYNCIFY is not possible
  #|   // This returns a pending state - use async version instead
  #|   return JSON.stringify({
  #|     type: "exception",
  #|     exceptionDetails: {
  #|       text: "Use async evaluation for QuickJS",
  #|       exception: { type: "error" }
  #|     },
  #|     consoleEntries: []
  #|   });
  #| }

///|
/// FFI: Evaluate expression in QuickJS context (async version)
/// Returns Promise that resolves to BiDi-formatted result JSON with console entries
extern "js" fn quickjs_evaluate_async(
  expression : String,
  await_promise : Bool,
) -> @core.Any =
  #| async (expression, awaitPromise) => {
  #|   const rt = globalThis.__quickjs_runtime;
  #|   if (!rt || !rt.vm) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         text: "QuickJS not initialized",
  #|         exception: { type: "error" }
  #|       },
  #|       consoleEntries: []
  #|     });
  #|   }
  #|   const { vm } = rt;
  #|
  #|   // Convert value to BiDi remote value
  #|   const toBidiValue = (value, depth = 0) => {
  #|     if (depth > 10) return { type: "object" }; // Prevent infinite recursion
  #|     if (value === undefined) return { type: "undefined" };
  #|     if (value === null) return { type: "null" };
  #|
  #|     const type = typeof value;
  #|
  #|     if (type === "boolean") return { type: "boolean", value };
  #|     if (type === "number") {
  #|       if (Number.isNaN(value)) return { type: "number", value: "NaN" };
  #|       if (!Number.isFinite(value)) return { type: "number", value: value > 0 ? "Infinity" : "-Infinity" };
  #|       if (Object.is(value, -0)) return { type: "number", value: "-0" };
  #|       return { type: "number", value };
  #|     }
  #|     if (type === "string") return { type: "string", value };
  #|     if (type === "bigint") return { type: "bigint", value: String(value) };
  #|     if (type === "symbol") return { type: "symbol" };
  #|     if (type === "function") return { type: "function" };
  #|
  #|     if (Array.isArray(value)) {
  #|       return { type: "array", value: value.map(v => toBidiValue(v, depth + 1)) };
  #|     }
  #|
  #|     if (value instanceof Date) {
  #|       return { type: "date", value: value.toISOString() };
  #|     }
  #|
  #|     if (value instanceof RegExp) {
  #|       return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     }
  #|
  #|     if (value instanceof Error) {
  #|       return { type: "error", value: { type: value.name, message: value.message } };
  #|     }
  #|
  #|     // Object
  #|     if (type === "object") {
  #|       try {
  #|         const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v, depth + 1)]);
  #|         return { type: "object", value: entries };
  #|       } catch (e) {
  #|         return { type: "object" };
  #|       }
  #|     }
  #|
  #|     return { type: "undefined" };
  #|   };
  #|
  #|   try {
  #|     const result = await vm.evalCodeAsync(expression, "eval.js");
  #|
  #|     // Collect console entries from QuickJS context
  #|     let consoleEntries = [];
  #|     try {
  #|       const logsResult = vm.evalCode("JSON.stringify(globalThis.console._logs || [])");
  #|       if (!logsResult.error) {
  #|         const logsJson = vm.dump(logsResult.value);
  #|         logsResult.value.dispose();
  #|         consoleEntries = JSON.parse(logsJson).map(log => ({
  #|           level: log.level === 'log' ? 'info' : log.level,
  #|           method: log.level,
  #|           text: log.args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' '),
  #|           timestamp: Date.now()
  #|         }));
  #|         // Clear the logs
  #|         const clearResult = vm.evalCode("globalThis.console._logs = []");
  #|         if (!clearResult.error) clearResult.value.dispose();
  #|         else if (clearResult.error) clearResult.error.dispose();
  #|       } else {
  #|         logsResult.error.dispose();
  #|       }
  #|     } catch (e) {
  #|       // Ignore console collection errors
  #|     }
  #|
  #|     if (result.error) {
  #|       const error = vm.dump(result.error);
  #|       result.error.dispose();
  #|       return JSON.stringify({
  #|         type: "exception",
  #|         exceptionDetails: {
  #|           columnNumber: 0,
  #|           lineNumber: 0,
  #|           text: typeof error === "string" ? error : JSON.stringify(error),
  #|           exception: { type: "error", value: { type: error?.name || "Error" } },
  #|           stackTrace: { callFrames: [] }
  #|         },
  #|         consoleEntries
  #|       });
  #|     }
  #|
  #|     const value = vm.dump(result.value);
  #|     result.value.dispose();
  #|
  #|     return JSON.stringify({
  #|       type: "success",
  #|       result: toBidiValue(value),
  #|       consoleEntries
  #|     });
  #|   } catch (e) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: { type: "error", value: { type: e?.name || "Error" } },
  #|         stackTrace: { callFrames: [] }
  #|       },
  #|       consoleEntries: []
  #|     });
  #|   }
  #| }

///|
/// FFI: Evaluate ES module in QuickJS context
extern "js" fn quickjs_evaluate_module(code : String) -> @core.Any =
  #| async (code) => {
  #|   const { vm } = globalThis.__quickjs_runtime;
  #|   if (!vm) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: { text: "QuickJS not initialized" }
  #|     });
  #|   }
  #|
  #|   try {
  #|     const result = await vm.evalCodeAsync(code, "module.js", { type: "module" });
  #|
  #|     if (result.error) {
  #|       const error = vm.dump(result.error);
  #|       result.error.dispose();
  #|       return JSON.stringify({
  #|         type: "exception",
  #|         exceptionDetails: { text: JSON.stringify(error) }
  #|       });
  #|     }
  #|
  #|     result.value.dispose();
  #|     return JSON.stringify({ type: "success", result: { type: "undefined" } });
  #|   } catch (e) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: { text: String(e) }
  #|     });
  #|   }
  #| }

///|
/// FFI: Load HTML into QuickJS Mock DOM
extern "js" fn quickjs_load_html(html : String) -> @core.Any =
  #| async (html) => {
  #|   const { vm } = globalThis.__quickjs_runtime;
  #|   if (!vm) {
  #|     return JSON.stringify({ success: false, error: "QuickJS not initialized" });
  #|   }
  #|
  #|   // Simple HTML parser for QuickJS
  #|   const parserCode = `
  #|     (function(html) {
  #|       // Reset document
  #|       document.head._children = [];
  #|       document.body._children = [];
  #|
  #|       // Very simple HTML parsing
  #|       const tagRegex = /<(\\/?)(\\w+)([^>]*)>/g;
  #|       const attrRegex = /(\\w+)=["']([^"']*)["']/g;
  #|
  #|       let current = document.body;
  #|       let lastIndex = 0;
  #|       let match;
  #|
  #|       while ((match = tagRegex.exec(html)) !== null) {
  #|         // Add text content before this tag
  #|         const textBefore = html.slice(lastIndex, match.index).trim();
  #|         if (textBefore) {
  #|           current.appendChild(document.createTextNode(textBefore));
  #|         }
  #|         lastIndex = tagRegex.lastIndex;
  #|
  #|         const isClosing = match[1] === '/';
  #|         const tagName = match[2].toLowerCase();
  #|         const attrs = match[3];
  #|
  #|         if (isClosing) {
  #|           if (current._parent) current = current._parent;
  #|         } else {
  #|           const elem = document.createElement(tagName);
  #|
  #|           // Parse attributes
  #|           let attrMatch;
  #|           while ((attrMatch = attrRegex.exec(attrs)) !== null) {
  #|             elem.setAttribute(attrMatch[1], attrMatch[2]);
  #|           }
  #|           attrRegex.lastIndex = 0;
  #|
  #|           // Handle head/body specially
  #|           if (tagName === 'head') {
  #|             current = document.head;
  #|           } else if (tagName === 'body') {
  #|             current = document.body;
  #|           } else if (tagName === 'title') {
  #|             // Title goes to head
  #|             document.head.appendChild(elem);
  #|             current = elem;
  #|           } else if (tagName === 'script' || tagName === 'style' || tagName === 'link' || tagName === 'meta') {
  #|             // These go to current context
  #|             current.appendChild(elem);
  #|             if (!attrs.includes('/>')) current = elem;
  #|           } else if (tagName !== 'html' && tagName !== '!doctype') {
  #|             current.appendChild(elem);
  #|             // Self-closing tags
  #|             const selfClosing = ['br', 'hr', 'img', 'input', 'meta', 'link'];
  #|             if (!selfClosing.includes(tagName) && !attrs.endsWith('/')) {
  #|               current = elem;
  #|             }
  #|           }
  #|         }
  #|       }
  #|
  #|       return { success: true, bodyChildren: document.body._children.length };
  #|     })
  #|   `;
  #|
  #|   try {
  #|     // First, inject the parser function
  #|     const parserResult = await vm.evalCodeAsync(parserCode, "parser.js");
  #|     if (parserResult.error) {
  #|       const error = vm.dump(parserResult.error);
  #|       parserResult.error.dispose();
  #|       return JSON.stringify({ success: false, error: "Parser error: " + JSON.stringify(error) });
  #|     }
  #|
  #|     // Get the parser function handle
  #|     const parserFn = parserResult.value;
  #|
  #|     // Create HTML string in QuickJS
  #|     const htmlHandle = vm.newString(html);
  #|
  #|     // Call the parser
  #|     const callResult = await vm.callFunction(parserFn, vm.undefined, htmlHandle);
  #|     htmlHandle.dispose();
  #|     parserFn.dispose();
  #|
  #|     if (callResult.error) {
  #|       const error = vm.dump(callResult.error);
  #|       callResult.error.dispose();
  #|       return JSON.stringify({ success: false, error: "Parse error: " + JSON.stringify(error) });
  #|     }
  #|
  #|     const result = vm.dump(callResult.value);
  #|     callResult.value.dispose();
  #|
  #|     return JSON.stringify(result);
  #|   } catch (e) {
  #|     return JSON.stringify({ success: false, error: String(e) });
  #|   }
  #| }

///|
/// FFI: Fetch URL and load into QuickJS (uses host fetch)
extern "js" fn quickjs_fetch_and_load(url : String) -> @core.Any =
  #| async (url) => {
  #|   try {
  #|     const res = await fetch(url);
  #|     if (!res.ok) {
  #|       return JSON.stringify({ success: false, status: res.status, error: "HTTP error" });
  #|     }
  #|     const html = await res.text();
  #|
  #|     // Store page URL
  #|     globalThis.__quickjs_baseUrl = new URL(url).origin;
  #|
  #|     // Load into QuickJS
  #|     const { vm } = globalThis.__quickjs_runtime;
  #|     const setUrlCode = `globalThis.__pageUrl = "${url}";`;
  #|     const urlResult = await vm.evalCodeAsync(setUrlCode, "set-url.js");
  #|     if (urlResult.value) urlResult.value.dispose();
  #|     if (urlResult.error) urlResult.error.dispose();
  #|
  #|     // Parse HTML
  #|     const loadResult = await quickjs_load_html(html);
  #|     const parsed = JSON.parse(loadResult);
  #|
  #|     return JSON.stringify({
  #|       success: parsed.success,
  #|       url,
  #|       status: res.status,
  #|       htmlLength: html.length,
  #|       ...parsed
  #|     });
  #|   } catch (e) {
  #|     return JSON.stringify({ success: false, error: String(e) });
  #|   }
  #| }

///|
/// FFI: Evaluate expression and send result via WebSocket
extern "js" fn quickjs_eval_and_send_ws(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
) -> Unit =
  #| async (socket, requestId, expression, ctxId) => {
  #|   const rt = globalThis.__quickjs_runtime;
  #|   if (!rt || !rt.vm) {
  #|     const errorResponse = JSON.stringify({
  #|       type: "error",
  #|       id: requestId,
  #|       error: "unknown error",
  #|       message: "QuickJS not initialized"
  #|     });
  #|     socket.send(errorResponse);
  #|     return;
  #|   }
  #|   const { vm } = rt;
  #|
  #|   const toBidiValue = (value, depth = 0) => {
  #|     if (depth > 10) return { type: "object" };
  #|     if (value === undefined) return { type: "undefined" };
  #|     if (value === null) return { type: "null" };
  #|     const type = typeof value;
  #|     if (type === "boolean") return { type: "boolean", value };
  #|     if (type === "number") {
  #|       if (Number.isNaN(value)) return { type: "number", value: "NaN" };
  #|       if (!Number.isFinite(value)) return { type: "number", value: value > 0 ? "Infinity" : "-Infinity" };
  #|       if (Object.is(value, -0)) return { type: "number", value: "-0" };
  #|       return { type: "number", value };
  #|     }
  #|     if (type === "string") return { type: "string", value };
  #|     if (type === "bigint") return { type: "bigint", value: String(value) };
  #|     if (type === "symbol") return { type: "symbol" };
  #|     if (type === "function") return { type: "function" };
  #|     if (Array.isArray(value)) {
  #|       return { type: "array", value: value.map(v => toBidiValue(v, depth + 1)) };
  #|     }
  #|     if (value instanceof Date) {
  #|       return { type: "date", value: value.toISOString() };
  #|     }
  #|     if (value instanceof RegExp) {
  #|       return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     }
  #|     if (value instanceof Error) {
  #|       return { type: "error", value: { type: value.name, message: value.message } };
  #|     }
  #|     if (type === "object") {
  #|       try {
  #|         const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v, depth + 1)]);
  #|         return { type: "object", value: entries };
  #|       } catch (e) {
  #|         return { type: "object" };
  #|       }
  #|     }
  #|     return { type: "undefined" };
  #|   };
  #|
  #|   // Helper to send log events
  #|   const sendLogEvent = (entry, ctxId) => {
  #|     const event = JSON.stringify({
  #|       type: "event",
  #|       method: "log.entryAdded",
  #|       params: {
  #|         type: "console",
  #|         level: entry.level,
  #|         source: { realm: "default-realm", context: ctxId },
  #|         text: entry.text,
  #|         timestamp: entry.timestamp,
  #|         method: entry.method,
  #|         args: [{ type: "string", value: entry.text }]
  #|       }
  #|     });
  #|     socket.send(event);
  #|   };
  #|
  #|   try {
  #|     const result = await vm.evalCodeAsync(expression, "eval.js");
  #|
  #|     // Collect and send console entries
  #|     try {
  #|       const logsResult = vm.evalCode("JSON.stringify(globalThis.console._logs || [])");
  #|       if (!logsResult.error) {
  #|         const logsJson = vm.dump(logsResult.value);
  #|         logsResult.value.dispose();
  #|         const logs = JSON.parse(logsJson);
  #|         for (const log of logs) {
  #|           sendLogEvent({
  #|             level: log.level === 'log' ? 'info' : log.level,
  #|             method: log.level,
  #|             text: log.args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' '),
  #|             timestamp: Date.now()
  #|           }, ctxId);
  #|         }
  #|         const clearResult = vm.evalCode("globalThis.console._logs = []");
  #|         if (!clearResult.error) clearResult.value.dispose();
  #|         else if (clearResult.error) clearResult.error.dispose();
  #|       } else {
  #|         logsResult.error.dispose();
  #|       }
  #|     } catch (e) {
  #|       // Ignore console collection errors
  #|     }
  #|
  #|     if (result.error) {
  #|       const error = vm.dump(result.error);
  #|       result.error.dispose();
  #|       const response = JSON.stringify({
  #|         type: "success",
  #|         id: requestId,
  #|         result: {
  #|           realm: "default-realm",
  #|           exceptionDetails: {
  #|             columnNumber: 0,
  #|             lineNumber: 0,
  #|             text: typeof error === "string" ? error : JSON.stringify(error),
  #|             exception: { type: "error", value: { type: error?.name || "Error" } },
  #|             stackTrace: { callFrames: [] }
  #|           }
  #|         }
  #|       });
  #|       socket.send(response);
  #|       return;
  #|     }
  #|
  #|     const value = vm.dump(result.value);
  #|     result.value.dispose();
  #|
  #|     const response = JSON.stringify({
  #|       type: "success",
  #|       id: requestId,
  #|       result: {
  #|         realm: "default-realm",
  #|         result: toBidiValue(value)
  #|       }
  #|     });
  #|     socket.send(response);
  #|   } catch (e) {
  #|     const errorResponse = JSON.stringify({
  #|       type: "error",
  #|       id: requestId,
  #|       error: "unknown error",
  #|       message: String(e)
  #|     });
  #|     socket.send(errorResponse);
  #|   }
  #| }

///|
/// Initialize QuickJS runtime
/// Returns a promise that resolves when initialization is complete
pub fn init_quickjs() -> @core.Any {
  if quickjs_state.initialized {
    return @core.any(true)
  }
  if quickjs_state.pending_init {
    // Return existing init promise
    return @core.any(true)
  }
  quickjs_state.pending_init = true
  quickjs_init_runtime()
}

///|
/// Mark QuickJS as initialized (call after awaiting init_quickjs)
pub fn mark_quickjs_initialized() -> Unit {
  quickjs_state.initialized = true
  quickjs_state.pending_init = false
}

///|
/// Check if QuickJS is initialized
pub fn is_quickjs_initialized() -> Bool {
  quickjs_state.initialized
}

///|
/// Evaluate expression using QuickJS (sync - not recommended, use async)
pub fn quickjs_eval_sync(expression : String) -> String {
  quickjs_evaluate_sync(expression)
}

///|
/// Evaluate expression using QuickJS (async)
/// Returns a promise that resolves to BiDi-formatted JSON
pub fn quickjs_eval_async(
  expression : String,
  await_promise : Bool,
) -> @core.Any {
  quickjs_evaluate_async(expression, await_promise)
}

///|
/// Evaluate expression and send result via WebSocket
pub fn quickjs_eval_ws(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
) -> Unit {
  quickjs_eval_and_send_ws(socket, request_id, expression, ctx_id)
}

///|
/// Evaluate ES module using QuickJS
/// Returns a promise that resolves to BiDi-formatted JSON
pub fn quickjs_eval_module(code : String) -> @core.Any {
  quickjs_evaluate_module(code)
}

///|
/// Load HTML into QuickJS Mock DOM
/// Returns a promise that resolves to result JSON
pub fn quickjs_load(html : String) -> @core.Any {
  quickjs_load_html(html)
}

///|
/// Fetch URL and load into QuickJS
/// Returns a promise that resolves to result JSON
pub fn quickjs_fetch(url : String) -> @core.Any {
  quickjs_fetch_and_load(url)
}
