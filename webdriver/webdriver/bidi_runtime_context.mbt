///|
/// Reset JS-side runtime globals between WebSocket sessions.
extern "js" fn reset_runtime_js_state() -> Unit =
  #| () => {
  #|   try {
  #|     globalThis.__bidiCurrentContext = "default-context";
  #|     globalThis.__bidiContextWindows = new Map();
  #|     globalThis.__bidiContextViewportState = new Map();
  #|     const installWindowGlobalSync = () => {
  #|       if (typeof globalThis.__bidiSyncWindowPropertiesToGlobal === "function") return;
  #|       const reserved = new Set([
  #|         "window", "self", "parent", "top", "frames",
  #|         "document", "location", "navigator", "history",
  #|         "screen", "matchMedia",
  #|         "innerWidth", "innerHeight", "outerWidth", "outerHeight",
  #|         "devicePixelRatio", "pageXOffset", "pageYOffset",
  #|         "localStorage", "sessionStorage",
  #|         "alert", "confirm", "prompt", "console", "performance", "crypto",
  #|         "setTimeout", "clearTimeout", "setInterval", "clearInterval",
  #|         "requestAnimationFrame", "cancelAnimationFrame", "queueMicrotask",
  #|         "fetch", "Response", "Request", "Headers", "Blob", "FormData",
  #|         "URL", "URLSearchParams",
  #|         "getComputedStyle", "matchMedia", "Event", "UIEvent", "MouseEvent",
  #|         "PointerEvent", "FocusEvent", "KeyboardEvent", "InputEvent",
  #|         "CompositionEvent", "CustomEvent", "MessageEvent", "StorageEvent",
  #|         "DragEvent", "ClipboardEvent", "DataTransfer", "DOMParser",
  #|         "DOMException", "Node", "Attr", "Element", "HTMLElement", "Document",
  #|         // Observer APIs shimmed by bidi_runtime_eval.mbt. Without
  #|         // these, the per-eval window→globalThis sync would clear them.
  #|         "IntersectionObserver", "ResizeObserver", "MutationObserver",
  #|         // Network primitives provided natively by Node 22+.
  #|         "WebSocket", "EventSource",
  #|         // File upload surface (Blob/File native in Node 22, FileReader
  #|         // shimmed by bidi_runtime_eval.mbt).
  #|         "Blob", "File", "FileReader", "FileList",
  #|       ]);
  #|       globalThis.__bidiSyncWindowPropertiesToGlobal = (win) => {
  #|         const source = win && typeof win === "object" ? win : globalThis.window;
  #|         if (!source || source === globalThis || typeof source !== "object") return;
  #|         const syncedKeys = globalThis.__bidiSyncedWindowKeys instanceof Set
  #|           ? globalThis.__bidiSyncedWindowKeys
  #|           : (globalThis.__bidiSyncedWindowKeys = new Set());
  #|         for (const key of Array.from(syncedKeys)) {
  #|           if (reserved.has(key) || String(key).startsWith("__bidi")) {
  #|             syncedKeys.delete(key);
  #|             continue;
  #|           }
  #|           if (!Object.prototype.hasOwnProperty.call(source, key)) {
  #|             try { delete globalThis[key]; } catch (_e) {}
  #|             syncedKeys.delete(key);
  #|           }
  #|         }
  #|         for (const key of Object.keys(source)) {
  #|           if (reserved.has(key) || String(key).startsWith("__bidi")) continue;
  #|           let value;
  #|           try { value = source[key]; } catch (_e) { continue; }
  #|           try {
  #|             Object.defineProperty(globalThis, key, {
  #|               configurable: true,
  #|               enumerable: true,
  #|               writable: true,
  #|               value,
  #|             });
  #|           } catch (_e) {
  #|             try { globalThis[key] = value; } catch (_e2) {}
  #|           }
  #|           syncedKeys.add(key);
  #|         }
  #|       };
  #|     };
  #|     installWindowGlobalSync();
  #|     const installContextWindowApi = () => {
  #|       if (typeof globalThis.__bidiInstallContextWindowApi === "function") return;
  #|       const nativeTimers = globalThis.__bidiNativeWindowTimers || {
  #|         setTimeout: typeof globalThis.setTimeout === "function" ? globalThis.setTimeout : undefined,
  #|         clearTimeout: typeof globalThis.clearTimeout === "function" ? globalThis.clearTimeout : undefined,
  #|         setInterval: typeof globalThis.setInterval === "function" ? globalThis.setInterval : undefined,
  #|         clearInterval: typeof globalThis.clearInterval === "function" ? globalThis.clearInterval : undefined,
  #|         queueMicrotask: typeof globalThis.queueMicrotask === "function" ? globalThis.queueMicrotask : undefined,
  #|         requestAnimationFrame: typeof globalThis.requestAnimationFrame === "function" ? globalThis.requestAnimationFrame : undefined,
  #|         cancelAnimationFrame: typeof globalThis.cancelAnimationFrame === "function" ? globalThis.cancelAnimationFrame : undefined,
  #|       };
  #|       globalThis.__bidiNativeWindowTimers = nativeTimers;
  #|       const nativeFetch = globalThis.__bidiNativeWindowFetch || (
  #|         typeof globalThis.fetch === "function" ? globalThis.fetch : undefined
  #|       );
  #|       globalThis.__bidiNativeWindowFetch = nativeFetch;
  #|       const bindNative = (name, fallback) => {
  #|         const fn = nativeTimers[name];
  #|         return typeof fn === "function" ? fn.bind(globalThis) : fallback;
  #|       };
  #|       globalThis.__bidiInstallContextWindowApi = (win) => {
  #|         if (!win || typeof win !== "object") return win;
  #|         win.window = win;
  #|         win.self = win;
  #|         if (!win.parent) win.parent = win;
  #|         if (!win.top) win.top = win;
  #|         win.setTimeout = bindNative("setTimeout", (handler, timeout) => {
  #|           if (typeof handler === "function") handler();
  #|           return 0;
  #|         });
  #|         win.clearTimeout = bindNative("clearTimeout", (_id) => undefined);
  #|         win.setInterval = bindNative("setInterval", win.setTimeout);
  #|         win.clearInterval = bindNative("clearInterval", win.clearTimeout);
  #|         win.queueMicrotask = bindNative("queueMicrotask", (callback) => Promise.resolve().then(callback));
  #|         win.requestAnimationFrame = bindNative("requestAnimationFrame", (callback) =>
  #|           win.setTimeout(() => {
  #|             if (typeof callback === "function") callback(Date.now());
  #|           }, 16)
  #|         );
  #|         win.cancelAnimationFrame = bindNative("cancelAnimationFrame", win.clearTimeout);
  #|         win.fetch = function(url, options) {
  #|           const fetchFn = globalThis.__craterUseObservableFetch
  #|             ? (globalThis.__craterObservableFetch || globalThis.__fetchInternal)
  #|             : globalThis.__fetchInternal;
  #|           const fallback = globalThis.fetch !== win.fetch ? globalThis.fetch : nativeFetch;
  #|           const target = fetchFn || fallback;
  #|           if (typeof target !== "function") return Promise.reject(new TypeError("fetch is not available"));
  #|           return target.call(globalThis, url, options);
  #|         };
  #|         for (const name of [
  #|           "Response", "Request", "Headers", "Blob", "FormData", "URL", "URLSearchParams",
  #|           "getComputedStyle", "matchMedia", "Event", "UIEvent", "MouseEvent", "PointerEvent",
  #|           "FocusEvent", "KeyboardEvent", "InputEvent", "CompositionEvent", "CustomEvent",
  #|           "MessageEvent", "StorageEvent", "DragEvent", "ClipboardEvent", "DataTransfer",
  #|           "DOMParser", "DOMException", "Node", "Attr", "Element", "HTMLElement", "Document",
  #|         ]) {
  #|           if (win[name] === undefined && globalThis[name] !== undefined) win[name] = globalThis[name];
  #|         }
  #|         return win;
  #|       };
  #|     };
  #|     installContextWindowApi();
  #|     globalThis.__bidiPatchNavigatorTarget = (target, patch) => {
  #|       if (!target || typeof target !== "object") return null;
  #|       const current = target.navigator && typeof target.navigator === "object"
  #|         ? target.navigator
  #|         : null;
  #|       const next = (() => {
  #|         try {
  #|           const proto = current && typeof current === "object"
  #|             ? Object.getPrototypeOf(current)
  #|             : Object.prototype;
  #|           const value = Object.create(proto || Object.prototype);
  #|           if (current && typeof current === "object") {
  #|             try {
  #|               Object.defineProperties(value, Object.getOwnPropertyDescriptors(current));
  #|             } catch (_e) {
  #|               for (const key of Object.keys(current)) {
  #|                 try { value[key] = current[key]; } catch (_e2) {}
  #|               }
  #|             }
  #|           }
  #|           return value;
  #|         } catch (_e) {
  #|           const value = {};
  #|           if (current && typeof current === "object") {
  #|             for (const key of Object.keys(current)) {
  #|               try { value[key] = current[key]; } catch (_e2) {}
  #|             }
  #|           }
  #|           return value;
  #|         }
  #|       })();
  #|       const setField = (holder, name, value) => {
  #|         if (!holder || typeof holder !== "object") return;
  #|         try {
  #|           Object.defineProperty(holder, name, {
  #|             configurable: true,
  #|             enumerable: true,
  #|             writable: true,
  #|             value,
  #|           });
  #|           return;
  #|         } catch (_e) {}
  #|         try { holder[name] = value; } catch (_e) {}
  #|       };
  #|       const resolvedLanguage = String(
  #|         patch && patch.language !== undefined
  #|           ? patch.language
  #|           : (current && current.language !== undefined ? current.language : "en-US")
  #|       );
  #|       const resolvedLanguages =
  #|         patch && Array.isArray(patch.languages)
  #|           ? Array.from(patch.languages)
  #|           : (
  #|             current && Array.isArray(current.languages)
  #|               ? Array.from(current.languages)
  #|               : [resolvedLanguage]
  #|           );
  #|       setField(
  #|         next,
  #|         "userAgent",
  #|         String(
  #|           patch && patch.userAgent !== undefined
  #|             ? patch.userAgent
  #|             : (current && current.userAgent !== undefined
  #|                 ? current.userAgent
  #|                 : "Crater/1.0 (MoonBit; BiDi)")
  #|         ),
  #|       );
  #|       setField(
  #|         next,
  #|         "platform",
  #|         String(current && current.platform !== undefined ? current.platform : "Crater"),
  #|       );
  #|       setField(next, "language", resolvedLanguage);
  #|       setField(next, "languages", resolvedLanguages);
  #|       setField(
  #|         next,
  #|         "onLine",
  #|         patch && patch.onLine !== undefined
  #|           ? !!patch.onLine
  #|           : (current ? current.onLine !== false : true),
  #|       );
  #|       setField(
  #|         next,
  #|         "cookieEnabled",
  #|         Boolean(current && current.cookieEnabled !== undefined ? current.cookieEnabled : false),
  #|       );
  #|       const userActivation =
  #|         current && current.userActivation && typeof current.userActivation === "object"
  #|           ? { ...current.userActivation }
  #|           : { isActive: false, hasBeenActive: false };
  #|       setField(next, "userActivation", userActivation);
  #|       try {
  #|         Object.defineProperty(target, "navigator", {
  #|           configurable: true,
  #|           enumerable: true,
  #|           writable: true,
  #|           value: next,
  #|         });
  #|         return next;
  #|       } catch (_e) {}
  #|       try {
  #|         target.navigator = next;
  #|         return target.navigator;
  #|       } catch (_e) {}
  #|       if (current && typeof current === "object") {
  #|         for (const name of ["userAgent", "platform", "language", "languages", "onLine", "cookieEnabled", "userActivation"]) {
  #|           try { setField(current, name, next[name]); } catch (_e) {}
  #|         }
  #|         return current;
  #|       }
  #|       return null;
  #|     };
  #|     if (!globalThis.__bidiProxyInstances) {
  #|       globalThis.__bidiProxyInstances = new WeakSet();
  #|     }
  #|     globalThis.allEvents = undefined;
  #|     globalThis.recordedEvents = undefined;
  #|     globalThis._shadowRoot = undefined;
  #|     globalThis.__bidiLastClickHref = undefined;
  #|     globalThis.__bidiChannelMessages = [];
  #|     globalThis.__bidiSharedNodeStore = new Map();
  #|     globalThis.__bidiHandleStore = new Map();
  #|     globalThis.__bidiNextHandleId = 1;
  #|     // Drop the realm-scoped fetch-shim install-once flag and the
  #|     // __rawFetch indirection it pairs with so the next
  #|     // js_evaluate_expression re-wraps fetch cleanly. Otherwise a
  #|     // browsingContext.create / destroy cycle that reuses the same JS
  #|     // realm would inherit the flag without re-wrapping, leaving
  #|     // __rawFetch pointing at the previous session's stub.
  #|     try { delete globalThis.__bidiFetchShimInstalled; } catch (_e) {}
  #|     try { delete globalThis.__rawFetch; } catch (_e) {}
  #|     // Also drop the per-realm preflight cache so stale entries from
  #|     // the previous session do not bleed cross-origin allow-lists
  #|     // into a fresh session.
  #|     try { delete globalThis.__bidiPreflightCache; } catch (_e) {}
  #|   } catch (_e) {}
  #| }

///|
/// Ensure JS-side navigator patch helper exists for runtime emulation overrides.
extern "js" fn ensure_runtime_navigator_patch_helper() -> Unit =
  #| () => {
  #|   if (typeof globalThis.__bidiPatchNavigatorTarget === "function") return;
  #|   try { globalThis.__bidiCurrentContext = globalThis.__bidiCurrentContext || "default-context"; } catch (_e) {}
  #|   try { globalThis.__bidiContextWindows = globalThis.__bidiContextWindows || new Map(); } catch (_e) {}
  #|   try {
  #|     globalThis.__bidiPatchNavigatorTarget = (target, patch) => {
  #|       if (!target || typeof target !== "object") return null;
  #|       const current = target.navigator && typeof target.navigator === "object"
  #|         ? target.navigator
  #|         : null;
  #|       const next = (() => {
  #|         try {
  #|           const proto = current && typeof current === "object"
  #|             ? Object.getPrototypeOf(current)
  #|             : Object.prototype;
  #|           const value = Object.create(proto || Object.prototype);
  #|           if (current && typeof current === "object") {
  #|             try {
  #|               Object.defineProperties(value, Object.getOwnPropertyDescriptors(current));
  #|             } catch (_e) {
  #|               for (const key of Object.keys(current)) {
  #|                 try { value[key] = current[key]; } catch (_e2) {}
  #|               }
  #|             }
  #|           }
  #|           return value;
  #|         } catch (_e) {
  #|           const value = {};
  #|           if (current && typeof current === "object") {
  #|             for (const key of Object.keys(current)) {
  #|               try { value[key] = current[key]; } catch (_e2) {}
  #|             }
  #|           }
  #|           return value;
  #|         }
  #|       })();
  #|       const setField = (holder, name, value) => {
  #|         if (!holder || typeof holder !== "object") return;
  #|         try {
  #|           Object.defineProperty(holder, name, {
  #|             configurable: true,
  #|             enumerable: true,
  #|             writable: true,
  #|             value,
  #|           });
  #|           return;
  #|         } catch (_e) {}
  #|         try { holder[name] = value; } catch (_e) {}
  #|       };
  #|       const resolvedLanguage = String(
  #|         patch && patch.language !== undefined
  #|           ? patch.language
  #|           : (current && current.language !== undefined ? current.language : "en-US")
  #|       );
  #|       const resolvedLanguages =
  #|         patch && Array.isArray(patch.languages)
  #|           ? Array.from(patch.languages)
  #|           : (
  #|             current && Array.isArray(current.languages)
  #|               ? Array.from(current.languages)
  #|               : [resolvedLanguage]
  #|           );
  #|       setField(
  #|         next,
  #|         "userAgent",
  #|         String(
  #|           patch && patch.userAgent !== undefined
  #|             ? patch.userAgent
  #|             : (current && current.userAgent !== undefined
  #|                 ? current.userAgent
  #|                 : "Crater/1.0 (MoonBit; BiDi)")
  #|         ),
  #|       );
  #|       setField(
  #|         next,
  #|         "platform",
  #|         String(current && current.platform !== undefined ? current.platform : "Crater"),
  #|       );
  #|       setField(next, "language", resolvedLanguage);
  #|       setField(next, "languages", resolvedLanguages);
  #|       setField(
  #|         next,
  #|         "onLine",
  #|         patch && patch.onLine !== undefined
  #|           ? !!patch.onLine
  #|           : (current ? current.onLine !== false : true),
  #|       );
  #|       setField(
  #|         next,
  #|         "cookieEnabled",
  #|         Boolean(current && current.cookieEnabled !== undefined ? current.cookieEnabled : false),
  #|       );
  #|       const userActivation =
  #|         current && current.userActivation && typeof current.userActivation === "object"
  #|           ? { ...current.userActivation }
  #|           : { isActive: false, hasBeenActive: false };
  #|       setField(next, "userActivation", userActivation);
  #|       try {
  #|         Object.defineProperty(target, "navigator", {
  #|           configurable: true,
  #|           enumerable: true,
  #|           writable: true,
  #|           value: next,
  #|         });
  #|         return next;
  #|       } catch (_e) {}
  #|       try {
  #|         target.navigator = next;
  #|         return target.navigator;
  #|       } catch (_e) {}
  #|       if (current && typeof current === "object") {
  #|         for (const name of ["userAgent", "platform", "language", "languages", "onLine", "cookieEnabled", "userActivation"]) {
  #|           try { setField(current, name, next[name]); } catch (_e) {}
  #|         }
  #|         return current;
  #|       }
  #|       return null;
  #|     };
  #|   } catch (_e) {}
  #| }

///|
/// Set current BiDi context for value serialization helpers.
extern "js" fn js_set_runtime_context(ctx_id : String) -> Unit =
  #| (ctxId) => {
  #|   globalThis.__bidiCurrentContext = ctxId;
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   if (!globalThis.__bidiContextViewportState) globalThis.__bidiContextViewportState = new Map();
  #|   const resolveViewportState = (id) => {
  #|     const fallback = { width: 1024, height: 768, devicePixelRatio: 1 };
  #|     const map = globalThis.__bidiContextViewportState;
  #|     if (!map || !map.has(id)) return fallback;
  #|     const raw = map.get(id) || {};
  #|     const width = Number(raw.width);
  #|     const height = Number(raw.height);
  #|     const dpr = Number(raw.devicePixelRatio);
  #|     return {
  #|       width: Number.isFinite(width) && width >= 0 ? width : fallback.width,
  #|       height: Number.isFinite(height) && height >= 0 ? height : fallback.height,
  #|       devicePixelRatio: Number.isFinite(dpr) && dpr > 0 ? dpr : fallback.devicePixelRatio,
  #|     };
  #|   };
  #|   const resolveScreenOrientationState = (id) => {
  #|     const fallback = { type: "portrait-primary", angle: 0 };
  #|     const map = globalThis.__bidiContextScreenOrientationState;
  #|     if (!map || !map.has(id)) return fallback;
  #|     const raw = map.get(id) || {};
  #|     const type = typeof raw.type === "string" && raw.type ? raw.type : fallback.type;
  #|     const angle = Number(raw.angle);
  #|     return {
  #|       type,
  #|       angle: Number.isFinite(angle) ? angle : fallback.angle,
  #|     };
  #|   };
  #|   const resolveScreenAreaState = (id, fallbackMetrics) => {
  #|     const fallback = {
  #|       width: fallbackMetrics.width,
  #|       height: fallbackMetrics.height,
  #|       availWidth: fallbackMetrics.width,
  #|       availHeight: fallbackMetrics.height,
  #|     };
  #|     const map = globalThis.__bidiContextScreenAreaState;
  #|     if (!map || !map.has(id)) return fallback;
  #|     const raw = map.get(id) || {};
  #|     const width = Number(raw.width);
  #|     const height = Number(raw.height);
  #|     const availWidth = Number(raw.availWidth);
  #|     const availHeight = Number(raw.availHeight);
  #|     return {
  #|       width: Number.isFinite(width) && width >= 0 ? width : fallback.width,
  #|       height: Number.isFinite(height) && height >= 0 ? height : fallback.height,
  #|       availWidth: Number.isFinite(availWidth) && availWidth >= 0 ? availWidth : fallback.availWidth,
  #|       availHeight: Number.isFinite(availHeight) && availHeight >= 0 ? availHeight : fallback.availHeight,
  #|     };
  #|   };
  #|   const ensureOrientationTarget = (orientation, state) => {
  #|     const target = orientation && typeof orientation === "object" ? orientation : {};
  #|     target.type = state.type;
  #|     target.angle = state.angle;
  #|     if (!target._listeners || typeof target._listeners !== "object") target._listeners = {};
  #|     if (typeof target.addEventListener !== "function") {
  #|       target.addEventListener = function(type, fn) {
  #|         if (!this._listeners[type]) this._listeners[type] = [];
  #|         this._listeners[type].push(fn);
  #|       };
  #|     }
  #|     if (typeof target.removeEventListener !== "function") {
  #|       target.removeEventListener = function(type, fn) {
  #|         if (!this._listeners[type]) return;
  #|         this._listeners[type] = this._listeners[type].filter((entry) => entry !== fn);
  #|       };
  #|     }
  #|     if (typeof target.dispatchEvent !== "function") {
  #|       target.dispatchEvent = function(event) {
  #|         try { event.currentTarget = this; } catch (_e) {}
  #|         try { event.target = this; } catch (_e) {}
  #|         const listeners = this._listeners[event.type] || [];
  #|         for (const fn of listeners) {
  #|           try { fn.call(this, event); } catch (_e) {}
  #|         }
  #|         return !event.defaultPrevented;
  #|       };
  #|     }
  #|     return target;
  #|   };
  #|   const ensureScreenObject = (win, orientationState, screenMetrics) => {
  #|     if (!win || typeof win !== "object") return null;
  #|     const screen = win.screen && typeof win.screen === "object" ? win.screen : {};
  #|     screen.width = screenMetrics.width;
  #|     screen.height = screenMetrics.height;
  #|     screen.availWidth = screenMetrics.availWidth;
  #|     screen.availHeight = screenMetrics.availHeight;
  #|     screen.orientation = ensureOrientationTarget(screen.orientation, orientationState);
  #|     win.screen = screen;
  #|     return screen;
  #|   };
  #|   const metrics = resolveViewportState(String(ctxId));
  #|   const screenOrientationState = resolveScreenOrientationState(String(ctxId));
  #|   const screenAreaState = resolveScreenAreaState(String(ctxId), metrics);
  #|   if (!globalThis.__bidiContextWindows.has(ctxId)) {
  #|     const win = {};
  #|     win.__bidiContextId = String(ctxId);
  #|     win.window = win;
  #|     win.innerWidth = metrics.width;
  #|     win.innerHeight = metrics.height;
  #|     win.outerWidth = metrics.width;
  #|     win.outerHeight = metrics.height;
  #|     win.devicePixelRatio = metrics.devicePixelRatio;
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
  #|     if (typeof globalThis.__bidiInstallContextWindowApi === "function") {
  #|       globalThis.__bidiInstallContextWindowApi(win);
  #|     }
  #|     globalThis.__bidiContextWindows.set(ctxId, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|   if (contextWindow) {
  #|     if (typeof globalThis.__bidiInstallContextWindowApi === "function") {
  #|       globalThis.__bidiInstallContextWindowApi(contextWindow);
  #|     }
  #|     if (!contextWindow.window) contextWindow.window = contextWindow;
  #|     contextWindow.innerWidth = metrics.width;
  #|     contextWindow.innerHeight = metrics.height;
  #|     contextWindow.outerWidth = metrics.width;
  #|     contextWindow.outerHeight = metrics.height;
  #|     contextWindow.devicePixelRatio = metrics.devicePixelRatio;
  #|     const screen = ensureScreenObject(contextWindow, screenOrientationState, screenAreaState);
  #|     const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|     globalThis.window = contextWindow;
  #|     globalThis.self = contextWindow;
  #|     globalThis.parent = contextWindow.parent || contextWindow;
  #|     globalThis.top = contextWindow.top || contextWindow;
  #|     contextWindow.matchMedia = globalThis.matchMedia;
  #|     globalThis.frames = frameWindows;
  #|     globalThis.screen = screen;
  #|     globalThis.innerWidth = metrics.width;
  #|     globalThis.innerHeight = metrics.height;
  #|     globalThis.outerWidth = metrics.width;
  #|     globalThis.outerHeight = metrics.height;
  #|     globalThis.devicePixelRatio = metrics.devicePixelRatio;
  #|     if (!globalThis.__bidiContextStorage) globalThis.__bidiContextStorage = new Map();
  #|     const ensureStorage = (kind) => {
  #|       const key = String(ctxId) + ":" + String(kind);
  #|       if (!globalThis.__bidiContextStorage.has(key)) {
  #|         globalThis.__bidiContextStorage.set(key, {});
  #|       }
  #|       const backing = globalThis.__bidiContextStorage.get(key);
  #|       return {
  #|         getItem(name) {
  #|           const storageKey = String(name);
  #|           return Object.prototype.hasOwnProperty.call(backing, storageKey)
  #|             ? backing[storageKey]
  #|             : null;
  #|         },
  #|         setItem(name, value) {
  #|           backing[String(name)] = String(value);
  #|         },
  #|         removeItem(name) {
  #|           delete backing[String(name)];
  #|         },
  #|         clear() {
  #|           for (const storageKey of Object.keys(backing)) {
  #|             delete backing[storageKey];
  #|           }
  #|         },
  #|         get length() {
  #|           return Object.keys(backing).length;
  #|         },
  #|         key(index) {
  #|           const keys = Object.keys(backing);
  #|           return keys[Number(index)] || null;
  #|         }
  #|       };
  #|     };
  #|     if (!contextWindow.localStorage) contextWindow.localStorage = ensureStorage("localStorage");
  #|     if (!contextWindow.sessionStorage) contextWindow.sessionStorage = ensureStorage("sessionStorage");
  #|     globalThis.localStorage = contextWindow.localStorage;
  #|     globalThis.sessionStorage = contextWindow.sessionStorage;
  #|     // alert / confirm / prompt — wire to the BiDi user-prompt bridge.
  #|     // A page-side call queues a userPromptOpened observation and returns
  #|     // the resolved value per the context's unhandledPromptBehavior (snapshot
  #|     // pushed via __bidiPromptHandlers). The MoonBit drain runs at every
  #|     // script.evaluate boundary and emits the deferred BiDi event so
  #|     // Playwright's `page.on('dialog')` consumers observe the dialog.
  #|     //
  #|     // Limitation: real browsers BLOCK the page on alert/confirm/prompt
  #|     // until the user (or driver) answers. Crater's headless realm can't
  #|     // synchronously park JS waiting for an out-of-realm decision, so the
  #|     // resolution is taken from the snapshot at call time — accept ⇒ true /
  #|     // default-value, dismiss ⇒ false / null. Drivers that need control
  #|     // over the response set the behavior via session.new
  #|     // `unhandledPromptBehavior` BEFORE the page calls alert/confirm/prompt.
  #|     const resolvePromptHandler = (promptType) => {
  #|       const handlers = globalThis.__bidiPromptHandlers;
  #|       if (handlers && typeof handlers === "object") {
  #|         const direct = handlers[promptType];
  #|         if (typeof direct === "string") return direct;
  #|         const fallback = handlers.default;
  #|         if (typeof fallback === "string") return fallback;
  #|       }
  #|       return "dismiss";
  #|     };
  #|     const enqueueUserPrompt = (promptType, message, defaultValue) => {
  #|       if (!Array.isArray(globalThis.__bidiPendingUserPrompts)) {
  #|         globalThis.__bidiPendingUserPrompts = [];
  #|       }
  #|       const handler = resolvePromptHandler(promptType);
  #|       const ctx = String(globalThis.__bidiCurrentContext || "default-context");
  #|       globalThis.__bidiPendingUserPrompts.push({
  #|         ctx,
  #|         type: promptType,
  #|         message: message === undefined || message === null ? "" : String(message),
  #|         defaultValue: defaultValue === undefined || defaultValue === null ? null : String(defaultValue),
  #|         handler,
  #|       });
  #|       return handler;
  #|     };
  #|     if (typeof contextWindow.alert !== "function") {
  #|       contextWindow.alert = function(message) {
  #|         enqueueUserPrompt("alert", message, null);
  #|         // alert returns undefined regardless of handler — accepting vs
  #|         // dismissing only changes whether the page knew the user saw it.
  #|         return undefined;
  #|       };
  #|     }
  #|     if (typeof contextWindow.confirm !== "function") {
  #|       contextWindow.confirm = function(message) {
  #|         const handler = enqueueUserPrompt("confirm", message, null);
  #|         return handler === "accept" || handler === "accept and notify";
  #|       };
  #|     }
  #|     if (typeof contextWindow.prompt !== "function") {
  #|       contextWindow.prompt = function(message, defaultValue) {
  #|         const handler = enqueueUserPrompt("prompt", message, defaultValue);
  #|         if (handler === "accept" || handler === "accept and notify") {
  #|           return defaultValue === undefined || defaultValue === null
  #|             ? ""
  #|             : String(defaultValue);
  #|         }
  #|         // dismiss / dismiss and notify / ignore → null per HTML spec
  #|         return null;
  #|       };
  #|     }
  #|     globalThis.alert = contextWindow.alert.bind(contextWindow);
  #|     globalThis.confirm = contextWindow.confirm.bind(contextWindow);
  #|     globalThis.prompt = contextWindow.prompt.bind(contextWindow);
  #|     if (contextWindow.document && typeof contextWindow.document === "object") {
  #|       globalThis.document = contextWindow.document;
  #|     } else if (globalThis.document && typeof globalThis.document === "object") {
  #|       contextWindow.document = globalThis.document;
  #|     }
  #|     if (globalThis.document && typeof globalThis.__bidiEnsureDocumentRange === "function") {
  #|       globalThis.__bidiEnsureDocumentRange(globalThis.document);
  #|       contextWindow.document = globalThis.document;
  #|     }
  #|     if (contextWindow.location && typeof contextWindow.location === "object") {
  #|       globalThis.location = contextWindow.location;
  #|       try { globalThis.__pageUrl = String(contextWindow.location.href || "about:blank"); } catch (_e) {}
  #|     } else {
  #|       const locationHref = "about:blank";
  #|       contextWindow.location = {
  #|         href: locationHref,
  #|         origin: '',
  #|         protocol: 'about:',
  #|         host: '',
  #|         hostname: '',
  #|         port: '',
  #|         pathname: 'blank',
  #|         search: '',
  #|         hash: '',
  #|         assign: function(url) { const next = String(url); globalThis.__pageUrl = next; this.href = next; },
  #|         replace: function(url) { const next = String(url); globalThis.__pageUrl = next; this.href = next; },
  #|         reload: function() {}
  #|       };
  #|       globalThis.location = contextWindow.location;
  #|       globalThis.__pageUrl = locationHref;
  #|     }
  #|     if (Object.prototype.hasOwnProperty.call(contextWindow, "__lastHTML")) {
  #|       globalThis.__lastHTML = contextWindow.__lastHTML;
  #|     }
  #|     if (contextWindow.__lastParsed) {
  #|       globalThis.__lastParsed = contextWindow.__lastParsed;
  #|     }
  #|     if (Object.prototype.hasOwnProperty.call(contextWindow, "__craterPaintCaptureSource")) {
  #|       globalThis.__craterPaintCaptureSource = contextWindow.__craterPaintCaptureSource;
  #|     }
  #|   }
  #| }

///|
/// Set current BiDi context for value serialization helpers.
pub fn set_runtime_context(ctx_id : String) -> Unit {
  js_set_runtime_context(ctx_id)
}

///|
/// Reset runtime event buffers/listeners for a specific context.
extern "js" fn js_reset_runtime_event_buffers(ctx_id : String) -> Unit =
  #| (ctxId) => {
  #|   try {
  #|     if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|       const win = globalThis.__bidiContextWindows.get(ctxId);
  #|       if (win && typeof win === "object") {
  #|         if (!win.allEvents || !Array.isArray(win.allEvents.events)) {
  #|           win.allEvents = { events: [] };
  #|         } else {
  #|           win.allEvents.events.length = 0;
  #|         }
  #|         if (win._listeners && typeof win._listeners === "object") {
  #|           win._listeners = {};
  #|         }
  #|         try { win.__bidiFocusedElement = null; } catch (_e) {}
  #|         win.__craterAllEventsFallbackInit = false;
  #|         win.__bidiLastClickHref = null;
  #|       }
  #|     }
  #|     if (globalThis.allEvents && Array.isArray(globalThis.allEvents.events)) {
  #|       globalThis.allEvents.events.length = 0;
  #|     } else {
  #|       globalThis.allEvents = { events: [] };
  #|     }
  #|     if (
  #|       globalThis.document &&
  #|       globalThis.document._listeners &&
  #|       typeof globalThis.document._listeners === "object"
  #|     ) {
  #|       globalThis.document._listeners = {};
  #|     }
  #|     try { globalThis.__bidiFocusedElement = null; } catch (_e) {}
  #|     globalThis.__bidiLastClickHref = null;
  #|   } catch (_e) {}
  #| }

///|
/// Reset runtime event buffers/listeners for a specific context.
pub fn reset_runtime_event_buffers(ctx_id : String) -> Unit {
  js_reset_runtime_event_buffers(ctx_id)
}

///|
/// Set frame window contexts for current runtime context.
extern "js" fn js_set_runtime_context_frames(
  ctx_id : String,
  frame_ctx_ids : Array[String],
) -> Unit =
  #| (ctxId, frameCtxIds) => {
  #|   if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
  #|   if (!globalThis.__bidiContextViewportState) globalThis.__bidiContextViewportState = new Map();
  #|   const resolveViewportState = (id) => {
  #|     const fallback = { width: 1024, height: 768, devicePixelRatio: 1 };
  #|     const map = globalThis.__bidiContextViewportState;
  #|     if (!map || !map.has(id)) return fallback;
  #|     const raw = map.get(id) || {};
  #|     const width = Number(raw.width);
  #|     const height = Number(raw.height);
  #|     const dpr = Number(raw.devicePixelRatio);
  #|     return {
  #|       width: Number.isFinite(width) && width >= 0 ? width : fallback.width,
  #|       height: Number.isFinite(height) && height >= 0 ? height : fallback.height,
  #|       devicePixelRatio: Number.isFinite(dpr) && dpr > 0 ? dpr : fallback.devicePixelRatio,
  #|     };
  #|   };
  #|   const ensureWindow = (id) => {
  #|     if (!globalThis.__bidiContextWindows.has(id)) {
  #|       const metrics = resolveViewportState(String(id));
  #|       const win = {};
  #|       win.__bidiContextId = String(id);
  #|       win.window = win;
  #|       win.innerWidth = metrics.width;
  #|       win.innerHeight = metrics.height;
  #|       win.outerWidth = metrics.width;
  #|       win.outerHeight = metrics.height;
  #|       win.devicePixelRatio = metrics.devicePixelRatio;
  #|       win.pageXOffset = 0;
  #|       win.pageYOffset = 0;
  #|       win._listeners = {};
  #|       win.addEventListener = function(type, fn) {
  #|         if (!this._listeners[type]) this._listeners[type] = [];
  #|         this._listeners[type].push(fn);
  #|       };
  #|       win.removeEventListener = function(type, fn) {
  #|         if (!this._listeners[type]) return;
  #|         this._listeners[type] = this._listeners[type].filter((f) => f !== fn);
  #|       };
  #|       win.dispatchEvent = function(event) {
  #|         try { event.currentTarget = this; } catch (_e) {}
  #|         const listeners = this._listeners[event.type] || [];
  #|         for (const fn of listeners) {
  #|           try { fn.call(this, event); } catch (_e) {}
  #|         }
  #|         return !event.defaultPrevented;
  #|       };
  #|       globalThis.__bidiContextWindows.set(id, win);
  #|     }
  #|     return globalThis.__bidiContextWindows.get(id);
  #|   };
  #|   const currentWindow = ensureWindow(ctxId);
  #|   const frames = Array.isArray(frameCtxIds)
  #|     ? frameCtxIds.map((id) => ensureWindow(String(id)))
  #|     : [];
  #|   currentWindow.frames = frames;
  #|   globalThis.frames = frames;
  #| }

///|
/// Set frame window contexts for current runtime context.
pub fn set_runtime_context_frames(
  ctx_id : String,
  frame_ctx_ids : Array[String],
) -> Unit {
  js_set_runtime_context_frames(ctx_id, frame_ctx_ids)
}

///|
/// Set runtime viewport metrics for a specific context.
extern "js" fn js_set_runtime_context_viewport(
  ctx_id : String,
  width : Int,
  height : Int,
  device_pixel_ratio : Double,
) -> Unit =
  #| (ctxId, width, height, devicePixelRatio) => {
  #|   if (!globalThis.__bidiContextViewportState) globalThis.__bidiContextViewportState = new Map();
  #|   const w = Number(width);
  #|   const h = Number(height);
  #|   const dpr = Number(devicePixelRatio);
  #|   const normalized = {
  #|     width: Number.isFinite(w) && w >= 0 ? w : 1024,
  #|     height: Number.isFinite(h) && h >= 0 ? h : 768,
  #|     devicePixelRatio: Number.isFinite(dpr) && dpr > 0 ? dpr : 1,
  #|   };
  #|   globalThis.__bidiContextViewportState.set(String(ctxId), normalized);
  #|   if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|     const win = globalThis.__bidiContextWindows.get(ctxId);
  #|     if (win && typeof win === "object") {
  #|       win.innerWidth = normalized.width;
  #|       win.innerHeight = normalized.height;
  #|       win.outerWidth = normalized.width;
  #|       win.outerHeight = normalized.height;
  #|       win.devicePixelRatio = normalized.devicePixelRatio;
  #|     }
  #|   }
  #|   if (String(globalThis.__bidiCurrentContext || "") === String(ctxId)) {
  #|     globalThis.innerWidth = normalized.width;
  #|     globalThis.innerHeight = normalized.height;
  #|     globalThis.outerWidth = normalized.width;
  #|     globalThis.outerHeight = normalized.height;
  #|     globalThis.devicePixelRatio = normalized.devicePixelRatio;
  #|   }
  #| }

///|
/// Set runtime viewport metrics for a specific context.
pub fn set_runtime_context_viewport(
  ctx_id : String,
  width : Int,
  height : Int,
  device_pixel_ratio : Double,
) -> Unit {
  js_set_runtime_context_viewport(ctx_id, width, height, device_pixel_ratio)
}

///|
/// Set runtime navigator.userAgent for a specific context.
extern "js" fn js_set_runtime_context_user_agent(
  ctx_id : String,
  user_agent : String,
) -> Unit =
  #| (ctxId, userAgent) => {
  #|   const normalized = String(userAgent ?? "Crater/1.0 (MoonBit; BiDi)");
  #|   const patchNavigator = globalThis.__bidiPatchNavigatorTarget;
  #|   if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|     const win = globalThis.__bidiContextWindows.get(ctxId);
  #|     if (win && typeof win === "object") {
  #|       patchNavigator(win, { userAgent: normalized });
  #|     }
  #|   }
  #|   if (String(globalThis.__bidiCurrentContext || "") === String(ctxId)) {
  #|     patchNavigator(globalThis, { userAgent: normalized });
  #|   }
  #| }

///|
/// Set runtime navigator.userAgent for a specific context.
pub fn set_runtime_context_user_agent(
  ctx_id : String,
  user_agent : String,
) -> Unit {
  ensure_runtime_navigator_patch_helper()
  js_set_runtime_context_user_agent(ctx_id, user_agent)
}

///|
/// Set runtime navigator.language(s) for a specific context.
extern "js" fn js_set_runtime_context_locale(
  ctx_id : String,
  locale : String,
) -> Unit =
  #| (ctxId, locale) => {
  #|   const normalized = String(locale ?? "en-US");
  #|   const languages = [normalized];
  #|   const patchNavigator = globalThis.__bidiPatchNavigatorTarget;
  #|   if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|     const win = globalThis.__bidiContextWindows.get(ctxId);
  #|     if (win && typeof win === "object") {
  #|       patchNavigator(win, { language: normalized, languages });
  #|     }
  #|   }
  #|   if (String(globalThis.__bidiCurrentContext || "") === String(ctxId)) {
  #|     patchNavigator(globalThis, { language: normalized, languages });
  #|   }
  #| }

///|
/// Set runtime navigator.language(s) for a specific context.
pub fn set_runtime_context_locale(ctx_id : String, locale : String) -> Unit {
  ensure_runtime_navigator_patch_helper()
  js_set_runtime_context_locale(ctx_id, locale)
}

///|
extern "js" fn js_set_runtime_context_network_online(
  ctx_id : String,
  is_online : Bool,
) -> Unit =
  #| (ctxId, isOnline) => {
  #|   const normalized = !!isOnline;
  #|   const dispatchStateEvent = (target, type) => {
  #|     if (!target || typeof target.dispatchEvent !== "function") return;
  #|     let event;
  #|     if (typeof globalThis.__bidiCreateEvent === "function") {
  #|       event = globalThis.__bidiCreateEvent(type, { bubbles: false, cancelable: false });
  #|     } else {
  #|       event = { type, bubbles: false, cancelable: false, defaultPrevented: false };
  #|     }
  #|     try { event.isTrusted = true; } catch (_e) {}
  #|     try { target.dispatchEvent(event); } catch (_e) {}
  #|   };
  #|   const patchNavigator = globalThis.__bidiPatchNavigatorTarget;
  #|   const ensureNavigator = (target) => patchNavigator(target, { onLine: normalized });
  #|   let contextWindow = null;
  #|   let previousOnline = null;
  #|   if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|     contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|     const navigator = ensureNavigator(contextWindow);
  #|     if (navigator) {
  #|       previousOnline = navigator.onLine !== false;
  #|       navigator.onLine = normalized;
  #|     }
  #|   }
  #|   if (String(globalThis.__bidiCurrentContext || "") === String(ctxId)) {
  #|     const globalNavigator = ensureNavigator(globalThis);
  #|     if (globalNavigator) globalNavigator.onLine = normalized;
  #|     const activeWindow = globalThis.window && typeof globalThis.window === "object"
  #|       ? globalThis.window
  #|       : null;
  #|     if (activeWindow && activeWindow !== contextWindow) {
  #|       const windowNavigator = ensureNavigator(activeWindow);
  #|       if (windowNavigator) {
  #|         const prev = windowNavigator.onLine !== false;
  #|         windowNavigator.onLine = normalized;
  #|         if (prev !== normalized) {
  #|           dispatchStateEvent(activeWindow, normalized ? "online" : "offline");
  #|         }
  #|       }
  #|     }
  #|   }
  #|   if (contextWindow && previousOnline !== null && previousOnline !== normalized) {
  #|     dispatchStateEvent(contextWindow, normalized ? "online" : "offline");
  #|   }
  #| }

///|
pub fn set_runtime_context_network_online(
  ctx_id : String,
  is_online : Bool,
) -> Unit {
  ensure_runtime_navigator_patch_helper()
  js_set_runtime_context_network_online(ctx_id, is_online)
}

///|
extern "js" fn js_set_runtime_context_screen_orientation(
  ctx_id : String,
  orientation_type : String,
  angle : Int,
) -> Unit =
  #| (ctxId, orientationType, angle) => {
  #|   if (!globalThis.__bidiContextScreenOrientationState) {
  #|     globalThis.__bidiContextScreenOrientationState = new Map();
  #|   }
  #|   const normalizedType =
  #|     typeof orientationType === "string" && orientationType
  #|       ? orientationType
  #|       : "portrait-primary";
  #|   const normalizedAngle = Number.isFinite(Number(angle)) ? Number(angle) : 0;
  #|   globalThis.__bidiContextScreenOrientationState.set(String(ctxId), {
  #|     type: normalizedType,
  #|     angle: normalizedAngle,
  #|   });
  #|   const dispatchChange = (target) => {
  #|     if (!target || typeof target.dispatchEvent !== "function") return;
  #|     let event;
  #|     if (typeof globalThis.__bidiCreateEvent === "function") {
  #|       event = globalThis.__bidiCreateEvent("change", { bubbles: false, cancelable: false });
  #|     } else {
  #|       event = { type: "change", bubbles: false, cancelable: false, defaultPrevented: false };
  #|     }
  #|     try { event.isTrusted = true; } catch (_e) {}
  #|     try { event.target = target; } catch (_e) {}
  #|     try { target.dispatchEvent(event); } catch (_e) {}
  #|   };
  #|   const ensureOrientationTarget = (orientation) => {
  #|     const target = orientation && typeof orientation === "object" ? orientation : {};
  #|     if (!target._listeners || typeof target._listeners !== "object") target._listeners = {};
  #|     if (typeof target.addEventListener !== "function") {
  #|       target.addEventListener = function(type, fn) {
  #|         if (!this._listeners[type]) this._listeners[type] = [];
  #|         this._listeners[type].push(fn);
  #|       };
  #|     }
  #|     if (typeof target.removeEventListener !== "function") {
  #|       target.removeEventListener = function(type, fn) {
  #|         if (!this._listeners[type]) return;
  #|         this._listeners[type] = this._listeners[type].filter((entry) => entry !== fn);
  #|       };
  #|     }
  #|     if (typeof target.dispatchEvent !== "function") {
  #|       target.dispatchEvent = function(event) {
  #|         try { event.currentTarget = this; } catch (_e) {}
  #|         try { event.target = this; } catch (_e) {}
  #|         const listeners = this._listeners[event.type] || [];
  #|         for (const fn of listeners) {
  #|           try { fn.call(this, event); } catch (_e) {}
  #|         }
  #|         return !event.defaultPrevented;
  #|       };
  #|     }
  #|     return target;
  #|   };
  #|   const ensureScreenObject = (target) => {
  #|     if (!target || typeof target !== "object") return null;
  #|     const screen = target.screen && typeof target.screen === "object" ? target.screen : {};
  #|     screen.orientation = ensureOrientationTarget(screen.orientation);
  #|     target.screen = screen;
  #|     return screen;
  #|   };
  #|   const apply = (target) => {
  #|     const screen = ensureScreenObject(target);
  #|     if (!screen || !screen.orientation) return;
  #|     const orientation = screen.orientation;
  #|     const previousType = typeof orientation.type === "string" ? orientation.type : "";
  #|     const previousAngle = Number.isFinite(Number(orientation.angle)) ? Number(orientation.angle) : 0;
  #|     orientation.type = normalizedType;
  #|     orientation.angle = normalizedAngle;
  #|     if (previousType !== normalizedType || previousAngle !== normalizedAngle) {
  #|       dispatchChange(orientation);
  #|     }
  #|   };
  #|   let contextWindow = null;
  #|   if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|     contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|     apply(contextWindow);
  #|   }
  #|   if (String(globalThis.__bidiCurrentContext || "") === String(ctxId)) {
  #|     const activeWindow = globalThis.window && typeof globalThis.window === "object"
  #|       ? globalThis.window
  #|       : globalThis;
  #|     if (activeWindow !== contextWindow) {
  #|       apply(activeWindow);
  #|     }
  #|     if (globalThis.window && typeof globalThis.window === "object" && globalThis.window.screen) {
  #|       globalThis.screen = globalThis.window.screen;
  #|     }
  #|   }
  #| }

///|
pub fn set_runtime_context_screen_orientation(
  ctx_id : String,
  orientation_type : String,
  angle : Int,
) -> Unit {
  js_set_runtime_context_screen_orientation(ctx_id, orientation_type, angle)
}

///|
extern "js" fn js_set_runtime_context_screen_area(
  ctx_id : String,
  width : Int,
  height : Int,
  avail_width : Int,
  avail_height : Int,
) -> Unit =
  #| (ctxId, width, height, availWidth, availHeight) => {
  #|   if (!globalThis.__bidiContextScreenAreaState) {
  #|     globalThis.__bidiContextScreenAreaState = new Map();
  #|   }
  #|   const normalizedWidth = Number.isFinite(Number(width)) && Number(width) >= 0 ? Number(width) : 1024;
  #|   const normalizedHeight = Number.isFinite(Number(height)) && Number(height) >= 0 ? Number(height) : 768;
  #|   const normalizedAvailWidth = Number.isFinite(Number(availWidth)) && Number(availWidth) >= 0
  #|     ? Number(availWidth)
  #|     : normalizedWidth;
  #|   const normalizedAvailHeight = Number.isFinite(Number(availHeight)) && Number(availHeight) >= 0
  #|     ? Number(availHeight)
  #|     : normalizedHeight;
  #|   globalThis.__bidiContextScreenAreaState.set(String(ctxId), {
  #|     width: normalizedWidth,
  #|     height: normalizedHeight,
  #|     availWidth: normalizedAvailWidth,
  #|     availHeight: normalizedAvailHeight,
  #|   });
  #|   const apply = (target) => {
  #|     if (!target || typeof target !== "object") return null;
  #|     const screen = target.screen && typeof target.screen === "object" ? target.screen : {};
  #|     screen.width = normalizedWidth;
  #|     screen.height = normalizedHeight;
  #|     screen.availWidth = normalizedAvailWidth;
  #|     screen.availHeight = normalizedAvailHeight;
  #|     target.screen = screen;
  #|     return screen;
  #|   };
  #|   let contextWindow = null;
  #|   if (globalThis.__bidiContextWindows && globalThis.__bidiContextWindows.has(ctxId)) {
  #|     contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|     apply(contextWindow);
  #|   }
  #|   if (String(globalThis.__bidiCurrentContext || "") === String(ctxId)) {
  #|     const activeWindow = globalThis.window && typeof globalThis.window === "object"
  #|       ? globalThis.window
  #|       : globalThis;
  #|     const screen = activeWindow === contextWindow ? activeWindow.screen : apply(activeWindow);
  #|     if (screen) {
  #|       globalThis.screen = screen;
  #|     }
  #|   }
  #| }

///|
pub fn set_runtime_context_screen_area(
  ctx_id : String,
  width : Int,
  height : Int,
  avail_width : Int,
  avail_height : Int,
) -> Unit {
  js_set_runtime_context_screen_area(
    ctx_id, width, height, avail_width, avail_height,
  )
}

///|
/// Push the partition cookie snapshot for a context into the JS realm and
/// install (if absent) the `globalThis.__bidiResolveCookies(url)` bridge that
/// the runtime fetch shim uses to attach a Cookie header. The snapshot is
/// re-pushed on every script.evaluate via
/// `apply_effective_viewport_to_runtime_context`, so stale jars between calls
/// are not a concern.
extern "js" fn js_set_runtime_context_cookies(
  ctx_id : String,
  cookies_json : String,
) -> Unit =
  #| (ctxId, cookiesJson) => {
  #|   if (!globalThis.__bidiContextCookies) {
  #|     globalThis.__bidiContextCookies = new Map();
  #|   }
  #|   let parsed = [];
  #|   try {
  #|     const raw = JSON.parse(String(cookiesJson || "[]"));
  #|     if (Array.isArray(raw)) parsed = raw;
  #|   } catch (_e) {}
  #|   globalThis.__bidiContextCookies.set(String(ctxId), parsed);
  #|   if (typeof globalThis.__bidiResolveCookies !== "function") {
  #|     const stripLeadingDot = (host) => host && host.charAt(0) === "." ? host.slice(1) : host;
  #|     const requestHost = (url) => {
  #|       try { return new URL(url, globalThis.__pageUrl || "about:blank").hostname.toLowerCase(); }
  #|       catch (_e) { return ""; }
  #|     };
  #|     const requestPath = (url) => {
  #|       try {
  #|         const path = new URL(url, globalThis.__pageUrl || "about:blank").pathname;
  #|         return path || "/";
  #|       } catch (_e) { return "/"; }
  #|     };
  #|     const requestScheme = (url) => {
  #|       try { return new URL(url, globalThis.__pageUrl || "about:blank").protocol; }
  #|       catch (_e) { return ""; }
  #|     };
  #|     const matchDomain = (cookieDomain, host) => {
  #|       const d = stripLeadingDot(String(cookieDomain || "").toLowerCase());
  #|       if (d.length === 0) return true;
  #|       return host === d || host.endsWith("." + d);
  #|     };
  #|     const matchPath = (cookiePath, path) => {
  #|       const cp = String(cookiePath || "/");
  #|       if (cp.length === 0 || cp === "/") return true;
  #|       if (path === cp) return true;
  #|       if (!path.startsWith(cp)) return false;
  #|       if (cp.endsWith("/")) return true;
  #|       if (path.length === cp.length) return true;
  #|       return path.charAt(cp.length) === "/";
  #|     };
  #|     globalThis.__bidiResolveCookies = function(url) {
  #|       try {
  #|         const ctx = String(globalThis.__bidiCurrentContext || "default-context");
  #|         const store = globalThis.__bidiContextCookies;
  #|         if (!store || !store.has(ctx)) return "";
  #|         const cookies = store.get(ctx) || [];
  #|         if (!Array.isArray(cookies) || cookies.length === 0) return "";
  #|         const host = requestHost(url);
  #|         const path = requestPath(url);
  #|         const scheme = requestScheme(url);
  #|         const parts = [];
  #|         for (const cookie of cookies) {
  #|           if (!cookie || typeof cookie !== "object") continue;
  #|           if (cookie.secure && scheme !== "https:") continue;
  #|           if (!matchDomain(cookie.domain, host)) continue;
  #|           if (!matchPath(cookie.path, path)) continue;
  #|           const name = String(cookie.name || "");
  #|           if (name.length === 0) continue;
  #|           parts.push(name + "=" + String(cookie.value == null ? "" : cookie.value));
  #|         }
  #|         return parts.join("; ");
  #|       } catch (_e) { return ""; }
  #|     };
  #|   }
  #| }

///|
/// Push the partition cookie snapshot for `ctx_id` into the JS realm.
fn set_runtime_context_cookies(ctx_id : String, cookies_json : String) -> Unit {
  js_set_runtime_context_cookies(ctx_id, cookies_json)
}

///|
/// Drain the `globalThis.__bidiPendingCookieIngest` buffer and return its
/// contents as JSON. The buffer is the fetch shim's record of inbound
/// `Set-Cookie` response headers; MoonBit calls this at every
/// `apply_effective_viewport_to_runtime_context` to ingest those cookies
/// back into the partition jar. Returns `"[]"` when the buffer is missing
/// or empty so MoonBit can use a single shape for both paths.
extern "js" fn js_drain_pending_cookie_ingest() -> String =
  #| () => {
  #|   const buf = globalThis.__bidiPendingCookieIngest;
  #|   if (!Array.isArray(buf) || buf.length === 0) return "[]";
  #|   const out = JSON.stringify(buf);
  #|   globalThis.__bidiPendingCookieIngest = [];
  #|   return out;
  #| }

///|
/// Drain the pending cookie ingest buffer to a JSON string. Each entry is
/// `{url, cookies: [setCookieHeaderValue, ...], ctx}`.
fn drain_pending_cookie_ingest() -> String {
  js_drain_pending_cookie_ingest()
}

///|
/// Push the per-context unhandledPromptBehavior snapshot into the JS realm.
/// Read by `resolvePromptHandler` inside alert/confirm/prompt to decide
/// the synchronous return value. Snapshot shape mirrors the spec
/// dictionary: `{ alert: "dismiss", confirm: "accept", prompt: "dismiss",
/// default: "dismiss" }`. Missing entries default to "dismiss".
pub extern "js" fn js_set_runtime_prompt_handlers(
  handlers_json : String,
) -> Unit =
  #| (handlersJson) => {
  #|   try {
  #|     const parsed = JSON.parse(handlersJson);
  #|     if (parsed && typeof parsed === "object") {
  #|       globalThis.__bidiPromptHandlers = parsed;
  #|       return;
  #|     }
  #|   } catch (_e) {}
  #|   globalThis.__bidiPromptHandlers = {};
  #| }

///|
fn set_runtime_prompt_handlers(handlers_json : String) -> Unit {
  js_set_runtime_prompt_handlers(handlers_json)
}

///|
/// Drain the pending user-prompt buffer. Each entry is
/// `{ctx, type, message, defaultValue, handler}` where `type` is one of
/// "alert" | "confirm" | "prompt" and `handler` is the resolved
/// unhandledPromptBehavior at the time alert/confirm/prompt was called.
/// MoonBit converts each entry to a `browsingContext.userPromptOpened`
/// event at the next script.evaluate boundary.
extern "js" fn js_drain_pending_user_prompts() -> String =
  #| () => {
  #|   const buf = globalThis.__bidiPendingUserPrompts;
  #|   if (!Array.isArray(buf) || buf.length === 0) return "[]";
  #|   const out = JSON.stringify(buf);
  #|   globalThis.__bidiPendingUserPrompts = [];
  #|   return out;
  #| }

///|
fn drain_pending_user_prompts() -> String {
  js_drain_pending_user_prompts()
}

///|
/// Check if runtime handle exists in current JS handle store.
extern "js" fn js_has_runtime_handle(handle_id : String) -> Bool =
  #| (handleId) => {
  #|   const store = globalThis.__bidiHandleStore;
  #|   if (!store || !store.has(handleId)) return false;
  #|   const contextStore = globalThis.__bidiHandleContextStore;
  #|   if (!contextStore || !contextStore.has(handleId)) return true;
  #|   return (
  #|     String(contextStore.get(handleId)) ===
  #|     String(globalThis.__bidiCurrentContext || "")
  #|   );
  #| }

///|
/// Check if runtime handle exists in current JS handle store.
pub fn has_runtime_handle(handle_id : String) -> Bool {
  js_has_runtime_handle(handle_id)
}

///|
/// Remove handle from current JS handle store (no-op when absent).
extern "js" fn js_delete_runtime_handle(handle_id : String) -> Unit =
  #| (handleId) => {
  #|   const store = globalThis.__bidiHandleStore;
  #|   if (!store) return;
  #|   const contextStore = globalThis.__bidiHandleContextStore;
  #|   if (contextStore && contextStore.has(handleId)) {
  #|     const owner = String(contextStore.get(handleId));
  #|     const current = String(globalThis.__bidiCurrentContext || "");
  #|     if (owner !== current) return;
  #|     contextStore.delete(handleId);
  #|   }
  #|   store.delete(handleId);
  #| }

///|
/// Remove handle from current JS handle store (no-op when absent).
pub fn delete_runtime_handle(handle_id : String) -> Unit {
  js_delete_runtime_handle(handle_id)
}

///|
/// Check if runtime shared node exists in current JS shared node store.
extern "js" fn js_has_runtime_shared_node(shared_id : String) -> Bool =
  #| (sharedId) => {
  #|   return !!(globalThis.__bidiSharedNodeStore && globalThis.__bidiSharedNodeStore.has(sharedId));
  #| }

///|
/// Check if runtime shared node exists in current JS shared node store.
pub fn has_runtime_shared_node(shared_id : String) -> Bool {
  js_has_runtime_shared_node(shared_id)
}

///|
/// Check if runtime shared node exists and is an element node.
extern "js" fn js_runtime_shared_node_is_element(shared_id : String) -> Bool =
  #| (sharedId) => {
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   if (!store) return false;
  #|   const node = store.get(sharedId);
  #|   return !!(node && node.nodeType === 1);
  #| }

///|
/// Check if runtime shared node exists and is an element node.
pub fn runtime_shared_node_is_element(shared_id : String) -> Bool {
  js_runtime_shared_node_is_element(shared_id)
}

///|
/// Check if runtime shared node exists and is a document node.
extern "js" fn js_runtime_shared_node_is_document(shared_id : String) -> Bool =
  #| (sharedId) => {
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   if (!store) return false;
  #|   const node = store.get(sharedId);
  #|   return !!(node && node.nodeType === 9);
  #| }

///|
/// Check if runtime shared node exists and is a document node.
pub fn runtime_shared_node_is_document(shared_id : String) -> Bool {
  js_runtime_shared_node_is_document(shared_id)
}

///|
/// Check if runtime shared node exists and is a shadow root node.
extern "js" fn js_runtime_shared_node_is_shadow_root(
  shared_id : String,
) -> Bool =
  #| (sharedId) => {
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   if (!store) return false;
  #|   const node = store.get(sharedId);
  #|   return !!(node && node.nodeType === 11 && node.host);
  #| }

///|
/// Check if runtime shared node exists and is a shadow root node.
pub fn runtime_shared_node_is_shadow_root(shared_id : String) -> Bool {
  js_runtime_shared_node_is_shadow_root(shared_id)
}

///|
/// Check if runtime shared node has draggable attribute enabled.
extern "js" fn js_runtime_shared_node_is_draggable(shared_id : String) -> Bool =
  #| (sharedId) => {
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   if (!store) return false;
  #|   const node = store.get(sharedId);
  #|   if (!node || node.nodeType !== 1) return false;
  #|   let draggable = null;
  #|   if (typeof node.getAttribute === "function") {
  #|     try { draggable = node.getAttribute("draggable"); } catch (_e) {}
  #|   }
  #|   if ((draggable === null || draggable === undefined) && node._attrs) {
  #|     draggable = node._attrs.draggable;
  #|   }
  #|   if (draggable === null || draggable === undefined) return false;
  #|   if (draggable === true) return true;
  #|   const value = String(draggable).toLowerCase();
  #|   return value === "" || value === "true";
  #| }

///|
/// Check if runtime shared node has draggable attribute enabled.
pub fn runtime_shared_node_is_draggable(shared_id : String) -> Bool {
  js_runtime_shared_node_is_draggable(shared_id)
}

///|
/// Get center coordinate of shared element as JSON string.
extern "js" fn js_runtime_shared_node_center_json(shared_id : String) -> String =
  #| (sharedId) => {
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   const node = store && store.get(sharedId);
  #|   if (!node || node.nodeType !== 1) {
  #|     return JSON.stringify({ ok: false });
  #|   }
  #|   let x = 0;
  #|   let y = 0;
  #|   if (typeof node.getBoundingClientRect === "function") {
  #|     try {
  #|       const rect = node.getBoundingClientRect();
  #|       if (rect && typeof rect.left === "number" && typeof rect.top === "number") {
  #|         const left = Number(rect.left);
  #|         const top = Number(rect.top);
  #|         const right = typeof rect.right === "number"
  #|           ? Number(rect.right)
  #|           : left + (typeof rect.width === "number" ? Number(rect.width) : 0);
  #|         const bottom = typeof rect.bottom === "number"
  #|           ? Number(rect.bottom)
  #|           : top + (typeof rect.height === "number" ? Number(rect.height) : 0);
  #|         const viewportWidth =
  #|           Number(
  #|             (globalThis.window && globalThis.window.innerWidth) ||
  #|             (globalThis.document &&
  #|               globalThis.document.documentElement &&
  #|               globalThis.document.documentElement.clientWidth) ||
  #|             1024
  #|           );
  #|         const viewportHeight =
  #|           Number(
  #|             (globalThis.window && globalThis.window.innerHeight) ||
  #|             (globalThis.document &&
  #|               globalThis.document.documentElement &&
  #|               globalThis.document.documentElement.clientHeight) ||
  #|             768
  #|           );
  #|         const clippedLeft = Math.max(0, Math.min(left, right));
  #|         const clippedRight = Math.min(viewportWidth, Math.max(left, right));
  #|         const clippedTop = Math.max(0, Math.min(top, bottom));
  #|         const clippedBottom = Math.min(viewportHeight, Math.max(top, bottom));
  #|         if (clippedRight > clippedLeft && clippedBottom > clippedTop) {
  #|           x = (clippedLeft + clippedRight) / 2;
  #|           y = (clippedTop + clippedBottom) / 2;
  #|         } else {
  #|           x = (left + right) / 2;
  #|           y = (top + bottom) / 2;
  #|         }
  #|       }
  #|     } catch (_e) {}
  #|   }
  #|   if (x === 0 && y === 0) {
  #|     const style = node._style || node.style || {};
  #|     const left = Number.parseFloat(style.left ?? "0");
  #|     const top = Number.parseFloat(style.top ?? "0");
  #|     const width = Number.parseFloat(style.width ?? "0");
  #|     const height = Number.parseFloat(style.height ?? "0");
  #|     const safe = (n) => Number.isFinite(n) ? n : 0;
  #|     x = safe(left) + safe(width) / 2;
  #|     y = safe(top) + safe(height) / 2;
  #|   }
  #|   return JSON.stringify({ ok: true, x, y });
  #| }

///|
/// Get center coordinate of shared element as JSON string.
pub fn get_runtime_shared_node_center_json(shared_id : String) -> String {
  js_runtime_shared_node_center_json(shared_id)
}

///|
/// Resolve shared node at viewport point, allocating sharedId if needed.
extern "js" fn js_runtime_shared_node_at_point(
  x : Double,
  y : Double,
) -> String? =
  #| (x, y) => {
  #|   const doc = globalThis.document;
  #|   if (!doc || typeof doc.elementFromPoint !== "function") return null;
  #|   let node = null;
  #|   try { node = doc.elementFromPoint(Number(x), Number(y)); } catch (_e) {}
  #|   if (!node) return null;
  #|   const sharedIds = globalThis.__bidiNodeSharedIds || (globalThis.__bidiNodeSharedIds = new WeakMap());
  #|   const nodeStore = globalThis.__bidiSharedNodeStore || (globalThis.__bidiSharedNodeStore = new Map());
  #|   if (typeof globalThis.__bidiNextNodeSharedId !== "number") {
  #|     globalThis.__bidiNextNodeSharedId = 1;
  #|   }
  #|   let sharedId = sharedIds.get(node);
  #|   if (!sharedId) {
  #|     sharedId = `node-${globalThis.__bidiNextNodeSharedId++}`;
  #|     sharedIds.set(node, sharedId);
  #|   }
  #|   nodeStore.set(sharedId, node);
  #|   return sharedId;
  #| }

///|
/// Resolve shared node at viewport point, allocating sharedId if needed.
pub fn get_runtime_shared_node_at_point(x : Double, y : Double) -> String? {
  js_runtime_shared_node_at_point(x, y)
}

///|
/// Resolve href attribute from a shared element node.
extern "js" fn js_runtime_shared_node_href(shared_id : String) -> String? =
  #| (sharedId) => {
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   const node = store && store.get(sharedId);
  #|   if (!node || node.nodeType !== 1) return "";
  #|   let href = null;
  #|   try {
  #|     if (typeof node.getAttribute === "function") {
  #|       href = node.getAttribute("href");
  #|     }
  #|   } catch (_e) {}
  #|   if ((href === null || href === undefined || href === "") && node._attrs) {
  #|     href = node._attrs.href;
  #|   }
  #|   if (href === null || href === undefined || href === "") return "";
  #|   const rawHref = String(href);
  #|   try {
  #|     const base =
  #|       (globalThis.location && globalThis.location.href) ||
  #|       globalThis.__pageUrl ||
  #|       "about:blank";
  #|     return new URL(rawHref, base).href;
  #|   } catch (_e) {
  #|     return rawHref;
  #|   }
  #| }

///|
/// Resolve href attribute from a shared element node.
pub fn get_runtime_shared_node_href(shared_id : String) -> String? {
  js_runtime_shared_node_href(shared_id)
}

///|
/// Resolve absolute href from an anchor identified by id or global symbol.
extern "js" fn js_runtime_anchor_href_by_id(anchor_id : String) -> String? =
  #| (anchorId) => {
  #|   const id = String(anchorId || "");
  #|   if (!id) return "";
  #|   const doc = globalThis.document;
  #|   if (!doc) return "";
  #|   let node = null;
  #|   try {
  #|     if (typeof doc.getElementById === "function") {
  #|       node = doc.getElementById(id);
  #|     }
  #|   } catch (_e) {}
  #|   if (!node) {
  #|     try {
  #|       const candidate = globalThis[id];
  #|       if (candidate && typeof candidate === "object") {
  #|         node = candidate;
  #|       }
  #|     } catch (_e) {}
  #|   }
  #|   if (!node) return "";
  #|   let href = null;
  #|   try {
  #|     if (typeof node.getAttribute === "function") {
  #|       href = node.getAttribute("href");
  #|     }
  #|   } catch (_e) {}
  #|   if ((href === null || href === undefined || href === "") && node._attrs) {
  #|     href = node._attrs.href;
  #|   }
  #|   if (href === null || href === undefined || href === "") return "";
  #|   const rawHref = String(href);
  #|   try {
  #|     const base =
  #|       (globalThis.location && globalThis.location.href) ||
  #|       globalThis.__pageUrl ||
  #|       "about:blank";
  #|     return new URL(rawHref, base).href;
  #|   } catch (_e) {
  #|     return rawHref;
  #|   }
  #| }

///|
/// Resolve absolute href from an anchor identified by id or global symbol.
pub fn get_runtime_anchor_href_by_id(anchor_id : String) -> String? {
  js_runtime_anchor_href_by_id(anchor_id)
}

///|
/// Resolve `download` attribute value from an anchor identified by id or global symbol.
extern "js" fn js_runtime_anchor_download_attr_by_id(
  anchor_id : String,
) -> String? =
  #| (anchorId) => {
  #|   const id = String(anchorId || "");
  #|   if (!id) return "";
  #|   const doc = globalThis.document;
  #|   if (!doc) return "";
  #|   let node = null;
  #|   try {
  #|     if (typeof doc.getElementById === "function") {
  #|       node = doc.getElementById(id);
  #|     }
  #|   } catch (_e) {}
  #|   if (!node) {
  #|     try {
  #|       const candidate = globalThis[id];
  #|       if (candidate && typeof candidate === "object") {
  #|         node = candidate;
  #|       }
  #|     } catch (_e) {}
  #|   }
  #|   if (!node) return "";
  #|   let value = null;
  #|   try {
  #|     if (typeof node.getAttribute === "function") {
  #|       value = node.getAttribute("download");
  #|     }
  #|   } catch (_e) {}
  #|   if ((value === null || value === undefined) && node._attrs) {
  #|     value = node._attrs.download;
  #|   }
  #|   if (value === null || value === undefined) return "";
  #|   return String(value);
  #| }

///|
/// Resolve `download` attribute value from an anchor identified by id or global symbol.
pub fn get_runtime_anchor_download_attr_by_id(anchor_id : String) -> String? {
  js_runtime_anchor_download_attr_by_id(anchor_id)
}

///|
/// Extract query parameter value from an URL string.
extern "js" fn js_runtime_url_query_param(
  url : String,
  key : String,
) -> String? =
  #| (url, key) => {
  #|   const rawUrl = String(url || "");
  #|   const rawKey = String(key || "");
  #|   if (!rawUrl || !rawKey) return "";
  #|   try {
  #|     const base =
  #|       (globalThis.location && globalThis.location.href) ||
  #|       globalThis.__pageUrl ||
  #|       "about:blank";
  #|     const parsed = new URL(rawUrl, base);
  #|     const value = parsed.searchParams.get(rawKey);
  #|     if (value === null || value === undefined) return "";
  #|     return String(value);
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
/// Extract query parameter value from an URL string.
pub fn get_runtime_url_query_param(url : String, key : String) -> String? {
  js_runtime_url_query_param(url, key)
}

///|
/// Write UTF-8 text file for synthetic download tests.
extern "js" fn js_runtime_write_text_file(
  path : String,
  content : String,
) -> Unit =
  #| (path, content) => {
  #|   const filePath = String(path || "");
  #|   if (!filePath) return;
  #|   try {
  #|     const deno = globalThis.Deno;
  #|     if (!deno || typeof deno.writeTextFileSync !== "function") return;
  #|     // Security: resolve to absolute path and reject path traversal
  #|     const resolved = deno.realPathSync ? (() => {
  #|       // Resolve parent directory to detect traversal
  #|       const sep = filePath.lastIndexOf("/");
  #|       if (sep <= 0) return filePath;
  #|       const dir = filePath.slice(0, sep);
  #|       const base = filePath.slice(sep + 1);
  #|       // Reject filenames with path separators or traversal
  #|       if (base.includes("/") || base.includes("\\") || base === ".." || base === ".") {
  #|         console.error("[security] rejected filename: " + base);
  #|         return null;
  #|       }
  #|       // Reject if directory contains traversal sequences
  #|       if (dir.includes("..")) {
  #|         console.error("[security] rejected path traversal in directory: " + dir);
  #|         return null;
  #|       }
  #|       return filePath;
  #|     })() : filePath;
  #|     if (!resolved) return;
  #|     const sep = resolved.lastIndexOf("/");
  #|     if (sep > 0 && typeof deno.mkdirSync === "function") {
  #|       const dir = resolved.slice(0, sep);
  #|       try { deno.mkdirSync(dir, { recursive: true }); } catch (_e) {}
  #|     }
  #|     deno.writeTextFileSync(resolved, String(content ?? ""));
  #|   } catch (_e) {}
  #| }

///|
/// Write UTF-8 text file for synthetic download tests.
pub fn runtime_write_text_file(path : String, content : String) -> Unit {
  js_runtime_write_text_file(path, content)
}

///|
/// Collect iframe src values from runtime document.
extern "js" fn js_runtime_iframe_sources() -> Array[String] =
  #| () => {
  #|   const doc = globalThis.document;
  #|   if (!doc || typeof doc.querySelectorAll !== "function") return [];
  #|   const nodes = doc.querySelectorAll("iframe");
  #|   const result = [];
  #|   for (const node of nodes) {
  #|     let src = null;
  #|     try {
  #|       if (node && typeof node.getAttribute === "function") {
  #|         src = node.getAttribute("src");
  #|       }
  #|     } catch (_e) {}
  #|     if ((src === null || src === undefined || src === "") && node && node._attrs) {
  #|       src = node._attrs.src;
  #|     }
  #|     if (src === null || src === undefined || src === "") {
  #|       result.push("about:blank");
  #|     } else {
  #|       result.push(String(src));
  #|     }
  #|   }
  #|   return result;
  #| }

///|
/// Collect iframe src values from runtime document.
pub fn get_runtime_iframe_sources() -> Array[String] {
  js_runtime_iframe_sources()
}

///|
/// Resolve href from the most recent synthetic click target.
extern "js" fn js_runtime_last_click_href() -> String? =
  #| () => {
  #|   const href = globalThis.__bidiLastClickHref;
  #|   if (href === null || href === undefined || href === "") return "";
  #|   return String(href);
  #| }

///|
/// Resolve href from the most recent synthetic click target.
pub fn get_runtime_last_click_href() -> String? {
  js_runtime_last_click_href()
}

///|
/// Resolve data/absolute URL assigned by inline event handlers like onkeydown/onmousedown.
extern "js" fn js_runtime_inline_navigation_url(
  attribute_name : String,
) -> String? =
  #| (attributeName) => {
  #|   const doc = globalThis.document;
  #|   if (!doc || typeof doc.querySelectorAll !== "function") return "";
  #|   const attr = String(attributeName || "");
  #|   if (attr === "") return "";
  #|   const selector = `[${attr}]`;
  #|   const nodes = doc.querySelectorAll(selector);
  #|   for (const node of nodes) {
  #|     let handler = "";
  #|     try {
  #|       if (node && typeof node.getAttribute === "function") {
  #|         handler = node.getAttribute(attr) || "";
  #|       }
  #|     } catch (_e) {}
  #|     if (!handler && node && node._attrs) {
  #|       handler = String(node._attrs[attr] || "");
  #|     }
  #|     if (!handler) continue;
  #|     const match = String(handler).match(/window\.location(?:\.href)?\s*=\s*["']([^"']+)["']/);
  #|     if (!match || !match[1]) continue;
  #|     const raw = String(match[1]);
  #|     try {
  #|       const base =
  #|         (globalThis.location && globalThis.location.href) ||
  #|         globalThis.__pageUrl ||
  #|         "about:blank";
  #|       return new URL(raw, base).href;
  #|     } catch (_e) {
  #|       return raw;
  #|     }
  #|   }
  #|   return "";
  #| }

///|
/// Resolve data/absolute URL assigned by inline event handlers like onkeydown/onmousedown.
pub fn get_runtime_inline_navigation_url(attribute_name : String) -> String? {
  js_runtime_inline_navigation_url(attribute_name)
}

///|
/// Resolve href from element under viewport coordinates.
extern "js" fn js_runtime_href_at_point(x : Double, y : Double) -> String? =
  #| (x, y) => {
  #|   const doc = globalThis.document;
  #|   if (!doc) return "";
  #|   let node = null;
  #|   if (typeof doc.elementFromPoint === "function") {
  #|     try {
  #|       node = doc.elementFromPoint(Number(x), Number(y));
  #|     } catch (_e) {}
  #|   }
  #|   const hrefFromNode = (candidate) => {
  #|     let current = candidate;
  #|     while (current) {
  #|       let href = null;
  #|       try {
  #|         if (typeof current.getAttribute === "function") {
  #|           href = current.getAttribute("href");
  #|         }
  #|       } catch (_e) {}
  #|       if ((href === null || href === undefined || href === "") && current._attrs) {
  #|         href = current._attrs.href;
  #|       }
  #|       if (href !== null && href !== undefined && href !== "") {
  #|         const rawHref = String(href);
  #|         try {
  #|           const base =
  #|             (globalThis.location && globalThis.location.href) ||
  #|             globalThis.__pageUrl ||
  #|             "about:blank";
  #|           return new URL(rawHref, base).href;
  #|         } catch (_e) {
  #|           return rawHref;
  #|         }
  #|       }
  #|       current = current._parent || current.parentNode || null;
  #|     }
  #|     return null;
  #|   };
  #|   let href = hrefFromNode(node);
  #|   if (href !== null && href !== undefined && href !== "") return href;
  #|   if (href === null || href === undefined || href === "") return "";
  #|   return href;
  #| }

///|
/// Resolve href from element under viewport coordinates.
pub fn get_runtime_href_at_point(x : Double, y : Double) -> String? {
  js_runtime_href_at_point(x, y)
}

///|
/// Push the per-context Authorization snapshot into the JS realm. The
/// snapshot is consumed by the auto-installed globalThis.__bidiResolveAuth
/// helper that the fetch shim calls before dispatching each outbound
/// request. Mirror of set_runtime_context_cookies.
pub extern "js" fn js_set_runtime_context_authorization(
  ctx_id : String,
  auth_json : String,
) -> Unit =
  #| (ctxId, authJson) => {
  #|   if (!globalThis.__bidiContextAuth) globalThis.__bidiContextAuth = {};
  #|   try {
  #|     globalThis.__bidiContextAuth[ctxId] = JSON.parse(authJson);
  #|   } catch (_e) {
  #|     globalThis.__bidiContextAuth[ctxId] = {};
  #|   }
  #|   if (typeof globalThis.__bidiResolveAuth !== 'function') {
  #|     globalThis.__bidiResolveAuth = function(url) {
  #|       const ctx = String(globalThis.__bidiCurrentContext || 'default-context');
  #|       const map = (globalThis.__bidiContextAuth || {})[ctx] || {};
  #|       try {
  #|         const u = new URL(url);
  #|         let origin = u.protocol + '//' + u.hostname;
  #|         if (
  #|           (u.protocol === 'http:'  && u.port && u.port !== '80') ||
  #|           (u.protocol === 'https:' && u.port && u.port !== '443')
  #|         ) origin += ':' + u.port;
  #|         return map[origin] || null;
  #|       } catch (_e) { return null; }
  #|     };
  #|   }
  #| }

///|
/// Push the per-context Authorization snapshot for `ctx_id` into the JS realm.
fn set_runtime_context_authorization(
  ctx_id : String,
  auth_json : String,
) -> Unit {
  js_set_runtime_context_authorization(ctx_id, auth_json)
}

///|
/// Push the per-context Digest credentials snapshot into the JS realm.
/// The snapshot shape is `{ origin: { username, password } }`. Consumed
/// by the fetch shim's 401 Digest auto-retry path via the auto-installed
/// `globalThis.__bidiResolveCredentials(url)` helper.
///
/// Credentials are passed by-value into the JS realm — there is no
/// indirection that would let the page read them ambient-style. The
/// runtime-side helper only returns the matching entry for the request's
/// origin AND only inside the retry path that already has a Digest
/// challenge in hand, so an attacker page on a different origin can't
/// silently extract a stored credential by issuing fetches.
pub extern "js" fn js_set_runtime_context_credentials(
  ctx_id : String,
  creds_json : String,
) -> Unit =
  #| (ctxId, credsJson) => {
  #|   if (!globalThis.__bidiContextCredentials) globalThis.__bidiContextCredentials = {};
  #|   try {
  #|     globalThis.__bidiContextCredentials[ctxId] = JSON.parse(credsJson);
  #|   } catch (_e) {
  #|     globalThis.__bidiContextCredentials[ctxId] = {};
  #|   }
  #|   if (typeof globalThis.__bidiResolveCredentials !== 'function') {
  #|     globalThis.__bidiResolveCredentials = function(url) {
  #|       const ctx = String(globalThis.__bidiCurrentContext || 'default-context');
  #|       const map = (globalThis.__bidiContextCredentials || {})[ctx] || {};
  #|       try {
  #|         const u = new URL(url);
  #|         let origin = u.protocol + '//' + u.hostname;
  #|         if (
  #|           (u.protocol === 'http:'  && u.port && u.port !== '80') ||
  #|           (u.protocol === 'https:' && u.port && u.port !== '443')
  #|         ) origin += ':' + u.port;
  #|         return map[origin] || null;
  #|       } catch (_e) { return null; }
  #|     };
  #|   }
  #| }

///|
/// Push the per-context credentials snapshot for `ctx_id` into the JS realm.
fn set_runtime_context_credentials(
  ctx_id : String,
  creds_json : String,
) -> Unit {
  js_set_runtime_context_credentials(ctx_id, creds_json)
}
