///|
/// JavaScript Runtime - QuickJS implementation
///
/// Uses quickjs-emscripten for sandboxed JavaScript execution.
/// DOM operations are queued and executed after JS completes.

///|
/// Global state for context management
priv struct RuntimeState {
  mut counter : Int
  contexts : Map[Int, @dom.DomTree]
  mut initialized : Bool
}

///|
/// Global runtime state
let runtime_state : RuntimeState = {
  counter: 0,
  contexts: {},
  initialized: false,
}

///|
/// Register a context and return its ID
fn register_context(dom : @dom.DomTree) -> Int {
  let id = runtime_state.counter
  runtime_state.counter = runtime_state.counter + 1
  runtime_state.contexts.set(id, dom)
  id
}

///|
/// Unregister a context
fn unregister_context(id : Int) -> Unit {
  runtime_state.contexts.remove(id)
}

///|
/// FFI: Initialize QuickJS runtime (must be called before execution)
/// Returns true if initialization succeeded
/// Note: QuickJS requires async init, so we fall back to Node.js vm if not pre-initialized
extern "js" fn quickjs_init() -> Bool =
  #| () => {
  #|   // Check if QuickJS was pre-initialized
  #|   if (globalThis.__quickjs_initialized && globalThis.__quickjs) {
  #|     return true;
  #|   }
  #|   // QuickJS requires async init - fall back to Node.js vm for now
  #|   // To use QuickJS, call initQuickJS() before using the runtime
  #|   globalThis.__use_nodejs_vm = true;
  #|   return true;
  #| }

///|
/// FFI: Execute JavaScript code with DOM mock
/// Uses QuickJS if initialized, otherwise falls back to Node.js vm
/// Returns JSON: { success, value, logs, domOps, error? }
extern "js" fn quickjs_execute_with_mock_dom(code : String) -> String =
  #| (code) => {
  #|   // Mock DOM setup code (shared between QuickJS and Node.js vm)
  #|   const setupCode = `
  #|     const logs = [];
  #|     const domOps = [];
  #|     let nodeIdCounter = 1000;
  #|     const mockElements = new Map();
  #|
  #|     // Microtask queue for queueMicrotask()
  #|     const _microtaskQueue = [];
  #|     function queueMicrotask(callback) {
  #|       if (typeof callback !== 'function') {
  #|         throw new TypeError('queueMicrotask requires a function argument');
  #|       }
  #|       _microtaskQueue.push(callback);
  #|     }
  #|     // Process all queued microtasks (called after script execution)
  #|     function _flushMicrotasks() {
  #|       let count = 0;
  #|       const limit = 10000; // Prevent infinite loops
  #|       while (_microtaskQueue.length > 0 && count < limit) {
  #|         const task = _microtaskQueue.shift();
  #|         try { task(); } catch (e) { logs.push('[ERROR] Microtask: ' + e); }
  #|         count++;
  #|       }
  #|       if (count >= limit) {
  #|         logs.push('[ERROR] Microtask limit exceeded (possible infinite loop)');
  #|       }
  #|     }
  #|
  #|     // Custom Promise implementation that uses _microtaskQueue for synchronous control
  #|     // This ensures Promise.then callbacks run during _flushMicrotasks()
  #|     const _PromiseState = { PENDING: 0, FULFILLED: 1, REJECTED: 2 };
  #|     function _SyncPromise(executor) {
  #|       this._state = _PromiseState.PENDING;
  #|       this._value = undefined;
  #|       this._handlers = [];
  #|       const resolve = (value) => {
  #|         if (this._state !== _PromiseState.PENDING) return;
  #|         if (value && typeof value.then === 'function') {
  #|           value.then(resolve, reject);
  #|           return;
  #|         }
  #|         this._state = _PromiseState.FULFILLED;
  #|         this._value = value;
  #|         this._handlers.forEach(h => queueMicrotask(() => h.onFulfilled(value)));
  #|         this._handlers = [];
  #|       };
  #|       const reject = (reason) => {
  #|         if (this._state !== _PromiseState.PENDING) return;
  #|         this._state = _PromiseState.REJECTED;
  #|         this._value = reason;
  #|         this._handlers.forEach(h => queueMicrotask(() => h.onRejected(reason)));
  #|         this._handlers = [];
  #|       };
  #|       try { executor(resolve, reject); } catch (e) { reject(e); }
  #|     }
  #|     _SyncPromise.prototype.then = function(onFulfilled, onRejected) {
  #|       return new _SyncPromise((resolve, reject) => {
  #|         const handle = (handler, value, fallback) => {
  #|           try {
  #|             if (typeof handler === 'function') {
  #|               resolve(handler(value));
  #|             } else {
  #|               fallback(value);
  #|             }
  #|           } catch (e) { reject(e); }
  #|         };
  #|         if (this._state === _PromiseState.FULFILLED) {
  #|           queueMicrotask(() => handle(onFulfilled, this._value, resolve));
  #|         } else if (this._state === _PromiseState.REJECTED) {
  #|           queueMicrotask(() => handle(onRejected, this._value, reject));
  #|         } else {
  #|           this._handlers.push({
  #|             onFulfilled: (v) => handle(onFulfilled, v, resolve),
  #|             onRejected: (r) => handle(onRejected, r, reject)
  #|           });
  #|         }
  #|       });
  #|     };
  #|     _SyncPromise.prototype.catch = function(onRejected) {
  #|       return this.then(undefined, onRejected);
  #|     };
  #|     _SyncPromise.prototype.finally = function(onFinally) {
  #|       return this.then(
  #|         v => { onFinally(); return v; },
  #|         r => { onFinally(); throw r; }
  #|       );
  #|     };
  #|     _SyncPromise.resolve = function(value) {
  #|       return new _SyncPromise(resolve => resolve(value));
  #|     };
  #|     _SyncPromise.reject = function(reason) {
  #|       return new _SyncPromise((_, reject) => reject(reason));
  #|     };
  #|     _SyncPromise.all = function(promises) {
  #|       return new _SyncPromise((resolve, reject) => {
  #|         const results = [];
  #|         let count = 0;
  #|         const arr = Array.from(promises);
  #|         if (arr.length === 0) { resolve([]); return; }
  #|         arr.forEach((p, i) => {
  #|           _SyncPromise.resolve(p).then(v => {
  #|             results[i] = v;
  #|             if (++count === arr.length) resolve(results);
  #|           }, reject);
  #|         });
  #|       });
  #|     };
  #|     _SyncPromise.race = function(promises) {
  #|       return new _SyncPromise((resolve, reject) => {
  #|         Array.from(promises).forEach(p => _SyncPromise.resolve(p).then(resolve, reject));
  #|       });
  #|     };
  #|     // Replace native Promise with our sync version
  #|     const Promise = _SyncPromise;
  #|
  #|     // Fetch API implementation with mock support
  #|     const _fetchMocks = new Map();
  #|
  #|     // Response class
  #|     class Response {
  #|       constructor(body, init) {
  #|         this._body = body || '';
  #|         this._init = init || {};
  #|         this.status = this._init.status || 200;
  #|         this.statusText = this._init.statusText || (this.status === 200 ? 'OK' : '');
  #|         this.ok = this.status >= 200 && this.status < 300;
  #|         this.headers = new Headers(this._init.headers);
  #|         this.type = 'basic';
  #|         this.url = this._init.url || '';
  #|         this._bodyUsed = false;
  #|       }
  #|       get bodyUsed() { return this._bodyUsed; }
  #|       _consumeBody() {
  #|         if (this._bodyUsed) throw new TypeError('Body already consumed');
  #|         this._bodyUsed = true;
  #|         return this._body;
  #|       }
  #|       text() {
  #|         return Promise.resolve(this._consumeBody());
  #|       }
  #|       json() {
  #|         return this.text().then(text => JSON.parse(text));
  #|       }
  #|       blob() {
  #|         return Promise.resolve(new Blob([this._consumeBody()]));
  #|       }
  #|       arrayBuffer() {
  #|         const text = this._consumeBody();
  #|         const buf = new ArrayBuffer(text.length);
  #|         const view = new Uint8Array(buf);
  #|         for (let i = 0; i < text.length; i++) view[i] = text.charCodeAt(i);
  #|         return Promise.resolve(buf);
  #|       }
  #|       clone() {
  #|         if (this._bodyUsed) throw new TypeError('Body already consumed');
  #|         return new Response(this._body, this._init);
  #|       }
  #|     }
  #|
  #|     // Headers class
  #|     class Headers {
  #|       constructor(init) {
  #|         this._headers = {};
  #|         if (init) {
  #|           if (init instanceof Headers) {
  #|             init.forEach((v, k) => this.set(k, v));
  #|           } else if (Array.isArray(init)) {
  #|             init.forEach(([k, v]) => this.set(k, v));
  #|           } else {
  #|             Object.keys(init).forEach(k => this.set(k, init[k]));
  #|           }
  #|         }
  #|       }
  #|       get(name) { return this._headers[name.toLowerCase()] || null; }
  #|       set(name, value) { this._headers[name.toLowerCase()] = String(value); }
  #|       has(name) { return name.toLowerCase() in this._headers; }
  #|       delete(name) { delete this._headers[name.toLowerCase()]; }
  #|       append(name, value) {
  #|         const key = name.toLowerCase();
  #|         if (this._headers[key]) this._headers[key] += ', ' + value;
  #|         else this._headers[key] = String(value);
  #|       }
  #|       forEach(callback, thisArg) {
  #|         Object.keys(this._headers).forEach(k => callback.call(thisArg, this._headers[k], k, this));
  #|       }
  #|       keys() { return Object.keys(this._headers)[Symbol.iterator](); }
  #|       values() { return Object.values(this._headers)[Symbol.iterator](); }
  #|       entries() { return Object.entries(this._headers)[Symbol.iterator](); }
  #|       [Symbol.iterator]() { return this.entries(); }
  #|     }
  #|
  #|     // Request class (simplified)
  #|     class Request {
  #|       constructor(input, init) {
  #|         this.url = typeof input === 'string' ? input : input.url;
  #|         this.method = (init && init.method) || 'GET';
  #|         this.headers = new Headers((init && init.headers) || {});
  #|         this._body = (init && init.body) || null;
  #|       }
  #|       text() { return Promise.resolve(this._body || ''); }
  #|       json() { return this.text().then(t => JSON.parse(t)); }
  #|     }
  #|
  #|     // Blob class (simplified)
  #|     class Blob {
  #|       constructor(parts, options) {
  #|         this._parts = parts || [];
  #|         this.type = (options && options.type) || '';
  #|         this.size = this._parts.reduce((acc, p) => acc + (p.length || 0), 0);
  #|       }
  #|       text() { return Promise.resolve(this._parts.join('')); }
  #|       arrayBuffer() {
  #|         const text = this._parts.join('');
  #|         const buf = new ArrayBuffer(text.length);
  #|         const view = new Uint8Array(buf);
  #|         for (let i = 0; i < text.length; i++) view[i] = text.charCodeAt(i);
  #|         return Promise.resolve(buf);
  #|       }
  #|     }
  #|
  #|     // fetch function
  #|     function fetch(input, init) {
  #|       return new Promise((resolve, reject) => {
  #|         const url = typeof input === 'string' ? input : input.url;
  #|         const mock = _fetchMocks.get(url);
  #|         if (mock) {
  #|           // Use mock response
  #|           queueMicrotask(() => {
  #|             const response = new Response(mock.body, {
  #|               status: mock.status || 200,
  #|               statusText: mock.statusText || '',
  #|               headers: mock.headers || {},
  #|               url: url
  #|             });
  #|             resolve(response);
  #|           });
  #|         } else {
  #|           // No mock - reject with network error
  #|           queueMicrotask(() => {
  #|             reject(new TypeError('Network request failed: no mock for ' + url));
  #|           });
  #|         }
  #|       });
  #|     }
  #|
  #|     // Task queue for setTimeout/setInterval (populated by window.setTimeout)
  #|     // Note: _timers is defined later with window object
  #|     // Run one pending timeout and return true if there was one
  #|     function _runOneTimeout() {
  #|       const ids = Object.keys(_timers.timeouts);
  #|       if (ids.length === 0) return false;
  #|       // Sort by timeout value to run shorter timeouts first (simplified model)
  #|       ids.sort((a, b) => (_timers.timeouts[a].timeout || 0) - (_timers.timeouts[b].timeout || 0));
  #|       const id = ids[0];
  #|       const entry = _timers.timeouts[id];
  #|       delete _timers.timeouts[id];
  #|       try { entry.handler(); } catch (e) { logs.push('[ERROR] setTimeout: ' + e); }
  #|       return true;
  #|     }
  #|     // Run all pending timeouts (for testing - runs until queue is empty)
  #|     function _runAllTimeouts(maxIterations) {
  #|       let count = 0;
  #|       const limit = maxIterations || 100;
  #|       while (count < limit && _runOneTimeout()) { count++; }
  #|       return count;
  #|     }
  #|     // Check if there are pending timers
  #|     function _hasPendingTimers() {
  #|       return Object.keys(_timers.timeouts).length > 0 || Object.keys(_timers.intervals).length > 0;
  #|     }
  #|
  #|     // DOMException class
  #|     function DOMException(message, name) {
  #|       Error.call(this, message);
  #|       this.message = message || '';
  #|       this.name = name || 'Error';
  #|       this.code = DOMException[name] || 0;
  #|     }
  #|     DOMException.prototype = Object.create(Error.prototype);
  #|     DOMException.prototype.constructor = DOMException;
  #|     DOMException.INDEX_SIZE_ERR = 1;
  #|     DOMException.HIERARCHY_REQUEST_ERR = 3;
  #|     DOMException.WRONG_DOCUMENT_ERR = 4;
  #|     DOMException.INVALID_CHARACTER_ERR = 5;
  #|     DOMException.NOT_FOUND_ERR = 8;
  #|     DOMException.NOT_SUPPORTED_ERR = 9;
  #|     DOMException.INVALID_STATE_ERR = 11;
  #|     DOMException.SYNTAX_ERR = 12;
  #|     DOMException.INVALID_MODIFICATION_ERR = 13;
  #|     DOMException.NAMESPACE_ERR = 14;
  #|     DOMException.IndexSizeError = 1;
  #|     DOMException.HierarchyRequestError = 3;
  #|     DOMException.WrongDocumentError = 4;
  #|     DOMException.InvalidCharacterError = 5;
  #|     DOMException.NotFoundError = 8;
  #|     DOMException.NotSupportedError = 9;
  #|     DOMException.InvalidStateError = 11;
  #|     DOMException.SyntaxError = 12;
  #|     DOMException.InvalidModificationError = 13;
  #|     DOMException.NamespaceError = 14;
  #|
  #|     // DOMImplementation class
  #|     function DOMImplementation() {}
  #|
  #|     // DOM interface classes for prototype chain
  #|     function Node() {}
  #|     Node.ELEMENT_NODE = 1;
  #|     Node.ATTRIBUTE_NODE = 2;
  #|     Node.TEXT_NODE = 3;
  #|     Node.CDATA_SECTION_NODE = 4;
  #|     Node.PROCESSING_INSTRUCTION_NODE = 7;
  #|     Node.COMMENT_NODE = 8;
  #|     Node.DOCUMENT_NODE = 9;
  #|     Node.DOCUMENT_TYPE_NODE = 10;
  #|     Node.DOCUMENT_FRAGMENT_NODE = 11;
  #|     Node.DOCUMENT_POSITION_DISCONNECTED = 1;
  #|     Node.DOCUMENT_POSITION_PRECEDING = 2;
  #|     Node.DOCUMENT_POSITION_FOLLOWING = 4;
  #|     Node.DOCUMENT_POSITION_CONTAINS = 8;
  #|     Node.DOCUMENT_POSITION_CONTAINED_BY = 16;
  #|     Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 32;
  #|     Node.prototype.ELEMENT_NODE = 1;
  #|     Node.prototype.ATTRIBUTE_NODE = 2;
  #|     Node.prototype.TEXT_NODE = 3;
  #|     Node.prototype.CDATA_SECTION_NODE = 4;
  #|     Node.prototype.PROCESSING_INSTRUCTION_NODE = 7;
  #|     Node.prototype.COMMENT_NODE = 8;
  #|     Node.prototype.DOCUMENT_NODE = 9;
  #|     Node.prototype.DOCUMENT_TYPE_NODE = 10;
  #|     Node.prototype.DOCUMENT_FRAGMENT_NODE = 11;
  #|     Node.prototype.DOCUMENT_POSITION_DISCONNECTED = 1;
  #|     Node.prototype.DOCUMENT_POSITION_PRECEDING = 2;
  #|     Node.prototype.DOCUMENT_POSITION_FOLLOWING = 4;
  #|     Node.prototype.DOCUMENT_POSITION_CONTAINS = 8;
  #|     Node.prototype.DOCUMENT_POSITION_CONTAINED_BY = 16;
  #|     Node.prototype.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 32;
  #|     if (typeof globalThis !== 'undefined') {
  #|       globalThis.Node = Node;
  #|     }
  #|
  #|     function Attr() {}
  #|     Attr.prototype = Object.create(Node.prototype);
  #|     Attr.prototype.constructor = Attr;
  #|     if (typeof globalThis !== 'undefined') {
  #|       globalThis.Attr = Attr;
  #|     }
  #|
  #|     Node.prototype.appendChild = function(child) {
  #|       if (typeof this.appendChild === 'function' && this.appendChild !== Node.prototype.appendChild) {
  #|         return this.appendChild(child);
  #|       }
  #|       if (!isNodeLike(child)) {
  #|         throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|       }
  #|       throw new DOMException('Cannot append child to this node type', 'HierarchyRequestError');
  #|     };
  #|     Node.prototype.insertBefore = function(newChild, refChild) {
  #|       if (typeof this.insertBefore === 'function' && this.insertBefore !== Node.prototype.insertBefore) {
  #|         return this.insertBefore(newChild, refChild);
  #|       }
  #|       if (arguments.length < 2) {
  #|         throw new TypeError('Failed to execute insertBefore: 2 arguments required');
  #|       }
  #|       if (!isNodeLike(newChild)) {
  #|         throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|       }
  #|       if (refChild !== null && refChild !== undefined && !isNodeLike(refChild)) {
  #|         throw new TypeError('Failed to execute insertBefore: parameter 2 is not of type Node');
  #|       }
  #|       throw new DOMException('Cannot insert child into this node type', 'HierarchyRequestError');
  #|     };
  #|     Node.prototype.removeChild = function(child) {
  #|       if (typeof this.removeChild === 'function' && this.removeChild !== Node.prototype.removeChild) {
  #|         return this.removeChild(child);
  #|       }
  #|       if (!isNodeLike(child)) {
  #|         throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|       }
  #|       throw new DOMException('The node to be removed is not a child of this node', 'NotFoundError');
  #|     };
  #|     Node.prototype.replaceChild = function(newChild, oldChild) {
  #|       if (typeof this.replaceChild === 'function' && this.replaceChild !== Node.prototype.replaceChild) {
  #|         return this.replaceChild(newChild, oldChild);
  #|       }
  #|       if (!isNodeLike(newChild) || !isNodeLike(oldChild)) {
  #|         throw new TypeError('Failed to execute replaceChild: parameters are not of type Node');
  #|       }
  #|       throw new DOMException('Cannot replace child on this node type', 'HierarchyRequestError');
  #|     };
  #|     Object.defineProperty(Node.prototype, 'parentNode', {
  #|       get() { return this._parent === undefined ? null : this._parent; },
  #|       set(v) { this._parent = v; },
  #|       configurable: true
  #|     });
  #|     Object.defineProperty(Node.prototype, 'parentElement', {
  #|       get() {
  #|         const p = this.parentNode;
  #|         return p && getNodeType(p) === 1 ? p : null;
  #|       },
  #|       configurable: true
  #|     });
  #|     Object.defineProperty(Node.prototype, 'nextSibling', {
  #|       get() {
  #|         const parent = getParentNode(this);
  #|         if (!parent) return null;
  #|         const siblings = getSiblingArray(this);
  #|         const idx = siblings.indexOf(this);
  #|         return idx >= 0 ? (siblings[idx + 1] || null) : null;
  #|       },
  #|       configurable: true
  #|     });
  #|     Object.defineProperty(Node.prototype, 'previousSibling', {
  #|       get() {
  #|         const parent = getParentNode(this);
  #|         if (!parent) return null;
  #|         const siblings = getSiblingArray(this);
  #|         const idx = siblings.indexOf(this);
  #|         return idx > 0 ? siblings[idx - 1] : null;
  #|       },
  #|       configurable: true
  #|     });
  #|     Node.prototype.hasChildNodes = function() {
  #|       const nodes = getChildNodesArray(this);
  #|       return nodes && nodes.length > 0;
  #|     };
  #|     Node.prototype.normalize = function() {
  #|       if (typeof this.normalize === 'function' && this.normalize !== Node.prototype.normalize) {
  #|         return this.normalize();
  #|       }
  #|       if (!this._children) return;
  #|       normalizeChildArray(this._children);
  #|     };
  #|     Node.prototype.contains = function(other) {
  #|       return nodeContains(this, other);
  #|     };
  #|     Node.prototype.compareDocumentPosition = function(other) {
  #|       return compareDocumentPositionImpl(this, other);
  #|     };
  #|     Node.prototype.lookupNamespaceURI = function(prefix) {
  #|       return lookupNamespaceURIImpl(this, prefix);
  #|     };
  #|     Node.prototype.isDefaultNamespace = function(namespace) {
  #|       const ns = namespace === undefined || namespace === null || namespace === '' ? null : String(namespace);
  #|       const nodeType = getNodeType(this);
  #|       if ((nodeType === 10 || nodeType === 11) && !getParentNode(this)) {
  #|         return ns === null;
  #|       }
  #|       const current = lookupNamespaceURIImpl(this, null);
  #|       return current === ns;
  #|     };
  #|     Node.prototype.addEventListener = function(type, listener, options) {};
  #|     Node.prototype.removeEventListener = function(type, listener, options) {};
  #|     Node.prototype.dispatchEvent = function(event) { return true; };
  #|
  #|     function CharacterData() {}
  #|     CharacterData.prototype = Object.create(Node.prototype);
  #|     CharacterData.prototype.constructor = CharacterData;
  #|
  #|     function Element() {}
  #|     Element.prototype = Object.create(Node.prototype);
  #|     Element.prototype.constructor = Element;
  #|
  #|     function NodeList() {}
  #|     NodeList.prototype = Object.create(Array.prototype);
  #|     NodeList.prototype.constructor = NodeList;
  #|     NodeList.prototype.item = function(i) {
  #|       const items = this._itemsFn ? this._itemsFn() : this;
  #|       return items[i] || null;
  #|     };
  #|     Object.defineProperty(NodeList.prototype, 'length', {
  #|       get() {
  #|         const items = this._itemsFn ? this._itemsFn() : (this._items || this);
  #|         return (items && typeof items.length === 'number') ? items.length : 0;
  #|       },
  #|       configurable: true
  #|     });
  #|
  #|     function HTMLCollection() {}
  #|     HTMLCollection.prototype = Object.create(Array.prototype);
  #|     HTMLCollection.prototype.constructor = HTMLCollection;
  #|     HTMLCollection.prototype.item = function(i) {
  #|       const items = this._itemsFn ? this._itemsFn() : this;
  #|       return items[i] || null;
  #|     };
  #|     HTMLCollection.prototype.namedItem = function(name) {
  #|       const items = this._itemsFn ? this._itemsFn() : this;
  #|       for (const el of items) {
  #|         if (!el || !el._attrs) continue;
  #|         if (el._attrs.id === name) return el;
  #|         if (el._namespaceURI === 'http://www.w3.org/1999/xhtml' && el._attrs.name === name) return el;
  #|       }
  #|       return null;
  #|     };
  #|
  #|     function makeLiveList(ctor, itemsFn, withNamedItem) {
  #|       const target = { _itemsFn: itemsFn };
  #|       Object.setPrototypeOf(target, ctor.prototype);
  #|       const isIndexProp = (prop) => typeof prop === 'string' && /^[0-9]+$/.test(prop);
  #|       const getItems = () => itemsFn();
  #|       const getNamedElement = (name) => {
  #|         if (!withNamedItem) return undefined;
  #|         const items = getItems();
  #|         for (const el of items) {
  #|           if (!el || !el._attrs) continue;
  #|           if (el._attrs.id === name) return el;
  #|           if (el._namespaceURI === 'http://www.w3.org/1999/xhtml' && el._attrs.name === name) return el;
  #|         }
  #|         return undefined;
  #|       };
  #|       const getNamedKeys = () => {
  #|         if (!withNamedItem) return [];
  #|         const items = getItems();
  #|         const seen = new Set();
  #|         const keys = [];
  #|         for (const el of items) {
  #|           if (!el || !el._attrs) continue;
  #|           const id = el._attrs.id;
  #|           if (id && !seen.has(id)) { keys.push(id); seen.add(id); }
  #|           const name = el._attrs.name;
  #|           if (name && el._namespaceURI === 'http://www.w3.org/1999/xhtml' && !seen.has(name)) {
  #|             keys.push(name);
  #|             seen.add(name);
  #|           }
  #|         }
  #|         return keys;
  #|       };
  #|       return new Proxy(target, {
  #|         get(obj, prop) {
  #|           if (prop === '_itemsFn') return obj._itemsFn;
  #|           if (prop === 'length') return getItems().length;
  #|           if (prop in obj) return obj[prop];
  #|           if (isIndexProp(prop)) {
  #|             const items = getItems();
  #|             return items[Number(prop)];
  #|           }
  #|           if (withNamedItem && typeof prop === 'string') {
  #|             const named = getNamedElement(prop);
  #|             if (named !== undefined) return named;
  #|           }
  #|           return undefined;
  #|         },
  #|         set(obj, prop, value) {
  #|           if (prop === 'length') return false;
  #|           if (isIndexProp(prop)) return false;
  #|           obj[prop] = value;
  #|           return true;
  #|         },
  #|         has(obj, prop) {
  #|           if (prop in obj) return true;
  #|           if (prop === 'length') return true;
  #|           if (isIndexProp(prop)) return Number(prop) < getItems().length;
  #|           if (withNamedItem && typeof prop === 'string') return getNamedElement(prop) !== undefined;
  #|           return false;
  #|         },
  #|         ownKeys(obj) {
  #|           const keys = [];
  #|           const items = getItems();
  #|           for (let i = 0; i < items.length; i++) keys.push(String(i));
  #|           for (const name of getNamedKeys()) keys.push(name);
  #|           for (const name of Object.getOwnPropertyNames(obj)) {
  #|             if (name === '_itemsFn' || name === 'length') continue;
  #|             if (!keys.includes(name)) keys.push(name);
  #|           }
  #|           return keys;
  #|         },
  #|         getOwnPropertyDescriptor(obj, prop) {
  #|           if (Object.prototype.hasOwnProperty.call(obj, prop)) {
  #|             return Object.getOwnPropertyDescriptor(obj, prop);
  #|           }
  #|           if (isIndexProp(prop)) {
  #|             const idx = Number(prop);
  #|             const items = getItems();
  #|             if (idx < items.length) {
  #|               return { configurable: true, enumerable: true, writable: false, value: items[idx] };
  #|             }
  #|             return undefined;
  #|           }
  #|           if (withNamedItem && typeof prop === 'string') {
  #|             const named = getNamedElement(prop);
  #|             if (named !== undefined) {
  #|               return { configurable: true, enumerable: false, writable: false, value: named };
  #|             }
  #|           }
  #|           return undefined;
  #|         }
  #|       });
  #|     }
  #|     function makeNodeList(items) {
  #|       if (typeof items === 'function') return makeLiveList(NodeList, items, false);
  #|       const list = {};
  #|       Object.setPrototypeOf(list, NodeList.prototype);
  #|       Object.defineProperty(list, '_items', { value: items.slice(), writable: false, enumerable: false, configurable: true });
  #|       for (let i = 0; i < items.length; i++) {
  #|         Object.defineProperty(list, i, { value: items[i], writable: false, enumerable: true, configurable: true });
  #|       }
  #|       return list;
  #|     }
  #|     function makeHTMLCollection(items) {
  #|       if (typeof items === 'function') return makeLiveList(HTMLCollection, items, true);
  #|       const list = items.slice();
  #|       Object.setPrototypeOf(list, HTMLCollection.prototype);
  #|       return list;
  #|     }
  #|
  #|     const emptyNodeList = makeNodeList([]);
  #|
  #|     function getParentNode(node) {
  #|       if (!node) return null;
  #|       if ('parentNode' in node) return node.parentNode;
  #|       if ('_parent' in node) return node._parent;
  #|       return null;
  #|     }
  #|     function getChildNodesArray(node) {
  #|       if (!node) return [];
  #|       if (node._children) return node._children;
  #|       if ('childNodes' in node && node.childNodes) {
  #|         try { return Array.from(node.childNodes); } catch (e) { return []; }
  #|       }
  #|       return [];
  #|     }
  #|     function getSiblingArray(node) {
  #|       if (!node || !node._parent) return [];
  #|       if (node._parent._children) return node._parent._children;
  #|       return getChildNodesArray(node._parent);
  #|     }
  #|     function traverseTree(root, visit) {
  #|       if (!root) return false;
  #|       if (visit(root) === false) return false;
  #|       if (root._children) {
  #|         for (const child of root._children) {
  #|           if (traverseTree(child, visit) === false) return false;
  #|         }
  #|       }
  #|       return true;
  #|     }
  #|     function normalizeChildArray(children) {
  #|       let i = 0;
  #|       while (i < children.length) {
  #|         const child = children[i];
  #|         if (child && child._nodeType === 3) {
  #|           if (child._textContent === '') {
  #|             children.splice(i, 1);
  #|             child._parent = null;
  #|             if ('parentNode' in child) child.parentNode = null;
  #|             continue;
  #|           }
  #|           while (i + 1 < children.length && children[i + 1] && children[i + 1]._nodeType === 3) {
  #|             const next = children[i + 1];
  #|             if (next._textContent !== '') {
  #|               child._textContent += next._textContent;
  #|             }
  #|             children.splice(i + 1, 1);
  #|             next._parent = null;
  #|             if ('parentNode' in next) next.parentNode = null;
  #|           }
  #|           i += 1;
  #|           continue;
  #|         }
  #|         if (child && typeof child.normalize === 'function') {
  #|           child.normalize();
  #|         }
  #|         i += 1;
  #|       }
  #|     }
  #|     function lookupNamespaceURIImpl(node, prefix) {
  #|       if (!node) return null;
  #|       const pref = prefix === undefined || prefix === null || prefix === '' ? null : String(prefix);
  #|       const nodeType = getNodeType(node);
  #|       if (nodeType === 10) {
  #|         return null;
  #|       }
  #|       if (nodeType === 1) {
  #|         const ns = node._namespaceURI || node.namespaceURI || null;
  #|         const pfx = node._prefix !== undefined ? node._prefix : (node.prefix || null);
  #|         if (pref === 'xml') return 'http://www.w3.org/XML/1998/namespace';
  #|         if (pref === 'xmlns') return 'http://www.w3.org/2000/xmlns/';
  #|         if (ns && pfx === pref) return ns;
  #|         if (ns && pref === null && (pfx === null || pfx === undefined)) return ns;
  #|         if (node._attrList) {
  #|           for (const attr of node._attrList) {
  #|             const attrNs = attr.ns === undefined ? null : attr.ns;
  #|             const attrPrefix = attr.prefix === undefined ? null : attr.prefix;
  #|             const attrLocal = attr.localName;
  #|             if (attrNs === 'http://www.w3.org/2000/xmlns/') {
  #|               if (attrPrefix === 'xmlns' && attrLocal === pref) return attr.value || null;
  #|               if ((attrLocal === 'xmlns' || attr.name === 'xmlns') && pref === null) return attr.value || null;
  #|             }
  #|             if (attrPrefix === 'xmlns' && attrLocal === pref) return attr.value || null;
  #|             if ((attrLocal === 'xmlns' || attr.name === 'xmlns') && pref === null) return attr.value || null;
  #|           }
  #|         }
  #|         const parent = getParentNode(node);
  #|         if (parent && getNodeType(parent) === 9) return null;
  #|         return parent ? lookupNamespaceURIImpl(parent, pref) : null;
  #|       }
  #|       if (nodeType === 9) {
  #|         const root = node.documentElement || (node._children ? node._children.find(n => n._nodeType === 1) : null);
  #|         return root ? lookupNamespaceURIImpl(root, pref) : null;
  #|       }
  #|       if (nodeType === 2) {
  #|         return node.ownerElement ? lookupNamespaceURIImpl(node.ownerElement, pref) : null;
  #|       }
  #|       const parent = getParentNode(node);
  #|       if (parent && getNodeType(parent) === 9) return null;
  #|       return parent ? lookupNamespaceURIImpl(parent, pref) : null;
  #|     }
  #|     function isNodeLike(node) {
  #|       return !!(node && typeof node === 'object' && (node._nodeType !== undefined || typeof node.nodeType === 'number'));
  #|     }
  #|     function isAllowedChildNodeTypeForElement(nodeType) {
  #|       return nodeType === 1 || nodeType === 3 || nodeType === 4 || nodeType === 7 || nodeType === 8 || nodeType === 11;
  #|     }
  #|     function nodeContains(reference, other) {
  #|       if (!other) return false;
  #|       let node = other;
  #|       while (node) {
  #|         if (node === reference) return true;
  #|         node = getParentNode(node);
  #|       }
  #|       return false;
  #|     }
  #|     function getRootNodeInternal(node) {
  #|       let n = node;
  #|       let parent = getParentNode(n);
  #|       while (parent) {
  #|         n = parent;
  #|         parent = getParentNode(n);
  #|       }
  #|       return n;
  #|     }
  #|     function getRootNodePublic(node) {
  #|       const root = getRootNodeInternal(node);
  #|       if (root && getNodeType(root) === 9) {
  #|         const docEl = root.documentElement || (root._children ? root._children.find(n => n && n._nodeType === 1) : null);
  #|         return docEl || root;
  #|       }
  #|       return root;
  #|     }
  #|     function isConnectedToDocument(node) {
  #|       const root = getRootNodeInternal(node);
  #|       return root && getNodeType(root) === 9;
  #|     }
  #|     function compareDocumentPositionImpl(reference, other) {
  #|       if (!isNodeLike(other)) {
  #|         throw new TypeError('Failed to execute compareDocumentPosition: parameter 1 is not of type Node');
  #|       }
  #|       if (reference === other) return 0;
  #|       const refRoot = getRootNodeInternal(reference);
  #|       const otherRoot = getRootNodeInternal(other);
  #|       if (refRoot !== otherRoot) {
  #|         return Node.DOCUMENT_POSITION_DISCONNECTED |
  #|           Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC |
  #|           Node.DOCUMENT_POSITION_PRECEDING;
  #|       }
  #|       if (nodeContains(other, reference)) {
  #|         return Node.DOCUMENT_POSITION_CONTAINS | Node.DOCUMENT_POSITION_PRECEDING;
  #|       }
  #|       if (nodeContains(reference, other)) {
  #|         return Node.DOCUMENT_POSITION_CONTAINED_BY | Node.DOCUMENT_POSITION_FOLLOWING;
  #|       }
  #|       const order = [];
  #|       const walk = (node) => {
  #|         order.push(node);
  #|         const children = getChildNodesArray(node);
  #|         for (const child of children) walk(child);
  #|       };
  #|       walk(refRoot);
  #|       const refIndex = order.indexOf(reference);
  #|       const otherIndex = order.indexOf(other);
  #|       if (refIndex === -1 || otherIndex === -1) {
  #|         return Node.DOCUMENT_POSITION_DISCONNECTED |
  #|           Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC |
  #|           Node.DOCUMENT_POSITION_PRECEDING;
  #|       }
  #|       return otherIndex < refIndex
  #|         ? Node.DOCUMENT_POSITION_PRECEDING
  #|         : Node.DOCUMENT_POSITION_FOLLOWING;
  #|     }
  #|     function documentHasElement(doc, exclude) {
  #|       return (doc._children || []).some(n => n._nodeType === 1 && n !== exclude);
  #|     }
  #|     function documentHasDoctype(doc, exclude) {
  #|       return (doc._children || []).some(n => n._nodeType === 10 && n !== exclude);
  #|     }
  #|     function documentDoctype(doc, exclude) {
  #|       return (doc._children || []).find(n => n._nodeType === 10 && n !== exclude) || null;
  #|     }
  #|     function validateDocumentInsert(doc, node, refChild, excludeChild) {
  #|       const exclude = (excludeChild === undefined) ? null : excludeChild;
  #|       const excludeType = exclude ? getNodeType(exclude) : null;
  #|       const excludeElement = excludeType === 1 ? exclude : null;
  #|       const excludeDoctype = excludeType === 10 ? exclude : null;
  #|       const nodeType = getNodeType(node);
  #|       if (nodeType === 9 || nodeType === 2) {
  #|         throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|       }
  #|       if (nodeType === 3) {
  #|         throw new DOMException('Cannot insert a text node into document', 'HierarchyRequestError');
  #|       }
  #|       if (nodeType === 10) {
  #|         if (documentHasDoctype(doc, excludeDoctype)) throw new DOMException('Document already has a doctype', 'HierarchyRequestError');
  #|         const element = (doc._children || []).find(n => n._nodeType === 1 && n !== excludeElement) || null;
  #|         if (element) {
  #|           if (refChild) {
  #|             const elemIdx = doc._children.indexOf(element);
  #|             const refIdx = doc._children.indexOf(refChild);
  #|             if (refIdx > elemIdx) {
  #|               throw new DOMException('Cannot insert doctype after element', 'HierarchyRequestError');
  #|             }
  #|           } else {
  #|             throw new DOMException('Cannot insert doctype after element', 'HierarchyRequestError');
  #|           }
  #|         }
  #|         return;
  #|       }
  #|       if (nodeType === 11) {
  #|         const children = node._children || [];
  #|         let elementCount = 0;
  #|         let hasText = false;
  #|         let hasDoctype = false;
  #|         for (const child of children) {
  #|           const ctype = getNodeType(child);
  #|           if (ctype === 1) elementCount++;
  #|           else if (ctype === 3) hasText = true;
  #|           else if (ctype === 10) hasDoctype = true;
  #|         }
  #|         if (hasText || hasDoctype || elementCount > 1) {
  #|           throw new DOMException('Invalid DocumentFragment for document', 'HierarchyRequestError');
  #|         }
  #|         if (elementCount === 1) {
  #|           if (documentHasElement(doc, excludeElement)) {
  #|             throw new DOMException('Document already has an element', 'HierarchyRequestError');
  #|           }
  #|           const doctype = documentDoctype(doc, excludeDoctype);
  #|           if (doctype && refChild) {
  #|             const doctypeIdx = doc._children.indexOf(doctype);
  #|             const refIdx = doc._children.indexOf(refChild);
  #|             if (refIdx <= doctypeIdx) {
  #|               throw new DOMException('Cannot insert element before doctype', 'HierarchyRequestError');
  #|             }
  #|           }
  #|         }
  #|         return;
  #|       }
  #|       if (nodeType === 1) {
  #|         if (documentHasElement(doc, excludeElement)) {
  #|           throw new DOMException('Document already has an element', 'HierarchyRequestError');
  #|         }
  #|         const doctype = documentDoctype(doc, excludeDoctype);
  #|         if (doctype && refChild) {
  #|           const doctypeIdx = doc._children.indexOf(doctype);
  #|           const refIdx = doc._children.indexOf(refChild);
  #|           if (refIdx <= doctypeIdx) {
  #|             throw new DOMException('Cannot insert element before doctype', 'HierarchyRequestError');
  #|           }
  #|         }
  #|         return;
  #|       }
  #|       if (nodeType === 7 || nodeType === 8) {
  #|         return;
  #|       }
  #|       throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|     }
  #|     function getGlobalDocument() {
  #|       if (typeof globalThis !== 'undefined' && globalThis.document) return globalThis.document;
  #|       return null;
  #|     }
  #|     function getNodeType(node) {
  #|       return node && node._nodeType !== undefined ? node._nodeType : (node ? node.nodeType : undefined);
  #|     }
  #|     function getOwnerDocument(node) {
  #|       if (!node) return getGlobalDocument();
  #|       if (node._nodeType === 9) return node;
  #|       if (node._ownerDocument) return node._ownerDocument;
  #|       const globalDoc = getGlobalDocument();
  #|       if (globalDoc) return globalDoc;
  #|       return null;
  #|     }
  #|     function adoptSubtree(node, doc) {
  #|       if (!node || !doc) return;
  #|       if (node._nodeType === 9) return;
  #|       if ('ownerDocument' in node) node.ownerDocument = doc;
  #|       if ('_ownerDocument' in node) node._ownerDocument = doc;
  #|       if (node._children) {
  #|         for (const child of node._children) {
  #|           adoptSubtree(child, doc);
  #|         }
  #|       }
  #|     }
  #|     function detachNode(node) {
  #|       if (!node) return;
  #|       const doc = getOwnerDocument(node);
  #|       if (doc && isConnectedToDocument(node)) unindexSubtree(node, doc);
  #|       if (!node._parent) return;
  #|       if (typeof node._parent.removeChild === 'function') {
  #|         node._parent.removeChild(node);
  #|       } else if (Array.isArray(node._parent._children)) {
  #|         const idx = node._parent._children.indexOf(node);
  #|         if (idx >= 0) node._parent._children.splice(idx, 1);
  #|       }
  #|       node._parent = null;
  #|       if ('parentNode' in node) node.parentNode = null;
  #|     }
  #|     function collectElements(root, includeRoot, predicate) {
  #|       const results = [];
  #|       if (!root) return results;
  #|       traverseTree(root, (node) => {
  #|         if (node._nodeType !== 1) return;
  #|         if (!includeRoot && node === root) return;
  #|         if (predicate(node)) results.push(node);
  #|       });
  #|       return results;
  #|     }
  #|     function ensureDocumentIndexes(doc) {
  #|       if (!doc) return null;
  #|       if (!doc._classIndex) doc._classIndex = new Map();
  #|       if (!doc._tagIndex) doc._tagIndex = new Map();
  #|       if (doc._elementCount === undefined) doc._elementCount = 0;
  #|       return doc;
  #|     }
  #|     function tagKeyForElement(el) {
  #|       if (!el) return '';
  #|       if (el._namespaceURI === 'http://www.w3.org/1999/xhtml') {
  #|         return asciiLowercase(el._tagName || '');
  #|       }
  #|       return el._tagName || '';
  #|     }
  #|     function getClassTokensFromValue(value) {
  #|       if (value === null || value === undefined) return [];
  #|       const str = String(value);
  #|       return splitAsciiWhitespace(str);
  #|     }
  #|     function indexElement(el, doc) {
  #|       if (!el || el._nodeType !== 1) return;
  #|       const targetDoc = ensureDocumentIndexes(doc);
  #|       if (!targetDoc) return;
  #|       if (el._indexed) return;
  #|       el._indexed = true;
  #|       targetDoc._elementCount = (targetDoc._elementCount || 0) + 1;
  #|       const tagKey = tagKeyForElement(el);
  #|       if (tagKey) {
  #|         let set = targetDoc._tagIndex.get(tagKey);
  #|         if (!set) { set = new Set(); targetDoc._tagIndex.set(tagKey, set); }
  #|         set.add(el);
  #|       }
  #|       const classAttr = el.getAttribute ? el.getAttribute('class') : null;
  #|       const tokens = getClassTokensFromValue(classAttr);
  #|       for (const token of tokens) {
  #|         let set = targetDoc._classIndex.get(token);
  #|         if (!set) { set = new Set(); targetDoc._classIndex.set(token, set); }
  #|         set.add(el);
  #|       }
  #|     }
  #|     function unindexElement(el, doc) {
  #|       if (!el || el._nodeType !== 1 || !doc) return;
  #|       if (!el._indexed) return;
  #|       el._indexed = false;
  #|       doc._elementCount = Math.max(0, (doc._elementCount || 0) - 1);
  #|       const classIndex = doc._classIndex;
  #|       const tagIndex = doc._tagIndex;
  #|       if (tagIndex) {
  #|         const tagKey = tagKeyForElement(el);
  #|         const set = tagIndex.get(tagKey);
  #|         if (set) {
  #|           set.delete(el);
  #|           if (set.size === 0) tagIndex.delete(tagKey);
  #|         }
  #|       }
  #|       if (classIndex) {
  #|         const classAttr = el.getAttribute ? el.getAttribute('class') : null;
  #|         const tokens = getClassTokensFromValue(classAttr);
  #|         for (const token of tokens) {
  #|           const set = classIndex.get(token);
  #|           if (!set) continue;
  #|           set.delete(el);
  #|           if (set.size === 0) classIndex.delete(token);
  #|         }
  #|       }
  #|     }
  #|     function indexSubtree(node, doc) {
  #|       if (!node) return;
  #|       const targetDoc = ensureDocumentIndexes(doc);
  #|       if (!targetDoc) return;
  #|       traverseTree(node, (n) => {
  #|         if (n._nodeType === 1) indexElement(n, targetDoc);
  #|       });
  #|     }
  #|     function unindexSubtree(node, doc) {
  #|       if (!node || !doc) return;
  #|       traverseTree(node, (n) => {
  #|         if (n._nodeType === 1) unindexElement(n, doc);
  #|       });
  #|     }
  #|     function updateClassIndex(el, oldValue, newValue) {
  #|       if (!el || el._nodeType !== 1) return;
  #|       if (!isConnectedToDocument(el)) return;
  #|       const doc = ensureDocumentIndexes(getOwnerDocument(el));
  #|       if (!doc) return;
  #|       const oldTokens = new Set(getClassTokensFromValue(oldValue));
  #|       const newTokens = new Set(getClassTokensFromValue(newValue));
  #|       for (const token of oldTokens) {
  #|         if (!newTokens.has(token)) {
  #|           const set = doc._classIndex.get(token);
  #|           if (set) {
  #|             set.delete(el);
  #|             if (set.size === 0) doc._classIndex.delete(token);
  #|           }
  #|         }
  #|       }
  #|       for (const token of newTokens) {
  #|         if (!oldTokens.has(token)) {
  #|           let set = doc._classIndex.get(token);
  #|           if (!set) { set = new Set(); doc._classIndex.set(token, set); }
  #|           set.add(el);
  #|         }
  #|       }
  #|     }
  #|     function getCandidatesByFilter(root, includeRoot, filter, allowLarge) {
  #|       if (!filter) return null;
  #|       if (!isConnectedToDocument(root) && getNodeType(root) !== 9) return null;
  #|       const doc = ensureDocumentIndexes(getOwnerDocument(root));
  #|       if (!doc) return null;
  #|       let candidates = null;
  #|       if (filter.kind === 'class') {
  #|         const tokens = filter.tokens || [];
  #|         if (tokens.length === 1) {
  #|           const set = doc._classIndex.get(tokens[0]);
  #|           if (!set) return [];
  #|           candidates = set;
  #|         } else {
  #|           for (const token of tokens) {
  #|             const set = doc._classIndex.get(token);
  #|             if (!set) return [];
  #|             if (candidates === null) {
  #|               candidates = new Set(set);
  #|             } else {
  #|               for (const el of Array.from(candidates)) {
  #|                 if (!set.has(el)) candidates.delete(el);
  #|               }
  #|             }
  #|             if (candidates.size === 0) return [];
  #|           }
  #|         }
  #|       } else if (filter.kind === 'tag') {
  #|         const name = String(filter.name);
  #|         if (name === '*') return null;
  #|         const lower = asciiLowercase(name);
  #|         const set1 = doc._tagIndex.get(name);
  #|         const set2 = lower === name ? null : doc._tagIndex.get(lower);
  #|         if (!set1 && !set2) return [];
  #|         if (set1 && !set2) {
  #|           candidates = set1;
  #|         } else if (!set1 && set2) {
  #|           candidates = set2;
  #|         } else {
  #|           candidates = new Set();
  #|           if (set1) for (const el of set1) candidates.add(el);
  #|           if (set2) for (const el of set2) candidates.add(el);
  #|         }
  #|       } else if (filter.kind === 'id') {
  #|         const el = doc.getElementById ? doc.getElementById(filter.id) : null;
  #|         candidates = new Set(el ? [el] : []);
  #|       }
  #|       if (!candidates) return null;
  #|       if (!allowLarge && filter.kind !== 'id') {
  #|         const total = doc._elementCount || 0;
  #|         if (total > 0 && candidates.size > total * 0.7) return null;
  #|       }
  #|       const list = [];
  #|       if (candidates.size > 64) {
  #|         traverseTree(root, (node) => {
  #|           if (node._nodeType !== 1) return;
  #|           if (!includeRoot && node === root) return;
  #|           if (!candidates.has(node)) return;
  #|           if (!applySimpleFilter(node, filter)) return;
  #|           list.push(node);
  #|         });
  #|         return list;
  #|       }
  #|       for (const el of candidates) {
  #|         if (!includeRoot && el === root) continue;
  #|         if (!nodeContains(root, el)) continue;
  #|         if (!applySimpleFilter(el, filter)) continue;
  #|         list.push(el);
  #|       }
  #|       if (list.length > 1) {
  #|         list.sort((a, b) => {
  #|           if (a === b) return 0;
  #|           const pos = compareDocumentPositionImpl(a, b);
  #|           return (pos & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1;
  #|         });
  #|       }
  #|       return list;
  #|     }
  #|     function normalizeNamespace(ns) {
  #|       if (ns === undefined || ns === null || ns === '') return null;
  #|       return ns;
  #|     }
  #|     function asciiLowercase(value) {
  #|       return String(value).replace(/[A-Z]/g, c => c.toLowerCase());
  #|     }
  #|     function matchesNamespace(node, ns) {
  #|       if (ns === '*' || ns === undefined) return true;
  #|       return node._namespaceURI === normalizeNamespace(ns);
  #|     }
  #|     function matchesTagName(node, tag) {
  #|       if (tag === '*') return true;
  #|       const name = String(tag);
  #|       if (node._namespaceURI === 'http://www.w3.org/1999/xhtml') {
  #|         const lower = asciiLowercase(name);
  #|         if (name.indexOf(':') >= 0) {
  #|           return asciiLowercase(node._tagName) === lower;
  #|         }
  #|         return node.localName === lower;
  #|       }
  #|       return node._tagName === name;
  #|     }
  #|     function matchesTagNameNS(node, tag) {
  #|       if (tag === '*') return true;
  #|       const name = String(tag);
  #|       return node.localName === name;
  #|     }
  #|     function isAsciiWhitespaceChar(ch) {
  #|       return ch === ' ' || ch === '\\t' || ch === '\\n' || ch === '\\f' || ch === '\\r';
  #|     }
  #|     function splitAsciiWhitespace(str) {
  #|       const tokens = [];
  #|       let current = '';
  #|       for (let i = 0; i < str.length; i++) {
  #|         const ch = str[i];
  #|         if (isAsciiWhitespaceChar(ch)) {
  #|           if (current !== '') { tokens.push(current); current = ''; }
  #|         } else {
  #|           current += ch;
  #|         }
  #|       }
  #|       if (current !== '') tokens.push(current);
  #|       return tokens;
  #|     }
  #|     function containsAsciiWhitespace(str) {
  #|       for (let i = 0; i < str.length; i++) {
  #|         if (isAsciiWhitespaceChar(str[i])) return true;
  #|       }
  #|       return false;
  #|     }
  #|     function isHexDigit(ch) {
  #|       return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F');
  #|     }
  #|     function isCssIdentDelimiter(ch) {
  #|       return isAsciiWhitespaceChar(ch) || ch === '.' || ch === '#' || ch === '[' || ch === ']' || ch === ':' ||
  #|         ch === '>' || ch === '+' || ch === '~' || ch === ',' || ch === ')';
  #|     }
  #|     function consumeCssEscape(str, index) {
  #|       if (index + 1 >= str.length) {
  #|         return { char: '\\uFFFD', nextIndex: str.length };
  #|       }
  #|       const next = str[index + 1];
  #|       if (next === '\\n' || next === '\\f') {
  #|         return { char: '', nextIndex: index + 2 };
  #|       }
  #|       if (next === '\\r') {
  #|         let nextIndex = index + 2;
  #|         if (str[nextIndex] === '\\n') nextIndex += 1;
  #|         return { char: '', nextIndex };
  #|       }
  #|       if (isHexDigit(next)) {
  #|         let hex = '';
  #|         let j = index + 1;
  #|         for (let count = 0; count < 6 && j < str.length && isHexDigit(str[j]); count++, j++) {
  #|           hex += str[j];
  #|         }
  #|         let code = parseInt(hex, 16);
  #|         if (j < str.length && isAsciiWhitespaceChar(str[j])) {
  #|           if (str[j] === '\\r' && str[j + 1] === '\\n') {
  #|             j += 2;
  #|           } else {
  #|             j += 1;
  #|           }
  #|         }
  #|         if (!code || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
  #|           code = 0xFFFD;
  #|         }
  #|         return { char: String.fromCodePoint(code), nextIndex: j };
  #|       }
  #|       return { char: next, nextIndex: index + 2 };
  #|     }
  #|     function readCssIdentifier(str, start) {
  #|       let value = '';
  #|       let i = start;
  #|       while (i < str.length) {
  #|         const ch = str[i];
  #|         if (ch === '\\u0000') {
  #|           value += '\\uFFFD';
  #|           i += 1;
  #|           continue;
  #|         }
  #|         if (ch === '\\\\') {
  #|           const esc = consumeCssEscape(str, i);
  #|           value += esc.char;
  #|           i = esc.nextIndex;
  #|           continue;
  #|         }
  #|         if (isCssIdentDelimiter(ch)) break;
  #|         value += ch;
  #|         i += 1;
  #|       }
  #|       return { value, end: i };
  #|     }
  #|     function bufEndsWithHexEscape(buf) {
  #|       let i = buf.length - 1;
  #|       let count = 0;
  #|       while (i >= 0 && count < 6 && isHexDigit(buf[i])) {
  #|         i -= 1;
  #|         count += 1;
  #|       }
  #|       if (count === 0) return false;
  #|       return i >= 0 && buf[i] === '\\\\';
  #|     }
  #|     function isWhitespaceAfterHexEscape(str, index) {
  #|       let i = index - 1;
  #|       let count = 0;
  #|       while (i >= 0 && count < 6 && isHexDigit(str[i])) {
  #|         i -= 1;
  #|         count += 1;
  #|       }
  #|       if (count === 0) return false;
  #|       return i >= 0 && str[i] === '\\\\';
  #|     }
  #|     function normalizeSelectorEscapes(selector) {
  #|       let str = String(selector);
  #|       // Consume a single whitespace after hex escapes, per CSS syntax.
  #|       str = str.replace(/\\\\([0-9a-fA-F]{1,6})(\\r\\n|[\\t\\n\\r\\f ])/g, '\\\\$1');
  #|       return str;
  #|     }
  #|     function parseClassTokens(input) {
  #|       const str = String(input);
  #|       return splitAsciiWhitespace(str);
  #|     }
  #|     function matchesClassTokens(node, tokens) {
  #|       if (tokens.length === 0) return false;
  #|       for (const token of tokens) {
  #|         if (!node.classList || !node.classList.contains(token)) return false;
  #|       }
  #|       return true;
  #|     }
  #|     function findAttributeForSelector(el, name) {
  #|       if (!el || !el._attrList) return null;
  #|       const rawName = String(name);
  #|       const isHtml = el._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|       const pipeIdx = rawName.indexOf('|');
  #|       if (pipeIdx >= 0) {
  #|         const prefix = rawName.slice(0, pipeIdx);
  #|         const local = rawName.slice(pipeIdx + 1);
  #|         const matchLocal = isHtml ? asciiLowercase(local) : local;
  #|         if (prefix === '*') {
  #|           return el._attrList.find(a => {
  #|             const aLocal = (a.localName !== undefined && a.localName !== null) ? a.localName : a.name;
  #|             return (isHtml ? asciiLowercase(aLocal) : aLocal) === matchLocal;
  #|           }) || null;
  #|         }
  #|         return el._attrList.find(a => {
  #|           const aLocal = (a.localName !== undefined && a.localName !== null) ? a.localName : a.name;
  #|           const aPrefix = a.prefix || '';
  #|           return aPrefix === prefix && (isHtml ? asciiLowercase(aLocal) : aLocal) === matchLocal;
  #|         }) || null;
  #|       }
  #|       if (isHtml) {
  #|         const lower = asciiLowercase(rawName);
  #|         return el._attrList.find(a => asciiLowercase(a.name) === lower) || null;
  #|       }
  #|       return el._attrList.find(a => a.name === rawName) || null;
  #|     }
  #|     function parseAttributeSelector(segment) {
  #|       const inner = segment.slice(1, -1).trim();
  #|       if (!inner) return null;
  #|       let name = '';
  #|       let operator = null;
  #|       let value = null;
  #|       let flag = null;
  #|       let inQuote = null;
  #|       let eqIdx = -1;
  #|       for (let i = 0; i < inner.length; i++) {
  #|         const ch = inner[i];
  #|         if (inQuote) {
  #|           if (ch === inQuote) inQuote = null;
  #|           continue;
  #|         }
  #|         if (ch === '"' || ch === "'") { inQuote = ch; continue; }
  #|         if (ch === '=') { eqIdx = i; break; }
  #|       }
  #|       if (eqIdx < 0) {
  #|         name = inner;
  #|         return { name: name.trim(), operator: null, value: null, flag: null };
  #|       }
  #|       const prev = inner[eqIdx - 1];
  #|       if (prev === '~' || prev === '|' || prev === '^' || prev === '$' || prev === '*') {
  #|         operator = prev + '=';
  #|         name = inner.slice(0, eqIdx - 1).trim();
  #|       } else {
  #|         operator = '=';
  #|         name = inner.slice(0, eqIdx).trim();
  #|       }
  #|       let rest = inner.slice(eqIdx + 1).trim();
  #|       if (!rest) return { name, operator, value: '', flag: null };
  #|       if (rest[0] === '"' || rest[0] === "'") {
  #|         const quote = rest[0];
  #|         let end = 1;
  #|         for (; end < rest.length; end++) {
  #|           if (rest[end] === quote) break;
  #|         }
  #|         value = rest.slice(1, end);
  #|         rest = rest.slice(end + 1).trim();
  #|       } else {
  #|         let end = 0;
  #|         while (end < rest.length && !isAsciiWhitespaceChar(rest[end]) && rest[end] !== ']') end++;
  #|         value = rest.slice(0, end);
  #|         rest = rest.slice(end).trim();
  #|       }
  #|       if (rest.length > 0) {
  #|         const ch = rest[0];
  #|         if (ch === 'i' || ch === 'I' || ch === 's' || ch === 'S') {
  #|           flag = ch.toLowerCase();
  #|         }
  #|       }
  #|       return { name, operator, value, flag };
  #|     }
  #|     function decodeHtmlEntities(value) {
  #|       const named = {
  #|         'lt': '<',
  #|         'gt': '>',
  #|         'amp': '&',
  #|         'quot': '"',
  #|         'apos': "'",
  #|         'nbsp': '\\u00A0'
  #|       };
  #|       return String(value).replace(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, function(_, inner) {
  #|         if (!inner) return '&' + inner + ';';
  #|         if (inner[0] === '#') {
  #|           const hex = inner[1] === 'x' || inner[1] === 'X';
  #|           const num = hex ? parseInt(inner.slice(2), 16) : parseInt(inner.slice(1), 10);
  #|           if (!num || num > 0x10FFFF || (num >= 0xD800 && num <= 0xDFFF)) return '\\uFFFD';
  #|           return String.fromCodePoint(num);
  #|         }
  #|         return named[inner] || ('&' + inner + ';');
  #|       });
  #|     }
  #|     function parseHtmlAttributes(text) {
  #|       const attrs = [];
  #|       const re = /([^\\s=\\/>]+)(?:\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'>]+)))?/g;
  #|       let m;
  #|       while ((m = re.exec(text)) !== null) {
  #|         const name = m[1];
  #|         const value = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : ''));
  #|         attrs.push({ name, value: decodeHtmlEntities(value) });
  #|       }
  #|       return attrs;
  #|     }
  #|     function parseHtmlFragment(html, ownerDoc) {
  #|       const doc = ownerDoc || document;
  #|       const frag = doc.createDocumentFragment();
  #|       const voidTags = {
  #|         area: true, base: true, br: true, col: true, embed: true, hr: true,
  #|         img: true, input: true, link: true, meta: true, param: true, source: true,
  #|         track: true, wbr: true
  #|       };
  #|       const stack = [frag];
  #|       const tokenRe = /<!--[\\s\\S]*?-->|<\\/?[A-Za-z0-9:_-]+[^>]*>|[^<]+/g;
  #|       let match;
  #|       while ((match = tokenRe.exec(String(html))) !== null) {
  #|         const token = match[0];
  #|         const current = stack[stack.length - 1];
  #|         if (token.startsWith('<!--')) {
  #|           const text = token.slice(4, -3);
  #|           current.appendChild(doc.createComment(text));
  #|           continue;
  #|         }
  #|         if (token.startsWith('</')) {
  #|           const endName = asciiLowercase(token.slice(2, -1).trim());
  #|           for (let i = stack.length - 1; i > 0; i--) {
  #|             const el = stack[i];
  #|             if (el && el._tagName && asciiLowercase(el._tagName) === endName) {
  #|               stack.length = i;
  #|               break;
  #|             }
  #|           }
  #|           continue;
  #|         }
  #|         if (token.startsWith('<')) {
  #|           const selfClosing = token.endsWith('/>');
  #|           const inner = token.slice(1, token.length - (selfClosing ? 2 : 1)).trim();
  #|           if (!inner) continue;
  #|           const parts = inner.split(/\\s+/, 1);
  #|           const tagName = parts[0];
  #|           const attrText = inner.slice(tagName.length);
  #|           const el = doc.createElement(tagName);
  #|           const attrs = parseHtmlAttributes(attrText);
  #|           for (const attr of attrs) {
  #|             try { el.setAttribute(attr.name, attr.value); } catch (e) {}
  #|           }
  #|           current.appendChild(el);
  #|           const lower = asciiLowercase(tagName);
  #|           if (!selfClosing && !voidTags[lower]) {
  #|             stack.push(el);
  #|           }
  #|           continue;
  #|         }
  #|         const text = decodeHtmlEntities(token);
  #|         if (text !== '') {
  #|           current.appendChild(doc.createTextNode(text));
  #|         }
  #|       }
  #|       return frag._children ? frag._children.slice() : [];
  #|     }
  #|     function matchesSimpleSelector(el, selector, scopeRoot) {
  #|       const sel = trimAsciiWhitespace(selector);
  #|       if (!sel) return false;
  #|       if (sel === '*') return true;
  #|       let rest = sel;
  #|       let ns = null;
  #|       let tagPart = null;
  #|       if (!rest.startsWith(':') && !rest.startsWith('[') && !rest.startsWith('.') && !rest.startsWith('#')) {
  #|         const pipeIdx = rest.indexOf('|');
  #|         if (pipeIdx >= 0) {
  #|           ns = rest.slice(0, pipeIdx);
  #|           rest = rest.slice(pipeIdx + 1);
  #|         }
  #|         const tagMatch = rest.match(/^[^.#\\[:]+/);
  #|         if (tagMatch) {
  #|           tagPart = tagMatch[0];
  #|           rest = rest.slice(tagPart.length);
  #|         }
  #|       }
  #|       const idMatches = [];
  #|       const classMatches = [];
  #|       const attrMatches = [];
  #|       const pseudoMatches = [];
  #|       let i = 0;
  #|       while (i < rest.length) {
  #|         const ch = rest[i];
  #|         if (ch === '#') {
  #|           const res = readCssIdentifier(rest, i + 1);
  #|           if (res.value === '') return false;
  #|           idMatches.push(res.value);
  #|           i = res.end;
  #|           continue;
  #|         }
  #|         if (ch === '.') {
  #|           const res = readCssIdentifier(rest, i + 1);
  #|           if (res.value === '') return false;
  #|           classMatches.push(res.value);
  #|           i = res.end;
  #|           continue;
  #|         }
  #|         if (ch === '[') {
  #|           const end = rest.indexOf(']', i + 1);
  #|           if (end < 0) return false;
  #|           const attr = parseAttributeSelector(rest.slice(i, end + 1));
  #|           if (!attr) return false;
  #|           attrMatches.push(attr);
  #|           i = end + 1;
  #|           continue;
  #|         }
  #|         if (ch === ':') {
  #|           let j = i + 1;
  #|           while (j < rest.length && /[A-Za-z0-9_-]/.test(rest[j])) j++;
  #|           const name = rest.slice(i + 1, j);
  #|           let arg = null;
  #|           if (rest[j] === '(') {
  #|             let depth = 1;
  #|             let k = j + 1;
  #|             let inQuote = null;
  #|             for (; k < rest.length; k++) {
  #|               const ch2 = rest[k];
  #|               if (inQuote) {
  #|                 if (ch2 === inQuote) inQuote = null;
  #|                 continue;
  #|               }
  #|               if (ch2 === '"' || ch2 === "'") {
  #|                 inQuote = ch2;
  #|                 continue;
  #|               }
  #|               if (ch2 === '(') depth++;
  #|               else if (ch2 === ')') {
  #|                 depth--;
  #|                 if (depth === 0) break;
  #|               }
  #|             }
  #|             arg = rest.slice(j + 1, k);
  #|             j = k + 1;
  #|           }
  #|           pseudoMatches.push({ name, arg });
  #|           i = j;
  #|           continue;
  #|         }
  #|         return false;
  #|       }
  #|       if (tagPart && tagPart !== '*') {
  #|         const name = tagPart;
  #|         const isHtml = el._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|         if (ns && ns !== '*') {
  #|           // Prefix resolution not supported; treat as wildcard
  #|         }
  #|         if (isHtml) {
  #|           const lower = asciiLowercase(name);
  #|           if (name.indexOf(':') >= 0) {
  #|             if (asciiLowercase(el._tagName) !== lower) return false;
  #|           } else {
  #|             if (el.localName !== lower) return false;
  #|           }
  #|         } else {
  #|           if (name.indexOf(':') >= 0) {
  #|             if (el._tagName !== name) return false;
  #|           } else {
  #|             if (el.localName !== name) return false;
  #|           }
  #|         }
  #|       }
  #|       if (idMatches.length > 0) {
  #|         const id = el.getAttribute ? el.getAttribute('id') : null;
  #|         if (!idMatches.every(v => v === id)) return false;
  #|       }
  #|       if (classMatches.length > 0) {
  #|         for (const cls of classMatches) {
  #|           if (!el.classList || !el.classList.contains(cls)) return false;
  #|         }
  #|       }
  #|       if (attrMatches.length > 0) {
  #|         for (const attr of attrMatches) {
  #|           const attrObj = findAttributeForSelector(el, attr.name);
  #|           if (!attrObj) return false;
  #|           if (!attr.operator) continue;
  #|           let actual = attrObj.value === undefined || attrObj.value === null ? '' : String(attrObj.value);
  #|           let expected = attr.value === undefined || attr.value === null ? '' : String(attr.value);
  #|           if (attr.flag === 'i') {
  #|             actual = asciiLowercase(actual);
  #|             expected = asciiLowercase(expected);
  #|           }
  #|           switch (attr.operator) {
  #|             case '=':
  #|               if (actual !== expected) return false;
  #|               break;
  #|             case '^=':
  #|               if (!actual.startsWith(expected)) return false;
  #|               break;
  #|             case '$=':
  #|               if (!actual.endsWith(expected)) return false;
  #|               break;
  #|             case '*=':
  #|               if (actual.indexOf(expected) < 0) return false;
  #|               break;
  #|             case '~=': {
  #|               const tokens = splitAsciiWhitespace(actual);
  #|               if (!tokens.includes(expected)) return false;
  #|               break;
  #|             }
  #|             case '|=':
  #|               if (!(actual === expected || actual.startsWith(expected + '-'))) return false;
  #|               break;
  #|             default:
  #|               if (actual !== expected) return false;
  #|           }
  #|         }
  #|       }
  #|       if (pseudoMatches.length > 0) {
  #|         for (const pseudo of pseudoMatches) {
  #|           const pname = pseudo.name;
  #|           if (pname === 'scope') {
  #|             if (!scopeRoot || el !== scopeRoot) return false;
  #|             continue;
  #|           }
  #|           if (pname === 'not') {
  #|             const argSel = pseudo.arg || '';
  #|             if (argSel && matchesSimpleSelector(el, argSel.trim(), scopeRoot)) return false;
  #|             continue;
  #|           }
  #|           if (pname === 'empty') {
  #|             if (el._children && el._children.length > 0) return false;
  #|             continue;
  #|           }
  #|           if (pname === 'first-child' || pname === 'last-child') {
  #|             const parent = el._parent;
  #|             if (!parent) return false;
  #|             const elems = (parent._children || []).filter(n => n._nodeType === 1);
  #|             if (elems.length === 0) return false;
  #|             if (pname === 'first-child' && elems[0] !== el) return false;
  #|             if (pname === 'last-child' && elems[elems.length - 1] !== el) return false;
  #|             continue;
  #|           }
  #|           if (pname === 'invalid') {
  #|             const isInvalidControl = (node) => {
  #|               if (!node || node._nodeType !== 1) return false;
  #|               if (!node.hasAttribute || !node.hasAttribute('required')) return false;
  #|               const tag = node._tagName;
  #|               if (tag === 'SELECT') {
  #|                 const options = node._children ? node._children.filter(n => n._nodeType === 1 && n._tagName === 'OPTION') : [];
  #|                 const hasSelected = options.some(opt => opt.hasAttribute && opt.hasAttribute('selected'));
  #|                 return !hasSelected;
  #|               }
  #|               const value = node.getAttribute ? node.getAttribute('value') : null;
  #|               return value === null || value === '';
  #|             };
  #|             if (isInvalidControl(el)) continue;
  #|             let invalidDesc = false;
  #|             traverseTree(el, (node) => {
  #|               if (node !== el && isInvalidControl(node)) { invalidDesc = true; return false; }
  #|             });
  #|             if (!invalidDesc) return false;
  #|             continue;
  #|           }
  #|           if (pname === 'has') {
  #|             const argSel = pseudo.arg ? pseudo.arg.trim() : '';
  #|             let found = false;
  #|             if (argSel.startsWith('>')) {
  #|               const inner = argSel.slice(1).trim();
  #|               for (const child of el._children || []) {
  #|                 if (child._nodeType !== 1) continue;
  #|                 if (matchesSelectorGroup(child, inner, scopeRoot)) { found = true; break; }
  #|               }
  #|             } else {
  #|               traverseTree(el, (node) => {
  #|                 if (node === el || node._nodeType !== 1) return;
  #|                 if (matchesSelectorGroup(node, argSel, scopeRoot)) { found = true; return false; }
  #|               });
  #|             }
  #|             if (!found) return false;
  #|             continue;
  #|           }
  #|           return false;
  #|         }
  #|       }
  #|       return true;
  #|     }
  #|     function parseSimpleClassSelector(selector) {
  #|       const sel = trimAsciiWhitespace(selector);
  #|       if (!sel || sel[0] !== '.') return null;
  #|       const classes = [];
  #|       let i = 0;
  #|       while (i < sel.length) {
  #|         if (sel[i] !== '.') return null;
  #|         const res = readCssIdentifier(sel, i + 1);
  #|         if (!res.value) return null;
  #|         classes.push(res.value);
  #|         i = res.end;
  #|       }
  #|       return classes;
  #|     }
  #|     function parseSimpleTagSelector(selector) {
  #|       const sel = trimAsciiWhitespace(selector);
  #|       if (!sel) return null;
  #|       if (sel === '*') return '*';
  #|       if (sel[0] === '.' || sel[0] === '#' || sel[0] === '[' || sel[0] === ':') return null;
  #|       const res = readCssIdentifier(sel, 0);
  #|       if (!res.value) return null;
  #|       if (res.end !== sel.length) return null;
  #|       return res.value;
  #|     }
  #|     function parseSimpleIdSelector(selector) {
  #|       const sel = trimAsciiWhitespace(selector);
  #|       if (!sel || sel[0] !== '#') return null;
  #|       const res = readCssIdentifier(sel, 1);
  #|       if (!res.value) return null;
  #|       if (res.end !== sel.length) return null;
  #|       return res.value;
  #|     }
  #|     function applySimpleFilter(el, filter) {
  #|       if (!filter) return true;
  #|       if (!el || el._nodeType !== 1) return false;
  #|       if (filter.kind === 'class') {
  #|         return matchesClassTokens(el, filter.tokens);
  #|       }
  #|       if (filter.kind === 'tag') {
  #|         return matchesTagName(el, filter.name);
  #|       }
  #|       if (filter.kind === 'id') {
  #|         const id = el.getAttribute ? el.getAttribute('id') : null;
  #|         return id === filter.id;
  #|       }
  #|       return true;
  #|     }
  #|     function tokenizeSelector(selector) {
  #|       const tokens = [];
  #|       let buf = '';
  #|       let combinator = null;
  #|       let inAttr = false;
  #|       let depth = 0;
  #|       let quote = null;
  #|       const rawSelector = String(selector);
  #|       let normalized = '';
  #|       for (let i = 0; i < rawSelector.length; i++) {
  #|         const ch = rawSelector[i];
  #|         if (ch !== '\\\\') {
  #|           normalized += ch;
  #|           continue;
  #|         }
  #|         normalized += ch;
  #|         if (i + 1 >= rawSelector.length) continue;
  #|         let j = i + 1;
  #|         if (isHexDigit(rawSelector[j])) {
  #|           let count = 0;
  #|           while (count < 6 && j < rawSelector.length && isHexDigit(rawSelector[j])) {
  #|             normalized += rawSelector[j];
  #|             j += 1;
  #|             count += 1;
  #|           }
  #|           if (j < rawSelector.length && isAsciiWhitespaceChar(rawSelector[j])) {
  #|             if (rawSelector[j] === '\\r' && rawSelector[j + 1] === '\\n') {
  #|               normalized += rawSelector[j];
  #|               normalized += rawSelector[j + 1];
  #|               j += 1;
  #|             } else {
  #|               normalized += rawSelector[j];
  #|             }
  #|             j += 1;
  #|           }
  #|           i = j - 1;
  #|           continue;
  #|         }
  #|         normalized += rawSelector[j];
  #|         i = j;
  #|       }
  #|       const pushToken = () => {
  #|         const text = buf.trim();
  #|         if (text) {
  #|           tokens.push({ selector: text, combinator });
  #|           combinator = null;
  #|         }
  #|         buf = '';
  #|       };
  #|       for (let i = 0; i < normalized.length; i++) {
  #|         const ch = normalized[i];
  #|         if (ch === '\\\\') {
  #|           buf += ch;
  #|           if (i + 1 < normalized.length) {
  #|             let j = i + 1;
  #|             if (isHexDigit(normalized[j])) {
  #|               let count = 0;
  #|               while (count < 6 && j < normalized.length && isHexDigit(normalized[j])) {
  #|                 buf += normalized[j];
  #|                 j += 1;
  #|                 count += 1;
  #|               }
  #|               if (j < normalized.length && isAsciiWhitespaceChar(normalized[j])) {
  #|                 buf += normalized[j];
  #|                 if (normalized[j] === '\\r' && normalized[j + 1] === '\\n') {
  #|                   buf += normalized[j + 1];
  #|                   j += 1;
  #|                 }
  #|                 j += 1;
  #|               }
  #|               i = j - 1;
  #|               continue;
  #|             }
  #|             buf += normalized[j];
  #|             i = j;
  #|             continue;
  #|           }
  #|           continue;
  #|         }
  #|         if (quote) {
  #|           buf += ch;
  #|           if (ch === quote) quote = null;
  #|           continue;
  #|         }
  #|         if (ch === '"' || ch === "'") {
  #|           quote = ch;
  #|           buf += ch;
  #|           continue;
  #|         }
  #|         if (ch === '[') inAttr = true;
  #|         if (ch === ']') inAttr = false;
  #|         if (!inAttr) {
  #|           if (ch === '(') depth++;
  #|           if (ch === ')') depth = Math.max(0, depth - 1);
  #|         }
  #|         if (!inAttr && depth === 0) {
  #|           if (ch === '>' || ch === '+' || ch === '~') {
  #|             pushToken();
  #|             combinator = ch;
  #|             continue;
  #|           }
  #|           if (ch === ' ') {
  #|             if (bufEndsWithHexEscape(buf) || isWhitespaceAfterHexEscape(normalized, i)) {
  #|               buf += ch;
  #|               continue;
  #|             }
  #|             pushToken();
  #|             if (!combinator) combinator = ' ';
  #|             while (i + 1 < normalized.length && normalized[i + 1] === ' ') i++;
  #|             continue;
  #|           }
  #|         }
  #|         buf += ch;
  #|       }
  #|       pushToken();
  #|       return tokens;
  #|     }
  #|     function trimAsciiWhitespace(str) {
  #|       const s = String(str);
  #|       let start = 0;
  #|       let end = s.length;
  #|       while (start < end && isAsciiWhitespaceChar(s[start])) start += 1;
  #|       while (end > start && isAsciiWhitespaceChar(s[end - 1])) end -= 1;
  #|       return s.slice(start, end);
  #|     }
  #|     function hasUnescapedCombinator(selector) {
  #|       const str = String(selector);
  #|       let inAttr = false;
  #|       let depth = 0;
  #|       let quote = null;
  #|       for (let i = 0; i < str.length; i++) {
  #|         const ch = str[i];
  #|         if (ch === '\\\\') {
  #|           if (i + 1 < str.length && isHexDigit(str[i + 1])) {
  #|             let j = i + 1;
  #|             let count = 0;
  #|             while (count < 6 && j < str.length && isHexDigit(str[j])) {
  #|               j += 1;
  #|               count += 1;
  #|             }
  #|             if (j < str.length && isAsciiWhitespaceChar(str[j])) {
  #|               if (str[j] === '\\r' && str[j + 1] === '\\n') j += 1;
  #|               j += 1;
  #|             }
  #|             i = j - 1;
  #|             continue;
  #|           }
  #|           if (i + 1 < str.length) {
  #|             i += 1;
  #|             continue;
  #|           }
  #|         }
  #|         if (quote) {
  #|           if (ch === quote) quote = null;
  #|           continue;
  #|         }
  #|         if (ch === '"' || ch === "'") {
  #|           quote = ch;
  #|           continue;
  #|         }
  #|         if (ch === '[') inAttr = true;
  #|         if (ch === ']') inAttr = false;
  #|         if (!inAttr) {
  #|           if (ch === '(') depth++;
  #|           if (ch === ')') depth = Math.max(0, depth - 1);
  #|         }
  #|         if (!inAttr && depth === 0) {
  #|           if (ch === '>' || ch === '+' || ch === '~' || ch === ',' || ch === ' ') return true;
  #|         }
  #|       }
  #|       return false;
  #|     }
  #|     const selectorGroupCache = new Map();
  #|     const selectorCache = new Map();
  #|     const MAX_SELECTOR_CACHE = 200;
  #|     function cacheSet(map, key, value) {
  #|       if (map.size > MAX_SELECTOR_CACHE) map.clear();
  #|       map.set(key, value);
  #|       return value;
  #|     }
  #|     function compileSelectorGroup(selector) {
  #|       const key = String(selector);
  #|       const cached = selectorGroupCache.get(key);
  #|       if (cached) return cached;
  #|       const trimmed = trimAsciiWhitespace(key);
  #|       if (!trimmed) return cacheSet(selectorGroupCache, key, { simple: '', tokens: null, filter: null });
  #|       if (!hasUnescapedCombinator(trimmed)) {
  #|         const classTokens = parseSimpleClassSelector(trimmed);
  #|         const tagName = parseSimpleTagSelector(trimmed);
  #|         const idName = parseSimpleIdSelector(trimmed);
  #|         const filter = classTokens
  #|           ? { kind: 'class', tokens: classTokens }
  #|           : (tagName ? { kind: 'tag', name: tagName } : (idName ? { kind: 'id', id: idName } : null));
  #|         return cacheSet(selectorGroupCache, key, { simple: trimmed, tokens: null, filter });
  #|       }
  #|       const tokens = tokenizeSelector(trimmed);
  #|       let filter = null;
  #|       if (tokens.length > 0) {
  #|         const rightmost = tokens[tokens.length - 1].selector;
  #|         const classTokens = parseSimpleClassSelector(rightmost);
  #|         const tagName = parseSimpleTagSelector(rightmost);
  #|         const idName = parseSimpleIdSelector(rightmost);
  #|         filter = classTokens
  #|           ? { kind: 'class', tokens: classTokens }
  #|           : (tagName ? { kind: 'tag', name: tagName } : (idName ? { kind: 'id', id: idName } : null));
  #|       }
  #|       return cacheSet(selectorGroupCache, key, { simple: null, tokens, filter });
  #|     }
  #|     function matchesSelectorGroupCompiled(el, compiled, scopeRoot, skipFilter) {
  #|       if (!compiled) return false;
  #|       if (!skipFilter && compiled.filter && !applySimpleFilter(el, compiled.filter)) return false;
  #|       if (compiled.simple !== null && compiled.simple !== undefined) {
  #|         if (!compiled.simple) return false;
  #|         return matchesSimpleSelector(el, compiled.simple, scopeRoot);
  #|       }
  #|       const tokens = compiled.tokens;
  #|       if (!tokens || tokens.length === 0) return false;
  #|       let current = el;
  #|       for (let i = tokens.length - 1; i >= 0; i--) {
  #|         const token = tokens[i];
  #|         if (!current || current._nodeType !== 1) return false;
  #|         if (!matchesSimpleSelector(current, token.selector, scopeRoot)) return false;
  #|         if (i === 0) return true;
  #|         const comb = token.combinator || ' ';
  #|         const prevToken = tokens[i - 1];
  #|         if (comb === ' ') {
  #|           let ancestor = current._parent;
  #|           let found = null;
  #|           while (ancestor) {
  #|             if (ancestor._nodeType === 1 && matchesSimpleSelector(ancestor, prevToken.selector, scopeRoot)) { found = ancestor; break; }
  #|             ancestor = ancestor._parent;
  #|           }
  #|           if (!found) return false;
  #|           current = found;
  #|           i -= 1;
  #|           continue;
  #|         }
  #|         if (comb === '>') {
  #|           const parent = current._parent;
  #|           if (!parent || parent._nodeType !== 1 || !matchesSimpleSelector(parent, prevToken.selector, scopeRoot)) return false;
  #|           current = parent;
  #|           i -= 1;
  #|           continue;
  #|         }
  #|         if (comb === '+') {
  #|           let prev = current.previousElementSibling;
  #|           if (!prev || !matchesSimpleSelector(prev, prevToken.selector, scopeRoot)) return false;
  #|           current = prev;
  #|           i -= 1;
  #|           continue;
  #|         }
  #|         if (comb === '~') {
  #|           let sib = current.previousElementSibling;
  #|           let found = null;
  #|           while (sib) {
  #|             if (matchesSimpleSelector(sib, prevToken.selector, scopeRoot)) { found = sib; break; }
  #|             sib = sib.previousElementSibling;
  #|           }
  #|           if (!found) return false;
  #|           current = found;
  #|           i -= 1;
  #|           continue;
  #|         }
  #|       }
  #|       return true;
  #|     }
  #|     function compileSelector(selector) {
  #|       const key = String(selector);
  #|       const cached = selectorCache.get(key);
  #|       if (cached) return cached;
  #|       const groups = splitSelectorGroups(key).map(s => trimAsciiWhitespace(s)).filter(Boolean);
  #|       const compiledGroups = groups.map(g => compileSelectorGroup(g));
  #|       return cacheSet(selectorCache, key, { groups: compiledGroups });
  #|     }
  #|     function matchesSelectorGroup(el, selector, scopeRoot) {
  #|       const compiled = compileSelectorGroup(selector);
  #|       return matchesSelectorGroupCompiled(el, compiled, scopeRoot, false);
  #|     }
  #|     function splitSelectorGroups(selector) {
  #|       const str = String(selector);
  #|       const groups = [];
  #|       let buf = '';
  #|       let inAttr = false;
  #|       let depth = 0;
  #|       let quote = null;
  #|       for (let i = 0; i < str.length; i++) {
  #|         const ch = str[i];
  #|         if (ch === '\\\\') {
  #|           buf += ch;
  #|           if (i + 1 < str.length) {
  #|             let j = i + 1;
  #|             if (isHexDigit(str[j])) {
  #|               let count = 0;
  #|               while (count < 6 && j < str.length && isHexDigit(str[j])) {
  #|                 buf += str[j];
  #|                 j += 1;
  #|                 count += 1;
  #|               }
  #|               if (j < str.length && isAsciiWhitespaceChar(str[j])) {
  #|                 if (str[j] === '\\r' && str[j + 1] === '\\n') {
  #|                   buf += str[j];
  #|                   buf += str[j + 1];
  #|                   j += 1;
  #|                 } else {
  #|                   buf += str[j];
  #|                 }
  #|                 j += 1;
  #|               }
  #|               i = j - 1;
  #|               continue;
  #|             }
  #|             buf += str[j];
  #|             i = j;
  #|             continue;
  #|           }
  #|           continue;
  #|         }
  #|         if (quote) {
  #|           buf += ch;
  #|           if (ch === quote) quote = null;
  #|           continue;
  #|         }
  #|         if (ch === '"' || ch === "'") {
  #|           quote = ch;
  #|           buf += ch;
  #|           continue;
  #|         }
  #|         if (ch === '[') inAttr = true;
  #|         if (ch === ']') inAttr = false;
  #|         if (!inAttr) {
  #|           if (ch === '(') depth++;
  #|           if (ch === ')') depth = Math.max(0, depth - 1);
  #|         }
  #|         if (!inAttr && depth === 0 && ch === ',') {
  #|           groups.push(buf);
  #|           buf = '';
  #|           continue;
  #|         }
  #|         buf += ch;
  #|       }
  #|       if (buf !== '') groups.push(buf);
  #|       return groups;
  #|     }
  #|     function matchesSelector(el, selector, scopeRoot) {
  #|       const compiled = compileSelector(selector);
  #|       const groups = compiled.groups || [];
  #|       if (groups.length === 0) return false;
  #|       for (const group of groups) {
  #|         if (matchesSelectorGroupCompiled(el, group, scopeRoot, false)) return true;
  #|       }
  #|       return false;
  #|     }
  #|
  #|     function HTMLElement() {}
  #|     HTMLElement.prototype = Object.create(Element.prototype);
  #|     HTMLElement.prototype.constructor = HTMLElement;
  #|
  #|     function HTMLHtmlElement() {}
  #|     HTMLHtmlElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHtmlElement.prototype.constructor = HTMLHtmlElement;
  #|
  #|     function HTMLHeadElement() {}
  #|     HTMLHeadElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHeadElement.prototype.constructor = HTMLHeadElement;
  #|
  #|     function HTMLBodyElement() {}
  #|     HTMLBodyElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLBodyElement.prototype.constructor = HTMLBodyElement;
  #|
  #|     function HTMLDivElement() {}
  #|     HTMLDivElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDivElement.prototype.constructor = HTMLDivElement;
  #|
  #|     function HTMLSpanElement() {}
  #|     HTMLSpanElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSpanElement.prototype.constructor = HTMLSpanElement;
  #|
  #|     function HTMLTitleElement() {}
  #|     HTMLTitleElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTitleElement.prototype.constructor = HTMLTitleElement;
  #|
  #|     function HTMLAnchorElement() {}
  #|     HTMLAnchorElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLAnchorElement.prototype.constructor = HTMLAnchorElement;
  #|
  #|     function HTMLAreaElement() {}
  #|     HTMLAreaElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLAreaElement.prototype.constructor = HTMLAreaElement;
  #|
  #|     function HTMLAudioElement() {}
  #|     HTMLAudioElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLAudioElement.prototype.constructor = HTMLAudioElement;
  #|
  #|     function HTMLBaseElement() {}
  #|     HTMLBaseElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLBaseElement.prototype.constructor = HTMLBaseElement;
  #|
  #|     function HTMLBRElement() {}
  #|     HTMLBRElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLBRElement.prototype.constructor = HTMLBRElement;
  #|
  #|     function HTMLButtonElement() {}
  #|     HTMLButtonElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLButtonElement.prototype.constructor = HTMLButtonElement;
  #|
  #|     function HTMLCanvasElement() {}
  #|     HTMLCanvasElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLCanvasElement.prototype.constructor = HTMLCanvasElement;
  #|
  #|     function HTMLDataElement() {}
  #|     HTMLDataElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDataElement.prototype.constructor = HTMLDataElement;
  #|
  #|     function HTMLDataListElement() {}
  #|     HTMLDataListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDataListElement.prototype.constructor = HTMLDataListElement;
  #|
  #|     function HTMLDetailsElement() {}
  #|     HTMLDetailsElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDetailsElement.prototype.constructor = HTMLDetailsElement;
  #|
  #|     function HTMLDialogElement() {}
  #|     HTMLDialogElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDialogElement.prototype.constructor = HTMLDialogElement;
  #|
  #|     function HTMLDListElement() {}
  #|     HTMLDListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDListElement.prototype.constructor = HTMLDListElement;
  #|
  #|     function HTMLEmbedElement() {}
  #|     HTMLEmbedElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLEmbedElement.prototype.constructor = HTMLEmbedElement;
  #|
  #|     function HTMLFieldSetElement() {}
  #|     HTMLFieldSetElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFieldSetElement.prototype.constructor = HTMLFieldSetElement;
  #|
  #|     function HTMLFormElement() {}
  #|     HTMLFormElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFormElement.prototype.constructor = HTMLFormElement;
  #|
  #|     function HTMLHRElement() {}
  #|     HTMLHRElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHRElement.prototype.constructor = HTMLHRElement;
  #|
  #|     function HTMLIFrameElement() {}
  #|     HTMLIFrameElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLIFrameElement.prototype.constructor = HTMLIFrameElement;
  #|
  #|     function HTMLImageElement() {}
  #|     HTMLImageElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLImageElement.prototype.constructor = HTMLImageElement;
  #|
  #|     function HTMLInputElement() {}
  #|     HTMLInputElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLInputElement.prototype.constructor = HTMLInputElement;
  #|
  #|     function HTMLLabelElement() {}
  #|     HTMLLabelElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLabelElement.prototype.constructor = HTMLLabelElement;
  #|
  #|     function HTMLLegendElement() {}
  #|     HTMLLegendElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLegendElement.prototype.constructor = HTMLLegendElement;
  #|
  #|     function HTMLLIElement() {}
  #|     HTMLLIElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLIElement.prototype.constructor = HTMLLIElement;
  #|
  #|     function HTMLLinkElement() {}
  #|     HTMLLinkElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLinkElement.prototype.constructor = HTMLLinkElement;
  #|
  #|     function HTMLMapElement() {}
  #|     HTMLMapElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMapElement.prototype.constructor = HTMLMapElement;
  #|
  #|     function HTMLMenuElement() {}
  #|     HTMLMenuElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMenuElement.prototype.constructor = HTMLMenuElement;
  #|
  #|     function HTMLMetaElement() {}
  #|     HTMLMetaElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMetaElement.prototype.constructor = HTMLMetaElement;
  #|
  #|     function HTMLMeterElement() {}
  #|     HTMLMeterElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMeterElement.prototype.constructor = HTMLMeterElement;
  #|
  #|     function HTMLModElement() {}
  #|     HTMLModElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLModElement.prototype.constructor = HTMLModElement;
  #|
  #|     function HTMLObjectElement() {}
  #|     HTMLObjectElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLObjectElement.prototype.constructor = HTMLObjectElement;
  #|
  #|     function HTMLOListElement() {}
  #|     HTMLOListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOListElement.prototype.constructor = HTMLOListElement;
  #|
  #|     function HTMLOptGroupElement() {}
  #|     HTMLOptGroupElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOptGroupElement.prototype.constructor = HTMLOptGroupElement;
  #|
  #|     function HTMLOptionElement() {}
  #|     HTMLOptionElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOptionElement.prototype.constructor = HTMLOptionElement;
  #|
  #|     function HTMLOutputElement() {}
  #|     HTMLOutputElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOutputElement.prototype.constructor = HTMLOutputElement;
  #|
  #|     function HTMLParagraphElement() {}
  #|     HTMLParagraphElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLParagraphElement.prototype.constructor = HTMLParagraphElement;
  #|
  #|     function HTMLPictureElement() {}
  #|     HTMLPictureElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLPictureElement.prototype.constructor = HTMLPictureElement;
  #|
  #|     function HTMLPreElement() {}
  #|     HTMLPreElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLPreElement.prototype.constructor = HTMLPreElement;
  #|
  #|     function HTMLProgressElement() {}
  #|     HTMLProgressElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLProgressElement.prototype.constructor = HTMLProgressElement;
  #|
  #|     function HTMLQuoteElement() {}
  #|     HTMLQuoteElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLQuoteElement.prototype.constructor = HTMLQuoteElement;
  #|
  #|     function HTMLScriptElement() {}
  #|     HTMLScriptElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLScriptElement.prototype.constructor = HTMLScriptElement;
  #|
  #|     function HTMLSelectElement() {}
  #|     HTMLSelectElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSelectElement.prototype.constructor = HTMLSelectElement;
  #|
  #|     function HTMLSlotElement() {}
  #|     HTMLSlotElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSlotElement.prototype.constructor = HTMLSlotElement;
  #|
  #|     function HTMLSourceElement() {}
  #|     HTMLSourceElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSourceElement.prototype.constructor = HTMLSourceElement;
  #|
  #|     function HTMLStyleElement() {}
  #|     HTMLStyleElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLStyleElement.prototype.constructor = HTMLStyleElement;
  #|
  #|     function HTMLTableElement() {}
  #|     HTMLTableElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableElement.prototype.constructor = HTMLTableElement;
  #|
  #|     function HTMLTableCellElement() {}
  #|     HTMLTableCellElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableCellElement.prototype.constructor = HTMLTableCellElement;
  #|
  #|     function HTMLTableColElement() {}
  #|     HTMLTableColElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableColElement.prototype.constructor = HTMLTableColElement;
  #|
  #|     function HTMLTableRowElement() {}
  #|     HTMLTableRowElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableRowElement.prototype.constructor = HTMLTableRowElement;
  #|
  #|     function HTMLTableSectionElement() {}
  #|     HTMLTableSectionElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableSectionElement.prototype.constructor = HTMLTableSectionElement;
  #|
  #|     function HTMLTemplateElement() {}
  #|     HTMLTemplateElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTemplateElement.prototype.constructor = HTMLTemplateElement;
  #|     Object.defineProperty(HTMLTemplateElement.prototype, 'content', {
  #|       get() {
  #|         if (!this._templateContent) {
  #|           const frag = document.createDocumentFragment();
  #|           frag._children = this._children || [];
  #|           this._templateContent = frag;
  #|         }
  #|         return this._templateContent;
  #|       }
  #|     });
  #|
  #|     function HTMLTextAreaElement() {}
  #|     HTMLTextAreaElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTextAreaElement.prototype.constructor = HTMLTextAreaElement;
  #|
  #|     function HTMLTimeElement() {}
  #|     HTMLTimeElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTimeElement.prototype.constructor = HTMLTimeElement;
  #|
  #|     function HTMLTrackElement() {}
  #|     HTMLTrackElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTrackElement.prototype.constructor = HTMLTrackElement;
  #|
  #|     function HTMLUListElement() {}
  #|     HTMLUListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLUListElement.prototype.constructor = HTMLUListElement;
  #|
  #|     function HTMLVideoElement() {}
  #|     HTMLVideoElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLVideoElement.prototype.constructor = HTMLVideoElement;
  #|
  #|     function HTMLUnknownElement() {}
  #|     HTMLUnknownElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLUnknownElement.prototype.constructor = HTMLUnknownElement;
  #|
  #|     function HTMLTableCaptionElement() {}
  #|     HTMLTableCaptionElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableCaptionElement.prototype.constructor = HTMLTableCaptionElement;
  #|
  #|     function HTMLDirectoryElement() {}
  #|     HTMLDirectoryElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDirectoryElement.prototype.constructor = HTMLDirectoryElement;
  #|
  #|     function HTMLFontElement() {}
  #|     HTMLFontElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFontElement.prototype.constructor = HTMLFontElement;
  #|
  #|     function HTMLMarqueeElement() {}
  #|     HTMLMarqueeElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMarqueeElement.prototype.constructor = HTMLMarqueeElement;
  #|
  #|     function HTMLFrameElement() {}
  #|     HTMLFrameElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFrameElement.prototype.constructor = HTMLFrameElement;
  #|
  #|     function HTMLFrameSetElement() {}
  #|     HTMLFrameSetElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFrameSetElement.prototype.constructor = HTMLFrameSetElement;
  #|
  #|     function HTMLParamElement() {}
  #|     HTMLParamElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLParamElement.prototype.constructor = HTMLParamElement;
  #|
  #|     function HTMLHeadingElement() {}
  #|     HTMLHeadingElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHeadingElement.prototype.constructor = HTMLHeadingElement;
  #|
  #|     // Tag to constructor mapping
  #|     const tagToConstructor = {
  #|       'html': HTMLHtmlElement,
  #|       'head': HTMLHeadElement,
  #|       'body': HTMLBodyElement,
  #|       'div': HTMLDivElement,
  #|       'span': HTMLSpanElement,
  #|       'title': HTMLTitleElement,
  #|       'a': HTMLAnchorElement,
  #|       'area': HTMLAreaElement,
  #|       'audio': HTMLAudioElement,
  #|       'base': HTMLBaseElement,
  #|       'br': HTMLBRElement,
  #|       'button': HTMLButtonElement,
  #|       'canvas': HTMLCanvasElement,
  #|       'data': HTMLDataElement,
  #|       'datalist': HTMLDataListElement,
  #|       'details': HTMLDetailsElement,
  #|       'dialog': HTMLDialogElement,
  #|       'dl': HTMLDListElement,
  #|       'embed': HTMLEmbedElement,
  #|       'fieldset': HTMLFieldSetElement,
  #|       'form': HTMLFormElement,
  #|       'h1': HTMLHeadingElement,
  #|       'h2': HTMLHeadingElement,
  #|       'h3': HTMLHeadingElement,
  #|       'h4': HTMLHeadingElement,
  #|       'h5': HTMLHeadingElement,
  #|       'h6': HTMLHeadingElement,
  #|       'hr': HTMLHRElement,
  #|       'iframe': HTMLIFrameElement,
  #|       'img': HTMLImageElement,
  #|       'input': HTMLInputElement,
  #|       'label': HTMLLabelElement,
  #|       'legend': HTMLLegendElement,
  #|       'li': HTMLLIElement,
  #|       'link': HTMLLinkElement,
  #|       'map': HTMLMapElement,
  #|       'menu': HTMLMenuElement,
  #|       'meta': HTMLMetaElement,
  #|       'meter': HTMLMeterElement,
  #|       'del': HTMLModElement,
  #|       'ins': HTMLModElement,
  #|       'object': HTMLObjectElement,
  #|       'ol': HTMLOListElement,
  #|       'optgroup': HTMLOptGroupElement,
  #|       'option': HTMLOptionElement,
  #|       'output': HTMLOutputElement,
  #|       'p': HTMLParagraphElement,
  #|       'picture': HTMLPictureElement,
  #|       'pre': HTMLPreElement,
  #|       'progress': HTMLProgressElement,
  #|       'blockquote': HTMLQuoteElement,
  #|       'q': HTMLQuoteElement,
  #|       'script': HTMLScriptElement,
  #|       'select': HTMLSelectElement,
  #|       'slot': HTMLSlotElement,
  #|       'source': HTMLSourceElement,
  #|       'style': HTMLStyleElement,
  #|       'table': HTMLTableElement,
  #|       'td': HTMLTableCellElement,
  #|       'th': HTMLTableCellElement,
  #|       'col': HTMLTableColElement,
  #|       'colgroup': HTMLTableColElement,
  #|       'tr': HTMLTableRowElement,
  #|       'thead': HTMLTableSectionElement,
  #|       'tbody': HTMLTableSectionElement,
  #|       'tfoot': HTMLTableSectionElement,
  #|       'template': HTMLTemplateElement,
  #|       'textarea': HTMLTextAreaElement,
  #|       'time': HTMLTimeElement,
  #|       'track': HTMLTrackElement,
  #|       'ul': HTMLUListElement,
  #|       'video': HTMLVideoElement,
  #|       'caption': HTMLTableCaptionElement,
  #|       'dir': HTMLDirectoryElement,
  #|       'font': HTMLFontElement,
  #|       'marquee': HTMLMarqueeElement,
  #|       'frame': HTMLFrameElement,
  #|       'frameset': HTMLFrameSetElement,
  #|       'param': HTMLParamElement
  #|     };
  #|
  #|     function Document() {
  #|       const doc = document.implementation.createDocument(null, null, null);
  #|       Object.setPrototypeOf(doc, Document.prototype);
  #|       return doc;
  #|     }
  #|     Document.prototype = Object.create(Node.prototype);
  #|     Document.prototype.constructor = Document;
  #|     Document.prototype.cloneNode = function(deep) {
  #|       const impl = this.implementation || (typeof document !== 'undefined' ? document.implementation : null);
  #|       if (this instanceof HTMLDocument) {
  #|         const cloned = impl && impl.createHTMLDocument ? impl.createHTMLDocument('') : document.implementation.createHTMLDocument('');
  #|         return cloned;
  #|       }
  #|       const ns = this.documentElement ? this.documentElement.namespaceURI : null;
  #|       const cloned = impl && impl.createDocument ? impl.createDocument(ns, null, null) : document.implementation.createDocument(ns, null, null);
  #|       if (this.contentType) cloned.contentType = this.contentType;
  #|       if (this.URL) cloned.URL = this.URL;
  #|       if (this.compatMode) cloned.compatMode = this.compatMode;
  #|       if (this.charset) cloned.charset = this.charset;
  #|       if (this.characterSet) cloned.characterSet = this.characterSet;
  #|       if (this.inputEncoding) cloned.inputEncoding = this.inputEncoding;
  #|       if (deep && this._children) {
  #|         for (const child of this._children) {
  #|           cloned.appendChild(child.cloneNode(true));
  #|         }
  #|       }
  #|       return cloned;
  #|     };
  #|
  #|     function XMLDocument() {}
  #|     XMLDocument.prototype = Object.create(Document.prototype);
  #|     XMLDocument.prototype.constructor = XMLDocument;
  #|
  #|     function HTMLDocument() {}
  #|     HTMLDocument.prototype = Object.create(Document.prototype);
  #|     HTMLDocument.prototype.constructor = HTMLDocument;
  #|
  #|     function DocumentType() {}
  #|     DocumentType.prototype = Object.create(Node.prototype);
  #|     DocumentType.prototype.constructor = DocumentType;
  #|
  #|     function DocumentFragment() {
  #|       if (!(this instanceof DocumentFragment)) throw new TypeError("Failed to construct 'DocumentFragment': Please use the 'new' operator");
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createDocumentFragment', id });
  #|       const frag = createMockDocumentFragment(id);
  #|       frag._ownerDocument = document;
  #|       Object.setPrototypeOf(frag, DocumentFragment.prototype);
  #|       return frag;
  #|     }
  #|     DocumentFragment.prototype = Object.create(Node.prototype);
  #|     DocumentFragment.prototype.constructor = DocumentFragment;
  #|     DocumentFragment.prototype.getElementById = function(id) {
  #|       const target = String(id);
  #|       if (target === '') return null;
  #|       let found = null;
  #|       traverseTree(this, (node) => {
  #|         if (node._nodeType !== 1) return;
  #|         if (node.id === target) { found = node; return false; }
  #|       });
  #|       return found;
  #|     };
  #|
  #|     // Text constructor
  #|     function Text(data) {
  #|       if (!(this instanceof Text)) throw new TypeError("Failed to construct 'Text': Please use the 'new' operator");
  #|       const str = data === undefined ? '' : String(data);
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createTextNode', id, text: str });
  #|       const node = createMockTextNode(str, id);
  #|       Object.setPrototypeOf(node, Text.prototype);
  #|       return node;
  #|     }
  #|     Text.prototype = Object.create(CharacterData.prototype);
  #|     Text.prototype.constructor = Text;
  #|
  #|     // Comment constructor
  #|     function Comment(data) {
  #|       if (!(this instanceof Comment)) throw new TypeError("Failed to construct 'Comment': Please use the 'new' operator");
  #|       const str = data === undefined ? '' : String(data);
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createComment', id, text: str });
  #|       const node = createMockComment(str, id);
  #|       Object.setPrototypeOf(node, Comment.prototype);
  #|       return node;
  #|     }
  #|     Comment.prototype = Object.create(CharacterData.prototype);
  #|     Comment.prototype.constructor = Comment;
  #|
  #|     function createMockElement(tagName, mockId) {
  #|       const el = {
  #|         _mockId: mockId,
  #|         _tagName: tagName,
  #|         _localName: null,
  #|         _namespaceURI: 'http://www.w3.org/1999/xhtml',
  #|         _prefix: null,
  #|         _ownerDocument: null,
  #|         _attrList: [], // Array of {ns, localName, prefix, name, value}
  #|         _textContent: '',
  #|         _children: [],
  #|         _parent: null,
  #|         _nodeType: 1,
  #|         get nodeType() { return this._nodeType; },
  #|         get nodeName() {
  #|           const doc = this._ownerDocument || getGlobalDocument();
  #|           if (doc && doc.contentType === 'text/html' && this._namespaceURI === 'http://www.w3.org/1999/xhtml') {
  #|             return this._tagName.toUpperCase();
  #|           }
  #|           return this._tagName;
  #|         },
  #|         get nodeValue() { return null; },
  #|         set nodeValue(v) {},
  #|         get tagName() {
  #|           const doc = this._ownerDocument || getGlobalDocument();
  #|           if (doc && doc.contentType === 'text/html' && this._namespaceURI === 'http://www.w3.org/1999/xhtml') {
  #|             return this._tagName.toUpperCase();
  #|           }
  #|           return this._tagName;
  #|         },
  #|         get localName() {
  #|           if (this._localName !== null && this._localName !== undefined) return this._localName;
  #|           if (this._namespaceURI === 'http://www.w3.org/1999/xhtml') return asciiLowercase(this._tagName);
  #|           return this._tagName.toLowerCase();
  #|         },
  #|         get namespaceURI() { return this._namespaceURI; },
  #|         get prefix() { return this._prefix; },
  #|         get baseURI() {
  #|           const doc = this.ownerDocument || getGlobalDocument();
  #|           if (doc && doc.baseURI) return doc.baseURI;
  #|           if (doc && doc.URL) return doc.URL;
  #|           return 'about:blank';
  #|         },
  #|         get ownerDocument() { return this._ownerDocument || getGlobalDocument(); },
  #|         set ownerDocument(v) { this._ownerDocument = v; },
  #|         get isConnected() {
  #|           let node = this;
  #|           while (node._parent) node = node._parent;
  #|           return node && node._nodeType === 9;
  #|         },
  #|         getRootNode() { return getRootNodePublic(this); },
  #|         // Legacy _attrs getter for backwards compatibility
  #|         get _attrs() {
  #|           const obj = {};
  #|           for (const attr of this._attrList) {
  #|             obj[attr.localName] = attr.value;
  #|           }
  #|           return obj;
  #|         },
  #|         get slot() { return this.getAttribute('slot') || ''; },
  #|         set slot(v) { this.setAttribute('slot', v); },
  #|         setAttribute(name, value) {
  #|           // Validate attribute name - empty string is invalid
  #|           if (name === '') {
  #|             throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|           }
  #|           const rawName = String(name);
  #|           const isHtml = this._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|           const normalizedName = isHtml ? asciiLowercase(rawName) : rawName;
  #|           const oldClassValue = normalizedName === 'class' ? this.getAttribute('class') : null;
  #|           const colonIdx = rawName.indexOf(':');
  #|           const rawLocal = colonIdx >= 0 ? rawName.slice(colonIdx + 1) : rawName;
  #|           const rawPrefix = colonIdx >= 0 ? rawName.slice(0, colonIdx) : null;
  #|           const localName = isHtml ? asciiLowercase(rawLocal) : rawLocal;
  #|           const prefix = rawPrefix ? (isHtml ? asciiLowercase(rawPrefix) : rawPrefix) : null;
  #|           const strValue = String(value);
  #|           const idx = this._attrList.findIndex(a => a.name === normalizedName);
  #|           if (idx >= 0) {
  #|             this._attrList[idx].value = strValue;
  #|             this._attrList[idx].localName = localName;
  #|             this._attrList[idx].prefix = prefix;
  #|           } else {
  #|             this._attrList.push({ ns: null, localName: localName, prefix: prefix, name: normalizedName, value: strValue });
  #|           }
  #|           if (normalizedName === 'class') {
  #|             updateClassIndex(this, oldClassValue, strValue);
  #|           }
  #|           domOps.push({ op: 'setAttribute', id: this._mockId, name: normalizedName, value: strValue });
  #|         },
  #|         getAttribute(name) {
  #|           const rawName = String(name);
  #|           const isHtml = this._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|           const searchName = isHtml ? asciiLowercase(rawName) : rawName;
  #|           const attr = this._attrList.find(a => (isHtml ? asciiLowercase(a.name) === searchName : a.name === searchName));
  #|           return attr ? attr.value : null;
  #|         },
  #|         removeAttribute(name) {
  #|           const rawName = String(name);
  #|           const isHtml = this._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|           const searchName = isHtml ? asciiLowercase(rawName) : rawName;
  #|           const oldClassValue = searchName === 'class' ? this.getAttribute('class') : null;
  #|           const idx = this._attrList.findIndex(a => (isHtml ? asciiLowercase(a.name) === searchName : a.name === searchName));
  #|           if (idx >= 0) {
  #|             this._attrList.splice(idx, 1);
  #|           }
  #|           if (searchName === 'class') {
  #|             updateClassIndex(this, oldClassValue, null);
  #|           }
  #|           domOps.push({ op: 'removeAttribute', id: this._mockId, name: searchName });
  #|         },
  #|         hasAttribute(name) {
  #|           const rawName = String(name);
  #|           const isHtml = this._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|           const searchName = isHtml ? asciiLowercase(rawName) : rawName;
  #|           return this._attrList.some(a => (isHtml ? asciiLowercase(a.name) === searchName : a.name === searchName));
  #|         },
  #|         hasAttributes() { return this._attrList.length > 0; },
  #|         getAttributeNames() { return this._attrList.map(a => a.name); },
  #|         get attributes() {
  #|           const self = this;
  #|           const items = this._attrList.map(function(a) {
  #|             const attrName = a.name;
  #|             const attr = {
  #|               name: a.name,
  #|               localName: a.localName,
  #|               nodeName: a.name,
  #|               namespaceURI: a.ns,
  #|               prefix: a.prefix,
  #|               ownerElement: self,
  #|               ownerDocument: self.ownerDocument || getGlobalDocument(),
  #|               specified: true,
  #|               nodeType: 2,
  #|               _nodeType: 2
  #|             };
  #|             Object.defineProperty(attr, 'value', {
  #|               get() { const v = self.getAttribute(attrName); return v === null ? '' : v; },
  #|               set(v) { self.setAttribute(attrName, v); }
  #|             });
  #|             Object.defineProperty(attr, 'nodeValue', {
  #|               get() { const v = self.getAttribute(attrName); return v === null ? '' : v; },
  #|               set(v) { self.setAttribute(attrName, v); }
  #|             });
  #|             Object.defineProperty(attr, 'textContent', {
  #|               get() { const v = self.getAttribute(attrName); return v === null ? '' : v; },
  #|               set(v) { self.setAttribute(attrName, v); }
  #|             });
  #|             Object.defineProperty(attr, 'baseURI', {
  #|               get() {
  #|                 if (self && self.baseURI) return self.baseURI;
  #|                 const doc = self && self.ownerDocument ? self.ownerDocument : getGlobalDocument();
  #|                 return doc && doc.baseURI ? doc.baseURI : 'about:blank';
  #|               }
  #|             });
  #|             attr.cloneNode = function() {
  #|               const doc = this.ownerDocument || getGlobalDocument();
  #|               let cloned;
  #|               if (this.namespaceURI) {
  #|                 cloned = doc && doc.createAttributeNS ? doc.createAttributeNS(this.namespaceURI, this.name) : document.createAttributeNS(this.namespaceURI, this.name);
  #|               } else {
  #|                 cloned = doc && doc.createAttribute ? doc.createAttribute(this.name) : document.createAttribute(this.name);
  #|               }
  #|               cloned.value = this.value;
  #|               return cloned;
  #|             };
  #|             attr.isSameNode = function(other) { return this === other; };
  #|             attr.isEqualNode = function(other) { return other && other._nodeType === 2 && other.name === this.name && other.value === this.value && other.namespaceURI === this.namespaceURI; };
  #|             Object.setPrototypeOf(attr, Attr.prototype);
  #|             return attr;
  #|           });
  #|           const namedNodeMap = {
  #|             length: items.length,
  #|             item(i) { return items[i] || null; },
  #|             getNamedItem(name) {
  #|               const rawName = String(name);
  #|               const isHtml = self._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|               const searchName = isHtml ? asciiLowercase(rawName) : rawName;
  #|               return items.find(function(a) {
  #|                 return isHtml ? asciiLowercase(a.name) === searchName : a.name === searchName;
  #|               }) || null;
  #|             },
  #|             getNamedItemNS(ns, localName) {
  #|               const normalNs = (ns === '' || ns === null) ? null : ns;
  #|               return items.find(function(a) {
  #|                 const attrNs = (a.namespaceURI === '' || a.namespaceURI === null) ? null : a.namespaceURI;
  #|                 return attrNs === normalNs && a.localName === localName;
  #|               }) || null;
  #|             },
  #|             setNamedItem(attr) { self.setAttribute(attr.name, attr.value); return attr; },
  #|             removeNamedItem(name) { const old = this.getNamedItem(name); self.removeAttribute(name); return old; },
  #|             [Symbol.iterator]() { return items[Symbol.iterator](); }
  #|           };
  #|           // Add numeric index access
  #|           for (let i = 0; i < items.length; i++) {
  #|             namedNodeMap[i] = items[i];
  #|           }
  #|           return namedNodeMap;
  #|         },
  #|         getAttributeNS(ns, localName) {
  #|           // NS methods match by (namespace, localName) - case-sensitive
  #|           // Treat null and "" as equivalent namespace
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           const attr = this._attrList.find(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|           return attr ? attr.value : null;
  #|         },
  #|         setAttributeNS(ns, qualifiedName, value) {
  #|           // Validate qualifiedName - empty string is invalid
  #|           if (qualifiedName === '') {
  #|             throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|           }
  #|           // Normalize namespace (treat "" as null)
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           // Extract localName and prefix from qualifiedName
  #|           const colonIdx = qualifiedName.indexOf(':');
  #|           const localName = colonIdx >= 0 ? qualifiedName.slice(colonIdx + 1) : qualifiedName;
  #|           const prefix = colonIdx >= 0 ? qualifiedName.slice(0, colonIdx) : null;
  #|           const oldClassValue = (normalNs === null && localName === 'class') ? this.getAttribute('class') : null;
  #|           const strValue = String(value);
  #|           // Find existing attr with same (namespace, localName)
  #|           const idx = this._attrList.findIndex(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|           if (idx >= 0) {
  #|             this._attrList[idx].value = strValue;
  #|             this._attrList[idx].prefix = prefix;
  #|             this._attrList[idx].name = qualifiedName;
  #|           } else {
  #|             this._attrList.push({ ns: normalNs, localName: localName, prefix: prefix, name: qualifiedName, value: strValue });
  #|           }
  #|           if (normalNs === null && localName === 'class') {
  #|             updateClassIndex(this, oldClassValue, strValue);
  #|           }
  #|           domOps.push({ op: 'setAttribute', id: this._mockId, name: qualifiedName, value: strValue });
  #|         },
  #|         removeAttributeNS(ns, localName) {
  #|           // NS methods match by (namespace, localName) - case-sensitive
  #|           // Treat null and "" as equivalent namespace
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           const oldClassValue = (normalNs === null && localName === 'class') ? this.getAttribute('class') : null;
  #|           const idx = this._attrList.findIndex(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|           if (idx >= 0) {
  #|             this._attrList.splice(idx, 1);
  #|           }
  #|           if (normalNs === null && localName === 'class') {
  #|             updateClassIndex(this, oldClassValue, null);
  #|           }
  #|           domOps.push({ op: 'removeAttribute', id: this._mockId, name: localName });
  #|         },
  #|         hasAttributeNS(ns, localName) {
  #|           // NS methods match by (namespace, localName) - case-sensitive
  #|           // Treat null and "" as equivalent namespace
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           return this._attrList.some(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|         },
  #|         getAttributeNode(name) { return this.attributes.getNamedItem(name); },
  #|         getAttributeNodeNS(ns, localName) { return this.attributes.getNamedItemNS(ns, localName); },
  #|         setAttributeNode(attr) {
  #|           this.setAttribute(attr.name, attr.value);
  #|           if (attr) {
  #|             attr.ownerElement = this;
  #|             attr.ownerDocument = this.ownerDocument || getGlobalDocument();
  #|           }
  #|           return attr;
  #|         },
  #|         setAttributeNodeNS(attr) { return this.setAttributeNode(attr); },
  #|         removeAttributeNode(attr) {
  #|           this.removeAttribute(attr.name);
  #|           if (attr) attr.ownerElement = null;
  #|           return attr;
  #|         },
  #|         toggleAttribute(name, force) {
  #|           // Validate name - empty string is invalid
  #|           if (name === '') {
  #|             throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|           }
  #|           const rawName = String(name);
  #|           const isHtml = this._namespaceURI === 'http://www.w3.org/1999/xhtml';
  #|           const attrName = isHtml ? asciiLowercase(rawName) : rawName;
  #|           if (force === undefined) {
  #|             if (this.hasAttribute(attrName)) { this.removeAttribute(attrName); return false; }
  #|             else { this.setAttribute(attrName, ''); return true; }
  #|           }
  #|           if (force) { this.setAttribute(attrName, ''); return true; }
  #|           else { this.removeAttribute(attrName); return false; }
  #|         },
  #|         get id() { return this.getAttribute('id') || ''; },
  #|         set id(v) { this.setAttribute('id', v); },
  #|         get className() { return this.getAttribute('class') || ''; },
  #|         set className(v) { this.setAttribute('class', v); },
  #|         get classList() {
  #|           if (!this._classListObj) {
  #|             const self = this;
  #|             const getter = () => self.getAttribute('class');
  #|             const setter = (v) => {
  #|               if (v === null || v === undefined) {
  #|                 self.removeAttribute('class');
  #|               } else {
  #|                 self.setAttribute('class', String(v));
  #|               }
  #|             };
  #|             const list = new DOMTokenList(getter, setter);
  #|             if (typeof Proxy !== 'undefined') {
  #|               this._classListObj = new Proxy(list, {
  #|                 get(target, prop) {
  #|                   if (prop === Symbol.iterator) return target.values ? target.values.bind(target) : target[Symbol.iterator];
  #|                   if (typeof prop === 'string' && /^[0-9]+$/.test(prop)) {
  #|                     const idx = Number(prop);
  #|                     const tokens = target._tokenize ? target._tokenize() : [];
  #|                     return tokens[idx];
  #|                   }
  #|                   return target[prop];
  #|                 },
  #|                 set(target, prop, value) {
  #|                   if (prop === 'value') { target.value = value; return true; }
  #|                   target[prop] = value;
  #|                   return true;
  #|                 }
  #|               });
  #|             } else {
  #|               this._classListObj = list;
  #|             }
  #|           }
  #|           return this._classListObj;
  #|         },
  #|         set classList(v) { /* readonly in spec; ignore assignment */ },
  #|         get textContent() {
  #|           // Collect text content from Text node descendants only
  #|           const collectText = (node) => {
  #|             if (node._nodeType === 3 || node._nodeType === 4) return node._textContent;
  #|             if (!node._children) return '';
  #|             return node._children.map(collectText).join('');
  #|           };
  #|           return collectText(this);
  #|         },
  #|         set textContent(v) {
  #|           const str = (v === null || v === undefined) ? '' : String(v);
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) {
  #|               for (const child of this._children) {
  #|                 unindexSubtree(child, doc);
  #|               }
  #|             }
  #|           }
  #|           // Remove all children
  #|           this._children.forEach(c => { c._parent = null; });
  #|           this._children = [];
  #|           // If non-empty, add a text node
  #|           if (str !== '') {
  #|             const textNode = document.createTextNode(str);
  #|             textNode._parent = this;
  #|             this._children.push(textNode);
  #|           }
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: str });
  #|         },
  #|         get innerHTML() { return this._children.map(c => c.outerHTML || c.textContent).join(''); },
  #|         set innerHTML(v) {
  #|           const html = (v === null || v === undefined) ? '' : String(v);
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) {
  #|               for (const child of this._children) {
  #|                 unindexSubtree(child, doc);
  #|               }
  #|             }
  #|           }
  #|           if (this._children && this._children.length > 0) {
  #|             for (const child of this._children) {
  #|               if (child && child._parent === this) child._parent = null;
  #|               if (child && 'parentNode' in child) child.parentNode = null;
  #|             }
  #|           }
  #|           this._children = [];
  #|           if (html === '') return;
  #|           const owner = getOwnerDocument(this) || document;
  #|           const nodes = parseHtmlFragment(html, owner);
  #|           for (const node of nodes) {
  #|             this.appendChild(node);
  #|           }
  #|         },
  #|         get outerHTML() {
  #|           const attrs = this._attrList.map(function(a) { return ' ' + a.name + '="' + a.value + '"'; }).join('');
  #|           const inner = this.innerHTML || this._textContent;
  #|           const tag = this._tagName.toLowerCase();
  #|           return '<' + tag + attrs + '>' + inner + '</' + tag + '>';
  #|         },
  #|         set outerHTML(v) {
  #|           const html = (v === null || v === undefined) ? '' : String(v);
  #|           const parent = this._parent;
  #|           if (!parent || typeof parent.insertBefore !== 'function' || typeof parent.removeChild !== 'function') return;
  #|           const owner = getOwnerDocument(parent) || document;
  #|           const nodes = parseHtmlFragment(html, owner);
  #|           const ref = this.nextSibling;
  #|           for (const node of nodes) {
  #|             parent.insertBefore(node, ref);
  #|           }
  #|           parent.removeChild(this);
  #|         },
  #|         appendChild(child) {
  #|           if (!isNodeLike(child)) {
  #|             throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           }
  #|           const childType = getNodeType(child);
  #|           if (childType === 9 || childType === 10) {
  #|             throw new DOMException('Cannot append this node type', 'HierarchyRequestError');
  #|           }
  #|           if (!isAllowedChildNodeTypeForElement(childType)) {
  #|             throw new DOMException('Cannot append this node type', 'HierarchyRequestError');
  #|           }
  #|           if (child === this || (child.contains && child.contains(this))) {
  #|             throw new DOMException('The new child is an ancestor of the parent', 'HierarchyRequestError');
  #|           }
  #|           if (childType === 11) {
  #|             const nodes = child._children ? child._children.slice() : [];
  #|             for (const node of nodes) {
  #|               this.appendChild(node);
  #|             }
  #|             if (child._children) child._children = [];
  #|             return child;
  #|           }
  #|           detachNode(child);
  #|           adoptSubtree(child, getOwnerDocument(this));
  #|           this._children.push(child);
  #|           child._parent = this;
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) indexSubtree(child, doc);
  #|           }
  #|           domOps.push({ op: 'appendChild', parentId: this._mockId, childId: child._mockId });
  #|           return child;
  #|         },
  #|         insertBefore(newChild, refChild) {
  #|           if (arguments.length < 2) {
  #|             throw new TypeError('Failed to execute insertBefore: 2 arguments required');
  #|           }
  #|           if (!isNodeLike(newChild)) {
  #|             throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           }
  #|           if (refChild !== null && refChild !== undefined && !isNodeLike(refChild)) {
  #|             throw new TypeError('Failed to execute insertBefore: parameter 2 is not of type Node');
  #|           }
  #|           if (newChild === this || (newChild.contains && newChild.contains(this))) {
  #|             throw new DOMException('The new child is an ancestor of the parent', 'HierarchyRequestError');
  #|           }
  #|           if (refChild === null || refChild === undefined) return this.appendChild(newChild);
  #|           if (refChild._parent !== this) {
  #|             throw new DOMException('The node before which the new node is to be inserted is not a child of this node', 'NotFoundError');
  #|           }
  #|           const newType = getNodeType(newChild);
  #|           if (newType === 9 || newType === 10) {
  #|             throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|           }
  #|           if (!isAllowedChildNodeTypeForElement(newType)) {
  #|             throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|           }
  #|           if (newType === 11) {
  #|             const nodes = newChild._children ? newChild._children.slice() : [];
  #|             for (const node of nodes) {
  #|               this.insertBefore(node, refChild);
  #|             }
  #|             if (newChild._children) newChild._children = [];
  #|             return newChild;
  #|           }
  #|           // DOM spec: if refChild === newChild, use newChild's next sibling
  #|           let actualRef = refChild;
  #|           if (refChild === newChild) {
  #|             actualRef = newChild.nextSibling;
  #|           }
  #|           detachNode(newChild);
  #|           adoptSubtree(newChild, getOwnerDocument(this));
  #|           if (actualRef === null || actualRef === undefined) {
  #|             return this.appendChild(newChild);
  #|           }
  #|           const idx = this._children.indexOf(actualRef);
  #|           if (idx >= 0) {
  #|             this._children.splice(idx, 0, newChild);
  #|             newChild._parent = this;
  #|             if (isConnectedToDocument(this)) {
  #|               const doc = getOwnerDocument(this);
  #|               if (doc) indexSubtree(newChild, doc);
  #|             }
  #|             domOps.push({ op: 'insertBefore', parentId: this._mockId, childId: newChild._mockId, refId: actualRef._mockId });
  #|           } else {
  #|             return this.appendChild(newChild);
  #|           }
  #|           return newChild;
  #|         },
  #|         removeChild(child) {
  #|           if (!isNodeLike(child)) {
  #|             throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|           }
  #|           const idx = this._children.indexOf(child);
  #|           if (idx < 0) {
  #|             throw new DOMException('The node to be removed is not a child of this node', 'NotFoundError');
  #|           }
  #|           this._children.splice(idx, 1);
  #|           child._parent = null;
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) unindexSubtree(child, doc);
  #|           }
  #|           domOps.push({ op: 'removeChild', parentId: this._mockId, childId: child._mockId });
  #|           return child;
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (!isNodeLike(newChild) || !isNodeLike(oldChild)) {
  #|             throw new TypeError('Failed to execute replaceChild: parameters are not of type Node');
  #|           }
  #|           if (newChild === this || (newChild.contains && newChild.contains(this))) {
  #|             throw new DOMException('The new child is an ancestor of the parent', 'HierarchyRequestError');
  #|           }
  #|           const idx = this._children.indexOf(oldChild);
  #|           if (idx < 0) {
  #|             throw new DOMException('The node to be replaced is not a child of this node', 'NotFoundError');
  #|           }
  #|           if (newChild === oldChild) return oldChild;
  #|           const newType = getNodeType(newChild);
  #|           if (newType === 9 || newType === 10) {
  #|             throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|           }
  #|           if (!isAllowedChildNodeTypeForElement(newType)) {
  #|             throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|           }
  #|           if (newType === 11) {
  #|             const ref = oldChild.nextSibling;
  #|             const nodes = newChild._children ? newChild._children.slice() : [];
  #|             for (const node of nodes) {
  #|               this.insertBefore(node, ref);
  #|             }
  #|             if (newChild._children) newChild._children = [];
  #|             this.removeChild(oldChild);
  #|             return oldChild;
  #|           }
  #|           detachNode(newChild);
  #|           adoptSubtree(newChild, getOwnerDocument(this));
  #|           this._children.splice(idx, 1, newChild);
  #|           oldChild._parent = null;
  #|           newChild._parent = this;
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) {
  #|               unindexSubtree(oldChild, doc);
  #|               indexSubtree(newChild, doc);
  #|             }
  #|           }
  #|           domOps.push({ op: 'replaceChild', parentId: this._mockId, childId: newChild._mockId, refId: oldChild._mockId });
  #|           return oldChild;
  #|         },
  #|         cloneNode(deep) {
  #|           const cloneElement = (el, isDeep) => {
  #|             if (el._nodeType === 3) {
  #|               const id = nodeIdCounter++;
  #|               domOps.push({ op: 'createTextNode', id, text: el._textContent });
  #|               return createMockTextNode(el._textContent, id);
  #|             }
  #|             if (el._nodeType === 8) {
  #|               const id = nodeIdCounter++;
  #|               domOps.push({ op: 'createComment', id, text: el._textContent });
  #|               return createMockComment(el._textContent, id);
  #|             }
  #|             if (el._nodeType === 11) {
  #|               const id = nodeIdCounter++;
  #|               domOps.push({ op: 'createDocumentFragment', id });
  #|               const frag = createMockDocumentFragment(id);
  #|               if (isDeep) {
  #|                 for (const child of el._children) {
  #|                   const clonedChild = cloneElement(child, true);
  #|                   frag._children.push(clonedChild);
  #|                   clonedChild._parent = frag;
  #|                 }
  #|               }
  #|               return frag;
  #|             }
  #|             const id = nodeIdCounter++;
  #|             domOps.push({ op: 'createElement', id, tagName: el._tagName });
  #|             const clone = createMockElement(el._tagName, id);
  #|             clone._tagName = el._tagName;
  #|             clone._localName = el._localName;
  #|             clone._namespaceURI = el._namespaceURI;
  #|             clone._prefix = el._prefix;
  #|             clone._ownerDocument = getOwnerDocument(el);
  #|             if (clone._namespaceURI === 'http://www.w3.org/1999/xhtml') {
  #|               const local = clone._localName !== null && clone._localName !== undefined
  #|                 ? clone._localName
  #|                 : asciiLowercase(clone._tagName);
  #|               const ctor = tagToConstructor[asciiLowercase(local)] || HTMLUnknownElement;
  #|               Object.setPrototypeOf(clone, ctor.prototype);
  #|             } else {
  #|               Object.setPrototypeOf(clone, Element.prototype);
  #|             }
  #|             for (const attr of el._attrList) {
  #|               clone._attrList.push({ ns: attr.ns, localName: attr.localName, prefix: attr.prefix, name: attr.name, value: attr.value });
  #|               domOps.push({ op: 'setAttribute', id, name: attr.name, value: attr.value });
  #|             }
  #|             if (el._textContent && el._children.length === 0) {
  #|               clone._textContent = el._textContent;
  #|               domOps.push({ op: 'setTextContent', id, value: el._textContent });
  #|             }
  #|             if (isDeep && el._children) {
  #|               for (const child of el._children) {
  #|                 const clonedChild = cloneElement(child, true);
  #|                 clone._children.push(clonedChild);
  #|                 clonedChild._parent = clone;
  #|                 domOps.push({ op: 'appendChild', parentId: id, childId: clonedChild._mockId });
  #|               }
  #|             }
  #|             return clone;
  #|           };
  #|           return cloneElement(this, !!deep);
  #|         },
  #|         isEqualNode(other) {
  #|           if (!other) return false;
  #|           if (this._nodeType !== other._nodeType) return false;
  #|           if (this.namespaceURI !== other.namespaceURI) return false;
  #|           if (this.prefix !== other.prefix) return false;
  #|           if (this.localName !== other.localName) return false;
  #|           const attrs1 = this._attrList || [];
  #|           const attrs2 = other._attrList || [];
  #|           if (attrs1.length !== attrs2.length) return false;
  #|           for (const a1 of attrs1) {
  #|             const ns1 = (a1.ns === '' || a1.ns === undefined) ? null : a1.ns;
  #|             const match = attrs2.find(a2 => {
  #|               const ns2 = (a2.ns === '' || a2.ns === undefined) ? null : a2.ns;
  #|               return ns1 === ns2 && a1.localName === a2.localName;
  #|             });
  #|             if (!match || match.value !== a1.value) return false;
  #|           }
  #|           if (this._children.length !== (other._children || []).length) return false;
  #|           for (let i = 0; i < this._children.length; i++) {
  #|             if (!this._children[i].isEqualNode || !this._children[i].isEqualNode(other._children[i])) return false;
  #|           }
  #|           return true;
  #|         },
  #|         isSameNode(other) { return this === other; },
  #|         normalize() {
  #|           normalizeChildArray(this._children);
  #|         },
  #|         compareDocumentPosition(other) {
  #|           return compareDocumentPositionImpl(this, other);
  #|         },
  #|         lookupPrefix(ns) {
  #|           if (ns === 'http://www.w3.org/1999/xhtml') return null;
  #|           return null;
  #|         },
  #|         lookupNamespaceURI(prefix) {
  #|           return lookupNamespaceURIImpl(this, prefix);
  #|         },
  #|         isDefaultNamespace(ns) {
  #|           return Node.prototype.isDefaultNamespace.call(this, ns);
  #|         },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get firstChild() { return this._children[0] || null; },
  #|         get lastChild() { return this._children[this._children.length - 1] || null; },
  #|         get childNodes() {
  #|           if (!this._childNodesList) {
  #|             this._childNodesList = makeNodeList(() => this._children.slice());
  #|           }
  #|           return this._childNodesList;
  #|         },
  #|         get children() {
  #|           if (!this._childrenCollection) {
  #|             this._childrenCollection = makeHTMLCollection(() => this._children.filter(c => c._nodeType === 1));
  #|           }
  #|           return this._childrenCollection;
  #|         },
  #|         get firstElementChild() { return this._children.find(c => c._nodeType === 1) || null; },
  #|         get lastElementChild() { return [...this._children].reverse().find(c => c._nodeType === 1) || null; },
  #|         get childElementCount() { return this._children.filter(c => c._nodeType === 1).length; },
  #|         hasChildNodes() { return this._children.length > 0; },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx >= 0 ? (siblings[idx + 1] || null) : null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx > 0 ? siblings[idx - 1] : null;
  #|         },
  #|         get nextElementSibling() {
  #|           let sib = this.nextSibling;
  #|           while (sib && sib._nodeType !== 1) sib = sib.nextSibling;
  #|           return sib;
  #|         },
  #|         get previousElementSibling() {
  #|           let sib = this.previousSibling;
  #|           while (sib && sib._nodeType !== 1) sib = sib.previousSibling;
  #|           return sib;
  #|         },
  #|         contains(node) {
  #|           return nodeContains(this, node);
  #|         },
  #|         matches(selector) {
  #|           return matchesSelector(this, selector, this);
  #|         },
  #|         closest(selector) {
  #|           let node = this;
  #|           while (node) {
  #|             if (node._nodeType === 1 && matchesSelector(node, selector, this)) return node;
  #|             node = node._parent;
  #|           }
  #|           return null;
  #|         },
  #|         getElementsByTagName(tag) {
  #|           const name = String(tag);
  #|           if (name !== '*') {
  #|             return makeHTMLCollection(() => {
  #|               const list = getCandidatesByFilter(this, false, { kind: 'tag', name });
  #|               if (list !== null) return list;
  #|               return collectElements(this, false, (el) => matchesTagName(el, name));
  #|             });
  #|           }
  #|           return makeHTMLCollection(() => collectElements(this, false, (el) => matchesTagName(el, name)));
  #|         },
  #|         getElementsByClassName(cls) {
  #|           const tokens = parseClassTokens(cls);
  #|           if (tokens.length === 0) return makeHTMLCollection(() => []);
  #|           return makeHTMLCollection(() => {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'class', tokens });
  #|             if (list !== null) return list;
  #|             return collectElements(this, false, (el) => matchesClassTokens(el, tokens));
  #|           });
  #|         },
  #|         getElementsByTagNameNS(ns, tag) {
  #|           const name = String(tag);
  #|           const namespace = ns;
  #|           return makeHTMLCollection(() =>
  #|             collectElements(this, false, (el) => matchesNamespace(el, namespace) && matchesTagNameNS(el, name))
  #|           );
  #|         },
  #|         webkitMatchesSelector(selector) {
  #|           return this.matches(selector);
  #|         },
  #|         insertAdjacentElement(position, element) {
  #|           if (!element) return null;
  #|           const pos = String(position).toLowerCase();
  #|           switch (pos) {
  #|             case 'beforebegin': if (this._parent) this._parent.insertBefore(element, this); break;
  #|             case 'afterbegin': this.insertBefore(element, this.firstChild); break;
  #|             case 'beforeend': this.appendChild(element); break;
  #|             case 'afterend': if (this._parent) this._parent.insertBefore(element, this.nextSibling); break;
  #|             default: throw new DOMException("Invalid position: " + position, "SyntaxError");
  #|           }
  #|           return element;
  #|         },
  #|         insertAdjacentText(position, text) {
  #|           const node = document.createTextNode(text);
  #|           this.insertAdjacentElement(position, node);
  #|         },
  #|         insertAdjacentHTML(position, html) {
  #|           const temp = document.createElement('template');
  #|           temp._textContent = html;
  #|           this.insertAdjacentElement(position, temp);
  #|         },
  #|         get shadowRoot() { return this._shadowRoot || null; },
  #|         attachShadow(init) {
  #|           if (this._shadowRoot) throw new Error('Already has shadow root');
  #|           const shadow = {
  #|             mode: init.mode,
  #|             host: this,
  #|             _children: [],
  #|             _parent: this,
  #|             appendChild(c) {
  #|               if (c && c._parent) {
  #|                 detachNode(c);
  #|               }
  #|               this._children.push(c);
  #|               if (c) {
  #|                 c._parent = this;
  #|                 if ('parentNode' in c) c.parentNode = this;
  #|               }
  #|               return c;
  #|             }
  #|           };
  #|           this._shadowRoot = shadow;
  #|           return shadow;
  #|         },
  #|         focus() {},
  #|         blur() {},
  #|         click() {},
  #|         dispatchEvent(event) { return true; },
  #|         addEventListener(type, listener, options) {},
  #|         removeEventListener(type, listener, options) {},
  #|         querySelector(selector) {
  #|           const sel = String(selector);
  #|           const classTokens = parseSimpleClassSelector(sel);
  #|           if (classTokens) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'class', tokens: classTokens });
  #|             if (list !== null) return list[0] || null;
  #|             let found = null;
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               if (node === this) return;
  #|               if (matchesClassTokens(node, classTokens)) { found = node; return false; }
  #|             });
  #|             return found;
  #|           }
  #|           const tagName = parseSimpleTagSelector(sel);
  #|           if (tagName) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'tag', name: tagName });
  #|             if (list !== null) return list[0] || null;
  #|             let found = null;
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               if (node === this) return;
  #|               if (matchesTagName(node, tagName)) { found = node; return false; }
  #|             });
  #|             return found;
  #|           }
  #|           const compiled = compileSelector(sel);
  #|           const groups = compiled.groups || [];
  #|           if (groups.length === 0) return null;
  #|           let found = null;
  #|           traverseTree(this, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             if (node === this) return;
  #|             for (const group of groups) {
  #|               if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|               if (matchesSelectorGroupCompiled(node, group, this, true)) { found = node; return false; }
  #|             }
  #|           });
  #|           return found;
  #|         },
  #|         querySelectorAll(selector) {
  #|           const sel = String(selector);
  #|           const classTokens = parseSimpleClassSelector(sel);
  #|           if (classTokens) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'class', tokens: classTokens });
  #|             if (list !== null) return makeNodeList(list);
  #|             return makeNodeList(collectElements(this, false, (el) => matchesClassTokens(el, classTokens)));
  #|           }
  #|           const tagName = parseSimpleTagSelector(sel);
  #|           if (tagName) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'tag', name: tagName });
  #|             if (list !== null) return makeNodeList(list);
  #|             return makeNodeList(collectElements(this, false, (el) => matchesTagName(el, tagName)));
  #|           }
  #|           const compiled = compileSelector(sel);
  #|           const groups = compiled.groups || [];
  #|           if (groups.length === 0) return makeNodeList([]);
  #|           const allFilterable = groups.every(
  #|             g => g.filter && !(g.filter.kind === 'tag' && String(g.filter.name) === '*')
  #|           );
  #|           if (!allFilterable || !isConnectedToDocument(this)) {
  #|             const results = [];
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               if (node === this) return;
  #|               for (const group of groups) {
  #|                 if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|                 if (matchesSelectorGroupCompiled(node, group, this, true)) {
  #|                   results.push(node);
  #|                   break;
  #|                 }
  #|               }
  #|             });
  #|             return makeNodeList(results);
  #|           }
  #|           const fallbackTraversal = () => {
  #|             const results = [];
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               if (node === this) return;
  #|               for (const group of groups) {
  #|                 if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|                 if (matchesSelectorGroupCompiled(node, group, this, true)) {
  #|                   results.push(node);
  #|                   break;
  #|                 }
  #|               }
  #|             });
  #|             return makeNodeList(results);
  #|           };
  #|           if (groups.length === 1) {
  #|             const group = groups[0];
  #|             const candidates = getCandidatesByFilter(this, false, group.filter, true);
  #|             if (candidates === null) return fallbackTraversal();
  #|             const results = [];
  #|             for (const node of candidates) {
  #|               if (!matchesSelectorGroupCompiled(node, group, this, true)) continue;
  #|               results.push(node);
  #|             }
  #|             return makeNodeList(results);
  #|           }
  #|           const results = [];
  #|           const seen = new Set();
  #|           let useIndex = true;
  #|           for (const group of groups) {
  #|             const candidates = getCandidatesByFilter(this, false, group.filter, true);
  #|             if (candidates === null) { useIndex = false; break; }
  #|             for (const node of candidates) {
  #|               if (!matchesSelectorGroupCompiled(node, group, this, true)) continue;
  #|               if (!seen.has(node)) { seen.add(node); results.push(node); }
  #|             }
  #|           }
  #|           if (!useIndex) return fallbackTraversal();
  #|           if (results.length > 1) {
  #|             results.sort((a, b) => {
  #|               if (a === b) return 0;
  #|               const pos = compareDocumentPositionImpl(a, b);
  #|               return (pos & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1;
  #|             });
  #|           }
  #|           return makeNodeList(results);
  #|         },
  #|         append(...nodes) {
  #|           for (const node of nodes) {
  #|             if (typeof node === 'string') {
  #|               const text = document.createTextNode(node);
  #|               this.appendChild(text);
  #|             } else {
  #|               this.appendChild(node);
  #|             }
  #|           }
  #|         },
  #|         prepend(...nodes) {
  #|           const first = this.firstChild;
  #|           for (const node of nodes) {
  #|             if (typeof node === 'string') {
  #|               const text = document.createTextNode(node);
  #|               this.insertBefore(text, first);
  #|             } else {
  #|               this.insertBefore(node, first);
  #|             }
  #|           }
  #|         },
  #|         remove() {
  #|           if (this._parent) this._parent.removeChild(this);
  #|         },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceChildren(...nodes) {
  #|           while (this._children.length > 0) this.removeChild(this._children[0]);
  #|           this.append(...nodes);
  #|         },
  #|         getBoundingClientRect() { return { x: 0, y: 0, width: 0, height: 0, top: 0, right: 0, bottom: 0, left: 0 }; },
  #|         get style() {
  #|           const self = this;
  #|           return new Proxy({}, {
  #|             get(_, prop) {
  #|               if (prop === 'cssText') return self._attrs.style || '';
  #|               return '';
  #|             },
  #|             set(_, prop, value) {
  #|               if (prop === 'cssText') {
  #|                 self.setAttribute('style', value);
  #|                 return true;
  #|               }
  #|               const style = self._attrs.style || '';
  #|               const propName = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               self.setAttribute('style', style + propName + ':' + value + ';');
  #|               return true;
  #|             }
  #|           });
  #|         },
  #|         set style(v) {
  #|           // el.style = "string" sets the style attribute
  #|           this.setAttribute('style', String(v));
  #|         },
  #|         // HTMLElement properties
  #|         get title() { return this._attrs.title || ''; },
  #|         set title(v) { this.setAttribute('title', v); },
  #|         get lang() { return this._attrs.lang || ''; },
  #|         set lang(v) { this.setAttribute('lang', v); },
  #|         get translate() { return this._attrs.translate !== 'no'; },
  #|         set translate(v) { this.setAttribute('translate', v ? 'yes' : 'no'); },
  #|         get dir() { return this._attrs.dir || ''; },
  #|         set dir(v) { this.setAttribute('dir', v); },
  #|         get hidden() { return this.hasAttribute('hidden'); },
  #|         set hidden(v) { if (v) this.setAttribute('hidden', ''); else this.removeAttribute('hidden'); },
  #|         get inert() { return this.hasAttribute('inert'); },
  #|         set inert(v) { if (v) this.setAttribute('inert', ''); else this.removeAttribute('inert'); },
  #|         get accessKey() { return this._attrs.accesskey || ''; },
  #|         set accessKey(v) { this.setAttribute('accesskey', v); },
  #|         get accessKeyLabel() { return this._attrs.accesskey || ''; },
  #|         get draggable() { return this._attrs.draggable === 'true'; },
  #|         set draggable(v) { this.setAttribute('draggable', v ? 'true' : 'false'); },
  #|         get spellcheck() { return this._attrs.spellcheck !== 'false'; },
  #|         set spellcheck(v) { this.setAttribute('spellcheck', String(v)); },
  #|         get writingSuggestions() { return this._attrs.writingsuggestions || ''; },
  #|         set writingSuggestions(v) { this.setAttribute('writingsuggestions', v); },
  #|         get autocapitalize() { return this._attrs.autocapitalize || ''; },
  #|         set autocapitalize(v) { this.setAttribute('autocapitalize', v); },
  #|         get innerText() { return this.textContent; },
  #|         set innerText(v) { this.textContent = v; },
  #|         get outerText() { return this.textContent; },
  #|         set outerText(v) { this.textContent = v; },
  #|         get tabIndex() { return parseInt(this._attrs.tabindex) || 0; },
  #|         set tabIndex(v) { this.setAttribute('tabindex', String(v)); },
  #|         get contentEditable() { return this._attrs.contenteditable || 'inherit'; },
  #|         set contentEditable(v) { this.setAttribute('contenteditable', v); },
  #|         get isContentEditable() { return this._attrs.contenteditable === 'true'; },
  #|         _popoverState: 'hidden',
  #|         get popover() { return this._attrs.popover || null; },
  #|         set popover(v) { if (v) this.setAttribute('popover', v); else this.removeAttribute('popover'); },
  #|         showPopover() { this._popoverState = 'showing'; },
  #|         hidePopover() { this._popoverState = 'hidden'; },
  #|         togglePopover(force) {
  #|           if (force === undefined) {
  #|             this._popoverState = this._popoverState === 'showing' ? 'hidden' : 'showing';
  #|           } else {
  #|             this._popoverState = force ? 'showing' : 'hidden';
  #|           }
  #|           return this._popoverState === 'showing';
  #|         },
  #|         attachInternals() { return { shadowRoot: null, form: null, willValidate: false, validity: {}, validationMessage: '', labels: [] }; },
  #|         get offsetParent() { return this._parent; },
  #|         get offsetTop() { return 0; },
  #|         get offsetLeft() { return 0; },
  #|         get offsetWidth() { return 0; },
  #|         get offsetHeight() { return 0; },
  #|         get dataset() {
  #|           const self = this;
  #|           return new Proxy({}, {
  #|             get(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               return self._attrs[attrName] || undefined;
  #|             },
  #|             set(_, prop, value) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               self.setAttribute(attrName, value);
  #|               return true;
  #|             },
  #|             has(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               return attrName in self._attrs;
  #|             },
  #|             deleteProperty(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               self.removeAttribute(attrName);
  #|               return true;
  #|             },
  #|             ownKeys() {
  #|               return Object.keys(self._attrs)
  #|                 .filter(function(k) { return k.startsWith('data-'); })
  #|                 .map(function(k) { return k.slice(5).replace(/-([a-z])/g, function(_, c) { return c.toUpperCase(); }); });
  #|             },
  #|             getOwnPropertyDescriptor(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               if (attrName in self._attrs) {
  #|                 return { enumerable: true, configurable: true, value: self._attrs[attrName] };
  #|               }
  #|             }
  #|           });
  #|         }
  #|       };
  #|       if (tagName.toLowerCase() === 'iframe' && !('contentDocument' in el)) {
  #|         el.contentDocument = document;
  #|       }
  #|       if (tagName.toLowerCase() === 'a' && !('href' in el)) {
  #|         Object.defineProperty(el, 'href', {
  #|           get() { return this._url ? this._url.href : ''; },
  #|           set(v) { this._url = new URL(v); },
  #|           configurable: true,
  #|           enumerable: true
  #|         });
  #|       }
  #|       mockElements.set(mockId, el);
  #|       return el;
  #|     }
  #|
  #|     function createMockTextNode(text, mockId) {
  #|       const node = {
  #|         _mockId: mockId,
  #|         _tagName: '#text',
  #|         _textContent: text,
  #|         _parent: null,
  #|         _nodeType: 3,
  #|         _ownerDocument: null,
  #|         get nodeType() { return 3; },
  #|         get nodeName() { return '#text'; },
  #|         get ownerDocument() { return this._ownerDocument || getGlobalDocument(); },
  #|         set ownerDocument(v) { this._ownerDocument = v; },
  #|         get isConnected() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n._tagName === 'HTML';
  #|         },
  #|         getRootNode(options) { return getRootNodePublic(this); },
  #|         get textContent() { return this._textContent; },
  #|         set textContent(v) {
  #|           this._textContent = String(v);
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: String(v) });
  #|         },
  #|         get nodeValue() { return this._textContent; },
  #|         set nodeValue(v) { this.data = v; },
  #|         get data() { return this._textContent; },
  #|         set data(v) {
  #|           const str = v === null ? '' : String(v);
  #|           this._textContent = str;
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: str });
  #|         },
  #|         get length() { return this._textContent.length; },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get firstChild() { return null; },
  #|         get lastChild() { return null; },
  #|         get childNodes() { return emptyNodeList; },
  #|         hasChildNodes() { return false; },
  #|         appendChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot appendChild to a Text node', 'HierarchyRequestError');
  #|         },
  #|         insertBefore(child, ref) {
  #|           if (child === null) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot insertBefore on a Text node', 'HierarchyRequestError');
  #|         },
  #|         removeChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot removeChild from a Text node', 'NotFoundError');
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (newChild === null) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot replaceChild on a Text node', 'HierarchyRequestError');
  #|         },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx >= 0 ? (siblings[idx + 1] || null) : null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx > 0 ? siblings[idx - 1] : null;
  #|         },
  #|         cloneNode() {
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createTextNode', id, text: this._textContent });
  #|           return createMockTextNode(this._textContent, id);
  #|         },
  #|         remove() { if (this._parent) this._parent.removeChild(this); },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         splitText(offset) {
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           const newText = this._textContent.slice(offset);
  #|           this._textContent = this._textContent.slice(0, offset);
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: this._textContent });
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createTextNode', id, text: newText });
  #|           const newNode = createMockTextNode(newText, id);
  #|           if (this._parent) {
  #|             const idx = this._parent._children.indexOf(this);
  #|             this._parent._children.splice(idx + 1, 0, newNode);
  #|             newNode._parent = this._parent;
  #|             domOps.push({ op: 'insertBefore', parentId: this._parent._mockId, childId: newNode._mockId, refId: this.nextSibling ? this.nextSibling._mockId : 0 });
  #|           }
  #|           return newNode;
  #|         },
  #|         get wholeText() {
  #|           let text = this._textContent;
  #|           let sib = this.previousSibling;
  #|           while (sib && sib._nodeType === 3) { text = sib._textContent + text; sib = sib.previousSibling; }
  #|           sib = this.nextSibling;
  #|           while (sib && sib._nodeType === 3) { text = text + sib._textContent; sib = sib.nextSibling; }
  #|           return text;
  #|         },
  #|         substringData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'substringData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           return this._textContent.substr(offset, count);
  #|         },
  #|         appendData(data) {
  #|           if (arguments.length < 1) throw new TypeError("Failed to execute 'appendData': 1 argument required");
  #|           this.textContent = this._textContent + String(data);
  #|         },
  #|         insertData(offset, data) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'insertData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           this.textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset);
  #|         },
  #|         deleteData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'deleteData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this.textContent = this._textContent.slice(0, offset) + this._textContent.slice(offset + count);
  #|         },
  #|         replaceData(offset, count, data) {
  #|           if (arguments.length < 3) throw new TypeError("Failed to execute 'replaceData': 3 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this.textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset + count);
  #|         },
  #|         normalize() {},
  #|         isEqualNode(other) { return other && other._nodeType === 3 && other._textContent === this._textContent; },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, node);
  #|       return node;
  #|     }
  #|     function createMockCDATASection(text, mockId) {
  #|       const node = createMockTextNode(text, mockId);
  #|       node._nodeType = 4;
  #|       node.nodeType = 4;
  #|       node.nodeName = '#cdata-section';
  #|       return node;
  #|     }
  #|
  #|     function createMockComment(text, mockId) {
  #|       const node = {
  #|         _mockId: mockId,
  #|         _tagName: '#comment',
  #|         _textContent: text,
  #|         _parent: null,
  #|         _nodeType: 8,
  #|         _ownerDocument: null,
  #|         _children: [],
  #|         get nodeType() { return 8; },
  #|         get nodeName() { return '#comment'; },
  #|         get ownerDocument() { return this._ownerDocument || getGlobalDocument(); },
  #|         set ownerDocument(v) { this._ownerDocument = v; },
  #|         get textContent() { return this._textContent; },
  #|         set textContent(v) { this.data = v; },
  #|         get nodeValue() { return this._textContent; },
  #|         set nodeValue(v) { this.data = v; },
  #|         get data() { return this._textContent; },
  #|         set data(v) { this._textContent = v === null ? '' : String(v); },
  #|         get length() { return this._textContent.length; },
  #|         get outerHTML() { return '<!--' + this._textContent + '-->'; },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get firstChild() { return null; },
  #|         get lastChild() { return null; },
  #|         get childNodes() { return emptyNodeList; },
  #|         hasChildNodes() { return false; },
  #|         appendChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot appendChild to a Comment node', 'HierarchyRequestError');
  #|         },
  #|         insertBefore(child, ref) {
  #|           if (child === null) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot insertBefore on a Comment node', 'HierarchyRequestError');
  #|         },
  #|         removeChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot removeChild from a Comment node', 'NotFoundError');
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (newChild === null) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot replaceChild on a Comment node', 'HierarchyRequestError');
  #|         },
  #|         get isConnected() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n._tagName === 'HTML';
  #|         },
  #|         getRootNode() { return getRootNodePublic(this); },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx >= 0 ? (siblings[idx + 1] || null) : null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx > 0 ? siblings[idx - 1] : null;
  #|         },
  #|         substringData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'substringData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           return this._textContent.substr(offset, count);
  #|         },
  #|         appendData(data) {
  #|           if (arguments.length < 1) throw new TypeError("Failed to execute 'appendData': 1 argument required");
  #|           this._textContent = this._textContent + String(data);
  #|         },
  #|         insertData(offset, data) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'insertData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset);
  #|         },
  #|         deleteData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'deleteData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + this._textContent.slice(offset + count);
  #|         },
  #|         replaceData(offset, count, data) {
  #|           if (arguments.length < 3) throw new TypeError("Failed to execute 'replaceData': 3 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset + count);
  #|         },
  #|         cloneNode() {
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createComment', id, text: this._textContent });
  #|           return createMockComment(this._textContent, id);
  #|         },
  #|         remove() { if (this._parent) this._parent.removeChild(this); },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         isEqualNode(other) { return other && other._nodeType === 8 && other._textContent === this._textContent; },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, node);
  #|       return node;
  #|     }
  #|
  #|     function createMockProcessingInstruction(target, data, mockId) {
  #|       const node = {
  #|         _mockId: mockId,
  #|         _tagName: target,
  #|         _textContent: data,
  #|         _target: target,
  #|         _parent: null,
  #|         _nodeType: 7,
  #|         _children: [],
  #|         get nodeType() { return 7; },
  #|         get nodeName() { return this._target; },
  #|         get target() { return this._target; },
  #|         get ownerDocument() { return this._ownerDocument || getGlobalDocument(); },
  #|         set ownerDocument(v) { this._ownerDocument = v; },
  #|         get textContent() { return this._textContent; },
  #|         set textContent(v) { this.data = v; },
  #|         get nodeValue() { return this._textContent; },
  #|         set nodeValue(v) { this.data = v; },
  #|         get data() { return this._textContent; },
  #|         set data(v) { this._textContent = v === null ? '' : String(v); },
  #|         get length() { return this._textContent.length; },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get isConnected() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n._tagName === 'HTML';
  #|         },
  #|         getRootNode(options) { return getRootNodePublic(this); },
  #|         get firstChild() { return null; },
  #|         get lastChild() { return null; },
  #|         get childNodes() { return emptyNodeList; },
  #|         hasChildNodes() { return false; },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx >= 0 ? (siblings[idx + 1] || null) : null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const siblings = getSiblingArray(this);
  #|           const idx = siblings.indexOf(this);
  #|           return idx > 0 ? siblings[idx - 1] : null;
  #|         },
  #|         appendChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot appendChild to a ProcessingInstruction node', 'HierarchyRequestError');
  #|         },
  #|         insertBefore(child, ref) {
  #|           if (child === null) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot insertBefore on a ProcessingInstruction node', 'HierarchyRequestError');
  #|         },
  #|         removeChild(child) {
  #|           throw new DOMException('Cannot removeChild from a ProcessingInstruction node', 'NotFoundError');
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (newChild === null) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot replaceChild on a ProcessingInstruction node', 'HierarchyRequestError');
  #|         },
  #|         substringData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'substringData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           return this._textContent.substr(offset, count);
  #|         },
  #|         appendData(data) {
  #|           if (arguments.length < 1) throw new TypeError("Failed to execute 'appendData': 1 argument required");
  #|           this._textContent = this._textContent + String(data);
  #|         },
  #|         insertData(offset, data) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'insertData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset);
  #|         },
  #|         deleteData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'deleteData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + this._textContent.slice(offset + count);
  #|         },
  #|         replaceData(offset, count, data) {
  #|           if (arguments.length < 3) throw new TypeError("Failed to execute 'replaceData': 3 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset + count);
  #|         },
  #|         cloneNode() {
  #|           const id = nodeIdCounter++;
  #|           return createMockProcessingInstruction(this._target, this._textContent, id);
  #|         },
  #|         remove() { if (this._parent) this._parent.removeChild(this); },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         isEqualNode(other) { return other && other._nodeType === 7 && other._target === this._target && other._textContent === this._textContent; },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, node);
  #|       return node;
  #|     }
  #|
  #|     function createMockDocumentFragment(mockId) {
  #|       const frag = {
  #|         _mockId: mockId,
  #|         _tagName: '#document-fragment',
  #|         _children: [],
  #|         _parent: null,
  #|         _nodeType: 11,
  #|         _ownerDocument: null,
  #|         get nodeType() { return 11; },
  #|         get nodeName() { return '#document-fragment'; },
  #|         get nodeValue() { return null; },
  #|         set nodeValue(v) { /* ignore */ },
  #|         get ownerDocument() { return this._ownerDocument || getGlobalDocument(); },
  #|         set ownerDocument(v) { this._ownerDocument = v; },
  #|         get textContent() {
  #|           // Collect text content from Text node descendants only
  #|           const collectText = (node) => {
  #|             if (node._nodeType === 3 || node._nodeType === 4) return node._textContent;
  #|             if (!node._children) return '';
  #|             return node._children.map(collectText).join('');
  #|           };
  #|           return collectText(this);
  #|         },
  #|         set textContent(v) {
  #|           const str = (v === null || v === undefined) ? '' : String(v);
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) {
  #|               for (const child of this._children) {
  #|                 unindexSubtree(child, doc);
  #|               }
  #|             }
  #|           }
  #|           this._children.forEach(c => { c._parent = null; });
  #|           this._children = [];
  #|           if (str !== '') {
  #|             const textNode = document.createTextNode(str);
  #|             textNode._parent = this;
  #|             this._children.push(textNode);
  #|           }
  #|         },
  #|         get firstChild() { return this._children[0] || null; },
  #|         get lastChild() { return this._children[this._children.length - 1] || null; },
  #|         get childNodes() {
  #|           if (!this._childNodesList) {
  #|             this._childNodesList = makeNodeList(() => this._children.slice());
  #|           }
  #|           return this._childNodesList;
  #|         },
  #|         get children() {
  #|           if (!this._childrenCollection) {
  #|             this._childrenCollection = makeHTMLCollection(() => this._children.filter(c => c._nodeType === 1));
  #|           }
  #|           return this._childrenCollection;
  #|         },
  #|         get childElementCount() { return this._children.filter(c => c._nodeType === 1).length; },
  #|         hasChildNodes() { return this._children.length > 0; },
  #|         appendChild(child) {
  #|           if (!isNodeLike(child)) {
  #|             throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           }
  #|           const childType = getNodeType(child);
  #|           if (childType === 9 || childType === 10) {
  #|             throw new DOMException('Cannot append this node type', 'HierarchyRequestError');
  #|           }
  #|           if (childType === 11) {
  #|             const nodes = child._children ? child._children.slice() : [];
  #|             for (const node of nodes) this.appendChild(node);
  #|             if (child._children) child._children = [];
  #|             return child;
  #|           }
  #|           detachNode(child);
  #|           adoptSubtree(child, getOwnerDocument(this));
  #|           this._children.push(child);
  #|           child._parent = this;
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) indexSubtree(child, doc);
  #|           }
  #|           return child;
  #|         },
  #|         insertBefore(newChild, refChild) {
  #|           if (arguments.length < 2) {
  #|             throw new TypeError('Failed to execute insertBefore: 2 arguments required');
  #|           }
  #|           if (!isNodeLike(newChild)) {
  #|             throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           }
  #|           if (refChild !== null && refChild !== undefined && !isNodeLike(refChild)) {
  #|             throw new TypeError('Failed to execute insertBefore: parameter 2 is not of type Node');
  #|           }
  #|           if (refChild !== null && refChild !== undefined && refChild._parent !== this) {
  #|             throw new DOMException('The node before which the new node is to be inserted is not a child of this node', 'NotFoundError');
  #|           }
  #|           const newType = getNodeType(newChild);
  #|           if (newType === 9 || newType === 10) {
  #|             throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|           }
  #|           if (refChild === null || refChild === undefined) return this.appendChild(newChild);
  #|           if (newType === 11) {
  #|             const nodes = newChild._children ? newChild._children.slice() : [];
  #|             for (const node of nodes) this.insertBefore(node, refChild);
  #|             if (newChild._children) newChild._children = [];
  #|             return newChild;
  #|           }
  #|           let actualRef = refChild;
  #|           if (refChild === newChild) {
  #|             actualRef = newChild.nextSibling;
  #|           }
  #|           detachNode(newChild);
  #|           adoptSubtree(newChild, getOwnerDocument(this));
  #|           if (actualRef === null || actualRef === undefined) {
  #|             return this.appendChild(newChild);
  #|           }
  #|           const idx = this._children.indexOf(actualRef);
  #|           if (idx >= 0) {
  #|             this._children.splice(idx, 0, newChild);
  #|             newChild._parent = this;
  #|             if (isConnectedToDocument(this)) {
  #|               const doc = getOwnerDocument(this);
  #|               if (doc) indexSubtree(newChild, doc);
  #|             }
  #|           }
  #|           else { return this.appendChild(newChild); }
  #|           return newChild;
  #|         },
  #|         removeChild(child) {
  #|           if (!isNodeLike(child)) {
  #|             throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|           }
  #|           const idx = this._children.indexOf(child);
  #|           if (idx < 0) {
  #|             throw new DOMException('The node to be removed is not a child of this node', 'NotFoundError');
  #|           }
  #|           this._children.splice(idx, 1);
  #|           child._parent = null;
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) unindexSubtree(child, doc);
  #|           }
  #|           return child;
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (!isNodeLike(newChild) || !isNodeLike(oldChild)) {
  #|             throw new TypeError('Failed to execute replaceChild: parameters are not of type Node');
  #|           }
  #|           if (newChild === this || (newChild.contains && newChild.contains(this))) {
  #|             throw new DOMException('The new child is an ancestor of the parent', 'HierarchyRequestError');
  #|           }
  #|           const idx = this._children.indexOf(oldChild);
  #|           if (idx < 0) {
  #|             throw new DOMException('The node to be replaced is not a child of this node', 'NotFoundError');
  #|           }
  #|           if (newChild === oldChild) return oldChild;
  #|           const newType = getNodeType(newChild);
  #|           if (newType === 9 || newType === 10) {
  #|             throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|           }
  #|           if (newType === 11) {
  #|             const ref = oldChild.nextSibling;
  #|             const nodes = newChild._children ? newChild._children.slice() : [];
  #|             for (const node of nodes) this.insertBefore(node, ref);
  #|             if (newChild._children) newChild._children = [];
  #|             this.removeChild(oldChild);
  #|             return oldChild;
  #|           }
  #|           detachNode(newChild);
  #|           adoptSubtree(newChild, getOwnerDocument(this));
  #|           this._children.splice(idx, 1, newChild);
  #|           oldChild._parent = null;
  #|           newChild._parent = this;
  #|           if (isConnectedToDocument(this)) {
  #|             const doc = getOwnerDocument(this);
  #|             if (doc) {
  #|               unindexSubtree(oldChild, doc);
  #|               indexSubtree(newChild, doc);
  #|             }
  #|           }
  #|           return oldChild;
  #|         },
  #|         append(...nodes) {
  #|           for (const n of nodes) {
  #|             const node = (n && n._mockId !== undefined) ? n : document.createTextNode(String(n));
  #|             this.appendChild(node);
  #|           }
  #|         },
  #|         prepend(...nodes) {
  #|           const first = this.firstChild;
  #|           for (const n of nodes) {
  #|             const node = (n && n._mockId !== undefined) ? n : document.createTextNode(String(n));
  #|             this.insertBefore(node, first);
  #|           }
  #|         },
  #|         replaceChildren(...nodes) {
  #|           while (this._children.length > 0) this.removeChild(this._children[0]);
  #|           this.append(...nodes);
  #|         },
  #|         querySelector(selector) {
  #|           const sel = String(selector);
  #|           const classTokens = parseSimpleClassSelector(sel);
  #|           if (classTokens) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'class', tokens: classTokens });
  #|             if (list !== null) return list[0] || null;
  #|             let found = null;
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               if (matchesClassTokens(node, classTokens)) { found = node; return false; }
  #|             });
  #|             return found;
  #|           }
  #|           const tagName = parseSimpleTagSelector(sel);
  #|           if (tagName) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'tag', name: tagName });
  #|             if (list !== null) return list[0] || null;
  #|             let found = null;
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               if (matchesTagName(node, tagName)) { found = node; return false; }
  #|             });
  #|             return found;
  #|           }
  #|           const compiled = compileSelector(sel);
  #|           const groups = compiled.groups || [];
  #|           if (groups.length === 0) return null;
  #|           let found = null;
  #|           traverseTree(this, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             for (const group of groups) {
  #|               if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|               if (matchesSelectorGroupCompiled(node, group, this, true)) { found = node; return false; }
  #|             }
  #|           });
  #|           return found;
  #|         },
  #|         querySelectorAll(selector) {
  #|           const sel = String(selector);
  #|           const classTokens = parseSimpleClassSelector(sel);
  #|           if (classTokens) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'class', tokens: classTokens });
  #|             if (list !== null) return makeNodeList(list);
  #|             return makeNodeList(collectElements(this, false, (el) => matchesClassTokens(el, classTokens)));
  #|           }
  #|           const tagName = parseSimpleTagSelector(sel);
  #|           if (tagName) {
  #|             const list = getCandidatesByFilter(this, false, { kind: 'tag', name: tagName });
  #|             if (list !== null) return makeNodeList(list);
  #|             return makeNodeList(collectElements(this, false, (el) => matchesTagName(el, tagName)));
  #|           }
  #|           const compiled = compileSelector(sel);
  #|           const groups = compiled.groups || [];
  #|           if (groups.length === 0) return makeNodeList([]);
  #|           const allFilterable = groups.every(
  #|             g => g.filter && !(g.filter.kind === 'tag' && String(g.filter.name) === '*')
  #|           );
  #|           if (!allFilterable || !isConnectedToDocument(this)) {
  #|             const results = [];
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               for (const group of groups) {
  #|                 if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|                 if (matchesSelectorGroupCompiled(node, group, this, true)) {
  #|                   results.push(node);
  #|                   break;
  #|                 }
  #|               }
  #|             });
  #|             return makeNodeList(results);
  #|           }
  #|           const fallbackTraversal = () => {
  #|             const results = [];
  #|             traverseTree(this, (node) => {
  #|               if (node._nodeType !== 1) return;
  #|               for (const group of groups) {
  #|                 if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|                 if (matchesSelectorGroupCompiled(node, group, this, true)) {
  #|                   results.push(node);
  #|                   break;
  #|                 }
  #|               }
  #|             });
  #|             return makeNodeList(results);
  #|           };
  #|           if (groups.length === 1) {
  #|             const group = groups[0];
  #|             const candidates = getCandidatesByFilter(this, false, group.filter, true);
  #|             if (candidates === null) return fallbackTraversal();
  #|             const results = [];
  #|             for (const node of candidates) {
  #|               if (!matchesSelectorGroupCompiled(node, group, this, true)) continue;
  #|               results.push(node);
  #|             }
  #|             return makeNodeList(results);
  #|           }
  #|           const results = [];
  #|           const seen = new Set();
  #|           let useIndex = true;
  #|           for (const group of groups) {
  #|             const candidates = getCandidatesByFilter(this, false, group.filter, true);
  #|             if (candidates === null) { useIndex = false; break; }
  #|             for (const node of candidates) {
  #|               if (!matchesSelectorGroupCompiled(node, group, this, true)) continue;
  #|               if (!seen.has(node)) { seen.add(node); results.push(node); }
  #|             }
  #|           }
  #|           if (!useIndex) return fallbackTraversal();
  #|           if (results.length > 1) {
  #|             results.sort((a, b) => {
  #|               if (a === b) return 0;
  #|               const pos = compareDocumentPositionImpl(a, b);
  #|               return (pos & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1;
  #|             });
  #|           }
  #|           return makeNodeList(results);
  #|         },
  #|         getElementById(id) {
  #|           const target = String(id);
  #|           if (target === '') return null;
  #|           let found = null;
  #|           traverseTree(this, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             if (node.id === target) { found = node; return false; }
  #|           });
  #|           return found;
  #|         },
  #|         cloneNode(deep) {
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createDocumentFragment', id });
  #|           const clone = createMockDocumentFragment(id);
  #|           if (deep) {
  #|             for (const child of this._children) {
  #|               const clonedChild = child.cloneNode(true);
  #|               clone._children.push(clonedChild);
  #|               clonedChild._parent = clone;
  #|             }
  #|           }
  #|           return clone;
  #|         },
  #|         isEqualNode(other) {
  #|           if (!other || other._nodeType !== 11) return false;
  #|           if (this._children.length !== (other._children || []).length) return false;
  #|           for (let i = 0; i < this._children.length; i++) {
  #|             if (!this._children[i].isEqualNode || !this._children[i].isEqualNode(other._children[i])) return false;
  #|           }
  #|           return true;
  #|         },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, frag);
  #|       return frag;
  #|     }
  #|
  #|     const htmlEl = createMockElement('html', 1);
  #|     const headEl = createMockElement('head', 3);
  #|     const bodyEl = createMockElement('body', 2);
  #|     Object.setPrototypeOf(htmlEl, HTMLHtmlElement.prototype);
  #|     Object.setPrototypeOf(headEl, HTMLHeadElement.prototype);
  #|     Object.setPrototypeOf(bodyEl, HTMLBodyElement.prototype);
  #|     htmlEl.appendChild(headEl);
  #|     htmlEl.appendChild(bodyEl);
  #|     let _title = '';
  #|     let _doctype = null;
  #|     let _implementation = null;
  #|
  #|     const document = {
  #|       _mockElements: mockElements,
  #|       _preNodes: [],
  #|       _postNodes: [],
  #|       _nodeType: 9,
  #|       _parent: null,
  #|       get nodeType() { return 9; },
  #|       get nodeName() { return '#document'; },
  #|       get nodeValue() { return null; },
  #|       get textContent() { return null; },
  #|       set textContent(v) { /* Document textContent is null, ignore setter */ },
  #|       get ownerDocument() { return null; },
  #|       get parentNode() { return null; },
  #|       get parentElement() { return null; },
  #|       get nextSibling() { return null; },
  #|       get previousSibling() { return null; },
  #|       get URL() {
  #|         if (typeof location !== 'undefined') {
  #|           if (location && typeof location.href === 'string') return location.href;
  #|           return String(location);
  #|         }
  #|         return 'about:blank';
  #|       },
  #|       get documentURI() {
  #|         if (typeof location !== 'undefined') {
  #|           if (location && typeof location.href === 'string') return location.href;
  #|           return String(location);
  #|         }
  #|         return 'about:blank';
  #|       },
  #|       get baseURI() {
  #|         if (typeof location !== 'undefined') {
  #|           if (location && typeof location.href === 'string') return location.href;
  #|           return String(location);
  #|         }
  #|         return 'about:blank';
  #|       },
  #|       get compatMode() { return 'CSS1Compat'; },
  #|       get characterSet() { return 'UTF-8'; },
  #|       get charset() { return 'UTF-8'; },
  #|       get inputEncoding() { return 'UTF-8'; },
  #|       get contentType() { return 'text/html'; },
  #|       get doctype() { return _doctype; },
  #|       _setDoctype(dt) { _doctype = dt; },
  #|       get implementation() {
  #|         if (_implementation) return _implementation;
  #|         // Helper to create implementation bound to a specific document
  #|         const createImplForDoc = function(ownerDoc) {
  #|           return {
  #|             _ownerDocument: ownerDoc,
  #|             createDocument(namespace, qualifiedName, doctype) {
  #|               if (arguments.length < 2) {
  #|                 throw new TypeError("Failed to execute 'createDocument': 2 arguments required");
  #|               }
  #|               const validateQualifiedName = (ns, qname) => {
  #|                 if (qname === null || qname === undefined) return;
  #|                 const name = String(qname);
  #|                 if (name === '') return;
  #|                 if (name.indexOf('>') >= 0) {
  #|                   throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                 }
  #|                 if (/\\s/.test(name)) {
  #|                   throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                 }
  #|                 if (name.indexOf('::') >= 0) {
  #|                   throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                 }
  #|                 const nsNormalized = ns === undefined || ns === '' ? null : ns;
  #|                 const colonIdx = name.indexOf(':');
  #|                 const prefix = colonIdx >= 0 ? name.split(":", 2)[0] : null;
  #|                 const localName = colonIdx >= 0 ? name.split(":", 2)[1] : name;
  #|                 if (colonIdx < 0) {
  #|                   const first = name[0];
  #|                   if ((first >= '0' && first <= '9') || first === '-' || first === '.' || first === ':' || first === '}' || first === '^' || first === '<') {
  #|                     throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                   }
  #|                 } else {
  #|                   if (colonIdx === 0) {
  #|                     throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                   }
  #|                   if (!localName) {
  #|                     throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                   }
  #|                   const localFirst = localName[0];
  #|                   if ((localFirst >= '0' && localFirst <= '9') || localFirst === '-' || localFirst === '.' || localFirst === ':') {
  #|                     throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                   }
  #|                   for (let i = 0; i < localName.length; i++) {
  #|                     const ch = localName[i];
  #|                     if (ch >= '\\u0080') continue;
  #|                     if (!/[A-Za-z0-9._-]/.test(ch)) {
  #|                       throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                     }
  #|                   }
  #|                 }
  #|                 if (name.endsWith(':')) {
  #|                   throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|                 }
  #|                 if (prefix !== null && nsNormalized === null) {
  #|                   throw new DOMException('Invalid namespace', 'NamespaceError');
  #|                 }
  #|                 if (prefix === 'xml' && nsNormalized !== 'http://www.w3.org/XML/1998/namespace') {
  #|                   throw new DOMException('Invalid namespace', 'NamespaceError');
  #|                 }
  #|                 if ((prefix === 'xmlns' || name === 'xmlns') && nsNormalized !== 'http://www.w3.org/2000/xmlns/') {
  #|                   throw new DOMException('Invalid namespace', 'NamespaceError');
  #|                 }
  #|                 if (nsNormalized === 'http://www.w3.org/2000/xmlns/' && !(prefix === 'xmlns' || name === 'xmlns')) {
  #|                   throw new DOMException('Invalid namespace', 'NamespaceError');
  #|                 }
  #|               };
  #|               validateQualifiedName(namespace, qualifiedName);
  #|               if (doctype !== undefined && doctype !== null && (!doctype._nodeType || doctype._nodeType !== 10)) {
  #|                 throw new TypeError("Failed to execute 'createDocument': parameter 3 is not of type DocumentType");
  #|               }
  #|               // Determine content type based on namespace
  #|               let contentType = 'application/xml';
  #|               if (namespace === 'http://www.w3.org/1999/xhtml') {
  #|                 contentType = 'application/xhtml+xml';
  #|               } else if (namespace === 'http://www.w3.org/2000/svg') {
  #|                 contentType = 'image/svg+xml';
  #|               }
  #|               let doc = null;
  #|               const createElementForDoc = function(ns, qname) {
  #|                 const normalizedNs = ns === undefined || ns === '' ? null : ns;
  #|                 const name = String(qname);
  #|                 const id = nodeIdCounter++;
  #|                 domOps.push({ op: 'createElement', id, tagName: name });
  #|                 const el = createMockElement(name, id);
  #|                 const colonIdx = name.indexOf(':');
  #|                 const parts = colonIdx >= 0 ? name.split(":", 2) : [null, name];
  #|                 const prefix = colonIdx >= 0 ? parts[0] : null;
  #|                 const localName = parts[1];
  #|                 const tagName = colonIdx >= 0 ? parts.join(":") : name;
  #|                 el._tagName = tagName;
  #|                 el._localName = localName;
  #|                 el._namespaceURI = normalizedNs;
  #|                 el._prefix = prefix;
  #|                 el._ownerDocument = doc;
  #|                 const lowerName = name.toLowerCase();
  #|                 const isHtmlNamespace = normalizedNs === 'http://www.w3.org/1999/xhtml';
  #|                 const Ctor = isHtmlNamespace ? (tagToConstructor[lowerName] || HTMLElement) : Element;
  #|                 Object.setPrototypeOf(el, Ctor.prototype);
  #|                 return el;
  #|               };
  #|               const createAttributeForDoc = function(name, lowercase) {
  #|                 const rawName = String(name);
  #|                 if (rawName === '') {
  #|                   throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|                 }
  #|                 const finalName = lowercase ? rawName.toLowerCase() : rawName;
  #|                 const attr = {
  #|                   _nodeType: 2,
  #|                   nodeType: 2,
  #|                   name: finalName,
  #|                   localName: finalName,
  #|                   nodeName: finalName,
  #|                   value: '',
  #|                   get nodeValue() { return this.value; },
  #|                   set nodeValue(v) { this.value = v === null ? '' : String(v); },
  #|                   get textContent() { return this.value; },
  #|                   set textContent(v) { this.value = v === null ? '' : String(v); },
  #|                   get baseURI() {
  #|                     const d = this.ownerDocument || getGlobalDocument();
  #|                     return d && d.baseURI ? d.baseURI : 'about:blank';
  #|                   },
  #|                   namespaceURI: null,
  #|                   prefix: null,
  #|                   ownerDocument: doc,
  #|                   ownerElement: null,
  #|                   specified: true,
  #|                   isSameNode(other) { return this === other; },
  #|                   isEqualNode(other) { return other && other._nodeType === 2 && other.name === this.name && other.value === this.value; },
  #|                   cloneNode() {
  #|                     const docRef = this.ownerDocument || document;
  #|                     let cloned;
  #|                     if (this.namespaceURI) {
  #|                       cloned = docRef.createAttributeNS ? docRef.createAttributeNS(this.namespaceURI, this.name) : document.createAttributeNS(this.namespaceURI, this.name);
  #|                     } else {
  #|                       cloned = docRef.createAttribute ? docRef.createAttribute(this.name) : document.createAttribute(this.name);
  #|                     }
  #|                     cloned.value = this.value;
  #|                     return cloned;
  #|                   }
  #|                 };
  #|                 Object.setPrototypeOf(attr, Attr.prototype);
  #|                 return attr;
  #|               };
  #|               doc = {
  #|                 _nodeType: 9,
  #|                 nodeType: 9,
  #|                 nodeName: '#document',
  #|                 ownerDocument: null,
  #|                 get nodeValue() { return null; },
  #|                 set nodeValue(v) { /* ignore */ },
  #|                 get textContent() { return null; },
  #|                 set textContent(v) { /* ignore */ },
  #|                 documentElement: null,
  #|                 doctype: doctype !== undefined ? doctype : null,
  #|                 _children: [],
  #|                 _impl: null,
  #|                 URL: 'about:blank',
  #|                 documentURI: 'about:blank',
  #|                 compatMode: 'CSS1Compat',
  #|                 characterSet: 'UTF-8',
  #|                 charset: 'UTF-8',
  #|                 inputEncoding: 'UTF-8',
  #|                 contentType: contentType,
  #|                 location: null,
  #|                 get implementation() {
  #|                   if (!this._impl) this._impl = createImplForDoc(this);
  #|                   return this._impl;
  #|                 },
  #|                 createElement(name) {
  #|                   const defaultNs = (this.contentType === 'text/html' || this.contentType === 'application/xhtml+xml')
  #|                     ? 'http://www.w3.org/1999/xhtml'
  #|                     : null;
  #|                   return createElementForDoc(defaultNs, name);
  #|                 },
  #|                 createElementNS(ns, name) { return createElementForDoc(ns, name); },
  #|                 createTextNode(text) {
  #|                   const str = String(text);
  #|                   const id = nodeIdCounter++;
  #|                   domOps.push({ op: 'createTextNode', id, text: str });
  #|                   const node = createMockTextNode(str, id);
  #|                   node._ownerDocument = doc;
  #|                   Object.setPrototypeOf(node, Text.prototype);
  #|                   return node;
  #|                 },
  #|                 createCDATASection(text) {
  #|                   const str = String(text);
  #|                   const id = nodeIdCounter++;
  #|                   domOps.push({ op: 'createCDATASection', id, text: str });
  #|                   const node = createMockCDATASection(str, id);
  #|                   node._ownerDocument = doc;
  #|                   Object.setPrototypeOf(node, Text.prototype);
  #|                   return node;
  #|                 },
  #|                 createComment(text) {
  #|                   const str = String(text);
  #|                   const id = nodeIdCounter++;
  #|                   domOps.push({ op: 'createComment', id, text: str });
  #|                   const node = createMockComment(str, id);
  #|                   node._ownerDocument = doc;
  #|                   Object.setPrototypeOf(node, Comment.prototype);
  #|                   return node;
  #|                 },
  #|                 createProcessingInstruction(target, data) {
  #|                   const node = document.createProcessingInstruction(target, data);
  #|                   node._ownerDocument = doc;
  #|                   Object.setPrototypeOf(node, ProcessingInstruction.prototype);
  #|                   return node;
  #|                 },
  #|                 createDocumentFragment() {
  #|                   const id = nodeIdCounter++;
  #|                   domOps.push({ op: 'createDocumentFragment', id });
  #|                   const frag = createMockDocumentFragment(id);
  #|                   frag._ownerDocument = doc;
  #|                   Object.setPrototypeOf(frag, DocumentFragment.prototype);
  #|                   return frag;
  #|                 },
  #|                 createAttribute(name) { return createAttributeForDoc(name, false); },
  #|                 createAttributeNS(ns, name) {
  #|                   const attr = createAttributeForDoc(name, false);
  #|                   attr.namespaceURI = ns === undefined || ns === '' ? null : ns;
  #|                   const colonIdx = String(name).indexOf(':');
  #|                   if (colonIdx >= 0) {
  #|                     attr.prefix = String(name).slice(0, colonIdx);
  #|                     attr.localName = String(name).slice(colonIdx + 1);
  #|                   }
  #|                   return attr;
  #|                 },
  #|                 insertBefore(newChild, refChild) {
  #|                   if (arguments.length < 2) {
  #|                     throw new TypeError('Failed to execute insertBefore: 2 arguments required');
  #|                   }
  #|                   if (!isNodeLike(newChild)) {
  #|                     throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|                   }
  #|                   if (refChild !== null && refChild !== undefined && !isNodeLike(refChild)) {
  #|                     throw new TypeError('Failed to execute insertBefore: parameter 2 is not of type Node');
  #|                   }
  #|                   if (newChild === this || (newChild.contains && newChild.contains(this))) {
  #|                     throw new DOMException('The new child is an ancestor of the parent', 'HierarchyRequestError');
  #|                   }
  #|                   if (refChild !== null && refChild !== undefined && refChild._parent !== this) {
  #|                     throw new DOMException('The node before which the new node is to be inserted is not a child of this node', 'NotFoundError');
  #|                   }
  #|                   const exclude = arguments.length > 2 ? arguments[2] : null;
  #|                   let actualRef = refChild === undefined ? null : refChild;
  #|                   if (actualRef === newChild) {
  #|                     actualRef = newChild.nextSibling;
  #|                   }
  #|                   validateDocumentInsert(this, newChild, actualRef, exclude);
  #|                   const newType = getNodeType(newChild);
  #|                   if (newType === 11) {
  #|                     const nodes = newChild._children ? newChild._children.slice() : [];
  #|                     for (const node of nodes) {
  #|                       this.insertBefore(node, actualRef, exclude);
  #|                     }
  #|                     if (newChild._children) newChild._children = [];
  #|                     return newChild;
  #|                   }
  #|                   detachNode(newChild);
  #|                   adoptSubtree(newChild, this);
  #|                   if (actualRef === null || actualRef === undefined) {
  #|                     this._children.push(newChild);
  #|                   } else {
  #|                     const idx = this._children.indexOf(actualRef);
  #|                     if (idx < 0) {
  #|                       throw new DOMException('The node before which the new node is to be inserted is not a child of this node', 'NotFoundError');
  #|                     }
  #|                     this._children.splice(idx, 0, newChild);
  #|                   }
  #|                   newChild._parent = this;
  #|                   newChild.parentNode = this;
  #|                   if (newType === 1) this.documentElement = newChild;
  #|                   if (newType === 10) this.doctype = newChild;
  #|                   indexSubtree(newChild, this);
  #|                   return newChild;
  #|                 },
  #|                 appendChild(child) { return this.insertBefore(child, null); },
  #|                 replaceChild(newChild, oldChild) {
  #|                   if (!isNodeLike(newChild) || !isNodeLike(oldChild)) {
  #|                     throw new TypeError('Failed to execute replaceChild: parameters are not of type Node');
  #|                   }
  #|                   const idx = this._children.indexOf(oldChild);
  #|                   if (idx < 0) {
  #|                     throw new DOMException('The node to be replaced is not a child of this node', 'NotFoundError');
  #|                   }
  #|                   if (newChild === oldChild) return oldChild;
  #|                   this.insertBefore(newChild, oldChild, oldChild);
  #|                   this.removeChild(oldChild);
  #|                   return oldChild;
  #|                 },
  #|                 removeChild(child) {
  #|                   if (!isNodeLike(child)) {
  #|                     throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|                   }
  #|                   const idx = this._children.indexOf(child);
  #|                   if (idx < 0) {
  #|                     throw new DOMException('The node to be removed is not a child of this node', 'NotFoundError');
  #|                   }
  #|                   this._children.splice(idx, 1);
  #|                   child._parent = null;
  #|                   child.parentNode = null;
  #|                   if (child._nodeType === 1) this.documentElement = null;
  #|                   if (child._nodeType === 10) this.doctype = null;
  #|                   unindexSubtree(child, this);
  #|                   return child;
  #|                 },
  #|                 append(...nodes) {
  #|                   const frag = this.createDocumentFragment();
  #|                   for (const n of nodes) {
  #|                     const node = (n && n._mockId !== undefined) ? n : this.createTextNode(String(n));
  #|                     frag.appendChild(node);
  #|                   }
  #|                   this.insertBefore(frag, null);
  #|                 },
  #|                 prepend(...nodes) {
  #|                   const frag = this.createDocumentFragment();
  #|                   for (const n of nodes) {
  #|                     const node = (n && n._mockId !== undefined) ? n : this.createTextNode(String(n));
  #|                     frag.appendChild(node);
  #|                   }
  #|                   this.insertBefore(frag, this.firstChild);
  #|                 },
  #|                 replaceChildren(...nodes) {
  #|                   while (this._children.length > 0) this.removeChild(this._children[0]);
  #|                   this.append(...nodes);
  #|                 },
  #|                 get childNodes() {
  #|                   if (!this._childNodesList) {
  #|                     this._childNodesList = makeNodeList(() => this._children.slice());
  #|                   }
  #|                   return this._childNodesList;
  #|                 },
  #|                 get firstChild() { return this._children[0] || null; },
  #|                 get lastChild() { return this._children[this._children.length - 1] || null; },
  #|                 getRootNode() { return this; },
  #|                 isSameNode(other) { return this === other; },
  #|                 isEqualNode(other) {
  #|                   if (!other || other._nodeType !== 9) return false;
  #|                   const kids1 = this._children || [];
  #|                   const kids2 = other._children || [];
  #|                   if (kids1.length !== kids2.length) return false;
  #|                   for (let i = 0; i < kids1.length; i++) {
  #|                     if (!kids1[i].isEqualNode || !kids1[i].isEqualNode(kids2[i])) return false;
  #|                   }
  #|                   return true;
  #|                 },
  #|                 cloneNode(deep) {
  #|                   const impl = this.implementation || document.implementation;
  #|                   const isHtml = this.contentType === 'text/html' || this.contentType === 'application/xhtml+xml'
  #|                     || (this.documentElement && this.documentElement._tagName === 'HTML');
  #|                   if (isHtml) {
  #|                     const cloned = impl && impl.createHTMLDocument ? impl.createHTMLDocument('') : document.implementation.createHTMLDocument('');
  #|                     return cloned;
  #|                   }
  #|                   const ns = this.documentElement ? this.documentElement.namespaceURI : null;
  #|                   const cloned = impl && impl.createDocument ? impl.createDocument(ns, null, null) : document.implementation.createDocument(ns, null, null);
  #|                   if (this.contentType) cloned.contentType = this.contentType;
  #|                   if (this.URL) cloned.URL = this.URL;
  #|                   if (this.compatMode) cloned.compatMode = this.compatMode;
  #|                   if (this.charset) cloned.charset = this.charset;
  #|                   if (this.characterSet) cloned.characterSet = this.characterSet;
  #|                   if (this.inputEncoding) cloned.inputEncoding = this.inputEncoding;
  #|                   if (deep && this._children) {
  #|                     for (const child of this._children) {
  #|                       cloned.appendChild(child.cloneNode(true));
  #|                     }
  #|                   }
  #|                   return cloned;
  #|                 },
  #|                 adoptNode(node) {
  #|                   if (!node) return null;
  #|                   if (node._nodeType === 9) throw new DOMException('Cannot adopt a document node', 'NotSupportedError');
  #|                   const detach = (n) => {
  #|                     if (!n._parent) return;
  #|                     if (typeof n._parent.removeChild === 'function') {
  #|                       n._parent.removeChild(n);
  #|                     } else if (Array.isArray(n._parent._children)) {
  #|                       const idx = n._parent._children.indexOf(n);
  #|                       if (idx >= 0) n._parent._children.splice(idx, 1);
  #|                     }
  #|                     n._parent = null;
  #|                     if ('parentNode' in n) n.parentNode = null;
  #|                   };
  #|                   const updateOwner = (n) => {
  #|                     n.ownerDocument = this;
  #|                     if (n._children) {
  #|                       for (const c of n._children) updateOwner(c);
  #|                     }
  #|                   };
  #|                   detach(node);
  #|                   updateOwner(node);
  #|                   return node;
  #|                 }
  #|               };
  #|               ensureDocumentIndexes(doc);
  #|               doc.cloneNode = function(deep) {
  #|                 const impl = this.implementation || document.implementation;
  #|                 const ns = this.documentElement ? this.documentElement.namespaceURI : null;
  #|                 const cloned = impl && impl.createDocument ? impl.createDocument(ns, null, null) : document.implementation.createDocument(ns, null, null);
  #|                 cloned.contentType = this.contentType;
  #|                 cloned.URL = this.URL;
  #|                 cloned.compatMode = this.compatMode;
  #|                 cloned.charset = this.charset;
  #|                 cloned.characterSet = this.characterSet;
  #|                 cloned.inputEncoding = this.inputEncoding;
  #|                 if (deep && this._children) {
  #|                   for (const child of this._children) {
  #|                     cloned.appendChild(child.cloneNode(true));
  #|                   }
  #|                 }
  #|                 return cloned;
  #|               };
  #|               Object.setPrototypeOf(doc, XMLDocument.prototype);
  #|               if (doctype !== undefined && doctype !== null) {
  #|                 doctype.ownerDocument = doc;
  #|                 doctype._parent = doc;
  #|                 doctype.parentNode = doc;
  #|                 doc._children.push(doctype);
  #|                 doc.doctype = doctype;
  #|               }
  #|               const qname = qualifiedName === null ? null : String(qualifiedName);
  #|               if (qname !== null && qname !== '') {
  #|                 const el = createElementForDoc(namespace, qname);
  #|                 doc.appendChild(el);
  #|               }
  #|               return doc;
  #|             },
  #|             createDocumentType(qualifiedName, publicId, systemId) {
  #|               const ownerDoc = this._ownerDocument || document;
  #|               const qname = String(qualifiedName);
  #|               if (qname.indexOf('>') >= 0 || qname.indexOf(' ') >= 0) {
  #|                 throw new DOMException('Invalid character in qualifiedName', 'InvalidCharacterError');
  #|               }
  #|               const doctype = {
  #|                 _nodeType: 10,
  #|                 nodeType: 10,
  #|                 name: qname,
  #|                 publicId: publicId || '',
  #|                 systemId: systemId || '',
  #|                 nodeName: qname,
  #|                 get nodeValue() { return null; },
  #|                 set nodeValue(v) { /* ignore */ },
  #|                 get textContent() { return null; },
  #|                 set textContent(v) { /* ignore */ },
  #|                 ownerDocument: ownerDoc,
  #|                 parentNode: null,
  #|                 _parent: null,
  #|                 get firstChild() { return null; },
  #|                 get lastChild() { return null; },
  #|                 get previousSibling() {
  #|                   const siblings = getSiblingArray(this);
  #|                   const idx = siblings.indexOf(this);
  #|                   return idx > 0 ? siblings[idx - 1] : null;
  #|                 },
  #|                 get nextSibling() {
  #|                   const siblings = getSiblingArray(this);
  #|                   const idx = siblings.indexOf(this);
  #|                   return idx >= 0 ? (siblings[idx + 1] || null) : null;
  #|                 },
  #|                 get childNodes() { return emptyNodeList; },
  #|                 hasChildNodes() { return false; },
  #|                 appendChild(child) {
  #|                   if (!isNodeLike(child)) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|                   throw new DOMException('Cannot appendChild to a DocumentType node', 'HierarchyRequestError');
  #|                 },
  #|                 insertBefore(child, ref) {
  #|                   if (!isNodeLike(child)) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|                   throw new DOMException('Cannot insertBefore on a DocumentType node', 'HierarchyRequestError');
  #|                 },
  #|                 removeChild(child) {
  #|                   if (!isNodeLike(child)) throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|                   throw new DOMException('Cannot removeChild from a DocumentType node', 'NotFoundError');
  #|                 },
  #|                 replaceChild(newChild, oldChild) {
  #|                   if (!isNodeLike(newChild)) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|                   throw new DOMException('Cannot replaceChild on a DocumentType node', 'HierarchyRequestError');
  #|                 },
  #|                 isSameNode(other) { return this === other; },
  #|                 isEqualNode(other) { return other && other._nodeType === 10 && other.name === this.name && other.publicId === this.publicId && other.systemId === this.systemId; },
  #|                 cloneNode() {
  #|                   return ownerDoc.implementation.createDocumentType(this.name, this.publicId, this.systemId);
  #|                 },
  #|                 remove() {
  #|                   if (this._parent && typeof this._parent.removeChild === 'function') {
  #|                     this._parent.removeChild(this);
  #|                   } else if (this._parent && Array.isArray(this._parent._children)) {
  #|                     const idx = this._parent._children.indexOf(this);
  #|                     if (idx >= 0) this._parent._children.splice(idx, 1);
  #|                     this._parent = null;
  #|                     this.parentNode = null;
  #|                   }
  #|                 },
  #|                 getRootNode() {
  #|                   let node = this;
  #|                   while (node._parent) node = node._parent;
  #|                   return node;
  #|                 }
  #|               };
  #|               Object.setPrototypeOf(doctype, DocumentType.prototype);
  #|               return doctype;
  #|             },
  #|             createHTMLDocument(title) {
  #|               const doctype = this.createDocumentType('html', '', '');
  #|               const doc = this.createDocument(null, null, doctype);
  #|               doc.cloneNode = function(deep) {
  #|                 const impl = this.implementation || document.implementation;
  #|                 const cloned = impl && impl.createHTMLDocument ? impl.createHTMLDocument('') : document.implementation.createHTMLDocument('');
  #|                 return cloned;
  #|               };
  #|               Object.setPrototypeOf(doc, HTMLDocument.prototype);
  #|               doc._children = [doctype];
  #|               doctype._parent = doc;
  #|               doctype.parentNode = doc;
  #|               doctype.ownerDocument = doc;
  #|               doc.doctype = doctype;
  #|               doc.contentType = 'text/html';
  #|               doc.createElement = function(name) {
  #|                 const el = document.createElement(name);
  #|                 el._ownerDocument = doc;
  #|                 return el;
  #|               };
  #|               doc.createElementNS = function(ns, name) {
  #|                 const el = document.createElementNS(ns, name);
  #|                 el._ownerDocument = doc;
  #|                 return el;
  #|               };
  #|               doc.createAttribute = function(name) {
  #|                 const attr = document.createAttribute(name);
  #|                 attr.ownerDocument = doc;
  #|                 return attr;
  #|               };
  #|               doc.createAttributeNS = function(ns, name) {
  #|                 const attr = document.createAttributeNS(ns, name);
  #|                 attr.ownerDocument = doc;
  #|                 return attr;
  #|               };
  #|               doc.createTextNode = function(text) {
  #|                 const node = document.createTextNode(text);
  #|                 node._ownerDocument = doc;
  #|                 return node;
  #|               };
  #|               doc.createComment = function(text) {
  #|                 const node = document.createComment(text);
  #|                 node._ownerDocument = doc;
  #|                 return node;
  #|               };
  #|               doc.createDocumentFragment = function() {
  #|                 const frag = document.createDocumentFragment();
  #|                 frag._ownerDocument = doc;
  #|                 return frag;
  #|               };
  #|               const html = doc.createElement('html');
  #|               const head = doc.createElement('head');
  #|               const body = doc.createElement('body');
  #|               if (title !== undefined) {
  #|                 const titleEl = doc.createElement('title');
  #|                 const titleText = title === null ? 'null' : String(title);
  #|                 const textNode = doc.createTextNode(titleText);
  #|                 titleEl.appendChild(textNode);
  #|                 head.appendChild(titleEl);
  #|               }
  #|               html.appendChild(head);
  #|               html.appendChild(body);
  #|               doc.appendChild(html);
  #|               doc.documentElement = html;
  #|               doc.head = head;
  #|               doc.body = body;
  #|               doc.title = title === null ? 'null' : (title === undefined ? '' : String(title));
  #|               return doc;
  #|             },
  #|             hasFeature() { return true; }
  #|           };
  #|         };
  #|         const impl = createImplForDoc(document);
  #|         Object.setPrototypeOf(impl, DOMImplementation.prototype);
  #|         _implementation = impl;
  #|         return impl;
  #|       },
  #|       get activeElement() { return bodyEl; },
  #|       get forms() { return []; },
  #|       get images() { return []; },
  #|       get links() { return []; },
  #|       get scripts() { return []; },
  #|       get embeds() { return []; },
  #|       get plugins() { return []; },
  #|       hasFocus() { return true; },
  #|       createElement(tagName) {
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createElement', id, tagName });
  #|         const el = createMockElement(tagName, id);
  #|         const Ctor = tagToConstructor[tagName.toLowerCase()] || HTMLUnknownElement;
  #|         Object.setPrototypeOf(el, Ctor.prototype);
  #|         return el;
  #|       },
  #|       createTextNode(text) {
  #|         const str = String(text);
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createTextNode', id, text: str });
  #|         const node = createMockTextNode(str, id);
  #|         Object.setPrototypeOf(node, Text.prototype);
  #|         return node;
  #|       },
  #|       createCDATASection(text) {
  #|         const str = String(text);
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createCDATASection', id, text: str });
  #|         const node = createMockCDATASection(str, id);
  #|         Object.setPrototypeOf(node, Text.prototype);
  #|         return node;
  #|       },
  #|       createComment(text) {
  #|         const str = String(text);
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createComment', id, text: str });
  #|         const node = createMockComment(str, id);
  #|         Object.setPrototypeOf(node, Comment.prototype);
  #|         return node;
  #|       },
  #|       createAttribute(name) {
  #|         const rawName = String(name);
  #|         if (rawName === '') {
  #|           throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|         }
  #|         const attrName = rawName.toLowerCase();
  #|         const attr = {
  #|           _nodeType: 2,
  #|           nodeType: 2,
  #|           name: attrName,
  #|           localName: attrName,
  #|           nodeName: attrName,
  #|           value: '',
  #|           get nodeValue() { return this.value; },
  #|           set nodeValue(v) { this.value = v === null ? '' : String(v); },
  #|           get textContent() { return this.value; },
  #|           set textContent(v) { this.value = v === null ? '' : String(v); },
  #|           get baseURI() {
  #|             const doc = this.ownerDocument || getGlobalDocument();
  #|             return doc && doc.baseURI ? doc.baseURI : 'about:blank';
  #|           },
  #|           namespaceURI: null,
  #|           prefix: null,
  #|           ownerDocument: getGlobalDocument(),
  #|           ownerElement: null,
  #|           specified: true,
  #|           isSameNode(other) { return this === other; },
  #|           isEqualNode(other) { return other && other._nodeType === 2 && other.name === this.name && other.value === this.value; },
  #|           cloneNode() {
  #|             const doc = this.ownerDocument || getGlobalDocument();
  #|             let cloned;
  #|             if (this.namespaceURI) {
  #|               cloned = doc && doc.createAttributeNS ? doc.createAttributeNS(this.namespaceURI, this.name) : document.createAttributeNS(this.namespaceURI, this.name);
  #|             } else {
  #|               cloned = doc && doc.createAttribute ? doc.createAttribute(this.name) : document.createAttribute(this.name);
  #|             }
  #|             cloned.value = this.value;
  #|             return cloned;
  #|           }
  #|         };
  #|         Object.setPrototypeOf(attr, Attr.prototype);
  #|         return attr;
  #|       },
  #|       createAttributeNS(ns, name) {
  #|         const attr = this.createAttribute(name);
  #|         attr.namespaceURI = ns;
  #|         const colonIdx = name.indexOf(':');
  #|         if (colonIdx >= 0) {
  #|           attr.prefix = name.slice(0, colonIdx);
  #|           attr.localName = name.slice(colonIdx + 1);
  #|         }
  #|         return attr;
  #|       },
  #|       createDocumentFragment() {
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createDocumentFragment', id });
  #|         return createMockDocumentFragment(id);
  #|       },
  #|       cloneNode(deep) {
  #|         const impl = this.implementation || document.implementation;
  #|         const cloned = impl && impl.createHTMLDocument ? impl.createHTMLDocument('') : document.implementation.createHTMLDocument('');
  #|         if (deep) {
  #|           const kids = getChildNodesArray(this);
  #|           for (const child of kids) {
  #|             cloned.appendChild(child.cloneNode(true));
  #|           }
  #|         }
  #|         return cloned;
  #|       },
  #|       appendChild(child) {
  #|         if (!isNodeLike(child)) {
  #|           throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|         }
  #|         const type = getNodeType(child);
  #|         if (type === 9 || type === 2) {
  #|           throw new DOMException('Cannot insert this node type', 'HierarchyRequestError');
  #|         }
  #|         if (type === 3) {
  #|           throw new DOMException('Cannot insert a text node into document', 'HierarchyRequestError');
  #|         }
  #|         if (type === 1 || type === 10) {
  #|           throw new DOMException('Document already has an element', 'HierarchyRequestError');
  #|         }
  #|         if (type === 11) {
  #|           const nodes = child._children ? child._children.slice() : [];
  #|           for (const node of nodes) {
  #|             this.appendChild(node);
  #|           }
  #|           if (child._children) child._children = [];
  #|           return child;
  #|         }
  #|         detachNode(child);
  #|         adoptSubtree(child, this);
  #|         this._postNodes.push(child);
  #|         child._parent = this;
  #|         child.parentNode = this;
  #|         indexSubtree(child, this);
  #|         return child;
  #|       },
  #|       get body() { return bodyEl; },
  #|       get head() { return headEl; },
  #|       get documentElement() { return htmlEl; },
  #|       get title() { return _title; },
  #|       set title(v) { _title = String(v); },
  #|       get childNodes() {
  #|         if (!this._childNodesList) {
  #|           this._childNodesList = makeNodeList(() => {
  #|             const nodes = [];
  #|             if (this._preNodes && this._preNodes.length > 0) nodes.push(...this._preNodes);
  #|             if (_doctype) nodes.push(_doctype);
  #|             nodes.push(htmlEl);
  #|             if (this._postNodes && this._postNodes.length > 0) nodes.push(...this._postNodes);
  #|             return nodes;
  #|           });
  #|         }
  #|         return this._childNodesList;
  #|       },
  #|       hasChildNodes() { return this.childNodes.length > 0; },
  #|       get children() {
  #|         if (!this._childrenCollection) {
  #|           this._childrenCollection = makeHTMLCollection(() => [htmlEl]);
  #|         }
  #|         return this._childrenCollection;
  #|       },
  #|       get firstChild() {
  #|         const nodes = this.childNodes;
  #|         return nodes[0] || null;
  #|       },
  #|       get lastChild() {
  #|         const nodes = this.childNodes;
  #|         return nodes[nodes.length - 1] || null;
  #|       },
  #|       getElementById(id) {
  #|         const target = String(id);
  #|         if (target === '') return null;
  #|         let found = null;
  #|         traverseTree(htmlEl, (node) => {
  #|           if (node._nodeType !== 1) return;
  #|           if (node.id === target) { found = node; return false; }
  #|         });
  #|         return found;
  #|       },
  #|       getElementsByTagName(tag) {
  #|         const name = String(tag);
  #|         if (name !== '*') {
  #|           return makeHTMLCollection(() => {
  #|             const list = getCandidatesByFilter(htmlEl, true, { kind: 'tag', name });
  #|             if (list !== null) return list;
  #|             return collectElements(htmlEl, true, (el) => matchesTagName(el, name));
  #|           });
  #|         }
  #|         return makeHTMLCollection(() => collectElements(htmlEl, true, (el) => matchesTagName(el, name)));
  #|       },
  #|       getElementsByClassName(cls) {
  #|         const tokens = parseClassTokens(cls);
  #|         if (tokens.length === 0) return makeHTMLCollection(() => []);
  #|         return makeHTMLCollection(() => {
  #|           const list = getCandidatesByFilter(htmlEl, true, { kind: 'class', tokens });
  #|           if (list !== null) return list;
  #|           return collectElements(htmlEl, true, (el) => matchesClassTokens(el, tokens));
  #|         });
  #|       },
  #|       getElementsByName(name) {
  #|         const target = String(name);
  #|         return makeNodeList(() => collectElements(htmlEl, true, (el) => el._attrs && el._attrs.name === target));
  #|       },
  #|       querySelector(selector) {
  #|         const sel = String(selector);
  #|         const classTokens = parseSimpleClassSelector(sel);
  #|         if (classTokens) {
  #|           const list = getCandidatesByFilter(htmlEl, true, { kind: 'class', tokens: classTokens });
  #|           if (list !== null) return list[0] || null;
  #|           let found = null;
  #|           traverseTree(htmlEl, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             if (matchesClassTokens(node, classTokens)) { found = node; return false; }
  #|           });
  #|           return found;
  #|         }
  #|         const tagName = parseSimpleTagSelector(sel);
  #|         if (tagName) {
  #|           const list = getCandidatesByFilter(htmlEl, true, { kind: 'tag', name: tagName });
  #|           if (list !== null) return list[0] || null;
  #|           let found = null;
  #|           traverseTree(htmlEl, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             if (matchesTagName(node, tagName)) { found = node; return false; }
  #|           });
  #|           return found;
  #|         }
  #|         const compiled = compileSelector(sel);
  #|         const groups = compiled.groups || [];
  #|         if (groups.length === 0) return null;
  #|         let found = null;
  #|         traverseTree(htmlEl, (node) => {
  #|           if (node._nodeType !== 1) return;
  #|           for (const group of groups) {
  #|             if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|             if (matchesSelectorGroupCompiled(node, group, htmlEl, true)) { found = node; return false; }
  #|           }
  #|         });
  #|         return found;
  #|       },
  #|       querySelectorAll(selector) {
  #|         const sel = String(selector);
  #|         const classTokens = parseSimpleClassSelector(sel);
  #|         if (classTokens) {
  #|           const list = getCandidatesByFilter(htmlEl, true, { kind: 'class', tokens: classTokens });
  #|           if (list !== null) return makeNodeList(list);
  #|           return makeNodeList(collectElements(htmlEl, true, (el) => matchesClassTokens(el, classTokens)));
  #|         }
  #|         const tagName = parseSimpleTagSelector(sel);
  #|         if (tagName) {
  #|           const list = getCandidatesByFilter(htmlEl, true, { kind: 'tag', name: tagName });
  #|           if (list !== null) return makeNodeList(list);
  #|           return makeNodeList(collectElements(htmlEl, true, (el) => matchesTagName(el, tagName)));
  #|         }
  #|         const compiled = compileSelector(sel);
  #|         const groups = compiled.groups || [];
  #|         if (groups.length === 0) return makeNodeList([]);
  #|         const allFilterable = groups.every(
  #|           g => g.filter && !(g.filter.kind === 'tag' && String(g.filter.name) === '*')
  #|         );
  #|         if (!allFilterable || !isConnectedToDocument(htmlEl)) {
  #|           const results = [];
  #|           traverseTree(htmlEl, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             for (const group of groups) {
  #|               if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|               if (matchesSelectorGroupCompiled(node, group, htmlEl, true)) {
  #|                 results.push(node);
  #|                 break;
  #|               }
  #|             }
  #|           });
  #|           return makeNodeList(results);
  #|         }
  #|         const fallbackTraversal = () => {
  #|           const results = [];
  #|           traverseTree(htmlEl, (node) => {
  #|             if (node._nodeType !== 1) return;
  #|             for (const group of groups) {
  #|               if (group.filter && !applySimpleFilter(node, group.filter)) continue;
  #|               if (matchesSelectorGroupCompiled(node, group, htmlEl, true)) {
  #|                 results.push(node);
  #|                 break;
  #|               }
  #|             }
  #|           });
  #|           return makeNodeList(results);
  #|         };
  #|         if (groups.length === 1) {
  #|           const group = groups[0];
  #|           const candidates = getCandidatesByFilter(htmlEl, true, group.filter, true);
  #|           if (candidates === null) return fallbackTraversal();
  #|           const results = [];
  #|           for (const node of candidates) {
  #|             if (!matchesSelectorGroupCompiled(node, group, htmlEl, true)) continue;
  #|             results.push(node);
  #|           }
  #|           return makeNodeList(results);
  #|         }
  #|         const results = [];
  #|         const seen = new Set();
  #|         let useIndex = true;
  #|         for (const group of groups) {
  #|           const candidates = getCandidatesByFilter(htmlEl, true, group.filter, true);
  #|           if (candidates === null) { useIndex = false; break; }
  #|           for (const node of candidates) {
  #|             if (!matchesSelectorGroupCompiled(node, group, htmlEl, true)) continue;
  #|             if (!seen.has(node)) { seen.add(node); results.push(node); }
  #|           }
  #|         }
  #|         if (!useIndex) return fallbackTraversal();
  #|         if (results.length > 1) {
  #|           results.sort((a, b) => {
  #|             if (a === b) return 0;
  #|             const pos = compareDocumentPositionImpl(a, b);
  #|             return (pos & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1;
  #|           });
  #|         }
  #|         return makeNodeList(results);
  #|       },
  #|       createEvent(type) {
  #|         const name = String(type);
  #|         const lower = asciiLowercase(name);
  #|         const eventMap = {
  #|           'beforeunloadevent': BeforeUnloadEvent,
  #|           'compositionevent': CompositionEvent,
  #|           'customevent': CustomEvent,
  #|           'devicemotionevent': DeviceMotionEvent,
  #|           'deviceorientationevent': DeviceOrientationEvent,
  #|           'dragevent': DragEvent,
  #|           'event': Event,
  #|           'events': Event,
  #|           'focusevent': FocusEvent,
  #|           'hashchangeevent': HashChangeEvent,
  #|           'htmlevents': Event,
  #|           'keyboardevent': KeyboardEvent,
  #|           'messageevent': MessageEvent,
  #|           'mouseevent': MouseEvent,
  #|           'mouseevents': MouseEvent,
  #|           'storageevent': StorageEvent,
  #|           'svgevents': Event,
  #|           'textevent': TextEvent,
  #|           'uievent': UIEvent,
  #|           'uievents': UIEvent,
  #|           'touchevent': TouchEvent
  #|         };
  #|         const ctor = eventMap[lower];
  #|         if (!ctor) {
  #|           throw new DOMException('Not supported', 'NotSupportedError');
  #|         }
  #|         if (lower === 'touchevent' && !('ontouchstart' in document)) {
  #|           throw new DOMException('Not supported', 'NotSupportedError');
  #|         }
  #|         const ev = new ctor('');
  #|         ev._type = '';
  #|         ev._target = null;
  #|         ev._currentTarget = null;
  #|         ev._eventPhase = 0;
  #|         ev._bubbles = false;
  #|         ev._cancelable = false;
  #|         ev._defaultPrevented = false;
  #|         ev._isTrusted = false;
  #|         return ev;
  #|       },
  #|       contains(node) { return nodeContains(this, node); },
  #|       createElementNS(ns, qualifiedName) {
  #|         const normalizedNs = ns === undefined || ns === '' ? null : ns;
  #|         const name = String(qualifiedName);
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createElement', id, tagName: name });
  #|         const el = createMockElement(name, id);
  #|         const colonIdx = name.indexOf(':');
  #|         const parts = colonIdx >= 0 ? name.split(":", 2) : [null, name];
  #|         const prefix = colonIdx >= 0 ? parts[0] : null;
  #|         const localName = parts[1];
  #|         const tagName = colonIdx >= 0 ? parts.join(":") : name;
  #|         el._localName = localName;
  #|         el._namespaceURI = normalizedNs;
  #|         el._prefix = prefix;
  #|         el._tagName = tagName;
  #|         el._ownerDocument = document;
  #|         if (normalizedNs === 'http://www.w3.org/1999/xhtml') {
  #|           const isLower = localName === localName.toLowerCase();
  #|           const Ctor = isLower ? (tagToConstructor[localName] || HTMLElement) : HTMLUnknownElement;
  #|           Object.setPrototypeOf(el, Ctor.prototype);
  #|         } else {
  #|           Object.setPrototypeOf(el, Element.prototype);
  #|         }
  #|         return el;
  #|       },
  #|       getElementsByTagNameNS(ns, tag) {
  #|         const name = String(tag);
  #|         const namespace = ns;
  #|         return makeHTMLCollection(() =>
  #|           collectElements(htmlEl, true, (el) => matchesNamespace(el, namespace) && matchesTagNameNS(el, name))
  #|         );
  #|       },
  #|       importNode(node, deep) {
  #|         if (!node) return null;
  #|         if (node._nodeType === 9 || node.nodeType === 9) {
  #|           throw new DOMException('Cannot import a document node', 'NotSupportedError');
  #|         }
  #|         const cloned = node.cloneNode ? node.cloneNode(deep) : node;
  #|         const updateOwner = (n) => {
  #|           n._ownerDocument = this;
  #|           if ('ownerDocument' in n) n.ownerDocument = this;
  #|           if (n._children) {
  #|             for (const c of n._children) updateOwner(c);
  #|           }
  #|         };
  #|         updateOwner(cloned);
  #|         return cloned;
  #|       },
  #|       adoptNode(node) {
  #|         if (!node) return null;
  #|         if (node._nodeType === 9 || node.nodeType === 9) {
  #|           throw new DOMException('Cannot adopt a document node', 'NotSupportedError');
  #|         }
  #|         const detach = (n) => {
  #|           if (!n._parent) return;
  #|           // Special handling for DocumentType nodes
  #|           if (n._nodeType === 10 || n.nodeType === 10) {
  #|             // DocumentType is not in _children but has _parent set
  #|             const parentDoc = n._parent;
  #|             if (parentDoc.doctype === n) {
  #|               // Don't clear doctype reference - just detach from tree
  #|             }
  #|             n._parent = null;
  #|             if ('parentNode' in n) n.parentNode = null;
  #|             return;
  #|           }
  #|           if (typeof n._parent.removeChild === 'function') {
  #|             try {
  #|               n._parent.removeChild(n);
  #|             } catch (e) {
  #|               // Fallback: manually detach from _children
  #|               if (Array.isArray(n._parent._children)) {
  #|                 const idx = n._parent._children.indexOf(n);
  #|                 if (idx >= 0) n._parent._children.splice(idx, 1);
  #|               }
  #|               n._parent = null;
  #|               if ('parentNode' in n) n.parentNode = null;
  #|             }
  #|           } else if (Array.isArray(n._parent._children)) {
  #|             const idx = n._parent._children.indexOf(n);
  #|             if (idx >= 0) n._parent._children.splice(idx, 1);
  #|             n._parent = null;
  #|             if ('parentNode' in n) n.parentNode = null;
  #|           }
  #|         };
  #|         const updateOwner = (n) => {
  #|           n.ownerDocument = this;
  #|           if (n._children) {
  #|             for (const c of n._children) updateOwner(c);
  #|           }
  #|         };
  #|         detach(node);
  #|         updateOwner(node);
  #|         return node;
  #|       },
  #|       createRange() {
  #|         const getNodeIndex = (node) => {
  #|           if (!node._parent && !node.parentNode) return 0;
  #|           const parent = node._parent || node.parentNode;
  #|           const children = parent._children || parent.childNodes || [];
  #|           for (let i = 0; i < children.length; i++) {
  #|             if (children[i] === node) return i;
  #|           }
  #|           return 0;
  #|         };
  #|         return {
  #|           startContainer: null, startOffset: 0, endContainer: null, endOffset: 0, collapsed: true,
  #|           setStart(node, offset) { this.startContainer = node; this.startOffset = offset; this._updateCollapsed(); },
  #|           setEnd(node, offset) { this.endContainer = node; this.endOffset = offset; this._updateCollapsed(); },
  #|           setStartBefore(node) {
  #|             const parent = node._parent || node.parentNode;
  #|             if (!parent) throw new DOMException('Node has no parent', 'InvalidNodeTypeError');
  #|             this.startContainer = parent;
  #|             this.startOffset = getNodeIndex(node);
  #|             this._updateCollapsed();
  #|           },
  #|           setStartAfter(node) {
  #|             const parent = node._parent || node.parentNode;
  #|             if (!parent) throw new DOMException('Node has no parent', 'InvalidNodeTypeError');
  #|             this.startContainer = parent;
  #|             this.startOffset = getNodeIndex(node) + 1;
  #|             this._updateCollapsed();
  #|           },
  #|           setEndBefore(node) {
  #|             const parent = node._parent || node.parentNode;
  #|             if (!parent) throw new DOMException('Node has no parent', 'InvalidNodeTypeError');
  #|             this.endContainer = parent;
  #|             this.endOffset = getNodeIndex(node);
  #|             this._updateCollapsed();
  #|           },
  #|           setEndAfter(node) {
  #|             const parent = node._parent || node.parentNode;
  #|             if (!parent) throw new DOMException('Node has no parent', 'InvalidNodeTypeError');
  #|             this.endContainer = parent;
  #|             this.endOffset = getNodeIndex(node) + 1;
  #|             this._updateCollapsed();
  #|           },
  #|           _updateCollapsed() {
  #|             this.collapsed = this.startContainer === this.endContainer && this.startOffset === this.endOffset;
  #|           },
  #|           selectNode(node) {
  #|             const parent = node._parent || node.parentNode;
  #|             if (parent) {
  #|               const idx = getNodeIndex(node);
  #|               this.startContainer = parent; this.startOffset = idx;
  #|               this.endContainer = parent; this.endOffset = idx + 1;
  #|             } else {
  #|               this.startContainer = this.endContainer = node;
  #|               this.startOffset = 0;
  #|               this.endOffset = (node._children || node.childNodes || []).length;
  #|             }
  #|             this._updateCollapsed();
  #|           },
  #|           selectNodeContents(node) {
  #|             this.startContainer = this.endContainer = node;
  #|             this.startOffset = 0;
  #|             this.endOffset = (node._children || node.childNodes || []).length;
  #|             this._updateCollapsed();
  #|           },
  #|           collapse(toStart) { if (toStart) { this.endContainer = this.startContainer; this.endOffset = this.startOffset; } else { this.startContainer = this.endContainer; this.startOffset = this.endOffset; } this.collapsed = true; },
  #|           cloneContents() { return document.createDocumentFragment(); },
  #|           deleteContents() {},
  #|           extractContents() { return document.createDocumentFragment(); },
  #|           insertNode(node) {},
  #|           surroundContents(node) {},
  #|           cloneRange() {
  #|             const newRange = document.createRange();
  #|             newRange.startContainer = this.startContainer;
  #|             newRange.startOffset = this.startOffset;
  #|             newRange.endContainer = this.endContainer;
  #|             newRange.endOffset = this.endOffset;
  #|             newRange.collapsed = this.collapsed;
  #|             return newRange;
  #|           },
  #|           detach() {},
  #|           toString() { return ''; },
  #|           compareBoundaryPoints(how, sourceRange) { return 0; },
  #|           comparePoint(node, offset) { return 0; },
  #|           isPointInRange(node, offset) { return false; },
  #|           intersectsNode(node) { return false; },
  #|           getClientRects() { return []; },
  #|           getBoundingClientRect() { return { x: 0, y: 0, width: 0, height: 0, top: 0, right: 0, bottom: 0, left: 0 }; }
  #|         };
  #|       },
  #|       createNodeIterator(root, whatToShow, filter) {
  #|         if (root === undefined) {
  #|           throw new TypeError("Failed to execute 'createNodeIterator': 1 argument required, but only 0 present.");
  #|         }
  #|         const show = whatToShow === undefined ? 0xFFFFFFFF : (whatToShow >>> 0);
  #|         const f = filter === undefined ? null : filter;
  #|         return { root, whatToShow: show, filter: f, nextNode() { return null; }, previousNode() { return null; } };
  #|       },
  #|       createTreeWalker(root, whatToShow, filter) {
  #|         if (root === undefined) {
  #|           throw new TypeError("Failed to execute 'createTreeWalker': 1 argument required, but only 0 present.");
  #|         }
  #|         const show = whatToShow === undefined ? 0xFFFFFFFF : (whatToShow >>> 0);
  #|         const f = filter === undefined ? null : filter;
  #|         return {
  #|           root,
  #|           currentNode: root,
  #|           whatToShow: show,
  #|           filter: f,
  #|           firstChild() {
  #|             const child = this.currentNode.firstChild || (this.currentNode._children && this.currentNode._children[0]) || null;
  #|             if (child) this.currentNode = child;
  #|             return child;
  #|           },
  #|           lastChild() {
  #|             const children = this.currentNode._children || this.currentNode.childNodes || [];
  #|             const child = children.length > 0 ? children[children.length - 1] : null;
  #|             if (child) this.currentNode = child;
  #|             return child;
  #|           },
  #|           nextSibling() {
  #|             const sibling = this.currentNode.nextSibling;
  #|             if (sibling) this.currentNode = sibling;
  #|             return sibling;
  #|           },
  #|           previousSibling() {
  #|             const sibling = this.currentNode.previousSibling;
  #|             if (sibling) this.currentNode = sibling;
  #|             return sibling;
  #|           },
  #|           parentNode() {
  #|             const parent = this.currentNode._parent || this.currentNode.parentNode;
  #|             if (parent && parent !== this.root) {
  #|               this.currentNode = parent;
  #|               return parent;
  #|             }
  #|             return null;
  #|           },
  #|           nextNode() { return null; },
  #|           previousNode() { return null; }
  #|         };
  #|       },
  #|       createCDATASection(data) {
  #|         throw new DOMException('CDATASection not supported in HTML documents', 'NotSupportedError');
  #|       },
  #|       createProcessingInstruction(target, data) {
  #|         const t = String(target);
  #|         const d = String(data);
  #|         if (d.indexOf('?>') >= 0) {
  #|           throw new DOMException('Invalid character in data', 'InvalidCharacterError');
  #|         }
  #|         if (!t || !/[A-Za-z_]/.test(t[0])) {
  #|           throw new DOMException('Invalid character in target', 'InvalidCharacterError');
  #|         }
  #|         for (let i = 0; i < t.length; i++) {
  #|           const ch = t[i];
  #|           if (ch === '\\u00D7' || ch === '\\\\' || ch === '\\f') {
  #|             throw new DOMException('Invalid character in target', 'InvalidCharacterError');
  #|           }
  #|           if (i > 0 && ch === '\\u00B7') continue;
  #|           if (!/[A-Za-z0-9._:-]/.test(ch)) {
  #|             throw new DOMException('Invalid character in target', 'InvalidCharacterError');
  #|           }
  #|         }
  #|         const id = nodeIdCounter++;
  #|         return createMockProcessingInstruction(target, data, id);
  #|       },
  #|       get defaultView() { return typeof window !== 'undefined' ? window : null; },
  #|       getRootNode() { return this; },
  #|       get readyState() { return 'complete'; },
  #|       get hidden() { return false; },
  #|       get visibilityState() { return 'visible'; },
  #|       ontouchstart: null,
  #|       get dir() { return ''; },
  #|       set dir(v) {},
  #|       get firstElementChild() { return htmlEl; },
  #|       get lastElementChild() { return htmlEl; },
  #|       get childElementCount() { return 1; },
  #|       prepend(...nodes) {
  #|         for (const n of nodes.reverse()) {
  #|           const node = (n && n._mockId !== undefined) ? n : this.createTextNode(String(n));
  #|           htmlEl.insertBefore(node, htmlEl.firstChild);
  #|         }
  #|       },
  #|       append(...nodes) {
  #|         for (const n of nodes) {
  #|           const node = (n && n._mockId !== undefined) ? n : this.createTextNode(String(n));
  #|           htmlEl.appendChild(node);
  #|         }
  #|       },
  #|       replaceChildren(...nodes) {
  #|         while (htmlEl._children.length > 0) htmlEl.removeChild(htmlEl._children[0]);
  #|         this.append(...nodes);
  #|       }
  #|     };
  #|     document.normalize = function() {
  #|       const nodes = document.childNodes;
  #|       for (let i = 0; i < nodes.length; i++) {
  #|         const child = nodes[i];
  #|         if (child && typeof child.normalize === 'function') child.normalize();
  #|       }
  #|     };
  #|     htmlEl._parent = document;
  #|     htmlEl.parentNode = document;
  #|     ensureDocumentIndexes(document);
  #|     indexSubtree(htmlEl, document);
  #|     if (typeof globalThis !== 'undefined') {
  #|       globalThis.document = document;
  #|     }
  #|
  #|     const console = {
  #|       log(...args) { logs.push(args.map(String).join(' ')); },
  #|       warn(...args) { logs.push('[WARN] ' + args.map(String).join(' ')); },
  #|       error(...args) { logs.push('[ERROR] ' + args.map(String).join(' ')); },
  #|       info(...args) { logs.push('[INFO] ' + args.map(String).join(' ')); }
  #|     };
  #|
  #|     // Event class
  #|     class Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         this._type = type === undefined ? '' : String(type);
  #|         this._bubbles = !!options.bubbles;
  #|         this._cancelable = !!options.cancelable;
  #|         this._composed = !!options.composed;
  #|         this._defaultPrevented = false;
  #|         this._propagationStopped = false;
  #|         this._immediatePropagationStopped = false;
  #|         this._target = null;
  #|         this._currentTarget = null;
  #|         this._eventPhase = 0;
  #|         this._timeStamp = Date.now();
  #|         this._isTrusted = false;
  #|       }
  #|       get type() { return this._type; }
  #|       get target() { return this._target; }
  #|       get srcElement() { return this._target; }
  #|       get currentTarget() { return this._currentTarget; }
  #|       get bubbles() { return this._bubbles; }
  #|       get cancelable() { return this._cancelable; }
  #|       get defaultPrevented() { return this._defaultPrevented; }
  #|       get composed() { return this._composed; }
  #|       get isTrusted() { return this._isTrusted; }
  #|       get timeStamp() { return this._timeStamp; }
  #|       get eventPhase() { return this._eventPhase; }
  #|       stopPropagation() { this._propagationStopped = true; }
  #|       stopImmediatePropagation() { this._immediatePropagationStopped = true; this._propagationStopped = true; }
  #|       preventDefault() { if (this._cancelable) this._defaultPrevented = true; }
  #|       initEvent(type, bubbles, cancelable) {
  #|         this._type = type;
  #|         this._bubbles = !!bubbles;
  #|         this._cancelable = !!cancelable;
  #|       }
  #|     }
  #|     Event.NONE = 0;
  #|     Event.CAPTURING_PHASE = 1;
  #|     Event.AT_TARGET = 2;
  #|     Event.BUBBLING_PHASE = 3;
  #|
  #|     class UIEvent extends Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         super(type, options);
  #|         this._view = options.view || null;
  #|         this._detail = options.detail || 0;
  #|       }
  #|       get view() { return this._view; }
  #|       get detail() { return this._detail; }
  #|       initUIEvent(type, bubbles, cancelable, view, detail) {
  #|         this.initEvent(type, bubbles, cancelable);
  #|         this._view = view || null;
  #|         this._detail = detail || 0;
  #|       }
  #|     }
  #|     class MouseEvent extends UIEvent {
  #|       constructor(type, options) {
  #|         super(type, options);
  #|         options = options || {};
  #|         this._screenX = options.screenX || 0;
  #|         this._screenY = options.screenY || 0;
  #|         this._clientX = options.clientX || 0;
  #|         this._clientY = options.clientY || 0;
  #|       }
  #|       get screenX() { return this._screenX; }
  #|       get screenY() { return this._screenY; }
  #|       get clientX() { return this._clientX; }
  #|       get clientY() { return this._clientY; }
  #|     }
  #|     class FocusEvent extends UIEvent {}
  #|     class KeyboardEvent extends UIEvent {}
  #|     class CompositionEvent extends UIEvent {}
  #|     class CustomEvent extends Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         super(type, options);
  #|         this._detail = options.detail !== undefined ? options.detail : null;
  #|       }
  #|       get detail() { return this._detail; }
  #|       initCustomEvent(type, bubbles, cancelable, detail) {
  #|         this.initEvent(type, bubbles, cancelable);
  #|         this._detail = detail;
  #|       }
  #|     }
  #|     class HashChangeEvent extends Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         super(type, options);
  #|         this._oldURL = options.oldURL || '';
  #|         this._newURL = options.newURL || '';
  #|       }
  #|       get oldURL() { return this._oldURL; }
  #|       get newURL() { return this._newURL; }
  #|     }
  #|     class MessageEvent extends Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         super(type, options);
  #|         this.data = options.data;
  #|         this.origin = options.origin || '';
  #|         this.lastEventId = options.lastEventId || '';
  #|         this.source = options.source || null;
  #|         this.ports = options.ports || [];
  #|       }
  #|     }
  #|     class StorageEvent extends Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         super(type, options);
  #|         this.key = options.key || null;
  #|         this.oldValue = options.oldValue || null;
  #|         this.newValue = options.newValue || null;
  #|         this.url = options.url || '';
  #|         this.storageArea = options.storageArea || null;
  #|       }
  #|     }
  #|     class DragEvent extends MouseEvent {}
  #|     class DeviceMotionEvent extends Event {}
  #|     class DeviceOrientationEvent extends Event {}
  #|     class TextEvent extends UIEvent {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         super(type, options);
  #|         this.data = options.data || '';
  #|       }
  #|     }
  #|     class BeforeUnloadEvent extends Event {}
  #|     class TouchEvent extends UIEvent {}
  #|
  #|     // Window object
  #|     const _timers = { nextId: 1, timeouts: {}, intervals: {} };
  #|     const _animationFrames = { nextId: 1, callbacks: {} };
  #|
  #|     const window = {
  #|       get window() { return this; },
  #|       get self() { return this; },
  #|       get document() { return document; },
  #|       Event: Event,
  #|       UIEvent: UIEvent,
  #|       MouseEvent: MouseEvent,
  #|       FocusEvent: FocusEvent,
  #|       KeyboardEvent: KeyboardEvent,
  #|       CompositionEvent: CompositionEvent,
  #|       CustomEvent: CustomEvent,
  #|       HashChangeEvent: HashChangeEvent,
  #|       MessageEvent: MessageEvent,
  #|       StorageEvent: StorageEvent,
  #|       DragEvent: DragEvent,
  #|       DeviceMotionEvent: DeviceMotionEvent,
  #|       DeviceOrientationEvent: DeviceOrientationEvent,
  #|       TextEvent: TextEvent,
  #|       BeforeUnloadEvent: BeforeUnloadEvent,
  #|       TouchEvent: TouchEvent,
  #|       get name() { return ''; },
  #|       get location() { return { href: 'about:blank', protocol: 'about:', host: '', hostname: '', port: '', pathname: 'blank', search: '', hash: '', origin: 'null' }; },
  #|       get history() { return { length: 1, state: null, back() {}, forward() {}, go() {}, pushState() {}, replaceState() {} }; },
  #|       get navigator() { return { userAgent: 'Crater/1.0', language: 'en', languages: ['en'], platform: 'Unknown', cookieEnabled: false, onLine: true }; },
  #|       devicePixelRatio: 1,
  #|       innerWidth: 1024,
  #|       innerHeight: 768,
  #|       outerWidth: 1024,
  #|       outerHeight: 768,
  #|       scrollX: 0,
  #|       scrollY: 0,
  #|       get pageXOffset() { return this.scrollX; },
  #|       get pageYOffset() { return this.scrollY; },
  #|       screenX: 0,
  #|       screenY: 0,
  #|       scroll(options) { if (options) { this.scrollX = options.left || 0; this.scrollY = options.top || 0; } },
  #|       scrollTo(options) { this.scroll(options); },
  #|       scrollBy(options) { if (options) { this.scrollX += options.left || 0; this.scrollY += options.top || 0; } },
  #|       alert(msg) { logs.push('[ALERT] ' + (msg || '')); },
  #|       close() {},
  #|       focus() {},
  #|       blur() {},
  #|       print() {},
  #|       stop() {},
  #|       setTimeout(handler, timeout) {
  #|         const id = _timers.nextId++;
  #|         _timers.timeouts[id] = { handler, timeout: timeout || 0 };
  #|         return id;
  #|       },
  #|       clearTimeout(id) { delete _timers.timeouts[id]; },
  #|       setInterval(handler, timeout) {
  #|         const id = _timers.nextId++;
  #|         _timers.intervals[id] = { handler, timeout: timeout || 0 };
  #|         return id;
  #|       },
  #|       clearInterval(id) { delete _timers.intervals[id]; },
  #|       requestAnimationFrame(callback) {
  #|         const id = _animationFrames.nextId++;
  #|         _animationFrames.callbacks[id] = callback;
  #|         return id;
  #|       },
  #|       cancelAnimationFrame(id) { delete _animationFrames.callbacks[id]; },
  #|       getComputedStyle(elt, pseudoElt) {
  #|         return new Proxy({}, {
  #|           get(_, prop) { return ''; },
  #|           getPropertyValue(prop) { return ''; }
  #|         });
  #|       },
  #|       matchMedia(query) {
  #|         return {
  #|           matches: false,
  #|           media: query,
  #|           onchange: null,
  #|           addListener(cb) {},
  #|           removeListener(cb) {},
  #|           addEventListener(type, cb) {},
  #|           removeEventListener(type, cb) {},
  #|           dispatchEvent(ev) { return true; }
  #|         };
  #|       },
  #|       addEventListener(type, listener, options) {},
  #|       removeEventListener(type, listener, options) {},
  #|       dispatchEvent(event) { return true; },
  #|       Event: Event,
  #|       Node: Node,
  #|       Attr: Attr,
  #|       CharacterData: CharacterData,
  #|       Element: Element,
  #|       Document: Document,
  #|       XMLDocument: XMLDocument,
  #|       HTMLDocument: HTMLDocument,
  #|       DocumentType: DocumentType,
  #|       DocumentFragment: DocumentFragment,
  #|       Text: Text,
  #|       Comment: Comment,
  #|       DOMParser: DOMParser,
  #|       DOMException: DOMException,
  #|       DOMImplementation: DOMImplementation,
  #|       HTMLElement: HTMLElement,
  #|       HTMLHtmlElement: HTMLHtmlElement,
  #|       HTMLHeadElement: HTMLHeadElement,
  #|       HTMLBodyElement: HTMLBodyElement,
  #|       HTMLDivElement: HTMLDivElement,
  #|       HTMLSpanElement: HTMLSpanElement,
  #|       HTMLTitleElement: HTMLTitleElement,
  #|       HTMLAnchorElement: HTMLAnchorElement,
  #|       HTMLAreaElement: HTMLAreaElement,
  #|       HTMLAudioElement: HTMLAudioElement,
  #|       HTMLBaseElement: HTMLBaseElement,
  #|       HTMLBRElement: HTMLBRElement,
  #|       HTMLButtonElement: HTMLButtonElement,
  #|       HTMLCanvasElement: HTMLCanvasElement,
  #|       HTMLDataElement: HTMLDataElement,
  #|       HTMLDataListElement: HTMLDataListElement,
  #|       HTMLDetailsElement: HTMLDetailsElement,
  #|       HTMLDialogElement: HTMLDialogElement,
  #|       HTMLDListElement: HTMLDListElement,
  #|       HTMLEmbedElement: HTMLEmbedElement,
  #|       HTMLFieldSetElement: HTMLFieldSetElement,
  #|       HTMLFormElement: HTMLFormElement,
  #|       HTMLHeadingElement: HTMLHeadingElement,
  #|       HTMLHRElement: HTMLHRElement,
  #|       HTMLIFrameElement: HTMLIFrameElement,
  #|       HTMLImageElement: HTMLImageElement,
  #|       HTMLInputElement: HTMLInputElement,
  #|       HTMLLabelElement: HTMLLabelElement,
  #|       HTMLLegendElement: HTMLLegendElement,
  #|       HTMLLIElement: HTMLLIElement,
  #|       HTMLLinkElement: HTMLLinkElement,
  #|       HTMLMapElement: HTMLMapElement,
  #|       HTMLMenuElement: HTMLMenuElement,
  #|       HTMLMetaElement: HTMLMetaElement,
  #|       HTMLMeterElement: HTMLMeterElement,
  #|       HTMLModElement: HTMLModElement,
  #|       HTMLObjectElement: HTMLObjectElement,
  #|       HTMLOListElement: HTMLOListElement,
  #|       HTMLOptGroupElement: HTMLOptGroupElement,
  #|       HTMLOptionElement: HTMLOptionElement,
  #|       HTMLOutputElement: HTMLOutputElement,
  #|       HTMLParagraphElement: HTMLParagraphElement,
  #|       HTMLPictureElement: HTMLPictureElement,
  #|       HTMLPreElement: HTMLPreElement,
  #|       HTMLProgressElement: HTMLProgressElement,
  #|       HTMLQuoteElement: HTMLQuoteElement,
  #|       HTMLScriptElement: HTMLScriptElement,
  #|       HTMLSelectElement: HTMLSelectElement,
  #|       HTMLSlotElement: HTMLSlotElement,
  #|       HTMLSourceElement: HTMLSourceElement,
  #|       HTMLStyleElement: HTMLStyleElement,
  #|       HTMLTableElement: HTMLTableElement,
  #|       HTMLTableCellElement: HTMLTableCellElement,
  #|       HTMLTableColElement: HTMLTableColElement,
  #|       HTMLTableRowElement: HTMLTableRowElement,
  #|       HTMLTableSectionElement: HTMLTableSectionElement,
  #|       HTMLTemplateElement: HTMLTemplateElement,
  #|       HTMLTextAreaElement: HTMLTextAreaElement,
  #|       HTMLTimeElement: HTMLTimeElement,
  #|       HTMLTrackElement: HTMLTrackElement,
  #|       HTMLUListElement: HTMLUListElement,
  #|       HTMLVideoElement: HTMLVideoElement,
  #|       HTMLUnknownElement: HTMLUnknownElement,
  #|       HTMLTableCaptionElement: HTMLTableCaptionElement,
  #|       HTMLDirectoryElement: HTMLDirectoryElement,
  #|       HTMLFontElement: HTMLFontElement,
  #|       HTMLMarqueeElement: HTMLMarqueeElement,
  #|       HTMLFrameElement: HTMLFrameElement,
  #|       HTMLFrameSetElement: HTMLFrameSetElement,
  #|       HTMLParamElement: HTMLParamElement
  #|     };
  #|     if (typeof globalThis !== 'undefined') {
  #|       globalThis.window = window;
  #|       globalThis.self = window;
  #|       globalThis.location = window.location;
  #|       globalThis.navigator = window.navigator;
  #|       globalThis.queueMicrotask = queueMicrotask;
  #|       globalThis.fetch = fetch;
  #|       globalThis.Response = Response;
  #|       globalThis.Request = Request;
  #|       globalThis.Headers = Headers;
  #|       globalThis.Blob = Blob;
  #|     }
  #|     window.queueMicrotask = queueMicrotask;
  #|     window.fetch = fetch;
  #|     window.Response = Response;
  #|     window.Request = Request;
  #|     window.Headers = Headers;
  #|     window.Blob = Blob;
  #|     const frames = [ { document: document.implementation.createHTMLDocument('') } ];
  #|     window.frames = frames;
  #|     if (typeof globalThis !== 'undefined') {
  #|       globalThis.frames = frames;
  #|     }
  #|
  #|     // Make window globals accessible
  #|     const setTimeout = window.setTimeout.bind(window);
  #|     const clearTimeout = window.clearTimeout.bind(window);
  #|     const setInterval = window.setInterval.bind(window);
  #|     const clearInterval = window.clearInterval.bind(window);
  #|     const requestAnimationFrame = window.requestAnimationFrame.bind(window);
  #|     const cancelAnimationFrame = window.cancelAnimationFrame.bind(window);
  #|     const alert = window.alert.bind(window);
  #|     const navigator = window.navigator;
  #|
  #|     // DOMTokenList class
  #|     function DOMTokenList(getter, setter) { this._getter = getter; this._setter = setter; }
  #|     DOMTokenList.prototype._getAttr = function() { return this._getter(); };
  #|     DOMTokenList.prototype._tokenize = function() {
  #|       var value = this._getter();
  #|       var str = value === null || value === undefined ? '' : String(value);
  #|       var parts = splitAsciiWhitespace(str);
  #|       var seen = new Set();
  #|       var tokens = [];
  #|       for (var i = 0; i < parts.length; i++) {
  #|         var part = parts[i];
  #|         if (!seen.has(part)) { seen.add(part); tokens.push(part); }
  #|       }
  #|       return tokens;
  #|     };
  #|     DOMTokenList.prototype._setTokens = function(tokens, hadAttr) {
  #|       if (!tokens || tokens.length === 0) {
  #|         if (hadAttr) this._setter('');
  #|         else this._setter(null);
  #|         return;
  #|       }
  #|       this._setter(tokens.join(' '));
  #|     };
  #|     DOMTokenList.prototype._validateToken = function(token) {
  #|       var str = String(token);
  #|       if (str.length === 0) throw new DOMException('The token provided must not be empty.', 'SyntaxError');
  #|       if (containsAsciiWhitespace(str)) {
  #|         throw new DOMException('The token provided contains HTML space characters, which are not valid in tokens.', 'InvalidCharacterError');
  #|       }
  #|       return str;
  #|     };
  #|     Object.defineProperties(DOMTokenList.prototype, {
  #|       length: { get: function() { return this._tokenize().length; } },
  #|       value: { get: function() { var v = this._getter(); return v === null || v === undefined ? '' : String(v); }, set: function(v) { this._setter(String(v)); } }
  #|     });
  #|     DOMTokenList.prototype.item = function(index) {
  #|       var n = Number(index);
  #|       if (!Number.isFinite(n) || n < 0) return null;
  #|       var tokens = this._tokenize();
  #|       return tokens[n] || null;
  #|     };
  #|     DOMTokenList.prototype.contains = function(token) {
  #|       var str = String(token);
  #|       if (str.length === 0 || containsAsciiWhitespace(str)) return false;
  #|       return this._tokenize().indexOf(str) >= 0;
  #|     };
  #|     DOMTokenList.prototype.add = function() {
  #|       var hadAttr = this._getter() !== null && this._getter() !== undefined;
  #|       var list = this._tokenize();
  #|       var set = new Set(list);
  #|       var args = Array.prototype.slice.call(arguments);
  #|       for (var i = 0; i < args.length; i++) {
  #|         var tok = this._validateToken(args[i]);
  #|         if (!set.has(tok)) { set.add(tok); list.push(tok); }
  #|       }
  #|       this._setTokens(list, hadAttr);
  #|     };
  #|     DOMTokenList.prototype.remove = function() {
  #|       var hadAttr = this._getter() !== null && this._getter() !== undefined;
  #|       var list = this._tokenize();
  #|       var removeSet = new Set();
  #|       var args = Array.prototype.slice.call(arguments);
  #|       for (var i = 0; i < args.length; i++) {
  #|         var tok = this._validateToken(args[i]);
  #|         removeSet.add(tok);
  #|       }
  #|       var filtered = list.filter(function(t) { return !removeSet.has(t); });
  #|       this._setTokens(filtered, hadAttr);
  #|     };
  #|     DOMTokenList.prototype.toggle = function(token, force) {
  #|       var tok = this._validateToken(token);
  #|       var hadAttr = this._getter() !== null && this._getter() !== undefined;
  #|       var list = this._tokenize();
  #|       var idx = list.indexOf(tok);
  #|       var has = idx >= 0;
  #|       if (force === undefined) {
  #|         if (has) {
  #|           list.splice(idx, 1);
  #|           this._setTokens(list, hadAttr);
  #|           return false;
  #|         } else {
  #|           list.push(tok);
  #|           this._setTokens(list, hadAttr);
  #|           return true;
  #|         }
  #|       }
  #|       if (force) {
  #|         if (!has) {
  #|           list.push(tok);
  #|           this._setTokens(list, hadAttr);
  #|         }
  #|         return true;
  #|       } else {
  #|         if (has) {
  #|           list.splice(idx, 1);
  #|           this._setTokens(list, hadAttr);
  #|         }
  #|         return false;
  #|       }
  #|     };
  #|     DOMTokenList.prototype.replace = function(token, newToken) {
  #|       var tokStr = String(token);
  #|       var newStr = String(newToken);
  #|       if (tokStr.length === 0 || newStr.length === 0) {
  #|         throw new DOMException('The token provided must not be empty.', 'SyntaxError');
  #|       }
  #|       if (containsAsciiWhitespace(tokStr) || containsAsciiWhitespace(newStr)) {
  #|         throw new DOMException('The token provided contains HTML space characters, which are not valid in tokens.', 'InvalidCharacterError');
  #|       }
  #|       var hadAttr = this._getter() !== null && this._getter() !== undefined;
  #|       var list = this._tokenize();
  #|       var idx = list.indexOf(tokStr);
  #|       if (idx < 0) return false;
  #|       list[idx] = newStr;
  #|       var seen = new Set();
  #|       var deduped = [];
  #|       for (var i = 0; i < list.length; i++) {
  #|         var t = list[i];
  #|         if (!seen.has(t)) { seen.add(t); deduped.push(t); }
  #|       }
  #|       this._setTokens(deduped, hadAttr);
  #|       return true;
  #|     };
  #|     DOMTokenList.prototype.supports = function() { throw new TypeError('Not supported'); };
  #|     DOMTokenList.prototype.toString = function() {
  #|       var v = this._getter();
  #|       return v === null || v === undefined ? '' : String(v);
  #|     };
  #|     DOMTokenList.prototype.forEach = function(cb, thisArg) {
  #|       var tokens = this._tokenize();
  #|       for (var i = 0; i < tokens.length; i++) cb.call(thisArg, tokens[i], i, this);
  #|     };
  #|     DOMTokenList.prototype.keys = function() {
  #|       var tokens = this._tokenize();
  #|       return tokens.map(function(_, i) { return i; })[Symbol.iterator]();
  #|     };
  #|     DOMTokenList.prototype.values = function() {
  #|       return this._tokenize()[Symbol.iterator]();
  #|     };
  #|     DOMTokenList.prototype.entries = function() {
  #|       var tokens = this._tokenize();
  #|       return tokens.map(function(v, i) { return [i, v]; })[Symbol.iterator]();
  #|     };
  #|     DOMTokenList.prototype[Symbol.iterator] = function() { return this.values(); };
  #|
  #|     // DOMRect class
  #|     class DOMRect {
  #|       constructor(x, y, width, height) {
  #|         this.x = x || 0;
  #|         this.y = y || 0;
  #|         this.width = width || 0;
  #|         this.height = height || 0;
  #|       }
  #|       get top() { return this.y; }
  #|       get right() { return this.x + this.width; }
  #|       get bottom() { return this.y + this.height; }
  #|       get left() { return this.x; }
  #|       static fromRect(rect) { return new DOMRect(rect.x, rect.y, rect.width, rect.height); }
  #|       toJSON() { return { x: this.x, y: this.y, width: this.width, height: this.height, top: this.top, right: this.right, bottom: this.bottom, left: this.left }; }
  #|     }
  #|
  #|     // Storage class
  #|     class Storage {
  #|       constructor() { this._data = {}; }
  #|       get length() { return Object.keys(this._data).length; }
  #|       key(index) { return Object.keys(this._data)[index] || null; }
  #|       getItem(key) { return this._data.hasOwnProperty(key) ? this._data[key] : null; }
  #|       setItem(key, value) { this._data[key] = String(value); }
  #|       removeItem(key) { delete this._data[key]; }
  #|       clear() { this._data = {}; }
  #|     }
  #|     const localStorage = new Storage();
  #|     const sessionStorage = new Storage();
  #|
  #|     // MutationObserver class
  #|     class MutationObserver {
  #|       constructor(callback) { this._callback = callback; this._records = []; this._targets = []; }
  #|       observe(target, options) { this._targets.push({ target, options }); }
  #|       disconnect() { this._targets = []; }
  #|       takeRecords() { const records = this._records; this._records = []; return records; }
  #|     }
  #|
  #|     // IntersectionObserver class
  #|     class IntersectionObserver {
  #|       constructor(callback, options) {
  #|         this._callback = callback;
  #|         this._options = options || {};
  #|         this._targets = [];
  #|       }
  #|       get root() { return this._options.root || null; }
  #|       get rootMargin() { return this._options.rootMargin || '0px'; }
  #|       get thresholds() { return this._options.threshold ? [].concat(this._options.threshold) : [0]; }
  #|       observe(target) { this._targets.push(target); }
  #|       unobserve(target) { this._targets = this._targets.filter(function(t) { return t !== target; }); }
  #|       disconnect() { this._targets = []; }
  #|       takeRecords() { return []; }
  #|     }
  #|
  #|     // ResizeObserver class
  #|     class ResizeObserver {
  #|       constructor(callback) { this._callback = callback; this._targets = []; }
  #|       observe(target, options) { this._targets.push({ target: target, options: options }); }
  #|       unobserve(target) { this._targets = this._targets.filter(function(t) { return t.target !== target; }); }
  #|       disconnect() { this._targets = []; }
  #|     }
  #|
  #|     // Automation helpers for CDP/BiDi compatibility
  #|     // waitForSelector - polls until an element matching selector appears
  #|     window.__waitForSelector = function(selector, options) {
  #|       options = options || {};
  #|       var timeout = options.timeout || 30000;
  #|       var interval = options.interval || 100;
  #|       var visible = options.visible || false;
  #|       var hidden = options.hidden || false;
  #|       var startTime = Date.now();
  #|       return new Promise(function(resolve, reject) {
  #|         function check() {
  #|           var element = document.querySelector(selector);
  #|           if (element) {
  #|             if (visible) {
  #|               // Check if element is visible (has size and not hidden)
  #|               var rect = element.getBoundingClientRect ? element.getBoundingClientRect() : { width: 1, height: 1 };
  #|               var isVisible = rect.width > 0 && rect.height > 0 && !element.hidden;
  #|               if (isVisible) { resolve(element); return; }
  #|             } else if (hidden) {
  #|               // Wait for element to be hidden (not found or hidden)
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
  #|     // waitForFunction - polls until a function returns truthy value
  #|     window.__waitForFunction = function(fn, options) {
  #|       options = options || {};
  #|       var timeout = options.timeout || 30000;
  #|       var interval = options.interval || 100;
  #|       var args = options.args || [];
  #|       var startTime = Date.now();
  #|       return new Promise(function(resolve, reject) {
  #|         function check() {
  #|           try {
  #|             var result = typeof fn === 'function' ? fn.apply(null, args) : eval('(' + fn + ')').apply(null, args);
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
  #|     // waitFor - generic wait with condition
  #|     window.__waitFor = function(condition, options) {
  #|       if (typeof condition === 'string') {
  #|         return window.__waitForSelector(condition, options);
  #|       }
  #|       return window.__waitForFunction(condition, options);
  #|     };
  #|
  #|     // FormData class (using bracket notation for reserved words)
  #|     function FormData(form) { this._data = []; }
  #|     FormData.prototype.append = function(name, value) { this._data.push([name, String(value)]); };
  #|     FormData.prototype['delete'] = function(name) { this._data = this._data.filter(function(e) { return e[0] !== name; }); };
  #|     FormData.prototype['get'] = function(name) { var entry = this._data.find(function(e) { return e[0] === name; }); return entry ? entry[1] : null; };
  #|     FormData.prototype.getAll = function(name) { return this._data.filter(function(e) { return e[0] === name; }).map(function(e) { return e[1]; }); };
  #|     FormData.prototype.has = function(name) { return this._data.some(function(e) { return e[0] === name; }); };
  #|     FormData.prototype['set'] = function(name, value) { this['delete'](name); this.append(name, value); };
  #|     FormData.prototype.keys = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][0], done: false } : { done: true }; } }; };
  #|     FormData.prototype.values = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][1], done: false } : { done: true }; } }; };
  #|     FormData.prototype.entries = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++], done: false } : { done: true }; } }; };
  #|     FormData.prototype.forEach = function(cb, thisArg) { var self = this; this._data.forEach(function(e) { cb.call(thisArg, e[1], e[0], self); }); };
  #|
  #|     // URLSearchParams class (using bracket notation for reserved words)
  #|     function URLSearchParams(init) {
  #|       this._data = [];
  #|       if (typeof init === 'string') {
  #|         var str = init.charAt(0) === '?' ? init.slice(1) : init;
  #|         if (str) {
  #|           var pairs = str.split('&');
  #|           for (var i = 0; i < pairs.length; i++) {
  #|             var parts = pairs[i].split('=');
  #|             this._data.push([decodeURIComponent(parts[0]), decodeURIComponent(parts[1] || '')]);
  #|           }
  #|         }
  #|       } else if (Array.isArray(init)) {
  #|         for (var j = 0; j < init.length; j++) {
  #|           this._data.push([String(init[j][0]), String(init[j][1])]);
  #|         }
  #|       } else if (init && typeof init === 'object') {
  #|         var keys = Object.keys(init);
  #|         for (var k = 0; k < keys.length; k++) {
  #|           this._data.push([keys[k], String(init[keys[k]])]);
  #|         }
  #|       }
  #|     }
  #|     URLSearchParams.prototype.append = function(name, value) { this._data.push([String(name), String(value)]); };
  #|     URLSearchParams.prototype['delete'] = function(name) { this._data = this._data.filter(function(e) { return e[0] !== name; }); };
  #|     URLSearchParams.prototype['get'] = function(name) { var entry = this._data.find(function(e) { return e[0] === name; }); return entry ? entry[1] : null; };
  #|     URLSearchParams.prototype.getAll = function(name) { return this._data.filter(function(e) { return e[0] === name; }).map(function(e) { return e[1]; }); };
  #|     URLSearchParams.prototype.has = function(name) { return this._data.some(function(e) { return e[0] === name; }); };
  #|     URLSearchParams.prototype['set'] = function(name, value) { this['delete'](name); this.append(name, value); };
  #|     URLSearchParams.prototype.sort = function() { this._data.sort(function(a, b) { return a[0].localeCompare(b[0]); }); };
  #|     URLSearchParams.prototype.toString = function() { return this._data.map(function(e) { return encodeURIComponent(e[0]) + '=' + encodeURIComponent(e[1]); }).join('&'); };
  #|     URLSearchParams.prototype.keys = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][0], done: false } : { done: true }; } }; };
  #|     URLSearchParams.prototype.values = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][1], done: false } : { done: true }; } }; };
  #|     URLSearchParams.prototype.entries = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++], done: false } : { done: true }; } }; };
  #|     URLSearchParams.prototype.forEach = function(cb, thisArg) { var self = this; this._data.forEach(function(e) { cb.call(thisArg, e[1], e[0], self); }); };
  #|
  #|     // URL class (simplified without complex regex)
  #|     function URL(url, base) {
  #|       this._protocol = 'https:';
  #|       this._hostname = '';
  #|       this._port = '';
  #|       this._pathname = '/';
  #|       this._search = '';
  #|       this._hash = '';
  #|       this._username = '';
  #|       this._password = '';
  #|       var fullUrl = encodeURI(String(url));
  #|       if (base && url.indexOf('://') === -1) {
  #|         var baseSlash = base.lastIndexOf('/');
  #|         if (baseSlash >= 0) fullUrl = base.substring(0, baseSlash + 1) + url;
  #|       }
  #|       var protoEnd = fullUrl.indexOf('://');
  #|       if (protoEnd >= 0) {
  #|         this._protocol = fullUrl.substring(0, protoEnd) + ':';
  #|         fullUrl = fullUrl.substring(protoEnd + 3);
  #|       }
  #|       var hashIdx = fullUrl.indexOf('#');
  #|       if (hashIdx >= 0) { this._hash = fullUrl.substring(hashIdx); fullUrl = fullUrl.substring(0, hashIdx); }
  #|       var searchIdx = fullUrl.indexOf('?');
  #|       if (searchIdx >= 0) { this._search = fullUrl.substring(searchIdx); fullUrl = fullUrl.substring(0, searchIdx); }
  #|       var pathIdx = fullUrl.indexOf('/');
  #|       if (pathIdx >= 0) { this._pathname = fullUrl.substring(pathIdx); fullUrl = fullUrl.substring(0, pathIdx); }
  #|       var portIdx = fullUrl.indexOf(':');
  #|       if (portIdx >= 0) { this._port = fullUrl.substring(portIdx + 1); this._hostname = fullUrl.substring(0, portIdx); }
  #|       else { this._hostname = fullUrl; }
  #|       this._searchParams = new URLSearchParams(this._search);
  #|     }
  #|     URL.prototype = {
  #|       get href() { return this._protocol + '//' + this.host + this._pathname + this._search + this._hash; },
  #|       set href(v) { var u = new URL(v); this._protocol = u._protocol; this._hostname = u._hostname; this._port = u._port; this._pathname = u._pathname; this._search = u._search; this._hash = u._hash; },
  #|       get origin() { return this._protocol + '//' + this.host; },
  #|       get protocol() { return this._protocol; },
  #|       set protocol(v) { this._protocol = v.charAt(v.length - 1) === ':' ? v : v + ':'; },
  #|       get username() { return this._username; },
  #|       set username(v) { this._username = v; },
  #|       get password() { return this._password; },
  #|       set password(v) { this._password = v; },
  #|       get host() { return this._port ? this._hostname + ':' + this._port : this._hostname; },
  #|       set host(v) { var parts = v.split(':'); this._hostname = parts[0]; this._port = parts[1] || ''; },
  #|       get hostname() { return this._hostname; },
  #|       set hostname(v) { this._hostname = v; },
  #|       get port() { return this._port; },
  #|       set port(v) { this._port = v; },
  #|       get pathname() { return this._pathname; },
  #|       set pathname(v) { this._pathname = v.charAt(0) === '/' ? v : '/' + v; },
  #|       get search() { return this._search; },
  #|       set search(v) { this._search = v.charAt(0) === '?' ? v : (v ? '?' + v : ''); this._searchParams = new URLSearchParams(this._search); },
  #|       get searchParams() { return this._searchParams; },
  #|       get hash() { return this._hash; },
  #|       set hash(v) { this._hash = v.charAt(0) === '#' ? v : (v ? '#' + v : ''); },
  #|       toString: function() { return this.href; },
  #|       toJSON: function() { return this.href; }
  #|     };
  #|
  #|     // DOMParser (minimal implementation for WPT DOM namespace tests)
  #|     function DOMParser() {}
  #|     DOMParser.prototype.parseFromString = function(str, mime) {
  #|       const type = String(mime || 'application/xml');
  #|       const text = str === undefined || str === null ? '' : String(str);
  #|       const tagMatch = text.match(/<\\s*([A-Za-z_][A-Za-z0-9:._-]*)/);
  #|       let doc;
  #|       if (type === 'text/html') {
  #|         doc = document.implementation.createHTMLDocument('');
  #|         doc.contentType = 'text/html';
  #|       } else {
  #|         // Try to extract xmlns attribute from the root element
  #|         let ns = type === 'application/xhtml+xml' ? 'http://www.w3.org/1999/xhtml' : null;
  #|         const xmlnsMatch = text.match(/xmlns\\s*=\\s*["']([^"']+)["']/);
  #|         if (xmlnsMatch) {
  #|           ns = xmlnsMatch[1];
  #|         }
  #|         const qname = tagMatch ? tagMatch[1] : null;
  #|         doc = document.implementation.createDocument(ns, qname, null);
  #|         doc.contentType = type;
  #|         // Also set the namespace on the documentElement if created
  #|         if (doc.documentElement && ns) {
  #|           doc.documentElement._namespaceURI = ns;
  #|         }
  #|       }
  #|       return doc;
  #|     };
  #|
  #|     // Initialize document doctype (simulating parser-created doctype)
  #|     _doctype = document.implementation.createDocumentType('html', '', '');
  #|     _doctype._parent = document;
  #|     _doctype.parentNode = document;
  #|   `;
  #|
  #|   const sanitizeErrorText = (value) => String(value).replace(/"/g, "'");
  #|   const buildErrorMessage = (err) => {
  #|     const msg = err && err.message ? err.message : String(err);
  #|     const stack = err && err.stack ? err.stack : '';
  #|     const head = String(code).slice(0, 400).replace(/"/g, "'");
  #|     const tail = String(code).slice(-200).replace(/"/g, "'");
  #|     return sanitizeErrorText(msg) + (stack ? ("\n" + sanitizeErrorText(stack)) : '') +
  #|       "\n[code head]\n" + head + "\n[code tail]\n" + tail;
  #|   };
  #|
  #|   // Use QuickJS if initialized, otherwise use Node.js vm
  #|   if (globalThis.__quickjs_initialized && globalThis.__quickjs && !globalThis.__use_nodejs_vm) {
  #|     // QuickJS execution
  #|     const QuickJS = globalThis.__quickjs;
  #|     const vm = QuickJS.newContext();
  #|     try {
  #|       // Phase 1: Run setup + user code and capture result
  #|       const userCodeResult = vm.evalCode(setupCode + '\n' + code);
  #|       if (userCodeResult.error) {
  #|         const errorStr = vm.dump(userCodeResult.error);
  #|         userCodeResult.error.dispose();
  #|         vm.dispose();
  #|         return JSON.stringify({
  #|           success: false, value: '', logs: [], domOps: [],
  #|           error: sanitizeErrorText(errorStr)
  #|         });
  #|       }
  #|       // Capture the return value before disposing
  #|       let userValue = 'undefined';
  #|       if (userCodeResult.value) {
  #|         userValue = vm.dump(userCodeResult.value);
  #|         userCodeResult.value.dispose();
  #|       }
  #|
  #|       // Phase 2: Event loop - process microtasks and timers
  #|       // Model: script -> microtasks -> task -> microtasks -> task -> ...
  #|       let maxIterations = 1000; // Prevent infinite loops
  #|
  #|       // Helper to flush all microtasks (Promise + queueMicrotask)
  #|       const flushAllMicrotasks = () => {
  #|         let totalWork = 0;
  #|         for (let i = 0; i < 100; i++) {
  #|           // Process QuickJS pending jobs (Promise.then callbacks)
  #|           let jobsExecuted = 0;
  #|           try {
  #|             const pendingResult = vm.runtime.executePendingJobs();
  #|             if (pendingResult.error) {
  #|               const errHandle = pendingResult.error;
  #|               const errorStr = vm.dump(errHandle);
  #|               errHandle.dispose();
  #|               vm.evalCode('logs.push("[ERROR] Promise: " + ' + JSON.stringify(errorStr) + ')');
  #|             } else {
  #|               jobsExecuted = pendingResult.value || 0;
  #|             }
  #|           } catch (e) {
  #|             // executePendingJobs might not be available in all environments
  #|             // Fall back to no-op
  #|           }
  #|
  #|           // Process custom microtask queue
  #|           const flushResult = vm.evalCode('_flushMicrotasks(); _microtaskQueue.length');
  #|           let queueLength = 0;
  #|           if (!flushResult.error && flushResult.value) {
  #|             queueLength = vm.getNumber(flushResult.value);
  #|             flushResult.value.dispose();
  #|           } else if (flushResult.error) {
  #|             flushResult.error.dispose();
  #|           }
  #|
  #|           totalWork += jobsExecuted + (queueLength > 0 ? 1 : 0);
  #|           if (jobsExecuted === 0 && queueLength === 0) break;
  #|         }
  #|         return totalWork;
  #|       };
  #|
  #|       // Initial microtask checkpoint (after script execution)
  #|       flushAllMicrotasks();
  #|
  #|       // Event loop: run timers and their microtasks
  #|       while (maxIterations-- > 0) {
  #|         // Run one setTimeout callback (task)
  #|         const timerResult = vm.evalCode('_runOneTimeout()');
  #|         let ranTimer = false;
  #|         if (!timerResult.error && timerResult.value) {
  #|           ranTimer = vm.dump(timerResult.value) === true;
  #|           timerResult.value.dispose();
  #|         } else if (timerResult.error) {
  #|           timerResult.error.dispose();
  #|         }
  #|
  #|         if (!ranTimer) break; // No more timers
  #|
  #|         // Microtask checkpoint after each task
  #|         flushAllMicrotasks();
  #|       }
  #|
  #|       // Phase 3: Collect logs and domOps
  #|       const collectResult = vm.evalCode('JSON.stringify({ logs, domOps })');
  #|       if (collectResult.error) {
  #|         const errorStr = vm.dump(collectResult.error);
  #|         collectResult.error.dispose();
  #|         vm.dispose();
  #|         return JSON.stringify({
  #|           success: false, value: '', logs: [], domOps: [],
  #|           error: sanitizeErrorText(errorStr)
  #|         });
  #|       }
  #|       const resultStr = vm.dump(collectResult.value);
  #|       collectResult.value.dispose();
  #|       vm.dispose();
  #|       const parsed = JSON.parse(resultStr);
  #|       return JSON.stringify({
  #|         success: true, value: userValue,
  #|         logs: parsed.logs || [], domOps: parsed.domOps || []
  #|       });
  #|     } catch (e) {
  #|       try { vm.dispose(); } catch {}
  #|       return JSON.stringify({
  #|         success: false, value: '', logs: [], domOps: [],
  #|         error: buildErrorMessage(e)
  #|       });
  #|     }
  #|   } else {
  #|     // Node.js vm fallback - two-phase execution
  #|     const vm = require('vm');
  #|     const sandbox = {};
  #|     try {
  #|       vm.createContext(sandbox);
  #|       // Phase 1: Run setup + user code and capture result
  #|       const userResult = vm.runInContext(setupCode + '\n' + code, sandbox, { timeout: 5000 });
  #|       // Phase 2: Process microtasks and timers (event loop simulation)
  #|       vm.runInContext('_flushMicrotasks()', sandbox, { timeout: 1000 });
  #|       // Run timers with microtask checkpoints after each
  #|       for (let i = 0; i < 100; i++) {
  #|         const ranTimer = vm.runInContext('_runOneTimeout()', sandbox, { timeout: 1000 });
  #|         if (!ranTimer) break;
  #|         vm.runInContext('_flushMicrotasks()', sandbox, { timeout: 1000 });
  #|       }
  #|       // Phase 3: Collect logs and domOps
  #|       const collected = vm.runInContext('({ logs, domOps })', sandbox, { timeout: 1000 });
  #|       return JSON.stringify({
  #|         success: true,
  #|         value: userResult === undefined ? 'undefined' : String(userResult),
  #|         logs: collected.logs || [],
  #|         domOps: collected.domOps || []
  #|       });
  #|     } catch (e) {
  #|       // Try to collect logs even on error
  #|       let logs = [], domOps = [];
  #|       try {
  #|         const collected = vm.runInContext('({ logs: logs || [], domOps: domOps || [] })', sandbox, { timeout: 100 });
  #|         logs = collected.logs || [];
  #|         domOps = collected.domOps || [];
  #|       } catch {}
  #|       return JSON.stringify({
  #|         success: false, value: '',
  #|         logs, domOps,
  #|         error: buildErrorMessage(e)
  #|       });
  #|     }
  #|   }
  #| }

///|
/// QuickJS runtime implementation
priv struct QuickJsRuntime {
  _unused : Int
}

///|
let quickjs_runtime : QuickJsRuntime = { _unused: 0 }

///|
fn default_js_runtime() -> &JsRuntime {
  quickjs_runtime as &JsRuntime
}

///|
impl JsRuntime for QuickJsRuntime with init(self : QuickJsRuntime) -> Unit {
  let _ = self
  if not(runtime_state.initialized) {
    let success = quickjs_init()
    if success {
      runtime_state.initialized = true
    }
  }
}

///|
impl JsRuntime for QuickJsRuntime with execute(
  self : QuickJsRuntime,
  dom : @dom.DomTree,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let context_id = register_context(dom)

  // Generate DOM initialization code from DomTree
  // This populates the mock DOM with actual HTML content
  let dom_init_code = create_dom_init_code(dom)

  // Execute: setupCode -> dom_init_code -> user_code
  let full_code = dom_init_code + "\n" + code
  let result_json = quickjs_execute_with_mock_dom(full_code)

  // Parse result
  let (result, dom_ops) = parse_js_result_with_ops(result_json)

  // Apply DOM operations to actual DomTree
  apply_dom_ops(dom, dom_ops)

  // Cleanup
  unregister_context(context_id)

  result
}

///|
/// Initialize JS runtime with QuickJS
pub fn init_js_runtime() -> Unit {
  quickjs_runtime.init()
}

///|
/// DOM operation type
priv struct DomOp {
  op : String
  id : Int
  parent_id : Int
  child_id : Int
  ref_id : Int // Reference node ID for insertBefore
  tag_name : String
  text : String
  name : String
  value : String
}

///|
/// Parse JS result JSON with DOM operations
fn parse_js_result_with_ops(json : String) -> (JsResult, Array[DomOp]) {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  let dom_ops = parse_dom_ops(json)
  ({ value, logs, success }, dom_ops)
}

///|
/// Parse DOM operations from JSON
fn parse_dom_ops(json : String) -> Array[DomOp] {
  let ops : Array[DomOp] = []
  // Find domOps array
  let pattern = "\"domOps\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      // Simple JSON array of objects parser
      let chars = json.to_array()
      let mut i = array_start
      let mut depth = 0
      let mut obj_start = -1
      while i < chars.length() {
        let c = chars[i]
        if c == '{' {
          if depth == 0 {
            obj_start = i
          }
          depth = depth + 1
        } else if c == '}' {
          depth = depth - 1
          if depth == 0 && obj_start >= 0 {
            let obj_json = json.unsafe_substring(start=obj_start, end=i + 1)
            let op = parse_single_dom_op(obj_json)
            ops.push(op)
            obj_start = -1
          }
        } else if c == ']' && depth == 0 {
          break
        }
        i = i + 1
      }
    }
    None => ()
  }
  ops
}

///|
/// Parse a single DOM operation object
fn parse_single_dom_op(json : String) -> DomOp {
  {
    op: extract_json_field(json, "op"),
    id: parse_int_field(json, "id"),
    parent_id: parse_int_field(json, "parentId"),
    child_id: parse_int_field(json, "childId"),
    ref_id: parse_int_field(json, "refId"),
    tag_name: extract_json_field(json, "tagName"),
    text: extract_json_field(json, "text"),
    name: extract_json_field(json, "name"),
    value: extract_json_field(json, "value"),
  }
}

///|
/// Parse integer field from JSON
fn parse_int_field(json : String, field : String) -> Int {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut end = value_start
      while end < chars.length() &&
            ((chars[end] >= '0' && chars[end] <= '9') || chars[end] == '-') {
        end = end + 1
      }
      if end > value_start {
        let num_str = json.unsafe_substring(start=value_start, end~)
        @strconv.parse_int(num_str) catch {
          _ => 0
        }
      } else {
        0
      }
    }
    None => 0
  }
}

///|
/// Resolve ID to NodeId for apply_dom_ops
/// If ID is in map, use mapped value; otherwise treat as direct DomTree NodeId
fn resolve_dom_id(id_map : Map[Int, @dom.NodeId], id : Int) -> @dom.NodeId? {
  match id_map.get(id) {
    Some(node_id) => Some(node_id)
    None =>
      // ID might be a direct DomTree NodeId (from DOM initialization)
      if id > 0 {
        Some(@dom.NodeId::from_int(id))
      } else {
        None
      }
  }
}

///|
/// Apply DOM operations to DomTree
fn apply_dom_ops(dom : @dom.DomTree, ops : Array[DomOp]) -> Unit {
  // Map mock IDs to real NodeIds
  let id_map : Map[Int, @dom.NodeId] = {}

  // Pre-populate with body (id=2 in mock)
  match dom.query_selector(dom.get_document(), "body") {
    Ok(Some(body_id)) => id_map.set(2, body_id)
    _ => ()
  }
  // Pre-populate with html (id=1 in mock)
  match dom.query_selector(dom.get_document(), "html") {
    Ok(Some(html_id)) => id_map.set(1, html_id)
    _ => ()
  }
  for op in ops {
    match op.op {
      "createElement" => {
        let node_id = dom.create_element(op.tag_name)
        id_map.set(op.id, node_id)
      }
      "createTextNode" => {
        let node_id = dom.create_text(op.text)
        id_map.set(op.id, node_id)
      }
      "createComment" => {
        let node_id = dom.create_comment(op.text)
        id_map.set(op.id, node_id)
      }
      "createDocumentFragment" => {
        // DocumentFragment is represented as a temporary container
        // For now, create a dummy element that won't be rendered
        let node_id = dom.create_element("template")
        id_map.set(op.id, node_id)
      }
      "appendChild" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(parent), Some(child)) => {
            let _ = dom.append_child(parent, child)
          }
          _ => ()
        }
      "insertBefore" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(parent), Some(child)) => {
            let ref_node = if op.ref_id > 0 {
              resolve_dom_id(id_map, op.ref_id)
            } else {
              None
            }
            let _ = dom.insert_before(parent, child, ref_node)
          }
          _ => ()
        }
      "replaceChild" => {
        let parent_id = resolve_dom_id(id_map, op.parent_id)
        let new_child_id = resolve_dom_id(id_map, op.child_id)
        let old_child_id = resolve_dom_id(id_map, op.ref_id)
        match (parent_id, new_child_id, old_child_id) {
          (Some(parent), Some(new_child), Some(old_child)) => {
            // replaceChild: insert new before old, then remove old
            let _ = dom.insert_before(parent, new_child, Some(old_child))
            let _ = dom.remove_child(parent, old_child)
          }
          _ => ()
        }
      }
      "removeChild" =>
        match
          (
            resolve_dom_id(id_map, op.parent_id),
            resolve_dom_id(id_map, op.child_id),
          ) {
          (Some(parent), Some(child)) => {
            let _ = dom.remove_child(parent, child)
          }
          _ => ()
        }
      "setAttribute" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let _ = dom.set_attribute(node_id, op.name, op.value)
          }
          None => ()
        }
      "removeAttribute" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let _ = dom.remove_attribute(node_id, op.name)
          }
          None => ()
        }
      "setTextContent" =>
        match resolve_dom_id(id_map, op.id) {
          Some(node_id) => {
            let _ = dom.set_text_content(node_id, op.value)
          }
          None => ()
        }
      _ => ()
    }
  }
}

///|
/// Extract string field from JSON
fn extract_json_field(json : String, field : String) -> String {
  let pattern = "\"" + field + "\":\""
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut end = value_start
      while end < chars.length() {
        if chars[end] == '"' && (end == value_start || chars[end - 1] != '\\') {
          break
        }
        end = end + 1
      }
      json.unsafe_substring(start=value_start, end~)
    }
    None => ""
  }
}

///|
/// Extract string array from JSON
fn extract_json_array(json : String, field : String) -> Array[String] {
  let pattern = "\"" + field + "\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      let chars = json.to_array()
      let result : Array[String] = []
      let mut i = array_start
      while i < chars.length() && chars[i] != ']' {
        if chars[i] == '"' {
          let str_start = i + 1
          let mut str_end = str_start
          while str_end < chars.length() {
            if chars[str_end] == '"' && chars[str_end - 1] != '\\' {
              break
            }
            str_end = str_end + 1
          }
          result.push(json.unsafe_substring(start=str_start, end=str_end))
          i = str_end + 1
        } else {
          i = i + 1
        }
      }
      result
    }
    None => []
  }
}
