/**
 * WPT DOM Test Runner for Crater
 *
 * Runs WPT DOM tests against Crater's mock DOM implementation.
 *
 * Usage:
 *   npx tsx scripts/wpt-dom-runner.ts wpt/dom/nodes/Document-createTextNode.html
 *   npx tsx scripts/wpt-dom-runner.ts --list
 *   npx tsx scripts/wpt-dom-runner.ts --all
 */

import vm from 'vm';
import fs from 'fs';
import path from 'path';

// Test result types
interface TestResult {
  name: string;
  status: 'pass' | 'fail' | 'error' | 'timeout';
  message?: string;
}

interface TestFileResult {
  file: string;
  tests: TestResult[];
  passed: number;
  failed: number;
  errors: number;
}

// Read mock DOM setup from js_runtime_quickjs.mbt
function extractMockDomSetup(): string {
  const mbtPath = path.join(process.cwd(), 'browser/src/js/js_runtime_quickjs.mbt');
  const content = fs.readFileSync(mbtPath, 'utf-8');

  // Extract setupCode from the file
  const match = content.match(/const setupCode = `([\s\S]*?)`;/);
  if (!match) {
    throw new Error('Could not find setupCode in js_runtime_quickjs.mbt');
  }

  // The setupCode in the MBT file uses #| prefixes, we need to clean it
  // Actually the setupCode is a template literal, let's extract it differently
  const setupStart = content.indexOf('const setupCode = `');
  if (setupStart === -1) {
    throw new Error('Could not find setupCode start');
  }

  // Find the matching backtick
  let depth = 0;
  let inString = false;
  let setupEnd = setupStart + 'const setupCode = `'.length;

  for (let i = setupEnd; i < content.length; i++) {
    const char = content[i];
    const prevChar = content[i - 1];

    if (char === '`' && prevChar !== '\\') {
      // Found closing backtick
      setupEnd = i;
      break;
    }
  }

  let setupCode = content.slice(setupStart + 'const setupCode = `'.length, setupEnd);

  // Clean up #| prefixes used in MoonBit raw strings
  setupCode = setupCode.replace(/^  #\| ?/gm, '');

  return setupCode;
}

// Minimal testharness.js implementation
function createTestHarness() {
  return `
    const __tests = [];
    const __results = [];
    let __currentTest = null;

    // DOMException class
    function DOMException(message, name) {
      this.message = message || '';
      this.name = name || 'Error';
      this.code = DOMException[name] || 0;
    }
    DOMException.prototype = Object.create(Error.prototype);
    DOMException.prototype.constructor = DOMException;
    DOMException.INDEX_SIZE_ERR = 1;
    DOMException.DOMSTRING_SIZE_ERR = 2;
    DOMException.HIERARCHY_REQUEST_ERR = 3;
    DOMException.WRONG_DOCUMENT_ERR = 4;
    DOMException.INVALID_CHARACTER_ERR = 5;
    DOMException.NO_DATA_ALLOWED_ERR = 6;
    DOMException.NO_MODIFICATION_ALLOWED_ERR = 7;
    DOMException.NOT_FOUND_ERR = 8;
    DOMException.NOT_SUPPORTED_ERR = 9;
    DOMException.INUSE_ATTRIBUTE_ERR = 10;
    DOMException.INVALID_STATE_ERR = 11;
    DOMException.SYNTAX_ERR = 12;
    DOMException.INVALID_MODIFICATION_ERR = 13;
    DOMException.NAMESPACE_ERR = 14;
    DOMException.INVALID_ACCESS_ERR = 15;
    DOMException.VALIDATION_ERR = 16;
    DOMException.TYPE_MISMATCH_ERR = 17;
    DOMException.SECURITY_ERR = 18;
    DOMException.NETWORK_ERR = 19;
    DOMException.ABORT_ERR = 20;
    DOMException.URL_MISMATCH_ERR = 21;
    DOMException.QUOTA_EXCEEDED_ERR = 22;
    DOMException.TIMEOUT_ERR = 23;
    DOMException.INVALID_NODE_TYPE_ERR = 24;
    DOMException.DATA_CLONE_ERR = 25;
    // Name to code mapping
    DOMException.IndexSizeError = 1;
    DOMException.HierarchyRequestError = 3;
    DOMException.WrongDocumentError = 4;
    DOMException.InvalidCharacterError = 5;
    DOMException.NoModificationAllowedError = 7;
    DOMException.NotFoundError = 8;
    DOMException.NotSupportedError = 9;
    DOMException.InUseAttributeError = 10;
    DOMException.InvalidStateError = 11;
    DOMException.SyntaxError = 12;
    DOMException.InvalidModificationError = 13;
    DOMException.NamespaceError = 14;
    DOMException.InvalidAccessError = 15;
    DOMException.SecurityError = 18;
    DOMException.NetworkError = 19;
    DOMException.AbortError = 20;
    DOMException.QuotaExceededError = 22;
    DOMException.TimeoutError = 23;
    DOMException.DataCloneError = 25;

    // DOM interface constructors for instanceof checks
    var Node = (typeof globalThis !== 'undefined' && globalThis.Node) ? globalThis.Node : function Node() {};
    if (typeof globalThis !== 'undefined') globalThis.Node = Node;
    // Node type constants
    if (Node.ELEMENT_NODE === undefined) Node.ELEMENT_NODE = 1;
    if (Node.ATTRIBUTE_NODE === undefined) Node.ATTRIBUTE_NODE = 2;
    if (Node.TEXT_NODE === undefined) Node.TEXT_NODE = 3;
    if (Node.CDATA_SECTION_NODE === undefined) Node.CDATA_SECTION_NODE = 4;
    if (Node.ENTITY_REFERENCE_NODE === undefined) Node.ENTITY_REFERENCE_NODE = 5;
    if (Node.ENTITY_NODE === undefined) Node.ENTITY_NODE = 6;
    if (Node.PROCESSING_INSTRUCTION_NODE === undefined) Node.PROCESSING_INSTRUCTION_NODE = 7;
    if (Node.COMMENT_NODE === undefined) Node.COMMENT_NODE = 8;
    if (Node.DOCUMENT_NODE === undefined) Node.DOCUMENT_NODE = 9;
    if (Node.DOCUMENT_TYPE_NODE === undefined) Node.DOCUMENT_TYPE_NODE = 10;
    if (Node.DOCUMENT_FRAGMENT_NODE === undefined) Node.DOCUMENT_FRAGMENT_NODE = 11;
    if (Node.NOTATION_NODE === undefined) Node.NOTATION_NODE = 12;
    // Document position constants
    if (Node.DOCUMENT_POSITION_DISCONNECTED === undefined) Node.DOCUMENT_POSITION_DISCONNECTED = 0x01;
    if (Node.DOCUMENT_POSITION_PRECEDING === undefined) Node.DOCUMENT_POSITION_PRECEDING = 0x02;
    if (Node.DOCUMENT_POSITION_FOLLOWING === undefined) Node.DOCUMENT_POSITION_FOLLOWING = 0x04;
    if (Node.DOCUMENT_POSITION_CONTAINS === undefined) Node.DOCUMENT_POSITION_CONTAINS = 0x08;
    if (Node.DOCUMENT_POSITION_CONTAINED_BY === undefined) Node.DOCUMENT_POSITION_CONTAINED_BY = 0x10;
    if (Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC === undefined) Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;
    // Copy constants to prototype
    if (Node.prototype.ELEMENT_NODE === undefined) Node.prototype.ELEMENT_NODE = 1;
    if (Node.prototype.ATTRIBUTE_NODE === undefined) Node.prototype.ATTRIBUTE_NODE = 2;
    if (Node.prototype.TEXT_NODE === undefined) Node.prototype.TEXT_NODE = 3;
    if (Node.prototype.CDATA_SECTION_NODE === undefined) Node.prototype.CDATA_SECTION_NODE = 4;
    if (Node.prototype.ENTITY_REFERENCE_NODE === undefined) Node.prototype.ENTITY_REFERENCE_NODE = 5;
    if (Node.prototype.ENTITY_NODE === undefined) Node.prototype.ENTITY_NODE = 6;
    if (Node.prototype.PROCESSING_INSTRUCTION_NODE === undefined) Node.prototype.PROCESSING_INSTRUCTION_NODE = 7;
    if (Node.prototype.COMMENT_NODE === undefined) Node.prototype.COMMENT_NODE = 8;
    if (Node.prototype.DOCUMENT_NODE === undefined) Node.prototype.DOCUMENT_NODE = 9;
    if (Node.prototype.DOCUMENT_TYPE_NODE === undefined) Node.prototype.DOCUMENT_TYPE_NODE = 10;
    if (Node.prototype.DOCUMENT_FRAGMENT_NODE === undefined) Node.prototype.DOCUMENT_FRAGMENT_NODE = 11;
    if (Node.prototype.NOTATION_NODE === undefined) Node.prototype.NOTATION_NODE = 12;
    if (Node.prototype.DOCUMENT_POSITION_DISCONNECTED === undefined) Node.prototype.DOCUMENT_POSITION_DISCONNECTED = 0x01;
    if (Node.prototype.DOCUMENT_POSITION_PRECEDING === undefined) Node.prototype.DOCUMENT_POSITION_PRECEDING = 0x02;
    if (Node.prototype.DOCUMENT_POSITION_FOLLOWING === undefined) Node.prototype.DOCUMENT_POSITION_FOLLOWING = 0x04;
    if (Node.prototype.DOCUMENT_POSITION_CONTAINS === undefined) Node.prototype.DOCUMENT_POSITION_CONTAINS = 0x08;
    if (Node.prototype.DOCUMENT_POSITION_CONTAINED_BY === undefined) Node.prototype.DOCUMENT_POSITION_CONTAINED_BY = 0x10;
    if (Node.prototype.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC === undefined) Node.prototype.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;

    // Provide Node.prototype methods if missing (delegate to instance methods when present)
    if (typeof Node.prototype.appendChild !== 'function') {
      Node.prototype.appendChild = function(child) {
        if (typeof this.appendChild === 'function' && this.appendChild !== Node.prototype.appendChild) {
          return this.appendChild(child);
        }
        if (!isNodeLike(child)) {
          throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
        }
        throw new DOMException('Cannot append child to this node type', 'HierarchyRequestError');
      };
    }
    if (typeof Node.prototype.insertBefore !== 'function') {
      Node.prototype.insertBefore = function(newChild, refChild) {
        if (typeof this.insertBefore === 'function' && this.insertBefore !== Node.prototype.insertBefore) {
          return this.insertBefore(newChild, refChild);
        }
        if (arguments.length < 2) {
          throw new TypeError('Failed to execute insertBefore: 2 arguments required');
        }
        if (!isNodeLike(newChild)) {
          throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
        }
        if (refChild !== null && refChild !== undefined && !isNodeLike(refChild)) {
          throw new TypeError('Failed to execute insertBefore: parameter 2 is not of type Node');
        }
        throw new DOMException('Cannot insert child into this node type', 'HierarchyRequestError');
      };
    }
    if (typeof Node.prototype.removeChild !== 'function') {
      Node.prototype.removeChild = function(child) {
        if (typeof this.removeChild === 'function' && this.removeChild !== Node.prototype.removeChild) {
          return this.removeChild(child);
        }
        if (!isNodeLike(child)) {
          throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
        }
        throw new DOMException('The node to be removed is not a child of this node', 'NotFoundError');
      };
    }
    if (typeof Node.prototype.replaceChild !== 'function') {
      Node.prototype.replaceChild = function(newChild, oldChild) {
        if (typeof this.replaceChild === 'function' && this.replaceChild !== Node.prototype.replaceChild) {
          return this.replaceChild(newChild, oldChild);
        }
        if (!isNodeLike(newChild) || !isNodeLike(oldChild)) {
          throw new TypeError('Failed to execute replaceChild: parameters are not of type Node');
        }
        throw new DOMException('Cannot replace child on this node type', 'HierarchyRequestError');
      };
    }

    // CharacterData, Text, Comment are defined in mockDomCode
    // Only define if not already defined (for backwards compatibility)
    if (typeof CharacterData === 'undefined') {
      function CharacterData() {}
      CharacterData.prototype = Object.create(Node.prototype);
    }

    // Text and Comment constructors with proper functionality are defined in mockDomCode
    // Do NOT override them here - just ensure prototype chain is correct
    if (typeof Text !== 'undefined' && Text.prototype) {
      // Ensure Text inherits from CharacterData
      if (Object.getPrototypeOf(Text.prototype) !== CharacterData.prototype) {
        Object.setPrototypeOf(Text.prototype, CharacterData.prototype);
      }
    }

    if (typeof Comment !== 'undefined' && Comment.prototype) {
      // Ensure Comment inherits from CharacterData
      if (Object.getPrototypeOf(Comment.prototype) !== CharacterData.prototype) {
        Object.setPrototypeOf(Comment.prototype, CharacterData.prototype);
      }
    }

    function Element() {}
    Element.prototype = Object.create(Node.prototype);
    Element.prototype.constructor = Element;

    // HTMLElement and subclasses are defined in mockDomCode
    // Just ensure prototype chain is correct
    if (typeof HTMLElement !== 'undefined' && HTMLElement.prototype) {
      if (Object.getPrototypeOf(HTMLElement.prototype) !== Element.prototype) {
        Object.setPrototypeOf(HTMLElement.prototype, Element.prototype);
      }
    }

    function Document() {
      // new Document() creates a Document (not XMLDocument) per spec
      const doc = document.implementation.createDocument(null, null, null);
      Object.setPrototypeOf(doc, Document.prototype);
      return doc;
    }
    Document.prototype = Object.create(Node.prototype);
    Document.prototype.constructor = Document;
    if (typeof XMLDocument !== 'undefined') {
      XMLDocument.prototype = Object.create(Document.prototype);
      XMLDocument.prototype.constructor = XMLDocument;
    }
    if (typeof HTMLDocument !== 'undefined') {
      HTMLDocument.prototype = Object.create(Document.prototype);
      HTMLDocument.prototype.constructor = HTMLDocument;
    }

    if (typeof DocumentFragment === 'undefined') {
      function DocumentFragment() {}
      DocumentFragment.prototype = Object.create(Node.prototype);
      DocumentFragment.prototype.constructor = DocumentFragment;
    } else if (DocumentFragment.prototype && Object.getPrototypeOf(DocumentFragment.prototype) !== Node.prototype) {
      Object.setPrototypeOf(DocumentFragment.prototype, Node.prototype);
    }

    function DocumentType() {}
    DocumentType.prototype = Object.create(Node.prototype);

    function ProcessingInstruction() {}
    ProcessingInstruction.prototype = Object.create(CharacterData.prototype);

    function DOMImplementation() {}

    // Make mock nodes inherit from proper constructors
    const _origCreateMockElement = createMockElement;
    createMockElement = function(tagName, mockId) {
      const el = _origCreateMockElement(tagName, mockId);
      const lowerTag = tagName.toLowerCase();
      const Ctor = tagToConstructor[lowerTag] || HTMLElement;
      Object.setPrototypeOf(el, Ctor.prototype);
      return el;
    };

    const _origCreateMockTextNode = createMockTextNode;
    createMockTextNode = function(text, mockId) {
      const node = _origCreateMockTextNode(text, mockId);
      Object.setPrototypeOf(node, Text.prototype);
      return node;
    };

    const _origCreateMockComment = createMockComment;
    createMockComment = function(text, mockId) {
      const node = _origCreateMockComment(text, mockId);
      Object.setPrototypeOf(node, Comment.prototype);
      return node;
    };

    const _origCreateMockDocumentFragment = createMockDocumentFragment;
    createMockDocumentFragment = function(mockId) {
      const frag = _origCreateMockDocumentFragment(mockId);
      Object.setPrototypeOf(frag, DocumentFragment.prototype);
      return frag;
    };

    const _origCreateMockProcessingInstruction = createMockProcessingInstruction;
    createMockProcessingInstruction = function(target, data, mockId) {
      const node = _origCreateMockProcessingInstruction(target, data, mockId);
      Object.setPrototypeOf(node, ProcessingInstruction.prototype);
      return node;
    };

    // Set document prototype (prefer HTMLDocument when available)
    Object.setPrototypeOf(
      document,
      (typeof HTMLDocument !== 'undefined' ? HTMLDocument.prototype : Document.prototype),
    );

    function run_cleanups(cleanups) {
      if (!cleanups) return null;
      for (const f of cleanups) {
        try { f(); } catch (e) { return e; }
      }
      return null;
    }

    function test(func, name) {
      const testName = name || 'unnamed test';
      const testObj = { name: testName, func: func, executed: true };
      __tests.push(testObj);
      const cleanups = [];
      const testContext = {
        step: function(f) { if (typeof f === 'function') f.call(this); },
        step_func: function(f) { return f; },
        step_func_done: function(f) { return function() { f.apply(this, arguments); }; },
        done: function() {},
        unreached_func: function(msg) { return function() { throw new Error(msg || 'unreached'); }; },
        add_cleanup: function(f) { if (typeof f === 'function') cleanups.push(f); }
      };
      let status = 'pass';
      let message = null;
      try {
        func.call(testContext);
      } catch (e) {
        status = 'fail';
        message = e.message || String(e);
      }
      const cleanupError = run_cleanups(cleanups);
      if (!message && cleanupError) {
        status = 'fail';
        message = cleanupError.message || String(cleanupError);
      }
      if (message) {
        __results.push({ name: testName, status, message });
      } else {
        __results.push({ name: testName, status });
      }
    }

    function async_test(funcOrName, maybeName) {
      // Form 1: async_test(function, name) - traditional
      // Form 2: async_test(name) - returns test object for step/done pattern
      if (typeof funcOrName === 'function') {
        const testObj = { name: maybeName || 'unnamed async test', func: funcOrName, async: true };
        __tests.push(testObj);
        return testObj;
      } else {
        // Form 2: funcOrName is the test name
        const testObj = {
          name: funcOrName || 'unnamed async test',
          func: null,
          async: true,
          steps: [],
          step: function(f) {
            this.steps.push(f);
            try { f.call(this); } catch(e) { this._error = e; }
          },
          step_func: function(f) {
            const self = this;
            return function() { self.step(function() { f.apply(this, arguments); }); };
          },
          step_func_done: function(f) {
            const self = this;
            return function() {
              self.step(function() { f.apply(this, arguments); });
              self._done = true;
            };
          },
          done: function() { this._done = true; },
          unreached_func: function(msg) { return function() { throw new Error(msg || 'unreached'); }; },
          cleanups: [],
          add_cleanup: function(f) { if (typeof f === 'function') this.cleanups.push(f); }
        };
        __tests.push(testObj);
        return testObj;
      }
    }

    function promise_test(func, name) {
      const testObj = { name: name || 'unnamed promise test', func: func, promise: true };
      __tests.push(testObj);
    }

    function setup(funcOrOptions, maybeOptions) {
      // If first argument is a function, execute it for setup
      if (typeof funcOrOptions === 'function') {
        funcOrOptions();
      }
      // options are ignored
    }

    function done() {
      // Test harness done - ignore
    }

    function format_value(val) {
      if (val === null) return 'null';
      if (val === undefined) return 'undefined';
      if (typeof val === 'string') return '"' + val + '"';
      if (typeof val === 'object') {
        try { return JSON.stringify(val); } catch { return String(val); }
      }
      return String(val);
    }

    function assert_equals(actual, expected, description) {
      if (actual !== expected) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + format_value(expected) + ' but got ' + format_value(actual));
      }
    }

    function assert_not_equals(actual, expected, description) {
      if (actual === expected) {
        throw new Error((description ? description + ': ' : '') +
          'got disallowed value ' + format_value(actual));
      }
    }

    function assert_true(actual, description) {
      if (actual !== true) {
        throw new Error((description ? description + ': ' : '') +
          'expected true but got ' + format_value(actual));
      }
    }

    function assert_false(actual, description) {
      if (actual !== false) {
        throw new Error((description ? description + ': ' : '') +
          'expected false but got ' + format_value(actual));
      }
    }

    function assert_implements(condition, description) {
      if (!condition) {
        throw new Error((description ? description + ': ' : '') + 'required feature not implemented');
      }
    }

    function assert_implements_optional(condition, description) {
      if (!condition) {
        throw new Error((description ? description + ': ' : '') + 'optional feature not implemented');
      }
    }

    function assert_in_array(actual, expected, description) {
      if (!expected.includes(actual)) {
        throw new Error((description ? description + ': ' : '') +
          format_value(actual) + ' not in ' + format_value(expected));
      }
    }

    function assert_array_equals(actual, expected, description) {
      const isArrayLike = (value) => typeof value === 'object' && value !== null && 'length' in value;
      if (!isArrayLike(actual) || !isArrayLike(expected)) {
        throw new Error((description ? description + ': ' : '') + 'not arrays');
      }
      if (actual.length !== expected.length) {
        throw new Error((description ? description + ': ' : '') +
          'array lengths differ: ' + actual.length + ' vs ' + expected.length);
      }
      for (let i = 0; i < actual.length; i++) {
        if (actual[i] !== expected[i]) {
          throw new Error((description ? description + ': ' : '') +
            'arrays differ at index ' + i + ': ' + format_value(actual[i]) + ' vs ' + format_value(expected[i]));
        }
      }
    }

    function assert_class_string(object, expected, description) {
      const actual = Object.prototype.toString.call(object);
      const expectedStr = '[object ' + expected + ']';
      if (actual !== expectedStr) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + expectedStr + ' but got ' + actual);
      }
    }

    function assert_throws_js(type, func, description) {
      let threw = false;
      let error = null;
      try {
        func();
      } catch (e) {
        threw = true;
        error = e;
      }
      if (!threw) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + (type.name || type) + ' to be thrown');
      }
      if (!(error instanceof type)) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + (type.name || type) + ' but got ' + (error.constructor.name || error));
      }
    }

    function assert_throws_dom(name, func, description) {
      // Support overload: assert_throws_dom(name, constructor, func, description)
      if (typeof description === 'function') {
        func = description;
        description = arguments[3];
      }
      // Map between legacy constant names and new names
      const legacyToName = {
        'INDEX_SIZE_ERR': 'IndexSizeError',
        'HIERARCHY_REQUEST_ERR': 'HierarchyRequestError',
        'WRONG_DOCUMENT_ERR': 'WrongDocumentError',
        'INVALID_CHARACTER_ERR': 'InvalidCharacterError',
        'NOT_FOUND_ERR': 'NotFoundError',
        'NOT_SUPPORTED_ERR': 'NotSupportedError',
        'INVALID_STATE_ERR': 'InvalidStateError',
        'SYNTAX_ERR': 'SyntaxError',
        'INVALID_MODIFICATION_ERR': 'InvalidModificationError',
        'NAMESPACE_ERR': 'NamespaceError'
      };
      const nameToLegacy = {};
      for (const [k, v] of Object.entries(legacyToName)) nameToLegacy[v] = k;

      let threw = false;
      let error = null;
      try {
        func();
      } catch (e) {
        threw = true;
        error = e;
      }
      if (!threw) {
        throw new Error((description ? description + ': ' : '') +
          'expected DOMException ' + name + ' to be thrown');
      }
      // Check if it's a DOMException with the right name
      const expectedName = legacyToName[name] || name;
      const expectedLegacy = nameToLegacy[name] || name;
      if (error.name !== expectedName && error.name !== expectedLegacy &&
          error.name !== name && error.code !== name) {
        const detail = error && error.message ? ': ' + error.message : '';
        throw new Error((description ? description + ': ' : '') +
          'expected DOMException ' + name + ' but got ' + (error.name || error.code || error) + detail);
      }
    }

    function assert_throws_exactly(expected, func, description) {
      let threw = false;
      let error = null;
      try {
        func();
      } catch (e) {
        threw = true;
        error = e;
      }
      if (!threw) {
        throw new Error((description ? description + ': ' : '') + 'expected exception');
      }
      if (error !== expected) {
        throw new Error((description ? description + ': ' : '') +
          'expected exactly ' + format_value(expected) + ' but got ' + format_value(error));
      }
    }

    function assert_readonly(object, property, description) {
      const desc = Object.getOwnPropertyDescriptor(object, property);
      if (desc && desc.writable) {
        throw new Error((description ? description + ': ' : '') +
          property + ' is not readonly');
      }
    }

    function assert_own_property(object, property, description) {
      if (!object.hasOwnProperty(property)) {
        throw new Error((description ? description + ': ' : '') +
          'expected own property ' + property);
      }
    }

    function assert_inherits(object, property, description) {
      if (!(property in object)) {
        throw new Error((description ? description + ': ' : '') +
          'expected inherited property ' + property);
      }
      if (object.hasOwnProperty(property)) {
        throw new Error((description ? description + ': ' : '') +
          'property ' + property + ' is own, not inherited');
      }
    }

    function assert_idl_attribute(object, name, description) {
      if (!(name in object)) {
        throw new Error((description ? description + ': ' : '') +
          'expected IDL attribute ' + name);
      }
    }

    function assert_regexp_match(actual, regexp, description) {
      if (!regexp.test(actual)) {
        throw new Error((description ? description + ': ' : '') +
          format_value(actual) + ' does not match ' + regexp);
      }
    }

    function assert_unreached(description) {
      throw new Error((description ? description + ': ' : '') + 'should not be reached');
      }

    // Run all tests and collect results
    function __runTests() {
      for (const t of __tests) {
        if (t.executed) continue;
        try {
          if (t.async) {
            // Form 2: func is null, test was created with just a name
            if (t.func === null) {
              // Steps were already executed when step() was called
              // Check if there was an error
              if (t._error) {
                throw t._error;
              }
              // Test passes if no error occurred
            } else {
              // Form 1: traditional async_test with function
              let completed = false;
              const cleanups = [];
              const testContext = {
                step: function(f) { if (typeof f === 'function') f(); },
                step_func: function(f) { return f; },
                step_func_done: function(f) { return function() { f.apply(this, arguments); completed = true; }; },
                done: function() { completed = true; },
                unreached_func: function(msg) { return function() { throw new Error(msg || 'unreached'); }; },
                add_cleanup: function(f) { if (typeof f === 'function') cleanups.push(f); }
              };
              // WPT async_test passes test object as first parameter and binds this
              t.func.call(testContext, testContext);
              const cleanupError = run_cleanups(cleanups);
              if (cleanupError) {
                throw cleanupError;
              }
            }
          } else if (t.promise) {
            // Skip promise tests for now
            __results.push({ name: t.name, status: 'skip', message: 'promise tests not supported' });
            continue;
          } else {
            t.func();
          }
          if (t.cleanups) {
            const cleanupError = run_cleanups(t.cleanups);
            if (cleanupError) throw cleanupError;
          }
          __results.push({ name: t.name, status: 'pass' });
        } catch (e) {
          __results.push({ name: t.name, status: 'fail', message: e.message || String(e) });
        }
      }
      return __results;
    }
  `;
}

// Extract test scripts from HTML file
function extractTestScripts(htmlPath: string): string[] {
  const content = fs.readFileSync(htmlPath, 'utf-8');
  const htmlDir = path.dirname(htmlPath);

  const scripts: string[] = [];

  // Extract inline scripts (excluding testharness.js and testharnessreport.js)
  const scriptRegex = /<script([^>]*)>([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = scriptRegex.exec(content)) !== null) {
    const tagAttrs = match[1];
    const scriptContent = match[2];

    // Check for src attribute
    const srcMatch =
      tagAttrs.match(/src\s*=\s*["']([^"']+)["']/i) ||
      tagAttrs.match(/src\s*=\s*([^\s>]+)/i);
    if (srcMatch) {
      const src = srcMatch[1];
      // Skip testharness files
      if (src.includes('testharness')) continue;

      // Try to load external script
      let scriptPath: string;
      if (src.startsWith('/')) {
        // Absolute path from WPT root
        scriptPath = path.join(process.cwd(), 'wpt', src);
      } else {
        scriptPath = path.join(htmlDir, src);
      }

      if (fs.existsSync(scriptPath)) {
        scripts.push(fs.readFileSync(scriptPath, 'utf-8'));
      }
    } else if (scriptContent.trim()) {
      scripts.push(scriptContent);
    }
  }

  return scripts;
}

function buildFixtureCode(htmlPath: string): string {
  const content = fs.readFileSync(htmlPath, 'utf-8');
  const withoutScripts = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  const voidTags = new Set([
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  ]);
  const decodeEntities = (value: string): string => {
    const named: Record<string, string> = {
      amp: '&',
      lt: '<',
      gt: '>',
      quot: '"',
      apos: "'",
    };
    return value
      .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => {
        const code = parseInt(hex, 16);
        return Number.isFinite(code) ? String.fromCodePoint(code) : _;
      })
      .replace(/&#([0-9]+);/g, (_, num) => {
        const code = parseInt(num, 10);
        return Number.isFinite(code) ? String.fromCodePoint(code) : _;
      })
      .replace(/&([a-zA-Z]+);/g, (_, name) => (name in named ? named[name] : _));
  };
  type FixtureNode =
    | { type: 'element'; tag: string; attrs: Record<string, string>; children: FixtureNode[] }
    | { type: 'text'; text: string }
    | { type: 'comment'; text: string };

  const root: FixtureNode = { type: 'element', tag: '__root__', attrs: {}, children: [] };
  const bodyAttrs: Record<string, string> = {};
  const htmlAttrs: Record<string, string> = {};
  const headAttrs: Record<string, string> = {};
  const stack: FixtureNode[] = [root];
  let skipTag: string | null = null;
  const tokenRegex = /<!--[\s\S]*?-->|<\/?[^>]+>|[^<]+/g;

  for (const match of withoutScripts.matchAll(tokenRegex)) {
    const token = match[0];
    if (!token) continue;
    if (skipTag) {
      if (token.startsWith('</')) {
        const tag = token.slice(2, -1).trim().toLowerCase();
        if (tag === skipTag) skipTag = null;
      }
      continue;
    }
    if (token.startsWith('<!--')) {
      const text = decodeEntities(token.slice(4, -3));
      stack[stack.length - 1].children.push({ type: 'comment', text });
      continue;
    }
    if (token.startsWith('</')) {
      const tag = token.slice(2, -1).trim().toLowerCase();
      for (let i = stack.length - 1; i > 0; i--) {
        const node = stack[i];
        if (node.type === 'element' && node.tag.toLowerCase() === tag) {
          stack.length = i;
          break;
        }
      }
      continue;
    }
    if (token.startsWith('<')) {
      const tagMatch = token.match(/^<([^\s>/]+)([^>]*)>$/);
      if (!tagMatch) continue;
      const tag = tagMatch[1];
      const attrsRaw = tagMatch[2] || '';
      const lowerTag = tag.toLowerCase();
      if (lowerTag === '!doctype') continue;
      if (lowerTag === 'title') {
        skipTag = 'title';
        continue;
      }
      if (lowerTag === 'script' || lowerTag === 'meta' || lowerTag === 'link') continue;

      const attrs: Record<string, string> = {};
      const attrRegex = /([^\s=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g;
      for (const attrMatch of attrsRaw.matchAll(attrRegex)) {
        const name = attrMatch[1];
        const rawValue = attrMatch[2] ?? attrMatch[3] ?? attrMatch[4] ?? '';
        attrs[name] = decodeEntities(rawValue);
      }
      if (lowerTag === 'html') {
        Object.assign(htmlAttrs, attrs);
        continue;
      }
      if (lowerTag === 'head') {
        Object.assign(headAttrs, attrs);
        continue;
      }
      if (lowerTag === 'body') {
        Object.assign(bodyAttrs, attrs);
        continue;
      }

      const node: FixtureNode = { type: 'element', tag, attrs, children: [] };
      stack[stack.length - 1].children.push(node);
      const selfClosing = token.endsWith('/>') || voidTags.has(lowerTag);
      if (!selfClosing) {
        stack.push(node);
      }
      continue;
    }

    const text = decodeEntities(token);
    if (text.trim() === '') continue;
    stack[stack.length - 1].children.push({ type: 'text', text });
  }

  if (root.children.length === 0) return '';
  return [
    '(() => {',
    `  const __tree = ${JSON.stringify(root.children)};`,
    `  const __bodyAttrs = ${JSON.stringify(bodyAttrs)};`,
    `  const __htmlAttrs = ${JSON.stringify(htmlAttrs)};`,
    `  const __headAttrs = ${JSON.stringify(headAttrs)};`,
    '  if (typeof document === "undefined" || !document.body) return;',
    '  const __applyAttrs = (el, attrs) => {',
    '    if (!el || !attrs) return;',
    '    for (const [name, value] of Object.entries(attrs)) {',
    '      if (name === "id") { el.id = value; }',
    '      else { try { el.setAttribute(name, value); } catch {} }',
    '    }',
    '  };',
    '  __applyAttrs(document.documentElement, __htmlAttrs);',
    '  __applyAttrs(document.head, __headAttrs);',
    '  __applyAttrs(document.body, __bodyAttrs);',
    '  const __SVG_NS = "http://www.w3.org/2000/svg";',
    '  const __XLINK_NS = "http://www.w3.org/1999/xlink";',
    '  const __XMLNS_NS = "http://www.w3.org/2000/xmlns/";',
    '  const __build = (node, parent, parentNs) => {',
    '    if (!node) return;',
    '    if (node.type === "text") { parent.appendChild(document.createTextNode(node.text)); return; }',
    '    if (node.type === "comment") { parent.appendChild(document.createComment(node.text)); return; }',
    '    const isSvg = parentNs === __SVG_NS || node.tag.toLowerCase() === "svg";',
    '    const ns = isSvg ? __SVG_NS : null;',
    '    const el = ns ? document.createElementNS(ns, node.tag) : document.createElement(node.tag);',
    '    for (const [name, value] of Object.entries(node.attrs || {})) {',
    '      if (name === "id") { el.id = value; continue; }',
    '      try {',
    '        if (ns === __SVG_NS) {',
    '          const lower = name.toLowerCase();',
    '          if (lower === "xmlns" || lower.startsWith("xmlns:")) {',
    '            el.setAttributeNS(__XMLNS_NS, name, value);',
    '          } else if (lower.startsWith("xlink:")) {',
    '            el.setAttributeNS(__XLINK_NS, name, value);',
    '          } else {',
    '            el.setAttribute(name, value);',
    '          }',
    '        } else {',
    '          el.setAttribute(name, value);',
    '        }',
    '      } catch {}',
    '    }',
    '    if (node.tag.toLowerCase() === "iframe" && !("contentDocument" in el)) {',
    '      el.contentDocument = document;',
    '    }',
    '    parent.appendChild(el);',
    '    if (el.id && !(el.id in globalThis)) {',
    '      globalThis[el.id] = el;',
    '    }',
    '    if (Array.isArray(node.children)) {',
    '      for (const child of node.children) __build(child, el, ns);',
    '    }',
    '  };',
    '  for (const child of __tree) __build(child, document.body, null);',
    '})();',
  ].join('\n');
}

function buildDoctypeCode(htmlPath: string): string {
  const content = fs.readFileSync(htmlPath, 'utf-8');
  const match = content.match(/<!doctype\s+([^>\s]+)(?:\s+public\s+"([^"]*)"\s+"([^"]*)")?/i);
  if (!match) return '';
  const name = match[1];
  const publicId = match[2] ?? '';
  const systemId = match[3] ?? '';
  const doctypeIndex = match.index ?? 0;
  const commentIndex = content.indexOf('<!--');
  const hasLeadingComment = commentIndex !== -1 && commentIndex < doctypeIndex;
  return [
    '(() => {',
    '  if (!document._preNodes) document._preNodes = [];',
    hasLeadingComment
      ? '  document._preNodes.push(document.createComment(""));'
      : '',
    `  const __doctype = document.implementation.createDocumentType(${JSON.stringify(name)}, ${JSON.stringify(publicId)}, ${JSON.stringify(systemId)});`,
    '  __doctype._parent = document;',
    '  __doctype.parentNode = document;',
    '  if (typeof document._setDoctype === "function") {',
    '    document._setDoctype(__doctype);',
    '  } else {',
    '    document.doctype = __doctype;',
    '  }',
    '})();',
  ].join('\n');
}

// Build mock DOM code from the MBT file
function buildMockDomCode(): string {
  // Read the full js_runtime_quickjs.mbt and extract the setup code
  const mbtPath = path.join(process.cwd(), 'browser/src/js/js_runtime_quickjs.mbt');
  const content = fs.readFileSync(mbtPath, 'utf-8');

  // Find all #| lines that form the setup code
  const lines = content.split('\n');
  const setupLines: string[] = [];
  let inSetupCode = false;

  for (const line of lines) {
    if (line.includes('const setupCode = `')) {
      inSetupCode = true;
      continue;
    }
    if (inSetupCode) {
      // Check for end marker: #|   `; (backtick followed by semicolon)
      if (line.trim() === '#|   `;' || line.trim() === '#|  `;') {
        break;
      }
      if (line.trim().startsWith('#|')) {
        // Extract the code after #|
        const codeLine = line.replace(/^\s*#\|\s?/, '');
        setupLines.push(codeLine);
      }
    }
  }

  return setupLines.join('\n');
}

// Run a single test file
function runTestFile(htmlPath: string): TestFileResult {
  const fileName = path.basename(htmlPath);

  try {
    const scripts = extractTestScripts(htmlPath);
    const mockDomCode = buildMockDomCode();
    const testHarness = createTestHarness();
    const fixtureCode = buildFixtureCode(htmlPath);
    const doctypeCode = buildDoctypeCode(htmlPath);

    // Combine all code
    // mockDomCode must come first as it defines document, createMockElement, etc.
    // testHarness augments these with prototype inheritance
    const fullCode = [
      mockDomCode,
      testHarness,
      doctypeCode,
      fixtureCode,
      ...scripts,
      '__runTests();',
    ].join('\n');

    // Create sandbox context
    const sandbox = {
      console: {
        log: (...args: unknown[]) => {},
        error: (...args: unknown[]) => {},
        warn: (...args: unknown[]) => {},
      },
      setTimeout: (fn: () => void, ms: number) => {
        fn();
        return 0;
      },
      clearTimeout: () => {},
      setInterval: () => 0,
      clearInterval: () => {},
    };

    // Run in VM
    const context = vm.createContext(sandbox);
    const results = vm.runInContext(fullCode, context, {
      timeout: 5000,
      filename: fileName,
    }) as TestResult[];

    const passed = results.filter((r) => r.status === 'pass').length;
    const failed = results.filter((r) => r.status === 'fail').length;
    const errors = results.filter((r) => r.status === 'error').length;

    return { file: fileName, tests: results, passed, failed, errors };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      file: fileName,
      tests: [{ name: 'execution', status: 'error', message }],
      passed: 0,
      failed: 0,
      errors: 1,
    };
  }
}

// Get available DOM test files
function getDomTestFiles(): string[] {
  const domDir = path.join(process.cwd(), 'wpt/dom/nodes');
  if (!fs.existsSync(domDir)) {
    return [];
  }

  return fs
    .readdirSync(domDir)
    .filter((f) => f.endsWith('.html'))
    .filter((f) => !f.includes('-ref.html'))
    .map((f) => path.join(domDir, f));
}

// List available tests
function listTests(): void {
  const files = getDomTestFiles();
  console.log(`Available DOM tests: ${files.length}\n`);

  // Group by prefix
  const groups: Record<string, string[]> = {};
  for (const file of files) {
    const name = path.basename(file);
    const prefix = name.split('-')[0];
    if (!groups[prefix]) groups[prefix] = [];
    groups[prefix].push(name);
  }

  for (const [prefix, names] of Object.entries(groups).sort()) {
    console.log(`${prefix}: ${names.length} tests`);
  }
}

// Main
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('WPT DOM Test Runner for Crater\n');
    console.log('Usage:');
    console.log('  npx tsx scripts/wpt-dom-runner.ts <path/to/test.html>');
    console.log('  npx tsx scripts/wpt-dom-runner.ts --list      # List available tests');
    console.log('  npx tsx scripts/wpt-dom-runner.ts --all       # Run all DOM tests');
    console.log('  npx tsx scripts/wpt-dom-runner.ts Document-*  # Run tests matching pattern');
    return;
  }

  if (args[0] === '--list') {
    listTests();
    return;
  }

  // Collect test files
  let testFiles: string[] = [];

  if (args[0] === '--all') {
    testFiles = getDomTestFiles();
  } else {
    for (const arg of args) {
      if (arg.includes('*')) {
        // Pattern match
        const pattern = arg.replace('*', '');
        testFiles.push(...getDomTestFiles().filter((f) => path.basename(f).includes(pattern)));
      } else if (fs.existsSync(arg)) {
        testFiles.push(arg);
      } else {
        // Try to find in wpt/dom/nodes
        const fullPath = path.join(process.cwd(), 'wpt/dom/nodes', arg);
        if (fs.existsSync(fullPath)) {
          testFiles.push(fullPath);
        } else if (fs.existsSync(fullPath + '.html')) {
          testFiles.push(fullPath + '.html');
        }
      }
    }
  }

  if (testFiles.length === 0) {
    console.error('No test files found');
    process.exit(1);
  }

  console.log(`Running ${testFiles.length} test file(s)...\n`);

  let totalPassed = 0;
  let totalFailed = 0;
  let totalErrors = 0;
  const failedFiles: TestFileResult[] = [];

  for (const file of testFiles) {
    const result = runTestFile(file);

    const icon = result.failed === 0 && result.errors === 0 ? '✓' : '✗';
    console.log(`${icon} ${result.file}: ${result.passed} passed, ${result.failed} failed`);

    totalPassed += result.passed;
    totalFailed += result.failed;
    totalErrors += result.errors;

    if (result.failed > 0 || result.errors > 0) {
      failedFiles.push(result);
    }
  }

  // Print failed test details
  if (failedFiles.length > 0) {
    console.log('\nFailed tests:\n');
    for (const result of failedFiles.slice(0, 10)) {
      console.log(`  ${result.file}:`);
      for (const test of result.tests.filter((t) => t.status !== 'pass').slice(0, 5)) {
        console.log(`    ✗ ${test.name}`);
        if (test.message) {
          console.log(`      ${test.message.slice(0, 100)}`);
        }
      }
      if (result.tests.filter((t) => t.status !== 'pass').length > 5) {
        console.log(`    ... and ${result.tests.filter((t) => t.status !== 'pass').length - 5} more`);
      }
    }
    if (failedFiles.length > 10) {
      console.log(`... and ${failedFiles.length - 10} more failed files`);
    }
  }

  console.log(`\nSummary: ${totalPassed} passed, ${totalFailed} failed, ${totalErrors} errors`);
  process.exit(totalFailed + totalErrors > 0 ? 1 : 0);
}

main().catch(console.error);
