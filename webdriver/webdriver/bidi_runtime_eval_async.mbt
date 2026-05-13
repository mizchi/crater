///|
/// FFI: Evaluate JavaScript expression asynchronously (awaits Promise)
/// Returns a Promise that resolves to JSON string
extern "js" fn js_evaluate_expression_async(
  expression : String,
  user_activation : Bool,
  ctx_id : String,
) -> @core.Any =
  #| async (expression, userActivation, ctxId) => {
  #|   const consoleEntries = [];
  #|   const captureConsole = true;
  #|   const originalConsole = {
  #|     target: console,
  #|     log: console.log,
  #|     warn: console.warn,
  #|     error: console.error,
  #|     info: console.info,
  #|     debug: console.debug,
  #|     assert: console.assert,
  #|     table: console.table,
  #|     trace: console.trace,
  #|     time: console.time,
  #|     timeEnd: console.timeEnd
  #|   };
  #|
  #|   const consoleArgToText = (arg) => {
  #|     if (typeof arg === "string") return arg;
  #|     if (arg === undefined) return "undefined";
  #|     if (typeof arg === "bigint") return `${arg}n`;
  #|     try {
  #|       const json = JSON.stringify(arg);
  #|       if (json !== undefined) return json;
  #|     } catch (_e) {}
  #|     return String(arg);
  #|   };
  #|
  #|   const pushConsoleEntry = (level, method, args, textArgs = args) => {
  #|     consoleEntries.push({
  #|       level,
  #|       method,
  #|       text: textArgs.map(consoleArgToText).join(" "),
  #|       args: args.map(toBidiValue),
  #|       timestamp: Date.now()
  #|     });
  #|   };
  #|
  #|   const makeInterceptor = (level, method) => (...args) => {
  #|     pushConsoleEntry(level, method, args);
  #|   };
  #|
  #|   console.log = makeInterceptor('info', 'log');
  #|   console.warn = makeInterceptor('warn', 'warn');
  #|   console.error = makeInterceptor('error', 'error');
  #|   console.info = makeInterceptor('info', 'info');
  #|   console.debug = makeInterceptor('debug', 'debug');
  #|   console.table = makeInterceptor('info', 'table');
  #|   console.trace = makeInterceptor('debug', 'trace');
  #|   console.assert = (...args) => {
  #|     if (args.length > 0 && args[0]) {
  #|       return;
  #|     }
  #|     const textArgs = args.length > 1 ? args.slice(1) : ["Assertion failed"];
  #|     pushConsoleEntry("error", "assert", textArgs);
  #|   };
  #|   console.time = (...args) => {
  #|   };
  #|   console.timeEnd = (...args) => {
  #|     const textArgs = args.length > 0 ? args : ["default"];
  #|     pushConsoleEntry("info", "timeEnd", textArgs);
  #|   };
  #|
  #|   const isActive = !!userActivation;
  #|   globalThis.__bidiUserActivation = isActive;
  #|   globalThis.__bidiCurrentContext = ctxId;
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
  #|   if (!globalThis.navigator) globalThis.navigator = {};
  #|   globalThis.navigator.userActivation = {
  #|     isActive,
  #|     hasBeenActive: isActive
  #|   };
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   if (!globalThis.__bidiContextWindows.has(ctxId)) {
  #|     const win = {};
  #|     win.__bidiContextId = String(ctxId);
  #|     win.window = win;
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
  #|       try { event.currentTarget = this; } catch (_e) {}
  #|       const listeners = this._listeners[event.type] || [];
  #|       for (const fn of listeners) {
  #|         try { fn.call(this, event); } catch (_e) {}
  #|       }
  #|       return !event.defaultPrevented;
  #|     };
  #|     globalThis.__bidiContextWindows.set(ctxId, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.frames = frameWindows;
  #|   if (contextWindow.document && typeof contextWindow.document === "object") {
  #|     globalThis.document = contextWindow.document;
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
  #|   if (!globalThis.document) {
  #|     const body = {
  #|       appendChild(node) { return node; }
  #|     };
  #|     const createElement = (tagName) => {
  #|       const name = String(tagName || "div");
  #|       return {
  #|         tagName: name.toUpperCase(),
  #|         localName: name.toLowerCase(),
  #|         nodeType: 1,
  #|         namespaceURI: "http://www.w3.org/1999/xhtml",
  #|         _attrs: {},
  #|         _children: [],
  #|         childNodes: [],
  #|         shadowRoot: null,
  #|         setAttribute(name, value) { this._attrs[String(name)] = String(value); },
  #|       };
  #|     };
  #|     globalThis.document = {
  #|       body,
  #|       createElement,
  #|       createTextNode(text) { return { nodeType: 3, textContent: String(text) }; },
  #|       createDocumentFragment() {
  #|         return {
  #|           nodeType: 11,
  #|           nodeName: "#document-fragment",
  #|           _children: [],
  #|           childNodes: [],
  #|         };
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
  #|           return globalThis.document.createDocumentFragment();
  #|         }
  #|       };
  #|     }
  #|   }
  #|   if (globalThis.document && !globalThis.window.document) {
  #|     contextWindow.document = globalThis.document;
  #|   }
  #|   if (globalThis.document) {
  #|     globalThis.document.execCommand = function(command) {
  #|       const cmd = String(command || '').toLowerCase();
  #|       if (cmd === 'selectall') return true;
  #|       if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|       return false;
  #|     };
  #|   }
  #|   if (globalThis.document && typeof globalThis.__bidiEnsureDocumentRange === "function") {
  #|     globalThis.__bidiEnsureDocumentRange(globalThis.document);
  #|     contextWindow.document = globalThis.document;
  #|   }
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
  #|   function toBidiNodeValue(node) {
  #|     const childNodes = Array.isArray(node._children)
  #|       ? node._children
  #|       : (Array.isArray(node.childNodes) ? node.childNodes : []);
  #|     const nodeType = typeof node.nodeType === "number" ? node.nodeType : 1;
  #|     const localName = node.localName || node._tagName || (node.tagName ? String(node.tagName).toLowerCase() : "");
  #|     const namespaceURI = node.namespaceURI || "http://www.w3.org/1999/xhtml";
  #|     const shadowRoot = node.shadowRoot
  #|       ? { type: "node", sharedId: getNodeSharedId(node.shadowRoot) }
  #|       : null;
  #|     return {
  #|       type: "node",
  #|       sharedId: getNodeSharedId(node),
  #|       value: {
  #|         nodeType,
  #|         localName: String(localName),
  #|         namespaceURI: String(namespaceURI),
  #|         childNodeCount: childNodes.length,
  #|         children: [],
  #|         attributes: getNodeAttributes(node),
  #|         shadowRoot
  #|       }
  #|     };
  #|   }
  #|
  #|   const internalIds = new WeakMap();
  #|   const referenceCounts = new WeakMap();
  #|   let nextInternalId = 1;
  #|   const trackReference = (obj) => {
  #|     const prev = referenceCounts.get(obj) || 0;
  #|     referenceCounts.set(obj, prev + 1);
  #|   };
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
  #|     const isContainer =
  #|       Array.isArray(value) ||
  #|       value instanceof Map ||
  #|       value instanceof Set ||
  #|       value.constructor === Object;
  #|     if (!isContainer) return;
  #|     trackReference(value);
  #|     if (seen.has(value)) return;
  #|     seen.add(value);
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
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
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
  #|   function toBidiValue(value) {
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
  #|       return withInternalId(value, toBidiNodeValue(value));
  #|     }
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       return withInternalId(value, { type: "map", value: entries });
  #|     }
  #|     if (value instanceof Set) {
  #|       return withInternalId(
  #|         value,
  #|         { type: "set", value: Array.from(value).map(toBidiValue) },
  #|       );
  #|     }
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|     if (Array.isArray(value)) {
  #|       return withInternalId(
  #|         value,
  #|         { type: "array", value: value.map(toBidiValue) },
  #|       );
  #|     }
  #|     if (value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return withInternalId(value, { type: "object", value: entries });
  #|     }
  #|     return { type: "object" };
  #|   }
  #|
  #|   try {
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     let result = (0, eval)(expression);
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     // Await if result is a Promise
  #|     if (result instanceof Promise) {
  #|       result = await result;
  #|     }
  #|     collectReferences(result);
  #|     return JSON.stringify({ type: "success", result: toBidiValue(result), consoleEntries });
  #|   } catch (e) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: toBidiValue(e),
  #|         stackTrace: { callFrames: [] }
  #|       },
  #|       consoleEntries
  #|     });
  #|   } finally {
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
/// FFI: Await a JavaScript Promise and return the result as string
extern "js" fn js_await_promise(promise : @core.Any) -> String =
  #| async (promise) => await promise

///|
/// Evaluate JavaScript expression asynchronously (awaits Promise if awaitPromise=true)
/// Returns a Promise (@core.Any) that resolves to JSON string
pub fn evaluate_js_async(expression : String) -> @core.Any {
  js_evaluate_expression_async(expression, false, "")
}

///|
/// FFI: Evaluate expression asynchronously and send result via WebSocket
/// This runs the evaluation, awaits any Promise result, and sends response directly
extern "js" fn js_eval_and_send_async(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
  realm_id : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  unwrap_result : Bool,
) -> Unit =
  #| async (socket, requestId, expression, ctxId, realmId, captureConsole, userActivation, rootOwnership, unwrapResult) => {
  #|   const consoleEntries = [];
  #|   let originalConsole = null;
  #|   if (captureConsole) {
  #|     originalConsole = {
  #|       target: console,
  #|       log: console.log, warn: console.warn, error: console.error,
  #|       info: console.info, debug: console.debug,
  #|       assert: console.assert, table: console.table, trace: console.trace,
  #|       time: console.time, timeEnd: console.timeEnd
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
  #|       consoleEntries.push({
  #|         level, method,
  #|         text: textArgs.map(consoleArgToText).join(" "),
  #|         args: args.map(toBidiValue),
  #|         timestamp: Date.now()
  #|       });
  #|     };
  #|
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
  #|   const isActive = !!userActivation;
  #|   globalThis.__bidiUserActivation = isActive;
  #|   globalThis.__bidiCurrentContext = ctxId;
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
  #|   if (!globalThis.navigator) globalThis.navigator = {};
  #|   globalThis.navigator.userActivation = {
  #|     isActive,
  #|     hasBeenActive: isActive
  #|   };
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   if (!globalThis.__bidiContextWindows.has(ctxId)) {
  #|     const win = {};
  #|     win.__bidiContextId = String(ctxId);
  #|     win.window = win;
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
  #|       try { event.currentTarget = this; } catch (_e) {}
  #|       const listeners = this._listeners[event.type] || [];
  #|       for (const fn of listeners) {
  #|         try { fn.call(this, event); } catch (_e) {}
  #|       }
  #|       return !event.defaultPrevented;
  #|     };
  #|     globalThis.__bidiContextWindows.set(ctxId, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.frames = frameWindows;
  #|   if (contextWindow.document && typeof contextWindow.document === "object") {
  #|     globalThis.document = contextWindow.document;
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
  #|   if (!globalThis.document) {
  #|     const body = {
  #|       appendChild(node) { return node; }
  #|     };
  #|     const createElement = (tagName) => {
  #|       const name = String(tagName || "div");
  #|       return {
  #|         tagName: name.toUpperCase(),
  #|         localName: name.toLowerCase(),
  #|         nodeType: 1,
  #|         namespaceURI: "http://www.w3.org/1999/xhtml",
  #|         _attrs: {},
  #|         _children: [],
  #|         childNodes: [],
  #|         shadowRoot: null,
  #|         setAttribute(name, value) { this._attrs[String(name)] = String(value); },
  #|       };
  #|     };
  #|     globalThis.document = {
  #|       body,
  #|       createElement,
  #|       createTextNode(text) { return { nodeType: 3, textContent: String(text) }; },
  #|       createDocumentFragment() {
  #|         return {
  #|           nodeType: 11,
  #|           nodeName: "#document-fragment",
  #|           _children: [],
  #|           childNodes: [],
  #|         };
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
  #|           return globalThis.document.createDocumentFragment();
  #|         }
  #|       };
  #|     }
  #|   }
  #|   if (globalThis.document) {
  #|     globalThis.document.execCommand = function(command) {
  #|       const cmd = String(command || '').toLowerCase();
  #|       if (cmd === 'selectall') return true;
  #|       if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|       return false;
  #|     };
  #|   }
  #|   if (globalThis.document && !contextWindow.document) {
  #|     contextWindow.document = globalThis.document;
  #|   }
  #|   if (globalThis.document && typeof globalThis.__bidiEnsureDocumentRange === "function") {
  #|     globalThis.__bidiEnsureDocumentRange(globalThis.document);
  #|     contextWindow.document = globalThis.document;
  #|   }
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
  #|   function toBidiNodeValue(node) {
  #|     const childNodes = Array.isArray(node._children)
  #|       ? node._children
  #|       : (Array.isArray(node.childNodes) ? node.childNodes : []);
  #|     const nodeType = typeof node.nodeType === "number" ? node.nodeType : 1;
  #|     const localName = node.localName || node._tagName || (node.tagName ? String(node.tagName).toLowerCase() : "");
  #|     const namespaceURI = node.namespaceURI || "http://www.w3.org/1999/xhtml";
  #|     const shadowRoot = node.shadowRoot
  #|       ? { type: "node", sharedId: getNodeSharedId(node.shadowRoot) }
  #|       : null;
  #|     return {
  #|       type: "node",
  #|       sharedId: getNodeSharedId(node),
  #|       value: {
  #|         nodeType,
  #|         localName: String(localName),
  #|         namespaceURI: String(namespaceURI),
  #|         childNodeCount: childNodes.length,
  #|         children: [],
  #|         attributes: getNodeAttributes(node),
  #|         shadowRoot
  #|       }
  #|     };
  #|   }
  #|
  #|   const internalIds = new WeakMap();
  #|   const referenceCounts = new WeakMap();
  #|   let nextInternalId = 1;
  #|   const trackReference = (obj) => {
  #|     const prev = referenceCounts.get(obj) || 0;
  #|     referenceCounts.set(obj, prev + 1);
  #|   };
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
  #|     const isContainer =
  #|       Array.isArray(value) ||
  #|       value instanceof Map ||
  #|       value instanceof Set ||
  #|       value.constructor === Object;
  #|     if (!isContainer) return;
  #|     trackReference(value);
  #|     if (seen.has(value)) return;
  #|     seen.add(value);
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
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
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
  #|   function toBidiValue(value) {
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
  #|       return withInternalId(value, toBidiNodeValue(value));
  #|     }
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       return withInternalId(value, { type: "map", value: entries });
  #|     }
  #|     if (value instanceof Set) {
  #|       return withInternalId(
  #|         value,
  #|         { type: "set", value: Array.from(value).map(toBidiValue) },
  #|       );
  #|     }
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|     if (Array.isArray(value)) {
  #|       return withInternalId(
  #|         value,
  #|         { type: "array", value: value.map(toBidiValue) },
  #|       );
  #|     }
  #|     if (value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return withInternalId(value, { type: "object", value: entries });
  #|     }
  #|     return { type: "object" };
  #|   }
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
  #|   let response;
  #|   try {
  #|     const runInContext = (code) => {
  #|       // Use indirect eval so script.evaluate keeps script-style sloppy mode
  #|       // unless the expression explicitly opts into strict mode.
  #|       return (0, eval)(code);
  #|     };
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     let result = runInContext(expression);
  #|     if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") {
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal(globalThis.window);
  #|     }
  #|     // Await if result is a Promise
  #|     if (result instanceof Promise) {
  #|       result = await result;
  #|     }
  #|     collectReferences(result);
  #|     response = {
  #|       id: requestId,
  #|       type: "success",
  #|       result: unwrapResult
  #|         ? toBidiValueFn(result, !!rootOwnership)
  #|         : {
  #|             realm: realmId,
  #|             result: toBidiValueFn(result, !!rootOwnership)
  #|           }
  #|     };
  #|   } catch (e) {
  #|     const exceptionResult = {
  #|       realm: realmId,
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: toBidiValueFn(e, !!rootOwnership),
  #|         stackTrace: { callFrames: [] }
  #|       }
  #|     };
  #|     response = {
  #|       id: requestId,
  #|       type: "success",
  #|       result: exceptionResult
  #|     };
  #|   } finally {
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
  #|
  #|   // Send console log events before response
  #|   for (const entry of consoleEntries) {
  #|     const logEvent = {
  #|       type: "event",
  #|       method: "log.entryAdded",
  #|       params: {
  #|         level: entry.level,
  #|         source: { realm: realmId, context: ctxId },
  #|         text: entry.text,
  #|         timestamp: entry.timestamp,
  #|         method: entry.method,
  #|         args: entry.args || [],
  #|         type: "console"
  #|       }
  #|     };
  #|     socket.send(JSON.stringify(logEvent));
  #|   }
  #|
  #|   // Send the response
  #|   socket.send(JSON.stringify(response));
  #| }

///|
/// Evaluate expression asynchronously and send result via WebSocket
fn eval_and_send_async_with_console(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
  realm_id : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  unwrap_result : Bool,
) -> Unit {
  js_eval_and_send_async(
    socket, request_id, expression, ctx_id, realm_id, capture_console, user_activation,
    root_ownership, unwrap_result,
  )
}

///|
/// Evaluate expression asynchronously and send result via WebSocket
pub fn eval_and_send_async(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
) -> Unit {
  eval_and_send_async_with_console(
    socket, request_id, expression, ctx_id, "default-realm", true, false, false,
    false,
  )
}

///|
/// Await a Promise and return result as String
pub fn await_promise(promise : @core.Any) -> String {
  js_await_promise(promise)
}
