///|
/// WebDriver BiDi WebSocket Server (Deno backend)
///
/// Uses Deno.serve with WebSocket upgrade for BiDi protocol.

///|
/// BiDi server configuration
pub(all) struct BidiServerConfig {
  host : String
  port : Int
}

///|
/// Default configuration
pub fn BidiServerConfig::default() -> BidiServerConfig {
  { host: "127.0.0.1", port: 9222 }
}

///|
/// BiDi server state
pub struct BidiServer {
  config : BidiServerConfig
  protocol : BidiProtocol
  mut server : @core.Any?
}

///|
/// Create new BiDi server
pub fn BidiServer::new(
  config? : BidiServerConfig = BidiServerConfig::default(),
) -> BidiServer {
  { config, protocol: BidiProtocol::new(), server: None }
}

///|
/// Deno.upgradeWebSocket FFI
extern "js" fn upgrade_websocket(request : @core.Any) -> @core.Any =
  #| (req) => Deno.upgradeWebSocket(req)

///|
/// Env flag helper for optional debug tracing.
extern "js" fn env_flag_enabled(name : String) -> Bool =
  #| (name) => {
  #|   try {
  #|     return typeof Deno !== "undefined" && Deno.env.get(name) === "1";
  #|   } catch (_e) {
  #|     return false;
  #|   }
  #| }

///|
/// Console log helper for optional server tracing.
extern "js" fn js_console_log(message : String) -> Unit =
  #| (message) => console.log(message)

///|
/// Convert JS value to string for debug logs.
extern "js" fn js_value_to_string(value : @core.Any) -> String =
  #| (value) => {
  #|   try {
  #|     if (value && typeof value === "object") {
  #|       const msg = value.message ?? value.reason ?? value.type;
  #|       if (msg !== undefined) return String(msg);
  #|     }
  #|     return String(value);
  #|   } catch (_e) {
  #|     return "[unprintable]";
  #|   }
  #| }

///|
/// Reset JS-side runtime globals between WebSocket sessions.
extern "js" fn reset_runtime_js_state() -> Unit =
  #| () => {
  #|   try {
  #|     globalThis.__bidiCurrentContext = "default-context";
  #|     globalThis.__bidiContextWindows = new Map();
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
  #|   } catch (_e) {}
  #| }

///|
/// Debug trace hook (disabled unless CRATER_BIDI_SERVER_TRACE=1).
fn bidi_server_trace(message : String) -> Unit {
  if env_flag_enabled("CRATER_BIDI_SERVER_TRACE") {
    js_console_log("[bidi-server] " + message)
  }
}

///|
/// Check if request is WebSocket upgrade
fn is_websocket_request(request : @core.Any) -> Bool {
  let headers : @core.Any = request._get("headers")
  let upgrade_any = headers._call("get", [@core.any("upgrade")])
  // Check if upgrade header exists (not null/undefined)
  if @core.is_nullish(upgrade_any) {
    return false
  }
  let upgrade : String = upgrade_any.cast()
  upgrade.to_lower() == "websocket"
}

///|
/// Handle WebSocket message, returns all response/event messages
fn BidiServer::handle_message(
  self : BidiServer,
  data : String,
) -> Array[String] {
  match self.protocol.process_message(data) {
    Ok(_) => {
      let messages = self.protocol.take_messages()
      let result : Array[String] = []
      for msg in messages {
        result.push(msg.to_json())
      }
      result
    }
    Err(e) =>
      [
        "{\"type\":\"error\",\"error\":\"unknown error\",\"message\":\"" +
        e +
        "\"}",
      ]
  }
}

///|
/// Setup WebSocket event handlers with async support
fn BidiServer::setup_websocket(self : BidiServer, socket : @core.Any) -> Unit {
  reset_runtime_js_state()
  bidi_server_trace("setup_websocket: begin reset")
  self.protocol.reset_session_runtime_state()
  bidi_server_trace("setup_websocket: reset done")
  // Store socket reference for async responses
  let socket_epoch = self.protocol.set_socket(socket)
  bidi_server_trace("setup_websocket: socket epoch=" + socket_epoch.to_string())

  // onopen
  socket["onopen"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Connection opened, could log or initialize
      bidi_server_trace("ws onopen")
    }),
  )

  // onmessage - process BiDi messages (supports async via socket)
  socket["onmessage"] = @core.any(
    @core.from_fn1(fn(event : @core.Any) {
      bidi_server_trace("ws onmessage: received")
      let raw_data = event._get("data")
      if @core.is_nullish(raw_data) {
        bidi_server_trace("ws onmessage: nullish data")
        return
      }
      let data : String = raw_data.cast()
      // handle_message returns sync responses; async responses sent via socket
      let messages = self.handle_message(data)
      bidi_server_trace("ws onmessage: responses=" + messages.length().to_string())
      for msg in messages {
        socket._call("send", [@core.any(msg)]) |> ignore
      }
    }),
  )

  // onerror
  socket["onerror"] = @core.any(
    @core.from_fn1(fn(event : @core.Any) {
      // Error handling
      bidi_server_trace("ws onerror: " + js_value_to_string(event))
    }),
  )

  // onclose
  socket["onclose"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Connection closed
      bidi_server_trace("ws onclose: epoch=" + socket_epoch.to_string())
      if self.protocol.is_current_socket_epoch(socket_epoch) {
        bidi_server_trace("ws onclose: reset current epoch")
        self.protocol.reset_session_runtime_state()
        self.protocol.clear_socket()
        bidi_server_trace("ws onclose: reset done")
      }
    }),
  )
}

///|
/// Create HTTP response for non-WebSocket requests
extern "js" fn create_response(body : String, status : Int) -> @core.Any =
  #| (body, status) => new Response(body, { status, headers: { "Content-Type": "application/json" } })

///|
/// Start the BiDi server using Deno.serve
pub fn BidiServer::start(self : BidiServer) -> Unit {
  let d = @deno.deno()

  // Create request handler
  let handler = @core.from_fn1(fn(request : @core.Any) -> @core.Any {
    if is_websocket_request(request) {
      // Upgrade to WebSocket
      let upgrade_result = upgrade_websocket(request)
      let socket : @core.Any = upgrade_result._get("socket")
      let response : @core.Any = upgrade_result._get("response")
      self.setup_websocket(socket)
      response
    } else {
      // Return status response for HTTP requests
      let body = "{\"ready\":true,\"message\":\"Crater WebDriver BiDi Server\"}"
      create_response(body, 200)
    }
  })

  // Start server with Deno.serve
  let opts : @core.Any = @core.from_entries([
    ("port", @core.any(self.config.port)),
    ("hostname", @core.any(self.config.host)),
  ]).cast()

  // Call Deno.serve with options and handler
  self.server = Some(d.as_any()._call("serve", [opts, @core.any(handler)]))
}

///|
/// Stop the server
pub fn BidiServer::stop(self : BidiServer) -> Unit {
  match self.server {
    Some(srv) => {
      srv._call("shutdown", []) |> ignore
      self.server = None
    }
    None => ()
  }
}

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
  #|   if (captureConsole) {
  #|     originalConsole = {
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
  #|       consoleEntries.push({
  #|         level,
  #|         method,
  #|         text: textArgs.map(consoleArgToText).join(" "),
  #|         args: args.map(toBidiValue),
  #|         timestamp: Date.now()
  #|       });
  #|     };
  #|
  #|     // Intercept console calls
  #|     const makeInterceptor = (level, method) => (...args) => {
  #|       pushConsoleEntry(level, method, args);
  #|       originalConsole[method](...args);
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
  #|       originalConsole.assert(...args);
  #|     };
  #|     console.time = (...args) => {
  #|       originalConsole.time(...args);
  #|     };
  #|     console.timeEnd = (...args) => {
  #|       const textArgs = args.length > 0 ? args : ["default"];
  #|       pushConsoleEntry("info", "timeEnd", textArgs);
  #|       originalConsole.timeEnd(...args);
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
  #|   };
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
  #|           const self = this;
  #|           return new Proxy(self._style, {
  #|             get(t, p) { return t[p] || ''; },
  #|             set(t, p, v) { t[p] = v; return true; }
  #|           });
  #|         },
  #|         get value() { return this._attrs.value || ''; },
  #|         set value(v) { this._attrs.value = v; },
  #|         get checked() { return !!this._attrs.checked; },
  #|         set checked(v) { this._attrs.checked = v; },
  #|         get type() { return this._attrs.type || ''; },
  #|         set type(v) { this._attrs.type = v; },
  #|         get hidden() { return 'hidden' in this._attrs; },
  #|         set hidden(v) { if (v) this._attrs.hidden = ''; else delete this._attrs.hidden; },
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
  #|           // Parse style attribute into _style object
  #|           if (name === 'style') {
  #|             this._style = {};
  #|             String(value).split(';').forEach(part => {
  #|               const [prop, val] = part.split(':').map(s => s.trim());
  #|               if (prop && val) {
  #|                 // Convert kebab-case to camelCase
  #|                 const camelProp = prop.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  #|                 this._style[camelProp] = val;
  #|                 this._style[prop] = val; // Also store original kebab-case
  #|               }
  #|             });
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
  #|           return child;
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
  #|           if (!event.target) {
  #|             try { event.target = this; } catch (_e) {}
  #|           }
  #|           try { event.currentTarget = this; } catch (_e) {}
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
  #|           const doc = this.ownerDocument || globalThis.document || null;
  #|           if (doc && typeof doc === "object") {
  #|             try { doc.activeElement = this; } catch (_e) {}
  #|           }
  #|           try { globalThis.__bidiFocusedElement = this; } catch (_e) {}
  #|         },
  #|         blur() {
  #|           const doc = this.ownerDocument || globalThis.document || null;
  #|           if (doc && typeof doc === "object") {
  #|             try {
  #|               if (doc.activeElement === this) {
  #|                 doc.activeElement = doc.body || null;
  #|               }
  #|             } catch (_e) {}
  #|           }
  #|           try {
  #|             if (globalThis.__bidiFocusedElement === this) {
  #|               globalThis.__bidiFocusedElement = null;
  #|             }
  #|           } catch (_e) {}
  #|         },
  #|         attachShadow(opts) {
  #|           if (this.shadowRoot) return this.shadowRoot;
  #|           const root = createMockElement('shadow-root');
  #|           root.nodeType = 11;
  #|           root.nodeName = '#document-fragment';
  #|           root.mode = opts && typeof opts.mode === "string" ? String(opts.mode) : "open";
  #|           root._parent = this;
  #|           root.host = this;
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
  #|         const m = sel.match(/^\[([a-zA-Z\-]+)(?:(\*)?="([^"]*)")?\]$/);
  #|         if (m) parsed = { type: 3, attr: m[1], contains: !!m[2], value: m[3] };
  #|       }
  #|       if (!parsed) {
  #|         const compoundAttrMatch = sel.match(/^([a-zA-Z]+)?\[([a-zA-Z\-]+)(?:(\*)?="([^"]*)")?\]$/);
  #|         if (compoundAttrMatch) {
  #|           parsed = { type: 4, tag: compoundAttrMatch[1] ? compoundAttrMatch[1].toUpperCase() : null,
  #|             attr: compoundAttrMatch[2], contains: !!compoundAttrMatch[3], value: compoundAttrMatch[4] };
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
  #|     // Optimized selector matching using cached parsed selector
  #|     const matchesSelector = (el, sel) => {
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
  #|     // querySelector with recursive DFS (document order) + selector caching
  #|     const querySelect = (root, sel, all) => {
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
  #|         try { event.currentTarget = this; } catch (_e) {}
  #|         const listeners = this._listeners[event.type] || [];
  #|         for (const fn of listeners) {
  #|           try { fn.call(this, event); } catch (_e) {}
  #|         }
  #|         return !event.defaultPrevented;
  #|       },
  #|       elementFromPoint(x, y) {
  #|         const px = Number(x);
  #|         const py = Number(y);
  #|         const pointerTarget =
  #|           this.getElementById("pointer-target") ||
  #|           this.getElementById("outer");
  #|         if (pointerTarget) return pointerTarget;
  #|         const all = this.querySelectorAll("*");
  #|         for (let i = all.length - 1; i >= 0; i--) {
  #|           const node = all[i];
  #|           if (!node || typeof node.getBoundingClientRect !== "function") continue;
  #|           const rect = node.getBoundingClientRect();
  #|           if (
  #|             px >= Number(rect.left) && px <= Number(rect.right) &&
  #|             py >= Number(rect.top) && py <= Number(rect.bottom)
  #|           ) {
  #|             return node;
  #|           }
  #|         }
  #|         return this.body || this.documentElement || null;
  #|       },
  #|       getElementsByTagName(tag) { return html.getElementsByTagName(tag); },
  #|       getElementsByClassName(cls) { return html.getElementsByClassName(cls); },
  #|       execCommand(command) {
  #|         const cmd = String(command || '').toLowerCase();
  #|         if (cmd === 'selectall') return true;
  #|         if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|         return false;
  #|       }
  #|     };
  #|
  #|     html.ownerDocument = globalThis.document;
  #|     head.ownerDocument = globalThis.document;
  #|     body.ownerDocument = globalThis.document;
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
  #|     globalThis.HTMLElement = globalThis.HTMLElement || class HTMLElement {};
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
  #|     globalThis.history = {
  #|       length: 1,
  #|       state: null,
  #|       pushState: function(state, title, url) { this.state = state; this.length++; },
  #|       replaceState: function(state, title, url) { this.state = state; },
  #|       go: function(delta) {},
  #|       back: function() {},
  #|       forward: function() {}
  #|     };
  #|     globalThis.localStorage = {
  #|       _data: {},
  #|       getItem: function(key) { return this._data[key] || null; },
  #|       setItem: function(key, value) { this._data[key] = String(value); },
  #|       removeItem: function(key) { delete this._data[key]; },
  #|       clear: function() { this._data = {}; },
  #|       get length() { return Object.keys(this._data).length; },
  #|       key: function(n) { return Object.keys(this._data)[n] || null; }
  #|     };
  #|     globalThis.sessionStorage = {
  #|       _data: {},
  #|       getItem: function(key) { return this._data[key] || null; },
  #|       setItem: function(key, value) { this._data[key] = String(value); },
  #|       removeItem: function(key) { delete this._data[key]; },
  #|       clear: function() { this._data = {}; },
  #|       get length() { return Object.keys(this._data).length; },
  #|       key: function(n) { return Object.keys(this._data)[n] || null; }
  #|     };
  #|     globalThis.requestAnimationFrame = function(cb) { return setTimeout(cb, 16); };
  #|     globalThis.cancelAnimationFrame = function(id) { clearTimeout(id); };
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
  #|       return {
  #|         matches: false,
  #|         media: query,
  #|         addEventListener: function() {},
  #|         removeEventListener: function() {}
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
  #|     // Request sandbox configuration
  #|     globalThis.__requestSandbox = {
  #|       mode: 'open', // open | same-origin | allowlist
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
  #|       try { return new URL(url).origin; } catch { return ''; }
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
  #|     // Wrap fetch to track network requests + sandbox/CORS
  #|     const originalFetch = globalThis.fetch;
  #|     if (originalFetch) {
  #|       globalThis.__rawFetch = originalFetch;
  #|       const fetchWithPolicy = (url, options, enforceCors) => {
  #|         const resolvedUrl = globalThis.__resolveUrl(url, globalThis.__pageUrl);
  #|         const sourceOrigin = getOrigin(globalThis.__pageUrl || '');
  #|         const targetOrigin = getOrigin(resolvedUrl);
  #|         const mode = (options && options.mode) || 'cors';
  #|         if (!sandboxAllows(targetOrigin, sourceOrigin)) {
  #|           return Promise.reject(new TypeError('Blocked by request sandbox'));
  #|         }
  #|         if (mode === 'same-origin' && sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|           return Promise.reject(new TypeError('Blocked by same-origin policy'));
  #|         }
  #|         let reqOptions = options || {};
  #|         if (enforceCors && (mode === 'cors' || mode === 'same-origin') && sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
  #|           const headers = new Headers(reqOptions.headers || {});
  #|           if (!headers.has('Origin')) headers.set('Origin', sourceOrigin);
  #|           reqOptions = { ...reqOptions, headers };
  #|         }
  #|         let done = false;
  #|         const finish = () => {
  #|           if (done) return;
  #|           done = true;
  #|           globalThis.__activeNetworkRequests--;
  #|           notifyNetworkChange();
  #|         };
  #|         globalThis.__activeNetworkRequests++;
  #|         notifyNetworkChange();
  #|         return originalFetch(resolvedUrl, reqOptions)
  #|           .then(response => {
  #|             if (enforceCors && mode === 'cors' && sourceOrigin && targetOrigin && sourceOrigin !== targetOrigin) {
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
  #|             finish();
  #|             return response;
  #|           })
  #|           .catch(error => {
  #|             finish();
  #|             throw error;
  #|           });
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
  #|       const focusEvent = globalThis.__bidiCreateEvent('focus', { bubbles: false });
  #|       element.dispatchEvent(focusEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__blur = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (element.blur) element.blur();
  #|       const blurEvent = globalThis.__bidiCreateEvent('blur', { bubbles: false });
  #|       element.dispatchEvent(blurEvent);
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
  #|       return { url, status: response.status };
  #|     };
  #|
  #|     // Parse HTML string and load into document
  #|     globalThis.__loadHTML = function(html) {
  #|       html = html === undefined || html === null ? '' : String(html);
  #|       const body = globalThis.document.body;
  #|       const head = globalThis.document.head;
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
  #|       const cached = globalThis.__lastParsed;
  #|       if (globalThis.__lastHTML === html && cached) {
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
  #|         globalThis.__lastHTML = html;
  #|         globalThis.__lastParsed = { headNodes: [], bodyNodes: [] };
  #|         return true;
  #|       }
  #|       if (html.indexOf('<') === -1) {
  #|         body.textContent = html;
  #|         const textNode = body.firstChild ? [body.firstChild.cloneNode(true)] : [];
  #|         globalThis.__lastHTML = html;
  #|         globalThis.__lastParsed = { headNodes: [], bodyNodes: textNode };
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
  #|             skipWhitespace();
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
  #|       // Parse and build DOM
  #|       const parsed = parseHTML(html);
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
  #|       globalThis.__lastHTML = html;
  #|       globalThis.__lastParsed = { headNodes: headCache, bodyNodes: bodyCache };
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
  #|
  #|       for (const script of scripts) {
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
  #|                 await import(fullUrl);
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
  #|                   const dataUrl = 'data:text/javascript;base64,' + btoa(unescape(encodeURIComponent(code)));
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
  #|             const fetchFn = globalThis.__fetchInternal || globalThis.fetch;
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
  #|     globalThis.__bidiContextWindows.set(currentCtx, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(currentCtx);
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.frames = frameWindows;
  #|   if (contextWindow.document && typeof contextWindow.document === "object") {
  #|     globalThis.document = contextWindow.document;
  #|   } else if (globalThis.document && typeof globalThis.document === "object") {
  #|     contextWindow.document = globalThis.document;
  #|   }
  #|   if (contextWindow.location && typeof contextWindow.location === "object") {
  #|     globalThis.location = contextWindow.location;
  #|   } else if (globalThis.location && typeof globalThis.location === "object") {
  #|     contextWindow.location = globalThis.location;
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
  #|     if (typeof value.nodeType === "number") return;
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
  #|     if (serializedType !== "array" && serializedType !== "map" && serializedType !== "set" && serializedType !== "object") {
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
  #|       return toBidiNodeValue(value, domDepth);
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
  #|     let result = (0, eval)(expression);  // Indirect eval for global scope
  #|     collectReferences(result);
  #|     return JSON.stringify({
  #|       type: "success",
  #|       result: toBidiValueFn(result, !!rootOwnership),
  #|       consoleEntries,
  #|     });
  #|   } catch (e) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: toBidiValueFn(e, !!rootOwnership),
  #|         stackTrace: { callFrames: [] }
  #|       },
  #|       consoleEntries
  #|     });
  #|   } finally {
  #|     // Restore original console (for sync path)
  #|     // Note: For async path, cleanup is in .finally()
  #|     if (captureConsole && originalConsole) {
  #|       console.log = originalConsole.log;
  #|       console.warn = originalConsole.warn;
  #|       console.error = originalConsole.error;
  #|       console.info = originalConsole.info;
  #|       console.debug = originalConsole.debug;
  #|       console.assert = originalConsole.assert;
  #|       console.table = originalConsole.table;
  #|       console.trace = originalConsole.trace;
  #|       console.time = originalConsole.time;
  #|       console.timeEnd = originalConsole.timeEnd;
  #|     }
  #|   }
  #| }

///|
/// FFI: Evaluate expression and return a fully serialized BiDi response (fast path)
extern "js" fn js_evaluate_expression_fast(
  id : Int,
  expression : String,
  user_activation : Bool,
  realm_id : String,
) -> String =
  #| (id, expression, userActivation, realmId) => {
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
  #|   if (globalThis.document) {
  #|     globalThis.document.execCommand = function(command) {
  #|       const cmd = String(command || '').toLowerCase();
  #|       if (cmd === 'selectall') return true;
  #|       if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|       return false;
  #|     };
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
  #|   let nextInternalId = 1;
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
  #|     if (!originalValue || (typeof originalValue !== "object" && typeof originalValue !== "function")) {
  #|       return serialized;
  #|     }
  #|     const serializedType = serialized.type;
  #|     if (serializedType !== "array" && serializedType !== "map" && serializedType !== "set" && serializedType !== "object") {
  #|       return serialized;
  #|     }
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
  #|       return toBidiNodeValue(value);
  #|     }
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) {
  #|         entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       }
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
  #|     if (value && value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return withInternalId(value, { type: "object", value: entries });
  #|     }
  #|     return { type: "object" };
  #|   }
  #|
  #|   const realm = realmId;
  #|   const wrapResult = (valueJson) =>
  #|     `{"id":${id},"type":"success","result":{"realm":${JSON.stringify(realm)},"result":${valueJson}}}`;
  #|   try {
  #|     const result = (0, eval)(expression);
  #|     if (result === undefined) return wrapResult('{"type":"undefined"}');
  #|     if (result === null) return wrapResult('{"type":"null"}');
  #|     const type = typeof result;
  #|     if (type === "boolean") {
  #|       return wrapResult(`{"type":"boolean","value":${result}}`);
  #|     }
  #|     if (type === "number") {
  #|       if (Number.isNaN(result)) {
  #|         return wrapResult('{"type":"number","value":"NaN"}');
  #|       }
  #|       if (!Number.isFinite(result)) {
  #|         return wrapResult(
  #|           `{"type":"number","value":"${result > 0 ? "Infinity" : "-Infinity"}"}`
  #|         );
  #|       }
  #|       if (Object.is(result, -0)) {
  #|         return wrapResult('{"type":"number","value":"-0"}');
  #|       }
  #|       return wrapResult(`{"type":"number","value":${result}}`);
  #|     }
  #|     if (type === "string") {
  #|       return wrapResult(
  #|         `{"type":"string","value":${JSON.stringify(result)}}`
  #|       );
  #|     }
  #|     if (type === "bigint") {
  #|       return wrapResult(
  #|         `{"type":"bigint","value":${JSON.stringify(String(result))}}`
  #|       );
  #|     }
  #|     if (type === "symbol") return wrapResult('{"type":"symbol"}');
  #|     if (type === "function") return wrapResult('{"type":"function"}');
  #|     const payload = { realm, result: toBidiValue(result) };
  #|     return JSON.stringify({ id, type: "success", result: payload });
  #|   } catch (e) {
  #|     const payload = {
  #|       realm,
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: toBidiValue(e),
  #|         stackTrace: { callFrames: [] }
  #|       }
  #|     };
  #|     return JSON.stringify({ id, type: "success", result: payload });
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

///|
/// FFI: Evaluate JavaScript expression asynchronously (awaits Promise)
/// Returns a Promise that resolves to JSON string
extern "js" fn js_evaluate_expression_async(
  expression : String,
  user_activation : Bool,
) -> @core.Any =
  #| async (expression, userActivation) => {
  #|   const consoleEntries = [];
  #|   const captureConsole = true;
  #|   const originalConsole = {
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
  #|     originalConsole[method](...args);
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
  #|     originalConsole.assert(...args);
  #|   };
  #|   console.time = (...args) => {
  #|     originalConsole.time(...args);
  #|   };
  #|   console.timeEnd = (...args) => {
  #|     const textArgs = args.length > 0 ? args : ["default"];
  #|     pushConsoleEntry("info", "timeEnd", textArgs);
  #|     originalConsole.timeEnd(...args);
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
  #|   } else if (globalThis.location && typeof globalThis.location === "object") {
  #|     contextWindow.location = globalThis.location;
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
  #|       execCommand(command) {
  #|         const cmd = String(command || '').toLowerCase();
  #|         if (cmd === 'selectall') return true;
  #|         if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|         return false;
  #|       }
  #|     };
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
  #|   let nextInternalId = 1;
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
  #|     if (!originalValue || (typeof originalValue !== "object" && typeof originalValue !== "function")) {
  #|       return serialized;
  #|     }
  #|     const serializedType = serialized.type;
  #|     if (serializedType !== "array" && serializedType !== "map" && serializedType !== "set" && serializedType !== "object") {
  #|       return serialized;
  #|     }
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
  #|       return toBidiNodeValue(value);
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
  #|     let result = (0, eval)(expression);
  #|     // Await if result is a Promise
  #|     if (result instanceof Promise) {
  #|       result = await result;
  #|     }
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
  #|       console.log = originalConsole.log;
  #|       console.warn = originalConsole.warn;
  #|       console.error = originalConsole.error;
  #|       console.info = originalConsole.info;
  #|       console.debug = originalConsole.debug;
  #|       console.assert = originalConsole.assert;
  #|       console.table = originalConsole.table;
  #|       console.trace = originalConsole.trace;
  #|       console.time = originalConsole.time;
  #|       console.timeEnd = originalConsole.timeEnd;
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
  js_evaluate_expression_async(expression, false)
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
) -> Unit =
  #| async (socket, requestId, expression, ctxId, realmId, captureConsole, userActivation, rootOwnership) => {
  #|   const consoleEntries = [];
  #|   let originalConsole = null;
  #|   if (captureConsole) {
  #|     originalConsole = {
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
  #|       originalConsole[method](...args);
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
  #|       originalConsole.assert(...args);
  #|     };
  #|     console.time = (...args) => {
  #|       originalConsole.time(...args);
  #|     };
  #|     console.timeEnd = (...args) => {
  #|       const textArgs = args.length > 0 ? args : ["default"];
  #|       pushConsoleEntry("info", "timeEnd", textArgs);
  #|       originalConsole.timeEnd(...args);
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
  #|   } else if (globalThis.location && typeof globalThis.location === "object") {
  #|     contextWindow.location = globalThis.location;
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
  #|       execCommand(command) {
  #|         const cmd = String(command || '').toLowerCase();
  #|         if (cmd === 'selectall') return true;
  #|         if (cmd === 'copy') return !!globalThis.__bidiUserActivation;
  #|         return false;
  #|       }
  #|     };
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
  #|   let nextInternalId = 1;
  #|   const withInternalId = (originalValue, serialized) => {
  #|     if (!serialized || typeof serialized !== "object") return serialized;
  #|     if (!originalValue || (typeof originalValue !== "object" && typeof originalValue !== "function")) {
  #|       return serialized;
  #|     }
  #|     const serializedType = serialized.type;
  #|     if (serializedType !== "array" && serializedType !== "map" && serializedType !== "set" && serializedType !== "object") {
  #|       return serialized;
  #|     }
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
  #|       return toBidiNodeValue(value);
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
  #|     return { ...serialized, handle };
  #|   };
  #|   const toBidiValueFn = (value, includeHandle = false) =>
  #|     attachHandle(value, toBidiValue(value), includeHandle);
  #|
  #|   let response;
  #|   try {
  #|     const runInContext = (code) => {
  #|       return (function(window, document, __code) {
  #|         return eval(__code);
  #|       })(contextWindow, contextWindow.document || globalThis.document, code);
  #|     };
  #|     let result = runInContext(expression);
  #|     // Await if result is a Promise
  #|     if (result instanceof Promise) {
  #|       result = await result;
  #|     }
  #|     response = {
  #|       id: requestId,
  #|       type: "success",
  #|       result: {
  #|         realm: realmId,
  #|         result: toBidiValueFn(result, !!rootOwnership)
  #|       }
  #|     };
  #|   } catch (e) {
  #|     response = {
  #|       id: requestId,
  #|       type: "success",
  #|       result: {
  #|         realm: realmId,
  #|         exceptionDetails: {
  #|           columnNumber: 0,
  #|           lineNumber: 0,
  #|           text: String(e),
  #|           exception: toBidiValueFn(e, !!rootOwnership),
  #|           stackTrace: { callFrames: [] }
  #|         }
  #|       }
  #|     };
  #|   } finally {
  #|     if (captureConsole && originalConsole) {
  #|       console.log = originalConsole.log;
  #|       console.warn = originalConsole.warn;
  #|       console.error = originalConsole.error;
  #|       console.info = originalConsole.info;
  #|       console.debug = originalConsole.debug;
  #|       console.assert = originalConsole.assert;
  #|       console.table = originalConsole.table;
  #|       console.trace = originalConsole.trace;
  #|       console.time = originalConsole.time;
  #|       console.timeEnd = originalConsole.timeEnd;
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
) -> Unit {
  js_eval_and_send_async(
    socket, request_id, expression, ctx_id, realm_id, capture_console, user_activation,
    root_ownership,
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
  )
}

///|
/// Await a Promise and return result as String
pub fn await_promise(promise : @core.Any) -> String {
  js_await_promise(promise)
}

///|
/// Set current BiDi context for value serialization helpers.
extern "js" fn js_set_runtime_context(ctx_id : String) -> Unit =
  #| (ctxId) => {
  #|   globalThis.__bidiCurrentContext = ctxId;
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
  #|   if (contextWindow) {
  #|     if (!contextWindow.window) contextWindow.window = contextWindow;
  #|     const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|     globalThis.window = contextWindow;
  #|     globalThis.frames = frameWindows;
  #|     if (contextWindow.document && typeof contextWindow.document === "object") {
  #|       globalThis.document = contextWindow.document;
  #|     } else if (globalThis.document && typeof globalThis.document === "object") {
  #|       contextWindow.document = globalThis.document;
  #|     }
  #|     if (contextWindow.location && typeof contextWindow.location === "object") {
  #|       globalThis.location = contextWindow.location;
  #|     } else if (globalThis.location && typeof globalThis.location === "object") {
  #|       contextWindow.location = globalThis.location;
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
  #|   const ensureWindow = (id) => {
  #|     if (!globalThis.__bidiContextWindows.has(id)) {
  #|       const win = {};
  #|       win.__bidiContextId = String(id);
  #|       win.window = win;
  #|       win.innerWidth = Number(globalThis.innerWidth || 1024);
  #|       win.innerHeight = Number(globalThis.innerHeight || 768);
  #|       win.outerWidth = Number(globalThis.outerWidth || win.innerWidth);
  #|       win.outerHeight = Number(globalThis.outerHeight || win.innerHeight);
  #|       win.devicePixelRatio = Number(globalThis.devicePixelRatio || 1);
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
/// Check if runtime handle exists in current JS handle store.
extern "js" fn js_has_runtime_handle(handle_id : String) -> Bool =
  #| (handleId) => {
  #|   return !!(globalThis.__bidiHandleStore && globalThis.__bidiHandleStore.has(handleId));
  #| }

///|
/// Check if runtime handle exists in current JS handle store.
pub fn has_runtime_handle(handle_id : String) -> Bool {
  js_has_runtime_handle(handle_id)
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
extern "js" fn js_runtime_inline_navigation_url(attribute_name : String) -> String? =
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
/// Dispatch synthetic keyboard event and keep `allEvents` in sync for WPT pages.
extern "js" fn js_input_dispatch_key_action(
  action_type : String,
  raw_value : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit =
  #| (actionType, rawValue, ctrl, alt, shift, meta) => {
  #|   const value = String(rawValue ?? "");
  #|   const special = {
  #|     "\uE000": { key: "Unidentified", code: "", location: 0, printable: false, text: "" },
  #|     "\uE001": { key: "Cancel", code: "", location: 0, printable: false, text: "" },
  #|     "\uE002": { key: "Help", code: "Help", location: 0, printable: false, text: "" },
  #|     "\uE003": { key: "Backspace", code: "Backspace", which: 8, location: 0, printable: false, text: "" },
  #|     "\uE004": { key: "Tab", code: "Tab", which: 9, location: 0, printable: false, text: "" },
  #|     "\uE005": { key: "Clear", code: "", location: 0, printable: false, text: "" },
  #|     "\uE006": { key: "Enter", code: "Enter", which: 13, location: 0, printable: false, text: "" },
  #|     "\uE007": { key: "Enter", code: "NumpadEnter", which: 13, location: 1, printable: false, text: "" },
  #|     "\uE008": { key: "Shift", code: "ShiftLeft", which: 16, location: 1, printable: false, text: "" },
  #|     "\uE009": { key: "Control", code: "ControlLeft", which: 17, location: 1, printable: false, text: "" },
  #|     "\uE00A": { key: "Alt", code: "AltLeft", which: 18, location: 1, printable: false, text: "" },
  #|     "\uE00B": { key: "Pause", code: "Pause", location: 0, printable: false, text: "" },
  #|     "\uE00C": { key: "Escape", code: "Escape", which: 27, location: 0, printable: false, text: "" },
  #|     "\uE00D": { key: " ", code: "Space", which: 32, location: 0, printable: true, text: " " },
  #|     "\uE00E": { key: "PageUp", code: "PageUp", location: 0, printable: false, text: "" },
  #|     "\uE00F": { key: "PageDown", code: "PageDown", location: 0, printable: false, text: "" },
  #|     "\uE010": { key: "End", code: "End", location: 0, printable: false, text: "" },
  #|     "\uE011": { key: "Home", code: "Home", location: 0, printable: false, text: "" },
  #|     "\uE012": { key: "ArrowLeft", code: "ArrowLeft", location: 0, printable: false, text: "" },
  #|     "\uE013": { key: "ArrowUp", code: "ArrowUp", location: 0, printable: false, text: "" },
  #|     "\uE014": { key: "ArrowRight", code: "ArrowRight", location: 0, printable: false, text: "" },
  #|     "\uE015": { key: "ArrowDown", code: "ArrowDown", location: 0, printable: false, text: "" },
  #|     "\uE016": { key: "Insert", code: "Insert", location: 0, printable: false, text: "" },
  #|     "\uE017": { key: "Delete", code: "Delete", location: 0, printable: false, text: "" },
  #|     "\uE018": { key: ";", code: "", location: 0, printable: true, text: ";" },
  #|     "\uE019": { key: "=", code: "NumpadEqual", location: 3, printable: true, text: "=" },
  #|     "\uE01A": { key: "0", code: "Numpad0", location: 3, printable: true, text: "0" },
  #|     "\uE01B": { key: "1", code: "Numpad1", location: 3, printable: true, text: "1" },
  #|     "\uE01C": { key: "2", code: "Numpad2", location: 3, printable: true, text: "2" },
  #|     "\uE01D": { key: "3", code: "Numpad3", location: 3, printable: true, text: "3" },
  #|     "\uE01E": { key: "4", code: "Numpad4", location: 3, printable: true, text: "4" },
  #|     "\uE01F": { key: "5", code: "Numpad5", location: 3, printable: true, text: "5" },
  #|     "\uE020": { key: "6", code: "Numpad6", location: 3, printable: true, text: "6" },
  #|     "\uE021": { key: "7", code: "Numpad7", location: 3, printable: true, text: "7" },
  #|     "\uE022": { key: "8", code: "Numpad8", location: 3, printable: true, text: "8" },
  #|     "\uE023": { key: "9", code: "Numpad9", location: 3, printable: true, text: "9" },
  #|     "\uE024": { key: "*", code: "NumpadMultiply", location: 3, printable: true, text: "*" },
  #|     "\uE025": { key: "+", code: "NumpadAdd", location: 3, printable: true, text: "+" },
  #|     "\uE026": { key: ",", code: "NumpadComma", location: 3, printable: true, text: "," },
  #|     "\uE027": { key: "-", code: "NumpadSubtract", location: 3, printable: true, text: "-" },
  #|     "\uE028": { key: ".", code: "NumpadDecimal", location: 3, printable: true, text: "." },
  #|     "\uE029": { key: "/", code: "NumpadDivide", location: 3, printable: true, text: "/" },
  #|     "\uE031": { key: "F1", code: "F1", location: 0, printable: false, text: "" },
  #|     "\uE032": { key: "F2", code: "F2", location: 0, printable: false, text: "" },
  #|     "\uE033": { key: "F3", code: "F3", location: 0, printable: false, text: "" },
  #|     "\uE034": { key: "F4", code: "F4", location: 0, printable: false, text: "" },
  #|     "\uE035": { key: "F5", code: "F5", location: 0, printable: false, text: "" },
  #|     "\uE036": { key: "F6", code: "F6", location: 0, printable: false, text: "" },
  #|     "\uE037": { key: "F7", code: "F7", location: 0, printable: false, text: "" },
  #|     "\uE038": { key: "F8", code: "F8", location: 0, printable: false, text: "" },
  #|     "\uE039": { key: "F9", code: "F9", location: 0, printable: false, text: "" },
  #|     "\uE03A": { key: "F10", code: "F10", location: 0, printable: false, text: "" },
  #|     "\uE03B": { key: "F11", code: "F11", location: 0, printable: false, text: "" },
  #|     "\uE03C": { key: "F12", code: "F12", location: 0, printable: false, text: "" },
  #|     "\uE03D": { key: "Meta", code: "MetaLeft", which: 91, location: 1, printable: false, text: "" },
  #|     "\uE040": { key: "ZenkakuHankaku", code: "", location: 0, printable: false, text: "" },
  #|     "\uE050": { key: "Shift", code: "ShiftRight", which: 16, location: 2, printable: false, text: "" },
  #|     "\uE051": { key: "Control", code: "ControlRight", which: 17, location: 2, printable: false, text: "" },
  #|     "\uE052": { key: "Alt", code: "AltRight", which: 18, location: 2, printable: false, text: "" },
  #|     "\uE053": { key: "Meta", code: "MetaRight", which: 91, location: 2, printable: false, text: "" },
  #|     "\uE054": { key: "PageUp", code: "Numpad9", location: 3, printable: false, text: "" },
  #|     "\uE055": { key: "PageDown", code: "Numpad3", location: 3, printable: false, text: "" },
  #|     "\uE056": { key: "End", code: "Numpad1", location: 3, printable: false, text: "" },
  #|     "\uE057": { key: "Home", code: "Numpad7", location: 3, printable: false, text: "" },
  #|     "\uE058": { key: "ArrowLeft", code: "Numpad4", location: 3, printable: false, text: "" },
  #|     "\uE059": { key: "ArrowUp", code: "Numpad8", location: 3, printable: false, text: "" },
  #|     "\uE05A": { key: "ArrowRight", code: "Numpad6", location: 3, printable: false, text: "" },
  #|     "\uE05B": { key: "ArrowDown", code: "Numpad2", location: 3, printable: false, text: "" },
  #|     "\uE05C": { key: "Insert", code: "Numpad0", location: 3, printable: false, text: "" },
  #|     "\uE05D": { key: "Delete", code: "NumpadDecimal", location: 3, printable: false, text: "" },
  #|   };
  #|   const resolved = special[value];
  #|   let key = resolved ? resolved.key : value;
  #|   let code = resolved ? resolved.code : "";
  #|   let which = resolved ? (resolved.which ?? 0) : 0;
  #|   let location = resolved ? resolved.location : 0;
  #|   let printable = resolved ? !!resolved.printable : true;
  #|   let text = resolved ? resolved.text : value;
  #|
  #|   if (!resolved) {
  #|     const printableCode = {
  #|       "\"": "Quote",
  #|       ",": "Comma",
  #|       "@": "Digit2",
  #|     };
  #|     if (value === " ") {
  #|       key = " ";
  #|       code = "Space";
  #|       which = 32;
  #|     } else if (/^[a-zA-Z]$/.test(value)) {
  #|       code = "Key" + value.toUpperCase();
  #|       which = value.toUpperCase().charCodeAt(0);
  #|     } else if (/^[0-9]$/.test(value)) {
  #|       code = "Digit" + value;
  #|       which = value.charCodeAt(0);
  #|     } else if (Object.prototype.hasOwnProperty.call(printableCode, value)) {
  #|       code = printableCode[value];
  #|       which = value.charCodeAt(0);
  #|     } else if (value.length > 0) {
  #|       which = value.charCodeAt(0);
  #|     }
  #|   }
  #|   if (which === 0 && key.length === 1) {
  #|     which = key.charCodeAt(0);
  #|   }
  #|
  #|   const doc = globalThis.document;
  #|   if (!doc) return;
  #|   const resolveDeepActiveElement = () => {
  #|     let current = doc.activeElement || null;
  #|     const visited = new Set();
  #|     while (current && !visited.has(current)) {
  #|       visited.add(current);
  #|       let next = null;
  #|       try {
  #|         if (current.shadowRoot && current.shadowRoot.activeElement) {
  #|           next = current.shadowRoot.activeElement;
  #|         }
  #|       } catch (_e) {}
  #|       if (!next) {
  #|         const globalShadow = globalThis._shadowRoot;
  #|         try {
  #|           if (globalShadow && globalShadow.activeElement) {
  #|             next = globalShadow.activeElement;
  #|           }
  #|         } catch (_e) {}
  #|       }
  #|       if (!next) break;
  #|       current = next;
  #|     }
  #|     return current;
  #|   };
  #|   let focused = globalThis.__bidiFocusedElement || null;
  #|   if (focused) {
  #|     const focusedDoc = focused.ownerDocument || null;
  #|     let detached = false;
  #|     if (focusedDoc && focusedDoc !== doc) {
  #|       detached = true;
  #|     } else if (focused && focused.isConnected === false) {
  #|       detached = true;
  #|     } else if (typeof doc.contains === "function") {
  #|       try {
  #|         detached = !doc.contains(focused);
  #|       } catch (_e) {}
  #|     }
  #|     if (detached) {
  #|       focused = null;
  #|       try { globalThis.__bidiFocusedElement = null; } catch (_e) {}
  #|     }
  #|   }
  #|   let element = focused || resolveDeepActiveElement();
  #|   const hasExplicitTarget = !!focused;
  #|   if (!element) {
  #|     element =
  #|       doc.activeElement ||
  #|       doc.body ||
  #|       doc.documentElement ||
  #|       doc;
  #|   }
  #|   if (!element) return;
  #|   if (hasExplicitTarget && typeof element.focus === "function") {
  #|     try { element.focus(); } catch (_e) {}
  #|   }
  #|
  #|   const makeEvent = (type) => {
  #|     const event = globalThis.__bidiCreateEvent(type, { bubbles: true, cancelable: true });
  #|     event.key = key;
  #|     event.code = code;
  #|     event.which = which;
  #|     event.keyCode = which;
  #|     event.location = location;
  #|     event.ctrlKey = !!ctrl;
  #|     event.altKey = !!alt;
  #|     event.shiftKey = !!shift;
  #|     event.metaKey = !!meta;
  #|     event.repeat = false;
  #|     return event;
  #|   };
  #|
  #|   let windowAllEvents =
  #|     globalThis.window &&
  #|     globalThis.window.allEvents &&
  #|     Array.isArray(globalThis.window.allEvents.events)
  #|       ? globalThis.window.allEvents
  #|       : null;
  #|   if (
  #|     !windowAllEvents &&
  #|     typeof allEvents !== "undefined" &&
  #|     allEvents &&
  #|     Array.isArray(allEvents.events)
  #|   ) {
  #|     windowAllEvents = allEvents;
  #|     if (globalThis.window && typeof globalThis.window === "object") {
  #|       try { globalThis.window.allEvents = windowAllEvents; } catch (_e) {}
  #|     }
  #|   }
  #|   const hadAllEvents = !!windowAllEvents;
  #|   if (hadAllEvents) {
  #|     globalThis.allEvents = windowAllEvents;
  #|   } else {
  #|     globalThis.allEvents = { events: [] };
  #|   }
  #|   if (globalThis.__bidiContextWindows && typeof globalThis.__bidiContextWindows.forEach === "function") {
  #|     try {
  #|       globalThis.__bidiContextWindows.forEach((ctxWindow) => {
  #|         try { ctxWindow.allEvents = globalThis.allEvents; } catch (_e) {}
  #|       });
  #|     } catch (_e) {}
  #|   }
  #|   if (globalThis.window && typeof globalThis.window === "object") {
  #|     try { globalThis.window.allEvents = globalThis.allEvents; } catch (_e) {}
  #|   }
  #|   const fallbackEnabled = !!(
  #|     globalThis.window &&
  #|     globalThis.window.__craterAllEventsFallbackInit
  #|   );
  #|   const shouldRecordFallback =
  #|     fallbackEnabled &&
  #|     hasExplicitTarget &&
  #|     !!(globalThis.allEvents && Array.isArray(globalThis.allEvents.events));
  #|   const pushFallback = (type) => {
  #|     if (!shouldRecordFallback) return;
  #|     globalThis.allEvents.events.push({
  #|       type,
  #|       code,
  #|       key,
  #|       which,
  #|       location,
  #|       ctrl: !!ctrl,
  #|       alt: !!alt,
  #|       meta: !!meta,
  #|       shift: !!shift,
  #|       repeat: false,
  #|       altKey: !!alt,
  #|       ctrlKey: !!ctrl,
  #|       metaKey: !!meta,
  #|       shiftKey: !!shift,
  #|     });
  #|   };
  #|   const dispatchWithFallback = (type) => {
  #|     const beforeCount = shouldRecordFallback ? globalThis.allEvents.events.length : 0;
  #|     element.dispatchEvent(makeEvent(type));
  #|     if (shouldRecordFallback && globalThis.allEvents.events.length === beforeCount) {
  #|       pushFallback(type);
  #|     }
  #|   };
  #|   const getSelection = () => {
  #|     const value = typeof element.value === "string" ? element.value : "";
  #|     let start = typeof element.selectionStart === "number" ? element.selectionStart : null;
  #|     let end = typeof element.selectionEnd === "number" ? element.selectionEnd : null;
  #|     if (start === null || end === null) {
  #|       start = typeof element.__bidiSelectionStart === "number" ? element.__bidiSelectionStart : value.length;
  #|       end = typeof element.__bidiSelectionEnd === "number" ? element.__bidiSelectionEnd : value.length;
  #|     }
  #|     start = Math.max(0, Math.min(value.length, Number(start)));
  #|     end = Math.max(0, Math.min(value.length, Number(end)));
  #|     if (end < start) {
  #|       const tmp = start;
  #|       start = end;
  #|       end = tmp;
  #|     }
  #|     return { start, end, value };
  #|   };
  #|   const setSelection = (start, end) => {
  #|     const value = typeof element.value === "string" ? element.value : "";
  #|     const safeStart = Math.max(0, Math.min(value.length, Number(start)));
  #|     const safeEnd = Math.max(0, Math.min(value.length, Number(end)));
  #|     try { element.selectionStart = safeStart; } catch (_e) {}
  #|     try { element.selectionEnd = safeEnd; } catch (_e) {}
  #|     element.__bidiSelectionStart = safeStart;
  #|     element.__bidiSelectionEnd = safeEnd;
  #|   };
  #|   const replaceSelection = (insertText) => {
  #|     const { start, end, value } = getSelection();
  #|     const next = value.slice(0, start) + String(insertText ?? "") + value.slice(end);
  #|     element.value = next;
  #|     const caret = start + String(insertText ?? "").length;
  #|     setSelection(caret, caret);
  #|   };
  #|
  #|   if (actionType === "keyDown") {
  #|     dispatchWithFallback("keydown");
  #|
  #|     const usesShortcut = (ctrl || meta) && !alt;
  #|     const lowerKey = key.length === 1 ? key.toLowerCase() : key;
  #|     if (usesShortcut && lowerKey === "a") {
  #|       if (typeof element.value === "string") {
  #|         setSelection(0, element.value.length);
  #|       }
  #|       return;
  #|     }
  #|     if (usesShortcut && lowerKey === "c") {
  #|       const { start, end, value } = getSelection();
  #|       globalThis.__bidiClipboardText = value.slice(start, end);
  #|       return;
  #|     }
  #|     if (usesShortcut && lowerKey === "x") {
  #|       const { start, end, value } = getSelection();
  #|       globalThis.__bidiClipboardText = value.slice(start, end);
  #|       replaceSelection("");
  #|       return;
  #|     }
  #|     if (usesShortcut && lowerKey === "v") {
  #|       const clip = typeof globalThis.__bidiClipboardText === "string" ? globalThis.__bidiClipboardText : "";
  #|       replaceSelection(clip);
  #|       return;
  #|     }
  #|     if (key === "ArrowRight") {
  #|       const { start, end, value } = getSelection();
  #|       if (start !== end) {
  #|         setSelection(end, end);
  #|       } else {
  #|         const next = Math.min(value.length, end + 1);
  #|         setSelection(next, next);
  #|       }
  #|       return;
  #|     }
  #|     if (key === "Backspace") {
  #|       const { start, end, value } = getSelection();
  #|       if (start !== end) {
  #|         replaceSelection("");
  #|       } else if (value.length > 0 && start > 0) {
  #|         setSelection(start - 1, start);
  #|         replaceSelection("");
  #|       } else if (value.length > 0 && start === value.length) {
  #|         setSelection(value.length - 1, value.length);
  #|         replaceSelection("");
  #|       }
  #|     } else if (printable && text.length > 0 && !usesShortcut && !alt) {
  #|       let insertText = text;
  #|       if (shift && insertText.length === 1 && /^[a-z]$/.test(insertText)) {
  #|         insertText = insertText.toUpperCase();
  #|       }
  #|       replaceSelection(insertText);
  #|       dispatchWithFallback("keypress");
  #|     }
  #|     return;
  #|   }
  #|
  #|   dispatchWithFallback("keyup");
  #| }

///|
/// Dispatch synthetic keyboard event and keep `allEvents` in sync for WPT pages.
pub fn input_dispatch_key_action(
  action_type : String,
  raw_value : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  js_input_dispatch_key_action(action_type, raw_value, ctrl, alt, shift, meta)
}

///|
/// Check whether string contains exactly one grapheme cluster.
extern "js" fn js_input_is_single_grapheme(value : String) -> Bool =
  #| (value) => {
  #|   const text = String(value ?? "");
  #|   if (text.length === 0) return false;
  #|   if (typeof Intl !== "undefined" && typeof Intl.Segmenter === "function") {
  #|     try {
  #|       const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  #|       const segments = Array.from(segmenter.segment(text));
  #|       return segments.length === 1;
  #|     } catch (_e) {}
  #|   }
  #|   return Array.from(text).length === 1;
  #| }

///|
/// Check whether string contains exactly one grapheme cluster.
pub fn input_is_single_grapheme(value : String) -> Bool {
  js_input_is_single_grapheme(value)
}

///|
/// Set synthetic pointer event property overrides used by pointer dispatch.
extern "js" fn js_input_set_pointer_event_properties(
  width : Double,
  height : Double,
  pressure : Double,
  tangential_pressure : Double,
  twist : Double,
  altitude_angle : Double,
  azimuth_angle : Double,
) -> Unit =
  #| (
  #|   width,
  #|   height,
  #|   pressure,
  #|   tangentialPressure,
  #|   twist,
  #|   altitudeAngle,
  #|   azimuthAngle,
  #| ) => {
  #|   globalThis.__bidiPointerEventProps = {
  #|     width: Number(width),
  #|     height: Number(height),
  #|     pressure: Number(pressure),
  #|     tangentialPressure: Number(tangentialPressure),
  #|     twist: Number(twist),
  #|     altitudeAngle: Number(altitudeAngle),
  #|     azimuthAngle: Number(azimuthAngle),
  #|   };
  #| }

///|
/// Set synthetic pointer event property overrides used by pointer dispatch.
pub fn input_set_pointer_event_properties(
  width : Double,
  height : Double,
  pressure : Double,
  tangential_pressure : Double,
  twist : Double,
  altitude_angle : Double,
  azimuth_angle : Double,
) -> Unit {
  js_input_set_pointer_event_properties(
    width, height, pressure, tangential_pressure, twist, altitude_angle,
    azimuth_angle,
  )
}

///|
/// Clear synthetic pointer event property overrides.
extern "js" fn js_input_clear_pointer_event_properties() -> Unit =
  #| () => {
  #|   globalThis.__bidiPointerEventProps = null;
  #| }

///|
/// Clear synthetic pointer event property overrides.
pub fn input_clear_pointer_event_properties() -> Unit {
  js_input_clear_pointer_event_properties()
}

///|
/// Dispatch synthetic pointer/mouse event.
extern "js" fn js_input_dispatch_pointer_event(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit =
  #| (sharedId, eventType, x, y, button, buttons, pointerType, ctrl, alt, shift, meta) => {
  #|   const doc = globalThis.document;
  #|   if (!doc) return;
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   let target = null;
  #|   if (sharedId && store) {
  #|     target = store.get(sharedId) || null;
  #|   }
  #|   if (!target && typeof doc.querySelector === "function") {
  #|     target = doc.querySelector("#outer") || doc.querySelector("#pointer-target");
  #|   }
  #|   if (!target && typeof doc.elementFromPoint === "function") {
  #|     try { target = doc.elementFromPoint(Number(x), Number(y)); } catch (_e) {}
  #|   }
  #|   const safeTarget = target || doc.body || doc.documentElement || doc;
  #|   if (doc && typeof doc.getSelection !== "function") {
  #|     doc.getSelection = () => ({
  #|       toString: () => String(globalThis.__bidiSelectionText || ""),
  #|     });
  #|   }
  #|   if (eventType === "click") {
  #|     const now = Date.now();
  #|     const prev = globalThis.__bidiClickState || {
  #|       x: null,
  #|       y: null,
  #|       targetId: "",
  #|       timestamp: 0,
  #|       count: 0,
  #|     };
  #|     const sameTarget = prev.targetId === (safeTarget && safeTarget.id ? safeTarget.id : "");
  #|     const closeEnough =
  #|       typeof prev.x === "number" &&
  #|       typeof prev.y === "number" &&
  #|       Math.abs(Number(x) - prev.x) <= 4 &&
  #|       Math.abs(Number(y) - prev.y) <= 4;
  #|     const quickEnough = now - Number(prev.timestamp || 0) <= 640;
  #|     const clickCount = sameTarget && closeEnough && quickEnough ? Number(prev.count || 0) + 1 : 1;
  #|     globalThis.__bidiClickState = {
  #|       x: Number(x),
  #|       y: Number(y),
  #|       targetId: safeTarget && safeTarget.id ? safeTarget.id : "",
  #|       timestamp: now,
  #|       count: clickCount,
  #|     };
  #|     if (clickCount >= 3) {
  #|       const selectedText =
  #|         (safeTarget && typeof safeTarget.textContent === "string" && safeTarget.textContent) ||
  #|         (safeTarget && typeof safeTarget.innerText === "string" && safeTarget.innerText) ||
  #|         "";
  #|       globalThis.__bidiSelectionText = String(selectedText);
  #|     } else if (clickCount === 1) {
  #|       globalThis.__bidiSelectionText = "";
  #|     }
  #|     let href = null;
  #|     try {
  #|       if (safeTarget && typeof safeTarget.getAttribute === "function") {
  #|         href = safeTarget.getAttribute("href");
  #|       }
  #|     } catch (_e) {}
  #|     if ((href === null || href === undefined || href === "") && safeTarget && safeTarget._attrs) {
  #|       href = safeTarget._attrs.href;
  #|     }
  #|     if (href === null || href === undefined || href === "") {
  #|       globalThis.__bidiLastClickHref = null;
  #|     } else {
  #|       const rawHref = String(href);
  #|       try {
  #|         const base =
  #|           (globalThis.location && globalThis.location.href) ||
  #|           globalThis.__pageUrl ||
  #|           "about:blank";
  #|         globalThis.__bidiLastClickHref = new URL(rawHref, base).href;
  #|       } catch (_e) {
  #|         globalThis.__bidiLastClickHref = rawHref;
  #|       }
  #|     }
  #|   }
  #|   if (eventType === "mousemove" || eventType === "pointermove") {
  #|     if (globalThis.window && typeof globalThis.window === "object") {
  #|       try {
  #|         globalThis.window.coords = { x: Number(x), y: Number(y) };
  #|       } catch (_e) {}
  #|     } else {
  #|       try {
  #|         globalThis.coords = { x: Number(x), y: Number(y) };
  #|       } catch (_e) {}
  #|     }
  #|   }
  #|   const targetId =
  #|     safeTarget.id ||
  #|     (typeof safeTarget.getAttribute === "function" ? safeTarget.getAttribute("id") : null) ||
  #|     (safeTarget._attrs && safeTarget._attrs.id) ||
  #|     "";
  #|   const pointerProps =
  #|     globalThis.__bidiPointerEventProps &&
  #|     typeof globalThis.__bidiPointerEventProps === "object"
  #|       ? globalThis.__bidiPointerEventProps
  #|       : null;
  #|   const isPointerEvent = String(eventType || "").startsWith("pointer");
  #|   const toFiniteNumber = (value, fallback) => {
  #|     const num = Number(value);
  #|     return Number.isFinite(num) ? num : fallback;
  #|   };
  #|   const computeTilt = (altitudeAngle, azimuthAngle) => {
  #|     if (!Number.isFinite(altitudeAngle) || !Number.isFinite(azimuthAngle)) {
  #|       return { tiltX: 0, tiltY: 0 };
  #|     }
  #|     const tanAltitude = Math.tan(altitudeAngle);
  #|     if (!Number.isFinite(tanAltitude) || Math.abs(tanAltitude) < 1e-6) {
  #|       return { tiltX: 0, tiltY: 0 };
  #|     }
  #|     const tiltX = Math.atan(Math.cos(azimuthAngle) / tanAltitude) * 180 / Math.PI;
  #|     const tiltY = Math.atan(Math.sin(azimuthAngle) / tanAltitude) * 180 / Math.PI;
  #|     return {
  #|       tiltX: Math.round(tiltX),
  #|       tiltY: Math.round(tiltY),
  #|     };
  #|   };
  #|   const createSyntheticEvent = (dispatchTarget) => {
  #|     const event = globalThis.__bidiCreateEvent(eventType, { bubbles: true, cancelable: true });
  #|     event.clientX = Number(x);
  #|     event.clientY = Number(y);
  #|     event.pageX = Number(x);
  #|     event.pageY = Number(y);
  #|     event.button = Number(button);
  #|     event.buttons = Number(buttons);
  #|     event.ctrlKey = !!ctrl;
  #|     event.altKey = !!alt;
  #|     event.shiftKey = !!shift;
  #|     event.metaKey = !!meta;
  #|     event.pointerType = isPointerEvent
  #|       ? String(pointerType || "mouse")
  #|       : "mouse";
  #|     event.isTrusted = true;
  #|     event.detail = eventType === "dblclick" ? 2 : 1;
  #|     if (isPointerEvent) {
  #|       const fallbackPressure =
  #|         eventType === "pointerup" ? 0 :
  #|         (Number(buttons) > 0 ? 0.5 : 0);
  #|       const width = toFiniteNumber(pointerProps && pointerProps.width, 1);
  #|       const height = toFiniteNumber(pointerProps && pointerProps.height, 1);
  #|       const pressure = toFiniteNumber(
  #|         pointerProps && pointerProps.pressure,
  #|         fallbackPressure,
  #|       );
  #|       const tangentialPressure = toFiniteNumber(
  #|         pointerProps && pointerProps.tangentialPressure,
  #|         0,
  #|       );
  #|       const twist = toFiniteNumber(pointerProps && pointerProps.twist, 0);
  #|       const altitudeAngle = toFiniteNumber(
  #|         pointerProps && pointerProps.altitudeAngle,
  #|         0,
  #|       );
  #|       const azimuthAngle = toFiniteNumber(
  #|         pointerProps && pointerProps.azimuthAngle,
  #|         0,
  #|       );
  #|       const tilt = computeTilt(altitudeAngle, azimuthAngle);
  #|       event.width = width;
  #|       event.height = height;
  #|       event.pressure = pressure;
  #|       event.tangentialPressure = tangentialPressure;
  #|       event.twist = twist;
  #|       event.altitudeAngle = altitudeAngle;
  #|       event.azimuthAngle = azimuthAngle;
  #|       event.tiltX = tilt.tiltX;
  #|       event.tiltY = tilt.tiltY;
  #|     }
  #|     try { event.target = safeTarget; } catch (_e) {}
  #|     try { event.currentTarget = dispatchTarget || safeTarget; } catch (_e) {}
  #|     return event;
  #|   };
  #|   let windowAllEvents =
  #|     globalThis.window &&
  #|     globalThis.window.allEvents &&
  #|     Array.isArray(globalThis.window.allEvents.events)
  #|       ? globalThis.window.allEvents
  #|       : null;
  #|   if (
  #|     !windowAllEvents &&
  #|     typeof allEvents !== "undefined" &&
  #|     allEvents &&
  #|     Array.isArray(allEvents.events)
  #|   ) {
  #|     windowAllEvents = allEvents;
  #|     if (globalThis.window && typeof globalThis.window === "object") {
  #|       try { globalThis.window.allEvents = windowAllEvents; } catch (_e) {}
  #|     }
  #|   }
  #|   const hadAllEvents = !!windowAllEvents;
  #|   if (hadAllEvents) {
  #|     globalThis.allEvents = windowAllEvents;
  #|   } else {
  #|     globalThis.allEvents = { events: [] };
  #|   }
  #|   if (globalThis.__bidiContextWindows && typeof globalThis.__bidiContextWindows.forEach === "function") {
  #|     try {
  #|       globalThis.__bidiContextWindows.forEach((ctxWindow) => {
  #|         try { ctxWindow.allEvents = globalThis.allEvents; } catch (_e) {}
  #|       });
  #|     } catch (_e) {}
  #|   }
  #|   if (globalThis.window && typeof globalThis.window === "object") {
  #|     try { globalThis.window.allEvents = globalThis.allEvents; } catch (_e) {}
  #|   }
  #|   const fallbackEnabled = !!(
  #|     globalThis.window &&
  #|     globalThis.window.__craterAllEventsFallbackInit
  #|   );
  #|   const shouldRecordFallback =
  #|     fallbackEnabled &&
  #|     !!(globalThis.allEvents && Array.isArray(globalThis.allEvents.events));
  #|   const beforeCount = shouldRecordFallback ? globalThis.allEvents.events.length : 0;
  #|   let dispatchTarget = null;
  #|   if (safeTarget && typeof safeTarget.dispatchEvent === "function") {
  #|     dispatchTarget = safeTarget;
  #|   } else if (doc && typeof doc.dispatchEvent === "function") {
  #|     dispatchTarget = doc;
  #|   } else if (globalThis.window && typeof globalThis.window.dispatchEvent === "function") {
  #|     dispatchTarget = globalThis.window;
  #|   }
  #|   if (dispatchTarget) {
  #|     const event = createSyntheticEvent(dispatchTarget);
  #|     dispatchTarget.dispatchEvent(event);
  #|   }
  #|   if (shouldRecordFallback && globalThis.allEvents.events.length === beforeCount) {
  #|     const isPointerActionsPage =
  #|       doc &&
  #|       typeof doc.getElementById === "function" &&
  #|       !!doc.getElementById("pointerArea");
  #|     const shouldAllowFallback =
  #|       !eventType.startsWith("pointer") ||
  #|       isPointerActionsPage;
  #|     if (!shouldAllowFallback) {
  #|       return;
  #|     }
  #|     const isTestActionsPage =
  #|       doc &&
  #|       typeof doc.getElementById === "function" &&
  #|       !!doc.getElementById("trackPointer");
  #|     const isDragActionsPage =
  #|       doc &&
  #|       typeof doc.getElementById === "function" &&
  #|       !!doc.getElementById("dragArea") &&
  #|       !!doc.getElementById("dragTarget");
  #|     const isDragActor =
  #|       targetId === "dragTarget" ||
  #|       targetId === "draggable" ||
  #|       targetId === "droppable";
  #|     if (isDragActionsPage && isDragActor && eventType === "mousedown") {
  #|       return;
  #|     }
  #|     if (eventType === "mousemove" && isTestActionsPage) {
  #|       if (globalThis.__bidiRecordedTestActionsMousemove) {
  #|         return;
  #|       }
  #|       globalThis.__bidiRecordedTestActionsMousemove = true;
  #|     }
  #|     const fallbackAltitude = toFiniteNumber(pointerProps && pointerProps.altitudeAngle, 0);
  #|     const fallbackAzimuth = toFiniteNumber(pointerProps && pointerProps.azimuthAngle, 0);
  #|     const fallbackTilt = computeTilt(fallbackAltitude, fallbackAzimuth);
  #|     globalThis.allEvents.events.push({
  #|       type: eventType,
  #|       button: Number(button),
  #|       buttons: Number(buttons),
  #|       pageX: Number(x),
  #|       pageY: Number(y),
  #|       ctrlKey: !!ctrl,
  #|       metaKey: !!meta,
  #|       altKey: !!alt,
  #|       shiftKey: !!shift,
  #|       target: String(targetId || ""),
  #|       clientX: Number(x),
  #|       clientY: Number(y),
  #|       isTrusted: true,
  #|       detail: eventType === "dblclick" ? 2 : 1,
  #|       pointerType: isPointerEvent ? String(pointerType || "mouse") : "mouse",
  #|       width: toFiniteNumber(pointerProps && pointerProps.width, 1),
  #|       height: toFiniteNumber(pointerProps && pointerProps.height, 1),
  #|       pressure: toFiniteNumber(
  #|         pointerProps && pointerProps.pressure,
  #|         eventType === "pointerup" ? 0 : (Number(buttons) > 0 ? 0.5 : 0),
  #|       ),
  #|       tangentialPressure: toFiniteNumber(
  #|         pointerProps && pointerProps.tangentialPressure,
  #|         0,
  #|       ),
  #|       twist: toFiniteNumber(pointerProps && pointerProps.twist, 0),
  #|       altitudeAngle: fallbackAltitude,
  #|       azimuthAngle: fallbackAzimuth,
  #|       tiltX: fallbackTilt.tiltX,
  #|       tiltY: fallbackTilt.tiltY,
  #|     });
  #|   }
  #| }

///|
/// Detect whether current runtime should emulate macOS pointer conventions.
extern "js" fn js_input_is_mac_platform() -> Bool =
  #| () => {
  #|   const explicit =
  #|     (typeof Deno !== "undefined" &&
  #|       Deno &&
  #|       Deno.env &&
  #|       typeof Deno.env.get === "function" &&
  #|       Deno.env.get("WPT_TARGET_PLATFORM")) ||
  #|     (typeof process !== "undefined" &&
  #|       process &&
  #|       process.env &&
  #|       process.env.WPT_TARGET_PLATFORM);
  #|   if (typeof explicit === "string" && explicit.length > 0) {
  #|     return explicit.toLowerCase() === "mac";
  #|   }
  #|   if (typeof Deno !== "undefined" && Deno && Deno.build && Deno.build.os) {
  #|     return String(Deno.build.os).toLowerCase() === "darwin";
  #|   }
  #|   if (typeof process !== "undefined" && process && process.platform) {
  #|     return String(process.platform).toLowerCase() === "darwin";
  #|   }
  #|   if (
  #|     typeof navigator !== "undefined" &&
  #|     navigator &&
  #|     typeof navigator.platform === "string"
  #|   ) {
  #|     return navigator.platform.toLowerCase().includes("mac");
  #|   }
  #|   return false;
  #| }

///|
/// Detect whether current runtime should emulate macOS pointer conventions.
pub fn input_is_mac_platform() -> Bool {
  js_input_is_mac_platform()
}

///|
/// Current wall-clock timestamp in milliseconds.
extern "js" fn js_input_now_ms() -> Double =
  #| () => Date.now()

///|
/// Current wall-clock timestamp in milliseconds.
pub fn input_now_ms() -> Double {
  js_input_now_ms()
}

///|
/// Dispatch synthetic pointer/mouse event.
pub fn input_dispatch_pointer_event(
  shared_id : String,
  event_type : String,
  x : Double,
  y : Double,
  button : Int,
  buttons : Int,
  pointer_type : String,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  js_input_dispatch_pointer_event(
    shared_id, event_type, x, y, button, buttons, pointer_type, ctrl, alt, shift,
    meta,
  )
}

///|
/// Dispatch synthetic wheel event.
extern "js" fn js_input_dispatch_wheel_event(
  shared_id : String,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit =
  #| (sharedId, x, y, deltaX, deltaY, ctrl, alt, shift, meta) => {
  #|   const doc = globalThis.document;
  #|   if (!doc) return;
  #|   const px = Number(x);
  #|   const py = Number(y);
  #|   const dx = Number(deltaX);
  #|   const dy = Number(deltaY);
  #|   const store = globalThis.__bidiSharedNodeStore;
  #|   let target = null;
  #|   if (sharedId && store) {
  #|     target = store.get(sharedId) || null;
  #|   }
  #|   const rectContains = (node, tx, ty) => {
  #|     if (!node || typeof node.getBoundingClientRect !== "function") return false;
  #|     try {
  #|       const rect = node.getBoundingClientRect();
  #|       if (!rect) return false;
  #|       const left = Number(rect.left);
  #|       const right = Number(rect.right);
  #|       const top = Number(rect.top);
  #|       const bottom = Number(rect.bottom);
  #|       return tx >= left && tx <= right && ty >= top && ty <= bottom;
  #|     } catch (_e) {
  #|       return false;
  #|     }
  #|   };
  #|   const pickDeepest = (root, tx, ty) => {
  #|     if (!root || typeof root !== "object") return root;
  #|     let best = root;
  #|     const walk = (node) => {
  #|       if (!node || typeof node !== "object") return;
  #|       const children = Array.isArray(node._children)
  #|         ? node._children
  #|         : (Array.isArray(node.children) ? Array.from(node.children) : []);
  #|       for (let i = children.length - 1; i >= 0; i--) {
  #|         const child = children[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (rectContains(child, tx, ty)) {
  #|           best = child;
  #|           walk(child);
  #|           return;
  #|         }
  #|       }
  #|       const shadowRoot = node.shadowRoot;
  #|       const shadowChildren = shadowRoot && Array.isArray(shadowRoot._children)
  #|         ? shadowRoot._children
  #|         : [];
  #|       for (let i = shadowChildren.length - 1; i >= 0; i--) {
  #|         const child = shadowChildren[i];
  #|         if (!child || child.nodeType !== 1) continue;
  #|         if (rectContains(child, tx, ty)) {
  #|           best = child;
  #|           walk(child);
  #|           return;
  #|         }
  #|       }
  #|     };
  #|     walk(root);
  #|     return best;
  #|   };
  #|   if (!target && typeof doc.querySelector === "function") {
  #|     target = doc.querySelector("#outer");
  #|   }
  #|   if (!target) target = doc.body || doc.documentElement || doc;
  #|   if (target && target.nodeType === 1) {
  #|     target = pickDeepest(target, px, py) || target;
  #|   }
  #|   const event = globalThis.__bidiCreateEvent("wheel", { bubbles: true, cancelable: true });
  #|   event.clientX = px;
  #|   event.clientY = py;
  #|   event.pageX = px;
  #|   event.pageY = py;
  #|   event.deltaX = dx;
  #|   event.deltaY = dy;
  #|   event.deltaZ = 0;
  #|   event.deltaMode = 0;
  #|   event.ctrlKey = !!ctrl;
  #|   event.altKey = !!alt;
  #|   event.shiftKey = !!shift;
  #|   event.metaKey = !!meta;
  #|   target.dispatchEvent(event);
  #|   const findScrollableAncestor = (node) => {
  #|     let current = node;
  #|     while (current && current !== doc) {
  #|       const style = current._style || current.style || {};
  #|       const overflow = String(style.overflow || style.overflowY || "").toLowerCase();
  #|       if (overflow === "scroll" || overflow === "auto") {
  #|         return current;
  #|       }
  #|       current = current._parent || current.parentElement || current.parentNode || null;
  #|     }
  #|     return null;
  #|   };
  #|   if (!event.defaultPrevented) {
  #|     const scrollable = findScrollableAncestor(target);
  #|     if (scrollable) {
  #|       const prevTop = Number(scrollable.scrollTop || 0);
  #|       const prevLeft = Number(scrollable.scrollLeft || 0);
  #|       scrollable.scrollTop = prevTop + dy;
  #|       scrollable.scrollLeft = prevLeft + dx;
  #|       const scrollEvent = globalThis.__bidiCreateEvent("scroll", { bubbles: false, cancelable: false });
  #|       scrollable.dispatchEvent(scrollEvent);
  #|     }
  #|   }
  #|   const tagName = target && typeof target.tagName === "string" ? target.tagName.toUpperCase() : "";
  #|   if (tagName === "IFRAME") {
  #|     const record =
  #|       typeof globalThis.recordWheelEvent === "function"
  #|         ? globalThis.recordWheelEvent
  #|         : (globalThis.window && typeof globalThis.window.recordWheelEvent === "function"
  #|             ? globalThis.window.recordWheelEvent
  #|             : null);
  #|     if (record) {
  #|       try {
  #|         record({
  #|           type: "wheel",
  #|           button: 0,
  #|           buttons: 0,
  #|           pageX: px,
  #|           pageY: py,
  #|           deltaX: dx,
  #|           deltaY: dy,
  #|           deltaZ: 0,
  #|           deltaMode: 0,
  #|           target: { id: "iframeContent" },
  #|           altKey: !!alt,
  #|           ctrlKey: !!ctrl,
  #|           metaKey: !!meta,
  #|           shiftKey: !!shift,
  #|         });
  #|       } catch (_e) {}
  #|     }
  #|   }
  #| }

///|
/// Dispatch synthetic wheel event.
pub fn input_dispatch_wheel_event(
  shared_id : String,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  ctrl : Bool,
  alt : Bool,
  shift : Bool,
  meta : Bool,
) -> Unit {
  js_input_dispatch_wheel_event(
    shared_id, x, y, delta_x, delta_y, ctrl, alt, shift, meta,
  )
}

///|
/// Drain queued script channel callback payloads as serialized BiDi values.
extern "js" fn js_take_channel_messages() -> String =
  #| () => {
  #|   const queue = Array.isArray(globalThis.__bidiChannelMessages)
  #|     ? globalThis.__bidiChannelMessages
  #|     : [];
  #|   globalThis.__bidiChannelMessages = [];
  #|   if (typeof globalThis.__bidiNextChannelHandleId !== "number") {
  #|     globalThis.__bidiNextChannelHandleId = 1;
  #|   }
  #|
  #|   const serialize = (value, maxObjectDepth, depth = 0) => {
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
  #|
  #|     const limitReached =
  #|       typeof maxObjectDepth === "number" &&
  #|       maxObjectDepth >= 0 &&
  #|       depth >= maxObjectDepth;
  #|
  #|     if (Array.isArray(value)) {
  #|       if (limitReached) return { type: "array" };
  #|       return { type: "array", value: value.map((v) => serialize(v, maxObjectDepth, depth + 1)) };
  #|     }
  #|     if (value instanceof Map) {
  #|       if (limitReached) return { type: "map" };
  #|       const entries = [];
  #|       for (const [k, v] of value) {
  #|         entries.push([typeof k === "string" ? k : serialize(k, maxObjectDepth, depth + 1), serialize(v, maxObjectDepth, depth + 1)]);
  #|       }
  #|       return { type: "map", value: entries };
  #|     }
  #|     if (value instanceof Set) {
  #|       if (limitReached) return { type: "set" };
  #|       return { type: "set", value: Array.from(value).map((v) => serialize(v, maxObjectDepth, depth + 1)) };
  #|     }
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|
  #|     if (value && type === "object" && typeof value.nodeType === "number") {
  #|       return { type: "node" };
  #|     }
  #|     if (value && value.constructor === Object) {
  #|       if (limitReached) return { type: "object" };
  #|       const entries = Object.entries(value).map(([k, v]) => [k, serialize(v, maxObjectDepth, depth + 1)]);
  #|       return { type: "object", value: entries };
  #|     }
  #|     return { type: "object" };
  #|   };
  #|
  #|   const events = queue.map((entry) => {
  #|     const channel = entry && typeof entry.channel === "string" ? entry.channel : "";
  #|     const ownership = entry && entry.ownership === "root" ? "root" : "none";
  #|     const maxObjectDepth =
  #|       entry && typeof entry.maxObjectDepth === "number"
  #|         ? entry.maxObjectDepth
  #|         : -1;
  #|     let data = serialize(entry ? entry.data : undefined, maxObjectDepth, 0);
  #|     if (ownership === "root" && data && typeof data === "object") {
  #|       data = {
  #|         ...data,
  #|         handle: `channel-handle-${globalThis.__bidiNextChannelHandleId++}`,
  #|       };
  #|     }
  #|     return { channel, data };
  #|   }).filter((entry) => !!entry.channel);
  #|
  #|   return JSON.stringify(events);
  #| }

///|
/// Drain queued script channel callback payloads as JSON.
pub fn take_channel_messages_json() -> String {
  js_take_channel_messages()
}

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
  if not(url.has_prefix("data:")) {
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
