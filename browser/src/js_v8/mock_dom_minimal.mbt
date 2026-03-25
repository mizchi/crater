///|
/// Minimal mock DOM for testing.
/// A subset of the full mock_dom.js, enough for basic DOM tests.
pub fn minimal_mock_dom_js() -> String {
  #|const logs = [];
  #|const domOps = [];
  #|let nodeIdCounter = 1000;
  #|const mockElements = new Map();
  #|
  #|const _microtaskQueue = [];
  #|function queueMicrotask(cb) { _microtaskQueue.push(cb); }
  #|function _flushMicrotasks() {
  #|  let count = 0;
  #|  while (_microtaskQueue.length > 0 && count < 10000) {
  #|    const task = _microtaskQueue.shift();
  #|    try { task(); } catch(e) { logs.push('[ERROR] ' + e); }
  #|    count++;
  #|  }
  #|}
  #|
  #|const _timeouts = [];
  #|let _timeoutId = 0;
  #|function setTimeout(fn, delay) {
  #|  const id = ++_timeoutId;
  #|  _timeouts.push({ id, fn, delay: delay || 0 });
  #|  return id;
  #|}
  #|function clearTimeout(id) {
  #|  const idx = _timeouts.findIndex(t => t.id === id);
  #|  if (idx >= 0) _timeouts.splice(idx, 1);
  #|}
  #|function _runOneTimeout() {
  #|  if (_timeouts.length === 0) return false;
  #|  const t = _timeouts.shift();
  #|  try { t.fn(); } catch(e) { logs.push('[ERROR] Timeout: ' + e); }
  #|  return true;
  #|}
  #|function _runOneAnimationFrame() { return false; }
  #|
  #|class EventTarget {
  #|  constructor() { this._listeners = {}; }
  #|  addEventListener(type, fn) {
  #|    if (!this._listeners[type]) this._listeners[type] = [];
  #|    this._listeners[type].push(fn);
  #|  }
  #|  removeEventListener(type, fn) {
  #|    if (!this._listeners[type]) return;
  #|    this._listeners[type] = this._listeners[type].filter(f => f !== fn);
  #|  }
  #|  dispatchEvent(event) {
  #|    event.target = this;
  #|    const fns = this._listeners[event.type] || [];
  #|    for (const fn of fns) fn(event);
  #|    return !event.defaultPrevented;
  #|  }
  #|}
  #|
  #|class Event {
  #|  constructor(type, opts) {
  #|    this.type = type;
  #|    this.bubbles = opts?.bubbles || false;
  #|    this.cancelable = opts?.cancelable || false;
  #|    this.defaultPrevented = false;
  #|    this.target = null;
  #|  }
  #|  preventDefault() { if (this.cancelable) this.defaultPrevented = true; }
  #|  stopPropagation() {}
  #|  stopImmediatePropagation() {}
  #|}
  #|
  #|class Node extends EventTarget {
  #|  constructor(nodeType, nodeName) {
  #|    super();
  #|    this._mockId = ++nodeIdCounter;
  #|    this.nodeType = nodeType;
  #|    this.nodeName = nodeName;
  #|    this.childNodes = [];
  #|    this.parentNode = null;
  #|    this.textContent = '';
  #|    mockElements.set(this._mockId, this);
  #|  }
  #|  get firstChild() { return this.childNodes[0] || null; }
  #|  get lastChild() { return this.childNodes[this.childNodes.length - 1] || null; }
  #|  get nextSibling() {
  #|    if (!this.parentNode) return null;
  #|    const idx = this.parentNode.childNodes.indexOf(this);
  #|    return this.parentNode.childNodes[idx + 1] || null;
  #|  }
  #|  appendChild(child) {
  #|    if (child.parentNode) child.parentNode.removeChild(child);
  #|    child.parentNode = this;
  #|    this.childNodes.push(child);
  #|    domOps.push({ op: 'appendChild', parentId: this._mockId, childId: child._mockId });
  #|    return child;
  #|  }
  #|  removeChild(child) {
  #|    const idx = this.childNodes.indexOf(child);
  #|    if (idx >= 0) {
  #|      this.childNodes.splice(idx, 1);
  #|      child.parentNode = null;
  #|      domOps.push({ op: 'removeChild', parentId: this._mockId, childId: child._mockId });
  #|    }
  #|    return child;
  #|  }
  #|  get children() { return this.childNodes.filter(c => c.nodeType === 1); }
  #|}
  #|
  #|class Element extends Node {
  #|  constructor(tagName) {
  #|    super(1, tagName.toUpperCase());
  #|    this.tagName = tagName.toUpperCase();
  #|    this._attributes = {};
  #|    this.style = {};
  #|    this.classList = {
  #|      _list: [],
  #|      add(...cls) { for (const c of cls) if (!this._list.includes(c)) this._list.push(c); },
  #|      remove(...cls) { this._list = this._list.filter(c => !cls.includes(c)); },
  #|      contains(c) { return this._list.includes(c); },
  #|      toggle(c) { if (this.contains(c)) this.remove(c); else this.add(c); return this.contains(c); },
  #|    };
  #|    domOps.push({ op: 'createElement', id: this._mockId, tagName });
  #|  }
  #|  setAttribute(name, value) {
  #|    this._attributes[name] = String(value);
  #|    domOps.push({ op: 'setAttribute', id: this._mockId, name, value: String(value) });
  #|  }
  #|  getAttribute(name) { return this._attributes[name] ?? null; }
  #|  removeAttribute(name) {
  #|    delete this._attributes[name];
  #|    domOps.push({ op: 'removeAttribute', id: this._mockId, name, value: '' });
  #|  }
  #|  hasAttribute(name) { return name in this._attributes; }
  #|  get id() { return this._attributes.id || ''; }
  #|  set id(v) { this.setAttribute('id', v); }
  #|  set textContent(v) {
  #|    this.childNodes = [];
  #|    if (v) {
  #|      const t = new Text(v);
  #|      this.appendChild(t);
  #|    }
  #|    domOps.push({ op: 'setTextContent', id: this._mockId, text: v || '' });
  #|  }
  #|  get textContent() {
  #|    return this.childNodes.map(c => c.textContent).join('');
  #|  }
  #|  get innerHTML() { return this.childNodes.map(c => c.nodeType === 1 ? c.outerHTML : c.textContent).join(''); }
  #|  get outerHTML() {
  #|    const tag = this.tagName.toLowerCase();
  #|    let attrs = '';
  #|    for (const [k, v] of Object.entries(this._attributes)) attrs += ` ${k}="${v}"`;
  #|    return `<${tag}${attrs}>${this.innerHTML}</${tag}>`;
  #|  }
  #|  click() { this.dispatchEvent(new Event('click', { bubbles: true })); }
  #|  querySelector(sel) {
  #|    for (const child of this.childNodes) {
  #|      if (child.nodeType === 1 && matchesSimple(child, sel)) return child;
  #|      if (child.querySelector) { const r = child.querySelector(sel); if (r) return r; }
  #|    }
  #|    return null;
  #|  }
  #|  querySelectorAll(sel) {
  #|    const result = [];
  #|    for (const child of this.childNodes) {
  #|      if (child.nodeType === 1 && matchesSimple(child, sel)) result.push(child);
  #|      if (child.querySelectorAll) result.push(...child.querySelectorAll(sel));
  #|    }
  #|    return result;
  #|  }
  #|}
  #|
  #|class Text extends Node {
  #|  constructor(data) { super(3, '#text'); this.data = data; this.textContent = data; }
  #|}
  #|
  #|function matchesSimple(el, sel) {
  #|  if (sel.startsWith('#')) return el.id === sel.slice(1);
  #|  if (sel.startsWith('.')) return el.classList?.contains(sel.slice(1));
  #|  return el.tagName === sel.toUpperCase();
  #|}
  #|
  #|class MutationObserver {
  #|  constructor(cb) { this._cb = cb; this._targets = []; }
  #|  observe(target, opts) { this._targets.push({ target, opts }); }
  #|  disconnect() { this._targets = []; }
  #|}
  #|
  #|const _docElement = new Element('html');
  #|const _head = new Element('head');
  #|const _body = new Element('body');
  #|_docElement.appendChild(_head);
  #|_docElement.appendChild(_body);
  #|
  #|const document = {
  #|  nodeType: 9,
  #|  nodeName: '#document',
  #|  documentElement: _docElement,
  #|  head: _head,
  #|  body: _body,
  #|  childNodes: [_docElement],
  #|  createElement(tag) { return new Element(tag); },
  #|  createTextNode(text) { return new Text(text); },
  #|  getElementById(id) {
  #|    for (const [, el] of mockElements) {
  #|      if (el.nodeType === 1 && el.id === id) return el;
  #|    }
  #|    return null;
  #|  },
  #|  querySelector(sel) { return _docElement.querySelector(sel) || _body.querySelector(sel); },
  #|  querySelectorAll(sel) { return [..._docElement.querySelectorAll(sel), ..._body.querySelectorAll(sel)]; },
  #|};
  #|
  #|const window = { document, setTimeout, clearTimeout, queueMicrotask, Event, MutationObserver };
  #|const self = window;
}
