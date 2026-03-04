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
  self.protocol.reset_subscription_state()
  // Store socket reference for async responses
  self.protocol.set_socket(socket)

  // onopen
  socket["onopen"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Connection opened, could log or initialize
    }),
  )

  // onmessage - process BiDi messages (supports async via socket)
  socket["onmessage"] = @core.any(
    @core.from_fn1(fn(event : @core.Any) {
      let data : String = event._get("data").cast()
      // handle_message returns sync responses; async responses sent via socket
      let messages = self.handle_message(data)
      for msg in messages {
        socket._call("send", [@core.any(msg)]) |> ignore
      }
    }),
  )

  // onerror
  socket["onerror"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Error handling
    }),
  )

  // onclose
  socket["onclose"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Connection closed
      self.protocol.reset_subscription_state()
      self.protocol.clear_socket()
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
  #|           event.target = this;
  #|           event.currentTarget = this;
  #|           const listeners = this._listeners[event.type] || [];
  #|           for (const fn of listeners) fn.call(this, event);
  #|           return !event.defaultPrevented;
  #|         },
  #|         click() {
  #|           this.dispatchEvent(new Event('click', { bubbles: true }));
  #|         },
  #|         focus() {},
  #|         blur() {},
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
  #|     // Event class
  #|     globalThis.Event = globalThis.Event || class Event {
  #|       constructor(type, opts = {}) {
  #|         this.type = type;
  #|         this.bubbles = !!opts.bubbles;
  #|         this.cancelable = !!opts.cancelable;
  #|         this.defaultPrevented = false;
  #|         this.target = null;
  #|         this.currentTarget = null;
  #|       }
  #|       preventDefault() { this.defaultPrevented = true; }
  #|       stopPropagation() {}
  #|       stopImmediatePropagation() {}
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
  #|       get childNodes() { return [this.doctype, this.documentElement]; },
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
  #|             try {
  #|               const source = String(ctor);
  #|               const match = source.match(/attachShadow\(\{\s*mode:\s*["'](open|closed)["']\s*\}\)/);
  #|               if (match && match[1]) shadowMode = match[1];
  #|             } catch (_e) {}
  #|             const elems = globalThis.document.querySelectorAll(String(name));
  #|             for (const elem of elems) {
  #|               if (elem && !elem.shadowRoot && typeof elem.attachShadow === 'function') {
  #|                 elem.attachShadow({ mode: shadowMode });
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
  #|       const event = new Event('click', { bubbles: true, cancelable: true });
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
  #|               const inputEvent = new Event('input', { bubbles: true });
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
  #|         const inputEvent = new Event('input', { bubbles: true });
  #|         element.dispatchEvent(inputEvent);
  #|         return true;
  #|       }
  #|     };
  #|
  #|     globalThis.__fill = function(selector, value) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       element.value = value;
  #|       const inputEvent = new Event('input', { bubbles: true });
  #|       element.dispatchEvent(inputEvent);
  #|       const changeEvent = new Event('change', { bubbles: true });
  #|       element.dispatchEvent(changeEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__clear = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       element.value = '';
  #|       const inputEvent = new Event('input', { bubbles: true });
  #|       element.dispatchEvent(inputEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__focus = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (element.focus) element.focus();
  #|       const focusEvent = new Event('focus', { bubbles: false });
  #|       element.dispatchEvent(focusEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__blur = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       if (element.blur) element.blur();
  #|       const blurEvent = new Event('blur', { bubbles: false });
  #|       element.dispatchEvent(blurEvent);
  #|       return true;
  #|     };
  #|
  #|     globalThis.__hover = function(selector) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       const mouseEnter = new Event('mouseenter', { bubbles: false });
  #|       const mouseOver = new Event('mouseover', { bubbles: true });
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
  #|         const changeEvent = new Event('change', { bubbles: true });
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
  #|         const changeEvent = new Event('change', { bubbles: true });
  #|         element.dispatchEvent(changeEvent);
  #|       }
  #|       return true;
  #|     };
  #|
  #|     globalThis.__select = function(selector, value) {
  #|       const element = globalThis.document.querySelector(selector);
  #|       if (!element) throw new Error('Element not found: ' + selector);
  #|       element.value = value;
  #|       const changeEvent = new Event('change', { bubbles: true });
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
  #|       const event = new Event(eventType, {
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
  #|     globalThis.__bidiContextWindows.set(currentCtx, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(currentCtx);
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.frames = frameWindows;
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
    expression,
    capture_console,
    user_activation,
    root_ownership,
    serialization_options_json,
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
  #|     globalThis.__bidiContextWindows.set(ctxId, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.frames = frameWindows;
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
  #|     globalThis.__bidiContextWindows.set(ctxId, win);
  #|   }
  #|   const contextWindow = globalThis.__bidiContextWindows.get(ctxId);
  #|   if (!contextWindow.window) contextWindow.window = contextWindow;
  #|   const frameWindows = Array.isArray(contextWindow.frames) ? contextWindow.frames : [];
  #|   globalThis.window = contextWindow;
  #|   globalThis.frames = frameWindows;
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
    socket,
    request_id,
    expression,
    ctx_id,
    realm_id,
    capture_console,
    user_activation,
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
    socket,
    request_id,
    expression,
    ctx_id,
    "default-realm",
    true,
    false,
    false,
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
  #|     globalThis.__bidiContextWindows.set(ctxId, win);
  #|   }
  #| }

///|
/// Set current BiDi context for value serialization helpers.
pub fn set_runtime_context(ctx_id : String) -> Unit {
  js_set_runtime_context(ctx_id)
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
  #|   if (typeof globalThis.__loadHTML !== "function") {
  #|     return "missing-loader";
  #|   }
  #|   globalThis.__loadHTML(html);
  #|   globalThis.__pageUrl = baseUrl;
  #|   if (executeScripts && typeof globalThis.__executeScripts === "function") {
  #|     try {
  #|       await globalThis.__executeScripts({ baseUrl });
  #|     } catch (_e) {}
  #|   }
  #|   return "ok";
  #| }

///|
/// FFI: Synchronize runtime document by fetching and loading a URL.
extern "js" fn js_sync_runtime_page_async(url : String) -> @core.Any =
  #| async (url) => {
  #|   if (typeof globalThis.__loadPageWithScripts === "function") {
  #|     try {
  #|       await globalThis.__loadPageWithScripts(url, { executeScripts: true });
  #|       return "ok";
  #|     } catch (_e) {
  #|       return "load-failed";
  #|     }
  #|   }
  #|   if (typeof globalThis.__loadPage === "function") {
  #|     try {
  #|       await globalThis.__loadPage(url);
  #|       return "ok";
  #|     } catch (_e) {
  #|       return "load-failed";
  #|     }
  #|   }
  #|   globalThis.__pageUrl = url;
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
