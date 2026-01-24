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
extern "js" fn js_evaluate_expression(expression : String) -> String =
  #| (expression) => {
  #|   const consoleEntries = [];
  #|   const originalConsole = {
  #|     log: console.log,
  #|     warn: console.warn,
  #|     error: console.error,
  #|     info: console.info,
  #|     debug: console.debug
  #|   };
  #|
  #|   // Intercept console calls
  #|   const makeInterceptor = (level, method) => (...args) => {
  #|     consoleEntries.push({
  #|       level,
  #|       method,
  #|       text: args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' '),
  #|       timestamp: Date.now()
  #|     });
  #|     originalConsole[method](...args);
  #|   };
  #|
  #|   console.log = makeInterceptor('info', 'log');
  #|   console.warn = makeInterceptor('warn', 'warn');
  #|   console.error = makeInterceptor('error', 'error');
  #|   console.info = makeInterceptor('info', 'info');
  #|   console.debug = makeInterceptor('debug', 'debug');
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
  #|     // Minimal Mock DOM for Preact compatibility
  #|     const createMockElement = (tagName) => {
  #|       const el = {
  #|         tagName: tagName.toUpperCase(),
  #|         nodeName: tagName.toUpperCase(),
  #|         nodeType: 1,
  #|         _attrs: {},
  #|         _children: [],
  #|         _parent: null,
  #|         _textContent: '',
  #|         _listeners: {},
  #|         _style: {},
  #|         ownerDocument: null, // Set after document is created
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
  #|           // Simple innerHTML parsing (for basic cases)
  #|           if (v) {
  #|             const text = createMockTextNode(v);
  #|             text._parent = this;
  #|             this._children.push(text);
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
  #|         setAttribute(name, value) {
  #|           const oldValue = this._attrs[name];
  #|           this._attrs[name] = String(value);
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
  #|         getAttribute(name) { return this._attrs[name] ?? null; },
  #|         removeAttribute(name) {
  #|           const oldValue = this._attrs[name];
  #|           delete this._attrs[name];
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
  #|           return results;
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
  #|           return results;
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
  #|     // Simple querySelector implementation
  #|     const querySelect = (root, sel, all) => {
  #|       const results = [];
  #|       const search = (node) => {
  #|         for (const child of node._children || []) {
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
  #|       return all ? results : results[0] || null;
  #|     };
  #|
  #|     const matchesSelector = (el, sel) => {
  #|       // Universal selector
  #|       if (sel === '*') return true;
  #|       // ID selector
  #|       if (sel.startsWith('#')) return el._attrs.id === sel.slice(1);
  #|       // Class selector (simple, no tag prefix)
  #|       if (sel.startsWith('.') && !sel.includes('[')) {
  #|         const classes = sel.slice(1).split('.');
  #|         return classes.every(c => el.classList.contains(c));
  #|       }
  #|       // Attribute selector: [attr], [attr="value"], [attr*="value"]
  #|       const attrMatch = sel.match(/^\[([a-zA-Z\-]+)(?:(\*)?="([^"]*)")?\]$/);
  #|       if (attrMatch) {
  #|         const [, attrName, isContains, attrValue] = attrMatch;
  #|         const elValue = el._attrs[attrName];
  #|         if (attrValue === undefined) return elValue !== undefined;
  #|         if (isContains) return elValue && elValue.includes(attrValue);
  #|         return elValue === attrValue;
  #|       }
  #|       // Compound selector: tag[attr="value"]
  #|       const compoundAttrMatch = sel.match(/^([a-zA-Z]+)?\[([a-zA-Z\-]+)(?:(\*)?="([^"]*)")?\]$/);
  #|       if (compoundAttrMatch) {
  #|         const [, tag, attrName, isContains, attrValue] = compoundAttrMatch;
  #|         if (tag && el.tagName !== tag.toUpperCase()) return false;
  #|         const elValue = el._attrs[attrName];
  #|         if (attrValue === undefined) return elValue !== undefined;
  #|         if (isContains) return elValue && elValue.includes(attrValue);
  #|         return elValue === attrValue;
  #|       }
  #|       // Compound selector: tag.class
  #|       if (sel.includes('.') && !sel.includes('[')) {
  #|         const parts = sel.split('.');
  #|         const tag = parts[0];
  #|         const classes = parts.slice(1);
  #|         if (tag && el.tagName !== tag.toUpperCase()) return false;
  #|         return classes.every(c => el.classList.contains(c));
  #|       }
  #|       // Tag selector
  #|       return el.tagName === sel.toUpperCase();
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
  #|     globalThis.document = {
  #|       nodeType: 9,
  #|       documentElement: html,
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
  #|       createDocumentFragment() {
  #|         const frag = createMockElement('fragment');
  #|         frag.nodeType = 11;
  #|         frag.ownerDocument = this;
  #|         return frag;
  #|       },
  #|       getElementById(id) {
  #|         return querySelect(html, '#' + id, false);
  #|       },
  #|       querySelector(sel) { return querySelect(html, sel, false); },
  #|       querySelectorAll(sel) { return querySelect(html, sel, true); },
  #|       getElementsByTagName(tag) { return html.getElementsByTagName(tag); },
  #|       getElementsByClassName(cls) { return html.getElementsByClassName(cls); }
  #|     };
  #|
  #|     html.ownerDocument = globalThis.document;
  #|     head.ownerDocument = globalThis.document;
  #|     body.ownerDocument = globalThis.document;
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
  #|       cookieEnabled: false
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
  #|     // Wrap fetch to track network requests
  #|     const originalFetch = globalThis.fetch;
  #|     if (originalFetch) {
  #|       globalThis.fetch = function(url, options) {
  #|         globalThis.__activeNetworkRequests++;
  #|         notifyNetworkChange();
  #|         return originalFetch(url, options)
  #|           .then(response => {
  #|             globalThis.__activeNetworkRequests--;
  #|             notifyNetworkChange();
  #|             return response;
  #|           })
  #|           .catch(error => {
  #|             globalThis.__activeNetworkRequests--;
  #|             notifyNetworkChange();
  #|             throw error;
  #|           });
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
  #|           return originalOpen.apply(this, arguments);
  #|         };
  #|
  #|         xhr.send = function() {
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
  #|       const response = await fetch(url);
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
  #|       // Simple HTML parser
  #|       const parseHTML = (htmlStr) => {
  #|         const nodes = [];
  #|         let i = 0;
  #|         const len = htmlStr.length;
  #|
  #|         const skipWhitespace = () => {
  #|           while (i < len && /\s/.test(htmlStr[i])) i++;
  #|         };
  #|
  #|         const parseTagName = () => {
  #|           let name = '';
  #|           while (i < len && /[a-zA-Z0-9\-]/.test(htmlStr[i])) {
  #|             name += htmlStr[i++];
  #|           }
  #|           return name.toLowerCase();
  #|         };
  #|
  #|         const parseAttrValue = () => {
  #|           skipWhitespace();
  #|           if (htmlStr[i] === '=') {
  #|             i++; // skip =
  #|             skipWhitespace();
  #|             let quote = '';
  #|             if (htmlStr[i] === '"' || htmlStr[i] === "'") {
  #|               quote = htmlStr[i++];
  #|               let val = '';
  #|               while (i < len && htmlStr[i] !== quote) {
  #|                 val += htmlStr[i++];
  #|               }
  #|               i++; // skip closing quote
  #|               return val;
  #|             } else {
  #|               let val = '';
  #|               while (i < len && !/[\s>]/.test(htmlStr[i])) {
  #|                 val += htmlStr[i++];
  #|               }
  #|               return val;
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
  #|             i = endIdx >= 0 ? endIdx + 3 : len;
  #|             return null;
  #|           }
  #|
  #|           // DOCTYPE
  #|           if (htmlStr.slice(i, i + 8).toLowerCase() === '!doctype') {
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
  #|             const endIdx = htmlStr.toLowerCase().indexOf(endTag, i);
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
  #|       // Clear current document
  #|       const body = globalThis.document.body;
  #|       const head = globalThis.document.head;
  #|       while (body.firstChild) body.removeChild(body.firstChild);
  #|       while (head.firstChild) head.removeChild(head.firstChild);
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
  #|       // Move head children to document.head
  #|       if (headEl) {
  #|         for (const child of Array.from(headEl.childNodes)) {
  #|           head.appendChild(child);
  #|         }
  #|       }
  #|
  #|       // Move body children to document.body
  #|       if (bodyEl) {
  #|         for (const child of Array.from(bodyEl.childNodes)) {
  #|           body.appendChild(child);
  #|         }
  #|       } else {
  #|         // No body found, append all parsed nodes
  #|         for (const node of parsed) {
  #|           if (node.tagName !== 'HTML' && node.tagName !== 'HEAD') {
  #|             body.appendChild(node);
  #|           }
  #|         }
  #|       }
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
  #|       if (src.startsWith('//')) {
  #|         return 'https:' + src;
  #|       } else if (src.startsWith('/')) {
  #|         const urlObj = new URL(baseUrl);
  #|         return urlObj.origin + src;
  #|       } else if (!src.startsWith('http')) {
  #|         return new URL(src, baseUrl).href;
  #|       }
  #|       return src;
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
  #|             const response = await fetch(fullUrl);
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
  #|   // Store toBidiValue in global scope for async use
  #|   const toBidiValueFn = toBidiValue;
  #|
  #|   try {
  #|     let result = (0, eval)(expression);  // Indirect eval for global scope
  #|     // If result is a Promise, await it
  #|     if (result instanceof Promise) {
  #|       return result.then(
  #|         (resolved) => JSON.stringify({ type: "success", result: toBidiValueFn(resolved), consoleEntries }),
  #|         (rejected) => JSON.stringify({
  #|           type: "exception",
  #|           exceptionDetails: {
  #|             columnNumber: 0,
  #|             lineNumber: 0,
  #|             text: String(rejected),
  #|             exception: { type: "error", value: { type: String(rejected?.name || "Error") } },
  #|             stackTrace: { callFrames: [] }
  #|           },
  #|           consoleEntries
  #|         })
  #|       ).finally(() => {
  #|         console.log = originalConsole.log;
  #|         console.warn = originalConsole.warn;
  #|         console.error = originalConsole.error;
  #|         console.info = originalConsole.info;
  #|         console.debug = originalConsole.debug;
  #|       });
  #|     }
  #|     return JSON.stringify({ type: "success", result: toBidiValueFn(result), consoleEntries });
  #|   } catch (e) {
  #|     return JSON.stringify({
  #|       type: "exception",
  #|       exceptionDetails: {
  #|         columnNumber: 0,
  #|         lineNumber: 0,
  #|         text: String(e),
  #|         exception: { type: "error", value: { type: String(e.name || "Error") } },
  #|         stackTrace: { callFrames: [] }
  #|       },
  #|       consoleEntries
  #|     });
  #|   } finally {
  #|     // Restore original console (for sync path)
  #|     // Note: For async path, cleanup is in .finally()
  #|   }
  #|
  #|   function toBidiValue(value) {
  #|     if (value === undefined) return { type: "undefined" };
  #|     if (value === null) return { type: "null" };
  #|
  #|     const type = typeof value;
  #|
  #|     if (type === "boolean") return { type: "boolean", value };
  #|
  #|     if (type === "number") {
  #|       if (Number.isNaN(value)) return { type: "number", value: "NaN" };
  #|       if (!Number.isFinite(value)) return { type: "number", value: value > 0 ? "Infinity" : "-Infinity" };
  #|       if (Object.is(value, -0)) return { type: "number", value: "-0" };
  #|       return { type: "number", value };
  #|     }
  #|
  #|     if (type === "string") return { type: "string", value };
  #|
  #|     if (type === "bigint") return { type: "bigint", value: String(value) };
  #|
  #|     if (type === "symbol") return { type: "symbol" };
  #|
  #|     if (type === "function") return { type: "function" };
  #|
  #|     // Objects
  #|     if (value instanceof RegExp) {
  #|       return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     }
  #|     if (value instanceof Date) {
  #|       return { type: "date", value: value.toISOString() };
  #|     }
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) {
  #|         entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       }
  #|       return { type: "map", value: entries };
  #|     }
  #|     if (value instanceof Set) {
  #|       return { type: "set", value: Array.from(value).map(toBidiValue) };
  #|     }
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|     if (Array.isArray(value)) {
  #|       return { type: "array", value: value.map(toBidiValue) };
  #|     }
  #|
  #|     // Plain object
  #|     if (value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return { type: "object", value: entries };
  #|     }
  #|
  #|     // Other objects (proxy, generator, etc.)
  #|     return { type: "object" };
  #|   }
  #| }

///|
/// Evaluate JavaScript expression and return result as JSON (sync)
pub fn evaluate_js(expression : String) -> String {
  js_evaluate_expression(expression)
}

///|
/// FFI: Evaluate JavaScript expression asynchronously (awaits Promise)
/// Returns a Promise that resolves to JSON string
extern "js" fn js_evaluate_expression_async(expression : String) -> @core.Any =
  #| async (expression) => {
  #|   const consoleEntries = [];
  #|   const originalConsole = {
  #|     log: console.log,
  #|     warn: console.warn,
  #|     error: console.error,
  #|     info: console.info,
  #|     debug: console.debug
  #|   };
  #|
  #|   const makeInterceptor = (level, method) => (...args) => {
  #|     consoleEntries.push({
  #|       level,
  #|       method,
  #|       text: args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' '),
  #|       timestamp: Date.now()
  #|     });
  #|     originalConsole[method](...args);
  #|   };
  #|
  #|   console.log = makeInterceptor('info', 'log');
  #|   console.warn = makeInterceptor('warn', 'warn');
  #|   console.error = makeInterceptor('error', 'error');
  #|   console.info = makeInterceptor('info', 'info');
  #|   console.debug = makeInterceptor('debug', 'debug');
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
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       return { type: "map", value: entries };
  #|     }
  #|     if (value instanceof Set) return { type: "set", value: Array.from(value).map(toBidiValue) };
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|     if (Array.isArray(value)) return { type: "array", value: value.map(toBidiValue) };
  #|     if (value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return { type: "object", value: entries };
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
  #|         exception: { type: "error", value: { type: String(e.name || "Error") } },
  #|         stackTrace: { callFrames: [] }
  #|       },
  #|       consoleEntries
  #|     });
  #|   } finally {
  #|     console.log = originalConsole.log;
  #|     console.warn = originalConsole.warn;
  #|     console.error = originalConsole.error;
  #|     console.info = originalConsole.info;
  #|     console.debug = originalConsole.debug;
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
  js_evaluate_expression_async(expression)
}

///|
/// FFI: Evaluate expression asynchronously and send result via WebSocket
/// This runs the evaluation, awaits any Promise result, and sends response directly
extern "js" fn js_eval_and_send_async(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
) -> Unit =
  #| async (socket, requestId, expression, ctxId) => {
  #|   const consoleEntries = [];
  #|   const originalConsole = {
  #|     log: console.log, warn: console.warn, error: console.error,
  #|     info: console.info, debug: console.debug
  #|   };
  #|
  #|   const makeInterceptor = (level, method) => (...args) => {
  #|     consoleEntries.push({
  #|       level, method,
  #|       text: args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' '),
  #|       timestamp: Date.now()
  #|     });
  #|     originalConsole[method](...args);
  #|   };
  #|
  #|   console.log = makeInterceptor('info', 'log');
  #|   console.warn = makeInterceptor('warn', 'warn');
  #|   console.error = makeInterceptor('error', 'error');
  #|   console.info = makeInterceptor('info', 'info');
  #|   console.debug = makeInterceptor('debug', 'debug');
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
  #|     if (value instanceof RegExp) return { type: "regexp", value: { pattern: value.source, flags: value.flags } };
  #|     if (value instanceof Date) return { type: "date", value: value.toISOString() };
  #|     if (value instanceof Error) return { type: "error" };
  #|     if (value instanceof Promise) return { type: "promise" };
  #|     if (value instanceof Map) {
  #|       const entries = [];
  #|       for (const [k, v] of value) entries.push([typeof k === "string" ? k : toBidiValue(k), toBidiValue(v)]);
  #|       return { type: "map", value: entries };
  #|     }
  #|     if (value instanceof Set) return { type: "set", value: Array.from(value).map(toBidiValue) };
  #|     if (value instanceof WeakMap) return { type: "weakmap" };
  #|     if (value instanceof WeakSet) return { type: "weakset" };
  #|     if (ArrayBuffer.isView(value)) return { type: "typedarray" };
  #|     if (value instanceof ArrayBuffer) return { type: "arraybuffer" };
  #|     if (Array.isArray(value)) return { type: "array", value: value.map(toBidiValue) };
  #|     if (value.constructor === Object) {
  #|       const entries = Object.entries(value).map(([k, v]) => [k, toBidiValue(v)]);
  #|       return { type: "object", value: entries };
  #|     }
  #|     return { type: "object" };
  #|   }
  #|
  #|   let response;
  #|   try {
  #|     let result = (0, eval)(expression);
  #|     // Await if result is a Promise
  #|     if (result instanceof Promise) {
  #|       result = await result;
  #|     }
  #|     response = {
  #|       id: requestId,
  #|       type: "success",
  #|       result: {
  #|         realm: "default-realm",
  #|         result: toBidiValue(result)
  #|       }
  #|     };
  #|   } catch (e) {
  #|     response = {
  #|       id: requestId,
  #|       type: "success",
  #|       result: {
  #|         realm: "default-realm",
  #|         exceptionDetails: {
  #|           columnNumber: 0,
  #|           lineNumber: 0,
  #|           text: String(e),
  #|           exception: { type: "error", value: { type: String(e.name || "Error") } },
  #|           stackTrace: { callFrames: [] }
  #|         }
  #|       }
  #|     };
  #|   } finally {
  #|     console.log = originalConsole.log;
  #|     console.warn = originalConsole.warn;
  #|     console.error = originalConsole.error;
  #|     console.info = originalConsole.info;
  #|     console.debug = originalConsole.debug;
  #|   }
  #|
  #|   // Send console log events before response
  #|   for (const entry of consoleEntries) {
  #|     const logEvent = {
  #|       type: "event",
  #|       method: "log.entryAdded",
  #|       params: {
  #|         level: entry.level,
  #|         source: { realm: "default-realm", context: ctxId },
  #|         text: entry.text,
  #|         timestamp: entry.timestamp,
  #|         method: entry.method,
  #|         args: []
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
pub fn eval_and_send_async(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
) -> Unit {
  js_eval_and_send_async(socket, request_id, expression, ctx_id)
}

///|
/// Await a Promise and return result as String
pub fn await_promise(promise : @core.Any) -> String {
  js_await_promise(promise)
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
  let data = make_substr(chars, comma_idx + 1, chars.length())
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
