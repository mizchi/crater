// =============================================================================
// JavaScript Evaluation for BiDi script.evaluate
// =============================================================================

///|
/// FFI: Evaluate JavaScript expression and return BiDi remote value JSON
/// Returns: { "type": "success"|"exception", "result"|"exceptionDetails": ..., "consoleEntries": [...] }
extern "js" fn js_evaluate_expression(
  expression : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
) -> String =
  #| (expression, captureConsole, userActivation, rootOwnership, serializationOptionsJson) => {
  #|   const consoleEntries = [];
  #|   let originalConsole = null;
  #|   const resolveCurrentLogUrl = () => {
  #|     try {
  #|       if (globalThis.location && typeof globalThis.location.href === "string" && globalThis.location.href !== "") {
  #|         return String(globalThis.location.href);
  #|       }
  #|     } catch (_e) {}
  #|     try {
  #|       if (typeof globalThis.__pageUrl === "string" && globalThis.__pageUrl !== "") {
  #|         return String(globalThis.__pageUrl);
  #|       }
  #|     } catch (_e) {}
  #|     return "about:blank";
  #|   };
  #|   const resolveInlineScriptOffsets = () => {
  #|     const url = resolveCurrentLogUrl();
  #|     if (!url.startsWith("data:")) {
  #|       return { lineOffset: 0, columnOffset: 0 };
  #|     }
  #|     try {
  #|       const comma = url.indexOf(",");
  #|       if (comma < 0) return { lineOffset: 0, columnOffset: 0 };
  #|       const meta = url.slice(0, comma).toLowerCase();
  #|       const payload = url.slice(comma + 1);
  #|       let decoded = "";
  #|       if (meta.includes(";base64")) {
  #|         decoded = atob(payload);
  #|       } else {
  #|         decoded = decodeURIComponent(payload);
  #|       }
  #|       const lines = decoded.replace(/\r\n/g, "\n").split("\n");
  #|       let inScript = false;
  #|       for (let index = 0; index < lines.length; index++) {
  #|         const line = String(lines[index] || "");
  #|         const lower = line.toLowerCase();
  #|         if (!inScript) {
  #|           if (lower.includes("<script")) {
  #|             inScript = true;
  #|           }
  #|           continue;
  #|         }
  #|         if (lower.includes("</script")) break;
  #|         if (line.trim() === "") continue;
  #|         const indentMatch = line.match(/^(\s*)/);
  #|         return {
  #|           lineOffset: index + 1,
  #|           columnOffset: indentMatch ? indentMatch[1].length : 0,
  #|         };
  #|       }
  #|     } catch (_e) {}
  #|     return { lineOffset: 0, columnOffset: 0 };
  #|   };
  #|   const inlineScriptOffsets = resolveInlineScriptOffsets();
  #|   const buildStackTraceFromStack = (stackText) => {
  #|     const frames = [];
  #|     const stack = String(stackText || "");
  #|     const lines = stack.split("\n");
  #|     for (let i = 0; i < lines.length; i++) {
  #|       const rawLine = String(lines[i] || "").trim();
  #|       if (!rawLine.startsWith("at ")) continue;
  #|       const body = rawLine.slice(3);
  #|       let functionName = "";
  #|       let location = body;
  #|       const withParens = body.match(/^(.*?)\s+\((.*)\)$/);
  #|       if (withParens) {
  #|         functionName = String(withParens[1] || "");
  #|         location = String(withParens[2] || "");
  #|       } else {
  #|         functionName = "";
  #|         location = body;
  #|       }
  #|       if (
  #|         functionName.includes("pushConsoleEntry") ||
  #|         functionName.includes("makeInterceptor")
  #|       ) {
  #|         continue;
  #|       }
  #|       let lineNumber = 0;
  #|       let columnNumber = 0;
  #|       let url = resolveCurrentLogUrl();
  #|       const anonymousLocationMatch = location.match(/<anonymous>:(\d+):(\d+)$/);
  #|       if (anonymousLocationMatch) {
  #|         const leadingColumnOffset = frames.length === 0
  #|           ? Number(inlineScriptOffsets.columnOffset || 0)
  #|           : 0;
  #|         lineNumber = Number(anonymousLocationMatch[1]) + Number(inlineScriptOffsets.lineOffset || 0);
  #|         columnNumber = Math.max(
  #|           0,
  #|           Number(anonymousLocationMatch[2]) + leadingColumnOffset - 1,
  #|         );
  #|       } else {
  #|         const locationMatch = location.match(/^(.*):(\d+):(\d+)$/);
  #|         if (!locationMatch) continue;
  #|         url = String(locationMatch[1] || "");
  #|         if (url.includes("bidi_main.js")) continue;
  #|         lineNumber = Number(locationMatch[2]);
  #|         columnNumber = Math.max(0, Number(locationMatch[3]) - 1);
  #|       }
  #|       if (functionName === "eval") {
  #|         functionName = "";
  #|       }
  #|       frames.push({
  #|         columnNumber,
  #|         functionName,
  #|         lineNumber,
  #|         url,
  #|       });
  #|       if (frames.length >= 3) break;
  #|     }
  #|     return { callFrames: frames };
  #|   };
  #|   const pushJavascriptErrorEntry = (errorValue) => {
  #|     if (!captureConsole) return;
  #|     const stackTrace = buildStackTraceFromStack(errorValue && errorValue.stack ? errorValue.stack : "");
  #|     const entry = {
  #|       type: "javascript",
  #|       level: "error",
  #|       text: String(errorValue),
  #|       timestamp: Date.now(),
  #|       realm: String(globalThis.__bidiCurrentRealm || ""),
  #|     };
  #|     if (Array.isArray(stackTrace.callFrames) && stackTrace.callFrames.length > 0) {
  #|       entry.stackTrace = stackTrace;
  #|     }
  #|     consoleEntries.push(entry);
  #|   };
  #|   globalThis.__bidiPushJavascriptErrorEntry = pushJavascriptErrorEntry;
  #|   if (captureConsole) {
  #|     originalConsole = {
  #|       target: console,
  #|       log: console.log,
  #|       warn: console.warn,
  #|       error: console.error,
  #|       info: console.info,
  #|       debug: console.debug,
  #|       assert: console.assert,
  #|       table: console.table,
  #|       trace: console.trace,
  #|       time: console.time,
  #|       timeEnd: console.timeEnd
  #|     };
  #|
  #|     const consoleArgToText = (arg) => {
  #|       if (typeof arg === "string") return arg;
  #|       if (arg === undefined) return "undefined";
  #|       if (typeof arg === "bigint") return `${arg}n`;
  #|       try {
  #|         const json = JSON.stringify(arg);
  #|         if (json !== undefined) return json;
  #|       } catch (_e) {}
  #|       return String(arg);
  #|     };
  #|
  #|     const pushConsoleEntry = (level, method, args, textArgs = args) => {
  #|       const stackTrace = buildStackTraceFromStack(new Error().stack || "");
  #|       const entry = {
  #|         type: "console",
  #|         level,
  #|         method,
  #|         text: textArgs.map(consoleArgToText).join(" "),
  #|         args: args.map(toBidiValue),
  #|         timestamp: Date.now(),
  #|         realm: String(globalThis.__bidiCurrentRealm || ""),
  #|       };
  #|       if (Array.isArray(stackTrace.callFrames) && stackTrace.callFrames.length > 0) {
  #|         entry.stackTrace = stackTrace;
  #|       }
  #|       consoleEntries.push(entry);
  #|     };
  #|
  #|     // Intercept console calls
  #|     const makeInterceptor = (level, method) => (...args) => {
  #|       pushConsoleEntry(level, method, args);
  #|     };
  #|
  #|     console.log = makeInterceptor('info', 'log');
  #|     console.warn = makeInterceptor('warn', 'warn');
  #|     console.error = makeInterceptor('error', 'error');
  #|     console.info = makeInterceptor('info', 'info');
  #|     console.debug = makeInterceptor('debug', 'debug');
  #|     console.table = makeInterceptor('info', 'table');
  #|     console.trace = makeInterceptor('debug', 'trace');
  #|     console.assert = (...args) => {
  #|       if (args.length > 0 && args[0]) {
  #|         return;
  #|       }
  #|       const textArgs = args.length > 1 ? args.slice(1) : ["Assertion failed"];
  #|       pushConsoleEntry("error", "assert", textArgs);
  #|     };
  #|     console.time = (...args) => {
  #|     };
  #|     console.timeEnd = (...args) => {
  #|       const textArgs = args.length > 0 ? args : ["default"];
  #|       pushConsoleEntry("info", "timeEnd", textArgs);
  #|     };
  #|   }
  #|
  #|   let serializationOptions = {};
  #|   try {
  #|     serializationOptions =
  #|       serializationOptionsJson && serializationOptionsJson.length > 0
  #|         ? JSON.parse(serializationOptionsJson)
  #|         : {};
  #|   } catch (_e) {
  #|     serializationOptions = {};
  #|   }
  #|   const hasMaxDomDepth = Object.prototype.hasOwnProperty.call(serializationOptions, "maxDomDepth");
  #|   const hasMaxObjectDepth = Object.prototype.hasOwnProperty.call(serializationOptions, "maxObjectDepth");
  #|   const rawMaxDomDepth = hasMaxDomDepth ? serializationOptions.maxDomDepth : undefined;
  #|   const rawMaxObjectDepth = hasMaxObjectDepth ? serializationOptions.maxObjectDepth : undefined;
  #|   const maxDomDepth =
  #|     rawMaxDomDepth === null
  #|       ? null
  #|       : (typeof rawMaxDomDepth === "number" && rawMaxDomDepth >= 0 ? rawMaxDomDepth : undefined);
  #|   const maxObjectDepth =
  #|     rawMaxObjectDepth === null
  #|       ? null
  #|       : (typeof rawMaxObjectDepth === "number" && rawMaxObjectDepth >= 0 ? rawMaxObjectDepth : undefined);
  #|   const includeShadowTree =
  #|     serializationOptions.includeShadowTree === "open" || serializationOptions.includeShadowTree === "all"
  #|       ? serializationOptions.includeShadowTree
  #|       : "none";
  #|
  #|   const applyUserActivation = (active) => {
  #|     const isActive = !!active;
  #|     globalThis.__bidiUserActivation = isActive;
  #|     if (!globalThis.navigator) globalThis.navigator = {};
  #|     globalThis.navigator.userActivation = {
  #|       isActive,
  #|       hasBeenActive: isActive
  #|     };
  #|     if (globalThis.document) {
  #|       globalThis.document.execCommand = function(command) {
  #|         const cmd = String(command || '').toLowerCase();
  #|         if (cmd === 'selectall') return true;
  #|         if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|         return false;
  #|       };
  #|     }
  #|     if (globalThis.document && typeof globalThis.__bidiEnsureDocumentRange === "function") {
  #|       globalThis.__bidiEnsureDocumentRange(globalThis.document);
  #|       if (globalThis.window && typeof globalThis.window === "object") {
  #|         globalThis.window.document = globalThis.document;
  #|       }
  #|     }
  #|   };
  #|
  #|   const installWindowGlobalSync = () => {
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") return;
  #|     const reserved = new Set([
  #|       "window", "self", "parent", "top", "frames",
  #|       "document", "location", "navigator", "history",
  #|       "screen", "matchMedia",
  #|       "innerWidth", "innerHeight", "outerWidth", "outerHeight",
  #|       "devicePixelRatio", "pageXOffset", "pageYOffset",
  #|       "localStorage", "sessionStorage",
  #|       "alert", "confirm", "prompt", "console", "performance", "crypto",
  #|       "setTimeout", "clearTimeout", "setInterval", "clearInterval",
  #|       "requestAnimationFrame", "cancelAnimationFrame", "queueMicrotask",
  #|       "fetch", "Response", "Request", "Headers", "Blob", "FormData",
  #|       "URL", "URLSearchParams",
  #|       "getComputedStyle", "matchMedia", "Event", "UIEvent", "MouseEvent",
  #|       "PointerEvent", "FocusEvent", "KeyboardEvent", "InputEvent",
  #|       "CompositionEvent", "CustomEvent", "MessageEvent", "StorageEvent",
  #|       "DragEvent", "ClipboardEvent", "DataTransfer", "DOMParser",
  #|       "DOMException", "Node", "Attr", "Element", "HTMLElement", "Document",
  #|       // Observer APIs shimmed by bidi_runtime_eval.mbt. Without these in
  #|       // the reserved set, the per-eval window→globalThis sync would
  #|       // delete them (when window doesn't carry them) right before the
  #|       // user expression runs.
  #|       "IntersectionObserver", "ResizeObserver", "MutationObserver",
  #|       // Network primitives provided natively by Node 22+. Reserving them
  #|       // ensures the per-eval sync doesn't drop the WebSocket / EventSource
  #|       // constructors that real-time apps need.
  #|       "WebSocket", "EventSource",
  #|     ]);
  #|     globalThis.__bidiSyncWindowPropertiesToGlobal = (win) => {
  #|       const source = win && typeof win === "object" ? win : globalThis.window;
  #|       if (!source || source === globalThis || typeof source !== "object") return;
  #|       const syncedKeys = globalThis.__bidiSyncedWindowKeys instanceof Set
  #|         ? globalThis.__bidiSyncedWindowKeys
  #|         : (globalThis.__bidiSyncedWindowKeys = new Set());
  #|       for (const key of Array.from(syncedKeys)) {
  #|         if (reserved.has(key) || String(key).startsWith("__bidi")) {
  #|           syncedKeys.delete(key);
  #|           continue;
  #|         }
  #|         if (!Object.prototype.hasOwnProperty.call(source, key)) {
  #|           try { delete globalThis[key]; } catch (_e) {}
  #|           syncedKeys.delete(key);
  #|         }
  #|       }
  #|       for (const key of Object.keys(source)) {
  #|         if (reserved.has(key) || String(key).startsWith("__bidi")) continue;
  #|         let value;
  #|         try { value = source[key]; } catch (_e) { continue; }
  #|         try {
  #|           Object.defineProperty(globalThis, key, {
  #|             configurable: true,
  #|             enumerable: true,
  #|             writable: true,
  #|             value,
  #|           });
  #|         } catch (_e) {
  #|           try { globalThis[key] = value; } catch (_e2) {}
  #|         }
  #|         syncedKeys.add(key);
  #|       }
  #|     };
  #|   };
  #|   installWindowGlobalSync();
  #|   const installContextWindowApi = () => {
  #|     if (typeof globalThis.__bidiInstallContextWindowApi === "function") return;
  #|     const nativeTimers = globalThis.__bidiNativeWindowTimers || {
  #|       setTimeout: typeof globalThis.setTimeout === "function" ? globalThis.setTimeout : undefined,
  #|       clearTimeout: typeof globalThis.clearTimeout === "function" ? globalThis.clearTimeout : undefined,
  #|       setInterval: typeof globalThis.setInterval === "function" ? globalThis.setInterval : undefined,
  #|       clearInterval: typeof globalThis.clearInterval === "function" ? globalThis.clearInterval : undefined,
  #|       queueMicrotask: typeof globalThis.queueMicrotask === "function" ? globalThis.queueMicrotask : undefined,
  #|       requestAnimationFrame: typeof globalThis.requestAnimationFrame === "function" ? globalThis.requestAnimationFrame : undefined,
  #|       cancelAnimationFrame: typeof globalThis.cancelAnimationFrame === "function" ? globalThis.cancelAnimationFrame : undefined,
  #|     };
  #|     globalThis.__bidiNativeWindowTimers = nativeTimers;
  #|     const nativeFetch = globalThis.__bidiNativeWindowFetch || (
  #|       typeof globalThis.fetch === "function" ? globalThis.fetch : undefined
  #|     );
  #|     globalThis.__bidiNativeWindowFetch = nativeFetch;
  #|     const bindNative = (name, fallback) => {
  #|       const fn = nativeTimers[name];
  #|       return typeof fn === "function" ? fn.bind(globalThis) : fallback;
  #|     };
  #|     globalThis.__bidiInstallContextWindowApi = (win) => {
  #|       if (!win || typeof win !== "object") return win;
  #|       win.window = win;
  #|       win.self = win;
  #|       if (!win.parent) win.parent = win;
  #|       if (!win.top) win.top = win;
  #|       win.setTimeout = bindNative("setTimeout", (handler, timeout) => {
  #|         if (typeof handler === "function") handler();
  #|         return 0;
  #|       });
  #|       win.clearTimeout = bindNative("clearTimeout", (_id) => undefined);
  #|       win.setInterval = bindNative("setInterval", win.setTimeout);
  #|       win.clearInterval = bindNative("clearInterval", win.clearTimeout);
  #|       win.queueMicrotask = bindNative("queueMicrotask", (callback) => Promise.resolve().then(callback));
  #|       win.requestAnimationFrame = bindNative("requestAnimationFrame", (callback) =>
  #|         win.setTimeout(() => {
  #|           if (typeof callback === "function") callback(Date.now());
  #|         }, 16)
  #|       );
  #|       win.cancelAnimationFrame = bindNative("cancelAnimationFrame", win.clearTimeout);
  #|       win.fetch = function(url, options) {
  #|         const fetchFn = globalThis.__craterUseObservableFetch
  #|           ? (globalThis.__craterObservableFetch || globalThis.__fetchInternal)
  #|           : globalThis.__fetchInternal;
  #|         const fallback = globalThis.fetch !== win.fetch ? globalThis.fetch : nativeFetch;
  #|         const target = fetchFn || fallback;
  #|         if (typeof target !== "function") return Promise.reject(new TypeError("fetch is not available"));
  #|         return target.call(globalThis, url, options);
  #|       };
  #|       for (const name of [
  #|         "Response", "Request", "Headers", "Blob", "FormData", "URL", "URLSearchParams",
  #|         "getComputedStyle", "matchMedia", "Event", "UIEvent", "MouseEvent", "PointerEvent",
  #|         "FocusEvent", "KeyboardEvent", "InputEvent", "CompositionEvent", "CustomEvent",
  #|         "MessageEvent", "StorageEvent", "DragEvent", "ClipboardEvent", "DataTransfer",
  #|         "DOMParser", "DOMException", "Node", "Attr", "Element", "HTMLElement", "Document",
  #|       ]) {
  #|         if (win[name] === undefined && globalThis[name] !== undefined) win[name] = globalThis[name];
  #|       }
  #|       return win;
  #|     };
  #|   };
  #|   installContextWindowApi();
  #|
  #|   // Setup Mock DOM if not already present
  #|   if (!globalThis.document) {
  #|     // MutationObserver implementation
  #|     const _mutationObservers = [];
  #|     let _mutationScheduled = false;
  #|     const _pendingMutations = new Map();
  #|
  #|     const shouldNotify = (mutatedNode, observedTarget, options, type) => {
  #|       if (type === 'childList' && !options.childList) return false;
  #|       if (type === 'attributes' && !options.attributes) return false;
  #|       if (type === 'characterData' && !options.characterData) return false;
  #|       if (mutatedNode === observedTarget) return true;
  #|       if (options.subtree) {
  #|         let node = mutatedNode;
  #|         while (node) {
  #|           if (node === observedTarget) return true;
  #|           node = node._parent;
  #|         }
  #|       }
  #|       return false;
  #|     };
  #|
  #|     const createMutationRecord = (type, target, opts = {}) => ({
  #|       type,
  #|       target,
  #|       addedNodes: opts.addedNodes || [],
  #|       removedNodes: opts.removedNodes || [],
  #|       previousSibling: opts.previousSibling || null,
  #|       nextSibling: opts.nextSibling || null,
  #|       attributeName: opts.attributeName || null,
  #|       attributeNamespace: opts.attributeNamespace || null,
  #|       oldValue: opts.oldValue || null
  #|     });
  #|
  #|     const notifyMutation = (record) => {
  #|       for (const observer of _mutationObservers) {
  #|         for (const { target, options } of observer._targets) {
  #|           if (shouldNotify(record.target, target, options, record.type)) {
  #|             if (!_pendingMutations.has(observer)) {
  #|               _pendingMutations.set(observer, []);
  #|             }
  #|             _pendingMutations.get(observer).push(record);
  #|             break;
  #|           }
  #|         }
  #|       }
  #|       // Schedule microtask to batch notifications
  #|       if (!_mutationScheduled && _pendingMutations.size > 0) {
  #|         _mutationScheduled = true;
  #|         // Use Promise.resolve for microtask scheduling (works in Deno)
  #|         Promise.resolve().then(() => {
  #|           _mutationScheduled = false;
  #|           for (const [observer, records] of _pendingMutations) {
  #|             if (records.length > 0) {
  #|               try {
  #|                 observer._callback(records, observer);
  #|               } catch (e) {
  #|                 console.error('MutationObserver callback error:', e);
  #|               }
  #|             }
  #|           }
  #|           _pendingMutations.clear();
  #|         });
  #|       }
  #|     };
  #|
  #|     globalThis.MutationObserver = class MutationObserver {
  #|       constructor(callback) {
  #|         this._callback = callback;
  #|         this._targets = [];
  #|       }
  #|       observe(target, options = {}) {
  #|         this._targets.push({ target, options });
  #|         if (!_mutationObservers.includes(this)) {
  #|           _mutationObservers.push(this);
  #|         }
  #|       }
  #|       disconnect() {
  #|         this._targets = [];
  #|         const idx = _mutationObservers.indexOf(this);
  #|         if (idx !== -1) _mutationObservers.splice(idx, 1);
  #|         _pendingMutations.delete(this);
  #|       }
  #|       takeRecords() {
  #|         const records = _pendingMutations.get(this) || [];
  #|         _pendingMutations.delete(this);
  #|         return records;
  #|       }
  #|     };
  #|
  #|     const toCollection = (items, collectionType) => {
  #|       if (!Array.isArray(items)) return items;
  #|       if (collectionType) {
  #|         Object.defineProperty(items, "__bidiCollectionType", {
  #|           value: String(collectionType),
  #|           configurable: true,
  #|           enumerable: false,
  #|           writable: true
  #|         });
  #|       }
  #|       if (typeof items.item !== "function") {
  #|         items.item = function(index) {
  #|           return this[index] ?? null;
  #|         };
  #|       }
  #|       return items;
  #|     };
  #|
  #|     // Minimal Mock DOM for Preact compatibility
  #|     const getContainingShadowRoot = (node) => {
  #|       let current = node;
  #|       while (current) {
  #|         if (current._isShadowRoot) return current;
  #|         current = current._parent || current.parentNode || null;
  #|       }
  #|       return null;
  #|     };
  #|     const getFocusAttr = (node, name) => {
  #|       if (!node || typeof node !== "object") return null;
  #|       try {
  #|         if (typeof node.getAttribute === "function") {
  #|           const value = node.getAttribute(name);
  #|           if (value !== null && value !== undefined) return String(value);
  #|         }
  #|       } catch (_e) {}
  #|       if (node._attrs && Object.prototype.hasOwnProperty.call(node._attrs, name)) {
  #|         const value = node._attrs[name];
  #|         return value === null || value === undefined ? null : String(value);
  #|       }
  #|       return null;
  #|     };
  #|     const getFocusChildren = (node) => {
  #|       if (!node || typeof node !== "object") return [];
  #|       if (Array.isArray(node._children)) return node._children;
  #|       if (Array.isArray(node.children)) return Array.from(node.children);
  #|       if (Array.isArray(node.childNodes)) return Array.from(node.childNodes);
  #|       return [];
  #|     };
  #|     const nodeContains = (root, node) => {
  #|       if (!root || !node) return false;
  #|       if (root === node) return true;
  #|       try {
  #|         if (typeof root.contains === "function") return !!root.contains(node);
  #|       } catch (_e) {}
  #|       const children = getFocusChildren(root);
  #|       for (let i = 0; i < children.length; i += 1) {
  #|         if (nodeContains(children[i], node)) return true;
  #|       }
  #|       return false;
  #|     };
  #|     const isSlotElementForFocus = (node) => {
  #|       if (!node || node.nodeType !== 1) return false;
  #|       const localName = String(node.localName || node.tagName || node.nodeName || "").toLowerCase();
  #|       return localName === "slot";
  #|     };
  #|     const findFirstSlotForFocusName = (root, slotName) => {
  #|       const children = getFocusChildren(root);
  #|       for (let i = 0; i < children.length; i += 1) {
  #|         const child = children[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (isSlotElementForFocus(child) && String(getFocusAttr(child, "name") || "") === slotName) {
  #|           return child;
  #|         }
  #|         const nested = findFirstSlotForFocusName(child, slotName);
  #|         if (nested) return nested;
  #|       }
  #|       return null;
  #|     };
  #|     const getAssignedChildrenForFocusSlot = (slot) => {
  #|       const shadowRoot = getContainingShadowRoot(slot);
  #|       if (!shadowRoot || !shadowRoot.host) return getFocusChildren(slot);
  #|       const slotName = String(getFocusAttr(slot, "name") || "");
  #|       const firstMatch = findFirstSlotForFocusName(shadowRoot, slotName);
  #|       if (firstMatch && firstMatch !== slot) return [];
  #|       const assigned = [];
  #|       const hostChildren = getFocusChildren(shadowRoot.host);
  #|       for (let i = 0; i < hostChildren.length; i += 1) {
  #|         const child = hostChildren[i];
  #|         if (!child) continue;
  #|         const childSlotName = String(getFocusAttr(child, "slot") || "");
  #|         if (childSlotName === slotName) assigned.push(child);
  #|       }
  #|       return assigned.length > 0 ? assigned : getFocusChildren(slot);
  #|     };
  #|     const getDelegatesFocusChildren = (node) => {
  #|       if (!node || typeof node !== "object") return [];
  #|       if (isSlotElementForFocus(node)) return getAssignedChildrenForFocusSlot(node);
  #|       const shadowRoot = node.shadowRoot || null;
  #|       if (shadowRoot) return getFocusChildren(shadowRoot);
  #|       return getFocusChildren(node);
  #|     };
  #|     const hasExplicitSequentialTabIndexForFocus = (node) => {
  #|       if (!node || typeof node !== "object") return false;
  #|       try {
  #|         if (typeof node.getAttribute === "function" && node.getAttribute("tabindex") !== null) {
  #|           return true;
  #|         }
  #|       } catch (_e) {}
  #|       return !!(node._attrs && Object.prototype.hasOwnProperty.call(node._attrs, "tabindex"));
  #|     };
  #|     const isSequentiallyFocusableForFocus = (node) => {
  #|       if (!node || node.nodeType !== 1) return false;
  #|       if (node.disabled || node.hidden) return false;
  #|       const style = node.style || {};
  #|       if (style.display === "none" || style.visibility === "hidden") return false;
  #|       if (hasExplicitSequentialTabIndexForFocus(node)) {
  #|         try {
  #|           return Number(node.tabIndex) >= 0;
  #|         } catch (_e) {
  #|           return false;
  #|         }
  #|       }
  #|       const tag = String(node.tagName || node.nodeName || "").toLowerCase();
  #|       if (["input", "textarea", "select", "button"].includes(tag)) return true;
  #|       if (tag === "a") {
  #|         try {
  #|           return !!(typeof node.getAttribute === "function" ? node.getAttribute("href") : null);
  #|         } catch (_e) {
  #|           return false;
  #|         }
  #|       }
  #|       return !!node.isContentEditable;
  #|     };
  #|     const findDelegatesFocusTarget = (node) => {
  #|       const shadowRoot = node && node.shadowRoot ? node.shadowRoot : null;
  #|       if (!shadowRoot || !shadowRoot.delegatesFocus) return null;
  #|       const visit = (current) => {
  #|         const children = getDelegatesFocusChildren(current);
  #|         for (let i = 0; i < children.length; i += 1) {
  #|           const child = children[i];
  #|           if (!child || child.nodeType !== 1) continue;
  #|           if (isSequentiallyFocusableForFocus(child)) return child;
  #|           const nested = visit(child);
  #|           if (nested) return nested;
  #|         }
  #|         return null;
  #|       };
  #|       return visit(shadowRoot);
  #|     };
  #|     const clearDocumentActiveChain = (doc) => {
  #|       if (!doc) return;
  #|       const current = doc.activeElement || null;
  #|       if (current && current.shadowRoot && current.shadowRoot.activeElement) {
  #|         current.shadowRoot.activeElement = null;
  #|       }
  #|       doc.activeElement = doc.body || null;
  #|     };
  #|     const getDeepActiveElement = (doc) => {
  #|       if (!doc) return null;
  #|       let current = doc.activeElement || null;
  #|       const visited = new Set();
  #|       while (current && !visited.has(current)) {
  #|         visited.add(current);
  #|         const next =
  #|           current.shadowRoot && current.shadowRoot.activeElement
  #|             ? current.shadowRoot.activeElement
  #|             : null;
  #|         if (!next) break;
  #|         current = next;
  #|       }
  #|       return current;
  #|     };
  #|     const retargetEventTarget = (originalTarget, currentTarget) => {
  #|       let candidate = originalTarget;
  #|       while (candidate) {
  #|         const shadowRoot = getContainingShadowRoot(candidate);
  #|         if (!shadowRoot) return candidate;
  #|         if (currentTarget === shadowRoot || nodeContains(shadowRoot, currentTarget)) {
  #|           return candidate;
  #|         }
  #|         candidate = shadowRoot.host || candidate;
  #|         if (!shadowRoot.host) return candidate;
  #|       }
  #|       return originalTarget;
  #|     };
  #|     const prepareEventForCurrentTarget = (event, currentTarget) => {
  #|       const originalTarget = event.__originalTarget || event.target || currentTarget;
  #|       const originalRelatedTarget =
  #|         event.__originalRelatedTarget !== undefined
  #|           ? event.__originalRelatedTarget
  #|           : (event.relatedTarget || null);
  #|       event.__originalTarget = originalTarget;
  #|       event.__originalRelatedTarget = originalRelatedTarget;
  #|       const adjustedTarget = retargetEventTarget(originalTarget, currentTarget);
  #|       const adjustedRelatedTarget = originalRelatedTarget
  #|         ? retargetEventTarget(originalRelatedTarget, currentTarget)
  #|         : null;
  #|       event.__retargetSuppressed =
  #|         !!(adjustedTarget && adjustedRelatedTarget && adjustedTarget === adjustedRelatedTarget);
  #|       try { event.target = adjustedTarget; } catch (_e) {}
  #|       try { event.relatedTarget = adjustedRelatedTarget; } catch (_e) {}
  #|       try { event.currentTarget = currentTarget; } catch (_e) {}
  #|     };
  #|     const dispatchFocusFamilyEvent = (target, type, bubbles, relatedTarget) => {
  #|       if (!target || typeof target.dispatchEvent !== "function") return;
  #|       const event = globalThis.__bidiCreateEvent(type, {
  #|         bubbles: !!bubbles,
  #|         cancelable: false,
  #|       });
  #|       event.relatedTarget = relatedTarget || null;
  #|       event.__originalRelatedTarget = relatedTarget || null;
  #|       target.dispatchEvent(event);
  #|     };
  #|     const focusNode = (node) => {
  #|       const doc = node && node.ownerDocument ? node.ownerDocument : globalThis.document;
  #|       if (!doc) return;
  #|       const delegatedTarget = findDelegatesFocusTarget(node);
  #|       if (delegatedTarget && delegatedTarget !== node) {
  #|         focusNode(delegatedTarget);
  #|         return;
  #|       }
  #|       const previous = getDeepActiveElement(doc);
  #|       if (previous === node) return;
  #|       if (previous) {
  #|         dispatchFocusFamilyEvent(previous, "blur", false, node);
  #|         dispatchFocusFamilyEvent(previous, "focusout", true, node);
  #|       }
  #|       clearDocumentActiveChain(doc);
  #|       const shadowRoot = getContainingShadowRoot(node);
  #|       if (shadowRoot && shadowRoot.host) {
  #|         shadowRoot.activeElement = node;
  #|         doc.activeElement = shadowRoot.host;
  #|       } else {
  #|         doc.activeElement = node;
  #|       }
  #|       dispatchFocusFamilyEvent(node, "focus", false, previous);
  #|       dispatchFocusFamilyEvent(node, "focusin", true, previous);
  #|     };
  #|     const blurNode = (node) => {
  #|       const doc = node && node.ownerDocument ? node.ownerDocument : globalThis.document;
  #|       if (!doc) return;
  #|       let target = node;
  #|       const ownShadowRoot = node && node.shadowRoot ? node.shadowRoot : null;
  #|       if (ownShadowRoot && ownShadowRoot.activeElement) {
  #|         target = ownShadowRoot.activeElement;
  #|       }
  #|       const active = getDeepActiveElement(doc);
  #|       if (active && active !== target && active !== node) return;
  #|       const shadowRoot = getContainingShadowRoot(target);
  #|       dispatchFocusFamilyEvent(target, "blur", false, null);
  #|       dispatchFocusFamilyEvent(target, "focusout", true, null);
  #|       if (shadowRoot && shadowRoot.activeElement === target) {
  #|         shadowRoot.activeElement = null;
  #|         if (doc.activeElement === shadowRoot.host) {
  #|           doc.activeElement = doc.body || null;
  #|         }
  #|       }
  #|       if (doc.activeElement === target || doc.activeElement === node) {
  #|         doc.activeElement = doc.body || null;
  #|       }
  #|     };
  #|
  #|     const toCamelStyleName = (name) =>
  #|       String(name || "").replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  #|     const toKebabStyleName = (name) =>
  #|       String(name || "").replace(/([A-Z])/g, "-$1").toLowerCase();
  #|     const getStylePropertyValue = (style, name) => {
  #|       const prop = String(name || "");
  #|       if (!prop) return "";
  #|       if (prop.startsWith("--")) return style[prop] ?? "";
  #|       const camel = toCamelStyleName(prop);
  #|       const kebab = toKebabStyleName(prop);
  #|       return style[prop] ?? style[camel] ?? style[kebab] ?? "";
  #|     };
  #|     const setStylePropertyValue = (style, name, value) => {
  #|       const prop = String(name || "");
  #|       if (!prop) return;
  #|       const next = value == null ? "" : String(value);
  #|       if (prop.startsWith("--")) {
  #|         style[prop] = next;
  #|         return;
  #|       }
  #|       const camel = toCamelStyleName(prop);
  #|       const kebab = toKebabStyleName(prop);
  #|       style[prop] = next;
  #|       style[camel] = next;
  #|       style[kebab] = next;
  #|     };
  #|     const removeStylePropertyValue = (style, name) => {
  #|       const prop = String(name || "");
  #|       const previous = getStylePropertyValue(style, prop);
  #|       if (!prop) return previous;
  #|       if (prop.startsWith("--")) {
  #|         delete style[prop];
  #|         return previous;
  #|       }
  #|       delete style[prop];
  #|       delete style[toCamelStyleName(prop)];
  #|       delete style[toKebabStyleName(prop)];
  #|       return previous;
  #|     };
  #|     const clearStyleProperties = (style) => {
  #|       for (const key of Object.keys(style)) delete style[key];
  #|     };
  #|     const parseStyleTextInto = (style, text) => {
  #|       clearStyleProperties(style);
  #|       String(text || "").split(";").forEach((part) => {
  #|         const index = part.indexOf(":");
  #|         if (index < 0) return;
  #|         const prop = part.slice(0, index).trim();
  #|         const value = part.slice(index + 1).trim();
  #|         if (prop) setStylePropertyValue(style, prop, value);
  #|       });
  #|     };
  #|     const serializeStyleText = (style) => {
  #|       const seen = new Set();
  #|       const parts = [];
  #|       for (const key of Object.keys(style)) {
  #|         const prop = key.startsWith("--") ? key : toKebabStyleName(key);
  #|         if (!prop || seen.has(prop)) continue;
  #|         seen.add(prop);
  #|         const value = getStylePropertyValue(style, key);
  #|         if (value !== "") parts.push(`${prop}: ${value};`);
  #|       }
  #|       return parts.join(" ");
  #|     };
  #|     const createStyleDeclaration = (element) => {
  #|       const style = element._style || (element._style = {});
  #|       return new Proxy(style, {
  #|         get(target, prop) {
  #|           if (prop === "setProperty") {
  #|             return (name, value) => setStylePropertyValue(target, name, value);
  #|           }
  #|           if (prop === "getPropertyValue") {
  #|             return (name) => getStylePropertyValue(target, name);
  #|           }
  #|           if (prop === "removeProperty") {
  #|             return (name) => removeStylePropertyValue(target, name);
  #|           }
  #|           if (prop === "cssText") return serializeStyleText(target);
  #|           if (prop === "item") {
  #|             return (index) => Object.keys(target)[Number(index)] || "";
  #|           }
  #|           if (prop === "length") return Object.keys(target).length;
  #|           if (typeof prop !== "string") return target[prop];
  #|           return getStylePropertyValue(target, prop);
  #|         },
  #|         set(target, prop, value) {
  #|           if (prop === "cssText") {
  #|             parseStyleTextInto(target, value);
  #|             return true;
  #|           }
  #|           if (typeof prop !== "string") {
  #|             target[prop] = value;
  #|             return true;
  #|           }
  #|           setStylePropertyValue(target, prop, value);
  #|           return true;
  #|         },
  #|         has(target, prop) {
  #|           if (typeof prop !== "string") return prop in target;
  #|           return prop in target || getStylePropertyValue(target, prop) !== "";
  #|         },
  #|         ownKeys(target) {
  #|           return Reflect.ownKeys(target);
  #|         },
  #|         getOwnPropertyDescriptor(target, prop) {
  #|           if (typeof prop !== "string") return Object.getOwnPropertyDescriptor(target, prop);
  #|           return {
  #|             value: getStylePropertyValue(target, prop),
  #|             writable: true,
  #|             enumerable: true,
  #|             configurable: true,
  #|           };
  #|         }
  #|       });
  #|     };
  #|
  #|     // ---- HTML form submission helpers (used by createMockElement('form')) ----
  #|     const descendsFrom = (node, ancestor) => {
  #|       let cur = node && (node._parent || node.parentNode || null);
  #|       while (cur) {
  #|         if (cur === ancestor) return true;
  #|         cur = cur._parent || cur.parentNode || null;
  #|       }
  #|       return false;
  #|     };
  #|     const collectFormControls = (formEl) => {
  #|       const out = [];
  #|       const stack = [formEl];
  #|       const allowed = new Set(['INPUT', 'SELECT', 'TEXTAREA', 'BUTTON']);
  #|       while (stack.length) {
  #|         const node = stack.pop();
  #|         if (!node) continue;
  #|         const kids = node._children || node.childNodes || [];
  #|         for (let i = kids.length - 1; i >= 0; i--) stack.push(kids[i]);
  #|         if (node === formEl) continue;
  #|         if (node.nodeType !== 1) continue;
  #|         if (!allowed.has(String(node.tagName || ''))) continue;
  #|         const attrs = node._attrs || {};
  #|         if ('disabled' in attrs) continue;
  #|         const name = attrs.name;
  #|         if (typeof name !== 'string' || name.length === 0) continue;
  #|         out.push(node);
  #|       }
  #|       return out;
  #|     };
  #|     const optionEffectiveValue = (option) => {
  #|       const oAttrs = option._attrs || {};
  #|       if (typeof oAttrs.value === 'string') return oAttrs.value;
  #|       // Fall back to the option's text content (concatenated descendant text).
  #|       const collectText = (node) => {
  #|         if (!node) return '';
  #|         if (node.nodeType === 3) {
  #|           if (typeof node.data === 'string') return node.data;
  #|           if (typeof node.nodeValue === 'string') return node.nodeValue;
  #|           return '';
  #|         }
  #|         const kids = node._children || node.childNodes || [];
  #|         let buf = '';
  #|         for (let i = 0; i < kids.length; i++) buf += collectText(kids[i]);
  #|         return buf;
  #|       };
  #|       return collectText(option);
  #|     };
  #|     const collectSelectOptions = (selectEl) => {
  #|       const out = [];
  #|       const stack = [selectEl];
  #|       while (stack.length) {
  #|         const node = stack.pop();
  #|         if (!node) continue;
  #|         const kids = node._children || node.childNodes || [];
  #|         for (let i = kids.length - 1; i >= 0; i--) stack.push(kids[i]);
  #|         if (node === selectEl) continue;
  #|         if (node.nodeType !== 1) continue;
  #|         if (String(node.tagName || '') === 'OPTION') out.push(node);
  #|       }
  #|       return out;
  #|     };
  #|     const controlEffectiveValue = (control) => {
  #|       const attrs = control._attrs || {};
  #|       const tag = String(control.tagName || '');
  #|       const type = String(attrs.type || '').toLowerCase();
  #|       if (tag === 'INPUT' && (type === 'checkbox' || type === 'radio')) {
  #|         if (typeof attrs.value === 'string' && attrs.value !== '') return attrs.value;
  #|         return 'on';
  #|       }
  #|       if (tag === 'SELECT') {
  #|         // Multi-select: return every selected option's effective value as
  #|         // an array; serializer emits one name=value pair per entry per
  #|         // https://html.spec.whatwg.org/#constructing-the-form-data-set.
  #|         const isMultiple =
  #|           !!attrs.multiple ||
  #|           control.multiple === true ||
  #|           (typeof control.multiple === 'string' && control.multiple !== '');
  #|         if (isMultiple) {
  #|           const options = collectSelectOptions(control);
  #|           const values = [];
  #|           for (const opt of options) {
  #|             const oAttrs = opt._attrs || {};
  #|             const selected = opt.selected === true ||
  #|               (opt.selected === undefined && !!oAttrs.selected);
  #|             if (selected) values.push(optionEffectiveValue(opt));
  #|           }
  #|           return values;
  #|         }
  #|         if (typeof control.value === 'string' && control.value !== '') return control.value;
  #|         if (typeof attrs.value === 'string' && attrs.value !== '') return attrs.value;
  #|         const options = collectSelectOptions(control);
  #|         if (options.length === 0) return '';
  #|         for (const opt of options) {
  #|           const oAttrs = opt._attrs || {};
  #|           const selected = opt.selected === true ||
  #|             (opt.selected === undefined && !!oAttrs.selected);
  #|           if (selected) return optionEffectiveValue(opt);
  #|         }
  #|         // HTML default: first option is selected if none marked.
  #|         return optionEffectiveValue(options[0]);
  #|       }
  #|       if (typeof control.value === 'string' && control.value !== '') return control.value;
  #|       if (typeof attrs.value === 'string') return attrs.value;
  #|       return '';
  #|     };
  #|     const isSubmissionExcluded = (control, submitter) => {
  #|       const tag = String(control.tagName || '');
  #|       const type = String((control._attrs && control._attrs.type) || '').toLowerCase();
  #|       if (tag === 'BUTTON') {
  #|         // Only the explicit submitter contributes; buttons without type default to submit.
  #|         if (control === submitter) return false;
  #|         return true;
  #|       }
  #|       if (tag === 'INPUT') {
  #|         if (type === 'button' || type === 'reset' || type === 'image' || type === 'file') {
  #|           return control !== submitter;
  #|         }
  #|         if (type === 'submit') return control !== submitter;
  #|         if (type === 'checkbox' || type === 'radio') {
  #|           return !control._attrs || !control._attrs.checked;
  #|         }
  #|       }
  #|       return false;
  #|     };
  #|     const serializeFormDataUrlEncoded = (controls, submitter) => {
  #|       const parts = [];
  #|       const enc = (s) => encodeURIComponent(String(s));
  #|       for (const c of controls) {
  #|         if (isSubmissionExcluded(c, submitter)) continue;
  #|         const attrs = c._attrs || {};
  #|         const name = attrs.name;
  #|         if (typeof name !== 'string' || name.length === 0) continue;
  #|         const value = controlEffectiveValue(c);
  #|         if (Array.isArray(value)) {
  #|           // <select multiple>: one name=value pair per selected option.
  #|           for (const v of value) {
  #|             parts.push(enc(name) + '=' + enc(v));
  #|           }
  #|         } else {
  #|           parts.push(enc(name) + '=' + enc(value));
  #|         }
  #|       }
  #|       return parts.join('&');
  #|     };
  #|     const dispatchFormSubmitEvent = (formEl, submitter) => {
  #|       const baseEvent = globalThis.__bidiCreateEvent
  #|         ? globalThis.__bidiCreateEvent('submit', { bubbles: true, cancelable: true })
  #|         : {
  #|             type: 'submit',
  #|             bubbles: true,
  #|             cancelable: true,
  #|             defaultPrevented: false,
  #|             preventDefault() { this.defaultPrevented = true; },
  #|             stopPropagation() {},
  #|             stopImmediatePropagation() {},
  #|           };
  #|       baseEvent.submitter = submitter || null;
  #|       if (typeof formEl.dispatchEvent === 'function') {
  #|         try { formEl.dispatchEvent(baseEvent); } catch (_e) {}
  #|       }
  #|       return !baseEvent.defaultPrevented;
  #|     };
  #|     const resolveSubmissionUrl = (action) => {
  #|       const base = (globalThis.location && typeof globalThis.location.href === 'string')
  #|         ? globalThis.location.href
  #|         : (globalThis.__pageUrl || 'about:blank');
  #|       try {
  #|         return new URL(String(action || ''), base).href;
  #|       } catch (_e) {
  #|         return String(action || base);
  #|       }
  #|     };
  #|     // WHATWG "Plan to navigate" filters unsafe URL schemes. We allow the
  #|     // realistic safe set for a test runtime and explicitly drop anything else
  #|     // (notably javascript: / vbscript: / other script-evaluating schemes) so a
  #|     // scripted page cannot navigate via form.action="javascript:...".
  #|     const isSubmissionSchemeAllowed = (url) => {
  #|       let proto = '';
  #|       try {
  #|         proto = new URL(String(url || '')).protocol;
  #|       } catch (_e) {
  #|         return false;
  #|       }
  #|       const allowedSchemes = new Set(['http:', 'https:', 'about:', 'blob:', 'data:', 'file:']);
  #|       return allowedSchemes.has(proto);
  #|     };
  #|     const performSubmission = (formEl, submitter) => {
  #|       try {
  #|         const attrs = formEl._attrs || {};
  #|         const actionAttr = (typeof attrs.action === 'string' && attrs.action) ? attrs.action : '';
  #|         const method = String(attrs.method || 'GET').toUpperCase();
  #|         let action = resolveSubmissionUrl(actionAttr);
  #|         if (!isSubmissionSchemeAllowed(action)) {
  #|           let proto = '';
  #|           try { proto = new URL(String(action || '')).protocol; } catch (_e) {}
  #|           if (typeof console !== 'undefined' && console.error) {
  #|             try { console.error('[bidi] form submission to unsafe scheme:', proto || action); } catch (_e) {}
  #|           }
  #|           return;
  #|         }
  #|         const controls = collectFormControls(formEl);
  #|         const serialized = serializeFormDataUrlEncoded(controls, submitter);
  #|         if (method === 'POST') {
  #|           const fetchFn = globalThis.__fetchInternal || globalThis.fetch;
  #|           if (typeof fetchFn === 'function') {
  #|             const init = {
  #|               method: 'POST',
  #|               headers: { 'content-type': 'application/x-www-form-urlencoded' },
  #|               body: serialized,
  #|               redirect: 'manual',
  #|             };
  #|             try {
  #|               const p = fetchFn(action, init);
  #|               if (p && typeof p.then === 'function') {
  #|                 p.then((response) => {
  #|                   if (!response) return;
  #|                   const status = Number(response.status || 0);
  #|                   if (status >= 300 && status < 400) {
  #|                     let loc = null;
  #|                     try { loc = response.headers && response.headers.get && response.headers.get('location'); } catch (_e) {}
  #|                     if (loc) {
  #|                       const resolved = resolveSubmissionUrl(loc);
  #|                       if (globalThis.location) {
  #|                         try { globalThis.location.href = resolved; } catch (_e) {}
  #|                       }
  #|                       globalThis.__pageUrl = resolved;
  #|                       if (typeof globalThis.__loadPageWithScripts === 'function') {
  #|                         try {
  #|                           const rp = globalThis.__loadPageWithScripts(resolved);
  #|                           if (rp && typeof rp.then === 'function') rp.then(() => {}, () => {});
  #|                         } catch (_e) {}
  #|                       } else if (typeof globalThis.__loadPage === 'function') {
  #|                         try {
  #|                           const rp = globalThis.__loadPage(resolved);
  #|                           if (rp && typeof rp.then === 'function') rp.then(() => {}, () => {});
  #|                         } catch (_e) {}
  #|                       }
  #|                     }
  #|                   } else if (status >= 200 && status < 300) {
  #|                     try {
  #|                       const tp = response.text && response.text();
  #|                       if (tp && typeof tp.then === 'function') {
  #|                         tp.then((html) => {
  #|                           if (typeof globalThis.__loadHTML === 'function') {
  #|                             try { globalThis.__loadHTML(String(html || '')); } catch (_e) {}
  #|                           }
  #|                           if (globalThis.location) {
  #|                             try { globalThis.location.href = action; } catch (_e) {}
  #|                           }
  #|                           globalThis.__pageUrl = action;
  #|                         }, () => {});
  #|                       }
  #|                     } catch (_e) {}
  #|                   }
  #|                 }, () => {});
  #|               }
  #|             } catch (_e) {}
  #|           }
  #|           return;
  #|         }
  #|         // GET (and any other method) — encode in query string and navigate.
  #|         let target = action;
  #|         if (serialized.length > 0) {
  #|           try {
  #|             const u = new URL(target);
  #|             u.search = '?' + serialized;
  #|             target = u.href;
  #|           } catch (_e) {
  #|             const hashIdx = target.indexOf('#');
  #|             const base = hashIdx >= 0 ? target.slice(0, hashIdx) : target;
  #|             const frag = hashIdx >= 0 ? target.slice(hashIdx) : '';
  #|             const qIdx = base.indexOf('?');
  #|             target = (qIdx >= 0 ? base.slice(0, qIdx) : base) + '?' + serialized + frag;
  #|           }
  #|         }
  #|         if (globalThis.location) {
  #|           try { globalThis.location.href = target; } catch (_e) {}
  #|         }
  #|         globalThis.__pageUrl = target;
  #|         if (typeof globalThis.__loadPageWithScripts === 'function') {
  #|           try {
  #|             const np = globalThis.__loadPageWithScripts(target);
  #|             if (np && typeof np.then === 'function') np.then(() => {}, () => {});
  #|           } catch (_e) {}
  #|         } else if (typeof globalThis.__loadPage === 'function') {
  #|           try {
  #|             const np = globalThis.__loadPage(target);
  #|             if (np && typeof np.then === 'function') np.then(() => {}, () => {});
  #|           } catch (_e) {}
  #|         }
  #|       } catch (_e) {}
  #|     };
  #|     const installFormSubmissionMethods = (el) => {
  #|       el.submit = function() {
  #|         performSubmission(this, null);
  #|         return undefined;
  #|       };
  #|       el.requestSubmit = function(submitter) {
  #|         let validatedSubmitter = null;
  #|         if (submitter !== undefined && submitter !== null) {
  #|           if (submitter.nodeType !== 1 || !(submitter._parent === this || descendsFrom(submitter, this))) {
  #|             throw new TypeError("requestSubmit: submitter is not a descendant of this form");
  #|           }
  #|           // Per WHATWG https://html.spec.whatwg.org/#dom-form-requestsubmit
  #|           // the submitter must be a submit button: BUTTON without a type
  #|           // attribute (default type=submit) or BUTTON with type=submit, or
  #|           // INPUT with type=submit / type=image.
  #|           const sTag = String(submitter.tagName || '');
  #|           const sAttrs = submitter._attrs || {};
  #|           const sType = typeof sAttrs.type === 'string' ? sAttrs.type.toLowerCase() : '';
  #|           let isSubmitButton = false;
  #|           if (sTag === 'BUTTON') {
  #|             isSubmitButton = !('type' in sAttrs) || sType === '' || sType === 'submit';
  #|           } else if (sTag === 'INPUT') {
  #|             isSubmitButton = sType === 'submit' || sType === 'image';
  #|           }
  #|           if (!isSubmitButton) {
  #|             throw new TypeError("requestSubmit: submitter is not a submit button");
  #|           }
  #|           validatedSubmitter = submitter;
  #|         }
  #|         const allowed = dispatchFormSubmitEvent(this, validatedSubmitter);
  #|         if (!allowed) return undefined;
  #|         performSubmission(this, validatedSubmitter);
  #|         return undefined;
  #|       };
  #|       el.reset = function() {
  #|         const resetEvent = globalThis.__bidiCreateEvent
  #|           ? globalThis.__bidiCreateEvent('reset', { bubbles: true, cancelable: true })
  #|           : null;
  #|         if (resetEvent && typeof this.dispatchEvent === 'function') {
  #|           try { this.dispatchEvent(resetEvent); } catch (_e) {}
  #|           // If a listener canceled the event, skip clearing values.
  #|           if (resetEvent.defaultPrevented) return undefined;
  #|         }
  #|         // Walk form descendants and reset each resettable control to its
  #|         // default state (https://html.spec.whatwg.org/#form-reset-algorithm).
  #|         const resettable = new Set(['INPUT', 'SELECT', 'TEXTAREA']);
  #|         const buttonInputTypes = new Set(['button', 'submit', 'reset', 'image']);
  #|         const stack = [this];
  #|         while (stack.length) {
  #|           const node = stack.pop();
  #|           if (!node) continue;
  #|           const kids = node._children || node.childNodes || [];
  #|           for (let i = kids.length - 1; i >= 0; i--) stack.push(kids[i]);
  #|           if (node === this) continue;
  #|           if (node.nodeType !== 1) continue;
  #|           const tag = String(node.tagName || '');
  #|           if (!resettable.has(tag)) continue;
  #|           const attrs = node._attrs || {};
  #|           if (tag === 'INPUT') {
  #|             const type = typeof attrs.type === 'string' ? attrs.type.toLowerCase() : '';
  #|             if (buttonInputTypes.has(type)) continue;
  #|             if (type === 'checkbox' || type === 'radio') {
  #|               // defaultChecked falls back to current `checked` attribute
  #|               // when no override was recorded.
  #|               const dc = (node._defaultChecked !== undefined)
  #|                 ? node._defaultChecked
  #|                 : !!attrs.checked;
  #|               // Bypass the value/checked setter snapshot so reset does not
  #|               // become the new "default" baseline.
  #|               if (dc) attrs.checked = 'checked'; else delete attrs.checked;
  #|             } else {
  #|               const dv = (node._defaultValue !== undefined)
  #|                 ? node._defaultValue
  #|                 : (typeof attrs.value === 'string' ? attrs.value : '');
  #|               attrs.value = dv;
  #|             }
  #|             continue;
  #|           }
  #|           if (tag === 'TEXTAREA') {
  #|             const dv = (node._defaultValue !== undefined)
  #|               ? node._defaultValue
  #|               : (typeof attrs.value === 'string' ? attrs.value : '');
  #|             attrs.value = dv;
  #|             continue;
  #|           }
  #|           if (tag === 'SELECT') {
  #|             const options = collectSelectOptions(node);
  #|             for (const opt of options) {
  #|               const oAttrs = opt._attrs || {};
  #|               const ds = (opt._defaultSelected !== undefined)
  #|                 ? opt._defaultSelected
  #|                 : !!oAttrs.selected;
  #|               // Bypass setter snapshot.
  #|               if (ds) oAttrs.selected = 'selected'; else delete oAttrs.selected;
  #|               // Keep any explicit opt.selected JS field in sync.
  #|               if ('selected' in opt) opt.selected = ds;
  #|             }
  #|             // Clear any cached select.value so controlEffectiveValue
  #|             // re-reads option selectedness from defaults.
  #|             try { node._attrs.value = ''; } catch (_e) {}
  #|             continue;
  #|           }
  #|         }
  #|         return undefined;
  #|       };
  #|     };
  #|
  #|     // Minimal Mock DOM for Preact compatibility
  #|     const createMockElement = (tagName) => {
  #|       const lowerTag = String(tagName || "").toLowerCase();
  #|       const defaultNamespace =
  #|         lowerTag === "svg"
  #|           ? "http://www.w3.org/2000/svg"
  #|           : "http://www.w3.org/1999/xhtml";
  #|       const el = {
  #|         tagName: tagName.toUpperCase(),
  #|         nodeName: tagName.toUpperCase(),
  #|         nodeType: 1,
  #|         namespaceURI: defaultNamespace,
  #|         _attrs: {},
  #|         _attrNamespaces: {},
  #|         _children: [],
  #|         _parent: null,
  #|         _textContent: '',
  #|         _listeners: {},
  #|         _style: {},
  #|         shadowRoot: null,
  #|         ownerDocument: null, // Set after document is created
  #|         get localName() { return this.tagName.toLowerCase(); },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent; },
  #|         get childNodes() { return this._children; },
  #|         get children() { return this._children.filter(c => c.nodeType === 1); },
  #|         get firstChild() { return this._children[0] || null; },
  #|         get lastChild() { return this._children[this._children.length - 1] || null; },
  #|         hasChildNodes() { return this._children.length > 0; },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return this._parent._children[idx + 1] || null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return this._parent._children[idx - 1] || null;
  #|         },
  #|         get nextElementSibling() {
  #|           let sibling = this.nextSibling;
  #|           while (sibling && sibling.nodeType !== 1) sibling = sibling.nextSibling;
  #|           return sibling || null;
  #|         },
  #|         get previousElementSibling() {
  #|           let sibling = this.previousSibling;
  #|           while (sibling && sibling.nodeType !== 1) sibling = sibling.previousSibling;
  #|           return sibling || null;
  #|         },
  #|         matches(sel) { return matchesSelector(this, String(sel)); },
  #|         webkitMatchesSelector(sel) { return this.matches(sel); },
  #|         closest(sel) {
  #|           let node = this;
  #|           while (node) {
  #|             if (node.nodeType === 1 && matchesSelector(node, String(sel))) return node;
  #|             node = node._parent || node.parentElement || node.parentNode || null;
  #|           }
  #|           return null;
  #|         },
  #|         get textContent() {
  #|           if (this.nodeType === 3) return this._textContent;
  #|           return this._children.map(c => c.textContent).join('');
  #|         },
  #|         set textContent(v) {
  #|           this._children = [];
  #|           if (v) {
  #|             const text = createMockTextNode(v);
  #|             text._parent = this;
  #|             this._children.push(text);
  #|           }
  #|         },
  #|         get innerHTML() {
  #|           return this._children.map(c => {
  #|             if (c.nodeType === 3) return c._textContent;
  #|             let html = '<' + c.tagName.toLowerCase();
  #|             for (const [k, v] of Object.entries(c._attrs)) {
  #|               html += ' ' + k + '="' + v + '"';
  #|             }
  #|             html += '>' + c.innerHTML + '</' + c.tagName.toLowerCase() + '>';
  #|             return html;
  #|           }).join('');
  #|         },
  #|         set innerHTML(v) {
  #|           this._children = [];
  #|           if (!v) return;
  #|           const nodes = parseHTMLFragment(
  #|             String(v),
  #|             this.ownerDocument || globalThis.document || null,
  #|           );
  #|           if (nodes.length === 0) {
  #|             const text = createMockTextNode(v);
  #|             text._parent = this;
  #|             text.ownerDocument = this.ownerDocument || null;
  #|             this._children.push(text);
  #|             return;
  #|           }
  #|           for (const node of nodes) {
  #|             node._parent = this;
  #|             node.ownerDocument = this.ownerDocument || node.ownerDocument || null;
  #|             this._children.push(node);
  #|           }
  #|         },
  #|         get id() { return this._attrs.id || ''; },
  #|         set id(v) { this._attrs.id = v; },
  #|         get className() { return this._attrs.class || ''; },
  #|         set className(v) { this._attrs.class = v; },
  #|         get slot() { return this._attrs.slot || ''; },
  #|         set slot(v) {
  #|           const next = String(v || '');
  #|           if (next === '') delete this._attrs.slot;
  #|           else this._attrs.slot = next;
  #|         },
  #|         get classList() {
  #|           const self = this;
  #|           return {
  #|             _getClasses() { return (self._attrs.class || '').split(/\s+/).filter(Boolean); },
  #|             add(...cls) { const c = new Set(this._getClasses()); cls.forEach(x => c.add(x)); self._attrs.class = [...c].join(' '); },
  #|             remove(...cls) { const c = new Set(this._getClasses()); cls.forEach(x => c.delete(x)); self._attrs.class = [...c].join(' '); },
  #|             toggle(cls, force) { if (force === undefined) force = !this.contains(cls); if (force) this.add(cls); else this.remove(cls); return force; },
  #|             contains(cls) { return this._getClasses().includes(cls); },
  #|             [Symbol.iterator]() { return this._getClasses()[Symbol.iterator](); }
  #|           };
  #|         },
  #|         get style() {
  #|           return createStyleDeclaration(this);
  #|         },
  #|         get value() { return this._attrs.value || ''; },
  #|         set value(v) {
  #|           // Snapshot the default (from the value attribute) on first
  #|           // mutation so form.reset() can restore it.
  #|           if (this._defaultValue === undefined) {
  #|             this._defaultValue = typeof this._attrs.value === 'string' ? this._attrs.value : '';
  #|           }
  #|           this._attrs.value = v;
  #|         },
  #|         get checked() { return !!this._attrs.checked; },
  #|         set checked(v) {
  #|           if (this._defaultChecked === undefined) {
  #|             this._defaultChecked = !!this._attrs.checked;
  #|           }
  #|           this._attrs.checked = v;
  #|         },
  #|         get defaultValue() {
  #|           return this._defaultValue !== undefined
  #|             ? this._defaultValue
  #|             : (typeof this._attrs.value === 'string' ? this._attrs.value : '');
  #|         },
  #|         set defaultValue(v) {
  #|           this._defaultValue = String(v);
  #|           this._attrs.value = String(v);
  #|         },
  #|         get defaultChecked() {
  #|           return this._defaultChecked !== undefined
  #|             ? this._defaultChecked
  #|             : !!this._attrs.checked;
  #|         },
  #|         set defaultChecked(v) {
  #|           this._defaultChecked = !!v;
  #|           if (v) this._attrs.checked = 'checked'; else delete this._attrs.checked;
  #|         },
  #|         get type() { return this._attrs.type || ''; },
  #|         set type(v) { this._attrs.type = v; },
  #|         get src() { return this._attrs.src || ''; },
  #|         set src(v) { this._attrs.src = String(v); },
  #|         get hidden() { return 'hidden' in this._attrs; },
  #|         set hidden(v) { if (v) this._attrs.hidden = ''; else delete this._attrs.hidden; },
  #|         get clientWidth() {
  #|           if (this.tagName === "HTML" || this.tagName === "BODY") {
  #|             return Number(
  #|               (globalThis.window && globalThis.window.innerWidth) ||
  #|               globalThis.innerWidth ||
  #|               1024,
  #|             );
  #|           }
  #|           const rect = this.getBoundingClientRect ? this.getBoundingClientRect() : null;
  #|           return Number(rect && rect.width ? rect.width : 0);
  #|         },
  #|         get clientHeight() {
  #|           if (this.tagName === "HTML" || this.tagName === "BODY") {
  #|             return Number(
  #|               (globalThis.window && globalThis.window.innerHeight) ||
  #|               globalThis.innerHeight ||
  #|               768,
  #|             );
  #|           }
  #|           const rect = this.getBoundingClientRect ? this.getBoundingClientRect() : null;
  #|           return Number(rect && rect.height ? rect.height : 0);
  #|         },
  #|         get scrollWidth() {
  #|           let maxWidth = Number(this.clientWidth || 0);
  #|           if (Array.isArray(this._children)) {
  #|             for (const child of this._children) {
  #|               if (!child || typeof child.getBoundingClientRect !== "function") continue;
  #|               const rect = child.getBoundingClientRect();
  #|               const right = Number(rect && rect.right ? rect.right : rect && rect.width ? rect.width : 0);
  #|               if (right > maxWidth) maxWidth = right;
  #|             }
  #|           }
  #|           return maxWidth;
  #|         },
  #|         get scrollHeight() {
  #|           let maxHeight = Number(this.clientHeight || 0);
  #|           if (Array.isArray(this._children)) {
  #|             for (const child of this._children) {
  #|               if (!child || typeof child.getBoundingClientRect !== "function") continue;
  #|               const rect = child.getBoundingClientRect();
  #|               const bottom = Number(rect && rect.bottom ? rect.bottom : rect && rect.height ? rect.height : 0);
  #|               if (bottom > maxHeight) maxHeight = bottom;
  #|             }
  #|           }
  #|           return maxHeight;
  #|         },
  #|         get attributes() {
  #|           const attrs = Object.entries(this._attrs).map(([name, value]) => ({
  #|             localName: String(name).includes(":") ? String(name).split(":").pop() : String(name),
  #|             namespaceURI:
  #|               this._attrNamespaces?.[name] ??
  #|               (String(name).startsWith("svg:") ? "http://www.w3.org/2000/svg" : null),
  #|             nodeType: 2,
  #|             nodeName: String(name),
  #|             name: String(name),
  #|             value: String(value),
  #|             nodeValue: String(value),
  #|             ownerElement: this,
  #|             ownerDocument: this.ownerDocument,
  #|             parentNode: null,
  #|             cloneNode() {
  #|               return {
  #|                 nodeType: 2,
  #|                 nodeName: this.nodeName,
  #|                 name: this.name,
  #|                 value: this.value,
  #|                 nodeValue: this.nodeValue,
  #|                 ownerElement: this.ownerElement,
  #|                 ownerDocument: this.ownerDocument,
  #|                 parentNode: null
  #|               };
  #|             }
  #|           }));
  #|           return toCollection(attrs, "namednodemap");
  #|         },
  #|         get dataset() {
  #|           const self = this;
  #|           // Convert data-foo-bar to fooBar
  #|           const toCamelCase = (name) => name.replace(/^data-/, '').replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  #|           // Convert fooBar to data-foo-bar
  #|           const toDataAttr = (name) => 'data-' + name.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|           return new Proxy({}, {
  #|             get(_, prop) {
  #|               if (typeof prop !== 'string') return undefined;
  #|               const attrName = toDataAttr(prop);
  #|               return self._attrs[attrName];
  #|             },
  #|             set(_, prop, value) {
  #|               if (typeof prop !== 'string') return false;
  #|               const attrName = toDataAttr(prop);
  #|               self._attrs[attrName] = String(value);
  #|               return true;
  #|             },
  #|             has(_, prop) {
  #|               if (typeof prop !== 'string') return false;
  #|               const attrName = toDataAttr(prop);
  #|               return attrName in self._attrs;
  #|             },
  #|             deleteProperty(_, prop) {
  #|               if (typeof prop !== 'string') return false;
  #|               const attrName = toDataAttr(prop);
  #|               delete self._attrs[attrName];
  #|               return true;
  #|             },
  #|             ownKeys(_) {
  #|               return Object.keys(self._attrs)
  #|                 .filter(k => k.startsWith('data-'))
  #|                 .map(k => toCamelCase(k));
  #|             },
  #|             getOwnPropertyDescriptor(_, prop) {
  #|               if (typeof prop !== 'string') return undefined;
  #|               const attrName = toDataAttr(prop);
  #|               if (attrName in self._attrs) {
  #|                 return { value: self._attrs[attrName], writable: true, enumerable: true, configurable: true };
  #|               }
  #|               return undefined;
  #|             }
  #|           });
  #|         },
  #|         setAttribute(name, value) {
  #|           const oldValue = this._attrs[name];
  #|           this._attrs[name] = String(value);
  #|           this._attrNamespaces[name] = null;
  #|           if (typeof name === "string" && name.toLowerCase().startsWith("on")) {
  #|             try {
  #|               this[name.toLowerCase()] = Function("event", String(value));
  #|             } catch (_e) {
  #|               this[name.toLowerCase()] = function() { return undefined; };
  #|             }
  #|           }
  #|           if (name === 'style') {
  #|             parseStyleTextInto(this._style, value);
  #|           }
  #|           notifyMutation(createMutationRecord('attributes', this, { attributeName: name, oldValue }));
  #|         },
  #|         setAttributeNS(namespace, name, value) {
  #|           const attrName = String(name);
  #|           const oldValue = this._attrs[attrName];
  #|           this._attrs[attrName] = String(value);
  #|           this._attrNamespaces[attrName] = namespace ?? null;
  #|           notifyMutation(
  #|             createMutationRecord('attributes', this, {
  #|               attributeName: attrName,
  #|               oldValue,
  #|             }),
  #|           );
  #|         },
  #|         getAttribute(name) { return this._attrs[name] ?? null; },
  #|         getAttributeNames() { return Object.keys(this._attrs); },
  #|         removeAttribute(name) {
  #|           const oldValue = this._attrs[name];
  #|           delete this._attrs[name];
  #|           delete this._attrNamespaces[name];
  #|           if (typeof name === "string" && name.toLowerCase().startsWith("on")) {
  #|             delete this[name.toLowerCase()];
  #|           }
  #|           notifyMutation(createMutationRecord('attributes', this, { attributeName: name, oldValue }));
  #|         },
  #|         hasAttribute(name) { return name in this._attrs; },
  #|         appendChild(child) {
  #|           if (child._parent) child._parent.removeChild(child);
  #|           const prevSibling = this._children[this._children.length - 1] || null;
  #|           child._parent = this;
  #|           child.ownerDocument = this.ownerDocument;
  #|           this._children.push(child);
  #|           notifyMutation(createMutationRecord('childList', this, { addedNodes: [child], previousSibling: prevSibling }));
  #|           try {
  #|             const childTag = String(child && child.tagName ? child.tagName : "").toUpperCase();
  #|             const parentTag = String(this && this.tagName ? this.tagName : "").toUpperCase();
  #|             if (!globalThis.__suppressScriptAppendExecution && childTag === "SCRIPT") {
  #|               const src = typeof child.getAttribute === "function"
  #|                 ? child.getAttribute("src")
  #|                 : child.src;
  #|               if (src) {
  #|                 const fireScriptLoad = () => {
  #|                   try {
  #|                     if (typeof child.dispatchEvent === "function") {
  #|                       child.dispatchEvent(new Event("load"));
  #|                     }
  #|                   } catch (_eventError) {}
  #|                 };
  #|                 if (typeof queueMicrotask === "function") queueMicrotask(fireScriptLoad);
  #|                 else if (typeof setTimeout === "function") setTimeout(fireScriptLoad, 0);
  #|               } else if (parentTag === "BODY" || parentTag === "HEAD" || parentTag === "HTML") {
  #|                 const code = String(child.textContent || "");
  #|                 if (code.trim() !== "") {
  #|                   try {
  #|                     (0, eval)(code);
  #|                   } catch (scriptError) {
  #|                     const pushError = globalThis.__bidiPushJavascriptErrorEntry;
  #|                     if (typeof pushError === "function") {
  #|                       pushError(scriptError);
  #|                     }
  #|                   }
  #|                 }
  #|             }
  #|             }
  #|           } catch (_e) {}
  #|           return child;
  #|         },
  #|         append(...nodes) {
  #|           for (const node of nodes) {
  #|             if (node === null || node === undefined) continue;
  #|             if (
  #|               typeof node === "string" ||
  #|               typeof node === "number" ||
  #|               typeof node === "boolean" ||
  #|               typeof node === "bigint"
  #|             ) {
  #|               this.appendChild(createMockTextNode(String(node)));
  #|               continue;
  #|             }
  #|             if (node.nodeType === 11 && Array.isArray(node._children)) {
  #|               const fragmentChildren = Array.from(node._children);
  #|               for (const fragmentChild of fragmentChildren) {
  #|                 this.appendChild(fragmentChild);
  #|               }
  #|               node._children = [];
  #|               continue;
  #|             }
  #|             this.appendChild(node);
  #|           }
  #|         },
  #|         insertBefore(newChild, refChild) {
  #|           if (newChild._parent) newChild._parent.removeChild(newChild);
  #|           newChild._parent = this;
  #|           newChild.ownerDocument = this.ownerDocument;
  #|           const idx = refChild ? this._children.indexOf(refChild) : this._children.length;
  #|           const prevSibling = idx > 0 ? this._children[idx - 1] : null;
  #|           if (idx === -1) this._children.push(newChild);
  #|           else this._children.splice(idx, 0, newChild);
  #|           notifyMutation(createMutationRecord('childList', this, { addedNodes: [newChild], previousSibling: prevSibling, nextSibling: refChild }));
  #|           return newChild;
  #|         },
  #|         removeChild(child) {
  #|           const idx = this._children.indexOf(child);
  #|           if (idx !== -1) {
  #|             const prevSibling = idx > 0 ? this._children[idx - 1] : null;
  #|             const nextSibling = this._children[idx + 1] || null;
  #|             this._children.splice(idx, 1);
  #|             child._parent = null;
  #|             notifyMutation(createMutationRecord('childList', this, { removedNodes: [child], previousSibling: prevSibling, nextSibling }));
  #|           }
  #|           return child;
  #|         },
  #|         remove() {
  #|           const parent = this._parent || this.parentNode || this.parentElement || null;
  #|           if (parent && typeof parent.removeChild === "function") {
  #|             parent.removeChild(this);
  #|           }
  #|         },
  #|         insertAdjacentElement(position, element) {
  #|           if (!element || typeof element !== "object") {
  #|             throw new TypeError("Failed to execute insertAdjacentElement: parameter 2 is not of type Element");
  #|           }
  #|           const pos = String(position || "").toLowerCase();
  #|           if (pos === "beforebegin") {
  #|             const parent = this._parent || this.parentNode || this.parentElement || null;
  #|             if (!parent || typeof parent.insertBefore !== "function") return null;
  #|             return parent.insertBefore(element, this);
  #|           }
  #|           if (pos === "afterend") {
  #|             const parent = this._parent || this.parentNode || this.parentElement || null;
  #|             if (!parent || typeof parent.insertBefore !== "function") return null;
  #|             return parent.insertBefore(element, this.nextSibling || null);
  #|           }
  #|           if (pos === "afterbegin") {
  #|             return this.insertBefore(element, this.firstChild || null);
  #|           }
  #|           if (pos === "beforeend") {
  #|             return this.appendChild(element);
  #|           }
  #|           throw new DOMException("Invalid insertAdjacentElement position", "SyntaxError");
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           const idx = this._children.indexOf(oldChild);
  #|           if (idx !== -1) {
  #|             if (newChild._parent) newChild._parent.removeChild(newChild);
  #|             const prevSibling = idx > 0 ? this._children[idx - 1] : null;
  #|             const nextSibling = this._children[idx + 1] || null;
  #|             newChild._parent = this;
  #|             newChild.ownerDocument = this.ownerDocument;
  #|             this._children[idx] = newChild;
  #|             oldChild._parent = null;
  #|             notifyMutation(createMutationRecord('childList', this, { addedNodes: [newChild], removedNodes: [oldChild], previousSibling: prevSibling, nextSibling }));
  #|           }
  #|           return oldChild;
  #|         },
  #|         cloneNode(deep) {
  #|           const clone = createMockElement(this.tagName);
  #|           clone._attrs = { ...this._attrs };
  #|           clone._attrNamespaces = { ...this._attrNamespaces };
  #|           clone._style = { ...this._style };
  #|           if (deep) {
  #|             for (const child of this._children) {
  #|               clone.appendChild(child.cloneNode(true));
  #|             }
  #|           }
  #|           return clone;
  #|         },
  #|         addEventListener(type, fn) {
  #|           if (!this._listeners[type]) this._listeners[type] = [];
  #|           this._listeners[type].push(fn);
  #|         },
  #|         removeEventListener(type, fn) {
  #|           if (this._listeners[type]) {
  #|             this._listeners[type] = this._listeners[type].filter(f => f !== fn);
  #|           }
  #|         },
  #|         dispatchEvent(event) {
  #|           prepareEventForCurrentTarget(event, this);
  #|           if (event.__retargetSuppressed) return !event.defaultPrevented;
  #|           const listeners = this._listeners[event.type] || [];
  #|           const previousEvent = globalThis.event;
  #|           globalThis.event = event;
  #|           try {
  #|             for (const fn of listeners) {
  #|               try { fn.call(this, event); } catch (_e) {}
  #|             }
  #|             if (event.bubbles) {
  #|               const parent = this._parent || this.parentElement || this.parentNode || null;
  #|               if (parent && parent !== this && typeof parent.dispatchEvent === "function") {
  #|                 parent.dispatchEvent(event);
  #|               } else {
  #|                 if (
  #|                   this.ownerDocument &&
  #|                   this.ownerDocument !== this &&
  #|                   typeof this.ownerDocument.dispatchEvent === "function"
  #|                 ) {
  #|                   this.ownerDocument.dispatchEvent(event);
  #|                 }
  #|                 if (globalThis.window && typeof globalThis.window.dispatchEvent === "function") {
  #|                   globalThis.window.dispatchEvent(event);
  #|                 }
  #|               }
  #|             }
  #|           } finally {
  #|             globalThis.event = previousEvent;
  #|           }
  #|           return !event.defaultPrevented;
  #|         },
  #|         click() {
  #|           this.dispatchEvent(globalThis.__bidiCreateEvent('click', { bubbles: true }));
  #|         },
  #|         focus() {
  #|           focusNode(this);
  #|           try { globalThis.__bidiFocusedElement = this; } catch (_e) {}
  #|         },
  #|         blur() {
  #|           blurNode(this);
  #|           try {
  #|             if (globalThis.__bidiFocusedElement === this) {
  #|               globalThis.__bidiFocusedElement = null;
  #|             }
  #|           } catch (_e) {}
  #|         },
  #|         setSelectionRange(start, end) {
  #|           const value = typeof this.value === "string" ? this.value : "";
  #|           const safeStart = Math.max(0, Math.min(value.length, Number(start)));
  #|           const safeEnd = Math.max(0, Math.min(value.length, Number(end)));
  #|           this.selectionStart = safeStart;
  #|           this.selectionEnd = safeEnd;
  #|         },
  #|         select() {
  #|           const value = typeof this.value === "string" ? this.value : "";
  #|           this.selectionStart = 0;
  #|           this.selectionEnd = value.length;
  #|         },
  #|         attachShadow(opts) {
  #|           if (this.shadowRoot) return this.shadowRoot;
  #|           const root = createMockElement('shadow-root');
  #|           root.nodeType = 11;
  #|           root.nodeName = '#document-fragment';
  #|           root.mode = opts && typeof opts.mode === "string" ? String(opts.mode) : "open";
  #|           root.delegatesFocus = !!(opts && opts.delegatesFocus);
  #|           root._parent = this;
  #|           root._isShadowRoot = true;
  #|           root.host = this;
  #|           root.activeElement = null;
  #|           root.ownerDocument = this.ownerDocument;
  #|           this.shadowRoot = root;
  #|           return root;
  #|         },
  #|         contains(node) {
  #|           if (node === this) return true;
  #|           for (const child of this._children) {
  #|             if (child === node || (child.contains && child.contains(node))) return true;
  #|           }
  #|           return false;
  #|         },
  #|         getBoundingClientRect() {
  #|           const toNumber = (value, fallback = 0) => {
  #|             const num = Number.parseFloat(String(value ?? ""));
  #|             return Number.isFinite(num) ? num : fallback;
  #|           };
  #|           const width = toNumber(this._style?.width ?? this._attrs?.width, 1);
  #|           const height = toNumber(this._style?.height ?? this._attrs?.height, 1);
  #|           let left = toNumber(this._style?.left, 0);
  #|           let top = toNumber(this._style?.top, 0);
  #|           if (this._parent && typeof this._parent.getBoundingClientRect === "function") {
  #|             try {
  #|               const parentRect = this._parent.getBoundingClientRect();
  #|               left += Number(parentRect?.left || 0);
  #|               top += Number(parentRect?.top || 0);
  #|             } catch (_e) {}
  #|           }
  #|           const right = left + width;
  #|           const bottom = top + height;
  #|           return {
  #|             x: left,
  #|             y: top,
  #|             left,
  #|             top,
  #|             right,
  #|             bottom,
  #|             width,
  #|             height,
  #|             toJSON() {
  #|               return {
  #|                 x: this.x,
  #|                 y: this.y,
  #|                 left: this.left,
  #|                 top: this.top,
  #|                 right: this.right,
  #|                 bottom: this.bottom,
  #|                 width: this.width,
  #|                 height: this.height,
  #|               };
  #|             },
  #|           };
  #|         },
  #|         querySelector(sel) { return querySelect(this, sel, false); },
  #|         querySelectorAll(sel) { return querySelect(this, sel, true); },
  #|         getElementsByTagName(tag) {
  #|           const results = [];
  #|           const search = (node) => {
  #|             for (const child of node._children) {
  #|               if (child.nodeType === 1) {
  #|                 if (tag === '*' || child.tagName === tag.toUpperCase()) results.push(child);
  #|                 search(child);
  #|               }
  #|             }
  #|           };
  #|           search(this);
  #|           return toCollection(results, "htmlcollection");
  #|         },
  #|         getElementsByClassName(cls) {
  #|           const results = [];
  #|           const search = (node) => {
  #|             for (const child of node._children) {
  #|               if (child.nodeType === 1) {
  #|                 if (child.classList.contains(cls)) results.push(child);
  #|                 search(child);
  #|               }
  #|             }
  #|           };
  #|           search(this);
  #|           return toCollection(results, "htmlcollection");
  #|         }
  #|       };
  #|       if (lowerTag === 'form') {
  #|         installFormSubmissionMethods(el);
  #|       }
  #|       return el;
  #|     };
  #|
  #|     const createMockTextNode = (text) => ({
  #|       nodeType: 3,
  #|       nodeName: '#text',
  #|       _textContent: String(text),
  #|       _parent: null,
  #|       ownerDocument: null,
  #|       get textContent() { return this._textContent; },
  #|       set textContent(v) { this._textContent = String(v); },
  #|       get nodeValue() { return this._textContent; },
  #|       set nodeValue(v) { this._textContent = String(v); },
  #|       get parentNode() { return this._parent; },
  #|       get nextSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) + 1] || null;
  #|       },
  #|       get previousSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) - 1] || null;
  #|       },
  #|       hasChildNodes() { return false; },
  #|       cloneNode() { return createMockTextNode(this._textContent); }
  #|     });
  #|
  #|     const createMockCommentNode = (text) => ({
  #|       nodeType: 8,
  #|       nodeName: '#comment',
  #|       _textContent: String(text),
  #|       _parent: null,
  #|       ownerDocument: null,
  #|       get textContent() { return this._textContent; },
  #|       set textContent(v) { this._textContent = String(v); },
  #|       get nodeValue() { return this._textContent; },
  #|       set nodeValue(v) { this._textContent = String(v); },
  #|       get parentNode() { return this._parent; },
  #|       get nextSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) + 1] || null;
  #|       },
  #|       get previousSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) - 1] || null;
  #|       },
  #|       hasChildNodes() { return false; },
  #|       cloneNode() { return createMockCommentNode(this._textContent); }
  #|     });
  #|
  #|     const createMockCDataNode = (text) => ({
  #|       nodeType: 4,
  #|       nodeName: '#cdata-section',
  #|       _textContent: String(text),
  #|       _parent: null,
  #|       ownerDocument: null,
  #|       get textContent() { return this._textContent; },
  #|       set textContent(v) { this._textContent = String(v); },
  #|       get nodeValue() { return this._textContent; },
  #|       set nodeValue(v) { this._textContent = String(v); },
  #|       get parentNode() { return this._parent; },
  #|       get nextSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) + 1] || null;
  #|       },
  #|       get previousSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) - 1] || null;
  #|       },
  #|       hasChildNodes() { return false; },
  #|       cloneNode() { return createMockCDataNode(this._textContent); }
  #|     });
  #|
  #|     const createMockProcessingInstruction = (target, data) => ({
  #|       nodeType: 7,
  #|       nodeName: String(target),
  #|       target: String(target),
  #|       data: String(data),
  #|       _textContent: String(data),
  #|       _parent: null,
  #|       ownerDocument: null,
  #|       get textContent() { return this._textContent; },
  #|       set textContent(v) { this._textContent = String(v); this.data = String(v); },
  #|       get nodeValue() { return this._textContent; },
  #|       set nodeValue(v) { this._textContent = String(v); this.data = String(v); },
  #|       get parentNode() { return this._parent; },
  #|       get nextSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) + 1] || null;
  #|       },
  #|       get previousSibling() {
  #|         if (!this._parent) return null;
  #|         const siblings = this._parent._children || [];
  #|         return siblings[siblings.indexOf(this) - 1] || null;
  #|       },
  #|       hasChildNodes() { return false; },
  #|       cloneNode() { return createMockProcessingInstruction(this.target, this.data); }
  #|     });
  #|
  #|     const parseHTMLFragment = (fragmentHtml, ownerDocument) => {
  #|       const source = String(fragmentHtml || "");
  #|       const root = { _children: [] };
  #|       const stack = [root];
  #|       const voidElements = new Set([
  #|         "area", "base", "br", "col", "embed", "hr", "img", "input",
  #|         "link", "meta", "param", "source", "track", "wbr"
  #|       ]);
  #|       const pushNode = (parent, node) => {
  #|         if (parent && typeof parent.appendChild === "function") {
  #|           parent.appendChild(node);
  #|           return;
  #|         }
  #|         node._parent = null;
  #|         root._children.push(node);
  #|       };
  #|       const tokenRe = /<!--[\s\S]*?-->|<\/?[a-zA-Z][^>]*>|[^<]+/g;
  #|       let tokenMatch;
  #|       while ((tokenMatch = tokenRe.exec(source))) {
  #|         const token = tokenMatch[0];
  #|         if (!token) continue;
  #|         if (token.startsWith("<!--")) {
  #|           const commentText = token.slice(4, -3);
  #|           const commentNode = createMockCommentNode(commentText);
  #|           commentNode.ownerDocument = ownerDocument;
  #|           pushNode(stack[stack.length - 1], commentNode);
  #|           continue;
  #|         }
  #|         if (token[0] !== "<") {
  #|           if (token.trim() === "") continue;
  #|           const textNode = createMockTextNode(token);
  #|           textNode.ownerDocument = ownerDocument;
  #|           pushNode(stack[stack.length - 1], textNode);
  #|           continue;
  #|         }
  #|         if (token[1] === "/") {
  #|           if (stack.length > 1) stack.pop();
  #|           continue;
  #|         }
  #|         const selfClosing = token.endsWith("/>");
  #|         const tagMatch = token.match(/^<([a-zA-Z][\w:-]*)/);
  #|         if (!tagMatch) continue;
  #|         const rawTagName = tagMatch[1];
  #|         const tagName = rawTagName.toLowerCase();
  #|         const element = createMockElement(tagName);
  #|         element.ownerDocument = ownerDocument;
  #|         const parentNode = stack[stack.length - 1] || null;
  #|         const parentNs = parentNode && typeof parentNode.namespaceURI === "string"
  #|           ? String(parentNode.namespaceURI)
  #|           : "";
  #|         if (tagName === "svg" || parentNs === "http://www.w3.org/2000/svg") {
  #|           element.namespaceURI = "http://www.w3.org/2000/svg";
  #|         }
  #|         const attrChunk = token.slice(
  #|           tagMatch[0].length,
  #|           token.length - (selfClosing ? 2 : 1),
  #|         );
  #|         const attrRe = /([^\s=\/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s\/>]+)))?/g;
  #|         let attrMatch;
  #|         while ((attrMatch = attrRe.exec(attrChunk))) {
  #|           const attrName = String(attrMatch[1]);
  #|           const attrValue = attrMatch[2] ?? attrMatch[3] ?? attrMatch[4] ?? attrName;
  #|           if (attrName.includes(":") && typeof element.setAttributeNS === "function") {
  #|             const ns = attrName.startsWith("svg:") ? "http://www.w3.org/2000/svg" : null;
  #|             element.setAttributeNS(ns, attrName, attrValue);
  #|           } else {
  #|             element.setAttribute(attrName, attrValue);
  #|           }
  #|         }
  #|         pushNode(stack[stack.length - 1], element);
  #|         if (!selfClosing && !voidElements.has(tagName)) {
  #|           stack.push(element);
  #|         }
  #|       }
  #|       return root._children;
  #|     };
  #|
  #|     // Selector parsing cache for performance
  #|     const selectorCache = new Map();
  #|
  #|     // Parse selector once and cache the result
  #|     const parseSelector = (sel) => {
  #|       if (selectorCache.has(sel)) return selectorCache.get(sel);
  #|       let parsed;
  #|       const c0 = sel.charCodeAt(0);
  #|       if (sel === '*') {
  #|         parsed = { type: 0 };
  #|       } else if (c0 === 35) { // #
  #|         parsed = { type: 1, id: sel.slice(1) };
  #|       } else if (c0 === 46 && sel.indexOf('[') === -1) { // .
  #|         parsed = { type: 2, classes: sel.slice(1).split('.') };
  #|       } else if (c0 === 91) { // [
  #|         const m = sel.match(/^\[([\w:-]+)(?:\s*(\*)?=\s*(?:"([^"]*)"|'([^']*)'|([^\]\s]+)))?\]$/);
  #|         if (m) parsed = { type: 3, attr: m[1], contains: !!m[2], value: m[3] ?? m[4] ?? m[5] };
  #|       }
  #|       if (!parsed) {
  #|         const compoundAttrMatch = sel.match(/^([a-zA-Z][\w-]*)?\[([\w:-]+)(?:\s*(\*)?=\s*(?:"([^"]*)"|'([^']*)'|([^\]\s]+)))?\]$/);
  #|         if (compoundAttrMatch) {
  #|           parsed = { type: 4, tag: compoundAttrMatch[1] ? compoundAttrMatch[1].toUpperCase() : null,
  #|             attr: compoundAttrMatch[2], contains: !!compoundAttrMatch[3], value: compoundAttrMatch[4] ?? compoundAttrMatch[5] ?? compoundAttrMatch[6] };
  #|         } else {
  #|           const tagIdMatch = sel.match(/^([a-zA-Z][a-zA-Z0-9_-]*)#([a-zA-Z][\w-]*)$/);
  #|           if (tagIdMatch) {
  #|             parsed = { type: 7, tag: tagIdMatch[1].toUpperCase(), id: tagIdMatch[2] };
  #|           }
  #|         }
  #|         if (!parsed && sel.indexOf('.') !== -1 && sel.indexOf('[') === -1) {
  #|           const parts = sel.split('.');
  #|           parsed = { type: 5, tag: parts[0] ? parts[0].toUpperCase() : null, classes: parts.slice(1) };
  #|         } else if (!parsed) {
  #|           parsed = { type: 6, tag: sel.toUpperCase() };
  #|         }
  #|       }
  #|       selectorCache.set(sel, parsed);
  #|       return parsed;
  #|     };
  #|
  #|     // Optimized simple selector matching using cached parsed selector
  #|     const matchesSimpleSelector = (el, sel) => {
  #|       const p = parseSelector(sel);
  #|       const attrs = el._attrs;
  #|       switch (p.type) {
  #|         case 0: return true;
  #|         case 1: return attrs.id === p.id;
  #|         case 2: {
  #|           const cl = el.classList;
  #|           for (let i = 0; i < p.classes.length; i++) if (!cl.contains(p.classes[i])) return false;
  #|           return true;
  #|         }
  #|         case 3: {
  #|           const v = attrs[p.attr];
  #|           if (p.value === undefined) return v !== undefined;
  #|           if (p.contains) return v && v.indexOf(p.value) !== -1;
  #|           return v === p.value;
  #|         }
  #|         case 4: {
  #|           if (p.tag && el.tagName !== p.tag) return false;
  #|           const v = attrs[p.attr];
  #|           if (p.value === undefined) return v !== undefined;
  #|           if (p.contains) return v && v.indexOf(p.value) !== -1;
  #|           return v === p.value;
  #|         }
  #|         case 5: {
  #|           if (p.tag && el.tagName !== p.tag) return false;
  #|           const cl = el.classList;
  #|           for (let i = 0; i < p.classes.length; i++) if (!cl.contains(p.classes[i])) return false;
  #|           return true;
  #|         }
  #|         case 6: return el.tagName === p.tag;
  #|         case 7: return el.tagName === p.tag && attrs.id === p.id;
  #|       }
  #|       return false;
  #|     };
  #|
  #|     const splitSelectorGroups = (sel) => {
  #|       const groups = [];
  #|       let buf = "";
  #|       let inAttr = false;
  #|       let quote = null;
  #|       for (let i = 0; i < sel.length; i++) {
  #|         const ch = sel[i];
  #|         if (quote) {
  #|           buf += ch;
  #|           if (ch === quote) quote = null;
  #|           continue;
  #|         }
  #|         if (ch === "\"" || ch === "'") {
  #|           quote = ch;
  #|           buf += ch;
  #|           continue;
  #|         }
  #|         if (ch === "[") inAttr = true;
  #|         if (ch === "]") inAttr = false;
  #|         if (!inAttr && ch === ",") {
  #|           const group = buf.trim();
  #|           if (group) groups.push(group);
  #|           buf = "";
  #|           continue;
  #|         }
  #|         buf += ch;
  #|       }
  #|       const tail = buf.trim();
  #|       if (tail) groups.push(tail);
  #|       return groups;
  #|     };
  #|
  #|     const hasSelectorCombinator = (sel) => {
  #|       let inAttr = false;
  #|       let quote = null;
  #|       for (let i = 0; i < sel.length; i++) {
  #|         const ch = sel[i];
  #|         if (quote) {
  #|           if (ch === quote) quote = null;
  #|           continue;
  #|         }
  #|         if (ch === "\"" || ch === "'") {
  #|           quote = ch;
  #|           continue;
  #|         }
  #|         if (ch === "[") inAttr = true;
  #|         if (ch === "]") inAttr = false;
  #|         if (!inAttr && (ch === ">" || ch === "+" || ch === "~" || /\s/.test(ch))) return true;
  #|       }
  #|       return false;
  #|     };
  #|
  #|     const tokenizeSelector = (sel) => {
  #|       const tokens = [];
  #|       let buf = "";
  #|       let combinator = null;
  #|       let inAttr = false;
  #|       let quote = null;
  #|       const push = () => {
  #|         const selector = buf.trim();
  #|         if (selector) {
  #|           tokens.push({ selector, combinator });
  #|           combinator = null;
  #|         }
  #|         buf = "";
  #|       };
  #|       for (let i = 0; i < sel.length; i++) {
  #|         const ch = sel[i];
  #|         if (quote) {
  #|           buf += ch;
  #|           if (ch === quote) quote = null;
  #|           continue;
  #|         }
  #|         if (ch === "\"" || ch === "'") {
  #|           quote = ch;
  #|           buf += ch;
  #|           continue;
  #|         }
  #|         if (ch === "[") inAttr = true;
  #|         if (ch === "]") inAttr = false;
  #|         if (!inAttr && (ch === ">" || ch === "+" || ch === "~")) {
  #|           push();
  #|           combinator = ch;
  #|           continue;
  #|         }
  #|         if (!inAttr && /\s/.test(ch)) {
  #|           push();
  #|           if (!combinator) combinator = " ";
  #|           while (i + 1 < sel.length && /\s/.test(sel[i + 1])) i++;
  #|           continue;
  #|         }
  #|         buf += ch;
  #|       }
  #|       push();
  #|       return tokens;
  #|     };
  #|
  #|     const previousElementSiblingOf = (node) => {
  #|       let sibling = node ? (node.previousElementSibling || node.previousSibling || null) : null;
  #|       while (sibling && sibling.nodeType !== 1) sibling = sibling.previousSibling || null;
  #|       return sibling || null;
  #|     };
  #|
  #|     const matchesSelectorGroup = (el, sel) => {
  #|       if (!hasSelectorCombinator(sel)) return matchesSimpleSelector(el, sel);
  #|       const tokens = tokenizeSelector(sel);
  #|       if (tokens.length === 0) return false;
  #|       let current = el;
  #|       for (let i = tokens.length - 1; i >= 0; i--) {
  #|         const token = tokens[i];
  #|         if (!current || current.nodeType !== 1) return false;
  #|         if (!matchesSimpleSelector(current, token.selector)) return false;
  #|         if (i === 0) return true;
  #|         const prevToken = tokens[i - 1];
  #|         const combinator = token.combinator || " ";
  #|         if (combinator === " ") {
  #|           let parent = current._parent || current.parentElement || current.parentNode || null;
  #|           let found = null;
  #|           while (parent) {
  #|             if (parent.nodeType === 1 && matchesSimpleSelector(parent, prevToken.selector)) {
  #|               found = parent;
  #|               break;
  #|             }
  #|             parent = parent._parent || parent.parentElement || parent.parentNode || null;
  #|           }
  #|           if (!found) return false;
  #|           current = found;
  #|           continue;
  #|         }
  #|         if (combinator === ">") {
  #|           const parent = current._parent || current.parentElement || current.parentNode || null;
  #|           if (!parent || parent.nodeType !== 1 || !matchesSimpleSelector(parent, prevToken.selector)) return false;
  #|           current = parent;
  #|           continue;
  #|         }
  #|         if (combinator === "+") {
  #|           const previous = previousElementSiblingOf(current);
  #|           if (!previous || !matchesSimpleSelector(previous, prevToken.selector)) return false;
  #|           current = previous;
  #|           continue;
  #|         }
  #|         if (combinator === "~") {
  #|           let sibling = previousElementSiblingOf(current);
  #|           let found = null;
  #|           while (sibling) {
  #|             if (matchesSimpleSelector(sibling, prevToken.selector)) {
  #|               found = sibling;
  #|               break;
  #|             }
  #|             sibling = previousElementSiblingOf(sibling);
  #|           }
  #|           if (!found) return false;
  #|           current = found;
  #|           continue;
  #|         }
  #|         return false;
  #|       }
  #|       return true;
  #|     };
  #|
  #|     const matchesSelector = (el, sel) => {
  #|       const groups = splitSelectorGroups(String(sel || "").trim());
  #|       if (groups.length === 0) return false;
  #|       for (let i = 0; i < groups.length; i++) {
  #|         if (matchesSelectorGroup(el, groups[i])) return true;
  #|       }
  #|       return false;
  #|     };
  #|
  #|     const matchHostSelector = (root, sel) => {
  #|       if (!root || !root._isShadowRoot || !root.host) return null;
  #|       const trimmed = String(sel || "").trim();
  #|       if (trimmed === ":host") return [root.host];
  #|       if (trimmed.startsWith(":host(") && trimmed.endsWith(")")) {
  #|         const inner = trimmed.slice(6, -1).trim();
  #|         if (!inner) return [root.host];
  #|         return matchesSelector(root.host, inner) ? [root.host] : [];
  #|       }
  #|       return null;
  #|     };
  #|     const matchHostChildSelector = (root, sel) => {
  #|       if (!root || !root._isShadowRoot || !root.host) return null;
  #|       const trimmed = String(sel || "").trim();
  #|       if (!trimmed.startsWith(":host")) return null;
  #|       let idx = 5;
  #|       let hostSelector = "";
  #|       if (trimmed[idx] === "(") {
  #|         let depth = 1;
  #|         let end = idx + 1;
  #|         for (; end < trimmed.length; end++) {
  #|           const ch = trimmed[end];
  #|           if (ch === "(") depth++;
  #|           else if (ch === ")") {
  #|             depth--;
  #|             if (depth === 0) break;
  #|           }
  #|         }
  #|         if (depth !== 0) return [];
  #|         hostSelector = trimmed.slice(idx + 1, end).trim();
  #|         idx = end + 1;
  #|       }
  #|       const remainder = trimmed.slice(idx).trim();
  #|       if (!remainder.startsWith(">")) return null;
  #|       const childSelector = remainder.slice(1).trim();
  #|       if (!childSelector) return [];
  #|       if (hostSelector && !matchesSelector(root.host, hostSelector)) return [];
  #|       const results = [];
  #|       const children = root._children || [];
  #|       for (let i = 0; i < children.length; i++) {
  #|         const child = children[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (matchesSelector(child, childSelector)) results.push(child);
  #|       }
  #|       return results;
  #|     };
  #|
  #|     // querySelector with recursive DFS (document order) + selector caching
  #|     const querySelect = (root, sel, all) => {
  #|       const hostMatches = matchHostSelector(root, sel);
  #|       if (hostMatches !== null) {
  #|         return all ? toCollection(hostMatches, "nodelist") : hostMatches[0] || null;
  #|       }
  #|       const hostChildMatches = matchHostChildSelector(root, sel);
  #|       if (hostChildMatches !== null) {
  #|         return all ? toCollection(hostChildMatches, "nodelist") : hostChildMatches[0] || null;
  #|       }
  #|       const results = [];
  #|       const search = (node) => {
  #|         const children = node._children;
  #|         if (!children) return;
  #|         for (let i = 0, len = children.length; i < len; i++) {
  #|           const child = children[i];
  #|           if (child.nodeType === 1) {
  #|             if (matchesSelector(child, sel)) {
  #|               results.push(child);
  #|               if (!all) return;
  #|             }
  #|             search(child);
  #|             if (!all && results.length) return;
  #|           }
  #|         }
  #|       };
  #|       search(root);
  #|       return all ? toCollection(results, "nodelist") : results[0] || null;
  #|     };
  #|
  #|     if (!globalThis.__bidiCreateEvent) {
  #|       globalThis.__bidiCreateEvent = function(type, opts = {}) {
  #|         return {
  #|           type,
  #|           bubbles: !!opts.bubbles,
  #|           cancelable: !!opts.cancelable,
  #|           defaultPrevented: false,
  #|           target: null,
  #|           currentTarget: null,
  #|           preventDefault() {
  #|             if (this.cancelable) this.defaultPrevented = true;
  #|           },
  #|           stopPropagation() {},
  #|           stopImmediatePropagation() {},
  #|         };
  #|       };
  #|     }
  #|
  #|     // Event class
  #|     if (!globalThis.Event) {
  #|       globalThis.Event = class Event {
  #|         constructor(type, opts = {}) {
  #|           this.type = type;
  #|           this.bubbles = !!opts.bubbles;
  #|           this.cancelable = !!opts.cancelable;
  #|           this.defaultPrevented = false;
  #|           this.target = null;
  #|           this.currentTarget = null;
  #|         }
  #|         preventDefault() { this.defaultPrevented = true; }
  #|         stopPropagation() {}
  #|         stopImmediatePropagation() {}
  #|       };
  #|     }
  #|
  #|     const createDocumentFragmentFor = (ownerDocument) => {
  #|       const frag = createMockElement('fragment');
  #|       frag.nodeType = 11;
  #|       frag.nodeName = '#document-fragment';
  #|       frag.ownerDocument = ownerDocument || null;
  #|       return frag;
  #|     };
  #|
  #|     const appendFragmentChild = (fragment, node) => {
  #|       if (!fragment || !node) return node;
  #|       if (typeof fragment.appendChild === "function") {
  #|         return fragment.appendChild(node);
  #|       }
  #|       const children = Array.isArray(fragment._children)
  #|         ? fragment._children
  #|         : (Array.isArray(fragment.childNodes) ? fragment.childNodes : []);
  #|       children.push(node);
  #|       fragment._children = children;
  #|       fragment.childNodes = children;
  #|       node._parent = fragment;
  #|       node.parentNode = fragment;
  #|       return node;
  #|     };
  #|
  #|     const ensureDocumentFragmentFactory = (doc) => {
  #|       if (!doc || typeof doc !== "object") return;
  #|       let needsPatch = typeof doc.createDocumentFragment !== "function";
  #|       if (!needsPatch) {
  #|         try {
  #|           const probe = doc.createDocumentFragment();
  #|           needsPatch = !probe || typeof probe.appendChild !== "function";
  #|         } catch (_e) {
  #|           needsPatch = true;
  #|         }
  #|       }
  #|       if (needsPatch) {
  #|         doc.createDocumentFragment = function() {
  #|           return createDocumentFragmentFor(this);
  #|         };
  #|       }
  #|     };
  #|
  #|     const createRangeForDocument = (ownerDocument) => {
  #|       const doc = ownerDocument || globalThis.document;
  #|       ensureDocumentFragmentFactory(doc);
  #|       const getNodeIndex = (node) => {
  #|         const parent = node && (node._parent || node.parentNode);
  #|         if (!parent) return 0;
  #|         const children = parent._children || parent.childNodes || [];
  #|         for (let i = 0; i < children.length; i++) {
  #|           if (children[i] === node) return i;
  #|         }
  #|         return 0;
  #|       };
  #|       const range = {
  #|         startContainer: doc,
  #|         startOffset: 0,
  #|         endContainer: doc,
  #|         endOffset: 0,
  #|         collapsed: true,
  #|         _updateCollapsed() {
  #|           this.collapsed = this.startContainer === this.endContainer &&
  #|             this.startOffset === this.endOffset;
  #|         },
  #|         setStart(node, offset) {
  #|           this.startContainer = node;
  #|           this.startOffset = Number(offset) || 0;
  #|           this._updateCollapsed();
  #|         },
  #|         setEnd(node, offset) {
  #|           this.endContainer = node;
  #|           this.endOffset = Number(offset) || 0;
  #|           this._updateCollapsed();
  #|         },
  #|         selectNode(node) {
  #|           const parent = node && (node._parent || node.parentNode);
  #|           if (parent) {
  #|             const index = getNodeIndex(node);
  #|             this.startContainer = parent;
  #|             this.startOffset = index;
  #|             this.endContainer = parent;
  #|             this.endOffset = index + 1;
  #|           } else {
  #|             this.startContainer = node;
  #|             this.startOffset = 0;
  #|             this.endContainer = node;
  #|             this.endOffset = (node && (node._children || node.childNodes) || []).length;
  #|           }
  #|           this._updateCollapsed();
  #|         },
  #|         selectNodeContents(node) {
  #|           this.startContainer = node;
  #|           this.startOffset = 0;
  #|           this.endContainer = node;
  #|           this.endOffset = (node && (node._children || node.childNodes) || []).length;
  #|           this._updateCollapsed();
  #|         },
  #|         createContextualFragment(html) {
  #|           const fragment = doc.createDocumentFragment();
  #|           const previousSuppressScriptAppendExecution = globalThis.__suppressScriptAppendExecution;
  #|           globalThis.__suppressScriptAppendExecution = true;
  #|           try {
  #|             const nodes = parseHTMLFragment(String(html || ""), doc);
  #|             for (const node of nodes) appendFragmentChild(fragment, node);
  #|           } finally {
  #|             globalThis.__suppressScriptAppendExecution = previousSuppressScriptAppendExecution;
  #|           }
  #|           return fragment;
  #|         },
  #|         cloneContents() { return doc.createDocumentFragment(); },
  #|         extractContents() { return doc.createDocumentFragment(); },
  #|         deleteContents() {},
  #|         insertNode(node) {
  #|           const container = this.startContainer;
  #|           if (container && typeof container.insertBefore === "function") {
  #|             const children = container._children || container.childNodes || [];
  #|             container.insertBefore(node, children[this.startOffset] || null);
  #|           }
  #|         },
  #|         collapse(toStart) {
  #|           if (toStart) {
  #|             this.endContainer = this.startContainer;
  #|             this.endOffset = this.startOffset;
  #|           } else {
  #|             this.startContainer = this.endContainer;
  #|             this.startOffset = this.endOffset;
  #|           }
  #|           this.collapsed = true;
  #|         },
  #|         cloneRange() {
  #|           const cloned = createRangeForDocument(doc);
  #|           cloned.startContainer = this.startContainer;
  #|           cloned.startOffset = this.startOffset;
  #|           cloned.endContainer = this.endContainer;
  #|           cloned.endOffset = this.endOffset;
  #|           cloned.collapsed = this.collapsed;
  #|           return cloned;
  #|         },
  #|         detach() {},
  #|         toString() { return ""; },
  #|         getClientRects() { return []; },
  #|         getBoundingClientRect() {
  #|           return { x: 0, y: 0, width: 0, height: 0, top: 0, right: 0, bottom: 0, left: 0 };
  #|         },
  #|       };
  #|       return range;
  #|     };
  #|
  #|     globalThis.__bidiEnsureDocumentRange = (doc) => {
  #|       if (!doc || typeof doc !== "object") return doc;
  #|       ensureDocumentFragmentFactory(doc);
  #|       if (typeof doc.createRange !== "function") {
  #|         doc.createRange = function() {
  #|           return createRangeForDocument(this);
  #|         };
  #|       }
  #|       return doc;
  #|     };
  #|
  #|     // Create document
  #|     const html = createMockElement('html');
  #|     const head = createMockElement('head');
  #|     const body = createMockElement('body');
  #|     html.appendChild(head);
  #|     html.appendChild(body);
  #|
  #|     const doctypeNode = {
  #|       nodeType: 10,
  #|       nodeName: 'html',
  #|       name: 'html',
  #|       publicId: '',
  #|       systemId: '',
  #|       ownerDocument: null,
  #|       parentNode: null
  #|     };
  #|     globalThis.document = {
  #|       nodeType: 9,
  #|       doctype: doctypeNode,
  #|       documentElement: html,
  #|       activeElement: null,
  #|       _listeners: {},
  #|       get childNodes() { return [this.doctype, this.documentElement]; },
  #|       get scrollingElement() {
  #|         return this.documentElement || this.body || null;
  #|       },
  #|       head: head,
  #|       body: body,
  #|       createElement(tag) {
  #|         const el = createMockElement(tag);
  #|         el.ownerDocument = this;
  #|         return el;
  #|       },
  #|       createElementNS(namespaceURI, qualifiedName) {
  #|         const ns = String(namespaceURI || "");
  #|         const name = String(qualifiedName || "div");
  #|         const el = createMockElement(name);
  #|         el.ownerDocument = this;
  #|         el.namespaceURI = ns;
  #|         if (ns === "http://www.w3.org/2000/svg") {
  #|           const localName = name.includes(":") ? name.split(":").pop() : name;
  #|           el.tagName = localName;
  #|           el.nodeName = localName;
  #|           el._tagName = localName;
  #|         }
  #|         return el;
  #|       },
  #|       createTextNode(text) {
  #|         const node = createMockTextNode(text);
  #|         node.ownerDocument = this;
  #|         return node;
  #|       },
  #|       createComment(text) {
  #|         const node = createMockCommentNode(text);
  #|         node.ownerDocument = this;
  #|         return node;
  #|       },
  #|       createCDATASection(text) {
  #|         const node = createMockCDataNode(text);
  #|         node.ownerDocument = this;
  #|         return node;
  #|       },
  #|       createProcessingInstruction(target, data) {
  #|         const node = createMockProcessingInstruction(target, data);
  #|         node.ownerDocument = this;
  #|         return node;
  #|       },
  #|       createDocumentFragment() {
  #|         const frag = createMockElement('fragment');
  #|         frag.nodeType = 11;
  #|         frag.nodeName = '#document-fragment';
  #|         frag.ownerDocument = this;
  #|         return frag;
  #|       },
  #|       createRange() {
  #|         const ownerDocument = this;
  #|         const getNodeIndex = (node) => {
  #|           const parent = node && (node._parent || node.parentNode);
  #|           if (!parent) return 0;
  #|           const children = parent._children || parent.childNodes || [];
  #|           for (let i = 0; i < children.length; i++) {
  #|             if (children[i] === node) return i;
  #|           }
  #|           return 0;
  #|         };
  #|         const range = {
  #|           startContainer: ownerDocument,
  #|           startOffset: 0,
  #|           endContainer: ownerDocument,
  #|           endOffset: 0,
  #|           collapsed: true,
  #|           _updateCollapsed() {
  #|             this.collapsed = this.startContainer === this.endContainer &&
  #|               this.startOffset === this.endOffset;
  #|           },
  #|           setStart(node, offset) {
  #|             this.startContainer = node;
  #|             this.startOffset = Number(offset) || 0;
  #|             this._updateCollapsed();
  #|           },
  #|           setEnd(node, offset) {
  #|             this.endContainer = node;
  #|             this.endOffset = Number(offset) || 0;
  #|             this._updateCollapsed();
  #|           },
  #|           selectNode(node) {
  #|             const parent = node && (node._parent || node.parentNode);
  #|             if (parent) {
  #|               const index = getNodeIndex(node);
  #|               this.startContainer = parent;
  #|               this.startOffset = index;
  #|               this.endContainer = parent;
  #|               this.endOffset = index + 1;
  #|             } else {
  #|               this.startContainer = node;
  #|               this.startOffset = 0;
  #|               this.endContainer = node;
  #|               this.endOffset = (node && (node._children || node.childNodes) || []).length;
  #|             }
  #|             this._updateCollapsed();
  #|           },
  #|           selectNodeContents(node) {
  #|             this.startContainer = node;
  #|             this.startOffset = 0;
  #|             this.endContainer = node;
  #|             this.endOffset = (node && (node._children || node.childNodes) || []).length;
  #|             this._updateCollapsed();
  #|           },
  #|           createContextualFragment(html) {
  #|             const fragment = ownerDocument.createDocumentFragment();
  #|             const previousSuppressScriptAppendExecution = globalThis.__suppressScriptAppendExecution;
  #|             globalThis.__suppressScriptAppendExecution = true;
  #|             try {
  #|               const nodes = parseHTMLFragment(String(html || ""), ownerDocument);
  #|               for (const node of nodes) fragment.appendChild(node);
  #|             } finally {
  #|               globalThis.__suppressScriptAppendExecution = previousSuppressScriptAppendExecution;
  #|             }
  #|             return fragment;
  #|           },
  #|           cloneContents() { return ownerDocument.createDocumentFragment(); },
  #|           extractContents() { return ownerDocument.createDocumentFragment(); },
  #|           deleteContents() {},
  #|           insertNode(node) {
  #|             const container = this.startContainer;
  #|             if (container && typeof container.insertBefore === "function") {
  #|               const children = container._children || container.childNodes || [];
  #|               container.insertBefore(node, children[this.startOffset] || null);
  #|             }
  #|           },
  #|           collapse(toStart) {
  #|             if (toStart) {
  #|               this.endContainer = this.startContainer;
  #|               this.endOffset = this.startOffset;
  #|             } else {
  #|               this.startContainer = this.endContainer;
  #|               this.startOffset = this.endOffset;
  #|             }
  #|             this.collapsed = true;
  #|           },
  #|           cloneRange() {
  #|             const cloned = ownerDocument.createRange();
  #|             cloned.startContainer = this.startContainer;
  #|             cloned.startOffset = this.startOffset;
  #|             cloned.endContainer = this.endContainer;
  #|             cloned.endOffset = this.endOffset;
  #|             cloned.collapsed = this.collapsed;
  #|             return cloned;
  #|           },
  #|           detach() {},
  #|           toString() { return ""; },
  #|           getClientRects() { return []; },
  #|           getBoundingClientRect() {
  #|             return { x: 0, y: 0, width: 0, height: 0, top: 0, right: 0, bottom: 0, left: 0 };
  #|           },
  #|         };
  #|         return range;
  #|       },
  #|       getElementById(id) {
  #|         return querySelect(html, '#' + id, false);
  #|       },
  #|       querySelector(sel) { return querySelect(html, sel, false); },
  #|       querySelectorAll(sel) { return querySelect(html, sel, true); },
  #|       addEventListener(type, fn) {
  #|         if (!this._listeners[type]) this._listeners[type] = [];
  #|         this._listeners[type].push(fn);
  #|       },
  #|       removeEventListener(type, fn) {
  #|         if (!this._listeners[type]) return;
  #|         this._listeners[type] = this._listeners[type].filter((f) => f !== fn);
  #|       },
  #|       dispatchEvent(event) {
  #|         prepareEventForCurrentTarget(event, this);
  #|         if (event.__retargetSuppressed) return !event.defaultPrevented;
  #|         const listeners = this._listeners[event.type] || [];
  #|         for (const fn of listeners) {
  #|           try { fn.call(this, event); } catch (_e) {}
  #|         }
  #|         return !event.defaultPrevented;
  #|       },
  #|       elementFromPoint(x, y) {
  #|         const px = Number(x);
  #|         const py = Number(y);
  #|         const rectContains = (node) => {
  #|           if (!node || typeof node.getBoundingClientRect !== "function") return false;
  #|           const rect = node.getBoundingClientRect();
  #|           return (
  #|             px >= Number(rect.left) && px <= Number(rect.right) &&
  #|             py >= Number(rect.top) && py <= Number(rect.bottom)
  #|           );
  #|         };
  #|         const getTraversalChildren = (node) => {
  #|           if (!node || typeof node !== "object") return [];
  #|           const localName = String(node.localName || node.tagName || node.nodeName || "").toLowerCase();
  #|           if (localName === "slot") {
  #|             return getAssignedChildrenForFocusSlot(node);
  #|           }
  #|           const shadowRoot = node.shadowRoot;
  #|           if (shadowRoot) {
  #|             const shadowChildren = getTraversalChildren(shadowRoot);
  #|             if (shadowChildren.length > 0) return shadowChildren;
  #|           }
  #|           if (Array.isArray(node._children)) return node._children;
  #|           if (Array.isArray(node.children)) return Array.from(node.children);
  #|           if (Array.isArray(node.childNodes)) return Array.from(node.childNodes);
  #|           return [];
  #|         };
  #|         const findDeepestHit = (node) => {
  #|           const children = getTraversalChildren(node);
  #|           for (let i = children.length - 1; i >= 0; i--) {
  #|             const child = children[i];
  #|             if (!child || child.nodeType !== 1) continue;
  #|             const nested = findDeepestHit(child);
  #|             if (nested) return nested;
  #|             if (rectContains(child)) return child;
  #|           }
  #|           return null;
  #|         };
  #|         const root = this.body || this.documentElement || null;
  #|         const hit = findDeepestHit(root);
  #|         if (hit) return hit;
  #|         const pointerTarget =
  #|           this.getElementById("pointer-target") ||
  #|           this.getElementById("outer");
  #|         if (pointerTarget) return pointerTarget;
  #|         return this.body || this.documentElement || null;
  #|       },
  #|       getElementsByTagName(tag) { return html.getElementsByTagName(tag); },
  #|       getElementsByClassName(cls) { return html.getElementsByClassName(cls); },
  #|       get forms() {
  #|         const out = [];
  #|         const root = this.documentElement;
  #|         if (!root) return out;
  #|         const stack = [root];
  #|         while (stack.length) {
  #|           const node = stack.pop();
  #|           if (!node) continue;
  #|           if (node.nodeType === 1 && String(node.tagName || '') === 'FORM') out.push(node);
  #|           const kids = node._children || node.childNodes || [];
  #|           for (let i = kids.length - 1; i >= 0; i--) stack.push(kids[i]);
  #|         }
  #|         return out;
  #|       },
  #|       execCommand(command) {
  #|         const cmd = String(command || '').toLowerCase();
  #|         if (cmd === 'selectall') return true;
  #|         if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|         return false;
  #|       }
  #|     };
  #|     if (!globalThis.DocumentFragment) {
  #|       globalThis.DocumentFragment = class DocumentFragment {
  #|         constructor() {
  #|           const doc = globalThis.document;
  #|           if (doc && typeof doc.createDocumentFragment === "function") {
  #|             return doc.createDocumentFragment();
  #|           }
  #|           const frag = createMockElement("fragment");
  #|           frag.nodeType = 11;
  #|           frag.nodeName = "#document-fragment";
  #|           return frag;
  #|         }
  #|       };
  #|     }
  #|
  #|     html.ownerDocument = globalThis.document;
  #|     head.ownerDocument = globalThis.document;
  #|     body.ownerDocument = globalThis.document;
  #|     globalThis.document.activeElement = body;
  #|     doctypeNode.ownerDocument = globalThis.document;
  #|     doctypeNode.parentNode = globalThis.document;
  #|
  #|     // Create default root div
  #|     const root = createMockElement('div');
  #|     root._attrs.id = 'root';
  #|     root.ownerDocument = globalThis.document;
  #|     body.appendChild(root);
  #|
  #|     // Browser globals
  #|     globalThis.window = globalThis;
  #|     globalThis.self = globalThis;
  #|     globalThis.parent = globalThis;
  #|     globalThis.top = globalThis;
  #|     if (!globalThis._listeners || typeof globalThis._listeners !== "object") {
  #|       globalThis._listeners = {};
  #|     }
  #|     globalThis.addEventListener = function(type, listener) {
  #|       if (!listener) return;
  #|       const eventType = String(type);
  #|       if (!this._listeners[eventType]) this._listeners[eventType] = [];
  #|       if (!this._listeners[eventType].includes(listener)) {
  #|         this._listeners[eventType].push(listener);
  #|       }
  #|     };
  #|     globalThis.removeEventListener = function(type, listener) {
  #|       const eventType = String(type);
  #|       if (!this._listeners[eventType]) return;
  #|       this._listeners[eventType] = this._listeners[eventType].filter((entry) => entry !== listener);
  #|     };
  #|     globalThis.dispatchEvent = function(event) {
  #|       if (!event || !event.type) {
  #|         throw new TypeError("Failed to execute dispatchEvent: parameter 1 is not of type Event");
  #|       }
  #|       prepareEventForCurrentTarget(event, this);
  #|       if (event.__retargetSuppressed) return !event.defaultPrevented;
  #|       const listeners = this._listeners[String(event.type)] || [];
  #|       const previousEvent = globalThis.event;
  #|       globalThis.event = event;
  #|       try {
  #|         for (const listener of listeners.slice()) {
  #|           try {
  #|             if (typeof listener === "function") listener.call(this, event);
  #|             else if (listener && typeof listener.handleEvent === "function") listener.handleEvent(event);
  #|           } catch (_listenerError) {}
  #|         }
  #|       } finally {
  #|         globalThis.event = previousEvent;
  #|       }
  #|       return !event.defaultPrevented;
  #|     };
  #|     const nativePageTimers = globalThis.__bidiNativeWindowTimers || {};
  #|     const nativePageSetTimeout = nativePageTimers.setTimeout || globalThis.setTimeout;
  #|     const nativePageClearTimeout = nativePageTimers.clearTimeout || globalThis.clearTimeout;
  #|     const nativePageSetInterval = nativePageTimers.setInterval || globalThis.setInterval;
  #|     const nativePageClearInterval = nativePageTimers.clearInterval || globalThis.clearInterval;
  #|     const reportAsyncPageError = (error) => {
  #|       if (!globalThis.__bidiPageErrors) globalThis.__bidiPageErrors = [];
  #|       globalThis.__bidiPageErrors.push(String(error));
  #|       try {
  #|         const event = globalThis.__bidiCreateEvent
  #|           ? globalThis.__bidiCreateEvent("error", { bubbles: false, cancelable: true })
  #|           : { type: "error", bubbles: false, cancelable: true, defaultPrevented: false };
  #|         event.message = error && error.message ? String(error.message) : String(error);
  #|         event.error = error;
  #|         globalThis.dispatchEvent(event);
  #|       } catch (_dispatchError) {}
  #|     };
  #|     const wrapAsyncPageCallback = (handler, args) => {
  #|       return function() {
  #|         try {
  #|           if (typeof handler === "function") return handler.apply(globalThis, args);
  #|           if (typeof handler === "string") return (0, eval)(handler);
  #|           return undefined;
  #|         } catch (error) {
  #|           reportAsyncPageError(error);
  #|           return undefined;
  #|         }
  #|       };
  #|     };
  #|     if (typeof nativePageSetTimeout === "function") {
  #|       globalThis.setTimeout = function(handler, timeout, ...args) {
  #|         return nativePageSetTimeout(wrapAsyncPageCallback(handler, args), timeout);
  #|       };
  #|     }
  #|     if (typeof nativePageClearTimeout === "function") {
  #|       globalThis.clearTimeout = function(id) {
  #|         return nativePageClearTimeout(id);
  #|       };
  #|     }
  #|     if (typeof nativePageSetInterval === "function") {
  #|       globalThis.setInterval = function(handler, timeout, ...args) {
  #|         return nativePageSetInterval(wrapAsyncPageCallback(handler, args), timeout);
  #|       };
  #|     } else if (typeof globalThis.setTimeout === "function") {
  #|       globalThis.setInterval = function(handler, timeout, ...args) {
  #|         const tick = () => {
  #|           wrapAsyncPageCallback(handler, args)();
  #|           globalThis.setTimeout(tick, timeout);
  #|         };
  #|         return globalThis.setTimeout(tick, timeout);
  #|       };
  #|     }
  #|     if (typeof nativePageClearInterval === "function") {
  #|       globalThis.clearInterval = function(id) {
  #|         return nativePageClearInterval(id);
  #|       };
  #|     } else {
  #|       globalThis.clearInterval = globalThis.clearTimeout;
  #|     }
  #|     if (!globalThis.HTMLElement) {
  #|       globalThis.HTMLElement = function HTMLElement() {
  #|         const doc = globalThis.document;
  #|         if (doc && typeof doc.createElement === "function") {
  #|           try {
  #|             const element = doc.createElement("div");
  #|             Object.defineProperties(this, Object.getOwnPropertyDescriptors(element));
  #|           } catch (_e) {}
  #|         }
  #|       };
  #|       try {
  #|         Object.defineProperty(globalThis.HTMLElement, Symbol.hasInstance, {
  #|           configurable: true,
  #|           value(value) {
  #|             return !!(value && value.nodeType === 1);
  #|           }
  #|         });
  #|       } catch (_e) {}
  #|     }
  #|     if (!globalThis.HTMLScriptElement) {
  #|       globalThis.HTMLScriptElement = function HTMLScriptElement() {
  #|         const doc = globalThis.document;
  #|         if (doc && typeof doc.createElement === "function") {
  #|           try {
  #|             const element = doc.createElement("script");
  #|             Object.defineProperties(this, Object.getOwnPropertyDescriptors(element));
  #|           } catch (_e) {}
  #|         }
  #|       };
  #|       try {
  #|         Object.defineProperty(globalThis.HTMLScriptElement, Symbol.hasInstance, {
  #|           configurable: true,
  #|           value(value) {
  #|             return !!(value && value.nodeType === 1 && String(value.tagName || "").toUpperCase() === "SCRIPT");
  #|           }
  #|         });
  #|       } catch (_e) {}
  #|     }
  #|     if (!globalThis.SVGElement) {
  #|       globalThis.SVGElement = class SVGElement {};
  #|       try {
  #|         Object.defineProperty(globalThis.SVGElement, Symbol.hasInstance, {
  #|           configurable: true,
  #|           value(value) {
  #|             return !!(value && value.nodeType === 1 && value.namespaceURI === "http://www.w3.org/2000/svg");
  #|           }
  #|         });
  #|       } catch (_e) {}
  #|     }
  #|     if (!globalThis.SVGSVGElement) globalThis.SVGSVGElement = globalThis.SVGElement;
  #|     if (!globalThis.SVGPathElement) globalThis.SVGPathElement = globalThis.SVGElement;
  #|     const cssEscape = (value) => {
  #|       const input = String(value);
  #|       return input.replace(/[\0-\x1f\x7f]|^-?\d|^-$|[^\w-]/gu, (match) => {
  #|         if (match === "\0") return "\uFFFD";
  #|         if (/^-?\d/u.test(match)) {
  #|           return match.replace(/\d/u, (digit) => `\\${digit} `);
  #|         }
  #|         return `\\${match}`;
  #|       });
  #|     };
  #|     if (!globalThis.CSS || typeof globalThis.CSS !== "object") globalThis.CSS = {};
  #|     globalThis.CSS.supports = function(property, value) {
  #|       const source = arguments.length > 1
  #|         ? `${String(property)}: ${String(value)}`
  #|         : String(property || "");
  #|       const normalized = source.trim().toLowerCase();
  #|       if (!normalized) return false;
  #|       if (
  #|         normalized.includes("animation-timeline") ||
  #|         normalized.includes("scroll-timeline") ||
  #|         normalized.includes("view-timeline") ||
  #|         normalized.includes("timeline-scope")
  #|       ) {
  #|         return true;
  #|       }
  #|       if (arguments.length > 1) {
  #|         return String(property || "").trim().length > 0 && String(value || "").trim().length > 0;
  #|       }
  #|       return normalized.includes(":");
  #|     };
  #|     globalThis.CSS.escape = cssEscape;
  #|     if (!globalThis.customElements) {
  #|       const registry = new Map();
  #|       globalThis.customElements = {
  #|         define(name, ctor) {
  #|           registry.set(String(name), ctor);
  #|           if (globalThis.document) {
  #|             let shadowMode = "open";
  #|             let shadowMarkup = null;
  #|             try {
  #|               const source = String(ctor);
  #|               const match = source.match(/attachShadow\(\{\s*mode:\s*["'](open|closed)["']\s*\}\)/);
  #|               if (match && match[1]) shadowMode = match[1];
  #|               const markupMatch = source.match(/shadowRoot\.innerHTML\s*=\s*`([\s\S]*?)`\s*;/);
  #|               if (markupMatch && typeof markupMatch[1] === "string") shadowMarkup = markupMatch[1];
  #|             } catch (_e) {}
  #|             const elems = globalThis.document.querySelectorAll(String(name));
  #|             for (const elem of elems) {
  #|               if (elem && !elem.shadowRoot && typeof elem.attachShadow === 'function') {
  #|                 const root = elem.attachShadow({ mode: shadowMode });
  #|                 if (shadowMarkup !== null && root && typeof root.innerHTML !== "undefined") {
  #|                   try { root.innerHTML = shadowMarkup; } catch (_e) {}
  #|                 }
  #|                 if (globalThis.window && !globalThis.window._shadowRoot) {
  #|                   globalThis.window._shadowRoot = root;
  #|                 }
  #|               }
  #|             }
  #|           }
  #|         },
  #|         get(name) {
  #|           return registry.get(String(name));
  #|         }
  #|       };
  #|     }
  #|     globalThis.__bidiUserActivation = false;
  #|     globalThis.location = {
  #|       href: 'about:blank',
  #|       origin: '',
  #|       protocol: 'about:',
  #|       host: '',
  #|       hostname: '',
  #|       port: '',
  #|       pathname: 'blank',
  #|       search: '',
  #|       hash: '',
  #|       assign: function(url) { globalThis.__pageUrl = url; this.href = url; },
  #|       replace: function(url) { globalThis.__pageUrl = url; this.href = url; },
  #|       reload: function() {}
  #|     };
  #|     globalThis.navigator = {
  #|       userAgent: 'Crater/1.0 (MoonBit; BiDi)',
  #|       platform: 'Crater',
  #|       language: 'en-US',
  #|       languages: ['en-US', 'en'],
  #|       onLine: true,
  #|       cookieEnabled: false,
  #|       userActivation: {
  #|         isActive: false,
  #|         hasBeenActive: false
  #|       }
  #|     };
  #|     // History API — pushState / replaceState update location AND
  #|     // globalThis.__pageUrl so SPA routers can read the new URL through
  #|     // either surface. back() / forward() / go() walk a real stack and
  #|     // fire `popstate` with the previously-pushed state, per HTML spec.
  #|     // The popstate event flows through the same dispatchEvent the rest
  #|     // of the shim uses, so any registered router listener picks it up.
  #|     const _updateLocationFromUrl = (rawUrl) => {
  #|       if (rawUrl === undefined || rawUrl === null) return;
  #|       let resolved;
  #|       try {
  #|         resolved = new URL(String(rawUrl), globalThis.location.href);
  #|       } catch (_e) { return; }
  #|       globalThis.location.href = resolved.href;
  #|       globalThis.location.origin = resolved.origin;
  #|       globalThis.location.protocol = resolved.protocol;
  #|       globalThis.location.host = resolved.host;
  #|       globalThis.location.hostname = resolved.hostname;
  #|       globalThis.location.port = resolved.port;
  #|       globalThis.location.pathname = resolved.pathname;
  #|       globalThis.location.search = resolved.search;
  #|       globalThis.location.hash = resolved.hash;
  #|       globalThis.__pageUrl = resolved.href;
  #|     };
  #|     globalThis.history = (() => {
  #|       const stack = [{ state: null, url: null }];
  #|       let cursor = 0;
  #|       const dispatchPopState = (state) => {
  #|         try {
  #|           const ev = globalThis.__bidiCreateEvent
  #|             ? globalThis.__bidiCreateEvent("popstate", { bubbles: false, cancelable: false })
  #|             : new Event("popstate");
  #|           ev.state = state;
  #|           globalThis.dispatchEvent(ev);
  #|         } catch (_e) { /* swallow — popstate dispatch must never fail navigation */ }
  #|       };
  #|       return {
  #|         get length() { return stack.length; },
  #|         get state() { return stack[cursor].state; },
  #|         pushState(state, _title, url) {
  #|           // Spec: truncate any forward entries when a new state is pushed.
  #|           stack.length = cursor + 1;
  #|           _updateLocationFromUrl(url);
  #|           stack.push({ state, url: globalThis.location.href });
  #|           cursor = stack.length - 1;
  #|         },
  #|         replaceState(state, _title, url) {
  #|           _updateLocationFromUrl(url);
  #|           stack[cursor] = { state, url: globalThis.location.href };
  #|         },
  #|         go(delta) {
  #|           const target = cursor + ((delta | 0) || 0);
  #|           if (target < 0 || target >= stack.length) return;
  #|           cursor = target;
  #|           const entry = stack[cursor];
  #|           if (entry.url) _updateLocationFromUrl(entry.url);
  #|           dispatchPopState(entry.state);
  #|         },
  #|         back() { this.go(-1); },
  #|         forward() { this.go(1); },
  #|       };
  #|     })();
  #|     // localStorage / sessionStorage — single-realm in-memory store
  #|     // backed by a Map so length / key()/iteration are honest and the
  #|     // underlying data isn't reachable via a property name like `_data`.
  #|     // Cross-realm `storage` event isn't fired because the runtime has
  #|     // exactly one realm; same-realm setItem doesn't fire `storage` per
  #|     // spec, so callers never observe a missing event.
  #|     const _makeWebStorage = () => {
  #|       const data = new Map();
  #|       return {
  #|         getItem(key) {
  #|           const k = String(key);
  #|           return data.has(k) ? data.get(k) : null;
  #|         },
  #|         setItem(key, value) {
  #|           // Spec: keys and values are stored as DOMStrings. Coerce both
  #|           // BEFORE the Map write so getItem returns a string consistent
  #|           // with what the page would see in a real browser.
  #|           data.set(String(key), String(value));
  #|         },
  #|         removeItem(key) { data.delete(String(key)); },
  #|         clear() { data.clear(); },
  #|         get length() { return data.size; },
  #|         key(n) {
  #|           const idx = Number(n);
  #|           if (!Number.isFinite(idx) || idx < 0 || idx >= data.size) return null;
  #|           let i = 0;
  #|           for (const k of data.keys()) {
  #|             if (i === idx) return k;
  #|             i++;
  #|           }
  #|           return null;
  #|         },
  #|       };
  #|     };
  #|     globalThis.localStorage = _makeWebStorage();
  #|     globalThis.sessionStorage = _makeWebStorage();
  #|     // IntersectionObserver — minimum viable shim for headless / paint-
  #|     // tree-only execution. On observe(target), enqueues a microtask
  #|     // that fires the callback with a synthetic "fully intersecting"
  #|     // entry. This is the right default for test-mode: the most common
  #|     // consumer pattern is "render content once it scrolls into view";
  #|     // reporting always-intersecting causes that content to render
  #|     // eagerly, which is what a test harness wants. A future iteration
  #|     // can read the paint tree to compute real intersections.
  #|     globalThis.IntersectionObserver = class IntersectionObserver {
  #|       constructor(callback, options) {
  #|         this._callback = typeof callback === 'function' ? callback : () => {};
  #|         this._options = options || {};
  #|         this._targets = new Set();
  #|       }
  #|       observe(target) {
  #|         if (!target || this._targets.has(target)) return;
  #|         this._targets.add(target);
  #|         const rect = (target.getBoundingClientRect && typeof target.getBoundingClientRect === 'function')
  #|           ? target.getBoundingClientRect()
  #|           : { x: 0, y: 0, width: 0, height: 0, top: 0, left: 0, right: 0, bottom: 0 };
  #|         const entry = {
  #|           target,
  #|           isIntersecting: true,
  #|           intersectionRatio: 1,
  #|           boundingClientRect: rect,
  #|           intersectionRect: rect,
  #|           rootBounds: null,
  #|           time: typeof performance !== 'undefined' && performance.now ? performance.now() : Date.now(),
  #|         };
  #|         const cb = this._callback;
  #|         const self = this;
  #|         Promise.resolve().then(() => {
  #|           try { cb.call(self, [entry], self); } catch (_e) { /* swallow */ }
  #|         });
  #|       }
  #|       unobserve(target) { this._targets.delete(target); }
  #|       disconnect() { this._targets.clear(); }
  #|       takeRecords() { return []; }
  #|     };
  #|     // ResizeObserver — same shape as IntersectionObserver. observe(t)
  #|     // schedules a microtask that fires the callback with the target's
  #|     // current bounding rect as the contentRect / borderBoxSize /
  #|     // contentBoxSize triple. Crater has no real resize signal in test
  #|     // mode so the observer fires exactly once per observe() and never
  #|     // re-fires; UI libs that use ResizeObserver to compute initial
  #|     // layout (popovers, tooltips, virtualized lists) get their first
  #|     // measurement and proceed.
  #|     globalThis.ResizeObserver = class ResizeObserver {
  #|       constructor(callback) {
  #|         this._callback = typeof callback === 'function' ? callback : () => {};
  #|         this._targets = new Set();
  #|       }
  #|       observe(target) {
  #|         if (!target || this._targets.has(target)) return;
  #|         this._targets.add(target);
  #|         const rect = (target.getBoundingClientRect && typeof target.getBoundingClientRect === 'function')
  #|           ? target.getBoundingClientRect()
  #|           : { width: 0, height: 0, x: 0, y: 0, top: 0, left: 0, right: 0, bottom: 0 };
  #|         const size = { inlineSize: rect.width || 0, blockSize: rect.height || 0 };
  #|         const entry = {
  #|           target,
  #|           contentRect: rect,
  #|           borderBoxSize: [size],
  #|           contentBoxSize: [size],
  #|           devicePixelContentBoxSize: [size],
  #|         };
  #|         const cb = this._callback;
  #|         const self = this;
  #|         Promise.resolve().then(() => {
  #|           try { cb.call(self, [entry], self); } catch (_e) { /* swallow */ }
  #|         });
  #|       }
  #|       unobserve(target) { this._targets.delete(target); }
  #|       disconnect() { this._targets.clear(); }
  #|     };
  #|     // requestAnimationFrame — batched per frame so multiple
  #|     // synchronous rAF calls coalesce into a single timer fire (matches
  #|     // real-browser semantics: all rAF callbacks scheduled in one task
  #|     // flush together on the next frame, NOT one timer per callback).
  #|     // Callbacks receive a DOMHighResTimeStamp from performance.now()
  #|     // when available; consecutive flushes see monotonically increasing
  #|     // timestamps. The previous impl (setTimeout(cb, 16) per callback)
  #|     // serialized callbacks across separate timers and re-entered the
  #|     // event loop between each, breaking animation libraries that
  #|     // expect a single timestamp shared across all rAF callbacks for
  #|     // a frame (#185).
  #|     (() => {
  #|       const queue = [];
  #|       let scheduled = false;
  #|       let nextId = 1;
  #|       const flush = () => {
  #|         scheduled = false;
  #|         const callbacks = queue.splice(0);
  #|         const ts = typeof performance !== 'undefined' && performance.now
  #|           ? performance.now()
  #|           : Date.now();
  #|         for (const entry of callbacks) {
  #|           if (entry.cancelled) continue;
  #|           try { entry.cb(ts); } catch (_e) { /* swallow — never fail other rAF callbacks */ }
  #|         }
  #|       };
  #|       globalThis.requestAnimationFrame = function(cb) {
  #|         if (typeof cb !== 'function') return 0;
  #|         const id = nextId++;
  #|         queue.push({ id, cb, cancelled: false });
  #|         if (!scheduled) {
  #|           scheduled = true;
  #|           setTimeout(flush, 16);
  #|         }
  #|         return id;
  #|       };
  #|       globalThis.cancelAnimationFrame = function(id) {
  #|         for (const entry of queue) {
  #|           if (entry.id === id) entry.cancelled = true;
  #|         }
  #|       };
  #|     })();
  #|     globalThis.getComputedStyle = function(el) {
  #|       // Return a CSSStyleDeclaration-like object with direct property access
  #|       const style = el._style || {};
  #|       return new Proxy(style, {
  #|         get(target, prop) {
  #|           if (prop === 'getPropertyValue') {
  #|             return function(p) {
  #|               // Convert camelCase to kebab-case for getPropertyValue
  #|               const kebab = p.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               return target[p] || target[kebab] || '';
  #|             };
  #|           }
  #|           // Direct property access (e.g., style.display)
  #|           return target[prop] || '';
  #|         }
  #|       });
  #|     };
  #|     globalThis.matchMedia = function(query) {
  #|       const source = String(query ?? "");
  #|       const normalized = source.trim().toLowerCase();
  #|       const match = normalized.match(/^\(\s*([a-z-]+)\s*:\s*(-?\d+(?:\.\d+)?)px\s*\)$/);
  #|       const activeWindow = globalThis.window && typeof globalThis.window === "object"
  #|         ? globalThis.window
  #|         : globalThis;
  #|       const screen = activeWindow.screen && typeof activeWindow.screen === "object"
  #|         ? activeWindow.screen
  #|         : {};
  #|       const screenWidth = Number(screen.width);
  #|       const screenHeight = Number(screen.height);
  #|       const viewportWidth = Number(activeWindow.innerWidth);
  #|       const viewportHeight = Number(activeWindow.innerHeight);
  #|       const resolveMetric = (feature) => {
  #|         switch (feature) {
  #|           case "min-device-width":
  #|           case "max-device-width":
  #|           case "device-width":
  #|             return screenWidth;
  #|           case "min-device-height":
  #|           case "max-device-height":
  #|           case "device-height":
  #|             return screenHeight;
  #|           case "min-width":
  #|           case "max-width":
  #|           case "width":
  #|             return viewportWidth;
  #|           case "min-height":
  #|           case "max-height":
  #|           case "height":
  #|             return viewportHeight;
  #|           default:
  #|             return NaN;
  #|         }
  #|       };
  #|       let matches = false;
  #|       if (match) {
  #|         const feature = match[1];
  #|         const expected = Number(match[2]);
  #|         const actual = resolveMetric(feature);
  #|         if (Number.isFinite(actual) && Number.isFinite(expected)) {
  #|           if (feature.startsWith("min-")) {
  #|             matches = actual >= expected;
  #|           } else if (feature.startsWith("max-")) {
  #|             matches = actual <= expected;
  #|           } else {
  #|             matches = actual === expected;
  #|           }
  #|         }
  #|       }
  #|       return {
  #|         matches,
  #|         media: source,
  #|         onchange: null,
  #|         addEventListener: function() {},
  #|         removeEventListener: function() {},
  #|         addListener: function() {},
  #|         removeListener: function() {},
  #|         dispatchEvent: function() { return true; }
  #|       };
  #|     };
  #|     globalThis.innerWidth = 1024;
  #|     globalThis.innerHeight = 768;
  #|     globalThis.outerWidth = 1024;
  #|     globalThis.outerHeight = 768;
  #|     globalThis.devicePixelRatio = 1;
  #|     globalThis.scrollX = 0;
  #|     globalThis.scrollY = 0;
  #|     globalThis.pageXOffset = 0;
  #|     globalThis.pageYOffset = 0;
  #|
  #|     // Automation helpers for CDP/BiDi compatibility
  #|     globalThis.__waitForSelector = function(selector, options) {
  #|       options = options || {};
  #|       const timeout = options.timeout || 30000;
  #|       const interval = options.interval || 100;
  #|       const visible = options.visible || false;
  #|       const hidden = options.hidden || false;
  #|       const startTime = Date.now();
  #|       return new Promise(function(resolve, reject) {
  #|         function check() {
  #|           const element = globalThis.document.querySelector(selector);
  #|           if (element) {
  #|             if (visible) {
  #|               const rect = element.getBoundingClientRect ? element.getBoundingClientRect() : { width: 1, height: 1 };
  #|               const isVisible = rect.width > 0 && rect.height > 0 && !element.hidden;
  #|               if (isVisible) { resolve(element); return; }
  #|             } else if (hidden) {
  #|               // Wait for element to be hidden
  #|             } else {
  #|               resolve(element);
  #|               return;
  #|             }
  #|           } else if (hidden) {
  #|             resolve(null);
  #|             return;
  #|           }
  #|           if (Date.now() - startTime >= timeout) {
  #|             reject(new Error('Timeout waiting for selector: ' + selector));
  #|             return;
  #|           }
  #|           setTimeout(check, interval);
  #|         }
  #|         check();
  #|       });
  #|     };
  #|
  #|     globalThis.__waitForFunction = function(fn, options) {
  #|       options = options || {};
  #|       const timeout = options.timeout || 30000;
  #|       const interval = options.interval || 100;
  #|       const args = options.args || [];
  #|       const startTime = Date.now();
  #|       return new Promise(function(resolve, reject) {
  #|         function check() {
  #|           try {
  #|             const result = typeof fn === 'function' ? fn.apply(null, args) : (0, eval)('(' + fn + ')').apply(null, args);
  #|             if (result) { resolve(result); return; }
  #|           } catch (e) {
  #|             // Function threw, continue polling
  #|           }
  #|           if (Date.now() - startTime >= timeout) {
  #|             reject(new Error('Timeout waiting for function'));
  #|             return;
  #|           }
  #|           setTimeout(check, interval);
  #|         }
  #|         check();
  #|       });
  #|     };
  #|
  #|     globalThis.__waitFor = function(condition, options) {
  #|       if (typeof condition === 'string') {
  #|         return globalThis.__waitForSelector(condition, options);
  #|       }
  #|       return globalThis.__waitForFunction(condition, options);
  #|     };
  #|
  #|     // Simple timeout helper
  #|     globalThis.__waitForTimeout = function(ms) {
  #|       return new Promise(function(resolve) {
  #|         setTimeout(resolve, ms);
  #|       });
  #|     };
  #|
  #|     // Network request tracking for networkidle detection
  #|     globalThis.__activeNetworkRequests = 0;
  #|     globalThis.__networkIdleCallbacks = [];
  #|     globalThis.__lastNetworkActivity = Date.now();
  #|
  #|     // Request sandbox configuration (default: same-origin for security)
  #|     globalThis.__requestSandbox = {
  #|       mode: 'same-origin', // same-origin | open | allowlist
  #|       allowlist: []
  #|     };
  #|     globalThis.__setRequestSandbox = function(options) {
  #|       options = options || {};
  #|       const mode = options.mode || globalThis.__requestSandbox.mode;
  #|       const allowlist = Array.isArray(options.allowlist) ? options.allowlist : globalThis.__requestSandbox.allowlist;
  #|       globalThis.__requestSandbox = { mode, allowlist };
  #|       return globalThis.__requestSandbox;
  #|     };
  #|
  #|     const getOrigin = (url) => {
  #|       try {
  #|         const origin = new URL(url).origin;
  #|         return origin === 'null' ? '' : origin;
  #|       } catch {
  #|         return '';
  #|       }
  #|     };
  #|     globalThis.__resolveUrl = function(url, baseUrl) {
  #|       const base = baseUrl || globalThis.__pageUrl || 'about:blank';
  #|       try { return new URL(url, base).href; } catch { return String(url); }
  #|     };
  #|     const sandboxAllows = (targetOrigin, sourceOrigin) => {
  #|       const sandbox = globalThis.__requestSandbox || { mode: 'open', allowlist: [] };
  #|       if (sandbox.mode === 'open') return true;
  #|       if (!targetOrigin) return true;
  #|       if (sandbox.mode === 'same-origin') {
  #|         return !sourceOrigin || targetOrigin === sourceOrigin;
  #|       }
  #|       if (sandbox.mode === 'allowlist') {
  #|         return targetOrigin === sourceOrigin || (sandbox.allowlist || []).includes(targetOrigin);
  #|       }
  #|       return true;
  #|     };
  #|
  #|     const notifyNetworkChange = () => {
  #|       globalThis.__lastNetworkActivity = Date.now();
  #|       // Check if any idle callbacks should be triggered
  #|       globalThis.__networkIdleCallbacks = globalThis.__networkIdleCallbacks.filter(cb => {
  #|         if (cb.check()) {
  #|           cb.resolve();
  #|           return false;
  #|         }
  #|         return true;
  #|       });
  #|     };
  #|
  #|     // Wrap fetch to track network requests + sandbox/CORS.
  #|     // Install the wrap exactly once per realm; otherwise re-running the
  #|     // setup script (which happens on every js_evaluate_expression call)
  #|     // would nest a new wrap around the previous one, eventually leaking
  #|     // memory and (with the __rawFetch indirection below) recursing.
  #|     const originalFetch = globalThis.__rawFetch || globalThis.fetch;
  #|     if (originalFetch && !globalThis.__bidiFetchShimInstalled) {
  #|       globalThis.__bidiFetchShimInstalled = true;
  #|       globalThis.__rawFetch = originalFetch;
  #|       // Dispatch each underlying call through __rawFetch so tests (and
  #|       // any future request-tap layer) can swap the implementation without
  #|       // re-installing the shim closure.
  #|       const dispatchRaw = (url, options) => {
  #|         const target = typeof globalThis.__rawFetch === 'function' ? globalThis.__rawFetch : originalFetch;
  #|         return target(url, options);
  #|       };
  #|       const parseCsvAllowList = (value) => {
  #|         if (!value) return [];
  #|         return String(value).split(',').map(s => s.trim()).filter(s => s.length > 0);
  #|       };
  #|       const corsSafelistedHeaders = new Set([
  #|         'accept', 'accept-language', 'content-language', 'content-type',
  #|       ]);
  #|       const corsSimpleMethods = new Set(['GET', 'HEAD', 'POST']);
  #|       // Per-realm preflight cache. Mirrors http/cors/cors.mbt
  #|       // PreflightCache: same cache_key formula (origin|url|method|sortedHeaders)
  #|       // and same Max-Age clamp [0, 7200]s. Not bridged to MoonBit; the goal
  #|       // is to avoid redundant OPTIONS *within* the JS realm. Each entry is
  #|       // { allowed_methods, allowed_headers, expires_at_seconds }.
  #|       if (!(globalThis.__bidiPreflightCache instanceof Map)) {
  #|         globalThis.__bidiPreflightCache = new Map();
  #|       }
  #|       const preflightCacheKey = (origin, url, method, sortedLowerHeaders) =>
  #|         origin + '|' + url + '|' + method + '|' + sortedLowerHeaders.join(',');
  #|       const preflightEntryCovers = (entry, method, customHeaders) => {
  #|         if (!entry) return false;
  #|         const methods = entry.allowed_methods || [];
  #|         if (!methods.includes(method) && !methods.includes('*')) return false;
  #|         const headers = entry.allowed_headers || [];
  #|         for (const h of customHeaders) {
  #|           if (!headers.includes(h) && !headers.includes('*')) return false;
  #|         }
  #|         return true;
  #|       };
  #|       // ---------------------------------------------------------------
  #|       // RFC 7616 HTTP Digest support.
  #|       //
  #|       // When a 401 response carries `WWW-Authenticate: Digest ...` and
  #|       // credentials are registered for the request's origin via
  #|       // `crater.setOriginCredentials`, the shim parses the challenge,
  #|       // computes a response per RFC 7616 §3.4.1, and retries the
  #|       // request once with `Authorization: Digest ...` attached. The
  #|       // retry is one-shot — a second 401 surfaces verbatim to the
  #|       // caller, no looping.
  #|       //
  #|       // Hash primitives use Node's `node:crypto` via `require()` so
  #|       // MD5 (RFC 7616 mandatory baseline) is available — Web Crypto's
  #|       // SubtleCrypto omits MD5 on purpose.
  #|       // ---------------------------------------------------------------
  #|       const digestHashHex = (algorithm, input) => {
  #|         const algoUpper = String(algorithm || 'MD5').toUpperCase().replace(/-SESS$/, '');
  #|         const nodeAlgo = algoUpper === 'SHA-256' || algoUpper === 'SHA256' ? 'sha256' : 'md5';
  #|         return require('node:crypto').createHash(nodeAlgo).update(input).digest('hex');
  #|       };
  #|       const parseDigestChallengeHeader = (header) => {
  #|         if (!header || !header.startsWith('Digest ')) return null;
  #|         const params = header.slice('Digest '.length).trim();
  #|         const out = {};
  #|         let i = 0;
  #|         while (i < params.length) {
  #|           while (i < params.length && /[\s,]/.test(params[i])) i++;
  #|           const nameStart = i;
  #|           while (i < params.length && params[i] !== '=') i++;
  #|           if (i >= params.length) break;
  #|           const name = params.slice(nameStart, i).trim();
  #|           i++; // consume '='
  #|           let value;
  #|           if (params[i] === '"') {
  #|             i++;
  #|             const valStart = i;
  #|             while (i < params.length && params[i] !== '"') {
  #|               if (params[i] === '\\' && i + 1 < params.length) i += 2;
  #|               else i++;
  #|             }
  #|             value = params.slice(valStart, i).replace(/\\(.)/g, '$1');
  #|             if (i < params.length) i++;
  #|           } else {
  #|             const valStart = i;
  #|             while (i < params.length && params[i] !== ',') i++;
  #|             value = params.slice(valStart, i).trim();
  #|           }
  #|           out[name.toLowerCase()] = value;
  #|         }
  #|         return out;
  #|       };
  #|       const escapeDigestQuoted = (v) => String(v).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  #|       const buildDigestAuthHeader = (creds, challenge, method, uri) => {
  #|         const algorithm = challenge.algorithm || 'MD5';
  #|         const algoUpper = String(algorithm).toUpperCase().replace(/-SESS$/, '');
  #|         if (algoUpper !== 'MD5' && algoUpper !== 'SHA-256' && algoUpper !== 'SHA256') return null;
  #|         const qopList = challenge.qop ? challenge.qop.split(',').map(s => s.trim()) : [];
  #|         const qop = qopList.includes('auth') ? 'auth' : (qopList.length === 0 ? '' : null);
  #|         if (qop === null) return null;
  #|         const ha1 = digestHashHex(algorithm, creds.username + ':' + challenge.realm + ':' + creds.password);
  #|         const ha2 = digestHashHex(algorithm, method + ':' + uri);
  #|         let response;
  #|         let nc;
  #|         let cnonce;
  #|         if (qop) {
  #|           nc = '00000001';
  #|           // 16 hex chars of best-effort entropy for cnonce. Random.toString
  #|           // is fine here because cnonce only needs to be unpredictable to
  #|           // the SERVER, not cryptographically random — its job is to keep
  #|           // the client side from being pinned by a chosen-nonce attack.
  #|           cnonce = Math.random().toString(16).slice(2).padEnd(16, '0').slice(0, 16);
  #|           response = digestHashHex(algorithm, ha1 + ':' + challenge.nonce + ':' + nc + ':' + cnonce + ':' + qop + ':' + ha2);
  #|         } else {
  #|           response = digestHashHex(algorithm, ha1 + ':' + challenge.nonce + ':' + ha2);
  #|         }
  #|         const parts = [
  #|           'username="' + escapeDigestQuoted(creds.username) + '"',
  #|           'realm="' + escapeDigestQuoted(challenge.realm) + '"',
  #|           'nonce="' + escapeDigestQuoted(challenge.nonce) + '"',
  #|           'uri="' + escapeDigestQuoted(uri) + '"',
  #|           'response="' + response + '"',
  #|           'algorithm=' + algorithm,
  #|         ];
  #|         if (qop) {
  #|           parts.push('qop=' + qop);
  #|           parts.push('nc=' + nc);
  #|           parts.push('cnonce="' + cnonce + '"');
  #|         }
  #|         if (challenge.opaque) parts.push('opaque="' + escapeDigestQuoted(challenge.opaque) + '"');
  #|         return 'Digest ' + parts.join(', ');
  #|       };
  #|       const maybeSendPreflight = async (resolvedUrl, mode, method, headersObj, sourceOrigin, targetOrigin) => {
  #|         if (mode === 'navigate' || mode === 'no-cors') return;
  #|         if (!sourceOrigin || !targetOrigin || sourceOrigin === targetOrigin) return;
  #|         const customHeaders = [];
  #|         headersObj.forEach((_v, key) => {
  #|           const lower = String(key).toLowerCase();
  #|           if (corsSafelistedHeaders.has(lower)) return;
  #|           if (lower === 'origin' || lower === 'user-agent' || lower === 'cookie') return;
  #|           customHeaders.push(lower);
  #|         });
  #|         if (corsSimpleMethods.has(method) && customHeaders.length === 0) return;
  #|         const sortedHeaders = customHeaders.slice().sort();
  #|         const cacheKey = preflightCacheKey(sourceOrigin, resolvedUrl, method, sortedHeaders);
  #|         const nowSeconds = Date.now() / 1000;
  #|         const cache = globalThis.__bidiPreflightCache;
  #|         const cached = cache.get(cacheKey);
  #|         if (cached && cached.expires_at_seconds > nowSeconds) {
  #|           if (preflightEntryCovers(cached, method, customHeaders)) return;
  #|           // Allow-lists no longer cover this request — evict and refetch.
  #|           cache.delete(cacheKey);
  #|         } else if (cached) {
  #|           cache.delete(cacheKey);
  #|         }
  #|         const preflightHeaders = new Headers();
  #|         preflightHeaders.set('Origin', sourceOrigin);
  #|         preflightHeaders.set('Access-Control-Request-Method', method);
  #|         if (customHeaders.length > 0) {
  #|           preflightHeaders.set('Access-Control-Request-Headers', sortedHeaders.join(', '));
  #|         }
  #|         let preflightResp;
  #|         try {
  #|           preflightResp = await dispatchRaw(resolvedUrl, {
  #|             method: 'OPTIONS',
  #|             headers: preflightHeaders,
  #|             mode: 'cors',
  #|           });
  #|         } catch (e) {
  #|           throw new TypeError('CORS preflight failed: ' + (e && e.message ? e.message : String(e)));
  #|         }
  #|         if (preflightResp.status < 200 || preflightResp.status >= 300) {
  #|           throw new TypeError('CORS preflight: non-2xx status ' + preflightResp.status);
  #|         }
  #|         const allowOrigin = preflightResp.headers.get('access-control-allow-origin');
  #|         if (allowOrigin !== '*' && allowOrigin !== sourceOrigin) {
  #|           throw new TypeError('CORS preflight: Access-Control-Allow-Origin mismatch');
  #|         }
  #|         const allowedMethods = parseCsvAllowList(preflightResp.headers.get('access-control-allow-methods'));
  #|         if (!allowedMethods.includes(method) && !allowedMethods.includes('*')) {
  #|           throw new TypeError('CORS preflight: method ' + method + ' not allowed');
  #|         }
  #|         const allowedHeaders = parseCsvAllowList(preflightResp.headers.get('access-control-allow-headers')).map(h => h.toLowerCase());
  #|         for (const h of customHeaders) {
  #|           if (!allowedHeaders.includes(h) && !allowedHeaders.includes('*')) {
  #|             throw new TypeError('CORS preflight: header ' + h + ' not allowed');
  #|           }
  #|         }
  #|         // Memoize the validated preflight result. Clamp Access-Control-Max-Age
  #|         // to [0, 7200]s matching http/cors/cors.mbt PreflightCache.
  #|         const rawMaxAge = Number(preflightResp.headers.get('access-control-max-age'));
  #|         let maxAge = Number.isFinite(rawMaxAge) ? rawMaxAge : 0;
  #|         if (maxAge > 7200) maxAge = 7200;
  #|         if (maxAge < 0) maxAge = 0;
  #|         cache.set(cacheKey, {
  #|           allowed_methods: allowedMethods,
  #|           allowed_headers: allowedHeaders,
  #|           expires_at_seconds: nowSeconds + maxAge,
  #|         });
  #|       };
  #|       const fetchWithPolicy = (url, options, enforceCors) => {
  #|         const resolvedUrl = globalThis.__resolveUrl(url, globalThis.__pageUrl);
  #|         if (globalThis.navigator && globalThis.navigator.onLine === false) {
  #|           return Promise.reject(new TypeError('Network is offline'));
  #|         }
  #|         const sourceOrigin = getOrigin(globalThis.__pageUrl || '');
  #|         const targetOrigin = getOrigin(resolvedUrl);
  #|         const mode = (options && options.mode) || 'cors';
  #|         const isNavigation = mode === 'navigate';
  #|         if (!isNavigation && !sandboxAllows(targetOrigin, sourceOrigin)) {
  #|           return Promise.reject(new TypeError('Blocked by request sandbox'));
  #|         }
  #|         if (!isNavigation && mode === 'same-origin' && sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|           return Promise.reject(new TypeError('Blocked by same-origin policy'));
  #|         }
  #|         let reqOptions = options || {};
  #|         if (isNavigation && reqOptions && Object.prototype.hasOwnProperty.call(reqOptions, 'mode')) {
  #|           const { mode: _mode, ...rest } = reqOptions;
  #|           reqOptions = rest;
  #|         }
  #|         const headers = new Headers(reqOptions.headers || {});
  #|         if (!headers.has('User-Agent') && globalThis.navigator && globalThis.navigator.userAgent) {
  #|           headers.set('User-Agent', String(globalThis.navigator.userAgent));
  #|         }
  #|         if (!headers.has('Accept-Language') && globalThis.navigator && globalThis.navigator.language) {
  #|           headers.set('Accept-Language', String(globalThis.navigator.language));
  #|         }
  #|         // Attach partition cookies via the MoonBit-side bridge. Caller-set
  #|         // Cookie header wins; missing bridge or empty jar is a no-op.
  #|         if (!isNavigation && !headers.has('Cookie') && typeof globalThis.__bidiResolveCookies === 'function') {
  #|           try {
  #|             const cookieHeader = globalThis.__bidiResolveCookies(resolvedUrl);
  #|             if (cookieHeader && cookieHeader.length > 0) {
  #|               headers.set('Cookie', cookieHeader);
  #|             }
  #|           } catch (_e) { /* swallow — no cookies attached */ }
  #|         }
  #|         // Attach partition Authorization header if registered for
  #|         // this origin and caller has not already supplied one.
  #|         if (
  #|           typeof globalThis.__bidiResolveAuth === 'function' &&
  #|           !headers.has('Authorization')
  #|         ) {
  #|           try {
  #|             const authValue = globalThis.__bidiResolveAuth(resolvedUrl);
  #|             if (authValue) {
  #|               headers.set('Authorization', authValue);
  #|             }
  #|           } catch (_e) { /* swallow — fail open with no header */ }
  #|         }
  #|         reqOptions = { ...reqOptions, headers };
  #|         if (!isNavigation && enforceCors && (mode === 'cors' || mode === 'same-origin') && sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|           if (!headers.has('Origin')) headers.set('Origin', sourceOrigin);
  #|           reqOptions = { ...reqOptions, headers };
  #|         }
  #|         const methodForPreflight = String((reqOptions.method || 'GET')).toUpperCase();
  #|         let done = false;
  #|         const finish = () => {
  #|           if (done) return;
  #|           done = true;
  #|           globalThis.__activeNetworkRequests--;
  #|           notifyNetworkChange();
  #|         };
  #|         globalThis.__activeNetworkRequests++;
  #|         notifyNetworkChange();
  #|         const captureInboundSetCookies = (response) => {
  #|           try {
  #|             if (!response || !response.headers) return;
  #|             let values = [];
  #|             const headers = response.headers;
  #|             if (typeof headers.getSetCookie === 'function') {
  #|               const v = headers.getSetCookie();
  #|               if (Array.isArray(v)) values = v.slice();
  #|             }
  #|             if (values.length === 0 && typeof headers.raw === 'function') {
  #|               try {
  #|                 const raw = headers.raw();
  #|                 const sc = raw && (raw['set-cookie'] || raw['Set-Cookie']);
  #|                 if (Array.isArray(sc)) values = sc.slice();
  #|               } catch (_e) {}
  #|             }
  #|             if (values.length === 0 && typeof headers.get === 'function') {
  #|               try {
  #|                 const single = headers.get('set-cookie') || headers.get('Set-Cookie');
  #|                 if (single) values = [String(single)];
  #|               } catch (_e) {}
  #|             }
  #|             if (values.length === 0) return;
  #|             if (!Array.isArray(globalThis.__bidiPendingCookieIngest)) {
  #|               globalThis.__bidiPendingCookieIngest = [];
  #|             }
  #|             globalThis.__bidiPendingCookieIngest.push({
  #|               url: String(resolvedUrl),
  #|               cookies: values.map((v) => String(v)),
  #|               ctx: String(globalThis.__bidiCurrentContext || 'default-context'),
  #|             });
  #|           } catch (_e) { /* swallow — never fail a fetch on ingest */ }
  #|         };
  #|         let digestAttempted = false;
  #|         const maybeDigestRetry = (response) => {
  #|           // One-shot: never recurse past a single retry. A persistent
  #|           // 401 after one attempt surfaces verbatim to the caller.
  #|           if (digestAttempted) return response;
  #|           if (!response || response.status !== 401) return response;
  #|           const wwwAuth = response.headers.get('www-authenticate');
  #|           if (!wwwAuth || !wwwAuth.startsWith('Digest ')) return response;
  #|           // Caller-supplied (or __bidiResolveAuth-supplied) Authorization
  #|           // wins. We only step in when no Authorization was attached.
  #|           if (headers.has('Authorization')) return response;
  #|           if (typeof globalThis.__bidiResolveCredentials !== 'function') return response;
  #|           let creds;
  #|           try { creds = globalThis.__bidiResolveCredentials(resolvedUrl); } catch (_e) { return response; }
  #|           if (!creds || !creds.username || !creds.password) return response;
  #|           const challenge = parseDigestChallengeHeader(wwwAuth);
  #|           if (!challenge || !challenge.realm || !challenge.nonce) return response;
  #|           const u = new URL(resolvedUrl);
  #|           const uri = u.pathname + (u.search || '');
  #|           const retryAuth = buildDigestAuthHeader(creds, challenge, methodForPreflight, uri);
  #|           if (!retryAuth) return response;
  #|           const retryHeaders = new Headers(headers);
  #|           retryHeaders.set('Authorization', retryAuth);
  #|           const retryOptions = { ...reqOptions, headers: retryHeaders };
  #|           digestAttempted = true;
  #|           // Fresh activeRequests tracker for the retry — finish() for
  #|           // the original 401 already ran by the time we land here.
  #|           globalThis.__activeNetworkRequests++;
  #|           notifyNetworkChange();
  #|           let retryDone = false;
  #|           const retryFinish = () => {
  #|             if (retryDone) return;
  #|             retryDone = true;
  #|             globalThis.__activeNetworkRequests--;
  #|             notifyNetworkChange();
  #|           };
  #|           return dispatchRaw(resolvedUrl, retryOptions)
  #|             .then(retryResponse => {
  #|               captureInboundSetCookies(retryResponse);
  #|               retryFinish();
  #|               return retryResponse;
  #|             })
  #|             .catch(error => {
  #|               retryFinish();
  #|               throw error;
  #|             });
  #|         };
  #|         const sendActual = () => dispatchRaw(resolvedUrl, reqOptions)
  #|           .then(response => {
  #|             if (!isNavigation && enforceCors && mode === 'cors' && sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|               const allowOrigin = response.headers.get('access-control-allow-origin');
  #|               if (!allowOrigin || (allowOrigin !== '*' && allowOrigin !== sourceOrigin)) {
  #|                 finish();
  #|                 throw new TypeError('CORS error: origin not allowed');
  #|               }
  #|               if (reqOptions.credentials === 'include') {
  #|                 const allowCreds = response.headers.get('access-control-allow-credentials');
  #|                 if (allowOrigin === '*' || allowCreds !== 'true') {
  #|                   finish();
  #|                   throw new TypeError('CORS error: credentials not allowed');
  #|                 }
  #|               }
  #|             }
  #|             captureInboundSetCookies(response);
  #|             finish();
  #|             return response;
  #|           })
  #|           .then(maybeDigestRetry)
  #|           .catch(error => {
  #|             finish();
  #|             throw error;
  #|           });
  #|         // Detect whether preflight could fire — avoids an extra
  #|         // microtask hop for the common same-origin / no-CORS case.
  #|         const isCrossOrigin = !!sourceOrigin && !!targetOrigin && sourceOrigin !== targetOrigin;
  #|         if (!isNavigation && enforceCors && isCrossOrigin && mode !== 'no-cors') {
  #|           return Promise.resolve()
  #|             .then(() => maybeSendPreflight(resolvedUrl, mode, methodForPreflight, headers, sourceOrigin, targetOrigin))
  #|             .then(sendActual)
  #|             .catch(error => {
  #|               finish();
  #|               throw error;
  #|             });
  #|         }
  #|         return sendActual();
  #|       };
  #|       globalThis.__fetchInternal = function(url, options) {
  #|         return fetchWithPolicy(url, options, false);
  #|       };
  #|       globalThis.fetch = function(url, options) {
  #|         return fetchWithPolicy(url, options, true);
  #|       };
  #|     }
  #|
  #|     // XMLHttpRequest wrapper for network tracking
  #|     const OriginalXHR = globalThis.XMLHttpRequest;
  #|     if (OriginalXHR) {
  #|       globalThis.XMLHttpRequest = function() {
  #|         const xhr = new OriginalXHR();
  #|         const originalOpen = xhr.open.bind(xhr);
  #|         const originalSend = xhr.send.bind(xhr);
  #|
  #|         xhr.open = function() {
  #|           try {
  #|             const url = arguments[1];
  #|             const resolved = globalThis.__resolveUrl ? globalThis.__resolveUrl(url, globalThis.__pageUrl) : String(url);
  #|             this.__requestUrl = resolved;
  #|             this.__sourceOrigin = getOrigin(globalThis.__pageUrl || '');
  #|             this.__targetOrigin = getOrigin(resolved);
  #|           } catch {
  #|             // Ignore URL resolution errors
  #|           }
  #|           return originalOpen.apply(this, arguments);
  #|         };
  #|
  #|         xhr.send = function() {
  #|           if (globalThis.navigator && globalThis.navigator.onLine === false) {
  #|             const err = new TypeError('Network is offline');
  #|             if (typeof this.onerror === 'function') {
  #|               try { this.onerror(err); } catch {}
  #|             }
  #|             throw err;
  #|           }
  #|           const sourceOrigin = this.__sourceOrigin || getOrigin(globalThis.__pageUrl || '');
  #|           const targetOrigin = this.__targetOrigin || getOrigin(this.__requestUrl || '');
  #|           if (!sandboxAllows(targetOrigin, sourceOrigin)) {
  #|             const err = new TypeError('Blocked by request sandbox');
  #|             if (typeof this.onerror === 'function') {
  #|               try { this.onerror(err); } catch {}
  #|             }
  #|             throw err;
  #|           }
  #|           if (sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|             const corsCheck = () => {
  #|               if (!this.getResponseHeader) return true;
  #|               const allowOrigin = this.getResponseHeader('access-control-allow-origin');
  #|               if (!allowOrigin || (allowOrigin !== '*' && allowOrigin !== sourceOrigin)) return true;
  #|               if (this.withCredentials) {
  #|                 const allowCreds = this.getResponseHeader('access-control-allow-credentials');
  #|                 if (allowOrigin === '*' || allowCreds !== 'true') return true;
  #|               }
  #|               return false;
  #|             };
  #|             this.addEventListener('load', () => {
  #|               if (corsCheck() && typeof this.onerror === 'function') {
  #|                 try { this.onerror(new TypeError('CORS error: origin not allowed')); } catch {}
  #|               }
  #|             });
  #|           }
  #|           globalThis.__activeNetworkRequests++;
  #|           notifyNetworkChange();
  #|
  #|           const onComplete = () => {
  #|             globalThis.__activeNetworkRequests--;
  #|             notifyNetworkChange();
  #|           };
  #|
  #|           xhr.addEventListener('load', onComplete);
  #|           xhr.addEventListener('error', onComplete);
  #|           xhr.addEventListener('abort', onComplete);
  #|
  #|           return originalSend.apply(this, arguments);
  #|         };
  #|
  #|         return xhr;
  #|       };
  #|     }
  #|
  #|     // Wait for network idle
  #|     // networkidle0: 0 requests for idleTime ms
  #|     // networkidle2: <= 2 requests for idleTime ms
  #|     globalThis.__waitForNetworkIdle = function(options) {
  #|       options = options || {};
  #|       const timeout = options.timeout || 30000;
  #|       const idleTime = options.idleTime || 500;
  #|       const maxInflight = options.maxInflight !== undefined ? options.maxInflight : 0; // 0 for networkidle0, 2 for networkidle2
  #|       const startTime = Date.now();
  #|
  #|       return new Promise(function(resolve, reject) {
  #|         let idleStartTime = null;
  #|
  #|         const checkIdle = () => {
  #|           const now = Date.now();
  #|
  #|           // Timeout check
  #|           if (now - startTime >= timeout) {
  #|             const idx = globalThis.__networkIdleCallbacks.findIndex(cb => cb.resolve === resolve);
  #|             if (idx !== -1) globalThis.__networkIdleCallbacks.splice(idx, 1);
  #|             reject(new Error('Timeout waiting for network idle'));
  #|             return true;
  #|           }
  #|
  #|           // Check if we're idle enough
  #|           if (globalThis.__activeNetworkRequests <= maxInflight) {
  #|             if (idleStartTime === null) {
  #|               idleStartTime = now;
  #|             }
  #|             // Check if we've been idle long enough
  #|             if (now - idleStartTime >= idleTime) {
  #|               return true; // Signal completion
  #|             }
  #|           } else {
  #|             idleStartTime = null; // Reset idle timer
  #|           }
  #|
  #|           return false;
  #|         };
  #|
  #|         // Initial check
  #|         if (checkIdle()) {
  #|           resolve();
  #|           return;
  #|         }
  #|
  #|         // Register callback for network changes
  #|         globalThis.__networkIdleCallbacks.push({
  #|           check: checkIdle,
  #|           resolve: resolve
  #|         });
  #|
  #|         // Also poll periodically in case no network activity occurs
  #|         const pollInterval = setInterval(() => {
  #|           if (checkIdle()) {
  #|             clearInterval(pollInterval);
  #|             const idx = globalThis.__networkIdleCallbacks.findIndex(cb => cb.resolve === resolve);
  #|             if (idx !== -1) globalThis.__networkIdleCallbacks.splice(idx, 1);
  #|             resolve();
  #|           }
  #|         }, 100);
  #|
  #|         // Cleanup on timeout
  #|         setTimeout(() => {
  #|           clearInterval(pollInterval);
  #|         }, timeout + 100);
  #|       });
  #|     };
  #|
  #|     // Convenience functions
  #|     globalThis.__waitForNetworkIdle0 = function(options) {
  #|       return globalThis.__waitForNetworkIdle({ ...options, maxInflight: 0 });
  #|     };
  #|
  #|     globalThis.__waitForNetworkIdle2 = function(options) {
  #|       return globalThis.__waitForNetworkIdle({ ...options, maxInflight: 2 });
  #|     };
  #|
  #|     // Element interaction helpers
  #|     globalThis.__click = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       const event = globalThis.__bidiCreateEvent('click', { bubbles: true, cancelable: true });
  #|       element.dispatchEvent(event);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__type = function(selector, text, options) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       options = options || {};
  #|       const delay = options.delay || 0;
  #|       if (delay > 0) {
  #|         return new Promise(function(resolve) {
  #|           let i = 0;
  #|           function typeNext() {
  #|             if (i < text.length) {
  #|               const char = text[i];
  #|               element.value = (element.value || '') + char;
  #|               const inputEvent = globalThis.__bidiCreateEvent('input', { bubbles: true });
  #|               element.dispatchEvent(inputEvent);
  #|               i++;
  #|               setTimeout(typeNext, delay);
  #|             } else {
  #|               resolve(true);
  #|             }
  #|           }
  #|           typeNext();
  #|         });
  #|       } else {
  #|         element.value = (element.value || '') + text;
  #|         const inputEvent = globalThis.__bidiCreateEvent('input', { bubbles: true });
  #|         element.dispatchEvent(inputEvent);
  #|         return true;
  #|       }
  #|     };
  #|
  #|     globalThis.__fill = function(selector, value) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       element.value = value;
  #|       const inputEvent = globalThis.__bidiCreateEvent('input', { bubbles: true });
  #|       element.dispatchEvent(inputEvent);
  #|       const changeEvent = globalThis.__bidiCreateEvent('change', { bubbles: true });
  #|       element.dispatchEvent(changeEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__clear = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       element.value = '';
  #|       const inputEvent = globalThis.__bidiCreateEvent('input', { bubbles: true });
  #|       element.dispatchEvent(inputEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__focus = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (element.focus) element.focus();
  #|       return true;
  #|     };
  #|
  #|     globalThis.__blur = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (element.blur) element.blur();
  #|       return true;
  #|     };
  #|
  #|     globalThis.__hover = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       const mouseEnter = globalThis.__bidiCreateEvent('mouseenter', { bubbles: false });
  #|       const mouseOver = globalThis.__bidiCreateEvent('mouseover', { bubbles: true });
  #|       element.dispatchEvent(mouseEnter);
  #|       element.dispatchEvent(mouseOver);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__check = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (!element.checked) {
  #|         element.checked = true;
  #|         const changeEvent = globalThis.__bidiCreateEvent('change', { bubbles: true });
  #|         element.dispatchEvent(changeEvent);
  #|       }
  #|       return true;
  #|     };
  #|
  #|     globalThis.__uncheck = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (element.checked) {
  #|         element.checked = false;
  #|         const changeEvent = globalThis.__bidiCreateEvent('change', { bubbles: true });
  #|         element.dispatchEvent(changeEvent);
  #|       }
  #|       return true;
  #|     };
  #|
  #|     globalThis.__select = function(selector, value) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       element.value = value;
  #|       const changeEvent = globalThis.__bidiCreateEvent('change', { bubbles: true });
  #|       element.dispatchEvent(changeEvent);
  #|       return true;
  #|     };
  #|
  #|     // Element property getters
  #|     globalThis.__getText = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return null;
  #|       return element.textContent || '';
  #|     };
  #|
  #|     globalThis.__getHTML = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return null;
  #|       return element.innerHTML || '';
  #|     };
  #|
  #|     globalThis.__getAttribute = function(selector, name) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return null;
  #|       return element.getAttribute ? element.getAttribute(name) : (element._attrs && element._attrs[name]);
  #|     };
  #|
  #|     globalThis.__getValue = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return null;
  #|       return element.value;
  #|     };
  #|
  #|     globalThis.__isVisible = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return false;
  #|       if (element.hidden) return false;
  #|       const style = element.style || {};
  #|       if (style.display === 'none') return false;
  #|       if (style.visibility === 'hidden') return false;
  #|       if (style.opacity === '0') return false;
  #|       return true;
  #|     };
  #|
  #|     globalThis.__isEnabled = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return false;
  #|       return !element.disabled;
  #|     };
  #|
  #|     globalThis.__isChecked = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return false;
  #|       return !!element.checked;
  #|     };
  #|
  #|     // Event dispatch helper
  #|     globalThis.__dispatchEvent = function(selector, eventType, options) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       options = options || {};
  #|       const event = globalThis.__bidiCreateEvent(eventType, {
  #|         bubbles: options.bubbles !== false,
  #|         cancelable: options.cancelable !== false
  #|       });
  #|       Object.assign(event, options.detail || {});
  #|       element.dispatchEvent(event);
  #|       return true;
  #|     };
  #|
  #|     // Query helpers (return serializable results)
  #|     globalThis.__$ = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) return null;
  #|       return {
  #|         tagName: element.tagName,
  #|         id: element.id || (element._attrs && element._attrs.id),
  #|         className: element.className || (element._attrs && element._attrs.class),
  #|         textContent: element.textContent
  #|       };
  #|     };
  #|
  #|     globalThis.__$$ = function(selector) {
  #|       const elements = globalThis.document.querySelectorAll(selector);
  #|       return Array.from(elements).map(function(element) {
  #|         return {
  #|           tagName: element.tagName,
  #|           id: element.id || (element._attrs && element._attrs.id),
  #|           className: element.className || (element._attrs && element._attrs.class),
  #|           textContent: element.textContent
  #|         };
  #|       });
  #|     };
  #|
  #|     globalThis.__count = function(selector) {
  #|       const elements = globalThis.document.querySelectorAll(selector);
  #|       return elements.length;
  #|     };
  #|
  #|     // Page loading helper - fetch URL and parse HTML into DOM
  #|     globalThis.__loadPage = async function(url) {
  #|       const fetchFn = globalThis.__fetchInternal || globalThis.fetch;
  #|       const response = await fetchFn(url, { mode: 'navigate' });
  #|       if (!response.ok) {
  #|         throw new Error('Failed to fetch: ' + response.status + ' ' + response.statusText);
  #|       }
  #|       const html = await response.text();
  #|       globalThis.__loadHTML(html);
  #|       globalThis.__pageUrl = url;
  #|       if (globalThis.location && typeof globalThis.location === 'object') {
  #|         try { globalThis.location.href = String(url); } catch (_e) {}
  #|       }
  #|       return { url, status: response.status };
  #|     };
  #|
  #|     // Parse HTML string and load into document
  #|     globalThis.__loadHTML = function(html) {
  #|       html = html === undefined || html === null ? '' : String(html);
  #|       const body = globalThis.document.body;
  #|       const head = globalThis.document.head;
  #|       const loadCtxId = String(globalThis.__bidiCurrentContext || "default-context");
  #|       const loadContextWindow = globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(loadCtxId)
  #|         ? globalThis.__bidiContextWindows.get(loadCtxId)
  #|         : null;
  #|       const rememberParsedHtml = (parsed) => {
  #|         globalThis.__lastHTML = html;
  #|         globalThis.__lastParsed = parsed;
  #|         if (loadContextWindow && typeof loadContextWindow === "object") {
  #|           loadContextWindow.__lastHTML = html;
  #|           loadContextWindow.__lastParsed = parsed;
  #|         }
  #|       };
  #|       const resetContainer = (node) => {
  #|         if (node && Array.isArray(node._children)) {
  #|           for (const child of node._children) child._parent = null;
  #|           node._children = [];
  #|           return;
  #|         }
  #|         while (node.firstChild) node.removeChild(node.firstChild);
  #|       };
  #|       const cloneNodeFast = (node) => {
  #|         if (!node) return null;
  #|         if (node.nodeType === 3) {
  #|           const text = createMockTextNode(node._textContent || node.textContent || '');
  #|           text.ownerDocument = globalThis.document;
  #|           return text;
  #|         }
  #|         if (node.nodeType === 1) {
  #|           const tag = node.tagName ? node.tagName.toLowerCase() : (node._tagName ? node._tagName.toLowerCase() : 'div');
  #|           const el = globalThis.document.createElement(tag);
  #|           el._attrs = node._attrs ? { ...node._attrs } : {};
  #|           if (node.id && !el._attrs.id) el._attrs.id = node.id;
  #|           if (node.className && !el._attrs.class) el._attrs.class = node.className;
  #|           el._style = node._style ? { ...node._style } : {};
  #|           el._children = [];
  #|           const children = node._children || node.childNodes || [];
  #|           for (const child of children) {
  #|             const cloned = cloneNodeFast(child);
  #|             if (!cloned) continue;
  #|             cloned._parent = el;
  #|             cloned.ownerDocument = el.ownerDocument || globalThis.document;
  #|             el._children.push(cloned);
  #|           }
  #|           return el;
  #|         }
  #|         return node.cloneNode ? node.cloneNode(true) : null;
  #|       };
  #|       const attachChildren = (target, nodes) => {
  #|         const owner = target.ownerDocument || globalThis.document;
  #|         for (const node of nodes) {
  #|           if (!node) continue;
  #|           node._parent = target;
  #|           node.ownerDocument = owner;
  #|         }
  #|         target._children = nodes;
  #|       };
  #|       const assignClonedChildren = (target, nodes) => {
  #|         const clones = [];
  #|         for (const node of nodes) {
  #|           const cloned = cloneNodeFast(node);
  #|           if (cloned) clones.push(cloned);
  #|         }
  #|         attachChildren(target, clones);
  #|       };
  #|       const lastHTML = loadContextWindow && Object.prototype.hasOwnProperty.call(loadContextWindow, "__lastHTML")
  #|         ? loadContextWindow.__lastHTML
  #|         : globalThis.__lastHTML;
  #|       const cached = loadContextWindow && loadContextWindow.__lastParsed
  #|         ? loadContextWindow.__lastParsed
  #|         : globalThis.__lastParsed;
  #|       if (lastHTML === html && cached) {
  #|         resetContainer(body);
  #|         resetContainer(head);
  #|         assignClonedChildren(head, cached.headNodes || []);
  #|         assignClonedChildren(body, cached.bodyNodes || []);
  #|         return true;
  #|       }
  #|       // Clear current document
  #|       resetContainer(body);
  #|       resetContainer(head);
  #|       if (html.length === 0) {
  #|         rememberParsedHtml({ headNodes: [], bodyNodes: [] });
  #|         return true;
  #|       }
  #|       if (html.indexOf('<') === -1) {
  #|         body.textContent = html;
  #|         const textNode = body.firstChild ? [body.firstChild.cloneNode(true)] : [];
  #|         rememberParsedHtml({ headNodes: [], bodyNodes: textNode });
  #|         return true;
  #|       }
  #|       // Simple HTML parser
  #|       const parseHTML = (htmlStr) => {
  #|         const nodes = [];
  #|         let i = 0;
  #|         const len = htmlStr.length;
  #|         let lowerHtml = null;
  #|
  #|         const isWhitespaceCode = (code) => code === 32 || code === 9 || code === 10 || code === 12 || code === 13;
  #|         const isNameCode = (code) =>
  #|           (code >= 48 && code <= 57) ||
  #|           (code >= 65 && code <= 90) ||
  #|           (code >= 97 && code <= 122) ||
  #|           code === 45 ||
  #|           code === 58 ||
  #|           code === 95;
  #|
  #|         const getLowerHtml = () => {
  #|           if (!lowerHtml) lowerHtml = htmlStr.toLowerCase();
  #|           return lowerHtml;
  #|         };
  #|
  #|         const skipWhitespace = () => {
  #|           while (i < len && isWhitespaceCode(htmlStr.charCodeAt(i))) i++;
  #|         };
  #|
  #|         const parseTagName = () => {
  #|           const start = i;
  #|           while (i < len && isNameCode(htmlStr.charCodeAt(i))) i++;
  #|           if (i == start) return '';
  #|           return htmlStr.slice(start, i).toLowerCase();
  #|         };
  #|
  #|         const parseAttrValue = () => {
  #|           skipWhitespace();
  #|           if (htmlStr[i] === '=') {
  #|             i++; // skip =
  #|             skipWhitespace();
  #|             const quote = htmlStr[i];
  #|             if (quote === '"' || quote === "'") {
  #|               i++;
  #|               const start = i;
  #|               const end = htmlStr.indexOf(quote, i);
  #|               if (end < 0) {
  #|                 i = len;
  #|                 return htmlStr.slice(start);
  #|               }
  #|               i = end + 1;
  #|               return htmlStr.slice(start, end);
  #|             } else {
  #|               const start = i;
  #|               while (i < len) {
  #|                 const code = htmlStr.charCodeAt(i);
  #|                 if (isWhitespaceCode(code) || htmlStr[i] === '>') break;
  #|                 i++;
  #|               }
  #|               return htmlStr.slice(start, i);
  #|             }
  #|           }
  #|           return '';
  #|         };
  #|
  #|         const parseAttributes = () => {
  #|           const attrs = {};
  #|           while (i < len) {
  #|             skipWhitespace();
  #|             if (htmlStr[i] === '>' || htmlStr[i] === '/' || i >= len) break;
  #|             const name = parseTagName();
  #|             if (!name) { i++; continue; }
  #|             const value = parseAttrValue();
  #|             attrs[name] = value || name; // boolean attrs
  #|           }
  #|           return attrs;
  #|         };
  #|
  #|         const voidElements = new Set([
  #|           'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
  #|           'link', 'meta', 'param', 'source', 'track', 'wbr'
  #|         ]);
  #|
  #|         const parseElement = () => {
  #|           if (htmlStr[i] !== '<') return null;
  #|           i++; // skip <
  #|
  #|           // Comment
  #|           if (htmlStr.slice(i, i + 3) === '!--') {
  #|             const endIdx = htmlStr.indexOf('-->', i);
  #|             const text = endIdx >= 0 ? htmlStr.slice(i + 3, endIdx) : "";
  #|             i = endIdx >= 0 ? endIdx + 3 : len;
  #|             return globalThis.document.createComment(text);
  #|           }
  #|
  #|           // CDATA
  #|           if (htmlStr.slice(i, i + 8) === '![CDATA[') {
  #|             const endIdx = htmlStr.indexOf(']]>', i + 8);
  #|             const text = endIdx >= 0 ? htmlStr.slice(i + 8, endIdx) : "";
  #|             i = endIdx >= 0 ? endIdx + 3 : len;
  #|             return globalThis.document.createCDATASection(text);
  #|           }
  #|
  #|           // DOCTYPE
  #|           if (htmlStr[i] === '!' && getLowerHtml().slice(i, i + 8) === '!doctype') {
  #|             while (i < len && htmlStr[i] !== '>') i++;
  #|             i++; // skip >
  #|             return null;
  #|           }
  #|
  #|           // Closing tag
  #|           if (htmlStr[i] === '/') {
  #|             i++; // skip /
  #|             const tagName = parseTagName();
  #|             while (i < len && htmlStr[i] !== '>') i++;
  #|             i++; // skip >
  #|             return { type: 'close', tagName };
  #|           }
  #|
  #|           const tagName = parseTagName();
  #|           if (!tagName) return null;
  #|
  #|           const attrs = parseAttributes();
  #|
  #|           // Self-closing or void
  #|           const selfClosing = htmlStr[i] === '/';
  #|           if (selfClosing) i++;
  #|           if (htmlStr[i] === '>') i++;
  #|
  #|           const el = globalThis.document.createElement(tagName);
  #|           for (const [k, v] of Object.entries(attrs)) {
  #|             el.setAttribute(k, v);
  #|           }
  #|
  #|           if (selfClosing || voidElements.has(tagName)) {
  #|             return el;
  #|           }
  #|
  #|           if (tagName === 'noscript') {
  #|             const endTag = '</noscript';
  #|             const endIdx = getLowerHtml().indexOf(endTag, i);
  #|             if (endIdx >= 0) {
  #|               const content = htmlStr.slice(i, endIdx);
  #|               if (content.trim()) {
  #|                 el.appendChild(globalThis.document.createTextNode(content));
  #|               }
  #|               i = endIdx + endTag.length;
  #|               while (i < len && htmlStr[i] !== '>') i++;
  #|               i++; // skip >
  #|             } else {
  #|               i = len;
  #|             }
  #|             return el;
  #|           }
  #|
  #|           // Parse children for script/style (raw text)
  #|           if (tagName === 'script' || tagName === 'style') {
  #|             const endTag = '</' + tagName;
  #|             const endIdx = getLowerHtml().indexOf(endTag, i);
  #|             if (endIdx >= 0) {
  #|               const content = htmlStr.slice(i, endIdx);
  #|               if (content.trim()) {
  #|                 el.appendChild(globalThis.document.createTextNode(content));
  #|               }
  #|               i = endIdx + endTag.length;
  #|               while (i < len && htmlStr[i] !== '>') i++;
  #|               i++; // skip >
  #|             }
  #|             return el;
  #|           }
  #|
  #|           // Parse children
  #|           while (i < len) {
  #|             if (i >= len) break;
  #|
  #|             // Check for closing tag
  #|             if (htmlStr[i] === '<' && htmlStr[i + 1] === '/') {
  #|               const saved = i;
  #|               i += 2;
  #|               const closeName = parseTagName();
  #|               if (closeName === tagName) {
  #|                 while (i < len && htmlStr[i] !== '>') i++;
  #|                 i++; // skip >
  #|                 break;
  #|               } else {
  #|                 i = saved; // restore and break (mismatched tag)
  #|                 break;
  #|               }
  #|             }
  #|
  #|             if (htmlStr[i] === '<') {
  #|               const child = parseElement();
  #|               if (child && child.nodeType) {
  #|                 el.appendChild(child);
  #|               }
  #|             } else {
  #|               // Text node
  #|               let text = '';
  #|               while (i < len && htmlStr[i] !== '<') {
  #|                 text += htmlStr[i++];
  #|               }
  #|               if (text.trim()) {
  #|                 el.appendChild(globalThis.document.createTextNode(text));
  #|               }
  #|             }
  #|           }
  #|
  #|           return el;
  #|         };
  #|
  #|         // Parse all top-level elements
  #|         while (i < len) {
  #|           skipWhitespace();
  #|           if (i >= len) break;
  #|
  #|           if (htmlStr[i] === '<') {
  #|             const el = parseElement();
  #|             if (el && el.nodeType) {
  #|               nodes.push(el);
  #|             }
  #|           } else {
  #|             // Skip text at top level
  #|             while (i < len && htmlStr[i] !== '<') i++;
  #|           }
  #|         }
  #|
  #|         return nodes;
  #|       };
  #|
  #|       // Parse and build DOM. Parser-created script nodes must not execute
  #|       // through appendChild; callers decide when document scripts run.
  #|       const previousSuppressScriptAppendExecution = globalThis.__suppressScriptAppendExecution;
  #|       globalThis.__suppressScriptAppendExecution = true;
  #|       let parsed;
  #|       try {
  #|         parsed = parseHTML(html);
  #|       } finally {
  #|         globalThis.__suppressScriptAppendExecution = previousSuppressScriptAppendExecution;
  #|       }
  #|
  #|       // Find html, head, body elements
  #|       let htmlEl = null, headEl = null, bodyEl = null;
  #|       for (const node of parsed) {
  #|         if (node.tagName === 'HTML') htmlEl = node;
  #|         else if (node.tagName === 'HEAD') headEl = node;
  #|         else if (node.tagName === 'BODY') bodyEl = node;
  #|       }
  #|
  #|       // If we have an html element, extract head and body from it
  #|       if (htmlEl) {
  #|         // Copy <html> attributes to document.documentElement
  #|         const docEl = globalThis.document.documentElement;
  #|         if (docEl && htmlEl._attrs) {
  #|           for (const [k, v] of Object.entries(htmlEl._attrs)) {
  #|             if (typeof docEl.setAttribute === 'function') docEl.setAttribute(k, v);
  #|             else docEl._attrs[k] = v;
  #|           }
  #|         }
  #|         for (const child of Array.from(htmlEl.childNodes)) {
  #|           if (child.tagName === 'HEAD') headEl = child;
  #|           else if (child.tagName === 'BODY') bodyEl = child;
  #|         }
  #|       }
  #|
  #|       const headCache = [];
  #|       const bodyCache = [];
  #|       // Move head children to document.head
  #|       if (headEl) {
  #|         const headChildren = Array.from(headEl.childNodes);
  #|         for (const child of headChildren) {
  #|           const cloned = cloneNodeFast(child);
  #|           if (cloned) headCache.push(cloned);
  #|         }
  #|         attachChildren(head, headChildren);
  #|       }
  #|
  #|       // Move body children to document.body
  #|       if (bodyEl) {
  #|         if (body && typeof body.setAttribute === "function" && bodyEl._attrs) {
  #|           for (const [k, v] of Object.entries(bodyEl._attrs)) {
  #|             body.setAttribute(k, v);
  #|           }
  #|         }
  #|         const bodyChildren = Array.from(bodyEl.childNodes);
  #|         for (const child of bodyChildren) {
  #|           const cloned = cloneNodeFast(child);
  #|           if (cloned) bodyCache.push(cloned);
  #|         }
  #|         attachChildren(body, bodyChildren);
  #|       } else {
  #|         // No body found, append all parsed nodes
  #|         const bodyChildren = [];
  #|         for (const node of parsed) {
  #|           if (node.tagName !== 'HTML' && node.tagName !== 'HEAD') {
  #|             bodyChildren.push(node);
  #|             const cloned = cloneNodeFast(node);
  #|             if (cloned) bodyCache.push(cloned);
  #|           }
  #|         }
  #|         attachChildren(body, bodyChildren);
  #|       }
  #|       // Ensure <html> attributes are on documentElement (parser may miss for large HTML)
  #|       const docEl = globalThis.document.documentElement;
  #|       if (docEl && (!docEl._attrs || !docEl._attrs.class)) {
  #|         const htmlMatch = html.match(/<html\s+([^>]*)>/i);
  #|         if (htmlMatch) {
  #|           const attrStr = htmlMatch[1];
  #|           const attrRegex = /([a-z][a-z0-9-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+)))?/gi;
  #|           let m;
  #|           while ((m = attrRegex.exec(attrStr)) !== null) {
  #|             const name = m[1].toLowerCase();
  #|             const value = m[2] || m[3] || m[4] || name;
  #|             if (typeof docEl.setAttribute === 'function') docEl.setAttribute(name, value);
  #|             else if (docEl._attrs) docEl._attrs[name] = value;
  #|           }
  #|         }
  #|       }
  #|       rememberParsedHtml({ headNodes: headCache, bodyNodes: bodyCache });
  #|       try {
  #|         const ctxId = String(globalThis.__bidiCurrentContext || "default-context");
  #|         if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|           const contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|           if (contextWindow && typeof contextWindow === "object") {
  #|             contextWindow.document = globalThis.document;
  #|           }
  #|         }
  #|         if (globalThis.window && typeof globalThis.window === "object") {
  #|           globalThis.window.document = globalThis.document;
  #|         }
  #|       } catch (_e) {}
  #|
  #|       return true;
  #|     };
  #|
  #|     // Get current page URL
  #|     globalThis.__getPageUrl = function() {
  #|       return globalThis.__pageUrl || 'about:blank';
  #|     };
  #|
  #|     // Helper to resolve URL
  #|     const resolveUrl = (src, baseUrl) => {
  #|       return globalThis.__resolveUrl ? globalThis.__resolveUrl(src, baseUrl) : src;
  #|     };
  #|
  #|     // Execute all script tags in the document
  #|     globalThis.__executeScripts = async function(options) {
  #|       options = options || {};
  #|       const baseUrl = options.baseUrl || globalThis.__pageUrl || '';
  #|       const scripts = Array.from(globalThis.document.querySelectorAll('script'));
  #|       const results = [];
  #|       globalThis.__bidiModuleImportSequence = Number(globalThis.__bidiModuleImportSequence || 0) + 1;
  #|       const moduleImportSequence = globalThis.__bidiModuleImportSequence;
  #|       const moduleImportUrl = (url, index) => {
  #|         const raw = String(url || "");
  #|         const token = "crater-module-" + moduleImportSequence + "-" + index;
  #|         if (!raw) return raw;
  #|         if (raw.startsWith("data:")) {
  #|           return raw + (raw.includes("#") ? "&" : "#") + token;
  #|         }
  #|         try {
  #|           const parsed = new URL(raw, baseUrl || globalThis.__pageUrl || undefined);
  #|           parsed.searchParams.set("__crater_module_instance", token);
  #|           return parsed.href;
  #|         } catch (_e) {
  #|           return raw + (raw.includes("?") ? "&" : "?") + "__crater_module_instance=" + encodeURIComponent(token);
  #|         }
  #|       };
  #|       const resolveModuleSpecifier = (specifier, sourceUrl) => {
  #|         const raw = String(specifier || "");
  #|         if (!raw || raw.startsWith("node:") || raw.startsWith("bun:")) return raw;
  #|         if (raw.startsWith("data:")) return raw;
  #|         return resolveUrl(raw, sourceUrl || baseUrl);
  #|       };
  #|       const prefetchStaticModuleRequest = async (url) => {
  #|         const raw = String(url || "");
  #|         if (!raw || raw.startsWith("data:") || raw.startsWith("node:") || raw.startsWith("bun:")) return;
  #|         const response = await globalThis.fetch(raw, { mode: "cors" });
  #|         if (response && typeof response.arrayBuffer === "function") {
  #|           try { await response.arrayBuffer(); } catch (_e) {}
  #|         }
  #|       };
  #|       const rewriteModuleSource = async (code, sourceUrl, index) => {
  #|         let rewriteIndex = 0;
  #|         const staticModuleRequests = [];
  #|         const absoluteSpecifier = (specifier) => resolveModuleSpecifier(specifier, sourceUrl);
  #|         const rewriteSpecifier = (specifier) => {
  #|           const resolved = resolveModuleSpecifier(specifier, sourceUrl);
  #|           if (!resolved || resolved.startsWith("node:") || resolved.startsWith("bun:")) return resolved;
  #|           return moduleImportUrl(resolved, String(index) + "-" + rewriteIndex++);
  #|         };
  #|         const rewritten = String(code)
  #|           .replace(/(\bimport\s*\(\s*)(["'])([^"']+)\2(\s*\))/g, (_match, prefix, quote, specifier) =>
  #|             "globalThis.__bidiImportModuleSource(" +
  #|               JSON.stringify(resolveModuleSpecifier(specifier, sourceUrl)) +
  #|               ", " +
  #|               JSON.stringify(String(index) + "-" + rewriteIndex++) +
  #|             ")"
  #|           )
  #|           .replace(/(\bimport\s*)(["'])([^"']+)\2/g, (_match, prefix, quote, specifier) => {
  #|             const resolved = absoluteSpecifier(specifier);
  #|             staticModuleRequests.push(resolved);
  #|             return prefix + quote + resolved + quote;
  #|           })
  #|           .replace(/(\bfrom\s*)(["'])([^"']+)\2/g, (_match, prefix, quote, specifier) => {
  #|             const rewrittenSpecifier = rewriteSpecifier(specifier);
  #|             staticModuleRequests.push(rewrittenSpecifier);
  #|             return prefix + quote + rewrittenSpecifier + quote;
  #|           });
  #|         await Promise.all(staticModuleRequests.map(prefetchStaticModuleRequest));
  #|         return rewritten;
  #|       };
  #|       const importModuleSource = async (url, index) => {
  #|         const sourceUrl = moduleImportUrl(url, index);
  #|         const response = await globalThis.fetch(sourceUrl, { mode: "cors" });
  #|         if (!response.ok) {
  #|           throw new Error("Failed to fetch module " + sourceUrl + ": " + response.status + " " + response.statusText);
  #|         }
  #|         const code = await response.text();
  #|         if (code.includes("import.meta.url")) {
  #|           return await import(sourceUrl);
  #|         }
  #|         const rewritten = await rewriteModuleSource(code, url, index);
  #|         const dataUrl = moduleImportUrl(
  #|           'data:text/javascript;base64,' + btoa(unescape(encodeURIComponent(rewritten))),
  #|           String(index) + "-source",
  #|         );
  #|         return await import(dataUrl);
  #|       };
  #|       globalThis.__bidiImportModuleSource = importModuleSource;
  #|       const syncWindowGlobals = () => {
  #|         try {
  #|           if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|             globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|           }
  #|         } catch (_e) {}
  #|       };
  #|       syncWindowGlobals();
  #|
  #|       for (const script of scripts) {
  #|         syncWindowGlobals();
  #|         const src = script.getAttribute('src');
  #|         const type = script.getAttribute('type') || 'text/javascript';
  #|
  #|         // Skip non-JavaScript types (like application/json)
  #|         if (type && !type.includes('javascript') && type !== 'module') {
  #|           results.push({ skipped: true, type, reason: 'non-js type' });
  #|           continue;
  #|         }
  #|
  #|         try {
  #|           if (type === 'module') {
  #|             // ES Module handling
  #|             if (src) {
  #|               // External module - use dynamic import
  #|               const fullUrl = resolveUrl(src, baseUrl);
  #|               try {
  #|                 const sourceOrigin = getOrigin(baseUrl || globalThis.__pageUrl || '');
  #|                 const targetOrigin = getOrigin(fullUrl);
  #|                 if (!sandboxAllows(targetOrigin, sourceOrigin)) {
  #|                   throw new Error('Blocked by request sandbox');
  #|                 }
  #|                 if (sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|                   await globalThis.fetch(fullUrl, { mode: 'cors' });
  #|                 }
  #|                 await importModuleSource(fullUrl, results.length);
  #|                 results.push({ executed: true, module: true, src: fullUrl });
  #|               } catch (e) {
  #|                 results.push({ error: true, module: true, src: fullUrl, message: String(e) });
  #|               }
  #|             } else {
  #|               // Inline module - convert to data URL and import
  #|               const code = script.textContent;
  #|               if (code && code.trim()) {
  #|                 try {
  #|                   // Create a data URL for the module
  #|                   const rewritten = await rewriteModuleSource(code, baseUrl, results.length, new Map(), 0);
  #|                   const dataUrl = moduleImportUrl(
  #|                     'data:text/javascript;base64,' + btoa(unescape(encodeURIComponent(rewritten))),
  #|                     results.length,
  #|                   );
  #|                   await import(dataUrl);
  #|                   results.push({ executed: true, module: true, inline: true, length: code.length });
  #|                 } catch (e) {
  #|                   results.push({ error: true, module: true, inline: true, message: String(e) });
  #|                 }
  #|               }
  #|             }
  #|           } else if (src) {
  #|             // External classic script - fetch and execute
  #|             const fullUrl = resolveUrl(src, baseUrl);
  #|             const fetchFn = globalThis.__craterUseObservableFetch
  #|               ? (globalThis.__craterObservableFetch || globalThis.__fetchInternal || globalThis.fetch)
  #|               : (globalThis.__fetchInternal || globalThis.fetch);
  #|             const response = await fetchFn(fullUrl, { mode: 'no-cors' });
  #|             if (response.ok) {
  #|               const code = await response.text();
  #|               (0, eval)(code);
  #|               results.push({ executed: true, src: fullUrl });
  #|             } else {
  #|               results.push({ error: true, src: fullUrl, status: response.status });
  #|             }
  #|           } else {
  #|             // Inline classic script
  #|             const code = script.textContent;
  #|             if (code && code.trim()) {
  #|               (0, eval)(code);
  #|               results.push({ executed: true, inline: true, length: code.length });
  #|             }
  #|           }
  #|         } catch (e) {
  #|           results.push({ error: true, message: String(e), src: src || 'inline' });
  #|         }
  #|         syncWindowGlobals();
  #|       }
  #|
  #|       return results;
  #|     };
  #|
  #|     // Load page and execute scripts
  #|     globalThis.__loadPageWithScripts = async function(url, options) {
  #|       options = options || {};
  #|       const loadResult = await globalThis.__loadPage(url);
  #|
  #|       // Execute scripts if requested (default: true)
  #|       if (options.executeScripts !== false) {
  #|         const scriptResults = await globalThis.__executeScripts({ baseUrl: url });
  #|         loadResult.scripts = scriptResults;
  #|       }
  #|
  #|       return loadResult;
  #|     };
  #|   }
  #|
  #|   applyUserActivation(userActivation);
  #|   const currentCtx = String(globalThis.__bidiCurrentContext || "default-context");
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   if (!globalThis.__bidiContextWindows.has(currentCtx)) {
  #|     const win = {};
  #|     win.__bidiContextId = currentCtx;
  #|     win.window = win;
  #|     const baseNavigator = globalThis.navigator && typeof globalThis.navigator === 'object'
  #|       ? globalThis.navigator
  #|       : {
  #|           userAgent: 'Crater/1.0 (MoonBit; BiDi)',
  #|           platform: 'Crater',
  #|           language: 'en-US',
  #|           languages: ['en-US', 'en'],
  #|           onLine: true,
  #|           cookieEnabled: false,
  #|           userActivation: {
  #|             isActive: false,
  #|             hasBeenActive: false,
  #|           },
  #|         };
  #|     win.navigator = {
  #|       userAgent: String(baseNavigator.userAgent ?? 'Crater/1.0 (MoonBit; BiDi)'),
  #|       platform: String(baseNavigator.platform ?? 'Crater'),
  #|       language: String(baseNavigator.language ?? 'en-US'),
  #|       languages: Array.isArray(baseNavigator.languages)
  #|         ? Array.from(baseNavigator.languages)
  #|         : ['en-US', 'en'],
  #|       onLine: baseNavigator.onLine !== false,
  #|       cookieEnabled: Boolean(baseNavigator.cookieEnabled ?? false),
  #|       userActivation: baseNavigator.userActivation && typeof baseNavigator.userActivation === 'object'
  #|         ? { ...baseNavigator.userActivation }
  #|         : { isActive: false, hasBeenActive: false },
  #|     };
  #|     win.innerWidth = Number(globalThis.innerWidth || 1024);
  #|     win.innerHeight = Number(globalThis.innerHeight || 768);
  #|     win.outerWidth = Number(globalThis.outerWidth || win.innerWidth);
  #|     win.outerHeight = Number(globalThis.outerHeight || win.innerHeight);
  #|     win.devicePixelRatio = Number(globalThis.devicePixelRatio || 1);
  #|     win.pageXOffset = 0;
  #|     win.pageYOffset = 0;
  #|     win._listeners = {};
  #|     win.addEventListener = function(type, fn) {
  #|       if (!this._listeners[type]) this._listeners[type] = [];
  #|       this._listeners[type].push(fn);
  #|     };
  #|     win.removeEventListener = function(type, fn) {
  #|       if (!this._listeners[type]) return;
  #|       this._listeners[type] = this._listeners[type].filter((f) => f !== fn);
  #|     };
  #|     win.dispatchEvent = function(event) {
  #|       prepareEventForCurrentTarget(event, this);
  #|       if (event.__retargetSuppressed) return !event.defaultPrevented;
  #|       try { event.currentTarget = this; } catch (_e) {}
  #|       const listeners = this._listeners[event.type] || [];
  #|       for (const fn of listeners) {
  #|         try { fn.call(this, event); } catch (_e) {}
  #|       }
  #|       return !event.defaultPrevented;
  #|     };
  #|     if (typeof globalThis.__bidiInstallContextWindowApi === "function") {
  #|       globalThis.__bidiInstallContextWindowApi(win);
  #|     }
  #|     globalThis.__bidiContextWindows.set(currentCtx, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(currentCtx);
  #|   if (typeof globalThis.__bidiInstallContextWindowApi === "function") {
  #|     globalThis.__bidiInstallContextWindowApi(contextWindow);
  #|   }
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.self = contextWindow;
  #|   globalThis.parent = contextWindow.parent || contextWindow;
  #|   globalThis.top = contextWindow.top || contextWindow;
  #|   globalThis.frames = frameWindows;
  #|   if (contextWindow.navigator && typeof contextWindow.navigator === 'object') {
  #|     globalThis.navigator = contextWindow.navigator;
  #|   } else if (globalThis.navigator && typeof globalThis.navigator === 'object') {
  #|     contextWindow.navigator = globalThis.navigator;
  #|   }
  #|   if (contextWindow.document && typeof contextWindow.document === "object") {
  #|     globalThis.document = contextWindow.document;
  #|   } else if (globalThis.document && typeof globalThis.document === "object") {
  #|     contextWindow.document = globalThis.document;
  #|   }
  #|   if (contextWindow.location && typeof contextWindow.location === "object") {
  #|     globalThis.location = contextWindow.location;
  #|     try { globalThis.__pageUrl = String(contextWindow.location.href || "about:blank"); } catch (_e) {}
  #|   } else {
  #|     const locationHref = "about:blank";
  #|     contextWindow.location = {
  #|       href: locationHref,
  #|       origin: '',
  #|       protocol: 'about:',
  #|       host: '',
  #|       hostname: '',
  #|       port: '',
  #|       pathname: 'blank',
  #|       search: '',
  #|       hash: '',
  #|       assign: function(url) { const next = String(url); globalThis.__pageUrl = next; this.href = next; },
  #|       replace: function(url) { const next = String(url); globalThis.__pageUrl = next; this.href = next; },
  #|       reload: function() {}
  #|     };
  #|     globalThis.location = contextWindow.location;
  #|     globalThis.__pageUrl = locationHref;
  #|   }
  #|   if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|     globalThis.__bidiSyncWindowPropertiesToGlobal(contextWindow);
  #|   }
  #|   if (!globalThis.__bidiProxyInstances) globalThis.__bidiProxyInstances = new WeakSet();
  #|   if (!globalThis.__bidiNativeProxy && typeof globalThis.Proxy === "function") {
  #|     const NativeProxy = globalThis.Proxy;
  #|     const tracked = globalThis.__bidiProxyInstances;
  #|     function TrackedProxy(target, handler) {
  #|       const proxied = new NativeProxy(target, handler);
  #|       tracked.add(proxied);
  #|       return proxied;
  #|     }
  #|     TrackedProxy.revocable = function(target, handler) {
  #|       const revocable = NativeProxy.revocable(target, handler);
  #|       tracked.add(revocable.proxy);
  #|       return revocable;
  #|     };
  #|     globalThis.__bidiNativeProxy = NativeProxy;
  #|     globalThis.Proxy = TrackedProxy;
  #|   }
  #|
  #|   if (!globalThis.__bidiHandleStore) globalThis.__bidiHandleStore = new Map();
  #|   if (!globalThis.__bidiHandleContextStore) globalThis.__bidiHandleContextStore = new Map();
  #|   if (typeof globalThis.__bidiNextHandleId !== "number") {
  #|     globalThis.__bidiNextHandleId = 1;
  #|   }
  #|   const attachHandle = (value, serialized, includeHandle) => {
  #|     if (!includeHandle) return serialized;
  #|     if (value === null || value === undefined) return serialized;
  #|     const valueType = typeof value;
  #|     if (valueType !== "object" && valueType !== "function" && valueType !== "symbol") return serialized;
  #|     if (!serialized || typeof serialized !== "object" || serialized.handle) return serialized;
  #|     const handle = `handle-${globalThis.__bidiNextHandleId++}`;
  #|     globalThis.__bidiHandleStore.set(handle, value);
  #|     globalThis.__bidiHandleContextStore.set(
  #|       handle,
  #|       String(globalThis.__bidiCurrentContext || ""),
  #|     );
  #|     return { ...serialized, handle };
  #|   };
  #|   const toBidiValueFn = (value, includeHandle = false) =>
  #|     attachHandle(value, toBidiValue(value), includeHandle);
  #|
  #|   function getNodeSharedId(node) {
  #|     const sharedIds = globalThis.__bidiNodeSharedIds || (globalThis.__bidiNodeSharedIds = new WeakMap());
  #|     const nodeStore = globalThis.__bidiSharedNodeStore || (globalThis.__bidiSharedNodeStore = new Map());
  #|     if (typeof globalThis.__bidiNextNodeSharedId !== "number") {
  #|       globalThis.__bidiNextNodeSharedId = 1;
  #|     }
  #|     let sharedId = sharedIds.get(node);
  #|     if (!sharedId) {
  #|       sharedId = `node-${globalThis.__bidiNextNodeSharedId++}`;
  #|       sharedIds.set(node, sharedId);
  #|     }
  #|     nodeStore.set(sharedId, node);
  #|     return sharedId;
  #|   }
  #|
  #|   function getNodeAttributes(node) {
  #|     const attrs = {};
  #|     if (!node || typeof node !== "object") return attrs;
  #|     if (node._attrs && typeof node._attrs === "object") {
  #|       for (const [k, v] of Object.entries(node._attrs)) attrs[k] = String(v);
  #|       return attrs;
  #|     }
  #|     if (node.attributes && typeof node.attributes.length === "number") {
  #|       for (const attr of Array.from(node.attributes)) {
  #|         if (attr && typeof attr.name === "string") attrs[attr.name] = String(attr.value ?? "");
  #|       }
  #|     }
  #|     return attrs;
  #|   }
  #|
  #|   function getNodeChildren(node) {
  #|     if (Array.isArray(node?._children)) return node._children;
  #|     if (Array.isArray(node?.childNodes)) return node.childNodes;
  #|     return [];
  #|   }
  #|
  #|   function shouldIncludeDomChildren(depth) {
  #|     if (maxDomDepth === null) return true;
  #|     if (typeof maxDomDepth === "number") return depth < maxDomDepth;
  #|     return false;
  #|   }
  #|
  #|   function getShadowMode(node) {
  #|     if (!node || typeof node !== "object") return "open";
  #|     if (typeof node.mode === "string") return String(node.mode);
  #|     if (typeof node._mode === "string") return String(node._mode);
  #|     return "open";
  #|   }
  #|
  #|   function serializeShadowRootReference(root, depth) {
  #|     const childNodes = getNodeChildren(root);
  #|     const mode = getShadowMode(root);
  #|     const includeTree =
  #|       includeShadowTree === "all" ||
  #|       (includeShadowTree === "open" && mode === "open");
  #|     const value = {
  #|       nodeType: 11,
  #|       childNodeCount: childNodes.length,
  #|     };
  #|     if (includeTree) {
  #|       value.mode = mode;
  #|       if (shouldIncludeDomChildren(depth)) {
  #|         value.children = childNodes.map((child) => toBidiNodeValue(child, depth + 1));
  #|       }
  #|     } else if (!hasMaxDomDepth && !hasMaxObjectDepth && includeShadowTree === "none") {
  #|       // Default (without serialization options) keeps mode for compatibility tests.
  #|       value.mode = mode;
  #|     }
  #|     return {
  #|       type: "node",
  #|       sharedId: getNodeSharedId(root),
  #|       value,
  #|     };
  #|   }
  #|
  #|   function toBidiNodeValue(node, domDepth = 0) {
  #|     const childNodes = getNodeChildren(node);
  #|     const nodeType = typeof node?.nodeType === "number" ? node.nodeType : 1;
  #|     const value = {
  #|       nodeType,
  #|       childNodeCount: childNodes.length,
  #|     };
  #|
  #|     if (nodeType === 1) {
  #|       const localName =
  #|         node.localName ||
  #|         node._tagName ||
  #|         (node.tagName ? String(node.tagName).toLowerCase() : "");
  #|       value.localName = String(localName);
  #|       value.namespaceURI = node.namespaceURI || "http://www.w3.org/1999/xhtml";
  #|       value.attributes = getNodeAttributes(node);
  #|       if (shouldIncludeDomChildren(domDepth)) {
  #|         value.children = childNodes.map((child) => toBidiNodeValue(child, domDepth + 1));
  #|       }
  #|       value.shadowRoot = node.shadowRoot
  #|         ? serializeShadowRootReference(node.shadowRoot, domDepth)
  #|         : null;
  #|     } else if (nodeType === 2) {
  #|       const attrName = String(node.name || node.nodeName || "");
  #|       value.localName = attrName.includes(":") ? attrName.split(":").pop() : attrName;
  #|       value.namespaceURI =
  #|         node.namespaceURI ??
  #|         (attrName.startsWith("svg:") ? "http://www.w3.org/2000/svg" : null);
  #|       value.nodeValue = String(node.nodeValue ?? node.value ?? "");
  #|     } else if (nodeType === 3 || nodeType === 4 || nodeType === 7 || nodeType === 8) {
  #|       value.nodeValue = String(node.nodeValue ?? node.textContent ?? "");
  #|     } else if (nodeType === 9) {
  #|       if (shouldIncludeDomChildren(domDepth)) {
  #|         value.children = childNodes.map((child) => toBidiNodeValue(child, domDepth + 1));
  #|       }
  #|     } else if (nodeType === 11) {
  #|       const isShadowRoot = !!node.host;
  #|       if (isShadowRoot) {
  #|         value.mode = getShadowMode(node);
  #|         const includeShadowChildren =
  #|           shouldIncludeDomChildren(domDepth) &&
  #|           (includeShadowTree === "all" || includeShadowTree === "open");
  #|         if (includeShadowChildren) {
  #|           value.children = childNodes.map((child) => toBidiNodeValue(child, domDepth + 1));
  #|         }
  #|       } else if (shouldIncludeDomChildren(domDepth)) {
  #|         value.children = childNodes.map((child) => toBidiNodeValue(child, domDepth + 1));
  #|       }
  #|     }
  #|
  #|     return {
  #|       type: "node",
  #|       sharedId: getNodeSharedId(node),
  #|       value,
  #|     };
  #|   }
  #|
  #|   const internalIds = new WeakMap();
  #|   const referenceCounts = new WeakMap();
  #|   let nextInternalId = 1;
  #|
  #|   const trackReference = (obj) => {
  #|     const prev = referenceCounts.get(obj) || 0;
  #|     referenceCounts.set(obj, prev + 1);
  #|   };
  #|
  #|   const collectReferences = (value, seen = new WeakSet()) => {
  #|     if (!value || typeof value !== "object") return;
  #|     if (typeof value.nodeType === "number") {
  #|       trackReference(value);
  #|       return;
  #|     }
  #|     if (
  #|       value instanceof Date ||
  #|       value instanceof RegExp ||
  #|       value instanceof Error ||
  #|       value instanceof Promise ||
  #|       value instanceof WeakMap ||
  #|       value instanceof WeakSet ||
  #|       value instanceof ArrayBuffer ||
  #|       ArrayBuffer.isView(value)
  #|     ) {
  #|       return;
  #|     }
  #|     if (globalThis.__bidiProxyInstances && globalThis.__bidiProxyInstances.has(value)) return;
  #|
  #|     const isContainer =
  #|       Array.isArray(value) ||
  #|       value instanceof Map ||
  #|       value instanceof Set ||
  #|       value.constructor === Object;
  #|     if (!isContainer) return;
  #|
  #|     trackReference(value);
  #|     if (seen.has(value)) return;
  #|     seen.add(value);
  #|
  #|     if (Array.isArray(value)) {
  #|       for (const item of value) collectReferences(item, seen);
  #|       return;
  #|     }
  #|     if (value instanceof Map) {
  #|       for (const [k, v] of value) {
  #|         if (typeof k !== "string") collectReferences(k, seen);
  #|         collectReferences(v, seen);
  #|       }
  #|       return;
  #|     }
  #|     if (value instanceof Set) {
  #|       for (const item of value) collectReferences(item, seen);
  #|       return;
  #|     }
  #|     for (const entryValue of Object.values(value)) {
  #|       collectReferences(entryValue, seen);
  #|     }
  #|   };
  #|
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
  #|     if (maxObjectDepth !== undefined) return serialized;
  #|     if (!originalValue || (typeof originalValue !== "object" && typeof originalValue !== "function")) {
  #|       return serialized;
  #|     }
  #|     const serializedType = serialized.type;
  #|     if (serializedType !== "array" && serializedType !== "map" && serializedType !== "set" && serializedType !== "object" && serializedType !== "node") {
  #|       return serialized;
  #|     }
  #|     const count = referenceCounts.get(originalValue) || 0;
  #|     if (count <= 1) return serialized;
  #|     let internalId = internalIds.get(originalValue);
  #|     if (!internalId) {
  #|       internalId = `internal-${nextInternalId++}`;
  #|       internalIds.set(originalValue, internalId);
  #|     }
  #|     if (serialized.internalId) return serialized;
  #|     return { ...serialized, internalId };
  #|   };
  #|
  #|   function toBidiValue(value, objectDepth = 0, domDepth = 0) {
  #|     if (value === undefined) return { type: "undefined" };
  #|     if (value === null) return { type: "null" };
  #|
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
  #|
  #|     const limitReached =
  #|       typeof maxObjectDepth === "number" &&
  #|       objectDepth >= maxObjectDepth;
  #|
  #|     const objectTag = type === "object" ? Object.prototype.toString.call(value) : "";
  #|     if (objectTag === "[object Generator]" || objectTag === "[object AsyncGenerator]") {
  #|       return { type: "generator" };
  #|     }
  #|     if (globalThis.__bidiProxyInstances && globalThis.__bidiProxyInstances.has(value)) {
  #|       return { type: "proxy" };
  #|     }
  #|     if (value && type === "object" && typeof value.__bidiContextId === "string") {
  #|       return { type: "window", value: { context: String(value.__bidiContextId) } };
  #|     }
  #|     if (value === globalThis || value === globalThis.window) {
  #|       return {
  #|         type: "window",
  #|         value: { context: String(globalThis.__bidiCurrentContext || "default-context") }
  #|       };
  #|     }
  #|     if (value && type === "object" && typeof value.nodeType === "number") {
  #|       return withInternalId(value, toBidiNodeValue(value, domDepth));
  #|     }
  #|
  #|     if (value instanceof RegExp) {
  #|       return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     }
  #|     if (value instanceof Date) {
  #|       return { type: "date", value: value.toISOString() };
  #|     }
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|
  #|     if (Array.isArray(value) && value.__bidiCollectionType === "htmlcollection") {
  #|       const items = value.map((item) => toBidiValue(item, objectDepth + 1, domDepth));
  #|       return { type: "htmlcollection", value: items };
  #|     }
  #|     if (Array.isArray(value) && value.__bidiCollectionType === "nodelist") {
  #|       const items = value.map((item) => toBidiValue(item, objectDepth + 1, domDepth));
  #|       return { type: "nodelist", value: items };
  #|     }
  #|
  #|     if (value instanceof Map) {
  #|       if (limitReached) return { type: "map" };
  #|       const entries = [];
  #|       for (const [k, v] of value) {
  #|         entries.push([
  #|           typeof k === "string" ? k : toBidiValue(k, objectDepth + 1, domDepth),
  #|           toBidiValue(v, objectDepth + 1, domDepth),
  #|         ]);
  #|       }
  #|       return withInternalId(value, { type: "map", value: entries });
  #|     }
  #|     if (value instanceof Set) {
  #|       if (limitReached) return { type: "set" };
  #|       return withInternalId(
  #|         value,
  #|         { type: "set", value: Array.from(value).map((item) => toBidiValue(item, objectDepth + 1, domDepth)) },
  #|       );
  #|     }
  #|     if (Array.isArray(value)) {
  #|       if (limitReached) return { type: "array" };
  #|       return withInternalId(
  #|         value,
  #|         { type: "array", value: value.map((item) => toBidiValue(item, objectDepth + 1, domDepth)) },
  #|       );
  #|     }
  #|
  #|     if (value && value.constructor === Object) {
  #|       if (limitReached) return { type: "object" };
  #|       const entries = Object.entries(value).map(([k, v]) => [
  #|         k,
  #|         toBidiValue(v, objectDepth + 1, domDepth),
  #|       ]);
  #|       return withInternalId(value, { type: "object", value: entries });
  #|     }
  #|
  #|     return { type: "object" };
  #|   }
  #|
  #|   try {
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     let result = (0, eval)(expression);  // Indirect eval for global scope
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     if (result instanceof Promise) {
  #|       // Avoid process-level unhandled rejection when awaitPromise=false.
  #|       result.catch(() => {});
  #|     }
  #|     collectReferences(result);
  #|     return JSON.stringify({
  #|       type: "success",
  #|       result: toBidiValueFn(result, !!rootOwnership),
  #|       consoleEntries,
  #|     });
  #|   } catch (e) {
  #|     const stackTrace = buildStackTraceFromStack(e && e.stack ? e.stack : "");
  #|     const topFrame = Array.isArray(stackTrace.callFrames) && stackTrace.callFrames.length > 0
  #|       ? stackTrace.callFrames[0]
  #|       : null;
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         columnNumber: topFrame ? Number(topFrame.columnNumber || 0) : 0,
  #|         lineNumber: topFrame ? Number(topFrame.lineNumber || 0) : 0,
  #|         text: String(e),
  #|         exception: toBidiValueFn(e, !!rootOwnership),
  #|         stackTrace
  #|       },
  #|       consoleEntries
  #|     });
  #|   } finally {
  #|     // Restore original console (for sync path)
  #|     // Note: For async path, cleanup is in .finally()
  #|     if (captureConsole && originalConsole) {
  #|       const restoreConsole = originalConsole.target || console;
  #|       restoreConsole.log = originalConsole.log;
  #|       restoreConsole.warn = originalConsole.warn;
  #|       restoreConsole.error = originalConsole.error;
  #|       restoreConsole.info = originalConsole.info;
  #|       restoreConsole.debug = originalConsole.debug;
  #|       restoreConsole.assert = originalConsole.assert;
  #|       restoreConsole.table = originalConsole.table;
  #|       restoreConsole.trace = originalConsole.trace;
  #|       restoreConsole.time = originalConsole.time;
  #|       restoreConsole.timeEnd = originalConsole.timeEnd;
  #|     }
  #|   }
  #| }

///|
/// Evaluate JavaScript expression and return result as JSON (sync)
fn evaluate_js_with_console(
  expression : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
) -> String {
  js_evaluate_expression(
    expression, capture_console, user_activation, root_ownership, serialization_options_json,
  )
}

///|
/// Evaluate JavaScript expression and return result as JSON (sync)
pub fn evaluate_js(expression : String) -> String {
  evaluate_js_with_console(expression, true, false, false, "{}")
}
